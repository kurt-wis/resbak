extends RefCounted

## Konstruksyon (scenes/construction_site.tscn), 2026-10-17 pass: layout and spawns, collision
## audit (spawns and base rings are clear, three walkable routes between the halves, vaultable
## props marked), camera occlusion fade, the sand-castle base prop and its crumble, the hot
## afternoon (fog, warm sun, drifting dust), music/ambience entries and the Audio music API,
## and a bot soak (nobody commanded to move stays stuck for 3 s).

const MAP := "res://scenes/construction_site.tscn"
const CASTLE := "res://assets/props/sand_castle.tscn"
const CELL := 0.5 ## walkability grid resolution, metres
## vehicle node (under the map) -> its prop in assets/props/vehicles/ (tools/build_vehicle_props.py)
const VEHICLES := {
	"RoadAndWalkways/PhilippineJeepney": "jeepney", "RoadAndWalkways/Pickup": "pickup",
	"RoadAndWalkways/ServicePickup": "pickup", "ConstructionEquipment/OrangeTrackedExcavator": "digger",
	"ConstructionEquipment/DumpTruck": "hauler", "ConstructionEquipment/CompactYellowLoader": "wheel_loader",
}

func run(t: TestCtx) -> void:
	await _layout(t)
	await _routes(t)
	await _occlusion(t)
	await _castle(t)
	_weather_and_audio(t)
	await _court_atmosphere(t)
	await _soak(t)

# ---- helpers ----------------------------------------------------------------------------------
## The real map with a 5v5 of bots, manual stepping (like match_scene, minus HUD and camera).
func _real_match(t: TestCtx, bots := true, map_path := MAP) -> MatchHost:
	var holder := Node3D.new()
	holder.name = "TestMatch"
	t.tree.root.add_child(holder)
	var map := (load(map_path) as PackedScene).instantiate() as Node3D
	MapDressing.disable_map_cameras(map)
	holder.add_child(map)
	var world := Node3D.new()
	world.name = "World"
	holder.add_child(world)
	var host := MatchHost.new()
	host.manual_step = true
	holder.add_child(host)
	var lineup: Array = []
	for team in range(2):
		for ts in range(5):
			lineup.append({"hero_id": HeroData.ORDER[ts], "team": team, "team_slot": ts, "is_bot": bots, "name": "B%d%d" % [team, ts]})
	host.setup(world, map, lineup, {"seed": 4242, "skip_intro": true})
	var inputs := ScriptedInput.new()
	for h in host.heroes:
		host.input_sources[h.slot] = inputs
	host.set_meta("inputs", inputs)
	return host

func _map(host: MatchHost) -> Node3D:
	return host.layout.root

## Is a capsule of `radius` standing at (x, z) touching anything a hero collides with?
func _blocked(space: PhysicsDirectSpaceState3D, x: float, z: float, radius: float) -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(1.8, radius * 2.0 + 0.4)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.2 + cap.height * 0.5, z))
	q.collision_mask = RB.L_WORLD | RB.L_VAULTABLE
	return not space.intersect_shape(q, 1).is_empty()

# ---- layout, spawns, collision ----------------------------------------------------------------
func _layout(t: TestCtx) -> void:
	var host := _real_match(t)
	await t.physics_frames(2)
	var lay := host.layout
	var tun := host.tuning
	t.check(lay.spawns[RB.DILAW].size() == 2 and lay.spawns[RB.LILA].size() == 2, "two spawns per side")
	t.check(lay.bounds == Rect2(-26.5, -12.5, 49, 27), "play_bounds are the yard (got %s)" % str(lay.bounds))
	var mid := lay.bounds.get_center().x
	var own: Vector3 = lay.site(RB.DILAW, 1)
	var foe: Vector3 = lay.site(RB.LILA, 1)
	t.check(absf((own.x + foe.x) * 0.5 - mid) <= 0.05 and absf(own.z - foe.z) <= 0.05, "the two bases mirror about the yard's middle (%s vs %s, middle x %.2f)" % [str(own), str(foe), mid])
	# 2026-10-17: the piles and the spawn pairs sit on the same mirror axis as the bases
	var yard := _map(host)
	var stone := yard.get_node_or_null("MaterialPilesAndProps/RoundedStonePile")
	var gravel := yard.get_node_or_null("MaterialPilesAndProps/GravelEarthPile")
	if t.check(stone != null and gravel != null, "the two mid-field piles exist"):
		var pa: Vector3 = stone.global_position
		var pb: Vector3 = gravel.global_position
		t.check(absf((pa.x + pb.x) * 0.5 - mid) <= 0.05 and absf(pa.z - pb.z) <= 0.05, "the two piles mirror about the yard's middle (%s vs %s)" % [str(pa), str(pb)])
	for n in range(2):
		var sd: Vector3 = lay.spawns[RB.DILAW][n]
		var sl: Vector3 = lay.spawns[RB.LILA][n]
		t.check(absf((sd.x + sl.x) * 0.5 - mid) <= 0.05 and absf(sd.z - sl.z) <= 0.05, "spawn %d mirrors across the middle (%s vs %s)" % [n, str(sd), str(sl)])
	for team in range(2):
		var line: PackedVector3Array = lay.lines[team]
		t.check(line.size() >= 4, "jail line %d has points" % team)
		var inside := true
		for p in line:
			inside = inside and lay.bounds.has_point(Vector2(p.x, p.z))
		t.check(inside, "jail line %d lies inside the play bounds" % team)
	t.check(lay.line_length(RB.DILAW) >= 18.0 and absf(lay.line_length(RB.DILAW) - lay.line_length(RB.LILA)) <= 3.0, "the jail lines are long and about equal (%.1f / %.1f m)" % [lay.line_length(RB.DILAW), lay.line_length(RB.LILA)])
	var space := _map(host).get_world_3d().direct_space_state
	var bad: Array[String] = []
	for team in range(2):
		for n in range(2):
			var sp: Vector3 = lay.spawns[team][n]
			t.check(lay.bounds.has_point(Vector2(sp.x, sp.z)), "spawn %d/%d inside the bounds" % [team, n])
			for off in [-1.0, 0.0, 1.0]:
				if _blocked(space, sp.x, sp.z + off * tun.spawn_spacing, tun.body_radius):
					bad.append("spawn %d/%d offset %.0f at %s" % [team, n, off, str(sp)])
	t.check(bad.is_empty(), "no spawn slot overlaps a collider (%s)" % ", ".join(bad))
	# every base ring is open ground, so a defender can stand and fight in it
	for team in range(2):
		var centre := lay.site(team, 1)
		var blocked := 0
		for i in range(16):
			var a := i * TAU / 16.0
			for r in [0.9, 1.6, tun.base_ring_radius - 0.1]:
				if _blocked(space, centre.x + cos(a) * r, centre.z + sin(a) * r, tun.body_radius):
					blocked += 1
		t.check(blocked == 0, "base ring %d is open ground (%d blocked samples)" % [team, blocked])
	# jail lines stay walkable along their length (the chain follows them)
	for team in range(2):
		var shut := 0
		var s := 0.0
		while s <= lay.line_length(team):
			var p := lay.line_point(team, s)
			if _blocked(space, p.x, p.z, tun.body_radius):
				shut += 1
			s += 0.75
		t.check(shut == 0, "jail line %d has no collider on it (%d spots)" % [team, shut])
	# vaultable props: every CourtProps child with a body is marked
	var court := _map(host).get_node_or_null("CourtProps")
	t.check(court != null and court.get_child_count() >= 8, "CourtProps holds the vaultable props")
	var with_body := 0
	for prop in court.get_children():
		if not prop.find_children("*", "StaticBody3D", true, false).is_empty():
			with_body += 1
	t.check(with_body == court.get_child_count(), "every CourtProps prop has its collider (%d of %d)" % [with_body, court.get_child_count()])
	t.check(lay.vaultables.size() >= with_body, "MapLayout marked the vaultables (%d)" % lay.vaultables.size())
	var marked := true
	for v in lay.vaultables:
		marked = marked and v.collision_layer == RB.L_VAULTABLE and v.is_in_group("vaultable")
	t.check(marked, "vaultables sit on the vaultable layer and group")
	# big solid things block, small clutter does not
	t.check(_blocked(space, -1.2, -7.7, tun.body_radius), "the dump truck is solid")
	t.check(_blocked(space, -21.7, 11.0, tun.body_radius), "the loader is solid")
	# Mathew's Meshy vehicles (2026-10-17) replace the box-built ones in the same nodes
	var swapped := 0
	for path in VEHICLES:
		var veh := _map(host).get_node_or_null(path)
		var model := veh.get_node_or_null("Model") if veh else null
		var src: String = model.scene_file_path if model else ""
		if src == "res://assets/props/vehicles/%s.tscn" % VEHICLES[path] and not model.find_children("*", "MeshInstance3D").is_empty() 				and veh.find_children("*", "StaticBody3D").size() == 1 and veh.find_children("*Geometry*").is_empty():
			swapped += 1
	t.check(swapped == VEHICLES.size(), "every vehicle wears its Meshy prop, one collider and no old box geometry (%d of %d)" % [swapped, VEHICLES.size()])
	t.ok("Konstruksyon layout: mirrored bases, spawns, jail lines, colliders, vaultables")
	await t.free_match(host)

# ---- walkable routes --------------------------------------------------------------------------
func _routes(t: TestCtx) -> void:
	var host := _real_match(t)
	await t.physics_frames(2)
	var space := _map(host).get_world_3d().direct_space_state
	var b := host.layout.bounds
	var w := int(b.size.x / CELL)
	var h := int(b.size.y / CELL)
	# free cells for a 2 m wide lane (radius 1.0): hero-size gaps are checked separately
	var free := PackedByteArray()
	free.resize(w * h)
	var free_small := PackedByteArray()
	free_small.resize(w * h)
	for j in range(h):
		for i in range(w):
			var x := b.position.x + (i + 0.5) * CELL
			var z := b.position.y + (j + 0.5) * CELL
			free[j * w + i] = 0 if _blocked(space, x, z, 1.0) else 1
			free_small[j * w + i] = 0 if _blocked(space, x, z, host.tuning.body_radius) else 1
	var cell := func(p: Vector3) -> Vector2i:
		return Vector2i(clampi(int((p.x - b.position.x) / CELL), 0, w - 1), clampi(int((p.z - b.position.y) / CELL), 0, h - 1))
	# 1. a hero can walk from one base to the other
	var a: Vector2i = cell.call(host.layout.site(RB.DILAW, 1) + Vector3(2.6, 0, 0))
	var z2: Vector2i = cell.call(host.layout.site(RB.LILA, 1) - Vector3(2.6, 0, 0))
	t.check(_reach(free_small, w, h, a, z2), "a hero-sized path joins the two bases")
	# 2. every vertical cut through the middle of the yard has at least two 2 m wide gaps
	var thin := ""
	for xs in range(-9, 6):
		var i := int((xs - b.position.x) / CELL)
		var runs := 0
		var longest := 0
		var cur := 0
		for j in range(h):
			if free[j * w + i] == 1:
				if cur == 0:
					runs += 1
				cur += 1
				longest = maxi(longest, cur)
			else:
				cur = 0
		# two separate lanes, or one wide-open stretch (6 m of lane centres)
		if runs < 2 and longest < 12:
			thin += " x=%d:%d" % [xs, runs]
	t.check(thin == "", "every cut across the middle has two 2 m lanes or a wide-open stretch (thin:%s)" % thin)
	# 3. three routes between the halves: greedy disjoint 2 m paths from the west edge of the
	# middle to its east edge, each one blocking the cells around it for the next
	var routes := 0
	var work := free.duplicate()
	for attempt in range(4):
		var path := _path_between_columns(work, w, h, int((-9.0 - b.position.x) / CELL), int((5.0 - b.position.x) / CELL))
		if path.is_empty():
			break
		routes += 1
		for c in path:
			for dj in range(-3, 4):
				for di in range(-3, 4):
					var q: Vector2i = c + Vector2i(di, dj)
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
						work[q.y * w + q.x] = 0
	t.check(routes >= 3, "at least three separate 2 m routes cross the middle (found %d)" % routes)
	t.ok("Konstruksyon routes: bases joined, two lanes at every cut, three routes between the halves")
	await t.free_match(host)

func _reach(grid: PackedByteArray, w: int, h: int, from: Vector2i, to: Vector2i) -> bool:
	if grid[from.y * w + from.x] == 0 or grid[to.y * w + to.x] == 0:
		return false
	var seen := PackedByteArray()
	seen.resize(w * h)
	var queue: Array[Vector2i] = [from]
	seen[from.y * w + from.x] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c == to:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen[n.y * w + n.x] == 1 or grid[n.y * w + n.x] == 0:
				continue
			seen[n.y * w + n.x] = 1
			queue.append(n)
	return false

## Shortest 4-connected path from any free cell in column `ca` to any in column `cb` (cell list).
func _path_between_columns(grid: PackedByteArray, w: int, h: int, ca: int, cb: int) -> Array[Vector2i]:
	var prev := PackedInt32Array()
	prev.resize(w * h)
	prev.fill(-2)
	var queue: Array[Vector2i] = []
	for j in range(h):
		if grid[j * w + ca] == 1:
			queue.append(Vector2i(ca, j))
			prev[j * w + ca] = -1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c.x == cb:
			var out: Array[Vector2i] = []
			var k := c.y * w + c.x
			while k >= 0:
				out.append(Vector2i(k % w, k / w))
				k = prev[k]
			return out
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < ca or n.x > cb or n.y < 0 or n.y >= h or grid[n.y * w + n.x] == 0 or prev[n.y * w + n.x] != -2:
				continue
			prev[n.y * w + n.x] = c.y * w + c.x
			queue.append(n)
	return []

# ---- camera occlusion -------------------------------------------------------------------------
func _occlusion(t: TestCtx) -> void:
	var host := _real_match(t, false)
	var holder := host.get_parent()
	var local: Hero = host.heroes[0]
	var cam := MatchCamera.new()
	cam.target = local
	cam.bounds = host.layout.bounds
	cam.enemy_dir = RB.flat(host.base_system.pole_pos(RB.LILA) - host.base_system.pole_pos(RB.DILAW)).normalized()
	holder.add_child(cam)
	t.check(OcclusionFade.wanted(_map(host)), "Konstruksyon opts in to the occlusion fade")
	var occ := OcclusionFade.new()
	holder.add_child(occ)
	occ.setup(cam, _map(host), local, host.layout.bounds)
	t.check(occ.groups.size() >= 10, "the tall props are tracked (%d groups)" % occ.groups.size())
	t.check(not occ.group_named("DumpTruck").is_empty() and not occ.group_named("RoundedStonePile").is_empty(), "the dump truck and the stone pile are tracked")
	t.go_live(host)
	# the camera sits south-west of the hero; the truck at z -8.5..-6.9 hides a hero at z -9.4
	TestCtx.put(local, -1.2, -9.4)
	cam.snap()
	occ.refresh(0.0)
	t.check("DumpTruck" in occ.faded_names(), "a hero hidden behind the truck fades it (faded %s)" % str(occ.faded_names()))
	var g: Dictionary = occ.group_named("DumpTruck")
	var swapped := false
	for gi in g.mats:
		for e in g.mats[gi]:
			if e.surface >= 0 and (gi as MeshInstance3D).get_surface_override_material(e.surface) == e.faded and (e.faded as BaseMaterial3D).albedo_color.a < 0.5:
				swapped = true
	t.check(swapped, "the faded truck wears alpha materials (the Compatibility renderer ignores GeometryInstance3D.transparency)")
	TestCtx.put(local, -1.2, 4.0)
	cam.snap()
	occ.refresh(0.0)
	t.check(occ.faded_names().is_empty(), "stepping clear brings every prop back (faded %s)" % str(occ.faded_names()))
	var restored := true
	for gi in g.mats:
		for e in g.mats[gi]:
			if e.surface >= 0:
				restored = restored and (gi as MeshInstance3D).get_surface_override_material(e.surface) == e.original
	t.check(restored, "the original materials are restored")
	TestCtx.put(local, -1.2, -9.4)
	cam.snap()
	occ.refresh(0.0)
	occ.refresh(0.0, true)
	t.check(occ.faded_names().is_empty(), "the round-1 flyover forces everything back")
	# the soft fade: a real delta moves it only part of the way, more time finishes it
	occ.refresh(0.05)
	var part: float = occ.group_named("DumpTruck").t
	t.check(part > 0.0 and part < OcclusionFade.FADED, "a real frame fades part of the way (%.2f)" % part)
	occ.refresh(1.0)
	t.check(is_equal_approx(float(occ.group_named("DumpTruck").t), OcclusionFade.FADED), "and a second finishes it")
	t.ok("occlusion fade: props between camera and hero go see-through and restore")
	await t.free_match(host)

# ---- sand castle ------------------------------------------------------------------------------
func _castle(t: TestCtx) -> void:
	var host := _real_match(t, false)
	var view := MatchView.new()
	host.get_parent().add_child(view)
	view.setup(host, host.heroes[0], null)
	await t.frames(2)
	t.check(host.layout.base_prop == CASTLE and ResourceLoader.exists(CASTLE), "the map names the sand castle as its base prop")
	t.check(host.base_system.base_prop_scene() != null, "BaseSystem resolves the base prop")
	var arena := view.arena
	t.check(arena.has_prop(RB.DILAW) and arena.has_prop(RB.LILA), "both bases are sand castles")
	t.check(arena.get_node("Base_Dilaw").get_node_or_null("BaseProp") != null, "the castle replaces the basketball stand")
	t.check(arena.get_node("Base_Dilaw").get_node_or_null("Ball") == null, "no basketball on this map")
	var flag := arena.get_node("Base_Lila/BaseProp").find_child("Flag", true, false) as MeshInstance3D
	t.check(flag != null and (flag.material_override as StandardMaterial3D).albedo_color == RB.TEAM_COLORS[RB.LILA], "the flag takes the team colour")
	# collision and capture rules are unchanged: the solid pole is still the only blocker
	t.check(host.base_system.pole_bodies.size() == 2, "the solid pole collider is unchanged")
	# the capture crumbles the defeated team's castle, a new round rebuilds it
	t.go_live(host)
	host.emit_event("capture", {"hero": host.heroes[0], "team": RB.DILAW})
	await t.frames(1)
	var castle := arena.get_node("Base_Lila/BaseProp") as Node3D
	arena.refresh(1.0)
	t.check(castle.scale.y < 0.4, "the captured castle slumps (scale.y %.2f)" % castle.scale.y)
	t.check(not (arena.get_node("Base_Dilaw/BaseProp") as Node3D).scale.y < 0.9, "the other castle still stands")
	host.round_flow.phase = RoundFlow.Phase.COUNTDOWN
	arena.refresh(0.1)
	t.check(is_equal_approx(castle.scale.y, 1.0), "the next round rebuilds it")
	# the court keeps its basketball stand
	var court_host := _real_match(t, false, "res://scenes/barangay_court.tscn")
	t.check(court_host.layout.base_prop == "" and court_host.base_system.base_prop_scene() == null, "Barangay Court keeps the basketball stand")
	await t.free_match(court_host)
	t.ok("sand castle: map metadata, flag, crumble, reset, court untouched")
	await t.free_match(host)

# ---- weather, music, audio API ----------------------------------------------------------------
func _weather_and_audio(t: TestCtx) -> void:
	var map := (load(MAP) as PackedScene).instantiate() as Node3D
	t.tree.root.add_child(map)
	var env := (map.find_child("HarborAtmosphere", true, false) as WorldEnvironment).environment
	t.check(env.fog_enabled and env.fog_light_color.r > env.fog_light_color.b, "a warm haze fog sits on the yard")
	var sun := map.find_child("WarmAfternoonSun", true, false) as DirectionalLight3D
	t.check(sun.light_color.r > sun.light_color.b + 0.25 and sun.light_energy >= 0.9, "the sun is hot and warm (energy %.2f)" % sun.light_energy)
	t.check(bool(map.get_node("Gameplay").get_meta("dust", false)), "the map asks for drifting dust")
	var dust := MapDressing.add_dust(map, Rect2(-26.5, -12.5, 49, 27))
	var save := t.tree.root.get_node_or_null("Save")
	var motion_off: bool = save != null and bool(save.get_setting("accessibility", "reduce_motion"))
	t.check(dust != null or motion_off, "dust is built unless Reduce motion is on")
	if dust:
		t.check(dust.amount >= 60 and dust.mesh != null and dust.get_parent() == map, "dust is a CPUParticles3D under the map")
	map.queue_free()
	var scene_script := load("res://scripts/match/match_scene.gd")
	var amb: Dictionary = scene_script.AMBIENCE
	var mus: Dictionary = scene_script.MUSIC
	t.check(amb.has("construction_site") and mus.has("construction_site"), "ambience and music entries exist for construction_site")
	var audio := t.tree.root.get_node("Audio")
	audio.stop_music(0.0)
	audio.play_music(mus["construction_site"], 0.0)
	t.check(audio.music_name == "music_construction_site", "play_music tracks the current track")
	audio.set_music_layer("tension", true, 0.0)
	t.check(audio.music_layers.get("tension", false) == true, "set_music_layer turns a stem on")
	if audio._layer_players.has("tension"): # the stem is a different tune: it replaces the base, never overlaps it
		t.check(audio._music_player.volume_db <= audio.LAYER_SILENT_DB + 0.1 and audio._layer_players["tension"].volume_db >= audio.MUSIC_LAYER_DB - 0.1, "the tension stem crossfades the base out (%.0f dB base)" % audio._music_player.volume_db)
	audio.set_music_layer("tension", false, 0.0)
	t.check(audio.music_layers.get("tension", true) == false, "and off")
	audio.stop_music(0.0)
	t.check(audio.music_name == "" and audio.music_layers.is_empty(), "stop_music clears the state")
	audio.set_music_layer("tension", true) # nothing playing: no error
	var heard: Array[String] = []
	var on_cue := func(n: String, _tx: String, _at: Vector3): heard.append(n)
	audio.cue.connect(on_cue)
	var view_script := load("res://scripts/match/match_view.gd")
	t.check(view_script.SFX.has("tag") and view_script.SFX.has("capture") and view_script.SFX.has("jailed"), "match events map to sound names")
	audio.cue.disconnect(on_cue)
	t.ok("Konstruksyon weather, ambience/music entries, Audio music API")

# ---- bot soak ---------------------------------------------------------------------------------
## Ten bots play 45 s of live time. A hero that is free, able to move and commanded to move at
## speed, yet covers under 0.5 m in 3 s, is stuck; none may be.
func _soak(t: TestCtx) -> void:
	var host := _real_match(t)
	var holder := host.get_parent()
	for h in host.heroes:
		var b := BotBrain.new()
		holder.add_child(b)
		b.setup(h, host, 1)
		host.input_sources[h.slot] = b
	t.go_live(host)
	var window := RB.ticks(3.0)
	var run_ticks := {}
	var travelled := {}
	var last := {}
	var stuck: Array[String] = []
	var ticks_live := 0
	for i in range(RB.ticks(45.0)):
		host.step()
		if not host.round_live():
			continue
		ticks_live += 1
		for hero in host.heroes:
			var slot: int = hero.slot
			var moving: bool = hero.is_free() and hero.can_move() and not hero.capturing and hero.frame != null and hero.frame.move.length() > 0.5
			var pos := Vector2(hero.global_position.x, hero.global_position.z)
			if not moving:
				run_ticks[slot] = 0
				travelled[slot] = 0.0
			else:
				run_ticks[slot] = int(run_ticks.get(slot, 0)) + 1
				travelled[slot] = float(travelled.get(slot, 0.0)) + pos.distance_to(last.get(slot, pos))
				if run_ticks[slot] >= window:
					if travelled[slot] < 0.5:
						stuck.append("%s (slot %d) near (%.1f, %.1f) at tick %d" % [hero.display_name, slot, pos.x, pos.y, host.tick])
					run_ticks[slot] = 0
					travelled[slot] = 0.0
			last[slot] = pos
	t.check(ticks_live > RB.ticks(10.0), "the soak ran live for a while (%d ticks)" % ticks_live)
	t.check(stuck.is_empty(), "no bot is stuck for 3 s commanded to move: %s" % "; ".join(stuck))
	t.ok("Konstruksyon bot soak: %d live ticks, nobody stuck" % ticks_live)
	await t.free_match(host)


func _court_atmosphere(t: TestCtx) -> void:
	var holder := Node3D.new()
	t.tree.root.add_child(holder)
	var court := (load("res://scenes/barangay_court.tscn") as PackedScene).instantiate() as Node3D
	holder.add_child(court)
	var site := (load(MAP) as PackedScene).instantiate() as Node3D
	var court_env := (court.find_child("CourtAtmosphere", true, false) as WorldEnvironment).environment
	var site_env := (site.find_child("HarborAtmosphere", true, false) as WorldEnvironment).environment
	var sun := court.find_child("WarmAfternoonSun", true, false) as DirectionalLight3D
	var site_sun := site.find_child("WarmAfternoonSun", true, false) as DirectionalLight3D
	t.check(court_env.fog_enabled and t.near(court_env.ambient_light_energy, site_env.ambient_light_energy), "court uses the same authored ambient/fog system")
	t.check(court_env.fog_density < site_env.fog_density and court_env.ambient_light_color.b > court_env.ambient_light_color.r, "court has lighter haze and cooler fill to retain paint readability")
	t.check(t.near(sun.light_energy, site_sun.light_energy) and t.near(sun.shadow_opacity, site_sun.shadow_opacity), "court shares the construction sun energy and shadow treatment")
	t.check(sun.light_color.b > site_sun.light_color.b, "court sun is warm without the construction site's strong amber cast")
	MapDressing.add_lighting(holder, false, court)
	t.check(not sun.shadow_enabled and holder.find_children("*", "DirectionalLight3D", true, false).size() == 1, "authored court lighting honors no-shadows without adding a second sun")
	t.check(holder.find_children("*", "WorldEnvironment", true, false).size() == 1, "court never receives a duplicate fallback environment")
	var camera := Camera3D.new()
	holder.add_child(camera)
	var ink := MapDressing.add_ink_edges(camera, Rect2(-23.4, -13, 46.8, 34.8), court)
	t.check(ink.shader.resource_path == "res://shaders/illustrated_edges.gdshader" and t.near(ink.get_shader_parameter("stroke_pixels"), 0.8), "court uses the construction site's same illustrated edge shader/width")
	var profile: Dictionary = court.get_node("Gameplay").get_meta("presentation")
	t.check(ink.get_shader_parameter("haze_color") == profile.haze_color, "court's shader haze reads its authored palette")
	var source_paint: ShaderMaterial = null
	for node in court.find_children("*", "MeshInstance3D", true, false):
		if node.mesh and node.mesh.get_surface_count() > 0:
			var candidate := node.get_active_material(0) as ShaderMaterial
			if candidate and candidate.shader and candidate.shader.resource_path == "res://shaders/reference_paint.gdshader":
				source_paint = candidate
				break
	MapDressing.apply_court_summer(court)
	var finished := 0
	for node in court.find_children("*", "MeshInstance3D", true, false):
		if node.mesh:
			for index in range(node.mesh.get_surface_count()):
				var material := node.get_active_material(index) as ShaderMaterial
				if material and material.get_shader_parameter("summer_wear") == 1.0:
					finished += 1
	t.check(finished > 20, "summer finish reaches court architecture and prop material instances")
	t.check(source_paint != null and source_paint.get_shader_parameter("summer_wear") != 1.0, "summer wear never mutates the shared source material")
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color(.1,.7,.25,1)
	plain.roughness = .2
	var localized := MapDressing._summer_material(plain, profile, true, {}) as StandardMaterial3D
	t.check(localized != plain and t.near(plain.roughness, .2) and t.near(localized.roughness, .7), "prop cohesion keeps source roughness untouched")
	var bunting := ShaderMaterial.new()
	bunting.shader = load("res://shaders/reference_bunting.gdshader")
	var still := MapDressing._summer_material(bunting, profile, true, {}) as ShaderMaterial
	t.check(still.get_shader_parameter("summer_breeze") == 0.0, "Reduce motion disables decorative breeze")
	var moving := MapDressing._summer_material(bunting, profile, false, {}) as ShaderMaterial
	t.check(moving.get_shader_parameter("summer_breeze") == 1.0, "summer bunting gets a gentle breeze without moving collision")
	var dust := MapDressing.add_dust(court, Rect2(-23.4, -13, 46.8, 34.8), profile)
	var save := t.tree.root.get_node_or_null("Save")
	var motion_off: bool = save != null and bool(save.get_setting("accessibility", "reduce_motion"))
	t.check(dust != null or motion_off, "court uses the shared dust system and respects Reduce motion")
	if dust:
		t.check(dust.amount == 52 and dust.amount < 140 and dust.mesh.size.x < 0.12, "court motes are fewer and finer than construction dust")
		t.check(dust.is_set_as_top_level() and t.near(dust.global_position.y, 1.8), "court motes remain in world space despite the scaled map root")
	t.check(MapLayout.from_map(court).bounds == Rect2(-23.4, -13, 46.8, 34.8), "presentation retains court gameplay bounds")
	site.free()
	holder.queue_free()
	await t.frames(1)
	t.ok("court presentation: shared shader, authored sun/fog, lighter motes, shadow/accessibility support")

extends RefCounted

## JM "Botsog" kit against docs/RESBAK.md § 4 JM: TALBOG!, TAMARAW!!!, MAKAPAL!.
## Small matches on the grey test arena with manual stepping (see TestCtx / core_rules):
## Dilaw poles (-12, 0), Lila (12, 0); arena walls' inner faces at x = +-20, z = +-12;
## Jail_Dilaw (holds Lila prisoners) x -19.6..-13.6, z 5.2..9.2.

const D := RB.DILAW
const L := RB.LILA
const TAG := RB.BTN_TAG
const S1 := RB.BTN_SKILL1
const S2 := RB.BTN_SKILL2
const USE := RB.BTN_INTERACT

var log_events: Array = []

func run(t: TestCtx) -> void:
	await _data(t)
	await _talbog_core(t)
	await _talbog_lifetime(t)
	await _talbog_wall_geometry(t)
	await _talbog_overlap(t)
	await _talbog_clamps(t)
	await _talbog_tagged_midair(t)
	await _tamaraw_charge(t)
	await _tamaraw_shove(t)
	await _tamaraw_turn(t)
	await _tamaraw_crash(t)
	await _tamaraw_recast_and_tag(t)
	await _makapal_break(t)
	await _makapal_regen_and_jail(t)
	await _makapal_capture(t)
	await _makapal_reset_and_icon(t)

# ---- helpers ---------------------------------------------------------------------------
## Live match, Dilaw = JM + extra allies, Lila = enemies; everyone parked far away at z = -10.
func _live(t: TestCtx, d_extra: Array, l_ids: Array) -> MatchHost:
	var lineup: Array = [{"hero_id": "jm", "team": D}]
	for id in d_extra:
		lineup.append({"hero_id": id, "team": D})
	for id in l_ids:
		lineup.append({"hero_id": id, "team": L})
	var host := t.make_match(lineup)
	log_events = []
	host.event.connect(func(kind: String, _data: Dictionary): log_events.append(kind))
	t.go_live(host)
	for i in range(host.heroes.size()):
		TestCtx.put(host.heroes[i], -9.0 + 1.8 * i, -10.0)
	return host

func _count(kind: String) -> int:
	return log_events.count(kind)

func _skill1(h: Hero) -> Skill:
	return h.skills[0]

func _skill2(h: Hero) -> Skill:
	return h.skills[1]

func _marker(host: MatchHost) -> Node:
	return host.world.get_node_or_null("TalbogMarker")

func _wall(host: MatchHost) -> Node:
	for o in host.objects:
		if o.has_method("resolve_overlaps"):
			return o
	return null

func _dir_deg(v: Vector3) -> float:
	return rad_to_deg(atan2(v.z, v.x))

## Step until the skill ends (max `limit`); returns the steps taken.
func _until_inactive(host: MatchHost, sk: Skill, limit := 200) -> int:
	for i in range(limit):
		if not sk.active:
			return i
		host.step()
	return -1

# ---- data ------------------------------------------------------------------------------
func _data(t: TestCtx) -> void:
	var hd := HeroData.load_hero("jm")
	t.check(hd.skill1_script != null and hd.skill2_script != null and hd.passive_script != null, "JM data wires both skills and the passive")
	for key in ["talbog_range", "talbog_air_time", "talbog_push_radius", "talbog_push_distance", "talbog_wall_width", "talbog_wall_offset", "talbog_wall_height", "talbog_wall_time", "tamaraw_speed", "tamaraw_time", "tamaraw_turn_rate_deg", "tamaraw_push_side", "tamaraw_wall_slow", "tamaraw_wall_slow_time", "tamaraw_wall_radius", "tamaraw_self_stun", "makapal_no_tag_time", "makapal_regen_time"]:
		t.check(hd.values.has(key), "jm.tres has %s" % key)
	t.check(t.near(hd.values.talbog_range, 6.0) and t.near(hd.values.talbog_air_time, 0.6) and t.near(hd.values.talbog_push_radius, 2.5) and t.near(hd.values.talbog_push_distance, 3.0), "TALBOG! numbers match the spec")
	t.check(t.near(hd.values.talbog_wall_width, 5.0) and t.near(hd.values.talbog_wall_offset, 1.5) and t.near(hd.values.talbog_wall_height, 1.5) and t.near(hd.values.talbog_wall_time, 4.0), "TALBOG! wall numbers match the spec")
	t.check(t.near(hd.values.tamaraw_speed, 8.2) and t.near(hd.values.tamaraw_time, 1.5) and t.near(hd.values.tamaraw_turn_rate_deg, 90.0) and t.near(hd.values.tamaraw_push_side, 2.0), "TAMARAW!!! numbers (8.2 m/s: v0.1.1 pacing, spec 9)")
	t.check(t.near(hd.values.tamaraw_wall_slow, 0.4) and t.near(hd.values.tamaraw_wall_slow_time, 1.0) and t.near(hd.values.tamaraw_wall_radius, 2.5) and t.near(hd.values.tamaraw_self_stun, 0.8), "TAMARAW!!! wall-hit numbers match the spec")
	t.check(t.near(hd.values.makapal_no_tag_time, 1.5) and t.near(hd.values.makapal_regen_time, 18.0) and t.near(hd.values.makapal_rage_time, 2.0) and t.near(hd.values.makapal_spin_radius, 2.5), "MAKAPAL! numbers (v0.1.1 rage: 2 s untaggable, spin shove; regen 18 s)")
	t.check(t.near(hd.skill1_cooldown, 12.0) and t.near(hd.skill2_cooldown, 16.0) and t.near(hd.run_speed, 4.15), "JM cooldowns 12 / 16 s and speed 4.15 (v0.1.1 pacing, spec 4.6)")
	t.ok("JM data and spec numbers")

# ---- TALBOG! ---------------------------------------------------------------------------
func _talbog_core(t: TestCtx) -> void:
	var host := _live(t, ["inday"], ["nathan", "nene", "tutoy"])
	var jm: Hero = host.heroes[0]
	var ally: Hero = host.heroes[1]
	var near_enemy: Hero = host.heroes[2] # behind the landing point, inside 2.5 m
	var far_enemy: Hero = host.heroes[3] # outside 2.5 m
	var inp := t.inputs(host)
	var sk := _skill1(jm)
	t.check(sk.kind() == RB.SkillKind.OFFENSIVE, "TALBOG! is an Offensive skill")
	TestCtx.put(jm, -4.0, 0.0)
	TestCtx.put(near_enemy, -1.5, 0.0)
	TestCtx.put(far_enemy, 0.0, -4.5)
	TestCtx.put(ally, -1.5, 1.5)
	inp.aim_at(jm, Vector3(0, 0, 0))
	inp.press(jm, S1)
	t.steps(host, 1)
	t.check(sk.active, "S1 starts the jump")
	t.check(not sk.is_ready() and sk.cd_ticks >= 718, "cooldown starts on cast (12 s), got %d" % sk.cd_ticks)
	t.check(_marker(host) != null, "landing marker is visible to all at cast")
	if _marker(host) != null:
		t.check(t.near(_marker(host).global_position.x, 0.0, 0.15) and t.near(_marker(host).global_position.z, 0.0, 0.15), "marker sits on the landing point")
	t.steps(host, 17)
	t.check(sk.active and jm.global_position.y > 0.5, "airborne at 18 ticks, y=%.2f" % jm.global_position.y)
	t.check(jm.global_position.x > -3.0 and jm.global_position.x < -1.0, "midway along the arc, x=%.2f" % jm.global_position.x)
	t.check(not jm.can_press_tag(), "can't tag while airborne")
	t.check(host.can_tag(near_enemy, jm), "taggable while airborne (still within the 1 m height gap)")
	jm.apply_push(Vector3.RIGHT, 2.0, true)
	t.check(not jm.is_being_pushed(), "can't be pushed while airborne")
	inp.press(jm, TAG)
	inp.move(jm, Vector2(0, 1))
	t.steps(host, 1)
	t.check(not jm.is_winding_up(), "a Tag press while airborne does nothing")
	t.steps(host, 16)
	t.check(sk.active, "still airborne 35 ticks after the cast tick")
	t.check(absf(jm.global_position.z) < 0.05, "can't steer in the air (z=%.3f)" % jm.global_position.z)
	t.steps(host, 1)
	t.check(sk.active, "still up 36 steps after the cast")
	t.steps(host, 1)
	inp.move(jm, Vector2.ZERO)
	t.check(not sk.active, "landed 36 ticks (0.6 s) after the cast tick")
	t.check(t.near(jm.global_position.x, 0.0, 0.05) and t.near(jm.global_position.z, 0.0, 0.05), "lands on the aimed point, got %s" % jm.global_position)
	t.check(t.near(jm.global_position.y, 0.05, 0.05), "back on the ground")
	t.check(_marker(host) == null, "marker removed on landing")
	t.check(_count("talbog_land") == 1, "talbog_land event")
	t.check(jm.collision_layer == RB.L_HERO, "JM is a solid Free body again")
	# impact: enemies within 2.5 m pushed 3 m away; allies and far enemies stay
	t.steps(host, 16)
	t.check(t.near(near_enemy.global_position.x, -4.5, 0.25) and t.near(near_enemy.global_position.z, 0.0, 0.1), "enemy inside 2.5 m pushed 3 m away from the landing point, got %s" % near_enemy.global_position)
	t.check(t.near(far_enemy.global_position.z, -4.5, 0.05), "enemy outside 2.5 m is not pushed")
	t.check(t.near(ally.global_position.x, -1.5, 0.05) and t.near(ally.global_position.z, 1.5, 0.05), "allies aren't pushed")
	# the wall
	var wall = _wall(host)
	t.check(wall != null, "an earth wall exists")
	if wall != null:
		var tips: Array = wall.tip_points()
		t.check(t.near(tips[0].distance_to(tips[1]), 5.0, 0.05), "wall is 5 m wide tip to tip, got %.2f" % tips[0].distance_to(tips[1]))
		t.check(t.near(wall.apex().x, 1.5, 0.05) and t.near(wall.apex().z, 0.0, 0.05), "wall centre is 1.5 m in front of the landing point along the aim, apex %s" % wall.apex())
		t.check(tips[0].x < wall.apex().x - 1.0 and tips[1].x < wall.apex().x - 1.0, "the wall curves back round JM (tips behind the apex)")
		t.check(wall.body.collision_layer == RB.L_SKILL_WALL, "wall is on the TALBOG! wall layer")
		var tall := 0.0
		for c in wall.body.get_children():
			tall = maxf(tall, ((c as CollisionShape3D).shape as BoxShape3D).size.y)
		t.check(t.near(tall, 1.5, 0.001), "wall is 1.5 m tall")
		# solid for everyone: an enemy running into the front can't pass
		TestCtx.put(far_enemy, 4.0, 0.0)
		inp.move(far_enemy, Vector2(-1, 0))
		t.steps(host, 60)
		t.check(far_enemy.global_position.x > 1.9, "the wall blocks an enemy (x=%.2f)" % far_enemy.global_position.x)
		inp.move(far_enemy, Vector2.ZERO)
		TestCtx.put(far_enemy, 4.0, -3.0)
		TestCtx.put(ally, 4.0, 0.0)
		inp.move(ally, Vector2(-1, 0))
		t.steps(host, 60)
		t.check(ally.global_position.x > 1.9, "the wall blocks JM's allies too (x=%.2f)" % ally.global_position.x)
		inp.move(ally, Vector2.ZERO)
		t.check(not host.los_clear(Vector3(4, 0, 0), Vector3(0, 0, 0)), "the wall blocks line of sight")
		# open ends are passable: run past a tip
		TestCtx.put(far_enemy, 4.0, -3.4)
		inp.move(far_enemy, Vector2(-1, 0))
		t.steps(host, 90)
		t.check(far_enemy.global_position.x < -1.0, "open ends are passable (x=%.2f)" % far_enemy.global_position.x)
		inp.move(far_enemy, Vector2.ZERO)
		t.check(not wall.expired, "wall still up after ~3.4 s")
	await t.free_match(host)
	t.ok("TALBOG! jump, restrictions, impact push, wall, open ends")

func _talbog_lifetime(t: TestCtx) -> void:
	var host := _live(t, [], ["nathan"])
	var jm: Hero = host.heroes[0]
	var inp := t.inputs(host)
	TestCtx.put(jm, -4.0, 0.0)
	inp.aim_at(jm, Vector3(0, 0, 0))
	inp.press(jm, S1)
	t.steps(host, 37) # cast tick + 36 -> lands on the 37th step
	var wall = _wall(host)
	t.check(wall != null, "wall rises on the landing tick")
	if wall != null:
		t.steps(host, 239)
		t.check(not wall.expired and wall.body.collision_layer == RB.L_SKILL_WALL, "wall still solid 239 ticks after landing")
		t.steps(host, 1)
		t.check(wall.expired and not host.objects.has(wall), "wall gone exactly 240 ticks (4 s) after landing")
		t.check(wall.body.collision_layer == 0, "wall is no longer solid after expiry")
	var sk := _skill1(jm)
	t.check(not sk.is_ready(), "still on cooldown at 4 s")
	inp.press(jm, S1)
	t.steps(host, 1)
	t.check(not sk.active, "can't recast during cooldown")
	t.steps(host, 720 - 278)
	t.check(sk.is_ready(), "ready again 12 s after the cast")
	await t.free_match(host)
	t.ok("TALBOG! wall lasts 240 ticks, cooldown 12 s")

func _talbog_wall_geometry(t: TestCtx) -> void:
	var host := _live(t, [], ["nathan"])
	var jm: Hero = host.heroes[0]
	var inp := t.inputs(host)
	TestCtx.put(jm, -3.0, -3.0)
	inp.aim_at(jm, Vector3(0, 0, 0)) # south-east, 4.24 m
	inp.press(jm, S1)
	t.steps(host, 38)
	var wall = _wall(host)
	t.check(wall != null, "wall rises on a diagonal aim")
	if wall != null:
		var rel: Vector3 = wall.apex() - jm.global_position
		t.check(t.near(rel.length(), 1.5, 0.05), "apex 1.5 m from the landing point (got %.2f)" % rel.length())
		t.check(t.near(rad_to_deg(atan2(rel.z, rel.x)), 45.0, 1.0), "apex lies along the aim (%.1f deg)" % rad_to_deg(atan2(rel.z, rel.x)))
		var tips: Array = wall.tip_points()
		t.check(t.near(tips[0].distance_to(tips[1]), 5.0, 0.05), "5 m wide on a diagonal too")
	await t.free_match(host)
	t.ok("TALBOG! wall follows the aim")

func _talbog_overlap(t: TestCtx) -> void:
	var host := _live(t, [], ["nathan", "nene"])
	var jm: Hero = host.heroes[0]
	var inner: Hero = host.heroes[1]
	var outer: Hero = host.heroes[2]
	var inp := t.inputs(host)
	TestCtx.put(jm, -4.0, 0.0)
	TestCtx.put(inner, 1.0, 0.0) # inside the wall's footprint, JM's side
	TestCtx.put(outer, 1.7, 0.0) # inside the footprint, outer side
	inp.aim_at(jm, Vector3(0, 0, 0))
	inp.press(jm, S1)
	t.steps(host, 37)
	var wall = _wall(host)
	t.check(wall != null, "wall exists")
	if wall != null:
		t.check(not wall.overlaps(inner.global_position, 0.4), "the hero on JM's side was moved off the wall (x=%.2f)" % inner.global_position.x)
		t.check(not wall.overlaps(outer.global_position, 0.4), "the hero on the far side was moved off the wall (x=%.2f)" % outer.global_position.x)
		t.check(inner.global_position.x < 1.2, "overlapped hero nearer JM's face ends on JM's side")
		t.check(outer.global_position.x > 1.8, "overlapped hero nearer the outer face ends outside")
	t.steps(host, 20)
	t.check(inner.global_position.x < 1.2, "pushed toward the wall it stays on its own side (x=%.2f)" % inner.global_position.x)
	t.check(outer.global_position.x > 4.0, "the outer hero is pushed 3 m away (x=%.2f)" % outer.global_position.x)
	await t.free_match(host)
	t.ok("TALBOG! overlapped heroes move to the nearer side")

func _talbog_clamps(t: TestCtx) -> void:
	var host := _live(t, [], ["nathan"])
	var jm: Hero = host.heroes[0]
	var inp := t.inputs(host)
	var sk := _skill1(jm)
	# range cap: aim 10 m away -> 6 m
	TestCtx.put(jm, -6.0, -6.0)
	inp.aim_at(jm, Vector3(4.0, 0, -6.0))
	inp.press(jm, S1)
	t.steps(host, 38)
	t.check(t.near(jm.global_position.x, 0.0, 0.1) and t.near(jm.global_position.z, -6.0, 0.05), "aim past range lands at max range 6 m, got %s" % jm.global_position)
	# shorter aim lands short
	sk.cd_ticks = 0
	TestCtx.put(jm, -6.0, -6.0)
	inp.aim_at(jm, Vector3(-3.0, 0, -6.0))
	inp.press(jm, S1)
	t.steps(host, 38)
	t.check(t.near(jm.global_position.x, -3.0, 0.1), "aim inside range lands on the aim point, got %.2f" % jm.global_position.x)
	# blocking wall: lands just before the arena wall (face at x = 20)
	sk.cd_ticks = 0
	TestCtx.put(jm, 15.0, 3.0)
	inp.aim_at(jm, Vector3(25.0, 0, 3.0))
	inp.press(jm, S1)
	t.steps(host, 38)
	t.check(jm.global_position.x > 19.2 and jm.global_position.x < 19.7, "lands just before the solid wall (x=%.2f)" % jm.global_position.x)
	# jail barrier: the band around the Dilaw jail line (x = -19, z 5.2..9.2)
	sk.cd_ticks = 0
	TestCtx.put(jm, -13.0, 7.2)
	inp.aim_at(jm, Vector3(-20.0, 0, 7.2))
	inp.press(jm, S1)
	t.steps(host, 38)
	var band_edge := -19.0 + host.tuning.jail_band + host.tuning.body_radius
	t.check(jm.global_position.x > band_edge - 0.02 and jm.global_position.x < band_edge + 0.35, "lands just before the jail barrier (x=%.2f)" % jm.global_position.x)
	# his own pole (-12,0): no ring barrier any more, only the solid pole (r 0.2 + body 0.4)
	sk.cd_ticks = 0
	TestCtx.put(jm, -7.0, 0.0)
	inp.aim_at(jm, Vector3(-20.0, 0, 0.0))
	inp.press(jm, S1)
	t.steps(host, 38)
	t.check(jm.global_position.x > -11.5 and jm.global_position.x < -11.3, "lands just before his own pole (x=%.2f)" % jm.global_position.x)
	# right next to a wall the jump lands in place
	sk.cd_ticks = 0
	TestCtx.put(jm, 19.5, 3.0)
	inp.aim_at(jm, Vector3(25.0, 0, 3.0))
	inp.press(jm, S1)
	t.steps(host, 38)
	t.check(jm.global_position.x < 19.7 and jm.is_free(), "next to a wall the jump lands in place (x=%.2f)" % jm.global_position.x)
	await t.free_match(host)
	t.ok("TALBOG! range cap and landing clamps")

func _talbog_tagged_midair(t: TestCtx) -> void:
	var host := _live(t, ["inday"], ["nathan"])
	var jm: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	var inp := t.inputs(host)
	var sk := _skill1(jm)
	jm.passive.guard = false # so the tag is a real tag
	TestCtx.put(jm, -4.0, 0.0)
	inp.aim_at(jm, Vector3(0, 0, 0))
	inp.press(jm, S1)
	t.steps(host, 15)
	jm.on_tagged(nathan)
	t.check(not sk.active and jm.state == Hero.State.TAGGED, "a tag ends the jump")
	t.check(_marker(host) == null, "marker removed")
	t.steps(host, 20)
	t.check(jm.global_position.y < 0.2, "tagged JM fell to the ground (y=%.2f)" % jm.global_position.y)
	t.steps(host, 40)
	t.check(_wall(host) == null and _count("talbog_land") == 0, "no wall and no impact if JM is tagged before landing")
	await t.free_match(host)
	t.ok("TALBOG! tagged mid-air")

# ---- TAMARAW!!! ------------------------------------------------------------------------
func _tamaraw_charge(t: TestCtx) -> void:
	var host := _live(t, [], ["nathan"])
	var jm: Hero = host.heroes[0]
	var inp := t.inputs(host)
	var sk := _skill2(jm)
	t.check(sk.kind() == RB.SkillKind.OFFENSIVE, "TAMARAW!!! is an Offensive skill")
	TestCtx.put(jm, -5.0, 3.0)
	inp.aim_at(jm, Vector3(30.0, 0, 3.0))
	inp.press(jm, S2)
	t.steps(host, 1)
	var tam: float = jm.data.v("tamaraw_speed") * host.tuning.move_speed_scale
	t.check(sk.active and t.near(jm.current_speed(), tam, 0.001), "charging at a fixed %.1f m/s" % tam)
	t.check(sk.cd_ticks >= 958 and sk.cd_ticks <= 960, "cooldown 16 s starts on cast (%d)" % sk.cd_ticks)
	t.steps(host, 59)
	t.check(t.near(jm.global_position.x, -5.0 + tam, 0.3), "60 ticks of charging cover %.1f m (x=%.2f)" % [tam, jm.global_position.x])
	t.check(jm.collision_layer == RB.L_GHOST, "JM is off the hero layer while charging")
	inp.press(jm, TAG)
	t.steps(host, 1)
	t.check(not jm.is_winding_up() and not jm.can_press_tag(), "can't tag while charging")
	inp.press(jm, S1)
	t.steps(host, 1)
	t.check(not _skill1(jm).active, "can't cast S1 mid-charge")
	t.steps(host, 27)
	t.check(sk.active, "still charging at 89 ticks")
	t.steps(host, 1)
	t.check(not sk.active, "charge ends after 1.5 s = 90 ticks")
	t.check(t.near(jm.global_position.x, -5.0 + tam * 1.5, 0.4), "1.5 s covers %.1f m (x=%.2f)" % [tam * 1.5, jm.global_position.x])
	t.check(jm.collision_layer == RB.L_HERO, "solid body back after the charge")
	t.check(not jm.is_stunned(), "no stun when the charge times out")
	# slows still apply to the fixed speed
	sk.cd_ticks = 0
	TestCtx.put(jm, -5.0, 3.0)
	jm.add_slow(0.4, 3.0, "test_slow", true)
	inp.press(jm, S2)
	t.steps(host, 2)
	t.check(t.near(jm.current_speed(), tam * 0.6, 0.001), "slows apply to the fixed charge speed (got %.2f)" % jm.current_speed())
	await t.free_match(host)
	t.ok("TAMARAW!!! fixed speed, duration, can't tag, cooldown")

func _tamaraw_shove(t: TestCtx) -> void:
	var host := _live(t, ["inday"], ["nathan", "nene"])
	var jm: Hero = host.heroes[0]
	var ally: Hero = host.heroes[1]
	var e_south: Hero = host.heroes[2] # slightly +z of the path
	var e_north: Hero = host.heroes[3] # slightly -z of the path
	var inp := t.inputs(host)
	TestCtx.put(jm, -5.0, 3.0)
	TestCtx.put(ally, 2.0, 3.0)
	TestCtx.put(e_south, 0.0, 3.3)
	TestCtx.put(e_north, 4.0, 2.7)
	inp.aim_at(jm, Vector3(30.0, 0, 3.0))
	inp.press(jm, S2)
	t.steps(host, 90)
	t.check(t.near(e_south.global_position.z, 5.3, 0.2) and t.near(e_south.global_position.x, 0.0, 0.1), "enemy on the +z side is shoved 2 m sideways off the path (got %s)" % e_south.global_position)
	t.check(t.near(e_north.global_position.z, 0.7, 0.2) and t.near(e_north.global_position.x, 4.0, 0.1), "enemy on the -z side is shoved the other way (got %s)" % e_north.global_position)
	t.check(_count("tamaraw_shove") == 2, "each enemy is shoved exactly once (%d events)" % _count("tamaraw_shove"))
	t.check(t.near(ally.global_position.x, 2.0, 0.05) and t.near(ally.global_position.z, 3.0, 0.05), "allies are unaffected and don't block")
	t.check(jm.global_position.x > 4.5, "the charge ran through them all (x=%.2f)" % jm.global_position.x)
	await t.free_match(host)
	t.ok("TAMARAW!!! shoves enemies sideways once, ignores allies")

func _tamaraw_turn(t: TestCtx) -> void:
	var host := _live(t, [], ["nathan"])
	var jm: Hero = host.heroes[0]
	var inp := t.inputs(host)
	TestCtx.put(jm, -8.0, -4.0)
	inp.aim_at(jm, Vector3(30.0, 0, -4.0))
	inp.press(jm, S2)
	t.steps(host, 1) # first move heads east
	inp.aim_at(jm, Vector3(jm.global_position.x, 0, 200.0)) # now aim 90 deg to the right
	t.steps(host, 30)
	var ang := _dir_deg(jm.velocity)
	t.check(ang > 38.0 and ang < 52.0, "turns at most 90 deg/s: about 45 deg after 0.5 s (got %.1f)" % ang)
	t.steps(host, 20)
	ang = _dir_deg(jm.velocity)
	t.check(ang > 70.0 and ang < 80.0, "keeps turning toward the aim at 90 deg/s (got %.1f)" % ang)
	await t.free_match(host)
	t.ok("TAMARAW!!! turn rate")

func _tamaraw_crash(t: TestCtx) -> void:
	var host := _live(t, [], ["nathan", "nene"])
	var jm: Hero = host.heroes[0]
	var near: Hero = host.heroes[1]
	var far: Hero = host.heroes[2]
	var inp := t.inputs(host)
	var sk := _skill2(jm)
	TestCtx.put(jm, 15.0, 3.0)
	TestCtx.put(near, 18.0, 4.5) # within 2.5 m of the crash point (19.6, 3), off the path
	TestCtx.put(far, 15.0, 7.0)
	inp.aim_at(jm, Vector3(30.0, 0, 3.0))
	inp.press(jm, S2)
	t.steps(host, 1)
	var n := _until_inactive(host, sk, 80)
	t.check(n > 0 and n < 60, "hitting a wall ends the charge (after %d ticks)" % n)
	t.check(_count("tamaraw_crash") == 1, "tamaraw_crash event")
	t.check(jm.global_position.x > 19.3 and jm.global_position.x < 19.7, "stopped at the wall (x=%.2f)" % jm.global_position.x)
	t.check(jm.is_stunned() and jm.stun_ticks == 48, "JM is stunned 0.8 s = 48 ticks by the crash (%d)" % jm.stun_ticks)
	t.check(near.has_modifier("tamaraw_wall") and t.near(near.strongest_slow(), 0.4, 0.001), "enemy within 2.5 m is slowed 40 %")
	t.check(not far.has_modifier("tamaraw_wall"), "enemy beyond 2.5 m is not slowed")
	t.check(t.near(near.current_speed(), near.base_speed() * 0.6 * host.tuning.move_speed_scale, 0.01), "the slow lowers the speed to 60 %")
	inp.press(jm, S1)
	inp.press(jm, TAG)
	t.steps(host, 1)
	t.check(not _skill1(jm).active and not jm.is_winding_up(), "stunned JM can't cast or tag")
	t.steps(host, 46) # 47 ticks after the crash
	t.check(jm.is_stunned(), "still stunned 47 ticks after the crash")
	t.steps(host, 1)
	t.check(not jm.is_stunned(), "stun over after 0.8 s")
	t.steps(host, 11) # 59 ticks after the crash
	t.check(near.has_modifier("tamaraw_wall"), "slow still on 59 ticks after the crash")
	t.steps(host, 1)
	t.check(not near.has_modifier("tamaraw_wall"), "the slow lasts 1 s (60 ticks)")
	await t.free_match(host)
	# a pole is solid too
	host = _live(t, [], ["nathan"])
	jm = host.heroes[0]
	inp = t.inputs(host)
	TestCtx.put(jm, 8.0, 0.0)
	inp.aim_at(jm, Vector3(30.0, 0, 0.0))
	inp.press(jm, S2)
	t.steps(host, 40)
	t.check(not _skill2(jm).active and jm.is_stunned(), "charging into the enemy pole ends the charge and stuns")
	t.check(jm.global_position.x < 11.5, "stopped before the pole (x=%.2f)" % jm.global_position.x)
	await t.free_match(host)
	# a TALBOG! wall is solid too: land a wall, then charge into its inner face
	host = _live(t, [], ["nathan"])
	jm = host.heroes[0]
	inp = t.inputs(host)
	TestCtx.put(jm, -8.0, -4.0)
	inp.aim_at(jm, Vector3(-4.0, 0, -4.0))
	inp.press(jm, S1)
	t.steps(host, 38) # lands at (-4, -4); wall centre of curvature (-5.5, -4), inner face at x = -2.8
	t.check(_wall(host) != null, "wall is up")
	TestCtx.put(jm, -5.5, -4.0)
	inp.aim_at(jm, Vector3(30.0, 0, -4.0))
	inp.press(jm, S2)
	t.steps(host, 30)
	t.check(not _skill2(jm).active and jm.is_stunned(), "charging into a TALBOG! wall ends the charge and stuns")
	t.check(jm.global_position.x < -2.8, "stopped inside the wall (x=%.2f)" % jm.global_position.x)
	await t.free_match(host)
	t.ok("TAMARAW!!! solid hit slows nearby enemies and stuns JM")

func _tamaraw_recast_and_tag(t: TestCtx) -> void:
	var host := _live(t, ["inday"], ["nathan"])
	var jm: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	var inp := t.inputs(host)
	var sk := _skill2(jm)
	TestCtx.put(jm, -5.0, 3.0)
	inp.aim_at(jm, Vector3(30.0, 0, 3.0))
	inp.press(jm, S2)
	t.steps(host, 20)
	var x_before := jm.global_position.x
	inp.press(jm, S2)
	t.steps(host, 1)
	t.check(not sk.active, "S2 again ends the charge")
	t.check(not sk.is_ready(), "ending early doesn't refund the cooldown")
	t.check(not jm.is_stunned(), "ending on purpose doesn't stun")
	t.check(jm.global_position.x < x_before + 1.2, "JM slows to a stop after the recast (x=%.2f)" % jm.global_position.x)
	# tagged during the charge: ends
	jm.passive.guard = false
	sk.cd_ticks = 0
	TestCtx.put(jm, -5.0, 3.0)
	inp.press(jm, S2)
	t.steps(host, 10)
	t.check(sk.active, "charging again")
	jm.on_tagged(nathan)
	t.check(not sk.active, "a tag ends the charge")
	await t.free_match(host)
	t.ok("TAMARAW!!! recast and tag end the charge")

# ---- MAKAPAL! --------------------------------------------------------------------------
## `tagger` taps Tag aimed at `victim`, then steps to the landing tick (windup + 1 steps).
func _tag_jm(t: TestCtx, host: MatchHost, tagger: Hero, victim: Hero) -> void:
	var inp := t.inputs(host)
	inp.aim_at(tagger, victim.global_position)
	inp.press(tagger, TAG)
	t.steps(host, RB.ticks(host.tuning.tag_windup) + 1)

func _makapal_break(t: TestCtx) -> void:
	var host := _live(t, ["inday"], ["nathan"])
	var jm: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	var pas = jm.passive
	t.check(pas.guard, "JM starts with the guard up")
	t.check(pas.hud_state().on, "HUD state says guard on")
	TestCtx.put(jm, 0.0, 0.0)
	TestCtx.put(nathan, 1.5, 0.0)
	_tag_jm(t, host, nathan, jm)
	t.check(jm.state == Hero.State.FREE, "first tag doesn't jail JM")
	t.check(not pas.guard, "the guard is broken")
	t.check(_count("guard_break") == 1 and _count("tag") == 0, "guard_break event, no tag event")
	t.check(not nathan.is_stumbling(), "the tagger doesn't stumble")
	t.check(jm.tagged_ticks == 0, "JM is not frozen")
	t.check(host.stats[nathan.slot].tags == 1 and host.stats[nathan.slot].guard_breaks == 1, "it counts as a successful tag and a guard break")
	t.check(host.stats[nathan.slot].impact == 2, "guard break gives the usual tag Impact")
	t.check(jm.tag_block_ticks == 90, "JM can't tag for 1.5 s (got %d)" % jm.tag_block_ticks)
	if jm.visual.has_clip("GuardBreak"):
		t.check(jm.visual._req_clip == "GuardBreak", "GuardBreak clip plays")
	t.check(not pas.hud_state().on, "HUD state says guard off")
	t.inputs(host).move(jm, Vector2(0, 1))
	t.steps(host, 10)
	t.check(jm.global_position.z > 0.2, "JM isn't frozen after the break (z=%.2f)" % jm.global_position.z)
	t.inputs(host).move(jm, Vector2.ZERO)
	t.steps(host, 79) # 89 ticks after the break
	t.check(jm.tag_block_ticks == 1 and not jm.can_press_tag(), "still barred from tagging 89 ticks after the break")
	t.steps(host, 1)
	t.check(jm.tag_block_ticks == 0 and jm.can_press_tag(), "tagging allowed 90 ticks after the break")
	await t.free_match(host)
	t.ok("MAKAPAL! first tag breaks the guard, no jail, no stumble, 1.5 s no-tag")

func _makapal_regen_and_jail(t: TestCtx) -> void:
	var host := _live(t, ["inday"], ["nathan"])
	var jm: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	var pas = jm.passive
	TestCtx.put(jm, 0.0, 0.0)
	TestCtx.put(nathan, 1.5, 0.0)
	_tag_jm(t, host, nathan, jm)
	var regen := RB.ticks(jm.data.v("makapal_regen_time"))
	t.steps(host, regen - 1)
	t.check(not pas.guard, "guard still down one tick before it returns")
	t.check(pas.hud_state().fill > 0.99 and not pas.hud_state().on, "HUD fill nearly full just before the guard returns")
	t.steps(host, 1)
	t.check(pas.guard, "guard returns %d ticks after the break" % regen)
	await t.free_match(host)
	# GALIT!: right after the break JM spins, shoves the tagger away and can't be tagged
	host = _live(t, ["inday"], ["nathan"])
	jm = host.heroes[0]
	nathan = host.heroes[2]
	pas = jm.passive
	TestCtx.put(jm, 0.0, 0.0)
	TestCtx.put(nathan, 1.5, 0.0)
	_tag_jm(t, host, nathan, jm)
	var rage := RB.ticks(jm.data.v("makapal_rage_time"))
	t.check(jm.is_immune() and not host.can_tag(nathan, jm), "GALIT!: JM can't be tagged right after the break")
	t.check(_count("jm_rage") == 1, "jm_rage event")
	t.steps(host, 15)
	t.check(RB.flat_dist(nathan.global_position, jm.global_position) > 3.0, "the angry spin shoved the tagger away (%.2f m)" % RB.flat_dist(nathan.global_position, jm.global_position))
	TestCtx.put(nathan, jm.global_position.x + 1.5, jm.global_position.z)
	t.steps(host, 30)
	TestCtx.put(nathan, jm.global_position.x + 1.5, jm.global_position.z)
	_tag_jm(t, host, nathan, jm)
	t.check(jm.state == Hero.State.FREE, "a tag during the rage does nothing")
	t.steps(host, rage)
	t.check(not jm.is_immune(), "the rage ends after %d ticks" % rage)
	await t.free_match(host)
	# a second tag after the rage, before the guard returns, jails; the timer keeps running in jail
	host = _live(t, ["inday"], ["nathan"])
	jm = host.heroes[0]
	nathan = host.heroes[2]
	pas = jm.passive
	regen = RB.ticks(jm.data.v("makapal_regen_time"))
	TestCtx.put(jm, 0.0, 0.0)
	TestCtx.put(nathan, 1.5, 0.0)
	_tag_jm(t, host, nathan, jm)
	t.steps(host, rage + 10)
	TestCtx.put(nathan, jm.global_position.x + 1.5, jm.global_position.z)
	_tag_jm(t, host, nathan, jm)
	t.check(jm.state == Hero.State.TAGGED, "the next tag after the rage jails JM (tagged state)")
	t.check(_count("tag") == 1 and _count("guard_break") == 1, "one guard break then one real tag")
	t.steps(host, 60)
	t.check(jm.state == Hero.State.JAILED or jm.state == Hero.State.CHAINED, "JM is in jail")
	t.steps(host, regen)
	t.check(not pas.guard and pas.regen_pending, "the regen time ran out in jail: guard waits for the rescue")
	jm.on_freed(nathan, 4.0, 4.0)
	t.check(pas.guard, "the guard is back the moment JM is freed")
	await t.free_match(host)
	# freed before the regen time is up: still broken until then
	host = _live(t, ["inday"], ["nathan"])
	jm = host.heroes[0]
	nathan = host.heroes[2]
	pas = jm.passive
	TestCtx.put(jm, 0.0, 0.0)
	TestCtx.put(nathan, 1.5, 0.0)
	_tag_jm(t, host, nathan, jm) # break at tick B
	t.steps(host, rage + 10)
	TestCtx.put(nathan, jm.global_position.x + 1.5, jm.global_position.z)
	_tag_jm(t, host, nathan, jm)
	t.steps(host, 60)
	jm.on_freed(nathan, 4.0, 4.0)
	t.check(not pas.guard and not pas.regen_pending, "freed early: guard still down")
	var tag_steps := RB.ticks(host.tuning.tag_windup) + 1
	t.steps(host, regen - (rage + 10 + tag_steps + 60) - 1)
	t.check(not pas.guard, "guard still down one tick before it returns")
	t.steps(host, 1)
	t.check(pas.guard, "guard returns on time even after a jail visit")
	await t.free_match(host)
	t.ok("MAKAPAL! rage (untaggable + spin shove), regen, next tag jails, jail keeps the timer")
func _makapal_capture(t: TestCtx) -> void:
	var host := _live(t, ["inday"], ["nathan"])
	var jm: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	var pas = jm.passive
	TestCtx.put(jm, 10.7, 0.0) # gap to the Lila pole: 1.3 - 0.6 = 0.7 m
	TestCtx.put(nathan, 9.0, 0.0)
	t.inputs(host).hold(jm, USE)
	t.steps(host, 20)
	t.check(jm.capturing, "JM is capturing")
	_tag_jm(t, host, nathan, jm)
	t.check(jm.state == Hero.State.TAGGED, "tagged while capturing: jailed even with the guard")
	t.check(pas.guard, "the guard isn't spent by that tag")
	t.check(_count("tag") == 1 and _count("guard_break") == 0, "a real tag, no guard break")
	t.steps(host, 60)
	t.check(jm.state == Hero.State.JAILED or jm.state == Hero.State.CHAINED, "JM is in jail")
	t.check(pas.guard, "guard state is kept in jail")
	jm.on_freed(nathan, 4.0, 4.0)
	t.check(pas.guard, "and after the rescue")
	await t.free_match(host)
	t.ok("MAKAPAL! doesn't protect a capturing JM, state kept in jail")

func _makapal_reset_and_icon(t: TestCtx) -> void:
	var host := _live(t, ["inday"], ["nathan"])
	var jm: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	var pas = jm.passive
	TestCtx.put(jm, 0.0, 0.0)
	TestCtx.put(nathan, 1.5, 0.0)
	t.steps(host, 2)
	var icon: Sprite3D = jm.visual.extras.get_node_or_null("GuardIcon")
	t.check(icon != null and icon.visible, "shield icon shown above JM (visible to all) while the guard is up")
	var tex_on: Texture2D = icon.texture if icon else null
	_tag_jm(t, host, nathan, jm)
	t.steps(host, 1)
	t.check(icon != null and icon.texture != tex_on, "the icon changes when the guard breaks")
	t.check(not pas.guard, "guard down")
	jm.reset_for_round(Vector3(-5, 0.05, 0), Vector3.RIGHT)
	t.check(pas.guard and pas.regen_ticks == 0 and not pas.regen_pending, "round reset restores the guard")
	t.steps(host, 1)
	t.check(icon != null and icon.texture == tex_on, "icon back to guard-up after the reset")
	t.check(pas.hud_state().on and pas.hud_state().fill == 1.0, "HUD state after reset")
	await t.free_match(host)
	t.ok("MAKAPAL! icon and round reset")

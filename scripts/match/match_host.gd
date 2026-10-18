class_name MatchHost
extends Node

## The host simulation (docs/RESBAK.md § 12 "Tick order"). One tick per _physics_process
## at 60 ticks/s. Everything that changes game state happens inside step(), in spec order:
##   1 inputs  2 actions  3 movement  4 jail barriers  5 tags  6 rescues  7 apply 5+6
##   8 captures  9 round end  10 events (emitted as they happen through `event`)
## Offline (vs Bots, tutorial) the same host runs locally; for LAN, clients will send
## InputFrames and draw snapshots, so keep all rules here and in the systems.

signal event(kind: String, data: Dictionary)

var tuning: Tuning
var layout: MapLayout
var world: Node3D ## parent of heroes and skill objects (the map's sibling)
var map_root: Node3D
var heroes: Array[Hero] = []
var objects: Array[SkillObject] = []
var tick := 0
var paused := false ## vs Bots / tutorial pause stops the host tick (spec § 7)
var manual_step := false ## tests drive step() themselves
var rng := RandomNumberGenerator.new()
var settings := {} ## see default_settings()
var input_sources := {} ## slot -> object with frame_for(hero: Hero, host: MatchHost) -> InputFrame
var stats := {} ## slot -> Dictionary (see _new_stats)

var training: TrainingMode
var tag_system: TagSystem
var base_system: BaseSystem
var jail_system: JailSystem
var round_flow: RoundFlow

static func default_settings() -> Dictionary:
	return {
		"skills": true, ## Tradisyonal = false (actives off; passives, speed, reach stay)
		"hazards": true,
		"base_mode": 1, ## v0.2: bases are fixed (one per team per map); kept for old saves
		"points_to_win": 3,
		"round_time": 120.0,
		"skip_intro": false, ## tests, --autoplay and the tutorial leave out the round-1 flyover
		"capture_toggle": false, ## Settings > Accessibility > Capture input
		"difficulty": 1, ## 0 Madali, 1 Katamtaman, 2 Mahirap
		"map": "barangay_court",
		"seed": 0,
	}

## lineup: Array of {hero_id, team, team_slot, name, is_bot}. Heroes go under `p_world`.
func setup(p_world: Node3D, p_map: Node3D, lineup: Array, p_settings: Dictionary = {}) -> void:
	tuning = Tuning.get_default()
	settings = default_settings()
	settings.merge(p_settings, true)
	rng.seed = int(settings.seed) if int(settings.seed) != 0 else int(Time.get_ticks_usec())
	world = p_world
	map_root = p_map
	layout = MapLayout.from_map(p_map)
	layout.mark_vaultables()
	tag_system = TagSystem.new(self)
	base_system = BaseSystem.new(self)
	jail_system = JailSystem.new(self)
	round_flow = RoundFlow.new(self)
	var slot := 0
	for entry in lineup:
		var hd := HeroData.load_hero(entry.hero_id)
		var h := Hero.new()
		# Jolt creates the body where the node enters the tree and only syncs later moves on the
		# next physics frame, so enter far below the floor, not at the origin (a phantom body there
		# shoves heroes teleported to the middle of the court until the first physics frame).
		h.position = Vector3(0, -50, 0)
		world.add_child(h)
		var team: int = entry.team
		var ts: int = entry.get("team_slot", slot % 5)
		h.setup(self, hd, team, team * 5 + ts, ts, entry.get("name", hd.display_name), entry.get("is_bot", true))
		heroes.append(h)
		stats[h.slot] = _new_stats()
		slot += 1
	base_system.setup_match()
	round_flow.start_match()
	if bool(settings.get("free_training", false)):
		training = TrainingMode.new(self)

func _physics_process(dt: float) -> void:
	if paused or manual_step or round_flow == null:
		return
	step(dt)

## One host tick.
func step(dt: float = 1.0 / RB.TICK_RATE) -> void:
	tick += 1
	round_flow.pre_tick()
	# 1. Inputs
	for h in heroes:
		h.set_frame(_frame_for(h))
	# 2. Actions
	if round_flow.accepts_actions():
		for h in heroes:
			_actions(h)
	# 3. Movement (players and skill objects; pushes, slows)
	for h in heroes:
		h.frozen = round_flow.heroes_frozen()
		h.tick_timers()
	for h in heroes:
		h.tick_move(dt)
	jail_system.after_move()
	for o in objects.duplicate():
		if is_instance_valid(o) and not o.expired:
			o.tick(dt)
	for h in heroes:
		h.tick_abilities(dt)
	# 4. Jail barriers (the own-ring base barrier is gone: docs/decisions.md 2026-10-17)
	jail_system.enforce_barriers()
	if round_flow.is_live():
		# 5. Tags, against the state after step 4; stored, not applied
		var tags := tag_system.resolve()
		# 6. Rescues (a player tagged in step 5 still counts as free here)
		var rescues := jail_system.find_rescues()
		# 7. Apply 5 and 6 together
		var landed := tag_system.apply(tags)
		jail_system.apply_rescues(rescues)
		# 8. Captures
		var captured := base_system.tick_captures()
		# 9. Round end
		round_flow.check_end(landed, captured)
	round_flow.post_tick()
	if training:
		training.post_tick()

func _frame_for(h: Hero) -> InputFrame:
	var src: Object = input_sources.get(h.slot)
	if src and src.has_method("frame_for"):
		var f: InputFrame = src.frame_for(h, self)
		if f:
			return f
	return InputFrame.new()

func _actions(h: Hero) -> void:
	var f := h.frame
	if h.state == Hero.State.FREE:
		for i in range(2):
			var s := h.skills[i]
			var btn := RB.BTN_SKILL1 if i == 0 else RB.BTN_SKILL2
			if f.was_pressed(btn):
				if s.active:
					s.on_recast(f)
				else:
					s.try_cast(f)
		for s in h.skills:
			if s.active:
				s.tick_action(f)
		tag_system.handle_tag_button(h, f)
		base_system.handle_interact(h, f)
	else:
		h.sabay_ticks = 0
		jail_system.handle_interact(h, f)
	if f.was_pressed(RB.BTN_PING):
		emit_event("ping", {"hero": h, "point": f.aim_point})

# ---- registries and queries ------------------------------------------------------------
func emit_event(kind: String, data: Dictionary = {}) -> void:
	data["tick"] = tick
	event.emit(kind, data)

func spawn_object(o: SkillObject, at: Vector3 = Vector3.INF) -> SkillObject:
	world.add_child(o)
	if at != Vector3.INF:
		o.global_position = at
	objects.append(o)
	return o

func remove_object(o: SkillObject) -> void:
	objects.erase(o)

func clear_objects() -> void:
	for o in objects.duplicate():
		if is_instance_valid(o):
			o.expire()
	objects.clear()

func round_live() -> bool:
	return round_flow != null and round_flow.is_live()

func skills_enabled() -> bool:
	return bool(settings.get("skills", true))

func team_heroes(team: int) -> Array[Hero]:
	var out: Array[Hero] = []
	for h in heroes:
		if h.team == team:
			out.append(h)
	return out

func enemies_of(h: Hero) -> Array[Hero]:
	return team_heroes(RB.other_team(h.team))

func allies_of(h: Hero, include_self := false) -> Array[Hero]:
	var out: Array[Hero] = []
	for o in heroes:
		if o.team == h.team and (include_self or o != h):
			out.append(o)
	return out

## Free heroes of `team` whose centre is within `radius` (flat) of `pos`.
func free_heroes_near(pos: Vector3, radius: float, team: int) -> Array[Hero]:
	var out: Array[Hero] = []
	for h in heroes:
		if h.team == team and h.is_free() and RB.flat_dist(h.global_position, pos) <= radius:
			out.append(h)
	return out

func hero_by_slot(slot: int) -> Hero:
	for h in heroes:
		if h.slot == slot:
			return h
	return null

## Line of sight at chest height; blocked by walls, solid props and TALBOG! walls.
func los_clear(a: Vector3, b: Vector3, mask: int = RB.MASK_LOS) -> bool:
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 0.9, 0), b + Vector3(0, 0.9, 0), mask)
	q.collide_with_areas = false
	return space.intersect_ray(q).is_empty()

## First hit of a ray at chest height (for "lands at the first wall"), or {}.
func ray_hit(a: Vector3, b: Vector3, mask: int = RB.MASK_LOS) -> Dictionary:
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 0.9, 0), b + Vector3(0, 0.9, 0), mask)
	return space.intersect_ray(q)

## How visible `target` is to `viewer` (a Hero, used for its team and position):
## 1 = visible, 0.25 = see-through (IYAK!), 0 = hidden (UBO! UBO! cloud). Allies always see
## each other; reveals (BUGA!, cough, patch) beat hiding.
func visibility(viewer: Hero, target: Hero) -> float:
	if viewer == null or target.team == viewer.team:
		return 1.0
	if target.is_revealed_to(viewer.team):
		return 1.0
	for o in objects:
		if o.hides(viewer, target.global_position):
			return 0.0
	return target.enemy_alpha

## Taggable by `tagger` right now (spec can_tag; the TagSystem owns the rule).
func can_tag(tagger: Hero, target: Hero) -> bool:
	return tag_system.can_tag(tagger, target)

# ---- stats (results screen) --------------------------------------------------------------
func _new_stats() -> Dictionary:
	return {"tags": 0, "rescues": 0, "captures": 0, "assists": 0, "saves": 0, "impact": 0,
		"captures_started": 0, "guard_breaks": 0, "pader": 0, "kidlat": 0.0, "clutch": 0,
		"round_impact": 0, "tagged_by": {}}

func add_stat(h: Hero, key: String, amount: Variant = 1) -> void:
	if h == null or not stats.has(h.slot):
		return
	stats[h.slot][key] += amount

func add_impact(h: Hero, amount: int) -> void:
	add_stat(h, "impact", amount)
	add_stat(h, "round_impact", amount)

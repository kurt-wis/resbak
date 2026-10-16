class_name Hero
extends CharacterBody3D

## One hero in a match (docs/RESBAK.md § 2 "Bodies and states", § 4 "Roster rules").
## The MatchHost drives it in tick order; it never reads Input itself (see InputFrame).
## Owns: state (Free / Tagged / Jailed / Chained), timers (EP, capture lockout, stumble, stun,
## tag block), speed modifiers (biggest bonus x strongest slow), pushes, collision layers,
## its two Skills and Passive, and a HeroVisual for presentation.
## The body is never rotated: facing lives in `facing` and on the visual only.

signal state_changed(hero: Hero, old_state: int, new_state: int)

enum State { FREE, TAGGED, JAILED, CHAINED }
const STATE_NAMES := ["free", "tagged", "jailed", "chained"]

var host: MatchHost
var tuning: Tuning
var data: HeroData
var team := RB.DILAW
var slot := 0 ## lineup slot 0-9 (Dilaw 0-4, Lila 5-9)
var team_slot := 0 ## 0-4 within the team (draft order)
var display_name := ""
var is_bot := false

var state := State.FREE
var frame := InputFrame.new() ## this tick's input (set in step 1)
var aim := Vector3(0, 0, 1) ## last valid flat aim direction
var facing := Vector3(0, 0, 1) ## where the body looks (presentation and lunge fallback)
var wish_dir := Vector3.ZERO ## this tick's wanted move direction (flat, unit or zero)

# Timers, in ticks (spec § 2: "Timers in ticks (s x 60, rounded)").
var tagged_ticks := 0 ## Tagged freeze left
var ep_ticks := 0 ## Escape Protection left
var lockout_ticks := 0 ## capture lockout left
var stumble_ticks := 0
var stun_ticks := 0
var tag_block_ticks := 0 ## can't press Tag (LUSOT! recovery, MAKAPAL! guard break)
var windup_end_tick := -1 ## host tick this hero's tag lands, or -1
var lunge_dir := Vector3.ZERO
var tagged_by: Hero = null ## sends us to the tagger's jail

var capturing := false
var capture_ticks := 0
var frozen := false ## countdown and round end: nobody moves

var enemy_alpha := 1.0 ## opacity enemies see (IYAK! see-through sets 0.25)
var revealed_ticks := [0, 0] ## per viewing team: seen everywhere (BUGA!, cough, patch)

var skills: Array[Skill] = []
var passive: Passive
var visual: HeroVisual
var body_shape: CollisionShape3D

var _mods: Array[Dictionary] = [] ## {kind: "slow"/"bonus", amount, ticks, source}
var _push_vel := Vector3.ZERO
var _push_ticks := 0
var _grounded_y := 0.0

# ---------------------------------------------------------------------------------------
func setup(p_host: MatchHost, p_data: HeroData, p_team: int, p_slot: int, p_team_slot: int, p_name: String, p_is_bot: bool) -> void:
	host = p_host
	tuning = p_host.tuning if p_host else Tuning.get_default()
	data = p_data
	team = p_team
	slot = p_slot
	team_slot = p_team_slot
	display_name = p_name
	is_bot = p_is_bot
	name = "Hero_%d_%s" % [slot, data.id]
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.02
	body_shape = CollisionShape3D.new()
	body_shape.name = "Body"
	var cap := CapsuleShape3D.new()
	cap.radius = tuning.body_radius
	cap.height = 1.5
	body_shape.shape = cap
	body_shape.position.y = 0.75
	add_child(body_shape)
	facing = Vector3(1, 0, 0) if team == RB.DILAW else Vector3(-1, 0, 0)
	aim = facing
	for i in range(2):
		var script: Script = data.skill1_script if i == 0 else data.skill2_script
		var sk: Skill = script.new() if script else Skill.new()
		sk.name = "Skill%d" % (i + 1)
		sk.hero = self
		sk.host = host
		sk.slot = i
		sk.cooldown = data.skill1_cooldown if i == 0 else data.skill2_cooldown
		add_child(sk)
		skills.append(sk)
	passive = data.passive_script.new() if data.passive_script else Passive.new()
	passive.name = "Passive"
	passive.hero = self
	passive.host = host
	add_child(passive)
	visual = HeroVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup(self)
	_update_collision()

# ---- queries ---------------------------------------------------------------------------
func is_free() -> bool:
	return state == State.FREE

func is_jailed_like() -> bool: ## Tagged, Jailed or Chained all count as jailed (spec § 2)
	return state != State.FREE

func has_ep() -> bool:
	return ep_ticks > 0

func is_stunned() -> bool:
	return stun_ticks > 0

func is_stumbling() -> bool:
	return stumble_ticks > 0

func is_winding_up() -> bool:
	return windup_end_tick >= 0

func is_disabled() -> bool: ## stumble or stun: no move, tag, skill, capture start
	return stun_ticks > 0 or stumble_ticks > 0

func round_live() -> bool:
	return host != null and host.round_live()

func active_skill() -> Skill:
	for s in skills:
		if s.active:
			return s
	return null

func can_move() -> bool:
	if frozen or state == State.TAGGED or capturing or is_disabled():
		return false
	if state == State.CHAINED:
		return host != null and host.jail_system.can_steer(self)
	return true

func can_press_tag() -> bool:
	if not round_live() or state != State.FREE or is_disabled() or capturing or is_winding_up():
		return false
	if tag_block_ticks > 0:
		return false
	for s in skills:
		if s.active and s.blocks_tagging():
			return false
	return true

func can_use_skills() -> bool:
	if not round_live() or state != State.FREE or is_disabled() or capturing or frozen:
		return false
	for s in skills:
		if s.active and s.blocks_other_skills():
			return false
	return true

func can_start_capture() -> bool:
	return round_live() and state == State.FREE and not is_disabled() and not is_winding_up() and lockout_ticks <= 0 and active_skill() == null

## Taggable by an enemy right now (state and EP; teams and height are TagSystem's job).
func is_taggable() -> bool:
	return state == State.FREE and ep_ticks <= 0

func tag_reach() -> float:
	return data.tag_reach

func base_speed() -> float:
	return data.run_speed

## Spec § 4: current = base x (1 + biggest bonus) x (1 - strongest slow). HARUROT! and
## TAMARAW!!! fix the speed (no bonus, slows apply).
func current_speed(walking := false) -> float:
	var slow := strongest_slow()
	for s in skills:
		if s.active and s.fixed_speed() > 0.0:
			return s.fixed_speed() * (1.0 - slow)
	var base := base_speed() * (tuning.walk_fraction if walking else 1.0)
	return base * (1.0 + biggest_bonus()) * (1.0 - slow)

func biggest_bonus() -> float:
	var b := passive.speed_bonus() if passive else 0.0
	for m in _mods:
		if m.kind == "bonus":
			b = maxf(b, m.amount)
	return b

func strongest_slow() -> float:
	var s := 0.0
	for m in _mods:
		if m.kind == "slow":
			s = maxf(s, m.amount)
	return s

func has_modifier(source: String) -> bool:
	for m in _mods:
		if m.source == source:
			return true
	return false

func is_revealed_to(viewer_team: int) -> bool:
	return revealed_ticks[viewer_team] > 0

func footsteps_silent() -> bool:
	return passive != null and passive.footsteps_silent()

# ---- effects (called by systems and skills) --------------------------------------------
## Slow by `fraction` (0.3 = 30 %) for `secs`. Same source refreshes instead of stacking.
func add_slow(fraction: float, secs: float, source: String, by_enemy_skill := true) -> void:
	if state == State.CHAINED: # pushes and slows ignore chained (spec § 2)
		return
	_set_mod("slow", fraction, secs, source)
	if passive:
		passive.on_slowed(by_enemy_skill)

func add_speed_bonus(fraction: float, secs: float, source: String) -> void:
	_set_mod("bonus", fraction, secs, source)

func clear_modifier(source: String) -> void:
	for i in range(_mods.size() - 1, -1, -1):
		if _mods[i].source == source:
			_mods.remove_at(i)

func _set_mod(kind: String, amount: float, secs: float, source: String) -> void:
	var t := maxi(1, RB.ticks(secs))
	for m in _mods:
		if m.source == source and m.kind == kind:
			m.amount = amount
			m.ticks = maxi(m.ticks, t)
			return
	_mods.append({"kind": kind, "amount": amount, "ticks": t, "source": source})

## Straight push over tuning.push_time, no steering; stops at walls (physics) and at jail
## and base barriers (systems clamp). Ignores Chained heroes and skills that refuse pushes.
func apply_push(direction: Vector3, distance: float, by_enemy_skill := true) -> void:
	if state == State.CHAINED or state == State.TAGGED:
		return
	for s in skills:
		if s.active and not s.can_be_pushed():
			return
	var d := RB.flat(direction)
	if d.length() < 0.001 or distance <= 0.0:
		return
	_push_ticks = maxi(1, RB.ticks(tuning.push_time))
	_push_vel = d.normalized() * (distance / tuning.push_time)
	if passive:
		passive.on_pushed(by_enemy_skill)
	for s in skills:
		s.on_owner_event("pushed", by_enemy_skill)

func is_being_pushed() -> bool:
	return _push_ticks > 0

## No stacking: the longer remaining time applies (spec § 2).
func stun(secs: float, by_enemy_skill := true) -> void:
	if state != State.FREE:
		return
	stun_ticks = maxi(stun_ticks, RB.ticks(secs))
	_disrupt()
	if passive:
		passive.on_stunned(by_enemy_skill)
	for s in skills:
		s.on_owner_event("stunned", by_enemy_skill)
	host.emit_event("stunned", {"hero": self, "seconds": secs})

func stumble(secs: float) -> void:
	if state != State.FREE:
		return
	stumble_ticks = maxi(stumble_ticks, RB.ticks(secs))
	_disrupt()

func _disrupt() -> void:
	windup_end_tick = -1
	if capturing:
		host.base_system.cancel_capture(self, "disrupted")

func reveal_to(viewer_team: int, secs: float) -> void:
	revealed_ticks[viewer_team] = maxi(revealed_ticks[viewer_team], RB.ticks(secs))

# ---- notifications ---------------------------------------------------------------------
func notify_tag_pressed() -> void:
	ep_ticks = 0
	_update_collision()
	if passive:
		passive.on_tag_pressed()
	for s in skills:
		s.on_owner_event("tag_pressed", null)

func notify_skill_cast(skill: Skill) -> void:
	if skill.kind() != RB.SkillKind.NEITHER:
		ep_ticks = 0
		_update_collision()
	if passive:
		passive.on_skill_cast(skill)
	for s in skills:
		if s != skill:
			s.on_owner_event("skill_cast", skill)

func notify_capture_start() -> void:
	ep_ticks = 0
	_update_collision()
	if passive:
		passive.on_capture_start()
	for s in skills:
		s.on_owner_event("capture_start", null)

func notify_rescued_others(freed: Array, by_skill: bool) -> void:
	if passive:
		passive.on_rescue_performed(freed, by_skill)
	for s in skills:
		s.on_owner_event("rescue", freed)

# ---- state changes ---------------------------------------------------------------------
func set_state(new_state: int) -> void:
	if new_state == state:
		return
	var old := state
	state = new_state
	_update_collision()
	state_changed.emit(self, old, new_state)

## A tag landed and was not absorbed: freeze, then the JailSystem moves us to jail.
func on_tagged(tagger: Hero) -> void:
	for s in skills:
		if s.active:
			s.end("tagged")
	if capturing:
		host.base_system.cancel_capture(self, "tagged")
	windup_end_tick = -1
	_push_ticks = 0
	stun_ticks = 0
	stumble_ticks = 0
	ep_ticks = 0
	tagged_by = tagger
	tagged_ticks = RB.ticks(tuning.tagged_freeze)
	velocity = Vector3.ZERO
	set_state(State.TAGGED)

func on_jailed(at: Vector3) -> void:
	_mods.clear()
	_push_ticks = 0
	teleport(at)
	set_state(State.JAILED)
	if passive:
		passive.on_jailed()

func on_freed(rescuer: Hero, ep_secs: float, lockout_secs: float) -> void:
	tagged_by = null
	ep_ticks = RB.ticks(ep_secs)
	lockout_ticks = RB.ticks(lockout_secs)
	set_state(State.FREE)
	_update_collision()
	if passive:
		passive.on_freed(rescuer)

func teleport(at: Vector3) -> void:
	global_position = at
	if is_inside_tree():
		force_update_transform() # push to the physics server now (manual-step tests, same-tick rescues)
	velocity = Vector3.ZERO
	_push_ticks = 0

## Round reset (spec § 2 "Reset"): free, clear every effect and timer, cooldowns ready.
func reset_for_round(at: Vector3, face: Vector3) -> void:
	for s in skills:
		s.on_round_reset()
		s.active = false
		s.cd_ticks = 0
	if passive:
		passive.on_round_reset()
	_mods.clear()
	_push_ticks = 0
	tagged_ticks = 0
	ep_ticks = 0
	lockout_ticks = 0
	stumble_ticks = 0
	stun_ticks = 0
	tag_block_ticks = 0
	windup_end_tick = -1
	capturing = false
	capture_ticks = 0
	tagged_by = null
	enemy_alpha = 1.0
	revealed_ticks = [0, 0]
	wish_dir = Vector3.ZERO
	facing = RB.flat(face).normalized()
	aim = facing
	teleport(at)
	set_state(State.FREE)
	_update_collision()

func _update_collision() -> void:
	var solid := state == State.FREE and ep_ticks <= 0
	collision_layer = RB.L_HERO if solid else RB.L_GHOST
	collision_mask = RB.MASK_MOVE | (RB.L_HERO if solid else 0)

# ---- tick (called by MatchHost) ----------------------------------------------------------
## Step 1: take this tick's input; update aim.
func set_frame(f: InputFrame) -> void:
	frame = f
	var d := f.aim_direction(global_position)
	if d != Vector3.ZERO:
		aim = d
	var m := Vector3(f.move.x, 0.0, f.move.y)
	wish_dir = m.normalized() if m.length() > tuning.stick_dead_zone else Vector3.ZERO

## Step 3a: count every timer down once per tick.
func tick_timers() -> void:
	for s in skills:
		if s.cd_ticks > 0:
			s.cd_ticks -= 1
	if ep_ticks > 0:
		ep_ticks -= 1
		if ep_ticks == 0:
			_update_collision()
	lockout_ticks = maxi(0, lockout_ticks - 1)
	stumble_ticks = maxi(0, stumble_ticks - 1)
	stun_ticks = maxi(0, stun_ticks - 1)
	tag_block_ticks = maxi(0, tag_block_ticks - 1)
	for t in range(2):
		revealed_ticks[t] = maxi(0, revealed_ticks[t] - 1)
	for i in range(_mods.size() - 1, -1, -1):
		_mods[i].ticks -= 1
		if _mods[i].ticks <= 0:
			_mods.remove_at(i)

## Step 3b: move. Pushes beat everything; then a movement skill; then normal running.
func tick_move(dt: float) -> void:
	if frozen or state == State.TAGGED:
		velocity = Vector3(0, velocity.y, 0)
		move_body(dt)
		return
	if _push_ticks > 0:
		_push_ticks -= 1
		velocity = Vector3(_push_vel.x, velocity.y, _push_vel.z)
		move_body(dt)
		if _push_ticks == 0: # the push ends dead: no extra slide while decelerating
			velocity = Vector3(0, velocity.y, 0)
		return
	for s in skills:
		if s.active and s.controls_movement():
			s.move(dt)
			_update_facing()
			return
	if not can_move():
		velocity = Vector3(0, velocity.y, 0)
		move_body(dt)
		_update_facing()
		return
	var tilt := frame.move.length()
	var want := 0.0
	if tilt >= tuning.stick_dead_zone:
		var walking := frame.from_gamepad and tilt < tuning.stick_run_tilt
		want = current_speed(walking)
	var target := wish_dir * want
	var horiz := Vector3(velocity.x, 0, velocity.z)
	var rate := tuning.acceleration if target.length() >= horiz.length() else tuning.deceleration
	horiz = horiz.move_toward(target, rate * dt)
	velocity = Vector3(horiz.x, velocity.y, horiz.z)
	move_body(dt)
	_update_facing()

## Shared body mover: gravity + move_and_slide. Skills that drive movement set the
## horizontal velocity, then call this.
func move_body(dt: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= 24.0 * dt
	# move_and_slide() integrates with the engine's delta: the physics delta inside a physics
	# frame, but the (variable) process delta when a test steps the host by hand. Rescale so
	# the body always moves velocity * dt.
	var k := 1.0
	if not Engine.is_in_physics_frame():
		var ed := get_process_delta_time()
		if ed > 0.0:
			k = dt / ed
	if k != 1.0:
		velocity *= k
		move_and_slide()
		velocity /= k
	else:
		move_and_slide()

func ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func _update_facing() -> void:
	if is_winding_up() and lunge_dir != Vector3.ZERO:
		facing = lunge_dir
		return
	var v := Vector3(velocity.x, 0, velocity.z)
	if v.length() > 0.5:
		facing = v.normalized()
	elif frame.has_aim or frame.aim_dir.length() > 0.1:
		facing = aim

## Step 3c: skills and passive tick after movement.
func tick_abilities(dt: float) -> void:
	for s in skills:
		s.tick(dt)
	if passive:
		passive.tick(dt)

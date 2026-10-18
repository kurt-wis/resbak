extends Passive

## Tutoy passive DIRE-DIRETSO (docs/RESBAK.md § 4 Tutoy): while moving without a sharp turn
## (> 45 deg within 0.5 s) the speed bonus rises evenly from 0 to +15 % over 3 s, then holds.
## Resets on stop, sharp turn, Tag press, capture start, and push / slow / stun by an enemy
## skill (terrain and hazard slows pass by_enemy_skill = false and do not reset it).

const MOVE_MIN := 0.3 ## m/s of real ground speed that counts as moving

var _moving_ticks := 0
var _headings: Array[Vector3] = [] ## last 0.5 s of movement headings
var _dust: CPUParticles3D
var _was_full := false

func speed_bonus() -> float:
	return float(v("dire_max_bonus")) * _fraction()

func _fraction() -> float:
	var build := maxi(1, RB.ticks(float(v("dire_build_time"))))
	return clampf(float(_moving_ticks) / build, 0.0, 1.0)

func tick(_dt: float) -> void:
	if not _is_moving():
		_reset()
		return
	var heading := hero.wish_dir
	if heading == Vector3.ZERO:
		heading = RB.flat(hero.velocity).normalized() # a skill is steering (HARUROT!, LUSOT!)
	_headings.append(heading)
	var window := RB.ticks(float(v("dire_sharp_turn_window")))
	while _headings.size() > window + 1:
		_headings.pop_front()
	var limit := deg_to_rad(float(v("dire_sharp_turn_deg")))
	for old in _headings:
		if old.angle_to(heading) > limit:
			_reset()
			_headings = [heading]
			return
	_moving_ticks += 1
	_update_fx()

func _is_moving() -> bool:
	if not hero.is_free():
		return false
	var steering := _skill_steering()
	if not steering and not hero.can_move():
		return false
	if hero.ground_speed() < MOVE_MIN:
		return false
	return hero.wish_dir != Vector3.ZERO or steering

func _skill_steering() -> bool:
	for s in hero.skills:
		if s.active and s.controls_movement():
			return true
	return false

func _reset() -> void:
	if _moving_ticks > 0 and _fraction() >= 0.5 and host and hero.visual:
		Vfx.burst(host.world, hero.global_position + Vector3(0, 0.15, 0), Color(0.75, 0.75, 0.8, 0.7), 10, 1.6, 0.35, 0.14, -1.0, 80.0)
	_moving_ticks = 0
	_headings.clear()
	_was_full = false
	if _dust:
		_dust.emitting = false

func _update_fx() -> void:
	var f := _fraction()
	if _dust == null and f >= 0.4 and hero.visual and hero.visual.extras:
		_dust = Vfx.emitter(hero.visual.extras, Color(1.0, 0.85, 0.5, 0.7), 14, 0.4, 0.14, 0.8, Vector3(0, 0.12, 0))
	if _dust:
		_dust.emitting = f >= 0.4
	if f >= 1.0 and not _was_full:
		_was_full = true
		Vfx.ring_pulse(host.world, hero.global_position, 1.4, Color(1.0, 0.85, 0.5, 0.8), 0.3)

# ---- resets ----------------------------------------------------------------------------
func on_tag_pressed() -> void:
	_reset()

func on_capture_start() -> void:
	_reset()

func on_pushed(by_enemy_skill: bool) -> void:
	if by_enemy_skill:
		_reset()

func on_slowed(by_enemy_skill: bool) -> void:
	if by_enemy_skill:
		_reset()

func on_stunned(by_enemy_skill: bool) -> void:
	if by_enemy_skill:
		_reset()

func on_jailed() -> void:
	_reset()

func on_freed(_rescuer: Hero) -> void:
	_reset()

func on_round_reset() -> void:
	_reset()

func hud_state() -> Dictionary:
	var f := _fraction()
	return {"fill": f, "on": f > 0.0, "note": "+%d%%" % int(round(speed_bonus() * 100.0))}

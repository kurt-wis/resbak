extends Skill

## Tutoy S1 HARUROT! (docs/RESBAK.md § 4 Tutoy): 9 m/s for 1.2 s, no turn limit (the burst follows
## the move input instantly; with no input it keeps its last heading). Leaves a wind trail
## everyone can see, each part lasting 2 s (HarurotTrail). Tagging stays possible, being
## tagged ends it. Speed is fixed (no DIRE-DIRETSO bonus), slows still apply.

var _ticks_left := 0
var _age := 0
var _dir := Vector3.RIGHT
var _dust: CPUParticles3D

func kind() -> int:
	return RB.SkillKind.MOVEMENT

func is_traversal() -> bool:
	return true

func fixed_speed() -> float:
	return float(v("harurot_speed")) if active else -1.0

func controls_movement() -> bool:
	return active and not hero.is_disabled()

func _cast(_frame: InputFrame) -> void:
	_dir = _pick_dir()
	_ticks_left = RB.ticks(float(v("harurot_time")))
	_age = 0
	active = true
	hero.visual.play_action("Harurot", float(v("harurot_time")))
	var feet := hero.global_position
	Vfx.burst(host.world, feet + Vector3(0, 0.15, 0), Color(0.9, 0.97, 1.0, 0.9), 22, 3.5, 0.45, 0.22, -1.0, 70.0, -_dir + Vector3.UP * 0.3)
	# Narrow speed streaks read as forward acceleration rather than a radial attack.
	var side := _dir.cross(Vector3.UP)
	for i in range(5):
		var points := PackedVector3Array()
		for j in range(7):
			var progress := float(j) / 6.0
			points.append(-_dir * (0.2 + progress * 1.7) + side * (i - 2) * 0.18 + Vector3.UP * (0.12 + sin(progress * PI) * 0.18))
		var streak := Vfx.ribbon(points, 0.035, Color(0.28, 0.85, 1.0, 0.85))
		host.world.add_child(streak)
		streak.global_position = feet
		Vfx.fade_and_free(streak, 0.25)
	if _dust == null and hero.visual.extras:
		_dust = Vfx.emitter(hero.visual.extras, Color(0.9, 0.97, 1.0, 0.8), 36, 0.45, 0.22, 1.4, Vector3(0, 0.15, 0))
	if _dust:
		_dust.emitting = true

func tick_action(_frame: InputFrame) -> void:
	if hero.is_disabled(): # a stumble (failed tag mid-burst) or stun ends the burst
		end("stunned")

func move(dt: float) -> void:
	if hero.wish_dir != Vector3.ZERO:
		_dir = hero.wish_dir
	var spd := hero.current_speed()
	hero.velocity = Vector3(_dir.x * spd, hero.velocity.y, _dir.z * spd)
	hero.move_body(dt)

func tick(_dt: float) -> void:
	if not active:
		return
	var every := maxi(1, int(v("harurot_trail_every", 4)))
	if _age % every == 0:
		_drop_trail()
	_age += 1
	_ticks_left -= 1
	if _ticks_left <= 0:
		end("expired")

func _drop_trail() -> void:
	var part := HarurotTrail.new()
	part.setup(host, hero, float(v("harurot_trail_part_time")))
	host.spawn_object(part, hero.global_position - _dir * 0.2)
	part.build(_dir, float(v("harurot_trail_length", 0.8)), Color(0.28, 0.85, 1.0, 0.8))

func end(reason: String) -> void:
	if active:
		hero.visual.stop_action("Harurot")
	active = false
	_ticks_left = 0
	if _dust:
		_dust.emitting = false

func on_owner_event(event: String, _data: Variant) -> void:
	if active and event == "stunned":
		end("stunned")

func hud_note() -> String:
	return "%.1f s" % RB.seconds(_ticks_left) if active else ""

func _pick_dir() -> Vector3:
	if hero.wish_dir != Vector3.ZERO:
		return hero.wish_dir
	if hero.ground_speed() > 1.0:
		return RB.flat(hero.velocity).normalized()
	return RB.flat(hero.facing).normalized()

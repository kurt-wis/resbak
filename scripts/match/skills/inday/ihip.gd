extends Skill

## Inday S1 IHIP! (docs/RESBAK.md § 4 Inday). Inday stands still blowing along her aim for up
## to ihip_time seconds. The wind lane starts at her, is ihip_length long and ihip_width wide,
## turns with her aim and is cut by the first wall on its centre line. Free allies whose centre
## is inside get +ihip_bonus speed (source "ihip", refreshed every tick); enemies get nothing.
## She can aim but can't move, tag or cast her other skill, and stays taggable. It ends on S1
## again, when tagged, pushed or stunned; the lane (and every bonus it gave) is gone that tick.

const SOURCE := "ihip"
const CLIP := "Ihip"
const LANE_COLOR := Color(0.72, 0.95, 1.0, 0.2)
const STREAK_COLOR := Color(0.92, 1.0, 1.0, 0.85)

var _left := 0 ## ticks of blowing still to apply
var _dir := Vector3(0, 0, 1)
var _length := 0.0 ## current lane length after the wall cut (m)
var _boosted: Array[Hero] = [] ## allies given the bonus last tick
var _lane: Node3D
var _lane_mesh: MeshInstance3D
var _streaks: CPUParticles3D
var _streak_len := -1.0

func kind() -> int:
	return RB.SkillKind.MOVEMENT

func _cast(_frame: InputFrame) -> void:
	active = true
	_left = RB.ticks(v("ihip_time", 4.0))
	_dir = hero.aim
	_length = float(v("ihip_length", 10.0))
	hero.velocity = Vector3(0, hero.velocity.y, 0)
	hero.visual.play_action(CLIP, -1.0, true)
	_build_lane()

func on_recast(_frame: InputFrame) -> void:
	end("recast")

func controls_movement() -> bool:
	return active

## Stand still (pushes are handled by the Hero before this is reached).
func move(dt: float) -> void:
	hero.velocity = Vector3(0, hero.velocity.y, 0)
	hero.move_body(dt)

func blocks_tagging() -> bool:
	return true

func blocks_other_skills() -> bool:
	return true

func tick_action(_frame: InputFrame) -> void:
	if not active:
		return
	if hero.state != Hero.State.FREE or hero.is_disabled():
		end("stunned")
		return
	if _left <= 0:
		end("expired")
		return
	_left -= 1
	_dir = hero.aim
	_length = _cut_length()
	var secs := 2.0 / RB.TICK_RATE # alive through the next movement step, refreshed every tick
	var now: Array[Hero] = []
	for a in host.allies_of(hero):
		if a.is_free() and in_lane(a.global_position):
			a.add_speed_bonus(float(v("ihip_bonus", 0.25)), secs, SOURCE)
			now.append(a)
	for old in _boosted:
		if not now.has(old) and is_instance_valid(old):
			old.clear_modifier(SOURCE)
	_boosted = now
	_update_lane_visual()

func on_owner_event(event: String, _data: Variant) -> void:
	if active and (event == "pushed" or event == "stunned"):
		end(event)

func end(_reason: String) -> void:
	var was := active
	active = false
	_left = 0
	for a in _boosted:
		if is_instance_valid(a):
			a.clear_modifier(SOURCE)
	_boosted.clear()
	_free_lane()
	if was and hero and hero.visual:
		hero.visual.stop_action(CLIP)

func hud_note() -> String:
	return "%.1f s" % RB.seconds(_left) if active else ""

# ---- lane geometry (rules; presentation reads these too) ----------------------------------
func lane_active() -> bool:
	return active

func lane_dir() -> Vector3:
	return _dir

## Lane length in metres: ihip_length, shortened to the first wall on the centre line.
func lane_length() -> float:
	return _length if active else 0.0

func _cut_length() -> float:
	var full := float(v("ihip_length", 10.0))
	var a := hero.global_position
	var hit := host.ray_hit(a, a + _dir * full)
	if hit.is_empty():
		return full
	var p: Vector3 = hit.position
	return clampf(RB.flat_dist(a, p), 0.0, full)

## True when a world point (flat) lies inside the current lane.
func in_lane(p: Vector3) -> bool:
	if not active:
		return false
	var rel := RB.flat(p - hero.global_position)
	var along := rel.dot(_dir)
	var side := absf(rel.x * _dir.z - rel.z * _dir.x)
	return along >= 0.0 and along <= _length and side <= float(v("ihip_width", 3.0)) * 0.5

# ---- presentation ---------------------------------------------------------------------
func _build_lane() -> void:
	_free_lane()
	var full := float(v("ihip_length", 10.0))
	var width := float(v("ihip_width", 3.0))
	_lane = Node3D.new()
	_lane.name = "IhipLane"
	host.world.add_child(_lane)
	_lane_mesh = Vfx.lane_mesh(full, width, LANE_COLOR)
	_lane.add_child(_lane_mesh)
	_streaks = Vfx.emitter(_lane, STREAK_COLOR, 36, 0.5, 0.18, 10.0, Vector3(0, 0.6, 0.5), false)
	_streaks.direction = Vector3(0, 0, 1)
	_streaks.spread = 4.0
	_streaks.gravity = Vector3.ZERO
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_streaks.emission_box_extents = Vector3(width * 0.5, 0.35, 0.3)
	_streaks.emitting = true
	_streak_len = -1.0

func _update_lane_visual() -> void:
	if _lane == null:
		return
	_lane.global_position = hero.global_position + Vector3(0, 0.07, 0)
	_lane.rotation = Vector3(0, atan2(_dir.x, _dir.z), 0)
	_lane_mesh.scale = Vector3(1, 1, _length / maxf(float(v("ihip_length", 10.0)), 0.01))
	if absf(_length - _streak_len) > 0.05:
		_streak_len = _length
		_streaks.initial_velocity_min = _length / 0.5 * 0.8
		_streaks.initial_velocity_max = _length / 0.5

func _free_lane() -> void:
	if _lane != null and is_instance_valid(_lane):
		_lane.visible = false
		if _lane.get_parent():
			_lane.get_parent().remove_child(_lane)
		_lane.queue_free()
	_lane = null
	_lane_mesh = null
	_streaks = null

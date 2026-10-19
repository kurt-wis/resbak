extends Skill

## Approved placed wind lane. Its object outlives the cast and the owner's tag.
var last_lane: SkillObject

func kind() -> int:
	return RB.SkillKind.MOVEMENT

func cast_plant_seconds() -> float:
	return float(v("ihip_form_time"))

func _cast(frame: InputFrame) -> void:
	var direction := frame.aim_direction(hero.global_position)
	if direction == Vector3.ZERO:
		direction = hero.aim
	var lane := preload("res://scripts/match/skills/inday/ihip_lane.gd").new()
	lane.setup(host, hero, float(v("ihip_time")))
	lane.direction = direction.normalized()
	lane.length_m = float(v("ihip_length"))
	lane.width_m = float(v("ihip_width"))
	lane.bonus = float(v("ihip_bonus"))
	lane.slow = float(v("ihip_slow"))
	lane.form_ticks = RB.ticks(v("ihip_form_time"))
	var hit := host.ray_hit(hero.global_position, hero.global_position + lane.direction * lane.length_m)
	if not hit.is_empty():
		lane.length_m = clampf(RB.flat_dist(hero.global_position, hit.position), 0.0, lane.length_m)
	host.spawn_object(lane, hero.global_position)
	last_lane = lane
	hero.visual.play_action("Ihip", cast_plant_seconds())

func lane_active() -> bool:
	return is_instance_valid(last_lane) and not last_lane.expired

func lane_dir() -> Vector3:
	return last_lane.direction if lane_active() else Vector3.ZERO

func lane_length() -> float:
	return last_lane.length_m if lane_active() else 0.0

func in_lane(point: Vector3) -> bool:
	return lane_active() and last_lane.contains(point)

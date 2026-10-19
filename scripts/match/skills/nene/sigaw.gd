extends Skill

## SIGAW sends a fixed 60-degree sound fan out to its range. Each reachable hero is
## affected once: enemy stun, teammate dash. Walls occlude their part of the wave.

func kind() -> int:
	return RB.SkillKind.OFFENSIVE

func _cast(frame: InputFrame) -> void:
	var dir := frame.aim_direction(hero.global_position)
	if dir == Vector3.ZERO:
		dir = hero.aim
	dir = RB.flat(dir).normalized()
	if dir == Vector3.ZERO:
		dir = Vector3.RIGHT if hero.team == RB.DILAW else Vector3.LEFT
	var word := SigawWord.new()
	word.begin(host, hero, dir, {
		"speed": float(v("sigaw_speed")),
		"range": float(v("sigaw_range")),
		"angle": float(v("sigaw_width_deg")),
		"radius": float(v("sigaw_radius")),
		"stun": float(v("sigaw_stun")),
		"dash": float(v("sigaw_dash_distance")),
	})
	host.spawn_object(word, hero.global_position)
	var clip_time := minf(hero.visual.clip_length("Sumbong"), 0.6) if hero.visual else 0.0
	if clip_time > 0.0:
		hero.visual.play_action("Sumbong", clip_time)
	host.emit_event("sigaw", {"hero": hero, "dir": dir, "object": word})

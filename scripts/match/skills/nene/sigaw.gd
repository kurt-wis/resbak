extends Skill

## Nene S1 SIGAW! (v0.2, replaces IYAK!; docs/status.md). She shouts a word ("SIGAW!") that
## flies straight along her aim (SigawWord). The first Free hero it meets decides what it does:
## an enemy is stunned for sigaw_stun seconds; a teammate gets a short dash (a quick push of
## sigaw_dash_distance metres the way they are moving, else the way the word flew). Walls stop
## it. Type: Offensive.

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
		"radius": float(v("sigaw_radius")),
		"stun": float(v("sigaw_stun")),
		"dash": float(v("sigaw_dash_distance")),
	})
	host.spawn_object(word, hero.global_position + dir * host.tuning.body_radius)
	Vfx.sound_shell(host.world, hero.global_position + Vector3.UP, dir, Color("ff83ba"), 0.7)
	var clip_time := minf(hero.visual.clip_length("Sumbong"), 0.6) if hero.visual else 0.0
	if clip_time > 0.0:
		hero.visual.play_action("Sumbong", clip_time)
	host.emit_event("sigaw", {"hero": hero, "dir": dir, "object": word})

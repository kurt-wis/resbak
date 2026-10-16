extends Skill

## Nene S2 SUMBONG KITA! (docs/RESBAK.md § 4 Nene). Fakes an alert at an aimed point up to
## 12 m away: a footstep icon and a running sound for her enemies for 3 s (FakeAlert; host
## event "fake_alert" {point, team, seconds}). It never scores and is never announced.
## If the point is within 8 m of the jail holding her teammates, a fake Nene rescuer
## (NeneFakeRescuer) runs from the point toward the chain tip instead (event "fake_rescuer").
## "Within 8 m of the jail" is measured to the jail's floor rectangle (0 inside it).
## A jail "holds her teammates" while any of her teammates is Jailed or Chained there.
## Type: Neither. Plays the Sumbong clip when the model has it.

func kind() -> int:
	return RB.SkillKind.NEITHER

## The aimed point, clamped to the cast range (aim past range = max range).
func target_point(frame: InputFrame) -> Vector3:
	var reach: float = v("sumbong_range")
	var from := hero.global_position
	var d := frame.aim_distance(from)
	var dir := frame.aim_direction(from)
	if dir == Vector3.ZERO:
		dir = hero.aim
	if d < 0.0:
		d = reach
	var p := from + dir * minf(d, reach)
	p.y = from.y
	return p

## True when a jail holding Nene's teammates is within `sumbong_jail_radius` of the point.
func jail_holds_team_near(point: Vector3) -> bool:
	var jail_owner := RB.other_team(hero.team)
	if host.jail_system.prisoners(jail_owner).is_empty():
		return false
	var r: Rect2 = host.layout.jail_rect(jail_owner)
	var nearest := Vector2(clampf(point.x, r.position.x, r.end.x), clampf(point.z, r.position.y, r.end.y))
	return Vector2(point.x, point.z).distance_to(nearest) <= float(v("sumbong_jail_radius"))

func _cast(frame: InputFrame) -> void:
	var point := target_point(frame)
	var clip_time := minf(hero.visual.clip_length("Sumbong"), 0.8)
	hero.visual.play_action("Sumbong", clip_time if clip_time > 0.0 else -1.0)
	if jail_holds_team_near(point):
		var fake := NeneFakeRescuer.new()
		fake.setup(host, hero, v("sumbong_fake_time"))
		host.spawn_object(fake, point)
		host.emit_event("fake_rescuer", {"hero": hero, "point": point, "team": hero.team, "seconds": float(v("sumbong_fake_time")), "object": fake})
		return
	var secs: float = v("sumbong_alert_time")
	var alert := FakeAlert.new()
	alert.setup(host, hero, secs)
	host.spawn_object(alert, point)
	host.emit_event("fake_alert", {"hero": hero, "point": point, "team": hero.team, "seconds": secs, "object": alert})

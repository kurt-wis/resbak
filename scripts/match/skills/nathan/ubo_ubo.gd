extends Skill

## Nathan S2 UBO! UBO! (docs/RESBAK.md § 4 Nathan). Offensive.
## Lob a Kimkim packet up to 9 m along his aim (aim past range = max range). It lands 0.5 s
## later, or sooner at the first wall in its path, and bursts into a UboCloud (r 3.5 m, 5 s).
## Instant skill: it never becomes `active`, and the packet and cloud last their full time
## even if Nathan is tagged.

func kind() -> int:
	return RB.SkillKind.OFFENSIVE

func _cast(frame: InputFrame) -> void:
	var origin := hero.global_position
	var dir := RB.flat(hero.aim).normalized()
	if dir == Vector3.ZERO:
		dir = RB.flat(hero.facing).normalized()
	var max_range: float = v("ubo_range")
	var want := frame.aim_distance(origin)
	var dist := max_range if want < 0.0 else minf(want, max_range)
	var land_d := dist
	var wall := host.ray_hit(origin, origin + dir * dist)
	if not wall.is_empty():
		land_d = maxf(0.0, minf(dist, RB.flat_dist(origin, wall.position) - 0.3))
	var ratio := 1.0 if dist < 0.01 else land_d / dist
	var flight := maxi(1, int(round(RB.ticks(float(v("ubo_flight_time"))) * ratio)))
	var land := origin + dir * land_d
	var cfg := {
		"radius": float(v("ubo_radius")),
		"time": float(v("ubo_cloud_time")),
		"sight": float(v("ubo_inside_sight")),
		"cough_after": float(v("ubo_cough_after")),
		"cough_reveal": float(v("ubo_cough_reveal")),
	}
	if hero.aim != Vector3.ZERO:
		hero.facing = hero.aim
	hero.visual.play_action("Ubo", 0.6)
	var packet := UboPacket.new()
	var from := origin + Vector3(0, 1.3, 0)
	packet.begin(host, hero, from, Vector3(land.x, origin.y + 0.2, land.z), flight, cfg)
	host.spawn_object(packet, from)
	host.emit_event("ubo_throw", {"hero": hero, "from": origin, "to": land, "flight_ticks": flight, "packet": packet})

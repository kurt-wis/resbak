class_name SigawWord
extends SkillObject

## The shouted word in flight (SIGAW!, Nene S1). Moves straight at a fixed speed in step 3;
## the first Free hero within `radius` of its path (edge to edge) is hit: an enemy is stunned,
## a teammate dashes. Stops at walls (world and TALBOG! walls) and after `range` metres.

var dir := Vector3.RIGHT
var cfg := {}
var travelled := 0.0
var label: Label3D
var waves: Array[Node3D] = []

func begin(p_host: MatchHost, p_owner: Hero, p_dir: Vector3, p_cfg: Dictionary) -> void:
	setup(p_host, p_owner, -1.0)
	name = "SigawWord"
	dir = p_dir
	cfg = p_cfg
	for i in range(3):
		var wave := Vfx.ground_ring(self, Vector3.ZERO, 0.35 + float(i) * 0.18, Color(1.0, 0.35 + i * 0.15, 0.65, 0.65), 0.04)
		wave.rotation = Vector3(PI * 0.5, atan2(dir.x, dir.z), 0)
		wave.position = Vector3.UP * 1.1 - dir * i * 0.2
		waves.append(wave)

func tick(dt: float) -> void:
	if expired:
		return
	var step := float(cfg.speed) * dt
	var from := global_position
	var to := from + dir * step
	var wall := host.ray_hit(from, to, RB.L_WORLD | RB.L_SKILL_WALL)
	if not wall.is_empty():
		to = RB.flat(wall.position) + Vector3(0, from.y, 0)
	var hit := _first_hero(from, to)
	if hit:
		_hit(hit)
		return
	global_position = to
	travelled += from.distance_to(to)
	if label:
		label.scale = Vector3.ONE * (1.0 + 0.15 * sin(travelled * 3.0))
	for i in range(waves.size()):
		waves[i].scale = Vector3.ONE * (1.0 + 0.15 * sin(travelled * 2.0 - i))
	if not wall.is_empty() or travelled >= float(cfg.range):
		host.emit_event("sigaw_fizzle", {"hero": owner_hero, "pos": global_position})
		expire()

## The Free hero nearest the start whose body the segment from..to passes within radius of.
func _first_hero(from: Vector3, to: Vector3) -> Hero:
	var best: Hero = null
	var best_k := INF
	var reach := float(cfg.radius) + host.tuning.body_radius
	var seg := RB.flat(to - from)
	var l2 := seg.length_squared()
	for h in host.heroes:
		if h == owner_hero or h.state != Hero.State.FREE:
			continue
		if absf(h.global_position.y - from.y) > host.tuning.height_gap:
			continue
		var rel := RB.flat(h.global_position - from)
		var k := 0.0 if l2 < 0.000001 else clampf(rel.dot(seg) / l2, 0.0, 1.0)
		if rel.distance_to(seg * k) <= reach and k < best_k:
			best_k = k
			best = h
	return best

func _hit(h: Hero) -> void:
	global_position = Vector3(h.global_position.x, global_position.y, h.global_position.z)
	Vfx.sound_shell(host.world, h.global_position + Vector3.UP, dir, Color("ff83ba") if h.team != team else Color("7fe8ff"), 1.4)
	Vfx.burst(host.world, h.global_position + Vector3.UP, Color("ffb4dc") if h.team != team else Color("8af6ff"), 18, 2.5, 0.3, 0.08, 0.0)
	if h.team != team:
		h.stun(float(cfg.stun), true)
		host.emit_event("sigaw_hit", {"hero": owner_hero, "target": h, "enemy": true})
	else:
		var d := RB.flat(h.wish_dir)
		if d.length() < 0.1:
			d = dir
		h.apply_push(d.normalized(), float(cfg.dash), false)
		host.emit_event("sigaw_hit", {"hero": owner_hero, "target": h, "enemy": false})
	expire()

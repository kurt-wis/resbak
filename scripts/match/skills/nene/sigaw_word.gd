class_name SigawWord
extends SkillObject

## Fixed 60-degree sound fan, `range` metres deep. The area never grows past that: a visible
## front sweeps outward inside it, every hero it reaches is affected once (enemy stun, teammate
## dash) and walls occlude the individual rays, so one wall never kills the clear side.
var dir := Vector3.RIGHT
var cfg := {}
var travelled := 0.0
var hit_slots := {}
var front: MeshInstance3D
var _fan: Array[Node3D] = []
var _fan_built := false

func begin(p_host: MatchHost, p_owner: Hero, p_dir: Vector3, p_cfg: Dictionary) -> void:
	setup(p_host, p_owner, -1.0)
	name = "SigawWord"
	dir = p_dir
	cfg = p_cfg
	front = MeshInstance3D.new()
	front.material_override = Vfx.flat_material(Color("ff83ba"))
	front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(front)

func tick(dt: float) -> void:
	if expired:
		return
	if not _fan_built:
		_fan_built = true
		_build_fan()
	var previous := travelled
	travelled = minf(float(cfg.range), travelled + float(cfg.speed) * dt)
	for h in host.heroes:
		if h == owner_hero or not h.is_free() or hit_slots.has(h.slot):
			continue
		if absf(h.global_position.y - global_position.y) > host.tuning.height_gap:
			continue
		var delta := RB.flat(h.global_position - global_position)
		var distance := delta.length()
		var padding := float(cfg.radius) + host.tuning.body_radius
		if distance > float(cfg.range) or distance + padding < previous or distance - padding > travelled:
			continue
		if distance > 0.001 and rad_to_deg(dir.angle_to(delta.normalized())) > float(cfg.angle) * 0.5:
			continue
		if not host.los_clear(global_position, h.global_position):
			continue
		hit_slots[h.slot] = true
		_hit(h)
	if DisplayServer.get_name() != "headless":
		_draw_front()
	if travelled >= float(cfg.range):
		host.emit_event("sigaw_fizzle", {"hero": owner_hero, "pos": global_position + dir * travelled})
		expire()

## The fixed area the fan will cover, drawn once: faint fill, ink edge, bright edge.
func _build_fan() -> void:
	var half := deg_to_rad(float(cfg.angle)) * 0.5
	var length := float(cfg.range)
	var segments := 24
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := PackedVector3Array()
	for i in range(segments + 1):
		var ray := dir.rotated(Vector3.UP, -half + 2.0 * half * i / segments)
		var hit := host.ray_hit(global_position, global_position + ray * length, RB.L_WORLD | RB.L_SKILL_WALL)
		var distance := length if hit.is_empty() else minf(length, RB.flat_dist(global_position, hit.position))
		var end := ray * distance
		rim.append(end)
		if i > 0:
			for vertex in [Vector3.ZERO, rim[i - 1], end]:
				surface.add_vertex(vertex + Vector3.UP * 0.03)
	var fill := MeshInstance3D.new()
	fill.mesh = surface.commit()
	fill.material_override = Vfx.flat_material(Color(Color("ff83ba"), 0.14))
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fill)
	_fan.append(fill)
	for stroke in [{"width": 0.16, "color": Color(0.05, 0.07, 0.1, 0.5), "lift": 0.05}, {"width": 0.07, "color": Color("ff9dc8"), "lift": 0.07}]:
		var ink := Vfx.ribbon(_lifted(rim, float(stroke.lift)), float(stroke.width), stroke.color)
		add_child(ink)
		_fan.append(ink)
		for side in [0, segments]:
			var edge := Vfx.ribbon(PackedVector3Array([Vector3.UP * float(stroke.lift), rim[side] + Vector3.UP * float(stroke.lift)]), float(stroke.width), stroke.color)
			add_child(edge)
			_fan.append(edge)

func _lifted(points: PackedVector3Array, lift: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for point in points:
		out.append(point + Vector3.UP * lift)
	return out

## The fixed area fades while the front is still travelling, so the fan never looks like it grows.
func _fade_fan() -> void:
	for node in _fan:
		if is_instance_valid(node):
			Vfx.fade_and_free(node, 0.18)
	_fan.clear()

func _draw_front() -> void:
	var half := deg_to_rad(float(cfg.angle)) * 0.5
	var segments := 24
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var ends: Array[Vector3] = []
		for j in [i, i + 1]:
			var direction := dir.rotated(Vector3.UP, -half + 2.0 * half * j / segments)
			var wall := host.ray_hit(global_position, global_position + direction * travelled, RB.L_WORLD | RB.L_SKILL_WALL)
			var distance := travelled if wall.is_empty() else minf(travelled, RB.flat_dist(global_position, wall.position))
			ends.append(direction * distance)
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		# One crisp ribbon plus a bright ground arc: the front reads flat from the match camera.
		for vertex in [a + Vector3.UP * 0.35, b + Vector3.UP * 0.35, a + Vector3.UP * 0.62, b + Vector3.UP * 0.35, b + Vector3.UP * 0.62, a + Vector3.UP * 0.62]:
			surface.add_vertex(vertex)
		var inner_a := a * (1.0 - minf(0.22, travelled * 0.5) / maxf(travelled, 0.001))
		var inner_b := b * (1.0 - minf(0.22, travelled * 0.5) / maxf(travelled, 0.001))
		for vertex in [a + Vector3.UP * 0.06, b + Vector3.UP * 0.06, inner_a + Vector3.UP * 0.06, b + Vector3.UP * 0.06, inner_b + Vector3.UP * 0.06, inner_a + Vector3.UP * 0.06]:
			surface.add_vertex(vertex)
	front.mesh = surface.commit()

func _hit(h: Hero) -> void:
	Vfx.ring_pulse(host.world, h.global_position, 1.2, Color("ff83ba") if h.team != team else Color("7fe8ff"), 0.35)
	Vfx.burst(host.world, h.global_position + Vector3.UP, Color("ffb4dc") if h.team != team else Color("8af6ff"), 18, 2.5, 0.3, 0.08, 0.0)
	if h.team != team:
		h.stun(float(cfg.stun), true)
		host.emit_event("sigaw_hit", {"hero": owner_hero, "target": h, "enemy": true})
	else:
		var direction := RB.flat(h.wish_dir)
		if direction.length() < 0.1:
			direction = dir
		h.apply_push(direction.normalized(), float(cfg.dash), false)
		host.emit_event("sigaw_hit", {"hero": owner_hero, "target": h, "enemy": false})

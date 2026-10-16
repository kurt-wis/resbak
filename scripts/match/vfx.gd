class_name Vfx
extends RefCounted

## Small presentation helpers shared by every skill and by match feedback, so effects look
## consistent and stay cheap on GL Compatibility (CPUParticles3D, unshaded meshes, tweens).
## Everything here is presentation only: never read it back for rules.

static func flat_material(color: Color, unshaded := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## One-shot particle burst at `pos` (world). Frees itself.
static func burst(parent: Node, pos: Vector3, color: Color, amount := 24, speed := 3.0, life := 0.6, size := 0.15, gravity := -4.0, spread := 180.0, dir := Vector3.UP) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.9
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := flat_material(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = m
	p.mesh = quad
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

## Continuous emitter attached to `parent` (local position `offset`). Caller toggles `emitting`.
static func emitter(parent: Node3D, color: Color, amount := 32, life := 0.8, size := 0.14, speed := 1.0, offset := Vector3.ZERO, world_space := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = not world_space
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	var m := flat_material(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = m
	p.mesh = quad
	p.position = offset
	p.emitting = false
	parent.add_child(p)
	return p

## Flat ring (or disc when inner == 0) lying on the ground. Returned node is yours to free.
static func ground_ring(parent: Node, pos: Vector3, radius: float, color: Color, width := 0.12, filled_alpha := 0.0) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos + Vector3(0, 0.06, 0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - width * 0.5, 0.01)
	torus.outer_radius = radius + width * 0.5
	torus.rings = 48
	torus.ring_segments = 4
	ring.mesh = torus
	ring.scale = Vector3(1, 0.04, 1)
	ring.material_override = flat_material(color)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	if filled_alpha > 0.0:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = 0.01
		cyl.radial_segments = 48
		disc.mesh = cyl
		disc.material_override = flat_material(Color(color.r, color.g, color.b, filled_alpha))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(disc)
	return root

## Expanding ring that fades out (impacts, shockwaves). Frees itself.
static func ring_pulse(parent: Node, pos: Vector3, radius: float, color: Color, time := 0.45) -> void:
	var r := ground_ring(parent, pos, 1.0, color, 0.15)
	r.scale = Vector3(0.2, 1, 0.2) * radius
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "scale", Vector3(radius, 1, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	for c in r.get_children():
		var m := (c as MeshInstance3D).material_override as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(r.queue_free)

## Flat fan (cone seen from above) of `length` and full angle `angle_deg`, pointing +Z.
## Rotate the returned node to aim it. Used for BUGA! and aim previews.
static func fan_mesh(length: float, angle_deg: float, color: Color, segments := 16) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(angle_deg) * 0.5
	for i in range(segments):
		var a0 := -half + 2.0 * half * i / segments
		var a1 := -half + 2.0 * half * (i + 1) / segments
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a1), 0, cos(a1)) * length)
		st.add_vertex(Vector3(sin(a0), 0, cos(a0)) * length)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = flat_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Flat rectangle from the origin along +Z (`length` x `width`). Used for IHIP! lanes.
static func lane_mesh(length: float, width: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(width, length)
	pm.center_offset = Vector3(0, 0, length * 0.5)
	mi.mesh = pm
	mi.material_override = flat_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Floating word (HULI!, PERFECT!, LUSOT!): rises and fades. Frees itself.
static func popup_text(parent: Node, pos: Vector3, text: String, color: Color, size := 110, time := 0.9) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 22
	l.modulate = color
	l.outline_modulate = Color("1a1020")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	parent.add_child(l)
	l.global_position = pos + Vector3(0, 2.3, 0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 0.9, time).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, time).set_delay(time * 0.5)
	tw.tween_property(l, "outline_modulate:a", 0.0, time).set_delay(time * 0.5)
	tw.chain().tween_callback(l.queue_free)

## Fade a node's StandardMaterial3D overrides out, then free it.
static func fade_and_free(node: Node3D, time := 0.3) -> void:
	var tw := node.create_tween().set_parallel(true)
	for mi in node.find_children("*", "MeshInstance3D", true, true) + ([node] if node is MeshInstance3D else []):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(node.queue_free)

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

static var _soft: Texture2D
static var _paper: Texture2D

## A soft round sprite (white, alpha falling off to the edge). Every particle uses it, so
## puffs, dust and wind read as soft blobs instead of square quads (v0.1.1: "blocky effects").
static func soft_texture() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.8))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft

## A small paper chip with rounded corners and a fold shade (KABOOM! confetti).
static func paper_texture() -> Texture2D:
	if _paper == null:
		var n := 32
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in range(n):
			for x in range(n):
				var u := (x + 0.5) / n * 2.0 - 1.0
				var v := (y + 0.5) / n * 2.0 - 1.0
				var d := Vector2(maxf(absf(u) - 0.6, 0.0), maxf(absf(v) - 0.6, 0.0)).length()
				if d > 0.4:
					continue
				var a := clampf((0.4 - d) * 12.0, 0.0, 1.0)
				var shade := 0.82 + 0.18 * (0.5 + 0.5 * u)
				img.set_pixel(x, y, Color(shade, shade, shade, a))
		_paper = ImageTexture.create_from_image(img)
	return _paper

## Unshaded, vertex-coloured, billboarded material with the soft sprite.
static func particle_material(tex: Texture2D = null) -> StandardMaterial3D:
	var m := flat_material(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true # without this every particle drew 1 m wide: the old 'blocky' look
	m.albedo_texture = tex if tex else soft_texture()
	return m

## KABOOM! confetti: small paper chips that tumble and flutter down. Frees itself.
static func confetti(parent: Node, pos: Vector3, colors: Array, amount := 90) -> void:
	for col in colors:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.amount = maxi(8, amount / colors.size())
		p.lifetime = 2.2
		p.explosiveness = 0.95
		p.direction = Vector3.UP
		p.spread = 70.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 8.5
		p.gravity = Vector3(0, -6.0, 0)
		p.damping_min = 2.0
		p.damping_max = 3.5
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = -540.0
		p.angular_velocity_max = 540.0
		p.scale_amount_min = 0.07
		p.scale_amount_max = 0.12
		var ramp := Gradient.new()
		ramp.set_color(0, col)
		ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
		ramp.add_point(0.8, col)
		p.color_ramp = ramp
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 0.6)
		quad.material = particle_material(paper_texture())
		p.mesh = quad
		parent.add_child(p)
		p.global_position = pos
		p.emitting = true
		p.finished.connect(p.queue_free)

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
	quad.size = Vector2.ONE * 1.6 # the soft sprite fades at its edge: draw it a bit larger
	quad.material = particle_material()
	p.mesh = quad
	p.scale_amount_curve = _puff_curve()
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
	quad.size = Vector2.ONE * 1.6 # the soft sprite fades at its edge: draw it a bit larger
	quad.material = particle_material()
	p.mesh = quad
	p.scale_amount_curve = _puff_curve()
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

## Only the curved outer edge: no filled wedge or radial sides. Presentation, never a hitbox.
static func tag_arc(length: float, angle_deg: float, color: Color, width := 0.025, segments := 40) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(angle_deg) * 0.5
	for i in range(segments):
		var a0 := -half + 2.0 * half * i / segments
		var a1 := -half + 2.0 * half * (i + 1) / segments
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		for v in [d0 * length, d1 * length, d0 * (length - width), d1 * length, d1 * (length - width), d0 * (length - width)]:
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = flat_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Thin inset border around the exact fan area, with radial sides; presentation only.
static func fan_border(length: float, angle_deg: float, color: Color, width := 0.035, segments := 32) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(angle_deg) * 0.5
	for i in range(segments):
		var a0 := -half + 2.0 * half * i / segments
		var a1 := -half + 2.0 * half * (i + 1) / segments
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		var vertices := [d0 * length, d1 * length, d0 * (length - width),
				d1 * length, d1 * (length - width), d0 * (length - width)]
		for v in vertices:
			st.add_vertex(v)
	for side in [-1.0, 1.0]:
		var dir := Vector3(sin(half * side), 0, cos(half * side))
		var inset: Vector3 = Vector3(-dir.z, 0, dir.x) * float(side) * width
		for v in [Vector3.ZERO, dir * length, dir * length + inset, Vector3.ZERO, dir * length + inset, inset]:
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = flat_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Flat arrow on the floor pointing +Z: a shaft from z = `start` to the head, whose tip is at
## `length`. Used for the tag aim arrow (the charge adds reach, so the mesh is rebuilt as it grows).
static func arrow_array_mesh(length: float, width: float, head_len: float, head_width: float, start := 0.0) -> ArrayMesh:
	var head := minf(head_len, maxf(0.0, length - start))
	var neck := length - head
	var hw := width * 0.5
	var hh := head_width * 0.5
	var v := PackedVector3Array([
		Vector3(-hw, 0, start), Vector3(hw, 0, start), Vector3(hw, 0, neck),
		Vector3(-hw, 0, start), Vector3(hw, 0, neck), Vector3(-hw, 0, neck),
		Vector3(-hh, 0, neck), Vector3(hh, 0, neck), Vector3(0, 0, length)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var normals := PackedVector3Array()
	for i in range(v.size()):
		normals.append(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func arrow_mesh(length: float, width: float, head_len: float, head_width: float, color: Color, start := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = arrow_array_mesh(length, width, head_len, head_width, start)
	mi.material_override = flat_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## The two meshes of the aim arrow, as [fill, outline]: the outline is a wider, slightly longer
## copy of the fill, so a dark edge surrounds the bright core on any floor (the plain arrow used
## to vanish into the orange Konstruksyon ground).
static func aim_arrow_meshes(length: float, width: float, head_len: float, head_width: float,
		start := 0.0, outset := 1.4, edge := 0.05) -> Array:
	return [arrow_array_mesh(length, width, head_len, head_width, start),
			arrow_array_mesh(length + edge, width * outset, head_len, head_width * outset,
					maxf(0.0, start - edge * 0.5))]

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

static var _curve: Curve

## Particles swell in quickly and shrink away at the end of their life.
static func _puff_curve() -> Curve:
	if _curve == null:
		_curve = Curve.new()
		_curve.add_point(Vector2(0.0, 0.35))
		_curve.add_point(Vector2(0.2, 1.0))
		_curve.add_point(Vector2(1.0, 0.55))
	return _curve
## Filled narrow straight guide. Hit-testing stays in TagSystem, never in this mesh.
static func tag_strip(length: float, half_width: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-half_width, 0, 0), Vector3(half_width, 0, 0), Vector3(-half_width, 0, length), Vector3(half_width, 0, 0), Vector3(half_width, 0, length), Vector3(-half_width, 0, length)]:
		st.add_vertex(v)
	var result := MeshInstance3D.new()
	result.mesh = st.commit()
	result.material_override = flat_material(color)
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result

## Border around a straight attack strip, with no opaque fill underneath.
static func tag_strip_border(length: float, half_width: float, width: float, color: Color) -> MeshInstance3D:
	var outer := [Vector3(-half_width, 0, 0), Vector3(half_width, 0, 0), Vector3(half_width, 0, length), Vector3(-half_width, 0, length)]
	var inner := [Vector3(-half_width + width, 0, width), Vector3(half_width - width, 0, width), Vector3(half_width - width, 0, length - width), Vector3(-half_width + width, 0, length - width)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var j := (i + 1) % 4
		for vertex in [outer[i], outer[j], inner[i], outer[j], inner[j], inner[i]]:
			st.add_vertex(vertex)
	var result := MeshInstance3D.new()
	result.mesh = st.commit()
	result.material_override = flat_material(color)
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result

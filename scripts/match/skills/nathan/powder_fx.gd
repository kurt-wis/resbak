class_name PowderFx
extends RefCounted

## Kimkim powder look shared by Nathan's skills (BUGA! cone and trail, UBO! UBO! packet and
## cloud, MAY TIRA PA! patch): pink and white puffs, cheap CPUParticles3D, unshaded.
## Presentation only; nothing here is read back by the rules.

const PINK := Color(1.0, 0.52, 0.76, 0.9)
const PINK_SOFT := Color(1.0, 0.78, 0.9, 0.8)
const WHITE := Color(1.0, 0.96, 1.0, 0.85)

static func _puff_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := Vfx.flat_material(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = m
	return quad

## Alpha envelope: fade in, hold, fade out.
static func _envelope(color: Color, peak_alpha: float) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.0),
		Color(color.r, color.g, color.b, peak_alpha),
		Color(color.r, color.g, color.b, 0.0)])
	return g

## Soft drifting puffs filling a sphere (the UBO! UBO! cloud body). Caller toggles `emitting`.
static func volume_emitter(parent: Node3D, radius: float, color: Color, amount: int, life: float, size: float, peak_alpha := 0.32, offset := Vector3(0, 0.9, 0)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.35
	p.gravity = Vector3.ZERO
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.2
	p.color_ramp = _envelope(color, peak_alpha)
	p.mesh = _puff_mesh()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = offset
	parent.add_child(p)
	p.emitting = true
	return p

## The BUGA! blast: a quick pink and white burst along `dir`, plus a fan that flashes and fades.
static func blow_cone(parent: Node3D, origin: Vector3, dir: Vector3, length: float, width_deg: float) -> void:
	var at := origin + Vector3(0, 1.15, 0) + dir * 0.4
	Vfx.burst(parent, at, PINK, 70, length * 1.25, 0.8, 0.55, 0.3, width_deg * 0.5, dir)
	Vfx.burst(parent, at, WHITE, 40, length * 1.1, 0.7, 0.35, 0.2, width_deg * 0.4, dir)
	var fan := Vfx.fan_mesh(length, width_deg, Color(PINK.r, PINK.g, PINK.b, 0.35))
	parent.add_child(fan)
	fan.global_position = origin + Vector3(0, 0.07, 0)
	fan.rotation.y = atan2(dir.x, dir.z)
	Vfx.fade_and_free(fan, 0.45)

## A ring that shrinks onto `hero_pos` (the BUGA! inhale). Frees itself.
static func inhale_ring(parent: Node3D, hero_pos: Vector3, radius: float, time: float) -> void:
	var r := Vfx.ground_ring(parent, hero_pos, 1.0, PINK_SOFT, 0.1)
	r.scale = Vector3(radius, 1, radius)
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "scale", Vector3(0.25, 1, 0.25), time).set_ease(Tween.EASE_IN)
	for c in r.get_children():
		var m := (c as MeshInstance3D).material_override as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(r.queue_free)

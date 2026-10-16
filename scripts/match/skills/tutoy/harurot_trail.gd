class_name HarurotTrail
extends SkillObject

## One part of HARUROT!'s wind trail (docs/RESBAK.md § 4 Tutoy): a flat streak on the ground
## plus an upright wisp, visible to every team, lasting `ticks_left` (2 s) and then fading.
## Rules never read it; the fade is presentation only (_process reads ticks_left).

const COLOR := Color(0.86, 0.96, 1.0)

var total_ticks := 120
var length := 0.8
var _mats: Array[StandardMaterial3D] = []

## dir = running direction (flat). Call after setup() and spawn_object().
func build(dir: Vector3, p_length: float, tint: Color) -> void:
	length = p_length
	total_ticks = maxi(ticks_left, 1)
	rotation.y = atan2(dir.x, dir.z)
	var col := COLOR.lerp(tint, 0.18)
	var flat := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.55, length)
	flat.mesh = q
	flat.rotation.x = -PI * 0.5
	flat.position.y = 0.07
	flat.material_override = _mat(col, 0.55)
	flat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flat)
	var wisp := MeshInstance3D.new()
	var w := QuadMesh.new()
	w.size = Vector2(length, 0.55)
	wisp.mesh = w
	wisp.rotation.y = PI * 0.5 # quad lies along the running direction, standing up
	wisp.position.y = 0.4
	wisp.material_override = _mat(col, 0.35)
	wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wisp)

func _mat(col: Color, alpha: float) -> StandardMaterial3D:
	var m := Vfx.flat_material(Color(col.r, col.g, col.b, alpha))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.set_meta("base_alpha", alpha)
	_mats.append(m)
	return m

func _process(_delta: float) -> void:
	if total_ticks <= 0:
		return
	var k := clampf(float(ticks_left) / total_ticks, 0.0, 1.0)
	var fade := minf(k * 2.5, 1.0) # solid for most of its life, fades over the last 40 %
	for m in _mats:
		var c := m.albedo_color
		c.a = float(m.get_meta("base_alpha")) * fade
		m.albedo_color = c

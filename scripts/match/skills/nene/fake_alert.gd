class_name FakeAlert
extends SkillObject

## SUMBONG KITA! fake alert (docs/RESBAK.md § 4 Nene S2): a footstep icon and a running sound
## at a point for 3 s, for Nene's enemies only. It fakes an attacker or a rescuer and nothing
## else: no rule reads it, it never scores and the announcer never mentions it. The match view
## and HUD respect `visible_to_team`; this object also hides itself from the local viewer's
## team when a MatchView exists (headless and tests: always "visible", no sound).

var visible_to_team := -1 ## the only team that sees and hears it (-1 = everyone)
var _view: MatchView
var _scan_in := 0
var _sound_in := 0.0

func setup(p_host: MatchHost, p_owner: Hero, seconds: float = -1.0) -> void:
	super.setup(p_host, p_owner, seconds)
	visible_to_team = RB.other_team(p_owner.team)
	name = "FakeAlert"

func _ready() -> void:
	var col := Color(1.0, 0.78, 0.25, 0.9)
	var ring := Vfx.ground_ring(self, Vector3.ZERO, 1.2, col, 0.12)
	ring.position = Vector3(0, 0.06, 0)
	var mat := Vfx.flat_material(col)
	for side in [-1.0, 1.0]:
		var print_mesh := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		print_mesh.mesh = s
		print_mesh.scale = Vector3(0.14, 0.03, 0.3)
		print_mesh.position = Vector3(0.22 * side, 0.08, 0.2 * side)
		print_mesh.material_override = mat
		print_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(print_mesh)
	var label := Label3D.new()
	label.text = "..."
	label.font_size = 96
	label.outline_size = 16
	label.modulate = col
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 1.4, 0)
	add_child(label)

## True if the local viewer is one of the team that is meant to see it (or there is no viewer).
func visible_to_local() -> bool:
	if visible_to_team < 0:
		return true
	var local := _local_hero()
	return local == null or local.team == visible_to_team

func _local_hero() -> Hero:
	if _view == null and _scan_in <= 0 and host != null and host.get_parent() != null:
		_scan_in = 60
		for n in host.get_parent().get_children():
			if n is MatchView:
				_view = n
				break
	_scan_in -= 1
	return _view.local if _view != null and is_instance_valid(_view) else null

func _process(delta: float) -> void:
	var show_it := visible_to_local()
	visible = show_it
	if show_it and _view != null:
		_sound_in -= delta
		if _sound_in <= 0.0:
			_sound_in = 0.3
			var audio := get_node_or_null("/root/Audio")
			if audio:
				audio.play("footstep_run", "Running footsteps", global_position)

extends CharacterBody3D

const SPEED := 5.0
const SPAWN := Vector3(-2, 0.3, 8)
@onready var visual: Node3D = $CharacterVisual
@onready var camera: Camera3D = $FollowCamera
@onready var animator: AnimationPlayer = $CharacterVisual/BatangHamog/AnimationPlayer
var walk_clip: StringName
var run_clip: StringName

func _ready() -> void:
	for clip in animator.get_animation_list():
		if String(clip).ends_with("Walking"):
			walk_clip = clip
		if String(clip).ends_with("Running"):
			run_clip = clip
	assert(not walk_clip.is_empty() and not run_clip.is_empty())
	animator.get_animation(walk_clip).loop_mode = Animation.LOOP_LINEAR
	animator.get_animation(run_clip).loop_mode = Animation.LOOP_LINEAR
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original = mesh.get_active_material(surface)
			if original is StandardMaterial3D:
				var paint := ShaderMaterial.new()
				paint.shader = load("res://shaders/character_toon.gdshader")
				paint.set_shader_parameter("base_texture", original.albedo_texture)
				paint.set_shader_parameter("base_color", original.albedo_color)
				mesh.set_surface_override_material(surface, paint)
	camera.make_current()
	update_camera()

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left","move_right","move_forward","move_back")
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT)
	var move_speed := SPEED * (1.6 if sprint else 1.0)
	velocity.x = input.x * move_speed
	velocity.z = input.y * move_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	if input.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(input.x,input.y), minf(15*delta,1.0))
		animator.play(run_clip if sprint else walk_clip)
	else:
		animator.stop()
	if global_position.y < -8.0:
		global_position = SPAWN
		velocity = Vector3.ZERO
	update_camera()

func update_camera() -> void:
	camera.global_position = global_position + Vector3(0,11,8)
	camera.look_at(global_position + Vector3(0,0.8,0))

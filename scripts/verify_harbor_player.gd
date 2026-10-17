extends Node

func frames(count: int) -> void:
 for i in range(count):
  await get_tree().physics_frame

func walk(action: String, count: int) -> void:
 Input.action_press(action)
 await frames(count)
 Input.action_release(action)
 await frames(2)

func _ready() -> void:
 await frames(2)
 assert(get_parent().has_node("BatangHamogPlayer"), "Harbor must contain the playable character")
 var player: CharacterBody3D = get_parent().get_node("BatangHamogPlayer")
 await frames(40)
 assert(player.is_on_floor(), "Character must settle on yard ground")
 var start := player.position
 await walk("move_right",30)
 var distance := player.position.distance_to(start)
 assert(distance > 2.0 and distance < 3.0, "Keyboard input must move at walking speed")
 assert(not player.get_node("CharacterVisual/BatangHamog/AnimationPlayer").is_playing(), "Animation must stop when movement stops")
 player.position = Vector3(-2,0.3,8)
 await frames(30)
 start = player.position
 Input.action_press("move_right")
 Input.action_press("move_forward")
 await frames(30)
 Input.action_release("move_right")
 Input.action_release("move_forward")
 await frames(2)
 assert(player.position.distance_to(start) < 3.0, "Diagonal movement must be normalized")
 player.position = Vector3(-2,0.3,8)
 await frames(30)
 start = player.position
 var shift := InputEventKey.new()
 shift.physical_keycode = KEY_SHIFT
 shift.pressed = true
 Input.parse_input_event(shift)
 Input.action_press("move_right")
 await frames(30)
 assert(player.get_node("CharacterVisual/BatangHamog/AnimationPlayer").current_animation == "Running", "Sprint must select running animation")
 Input.action_release("move_right")
 shift.pressed = false
 Input.parse_input_event(shift)
 await frames(2)
 assert(player.position.distance_to(start) > 3.5, "Shift must increase movement speed")
 player.position = Vector3(-8,0.3,-7.6)
 await frames(30)
 await walk("move_right",90)
 assert(player.position.x < -6.0, "Character must not pass through dump truck")
 player.position.y = -20
 await frames(40)
 assert(player.position.distance_to(Vector3(-2,0.0,8)) < 0.2, "Falling into harbor must reset to safe spawn")
 assert(player.get_node("FollowCamera").is_current(), "Follow camera must be active")
 print("HARBOR_PLAYER_CHECKS_PASS: grounded, keyboard movement, diagonal speed, idle, truck collision, respawn, follow camera")

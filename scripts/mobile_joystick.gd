extends Control

signal direction_changed(direction: Vector2)
const RADIUS := 82.0
const DEAD_ZONE := 0.14
var active_finger := -1
var stick := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse()*point

func set_stick(point: Vector2) -> void:
	stick = ((local_point(point)-size*0.5)/RADIUS).limit_length()
	var strength := stick.length()
	var direction := Vector2.ZERO
	if strength > DEAD_ZONE:
		direction = stick.normalized()*(strength-DEAD_ZONE)/(1.0-DEAD_ZONE)
	direction_changed.emit(direction)
	queue_redraw()

func release_stick() -> void:
	active_finger = -1
	stick = Vector2.ZERO
	direction_changed.emit(Vector2.ZERO)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and active_finger == -1 and local_point(event.position).distance_to(size*0.5) <= RADIUS:
			active_finger = event.index
			set_stick(event.position)
		elif not event.pressed and event.index == active_finger:
			release_stick()
	elif event is InputEventScreenDrag and event.index == active_finger:
		set_stick(event.position)
	# Mouse support is only for testing the same joystick in the desktop editor.
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and active_finger == -1 and local_point(event.position).distance_to(size*0.5) <= RADIUS:
			active_finger = -2
			set_stick(event.position)
		elif not event.pressed and active_finger == -2:
			release_stick()
	elif event is InputEventMouseMotion and active_finger == -2:
		set_stick(event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_stick()

func _draw() -> void:
	var center := size*0.5
	draw_circle(center,RADIUS,Color(0.14,0.13,0.11,0.32))
	draw_arc(center,RADIUS,0,TAU,64,Color(0.91,0.85,0.72,0.65),2.0,true)
	draw_circle(center+stick*RADIUS,32,Color(0.84,0.66,0.43,0.8))
	draw_arc(center+stick*RADIUS,32,0,TAU,32,Color(0.98,0.92,0.81,0.8),2.0,true)

extends HudPart

## White sugar on the local camera, independently of the authoritative vision query.
var alpha := 0.0
var in_cloud := false
var blinded := false

func refresh(delta: float) -> void:
	in_cloud = false
	blinded = hud.local != null and hud.local.blind_ticks > 0
	var owner_view := false
	var hostile_view := false
	if hud.local:
		for object in hud.host.objects:
			if object is UboCloud and object.contains(hud.local.global_position):
				in_cloud = true
				if object.owner_hero == hud.local:
					owner_view = true
				else:
					hostile_view = true
	var goal := 0.94 if blinded else (0.7 if in_cloud and (not owner_view or hostile_view) else 0.0)
	alpha = move_toward(alpha, goal, delta * 7.0)
	queue_redraw()

func _draw() -> void:
	if alpha < 0.01:
		return
	var size := sz()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.96, 0.98, 1.0, alpha * 0.72))
	for i in range(28):
		var point := Vector2(fmod(float(i * 431 + 137), size.x), fmod(float(i * 293 + 71), size.y))
		var radius := 35.0 + float(i % 5) * 23.0
		draw_circle(point, radius, Color(1, 1, 1, alpha * 0.28))
		for j in range(4):
			draw_circle(point + Vector2(float(j * 23 - 32), float(j * 17 - 21)), 2.0 + float(j), Color(1, 1, 1, alpha))

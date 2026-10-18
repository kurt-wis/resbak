class_name ChalkBackdrop
extends Control

## Dark asphalt with faint chalk court lines (long axis left-right, Dilaw left), drawn in code.

@export var line_alpha := 0.10

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), FE.INK)
	for i in range(8):
		var a := 0.035 * (8 - i) / 8.0
		draw_rect(Rect2(0, s.y * 0.55 + i * s.y * 0.06, s.x, s.y * 0.06), Color(1.0, 0.62, 0.25, a))
	var c := Color(FE.CHALK, line_alpha)
	var m := Rect2(s.x * 0.06, s.y * 0.16, s.x * 0.88, s.y * 0.68)
	draw_rect(m, c, false, 4.0)
	draw_line(Vector2(s.x * 0.5, m.position.y), Vector2(s.x * 0.5, m.end.y), c, 4.0)
	draw_arc(Vector2(s.x * 0.5, s.y * 0.5), s.y * 0.14, 0, TAU, 64, c, 4.0)
	draw_arc(Vector2(m.position.x + m.size.x * 0.12, s.y * 0.5), s.y * 0.09, 0, TAU, 48, Color(FE.DILAW, line_alpha * 1.4), 4.0)
	draw_arc(Vector2(m.end.x - m.size.x * 0.12, s.y * 0.5), s.y * 0.09, 0, TAU, 48, Color(FE.LILA, line_alpha * 1.8), 4.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

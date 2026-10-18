class_name HudDanger
extends HudPart

## Danger border (docs/RESBAK.md § 7): an orange screen edge while any enemy within 10 m can
## tag the local hero (MatchView.danger). Setting Danger border off hides it; Reduce flashing
## makes it a steady glow. A low tick plays when it switches on.

const WIDTH := 120.0

var active := false ## border is on this frame
var alpha := 0.0

func refresh(delta: float) -> void:
	var want: bool = hud.danger_enabled and hud.view != null and hud.view.danger
	if want and not active:
		var audio := hud.get_node_or_null("/root/Audio")
		if audio:
			audio.play("danger_tick", "")
	active = want
	alpha = move_toward(alpha, 1.0 if want else 0.0, delta * 6.0)
	queue_redraw()

func _draw() -> void:
	if alpha <= 0.01:
		return
	var s := sz()
	var pulse := 1.0 if hud.reduce_flashing else 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 8.0)
	var c := Color(HudStyle.ORANGE, 0.75 * alpha * pulse)
	var t := Color(HudStyle.ORANGE, 0.0)
	var cols := PackedColorArray([c, c, t, t])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, WIDTH), Vector2(0, WIDTH)]), cols)
	draw_polygon(PackedVector2Array([Vector2(0, s.y), Vector2(s.x, s.y), Vector2(s.x, s.y - WIDTH), Vector2(0, s.y - WIDTH)]), cols)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, s.y), Vector2(WIDTH, s.y), Vector2(WIDTH, 0)]), cols)
	draw_polygon(PackedVector2Array([Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - WIDTH, s.y), Vector2(s.x - WIDTH, 0)]), cols)

class_name HudHallucinate
extends HudPart

## BAWAL! curse (v0.2, Nene S2): while the local hero hallucinates (Hero.is_hallucinating,
## controls turned around) the screen edges swim in pink and violet blobs and a wobbling
## "NAHIHILO!" line says why the stick feels wrong. Reduce flashing keeps it steady.

var alpha := 0.0

func refresh(delta: float) -> void:
	var want := hud.local != null and hud.local.is_hallucinating()
	alpha = move_toward(alpha, 1.0 if want else 0.0, delta * 5.0)
	queue_redraw()

func _draw() -> void:
	if alpha <= 0.01:
		return
	var s := sz()
	var t := 0.0 if hud.reduce_flashing else Time.get_ticks_msec() / 1000.0
	var cols := [Color("ff6fa8"), Color("9b5cff"), Color("ffd27a")]
	for i in range(14):
		var k := float(i) / 14.0
		var ang := k * TAU + t * (0.6 + 0.2 * (i % 3))
		var r := 0.5 + 0.08 * sin(t * 2.0 + i)
		var p := s * 0.5 + Vector2(cos(ang) * s.x * r, sin(ang) * s.y * r)
		draw_circle(p, 150.0 + 40.0 * sin(t * 3.0 + i * 1.7), Color(cols[i % 3], 0.22 * alpha))
	var font := get_theme_default_font()
	var text := "NAHIHILO!  baligtad ang galaw"
	var fs := 40
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2((s.x - w) * 0.5 + 12.0 * sin(t * 5.0), s.y * 0.28)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.1, 0.02, 0.08, alpha))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color("ffb3d4"), alpha))

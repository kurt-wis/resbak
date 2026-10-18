class_name HudCaptureRings
extends HudPart

## Capture progress ring (docs/RESBAK.md § 7): a ring over every visible capturer, bigger
## for the local hero, filling clockwise over the 1.5 s hold.

## {hero, progress 0..1, screen (Vector2), local (bool)}
var entries: Array[Dictionary] = []

func refresh(_delta: float) -> void:
	entries.clear()
	var host := hud.host
	var cam: Camera3D = hud.view.camera if hud.view else null
	var hold := float(RB.ticks(host.tuning.capture_hold))
	for h in host.heroes:
		if not h.capturing:
			continue
		if hud.local and host.visibility(hud.local, h) <= 0.0:
			continue
		var screen := sz() * 0.5
		if cam and cam.is_inside_tree():
			var head := h.global_position + Vector3(0, h.data.model_height + 0.7, 0)
			if not cam.is_position_behind(head):
				screen = cam.unproject_position(head)
		entries.append({"hero": h, "progress": clampf(float(h.capture_ticks) / hold, 0.0, 1.0), "screen": screen, "local": h == hud.local})
	queue_redraw()

## Under the scorebug: a bar per base being captured, worded from the local team's view.
func _alerts() -> void:
	var host := hud.host
	var my_team := hud.left_team()
	var y := 150.0
	for attackers in [RB.other_team(my_team), my_team]:
		var prog := host.base_system.capture_progress(attackers)
		if prog <= 0.0:
			continue
		var ours: bool = attackers != my_team
		var txt := "INAAGAW ANG BASE NINYO!" if ours else "INAAGAW NINYO ANG BASE NILA!"
		var col := hud.team_color(attackers)
		var w := 520.0
		var r := Rect2(sz().x * 0.5 - w * 0.5, y, w, 58)
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 90.0) if ours and not hud.reduce_flashing else 1.0
		HudStyle.panel(self, r, Color(col, pulse), Color(0.06, 0.05, 0.08, 0.9), 14, 3)
		HudStyle.text(self, txt, Vector2(r.position.x, r.position.y + 30), 24, HudStyle.RED if ours else HudStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var bar := Rect2(r.position + Vector2(16, 38), Vector2(r.size.x - 32, 10))
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * prog, bar.size.y)), col)
		y += 66.0

func _draw() -> void:
	_alerts()
	for e in entries:
		var r := 38.0 if e.local else 26.0
		var c: Vector2 = e.screen
		var col := hud.team_color((e.hero as Hero).team)
		draw_arc(c, r, 0.0, TAU, 40, HudStyle.INK, 12.0, true)
		draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 8.0, true)
		HudStyle.arc(self, c, r, e.progress, 8.0, col)

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

func _draw() -> void:
	for e in entries:
		var r := 38.0 if e.local else 26.0
		var c: Vector2 = e.screen
		var col := hud.team_color((e.hero as Hero).team)
		draw_arc(c, r, 0.0, TAU, 40, HudStyle.INK, 12.0, true)
		draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 8.0, true)
		HudStyle.arc(self, c, r, e.progress, 8.0, col)

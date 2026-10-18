class_name HudArrows
extends HudPart

## Off-screen arrows at the screen edge (docs/RESBAK.md § 7): your own base, an enemy jail
## holding a teammate, and any capture in progress. A target on screen draws nothing.

const EDGE := 70.0

## One entry per target: {kind, label, color, pos (world), onscreen, edge (Vector2), dir (Vector2), pulse}
var targets: Array[Dictionary] = []

func _camera() -> Camera3D:
	if hud.view and hud.view.camera and hud.view.camera.is_inside_tree():
		return hud.view.camera
	return null

func refresh(_delta: float) -> void:
	targets.clear()
	var me := hud.local
	var cam := _camera()
	if me == null or cam == null:
		queue_redraw()
		return
	var host := hud.host
	var raw: Array[Dictionary] = []
	var capture_poles: Array[int] = []
	for t in range(2):
		if host.base_system.capture_progress(t) > 0.0:
			var pole_team := RB.other_team(t)
			capture_poles.append(pole_team)
			raw.append({"kind": "capture", "label": "TAYA!", "color": hud.team_color(t), "pos": host.base_system.pole_pos(pole_team), "pulse": true})
	if not capture_poles.has(me.team):
		raw.append({"kind": "base", "label": "BASE", "color": hud.team_color(me.team), "pos": host.base_system.pole_pos(me.team), "pulse": false})
	var enemy := RB.other_team(me.team)
	var held := 0
	for p in host.jail_system.prisoners(enemy):
		if p != me:
			held += 1
	if held > 0:
		raw.append({"kind": "jail", "label": "RESBAK", "color": hud.team_color(me.team), "pos": host.jail_system.post(enemy), "pulse": true})
	var area := Rect2(Vector2.ZERO, sz())
	for r in raw:
		var pos: Vector3 = r.pos
		var behind := cam.is_position_behind(pos)
		var sp := cam.unproject_position(pos)
		var on := not behind and area.grow(-36.0).has_point(sp)
		r["onscreen"] = on
		r["edge"] = Vector2.ZERO
		r["dir"] = Vector2.ZERO
		if not on:
			var c := area.get_center()
			var dir := sp - c
			if behind:
				dir = -dir
			dir = dir.normalized() if dir.length() > 1.0 else Vector2.UP
			var inner := area.grow(-EDGE)
			var tx := INF if absf(dir.x) < 0.0001 else inner.size.x * 0.5 / absf(dir.x)
			var ty := INF if absf(dir.y) < 0.0001 else inner.size.y * 0.5 / absf(dir.y)
			r["edge"] = c + dir * minf(tx, ty)
			r["dir"] = dir
		targets.append(r)
	queue_redraw()

func _draw() -> void:
	for t in targets:
		if t.onscreen:
			continue
		var e: Vector2 = t.edge
		var dir: Vector2 = t.dir
		var perp := dir.orthogonal()
		var col: Color = t.color
		if t.pulse:
			col.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() / 120.0)
		var tri := PackedVector2Array([e + dir * 22.0, e + perp * 17.0 - dir * 10.0, e - perp * 17.0 - dir * 10.0])
		draw_colored_polygon(tri, HudStyle.INK)
		var inner_tri := PackedVector2Array([e + dir * 15.0, e + perp * 11.0 - dir * 8.0, e - perp * 11.0 - dir * 8.0])
		draw_colored_polygon(inner_tri, col)
		var lp: Vector2 = e - dir * 42.0
		HudStyle.text(self, t.label, Vector2(lp.x - 70.0, lp.y + 7.0), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 140.0)

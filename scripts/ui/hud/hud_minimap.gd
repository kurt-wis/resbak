class_name HudMinimap
extends HudPart

## Minimap (docs/RESBAK.md § 7): active bases, jails, allies; enemies only within 12 m of an
## ally and not hidden (cloud), or revealed (BUGA!, cough, patch). Nene's IYAK! decoy shows
## as an enemy Nene. Top right by default (Settings > Gameplay: size S/M/L, position).

const SIZES := {"S": 240.0, "M": 300.0, "L": 370.0}

var rect := Rect2()

func apply_layout() -> void:
	_layout()

func _layout() -> void:
	if hud == null or hud.host == null or hud.host.layout == null:
		return
	var b: Rect2 = hud.host.layout.bounds
	var w: float = SIZES.get(hud.minimap_size, 260.0)
	var h := w * b.size.y / b.size.x
	var margin := 24.0
	var y := 132.0 if hud.minimap_position != "bottom_right" else sz().y - margin - h # top: under the face row
	rect = Rect2(sz().x - margin - w, y, w, h)

func world_to_map(p: Vector3) -> Vector2:
	var b: Rect2 = hud.host.layout.bounds
	return rect.position + Vector2((p.x - b.position.x) / b.size.x * rect.size.x, (p.z - b.position.y) / b.size.y * rect.size.y)

func scale_m() -> float:
	return rect.size.x / hud.host.layout.bounds.size.x

## Enemies shown right now: within sight of an ally and not hidden, or revealed to our team.
func visible_enemies() -> Array[Hero]:
	var out: Array[Hero] = []
	var me := hud.local
	if me == null:
		return out
	var sight := hud.host.tuning.minimap_ally_sight
	for e in hud.host.enemies_of(me):
		if hud.host.visibility(me, e) <= 0.0:
			continue
		if e.is_revealed_to(me.team) or _near_ally(e.global_position, me.team, sight):
			out.append(e)
	return out

## Enemy-side markers of decoys (objects with minimap_as_hero; none since IYAK! left in v0.2).
func visible_decoys() -> Array:
	var out: Array = []
	var me := hud.local
	if me == null:
		return out
	var sight := hud.host.tuning.minimap_ally_sight
	for o in hud.host.objects:
		var as_hero: Variant = o.get("minimap_as_hero")
		if as_hero == null or o.team == me.team or o.expired:
			continue
		if _near_ally(o.global_position, me.team, sight):
			out.append({"hero": as_hero, "pos": o.global_position})
	return out

func _near_ally(p: Vector3, team: int, sight: float) -> bool:
	for a in hud.host.team_heroes(team):
		if RB.flat_dist(a.global_position, p) <= sight:
			return true
	return false

func refresh(_delta: float) -> void:
	if rect.size == Vector2.ZERO:
		_layout()
	visible = hud.minimap_visible
	queue_redraw()

func _draw() -> void:
	if hud == null or hud.host == null or hud.host.layout == null or rect.size == Vector2.ZERO:
		return
	var host := hud.host
	HudStyle.panel(self, rect.grow(6), Color(1, 1, 1, 0.22), Color(0.06, 0.07, 0.1, 0.84), 14, 2)
	draw_rect(rect, Color(0.16, 0.14, 0.12, 0.55))
	var s := scale_m()
	for t in range(2): # v0.2 jail line: the band, its chalk line and the post where it stands now
		var col := hud.team_color(t)
		var line := PackedVector2Array()
		for q in (host.layout.lines[t] as PackedVector3Array):
			line.append(world_to_map(q))
		if line.size() >= 2:
			draw_polyline(line, Color(col, 0.28), maxf(2.0, host.tuning.jail_band * 2.0 * s), true)
			draw_polyline(line, Color(col, 0.9), 2.0, true)
		var post := world_to_map(host.jail_system.post(t))
		draw_circle(post, 4.0, Color(0.95, 0.95, 0.95))
		draw_arc(post, 4.0, 0.0, TAU, 12, col, 1.5, true)
	for t in range(2):
		var c := world_to_map(host.base_system.pole_pos(t))
		var col := hud.team_color(t)
		draw_arc(c, host.tuning.base_ring_radius * s, 0.0, TAU, 28, col, 2.0, true)
		draw_circle(c, 4.0, col)
		var prog := host.base_system.capture_progress(RB.other_team(t))
		if prog > 0.0:
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 90.0)
			draw_arc(c, host.tuning.base_ring_radius * s + 4.0, 0.0, TAU, 28, Color(1, 1, 1, pulse), 3.0, true)
			HudStyle.arc(self, c, host.tuning.base_ring_radius * s + 8.0, prog, 3.0, hud.team_color(RB.other_team(t)))
	var me := hud.local
	var allies: Array[Hero] = host.team_heroes(me.team) if me else host.team_heroes(RB.DILAW)
	for a in allies:
		_hero_dot(a, a == me, 1.0)
	for e in visible_enemies():
		_hero_dot(e, false, host.visibility(me, e))
	for d in visible_decoys():
		_dot(world_to_map(d.pos), hud.team_color((d.hero as Hero).team), true, 1.0)

func _hero_dot(h: Hero, is_local: bool, alpha: float) -> void:
	var p := world_to_map(h.global_position)
	var col := hud.team_color(h.team)
	_dot(p, col, h.is_free(), alpha, 8.0 if is_local else 6.0)
	if is_local:
		draw_arc(p, 10.0, 0.0, TAU, 20, Color.WHITE, 2.0, true)
		var f := Vector2(h.facing.x, h.facing.z)
		if f.length() > 0.01:
			draw_line(p, p + f.normalized() * 15.0, Color.WHITE, 2.0)

func _dot(p: Vector2, col: Color, filled: bool, alpha: float, r := 6.0) -> void:
	var c := Color(col, alpha)
	if filled:
		draw_circle(p, r, c)
		draw_arc(p, r, 0.0, TAU, 16, Color(0, 0, 0, alpha), 1.5, true)
	else:
		draw_arc(p, r, 0.0, TAU, 16, c, 2.5, true)

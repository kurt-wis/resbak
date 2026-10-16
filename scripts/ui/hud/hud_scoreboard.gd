class_name HudScoreboard
extends HudPart

## Scoreboard, shown while C / View is held (not Tab: Alt+Tab would open it) (docs/RESBAK.md § 7, § 9): name, hero, tags,
## rescues, captures and state for all ten players, own team first. Also allowed between
## rounds.

const COLS := [84.0, 400.0, 600.0, 720.0, 860.0, 1000.0] ## x of name, hero, tags, rescues, captures, state
const WIDTHS := [310.0, 190.0, 110.0, 130.0, 140.0, 150.0]
const ROW := 40.0
const PANEL_W := 1160.0

var held := false
var rows := {} ## slot -> Array[Label] (6 cells)
var heads: Array[Label] = [] ## column headers
var team_labels := {} ## team -> Label
var _built := false
var _panel := Rect2()

func _init() -> void:
	visible = false

func _layout() -> void:
	var s := sz()
	var h := ROW * 13.0 + 30.0
	_panel = Rect2((s.x - PANEL_W) * 0.5, (s.y - h) * 0.5, PANEL_W, h)
	if _built:
		_place()

func _align(i: int) -> HorizontalAlignment:
	return HORIZONTAL_ALIGNMENT_LEFT if i == 0 or i == 1 or i == 5 else HORIZONTAL_ALIGNMENT_CENTER

func _build() -> void:
	_built = true
	var titles := ["IGINAGAWA", "BIDA", "TAG", "RESBAK", "TAYA", "ESTADO"]
	for i in range(6):
		var l := HudStyle.label(self, 22, _align(i), HudStyle.DIM)
		l.text = titles[i]
		heads.append(l)
	for team in range(2):
		team_labels[team] = HudStyle.label(self, 26, HORIZONTAL_ALIGNMENT_LEFT)
	for h in hud.host.heroes:
		var cells: Array[Label] = []
		for i in range(6):
			cells.append(HudStyle.label(self, 24, _align(i), Color.WHITE, 6))
		rows[h.slot] = cells
	_place()

func _place() -> void:
	var lt := hud.left_team()
	var y := _panel.position.y + 10.0
	for i in range(6):
		heads[i].position = Vector2(_panel.position.x + COLS[i], y)
		heads[i].size = Vector2(WIDTHS[i], ROW)
	y += ROW
	for side in range(2):
		var team := lt if side == 0 else RB.other_team(lt)
		var tl: Label = team_labels[team]
		tl.position = Vector2(_panel.position.x + 20.0, y)
		tl.size = Vector2(600, ROW)
		y += ROW
		var members := hud.host.team_heroes(team)
		members.sort_custom(func(a: Hero, b: Hero) -> bool: return a.team_slot < b.team_slot)
		for h in members:
			var cells: Array = rows[h.slot]
			for i in range(6):
				var c: Label = cells[i]
				c.position = Vector2(_panel.position.x + COLS[i], y)
				c.size = Vector2(WIDTHS[i], ROW)
			y += ROW

static func state_text(h: Hero) -> String:
	match h.state:
		Hero.State.TAGGED:
			return "Huli"
		Hero.State.JAILED:
			return "Kulong"
		Hero.State.CHAINED:
			return "Kadena"
	if h.capturing:
		return "Taya"
	if h.has_ep():
		return "EP"
	return "Malaya"

## The text of one player's row (for tests): [name, hero, tags, rescues, captures, state].
func row_text(slot: int) -> PackedStringArray:
	var out := PackedStringArray()
	if rows.has(slot):
		for c in rows[slot]:
			out.append((c as Label).text)
	return out

func refresh(_delta: float) -> void:
	visible = held
	if not _built:
		_build()
	if not held:
		return
	var host := hud.host
	var rf := host.round_flow
	for team in range(2):
		var tl: Label = team_labels[team]
		tl.text = "%s   %d" % [RB.TEAM_FULL_NAMES[team].to_upper(), rf.score[team]]
		HudStyle.set_color(tl, hud.team_color(team))
	for h in host.heroes:
		var st: Dictionary = host.stats[h.slot]
		var cells: Array = rows[h.slot]
		var vals := [h.display_name, h.data.display_name, str(st.tags), str(st.rescues), str(st.captures), state_text(h)]
		for i in range(6):
			(cells[i] as Label).text = vals[i]
		HudStyle.set_color(cells[0], hud.team_color(h.team) if h == hud.local else Color.WHITE)
	queue_redraw()

func _draw() -> void:
	if not held:
		return
	draw_rect(Rect2(Vector2.ZERO, sz()), Color(0, 0, 0, 0.35))
	HudStyle.panel(self, _panel, HudStyle.PANEL_EDGE, Color(0.05, 0.07, 0.1, 0.92), 20)
	for h in hud.host.heroes:
		if not rows.has(h.slot):
			continue
		var name_cell: Label = rows[h.slot][0]
		var c := Vector2(_panel.position.x + 46.0, name_cell.position.y + ROW * 0.5)
		if h == hud.local:
			HudStyle.panel(self, Rect2(_panel.position.x + 8, name_cell.position.y + 1, _panel.size.x - 16, ROW - 2), Color(0, 0, 0, 0), Color(hud.team_color(h.team), 0.18), 8, 0)
		Portraits.draw_face(self, h.data.id, c, 17.0, h.data.color.darkened(0.35), hud.team_color(h.team), 2.0, 0.0 if h.is_free() else 0.55, HudStyle.font())

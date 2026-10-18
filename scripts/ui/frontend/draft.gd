extends FrontScreen

## Snake draft screen (docs/RESBAK.md § 6): own slots left (Dilaw), enemy right (Lila), hero grid
## centre, skills / passive / portrait bottom, map top right. Rules live in DraftLogic: A1, B1,
## B2, A2, A3, B3, B4, A4, A5, B5; 12 s per pick (timeout = hovered, else random); bots lock a
## random hero 2 s in; no duplicate hero in a team. When all ten are in, builds Session.lineup
## and starts the match.

const END_DELAY := 1.0

var draft: DraftLogic
var hovered := ""
var turn_time := DraftLogic.TURN_SECS
var finished := false
var end_timer := 0.0
var preview: HeroPreview
var cards := {} ## hero_id -> Button
var slot_panels := [[], []] ## per team: [{panel, name, hero}]
var timer_label: Label
var turn_box: VBoxContainer
var info_name: Label
var info_role: Label
var info_rows: Array[Label] = []
var lock_btn: Button
var _selected := ""
var _built_turn := -1

func build() -> void:
	draft = DraftLogic.new(int(Session.settings.get("seed", 0)), int(Session.settings.get("human_team", RB.DILAW)))
	Portraits.request_all()
	_build_top()
	_build_slots()
	_build_grid()
	_build_info()
	_begin_turn()
	set_hover(HeroData.ORDER[0])

func first_focus() -> Control:
	return cards.get(HeroData.ORDER[0])

func on_back() -> void:
	ask("Aalis ka na?", "Leaving?", func(): go("home"))

# ---- layout -----------------------------------------------------------------------------
func _build_top() -> void:
	var t := FE.bi_box("Pumili ng Katropa", "Pick your crew", 52, FE.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	t.position = Vector2(60, 28)
	t.size = Vector2(600, 110)
	content.add_child(t)
	turn_box = FE.bi_box("", "", 40, FE.CHALK)
	turn_box.name = "TurnBox"
	turn_box.position = Vector2(560, 24)
	turn_box.size = Vector2(800, 100)
	content.add_child(turn_box)
	timer_label = FE.shout("12", 84, FE.CHALK, FE.INK)
	timer_label.name = "Timer"
	timer_label.position = Vector2(860, 108)
	timer_label.size = Vector2(200, 100)
	content.add_child(timer_label)
	var map: Dictionary = FE.map_info(String(Session.settings.get("map", "barangay_court")))
	var mb := FE.bi_box(map.fil, "Fixed bases", 36, FE.CHALK, HORIZONTAL_ALIGNMENT_RIGHT)
	mb.name = "MapTag"
	mb.position = Vector2(1360, 28)
	mb.size = Vector2(500, 100)
	content.add_child(mb)

func _build_slots() -> void:
	for team in range(2):
		var own: bool = team == draft.human_team # your team is always on the left
		var x := 60 if own else 1460
		var head := FE.label(RB.TEAM_FULL_NAMES[team] + ("  (ikaw)" if own else ""), 30, RB.TEAM_COLORS[team], HORIZONTAL_ALIGNMENT_LEFT if own else HORIZONTAL_ALIGNMENT_RIGHT)
		head.position = Vector2(x, 150)
		head.size = Vector2(400, 40)
		content.add_child(head)
		for i in range(5):
			var p := PanelContainer.new()
			p.name = "Slot_%d_%d" % [team, i]
			p.position = Vector2(x, 200 + i * 80)
			p.custom_minimum_size = Vector2(400, 72)
			p.add_theme_stylebox_override("panel", FE.box_style(FE.INK2, Color(RB.TEAM_COLORS[team], 0.5), 2, 12))
			content.add_child(p)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			p.add_child(row)
			var num := FE.label(str(i + 1), 34, RB.TEAM_COLORS[team])
			num.custom_minimum_size = Vector2(36, 0)
			row.add_child(num)
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", -4)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col)
			var who := Session.player_name() if (own and i == 0) else "Bot %d" % (i + 1)
			var nl := FE.label(who, 24, FE.CHALK)
			var hl := FE.label("", 22, FE.GOLD)
			col.add_child(nl)
			col.add_child(hl)
			slot_panels[team].append({"panel": p, "name": nl, "hero": hl})

func _build_grid() -> void:
	var row := HBoxContainer.new()
	row.name = "Grid"
	row.position = Vector2(510, 230)
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	for hid in HeroData.ORDER:
		var data := HeroData.load_hero(hid)
		var b := Button.new()
		b.name = "Hero_" + hid
		b.custom_minimum_size = Vector2(170, 300)
		b.set_meta("fil", data.display_name)
		b.clip_contents = true
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_END
		v.add_theme_constant_override("separation", 0)
		b.add_child(v)
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(0, 150)
		swatch.size_flags_vertical = Control.SIZE_EXPAND_FILL
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.add_theme_stylebox_override("panel", FE.box_style(data.color.darkened(0.2), Color(0, 0, 0, 0), 0, 10))
		v.add_child(swatch)
		var face := FaceBadge.new(hid, 138)
		face.bg = data.color.darkened(0.45)
		face.ring = FE.CHALK
		var centre := CenterContainer.new()
		centre.set_anchors_preset(Control.PRESET_FULL_RECT)
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.add_child(centre)
		centre.add_child(face)
		v.add_child(FE.label(data.display_name, 30, FE.CHALK, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(FE.label(data.role, 20, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		var dots := FE.label("", 22, FE.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		dots.name = "Taken"
		v.add_child(dots)
		row.add_child(b)
		cards[hid] = b
		buttons[b.name] = b
		b.mouse_entered.connect(func(): set_hover(hid))
		b.focus_entered.connect(func(): set_hover(hid))
		b.pressed.connect(func(): _on_card(hid))
	var tip := FE.label("Pili: i-click o Enter, tapos I-LOCK.  Pick, then lock in.", 20, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	tip.position = Vector2(510, 545)
	tip.size = Vector2(920, 30)
	content.add_child(tip)

func _build_info() -> void:
	var panel := FE.panel(FE.INK2, FE.CHALK_DIM, 2, 20)
	panel.name = "InfoPanel"
	panel.position = Vector2(60, 610)
	panel.custom_minimum_size = Vector2(1800, 430)
	content.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	preview = HeroPreview.new()
	preview.name = "Portrait"
	preview.custom_minimum_size = Vector2(380, 380)
	row.add_child(preview)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	info_name = FE.label("", 50, FE.GOLD)
	col.add_child(info_name)
	info_role = FE.label("", 24, FE.CHALK_DIM)
	col.add_child(info_role)
	for i in range(3):
		var l := FE.label("", 24, FE.CHALK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(1000, 0)
		col.add_child(l)
		info_rows.append(l)
	lock_btn = btn("Lock", "I-LOCK", "Lock in", Vector2(300, 150), 44, false, true)
	row.add_child(lock_btn)
	lock_btn.pressed.connect(confirm)

# ---- hover / select ---------------------------------------------------------------------
func set_hover(hid: String) -> void:
	hovered = hid
	var d := HeroData.load_hero(hid)
	info_name.text = d.display_name.to_upper() + ("  \"%s\"" % d.nickname if d.nickname != "" else "")
	info_role.text = d.role + (" / " + d.secondary_role if d.secondary_role != "" else "")
	var q := Controls.label("skill_1")
	var e := Controls.label("skill_2")
	info_rows[0].text = "[%s]  %s:  %s" % [q, d.skill1_name, d.skill1_text]
	info_rows[1].text = "[%s]  %s:  %s" % [e, d.skill2_name, d.skill2_text]
	info_rows[2].text = "Passive  %s:  %s" % [d.passive_name, d.passive_text]
	preview.show_hero(hid, "BreakDance")

func _on_card(hid: String) -> void:
	if finished or not draft.is_human_turn() or not draft.can_pick(hid):
		set_hover(hid)
		return
	if _selected == hid:
		confirm()
		return
	_selected = hid
	set_hover(hid)
	_refresh_cards()

## Lock the selected (or hovered) hero for the human's turn.
func confirm() -> void:
	if finished or not draft.is_human_turn():
		return
	var hid := _selected if _selected != "" else hovered
	if hid == "" or not draft.can_pick(hid):
		return
	_lock(hid)

func _lock(hid: String) -> void:
	var team := draft.team_now()
	var slot := draft.slot_now()
	if not draft.pick(hid):
		return
	var sp: Dictionary = slot_panels[team][slot]
	var d := HeroData.load_hero(hid)
	sp.hero.text = d.display_name
	if not (team == draft.human_team and slot == 0):
		sp.name.text = d.display_name + " (Bot)"
	_selected = ""
	_refresh_cards()
	if draft.is_done():
		finished = true
		end_timer = END_DELAY
		turn_time = 0.0
		_set_turn("Handa na ang mga koponan!", "Teams are set", FE.GOLD)
		timer_label.text = ""
		lock_btn.disabled = true
	else:
		_begin_turn()

# ---- turns ------------------------------------------------------------------------------
func _begin_turn() -> void:
	turn_time = DraftLogic.TURN_SECS
	_built_turn = draft.turn
	var team := draft.team_now()
	var slot := draft.slot_now()
	for t in range(2):
		for i in range(5):
			var on: bool = t == team and i == slot
			(slot_panels[t][i].panel as PanelContainer).add_theme_stylebox_override("panel",
				FE.box_style(FE.INK3 if on else FE.INK2, RB.TEAM_COLORS[t] if on else Color(RB.TEAM_COLORS[t], 0.5), 5 if on else 2, 12))
	if draft.is_human_turn():
		_set_turn("Ikaw na! Pumili ka.", "Your pick", FE.GOLD)
	else:
		_set_turn("Pumipili ang %s (%d)" % [RB.TEAM_FULL_NAMES[team], slot + 1], "%s is picking" % RB.TEAM_FULL_NAMES[team], RB.TEAM_COLORS[team])
	lock_btn.disabled = not draft.is_human_turn()
	lock_btn.modulate.a = 1.0 if draft.is_human_turn() else 0.45
	_refresh_cards()

func _set_turn(fil: String, en: String, color: Color) -> void:
	FE.set_bi(turn_box, fil, en)
	(turn_box.get_node("Fil") as Label).add_theme_color_override("font_color", color)

func _refresh_cards() -> void:
	for hid in cards:
		var b: Button = cards[hid]
		var taken := ""
		for t in range(2):
			if hid in draft.picks[t]:
				taken += "●"
		(b.find_child("Taken", true, false) as Label).text = taken
		var mine_gone: bool = hid in draft.picks[draft.human_team]
		b.modulate = Color(1, 1, 1, 0.45) if (mine_gone and draft.is_human_turn()) else Color.WHITE
		if hid == _selected and draft.is_human_turn():
			b.add_theme_stylebox_override("normal", FE.box_style(FE.INK3, FE.DILAW, 6))
		else:
			b.remove_theme_stylebox_override("normal")

func _process(delta: float) -> void:
	advance(delta)

## Advance the draft clock by `delta` seconds (tests call this directly).
func advance(delta: float) -> void:
	if finished:
		end_timer -= delta
		if end_timer <= 0.0 and draft.is_done() and last_go == "":
			start_match()
		return
	turn_time -= delta
	timer_label.text = str(maxi(0, int(ceil(turn_time))))
	timer_label.add_theme_color_override("font_color", FE.ORANGE if turn_time <= 3.0 else FE.CHALK)
	if draft.is_human_turn():
		if turn_time <= 0.0:
			var pick := draft.available(draft.team_now())
			var want := _selected if _selected in pick else (hovered if hovered in pick else "")
			if want == "":
				want = pick[draft.rng.randi() % pick.size()]
			_lock(want)
	elif DraftLogic.TURN_SECS - turn_time >= DraftLogic.BOT_LOCK_SECS:
		var over := (DraftLogic.TURN_SECS - turn_time) - DraftLogic.BOT_LOCK_SECS
		var pool := draft.available(draft.team_now())
		_lock(pool[draft.rng.randi() % pool.size()])
		if over > 0.001:
			advance(over) ## big test steps keep cascading into the next turns

func start_match() -> void:
	var s := Session
	s.lineup = draft.lineup(s.player_name())
	s.local_slot = draft.human_team * 5
	s.mode = "vs_bots"
	go_call("match", func(): s.start_match())

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if dialog or finished:
		return
	if event.is_action_pressed("interact") and draft.is_human_turn():
		confirm()

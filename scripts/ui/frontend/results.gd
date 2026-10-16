extends FrontScreen

## Results (docs/RESBAK.md § 6 "Results (steps 1 to 3)"), reading Session.last_results:
## 1. PANALO! / TALO! + score, 4 s.  2. MVP card per team (winners gold first, losers silver
## "Bida ng Talo"), then up to 3 badges, 6 s.  3. Scoreboard with tabs Impact, Tags, Rescues,
## Captures, Assists, Saves; LARO ULIT (new match, same settings, at the roulette) and
## BUMALIK SA TAMBAYAN (Home). Timed steps skip on any confirm. Saves the profile once.

const STEP_TIMES := [4.0, 6.0]

var data := {}
var step := 0
var _left := 0.0
var _step_box: Control
var _tab := 0
var _table: VBoxContainer
var recorded := false

func build() -> void:
	var s := FE.session()
	data = ResultsCalc.compute(s.last_results if s and not s.last_results.is_empty() else {})
	_record()
	_show_step(0)

func first_focus() -> Control:
	return buttons.get("LaroUlit")

func on_back() -> void:
	if step < 2:
		_show_step(step + 1)
	else:
		go("home")

func _record() -> void:
	var s := FE.save()
	if s == null or recorded or data.rows.is_empty():
		return
	recorded = true
	var mine: Dictionary = {}
	for r in data.rows:
		if int(r.slot) == int(data.local_slot):
			mine = r.stats
	s.record_match(bool(data.local_won), mine, int(data.mvp.get(data.local_team, -1)) == int(data.local_slot))

func _process(delta: float) -> void:
	if step < 2:
		_left -= delta
		if _left <= 0.0:
			_show_step(step + 1)

func _gui_input(event: InputEvent) -> void:
	if step < 2 and event is InputEventMouseButton and event.pressed:
		_show_step(step + 1)

func _unhandled_input(event: InputEvent) -> void:
	if step < 2 and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_show_step(step + 1)
		return
	super._unhandled_input(event)

func _show_step(n: int) -> void:
	step = clampi(n, 0, 2)
	_left = STEP_TIMES[step] if step < 2 else 0.0
	if _step_box:
		_step_box.queue_free()
	_step_box = Control.new()
	_step_box.name = "Step%d" % step
	_step_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_step_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_step_box)
	match step:
		0: _build_banner()
		1: _build_mvp()
		2: _build_board()

func _team_name(t: int) -> String:
	return RB.TEAM_FULL_NAMES[t] if t >= 0 else "Tabla"

func _centre_column(sep := 24) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_step_box.add_child(c)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", sep)
	c.add_child(v)
	return v

# ---- step 1 -----------------------------------------------------------------------------
func _build_banner() -> void:
	var v := _centre_column()
	var won: bool = data.local_won
	var title := FE.shout("PANALO!" if won else "TALO!", 180, FE.GOLD if won else FE.SILVER)
	title.name = "Outcome"
	v.add_child(title)
	v.add_child(FE.label("Win" if won else "Loss", 30, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var sc := FE.label("%s  %d  -  %d  %s" % [RB.TEAM_NAMES[0].to_upper(), data.score[0], data.score[1], RB.TEAM_NAMES[1].to_upper()], 64, FE.CHALK, HORIZONTAL_ALIGNMENT_CENTER)
	sc.name = "Score"
	v.add_child(sc)

# ---- step 2 -----------------------------------------------------------------------------
func _row(slot: int) -> Dictionary:
	for r in data.rows:
		if int(r.slot) == slot:
			return r
	return {}

func _build_mvp() -> void:
	var v := _centre_column(36)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 60)
	v.add_child(cards)
	var order := [data.winner, RB.other_team(data.winner)] if data.winner >= 0 else [0, 1]
	for t in order:
		if not data.mvp.has(t):
			continue
		var r := _row(int(data.mvp[t]))
		var gold: bool = t == data.winner
		var p := FE.panel(FE.INK2, FE.GOLD if gold else FE.SILVER, 4, 22)
		p.name = "Mvp_%s" % RB.TEAM_NAMES[t]
		p.custom_minimum_size = Vector2(560, 300)
		cards.add_child(p)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(col)
		col.add_child(FE.bi_box("MVP" if gold else "Bida ng Talo", "Most valuable" if gold else "Star of the losing side", 40, FE.GOLD if gold else FE.SILVER))
		col.add_child(FE.label(String(r.get("name", "")), 48, FE.CHALK, HORIZONTAL_ALIGNMENT_CENTER))
		var hd := HeroData.load_hero(String(r.get("hero_id", "tutoy")))
		col.add_child(FE.label("%s  ·  %s" % [hd.display_name if hd else "", _team_name(t)], 26, RB.TEAM_COLORS[t], HORIZONTAL_ALIGNMENT_CENTER))
		var st: Dictionary = r.get("stats", {})
		col.add_child(FE.label("Impact %d   Tags %d   Rescues %d   Captures %d" % [int(st.get("impact", 0)), int(st.get("tags", 0)), int(st.get("rescues", 0)), int(st.get("captures", 0))], 24, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var badges := HBoxContainer.new()
	badges.name = "Badges"
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.add_theme_constant_override("separation", 30)
	v.add_child(badges)
	for b in data.badges:
		var p := FE.panel(FE.INK3, FE.CHALK_DIM, 2, 16)
		p.custom_minimum_size = Vector2(380, 120)
		badges.add_child(p)
		var col := VBoxContainer.new()
		p.add_child(col)
		col.add_child(FE.bi_box(String(b.fil), String(b.en), 30, FE.ORANGE))
		var who := String(_row(int(b.slot)).get("name", ""))
		if int(b.slot2) >= 0:
			who += " & " + String(_row(int(b.slot2)).get("name", ""))
		col.add_child(FE.label(who, 24, FE.CHALK, HORIZONTAL_ALIGNMENT_CENTER))

# ---- step 3 -----------------------------------------------------------------------------
func _build_board() -> void:
	var v := VBoxContainer.new()
	v.position = Vector2(160, 70)
	v.custom_minimum_size = Vector2(1600, 0)
	v.add_theme_constant_override("separation", 18)
	_step_box.add_child(v)
	v.add_child(FE.label("%s  %d  -  %d  %s" % [RB.TEAM_FULL_NAMES[0], data.score[0], data.score[1], RB.TEAM_FULL_NAMES[1]], 44, FE.CHALK))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	v.add_child(tabs)
	for i in range(ResultsCalc.TABS.size()):
		var tb: Dictionary = ResultsCalc.TABS[i]
		var b := btn("Tab_" + String(tb.key), String(tb.fil), "", Vector2(230, 60), 26)
		b.pressed.connect(_set_tab.bind(i))
		tabs.add_child(b)
	_table = VBoxContainer.new()
	_table.name = "Table"
	_table.add_theme_constant_override("separation", 6)
	v.add_child(_table)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	var again := btn("LaroUlit", "LARO ULIT", "Play again", Vector2(420, 84), 34, false, true)
	again.pressed.connect(func(): go("roulette"))
	row.add_child(again)
	var home := btn("Bumalik", "BUMALIK SA TAMBAYAN", "Back to Home", Vector2(520, 84), 34)
	home.pressed.connect(func(): go("home"))
	row.add_child(home)
	_set_tab(0)
	again.grab_focus.call_deferred()

func _set_tab(i: int) -> void:
	_tab = i
	for c in _table.get_children():
		c.queue_free()
	var key := String(ResultsCalc.TABS[i].key)
	var rows: Array = data.rows.duplicate()
	rows.sort_custom(func(a, b): return float(a.stats.get(key, 0)) > float(b.stats.get(key, 0)) or (float(a.stats.get(key, 0)) == float(b.stats.get(key, 0)) and int(a.slot) < int(b.slot)))
	for r in rows:
		var line := FE.label("%-22s %-10s %-12s %6d" % [String(r.name).left(22), String(r.hero_id).capitalize(), RB.TEAM_NAMES[int(r.team)], int(r.stats.get(key, 0))], 28, RB.TEAM_COLORS[int(r.team)] if int(r.slot) != int(data.local_slot) else FE.GOLD)
		_table.add_child(line)

func current_tab_key() -> String:
	return String(ResultsCalc.TABS[_tab].key)

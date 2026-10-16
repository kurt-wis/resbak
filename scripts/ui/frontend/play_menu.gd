extends FrontScreen

## Play menu (docs/RESBAK.md § 6 and § 8). Cards: Laban sa Bots, Tradisyonal (vs bots with the
## Tradisyonal preset), Custom Room (greyed, "Malapit na"). Options: difficulty Madali /
## Katamtaman / Mahirap (default Katamtaman) and map (Barangay Court or Roulette, default
## Roulette). SIMULAN writes Session.settings and goes to the roulette.

var mode_sel := "bots" ## "bots" | "tradisyonal"
var diff := 1
var map_choice := "roulette" ## "roulette" or a map id
var cards := {}
var diff_btns: Array[Button] = []
var map_btns := {}

func build() -> void:
	var title := FE.bi_box("LARO", "Play", 72, FE.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	title.position = Vector2(100, 50)
	title.size = Vector2(700, 150)
	content.add_child(title)
	var q := FE.label("Laban sa Bots o Custom Room?  Against bots or Custom Room?", 26, FE.CHALK_DIM)
	q.position = Vector2(104, 205)
	content.add_child(q)
	var row := HBoxContainer.new()
	row.name = "Cards"
	row.position = Vector2(100, 270)
	row.add_theme_constant_override("separation", 40)
	content.add_child(row)
	row.add_child(_card("bots", "Laban sa Bots", "Against bots", "You and 4 bots against 5 bots", false))
	row.add_child(_card("tradisyonal", "Tradisyonal", "Classic rules", "No skills, one base each, the real playground rules", false))
	row.add_child(_card("custom", "Custom Room", "Private room", "Private room for friends, LAN and tournaments", true))
	_build_options()
	_refresh()

func first_focus() -> Control:
	return buttons.get("SIMULAN")

func on_back() -> void:
	go("home")

func _card(key: String, fil: String, en: String, summary: String, greyed: bool) -> Button:
	var b := Button.new()
	b.name = "Card_" + key
	b.custom_minimum_size = Vector2(540, 360)
	b.set_meta("fil", fil)
	b.clip_contents = true
	buttons[b.name] = b
	cards[key] = b
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	b.add_child(margin)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 16)
	margin.add_child(v)
	v.add_child(FE.bi_box(fil, en, 52, FE.CHALK, HORIZONTAL_ALIGNMENT_LEFT))
	var sum := FE.label(summary, 28, FE.CHALK_DIM)
	sum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sum.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sum)
	if greyed:
		FE.set_greyed(b, true)
	else:
		b.pressed.connect(func():
			mode_sel = key
			_refresh())
	return b

func _build_options() -> void:
	var panel := FE.panel(FE.INK2, FE.CHALK_DIM, 2, 22)
	panel.name = "Options"
	panel.position = Vector2(100, 670)
	panel.custom_minimum_size = Vector2(1300, 260)
	content.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 18)
	panel.add_child(grid)
	var l1 := FE.bi_box("Hirap ng Bots", "Bot difficulty", 30, FE.CHALK, HORIZONTAL_ALIGNMENT_LEFT)
	l1.custom_minimum_size = Vector2(380, 0)
	grid.add_child(l1)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 16)
	grid.add_child(r1)
	for i in range(FE.DIFFICULTIES.size()):
		var d: Dictionary = FE.DIFFICULTIES[i]
		var b := btn("Diff_%d" % i, d.fil, d.en, Vector2(280, 80), 30)
		b.pressed.connect(func():
			diff = i
			_refresh())
		r1.add_child(b)
		diff_btns.append(b)
	var l2 := FE.bi_box("Mapa", "Map", 30, FE.CHALK, HORIZONTAL_ALIGNMENT_LEFT)
	grid.add_child(l2)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 16)
	grid.add_child(r2)
	var maps := [["barangay_court", "Barangay Court", "Showcase map"], ["roulette", "Roulette", "Random map"]]
	for m in maps:
		var b := btn("Map_" + m[0], m[1], m[2], Vector2(280, 80), 30)
		b.pressed.connect(func():
			map_choice = m[0]
			_refresh())
		r2.add_child(b)
		map_btns[m[0]] = b
	var go := btn("SIMULAN", "SIMULAN", "Start", Vector2(380, 190), 54, false, true)
	go.position = Vector2(1440, 720)
	content.add_child(go)
	go.pressed.connect(start)

func _mark(b: Button, on: bool) -> void:
	if on:
		b.add_theme_stylebox_override("normal", FE.box_style(FE.INK3, FE.DILAW, 5))
	else:
		b.remove_theme_stylebox_override("normal")

func _refresh() -> void:
	for k in cards:
		if k != "custom":
			_mark(cards[k], k == mode_sel)
	for i in range(diff_btns.size()):
		_mark(diff_btns[i], i == diff)
	for k in map_btns:
		_mark(map_btns[k], k == map_choice)

## Write the room settings and head to the roulette.
func start() -> void:
	apply_to_session()
	go("roulette")

func apply_to_session() -> void:
	var s := Session
	s.reset_settings()
	s.mode = "vs_bots"
	if mode_sel == "tradisyonal":
		s.apply_tradisyonal()
	s.settings["difficulty"] = diff
	s.settings["map_choice"] = map_choice
	s.settings["base_choice"] = s.settings["base_mode"]
	if map_choice != "roulette":
		s.settings["map"] = map_choice
	s.settings["capture_toggle"] = String(FE.setting("accessibility", "capture_input")) == "toggle"
	s.lineup = []
	s.local_slot = 0

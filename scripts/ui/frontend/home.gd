extends FrontScreen

## Home / "Tambayan" (docs/RESBAK.md § 6): bench hero doing BreakDance, player card, Settings,
## LARO (preselected), ENSAYO / BARKADA / LOCKER / GAWAIN greyed "Malapit na", LUMABAS with the
## "Aalis ka na?" dialog. The bench hero is saved in profile.home_hero (JM on first launch).

var preview: HeroPreview
var bench_id := "jm"
var hero_name: Label
var hero_role: Label
var card_name: Label
var card_stats: Label
var card_dot: Panel

func build() -> void:
	var s := FE.save()
	bench_id = String(s.get_profile().get("home_hero", "jm")) if s else "jm"
	if not (bench_id in HeroData.ORDER):
		bench_id = "jm"
	_build_player_card()
	_build_nav()
	_build_bench()
	_build_soon_tiles()
	_refresh_bench()

func first_focus() -> Control:
	return buttons.get("Laro")

func on_back() -> void:
	_ask_quit()

func _ask_quit() -> void:
	ask("Aalis ka na?", "Leaving?", func(): get_tree().quit())

# ---- layout -----------------------------------------------------------------------------
func _build_player_card() -> void:
	var card := FE.panel(FE.INK2, FE.CHALK_DIM, 2, 22)
	card.name = "PlayerCard"
	card.position = Vector2(80, 60)
	card.custom_minimum_size = Vector2(640, 150)
	content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	card.add_child(row)
	card_dot = Panel.new()
	card_dot.custom_minimum_size = Vector2(110, 110)
	row.add_child(card_dot)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	card_name = FE.label(Session.player_name(), 44, FE.GOLD)
	card_name.name = "PlayerName"
	col.add_child(card_name)
	card_stats = FE.label("", 22, FE.CHALK_DIM)
	card_stats.name = "PlayerStats"
	col.add_child(card_stats)
	var s := FE.save()
	var t: Dictionary = s.get_profile().get("totals", {}) if s else {}
	card_stats.text = "Laro %d   Panalo %d   MVP %d\nMatches %d   Wins %d" % [int(t.get("matches", 0)), int(t.get("wins", 0)), int(t.get("mvps", 0)), int(t.get("matches", 0)), int(t.get("wins", 0))]

func _build_nav() -> void:
	var col := VBoxContainer.new()
	col.name = "Nav"
	col.position = Vector2(80, 270)
	col.add_theme_constant_override("separation", 18)
	content.add_child(col)
	var laro := btn("Laro", "LARO", "Play", Vector2(560, 150), 72, false, true)
	col.add_child(laro)
	laro.pressed.connect(func(): go("play_menu"))
	var greyed := [["Ensayo", "ENSAYO", "Practice"], ["Barkada", "BARKADA", "Friends"], ["Locker", "LOCKER", "Locker"], ["Gawain", "GAWAIN", "Challenges"]]
	for g in greyed:
		col.add_child(btn(g[0], g[1], g[2], Vector2(560, 84), 34, true))
	col.add_child(FE.spacer(6))
	var quit := btn("Lumabas", "LUMABAS", "Quit", Vector2(560, 84), 34)
	col.add_child(quit)
	quit.pressed.connect(_ask_quit)
	var settings := btn("Settings", "Settings", "Settings", Vector2(260, 76), 28)
	settings.position = Vector2(1580, 60)
	content.add_child(settings)
	settings.pressed.connect(func():
		FE.back_to = "home"
		go("settings"))

func _build_bench() -> void:
	preview = HeroPreview.new()
	preview.name = "BenchPreview"
	preview.position = Vector2(820, 150)
	preview.size = Vector2(760, 700)
	content.add_child(preview)
	hero_name = FE.shout("", 80, FE.CHALK, FE.INK)
	hero_name.name = "BenchName"
	hero_name.position = Vector2(740, 830)
	hero_name.size = Vector2(920, 100)
	content.add_child(hero_name)
	hero_role = FE.label("", 26, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hero_role.position = Vector2(740, 930)
	hero_role.size = Vector2(920, 40)
	content.add_child(hero_role)
	var prev := btn("BenchPrev", "<", "", Vector2(90, 90), 44)
	var next := btn("BenchNext", ">", "", Vector2(90, 90), 44)
	prev.position = Vector2(760, 470)
	next.position = Vector2(1640, 470)
	content.add_child(prev)
	content.add_child(next)
	prev.pressed.connect(func(): cycle_bench(-1))
	next.pressed.connect(func(): cycle_bench(1))

func _build_soon_tiles() -> void:
	var tiles := [["Tansan", "Tansan", Vector2(1580, 160), Vector2(260, 64)],
		["News", "Balita", Vector2(1580, 250), Vector2(260, 64)],
		["Profile", "Profile", Vector2(1580, 340), Vector2(260, 64)]]
	for t in tiles:
		var b := btn(t[0], t[1], "", t[3], 26, true)
		b.position = t[2]
		content.add_child(b)

# ---- bench hero -------------------------------------------------------------------------
func cycle_bench(dir: int) -> void:
	var i := HeroData.ORDER.find(bench_id)
	set_bench(HeroData.ORDER[wrapi(i + dir, 0, HeroData.ORDER.size())])

func set_bench(id: String) -> void:
	bench_id = id
	var s := FE.save()
	if s:
		s.profile["home_hero"] = id
		s.save_profile()
	_refresh_bench()

func _refresh_bench() -> void:
	var data := HeroData.load_hero(bench_id)
	preview.show_hero(bench_id, "BreakDance")
	hero_name.text = data.display_name.to_upper()
	hero_role.text = ("%s \"%s\"   %s" % [data.display_name, data.nickname, data.role]) if data.nickname != "" else data.role
	card_dot.add_theme_stylebox_override("panel", FE.box_style(data.color, FE.CHALK, 4, 55))

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if dialog:
		return
	if event.is_action_pressed("ui_page_up"):
		cycle_bench(-1)
	elif event.is_action_pressed("ui_page_down"):
		cycle_bench(1)

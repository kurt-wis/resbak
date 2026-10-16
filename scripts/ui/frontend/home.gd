extends FrontScreen

## Home / "Tambayan" (docs/RESBAK.md § 6): bench hero doing BreakDance, player card, Settings,
## LARO (preselected), ENSAYO (the tutorial), BARKADA / LOCKER / GAWAIN greyed "Malapit na",
## LUMABAS back to the title screen (leaving steps back one screen at a time: the title is the
## last screen before quitting). The bench hero is saved in profile.home_hero (JM first launch)
## and its face is the player card's portrait.

var preview: HeroPreview
var bench_id := "jm"
var hero_name: Label
var hero_role: Label
var card_name: Label
var card_stats: Label
var card_face: FaceBadge
var stat_values := {} ## "matches"/"wins"/"mvps" -> Label

func build() -> void:
	var s := FE.save()
	bench_id = String(s.get_profile().get("home_hero", "jm")) if s else "jm"
	if not (bench_id in HeroData.ORDER):
		bench_id = "jm"
	Portraits.request_all()
	_build_player_card()
	_build_nav()
	_build_bench()
	_build_soon_tiles()
	_refresh_bench()

func first_focus() -> Control:
	return buttons.get("Laro")

func on_back() -> void:
	go("title")

# ---- layout -----------------------------------------------------------------------------
func _build_player_card() -> void:
	var card := FE.panel(FE.INK2, FE.CHALK_DIM, 2, 26)
	card.name = "PlayerCard"
	card.position = Vector2(80, 56)
	card.custom_minimum_size = Vector2(660, 176)
	content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)
	card_face = FaceBadge.new(bench_id, 140)
	card_face.name = "PlayerFace"
	row.add_child(card_face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	card_name = FE.shout(Session.player_name(), 48, FE.GOLD, FE.OUTLINE if not FE.light else FE.INK)
	card_name.name = "PlayerName"
	card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(card_name)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 34)
	col.add_child(stats)
	var s := FE.save()
	var t: Dictionary = s.get_profile().get("totals", {}) if s else {}
	for st in [["matches", "Laro", "Matches"], ["wins", "Panalo", "Wins"], ["mvps", "MVP", "MVP"]]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", -6)
		var v := FE.shout(str(int(t.get(st[0], 0))), 40, FE.CHALK, FE.OUTLINE if not FE.light else FE.INK3)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cell.add_child(v)
		var p := FE.pair(st[1], st[2])
		var cap := FE.label(p[0] if p[1] == "" or p[0] == p[1] else "%s · %s" % [p[0], p[1]], 18, FE.CHALK_DIM)
		cell.add_child(cap)
		stats.add_child(cell)
		stat_values[st[0]] = v
	# kept for tests/tools that read the old single label
	card_stats = FE.label("Laro %d   Panalo %d   MVP %d" % [int(t.get("matches", 0)), int(t.get("wins", 0)), int(t.get("mvps", 0))], 18, FE.CHALK_DIM)
	card_stats.name = "PlayerStats"
	card_stats.visible = false
	col.add_child(card_stats)

func _build_nav() -> void:
	var col := VBoxContainer.new()
	col.name = "Nav"
	col.position = Vector2(80, 268)
	col.add_theme_constant_override("separation", 16)
	content.add_child(col)
	var laro := btn("Laro", "LARO", "Play", Vector2(560, 150), 76, false, true)
	col.add_child(laro)
	laro.pressed.connect(func(): go("play_menu"))
	var ensayo := btn("Ensayo", "ENSAYO", "Tutorial: Turo ni Kuya Tanod", Vector2(560, 92), 36)
	col.add_child(ensayo)
	ensayo.pressed.connect(start_tutorial)
	var greyed := [["Barkada", "BARKADA", "Friends"], ["Locker", "LOCKER", "Locker"], ["Gawain", "GAWAIN", "Challenges"]]
	for g in greyed:
		col.add_child(btn(g[0], g[1], g[2], Vector2(560, 80), 32, true))
	col.add_child(FE.spacer(6))
	var quit := btn("Lumabas", "LUMABAS", "Back to title", Vector2(560, 84), 34)
	col.add_child(quit)
	quit.pressed.connect(func(): go("title"))
	var settings := btn("Settings", "Settings", "Settings", Vector2(260, 76), 28)
	settings.position = Vector2(1580, 56)
	content.add_child(settings)
	settings.pressed.connect(func():
		FE.back_to = "home"
		go("settings"))

## ENSAYO: the short tutorial match with the bench hero.
func start_tutorial() -> void:
	Tutorial.prepare_session(bench_id)
	go_call("tutorial", func(): Session.start_match())

func _build_bench() -> void:
	var pad := FE.panel(Color(FE.INK2, 0.55), Color(FE.CHALK_DIM, 0.35), 2, 40)
	pad.position = Vector2(800, 150)
	pad.custom_minimum_size = Vector2(800, 860)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(pad)
	preview = HeroPreview.new()
	preview.name = "BenchPreview"
	preview.position = Vector2(820, 160)
	preview.size = Vector2(760, 680)
	content.add_child(preview)
	hero_name = FE.shout("", 84, FE.CHALK, FE.OUTLINE if not FE.light else FE.INK3)
	hero_name.name = "BenchName"
	hero_name.position = Vector2(740, 820)
	hero_name.size = Vector2(920, 100)
	content.add_child(hero_name)
	hero_role = FE.label("", 26, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hero_role.position = Vector2(740, 922)
	hero_role.size = Vector2(920, 40)
	content.add_child(hero_role)
	var hint := FE.label("Piliin ang katropa mo sa tambayan  ·  Pick who hangs out with you", 20, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(740, 966)
	hint.size = Vector2(920, 30)
	content.add_child(hint)
	var prev := btn("BenchPrev", "<", "", Vector2(90, 90), 44)
	var next := btn("BenchNext", ">", "", Vector2(90, 90), 44)
	prev.position = Vector2(760, 470)
	next.position = Vector2(1640, 470)
	content.add_child(prev)
	content.add_child(next)
	prev.pressed.connect(func(): cycle_bench(-1))
	next.pressed.connect(func(): cycle_bench(1))

func _build_soon_tiles() -> void:
	var tiles := [["Tansan", "Tansan", Vector2(1640, 160), Vector2(200, 68)],
		["News", "Balita", Vector2(1640, 244), Vector2(200, 68)],
		["Profile", "Profile", Vector2(1640, 328), Vector2(200, 68)]]
	for t in tiles:
		var b := btn(t[0], t[1], "", t[3], 24, true)
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
	hero_role.text = ("\"%s\"  ·  %s / %s" % [data.nickname, data.role, data.secondary_role]) if data.nickname != "" else "%s / %s" % [data.role, data.secondary_role]
	card_face.set_hero(bench_id, data.color.darkened(0.25), FE.DILAW)

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if dialog:
		return
	if event.is_action_pressed("ui_page_up"):
		cycle_bench(-1)
	elif event.is_action_pressed("ui_page_down"):
		cycle_bench(1)

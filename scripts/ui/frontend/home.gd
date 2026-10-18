extends FrontScreen

## Home / "Tambayan" (docs/RESBAK.md § 6): the sari-sari store diorama behind street-sticker UI. Left
## column: the cardboard player card (click it to open the default-character picker), LARO
## (preselected), ENSAYO (the tutorial), BARKADA / LOCKER / GAWAIN greyed "Malapit na", LUMABAS back to
## the title screen (leaving steps back one screen at a time: the title is the last screen before
## quitting). The default hero is saved in profile.home_hero (JM first launch); its face is the card's
## portrait and it is who ENSAYO plays. The breakdance preview lives in the picker (hero_picker.gd).

const HOME_MUSIC := "home/home_music"
const AMBIENCE := "res://assets/audio/barangay_daylight.wav"
const SFX_HOVER := "home/ui_hover"
const SFX_CLICK := "home/ui_click"
const CHATTER := "home/chatter_%s"
const CHATTER_VARIANTS := "abcd"
const VIGNETTE_WIDTH := 0.45 ## of the screen, left side, so the UI reads over the picture
const VIGNETTE_ALPHA := 0.62
const CARD_TILT := -1.6
const SFX_ARM_DELAY := 0.4 ## no hover tick for the first-focus grab

var bench_id := "jm" ## the default hero
var card: Button
var card_name: Label
var card_stats: Label
var card_face: FaceBadge
var stat_values := {} ## "matches"/"wins"/"mvps" -> Label
var picker: HeroPicker
var diorama: HomeDiorama
var diorama_data: HomeDioramaData
var _live: SubViewportContainer
var _ambience: AudioStreamPlayer
var _sfx_armed := false
var _wiggle: Tween

func draws_backdrop() -> bool:
	return false

func build() -> void:
	var s := FE.save()
	bench_id = String(s.get_profile().get("home_hero", "jm")) if s else "jm"
	if not (bench_id in HeroData.ORDER):
		bench_id = "jm"
	Portraits.request_all()
	diorama_data = HomeDioramaData.load_data()
	_build_diorama()
	_build_vignette()
	_build_player_card()
	_build_nav()
	_build_soon_tiles()
	_refresh_card()
	_start_audio()
	card.focus_neighbor_bottom = buttons["Laro"].get_path()
	buttons["Laro"].focus_neighbor_top = card.get_path()
	navigated.connect(_on_navigated)
	get_tree().create_timer(SFX_ARM_DELAY).timeout.connect(func(): _sfx_armed = true)

func first_focus() -> Control:
	return buttons.get("Laro")

func on_back() -> void:
	if picker and is_instance_valid(picker):
		picker.close()
		return
	go("title")

# ---- backdrop ---------------------------------------------------------------------------
## The live 3D store, in its own world so it never touches the title or the match. Skipped without
## a display (the headless gate builds the screen but not the picture).
func _build_diorama() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_live = SubViewportContainer.new()
	_live.name = "DioramaView"
	_live.stretch = true
	_live.set_anchors_preset(Control.PRESET_FULL_RECT)
	_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_live)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.audio_listener_enable_3d = true
	_live.add_child(vp)
	diorama = HomeDiorama.new()
	diorama.name = "Diorama"
	diorama.audio_enabled = true
	diorama.turn_started.connect(_on_turn_started)
	vp.add_child(diorama)

## A warm dark fade over the left of the picture so the sticker UI always has contrast.
func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.09, 0.05, 0.03, VIGNETTE_ALPHA))
	g.set_color(1, Color(0.09, 0.05, 0.03, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.width = 512
	tex.height = 8
	var v := TextureRect.new()
	v.name = "Vignette"
	v.texture = tex
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	v.anchor_right = VIGNETTE_WIDTH
	v.offset_right = 0.0
	content.add_child(v)

# ---- layout -----------------------------------------------------------------------------
func _build_player_card() -> void:
	card = Button.new()
	card.name = "PlayerCard"
	card.position = Vector2(70, 48)
	card.size = Vector2(660, 196)
	card.custom_minimum_size = card.size
	card.focus_mode = Control.FOCUS_ALL
	card.tooltip_text = "Palitan ang katropa  ·  Change your character"
	var board := HomeSkin.cardboard()
	var lit := HomeSkin.cardboard()
	for st in ["normal", "pressed", "disabled"]:
		card.add_theme_stylebox_override(st, board)
	card.add_theme_stylebox_override("hover", lit)
	var ring := HomeSkin.sticker(Color(0, 0, 0, 0), Color.WHITE, 6, 22, 0)
	card.add_theme_stylebox_override("focus", ring)
	content.add_child(card)
	HomeSkin.tilt(card, CARD_TILT)
	HomeSkin.tape(card, Vector2(-30, -6), -34)
	HomeSkin.tape(card, Vector2(card.size.x - 76, -8), 30)

	var row := HBoxContainer.new()
	row.position = Vector2(30, 24)
	row.size = Vector2(card.size.x - 60, card.size.y - 48)
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	card_face = FaceBadge.new(bench_id, 140)
	card_face.name = "PlayerFace"
	row.add_child(card_face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	card_name = HomeSkin.shout(Session.player_name(), 50, HomeSkin.PAPER)
	card_name.name = "PlayerName"
	card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card_name.clip_text = true
	col.add_child(card_name)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 34)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stats)
	var s := FE.save()
	var t: Dictionary = s.get_profile().get("totals", {}) if s else {}
	for st in [["matches", "Laro", "Matches"], ["wins", "Panalo", "Wins"], ["mvps", "MVP", "MVP"]]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", -6)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := HomeSkin.shout(str(int(t.get(st[0], 0))), 40, HomeSkin.YELLOW)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cell.add_child(v)
		var p := FE.pair(st[1], st[2])
		var cap := FE.label(p[0] if p[1] == "" or p[0] == p[1] else "%s · %s" % [p[0], p[1]], 18, HomeSkin.INK)
		cell.add_child(cap)
		stats.add_child(cell)
		stat_values[st[0]] = v
	# kept for tests/tools that read the old single label
	card_stats = FE.label("Laro %d   Panalo %d   MVP %d" % [int(t.get("matches", 0)), int(t.get("wins", 0)), int(t.get("mvps", 0))], 18, HomeSkin.INK)
	card_stats.name = "PlayerStats"
	card_stats.visible = false
	col.add_child(card_stats)

	var badge := PanelContainer.new()
	badge.name = "Palitan"
	badge.add_theme_stylebox_override("panel", HomeSkin.sticker(HomeSkin.RED, HomeSkin.INK, 3, 10, 4))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := HomeSkin.shout("PALITAN", 26, HomeSkin.PAPER)
	badge.add_child(bl)
	badge.position = Vector2(card.size.x - 186, card.size.y - 38)
	badge.rotation_degrees = 5.0
	card.add_child(badge)

	card.pressed.connect(open_picker)
	card.mouse_entered.connect(_wiggle_card)
	card.focus_entered.connect(_wiggle_card)
	_sfx(card)

func _wiggle_card() -> void:
	if _wiggle and _wiggle.is_valid():
		_wiggle.kill()
	_wiggle = card.create_tween()
	_wiggle.tween_property(card, "rotation_degrees", CARD_TILT + 2.2, 0.07)
	_wiggle.tween_property(card, "rotation_degrees", CARD_TILT - 1.4, 0.09)
	_wiggle.tween_property(card, "rotation_degrees", CARD_TILT, 0.08)

func _build_nav() -> void:
	var col := VBoxContainer.new()
	col.name = "Nav"
	col.position = Vector2(86, 290)
	col.add_theme_constant_override("separation", 16)
	content.add_child(col)
	# The column ends at x = 566 so Inday (the leftmost hero) stands clear of it in the 3D backdrop.
	var laro := btn("Laro", "LARO", "Play", Vector2(480, 150), 84, false, true)
	HomeSkin.skin_button(laro, "primary")
	col.add_child(laro)
	laro.pressed.connect(func(): go("play_menu"))
	var ensayo := btn("Ensayo", "ENSAYO", "Tutorial", Vector2(480, 100), 40)
	HomeSkin.skin_button(ensayo)
	col.add_child(ensayo)
	ensayo.pressed.connect(start_tutorial)
	var soon_row := HBoxContainer.new()
	soon_row.add_theme_constant_override("separation", 14)
	col.add_child(soon_row)
	for g in [["Barkada", "BARKADA"], ["Locker", "LOCKER"], ["Gawain", "GAWAIN"]]:
		var b := btn(g[0], g[1], "", Vector2(150, 92), 24, true)
		HomeSkin.skin_button(b)
		soon_row.add_child(b)
	col.add_child(FE.spacer(8))
	var quit := btn("Lumabas", "LUMABAS", "Back to title", Vector2(400, 92), 38)
	HomeSkin.skin_button(quit)
	col.add_child(quit)
	quit.pressed.connect(func(): go("title"))
	var settings := btn("Settings", "Settings", "", Vector2(240, 76), 32)
	HomeSkin.skin_button(settings)
	settings.position = Vector2(1620, 48)
	content.add_child(settings)
	settings.pressed.connect(func():
		FE.back_to = "home"
		go("settings"))
	for key in ["Laro", "Ensayo", "Lumabas", "Settings"]:
		_sfx(buttons[key])
	for i in range(3):
		var b := buttons[["Barkada", "Locker", "Gawain"][i]] as Button
		_sfx(b)

## ENSAYO: the short tutorial match with the default hero.
func start_tutorial() -> void:
	Tutorial.prepare_session(bench_id)
	go_call("tutorial", func(): Session.start_match())

func _build_soon_tiles() -> void:
	var tiles := [["Tansan", "Tansan", Vector2(1660, 144)],
		["News", "Balita", Vector2(1660, 218)],
		["Profile", "Profile", Vector2(1660, 292)]]
	for t in tiles:
		var b := btn(t[0], t[1], "", Vector2(200, 64), 24, true)
		HomeSkin.skin_button(b)
		b.position = t[2]
		content.add_child(b)

# ---- default hero -----------------------------------------------------------------------
func open_picker() -> HeroPicker:
	if picker and is_instance_valid(picker):
		return picker
	_freeze(content, true)
	picker = HeroPicker.new(bench_id)
	picker.chosen.connect(set_bench)
	picker.closed.connect(_on_picker_closed)
	add_child(picker)
	return picker

func _on_picker_closed() -> void:
	picker = null
	_freeze(content, false)
	if is_inside_tree() and card and card.is_inside_tree():
		card.grab_focus.call_deferred()

func set_bench(id: String) -> void:
	bench_id = id
	var s := FE.save()
	if s:
		s.profile["home_hero"] = id
		s.save_profile()
	_refresh_card()

func _refresh_card() -> void:
	var data := HeroData.load_hero(bench_id)
	card_face.set_hero(bench_id, data.color.darkened(0.25), HomeSkin.YELLOW)

# ---- audio ------------------------------------------------------------------------------
func _start_audio() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio == null:
		return
	audio.play_music(HOME_MUSIC, diorama_data.music_fade_in)
	if ResourceLoader.exists(AMBIENCE):
		var stream := (load(AMBIENCE) as AudioStream).duplicate()
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(stream as AudioStreamWAV).loop_end = int(stream.get_length() * (stream as AudioStreamWAV).mix_rate)
		_ambience = AudioStreamPlayer.new()
		_ambience.name = "Ambience"
		_ambience.stream = stream
		_ambience.bus = "Effects"
		_ambience.volume_db = diorama_data.ambience_db
		add_child(_ambience)
		_ambience.play()

## Fade the Home music out when leaving for anywhere but Settings (which comes straight back).
func _on_navigated(target: String) -> void:
	if target == "settings":
		return
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.stop_music(diorama_data.music_fade_out)
	if _ambience:
		var tw := _ambience.create_tween()
		tw.tween_property(_ambience, "volume_db", -60.0, diorama_data.music_fade_out)

## A hero starts talking: a short synthesised babble, pitched to the speaker.
func _on_turn_started(hero_id: String, line_id: int) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio == null:
		return
	var variant := CHATTER_VARIANTS[line_id % CHATTER_VARIANTS.length()]
	var pitch: float = float(diorama_data.chatter_pitch.get(hero_id, 1.0))
	audio.play(CHATTER % variant, "", Vector3.INF, "Voices", pitch, diorama_data.chatter_db)

func _sfx(b: Button) -> void:
	if b.disabled:
		return
	b.mouse_entered.connect(func(): _tick(SFX_HOVER))
	b.focus_entered.connect(func(): _tick(SFX_HOVER))
	b.pressed.connect(func(): _tick(SFX_CLICK, true))

func _tick(sound: String, always := false) -> void:
	if not (_sfx_armed or always):
		return
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play(sound)

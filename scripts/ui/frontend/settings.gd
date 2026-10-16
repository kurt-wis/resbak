extends FrontScreen

## Settings (docs/RESBAK.md § 10), basic version: tabs Gameplay, Controls, Video, Audio,
## Accessibility; every row reads and writes Save (settings.cfg is written on every change)
## and applies instantly (audio volumes, display mode). IBALIK SA DEFAULT resets the open tab.
## Online-only rows (All chat, Region...) are not shown. Escape goes back.

## [section, key, Filipino, English, kind, options/range]
const ROWS := {
	"gameplay": [
		["gameplay", "danger_border", "Babala sa panganib", "Danger border", "bool", null],
		["gameplay", "tag_assist", "Tulong sa taya", "Tag assist", "bool", null],
		["gameplay", "camera_shake", "Yanig ng kamera", "Camera shake", "slider", [0.0, 1.0, 0.05]],
		["gameplay", "minimap_size", "Laki ng mapa", "Minimap size", "cycle", ["S", "M", "L"]],
		["gameplay", "minimap_position", "Puwesto ng mapa", "Minimap position", "cycle", ["top_right", "bottom_right"]],
		["gameplay", "tag_feed", "Listahan ng huli", "Tag feed", "bool", null],
		["gameplay", "team_colours", "Kulay ng koponan", "Team colours", "cycle", ["fixed", "relative"]],
	],
	"controls": [
		["controls", "mouse_sensitivity", "Bilis ng mouse", "Mouse sensitivity", "slider", [0.1, 3.0, 0.1]],
		["controls", "stick_dead_zone", "Dead zone ng stick", "Stick dead zone", "slider", [0.0, 0.3, 0.05]],
		["controls", "vibration", "Panginig", "Vibration", "bool", null],
		["controls", "button_icons", "Mga icon", "Button icons", "cycle", ["auto", "xbox", "playstation", "generic"]],
	],
	"video": [
		["video", "display_mode", "Display", "Display mode", "cycle", ["windowed", "borderless", "fullscreen"]],
		["video", "vsync", "VSync", "VSync", "bool", null],
		["video", "frame_cap", "Limit ng frame", "Frame cap", "cycle", [30, 60, 120, 0]],
		["video", "quality", "Kalidad", "Quality preset", "cycle", ["auto", "mababa", "katamtaman", "mataas"]],
		["video", "brightness", "Liwanag", "Brightness", "slider", [0.0, 100.0, 1.0]],
		["video", "interface_size", "Laki ng interface", "Interface size", "slider", [0.8, 1.3, 0.05]],
	],
	"audio": [
		["audio", "master", "Lahat", "Master", "slider", [0.0, 100.0, 1.0]],
		["audio", "music", "Musika", "Music", "slider", [0.0, 100.0, 1.0]],
		["audio", "effects", "Tunog", "Sound effects", "slider", [0.0, 100.0, 1.0]],
		["audio", "voices", "Boses", "Voices and banter", "slider", [0.0, 100.0, 1.0]],
		["audio", "announcer", "Tagapagbalita", "Announcer", "slider", [0.0, 100.0, 1.0]],
	],
	"accessibility": [
		["accessibility", "colour_mode", "Kulay", "Colour mode", "cycle", ["default", "deuteranopia", "protanopia", "tritanopia", "high_contrast"]],
		["accessibility", "subtitles", "Subtitle", "Subtitles", "bool", null],
		["accessibility", "subtitle_size", "Laki ng subtitle", "Subtitle size", "cycle", ["S", "M", "L"]],
		["accessibility", "sound_cues", "Tunog sa screen", "Sound cues on screen", "bool", null],
		["accessibility", "reduce_flashing", "Bawas kislap", "Reduce flashing", "bool", null],
		["accessibility", "reduce_motion", "Bawas galaw ng kamera", "Reduce camera motion", "bool", null],
		["accessibility", "capture_input", "Pag-agaw", "Capture input", "cycle", ["hold", "toggle"]],
	],
}
const TABS := [["gameplay", "Laro", "Gameplay"], ["controls", "Kontrol", "Controls"], ["video", "Video", "Video"], ["audio", "Tunog", "Audio"], ["accessibility", "Accessibility", "Accessibility"]]

var tab := "gameplay"
var _rows_box: VBoxContainer
var row_controls := {} ## "section/key" -> Control (tests)

func build() -> void:
	var v := VBoxContainer.new()
	v.position = Vector2(160, 60)
	v.custom_minimum_size = Vector2(1600, 0)
	v.add_theme_constant_override("separation", 20)
	content.add_child(v)
	v.add_child(FE.bi_box("MGA SETTING", "Settings", 56, FE.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	v.add_child(tabs)
	for t in TABS:
		var b := btn("Tab_" + String(t[0]), String(t[1]), String(t[2]), Vector2(280, 76), 28)
		b.pressed.connect(show_tab.bind(String(t[0])))
		tabs.add_child(b)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 10)
	v.add_child(_rows_box)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 24)
	v.add_child(bottom)
	var reset := btn("Reset", "IBALIK SA DEFAULT", "Reset to default", Vector2(440, 72), 28)
	reset.pressed.connect(reset_tab)
	bottom.add_child(reset)
	var back := btn("Back", "BUMALIK", "Back", Vector2(300, 72), 28)
	back.pressed.connect(on_back)
	bottom.add_child(back)
	show_tab("gameplay")

func first_focus() -> Control:
	return buttons.get("Tab_gameplay")

func on_back() -> void:
	var s := FE.save()
	go("home" if s and bool(s.get_profile().get("setup_done", false)) else "title")

func show_tab(key: String) -> void:
	tab = key
	row_controls.clear()
	for c in _rows_box.get_children():
		c.queue_free()
	for r in ROWS[key]:
		_rows_box.add_child(_row(r))

func reset_tab() -> void:
	var s := FE.save()
	if s:
		s.reset_section(tab)
	_apply()
	show_tab(tab)

func _value(r: Array) -> Variant:
	var s := FE.save()
	return s.get_setting(r[0], r[1]) if s else null

func set_value(section: String, key: String, value: Variant) -> void:
	var s := FE.save()
	if s:
		s.set_setting(section, key, value)
	_apply()

func _apply() -> void:
	FE.apply_all()

func _row(r: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	var name_box := FE.bi_box(String(r[2]), String(r[3]), 26, FE.CHALK, HORIZONTAL_ALIGNMENT_LEFT)
	name_box.custom_minimum_size = Vector2(620, 0)
	h.add_child(name_box)
	var id := "%s/%s" % [r[0], r[1]]
	var val: Variant = _value(r)
	match String(r[4]):
		"bool":
			var b := FE.button("Bukas" if bool(val) else "Sarado", "On" if bool(val) else "Off", Vector2(260, 60), 26)
			b.pressed.connect(func():
				var nv := not bool(_value(r))
				set_value(r[0], r[1], nv)
				FE.set_button_text(b, "Bukas" if nv else "Sarado", "On" if nv else "Off"))
			h.add_child(b)
			row_controls[id] = b
		"cycle":
			var opts: Array = r[5]
			var b := FE.button(_opt_text(val), "", Vector2(360, 60), 26)
			b.pressed.connect(func():
				var cur: Variant = _value(r)
				var i := opts.find(cur)
				var nv: Variant = opts[(i + 1) % opts.size()]
				set_value(r[0], r[1], nv)
				FE.set_button_text(b, _opt_text(nv), ""))
			h.add_child(b)
			row_controls[id] = b
		"slider":
			var rng: Array = r[5]
			var sl := HSlider.new()
			sl.min_value = rng[0]
			sl.max_value = rng[1]
			sl.step = rng[2]
			sl.value = float(val) if val != null else float(rng[0])
			sl.custom_minimum_size = Vector2(520, 40)
			sl.focus_mode = Control.FOCUS_ALL
			var shown := FE.label(_num(sl.value, rng), 26, FE.CHALK_DIM)
			sl.value_changed.connect(func(x: float):
				set_value(r[0], r[1], x)
				shown.text = _num(x, rng))
			h.add_child(sl)
			h.add_child(shown)
			row_controls[id] = sl
	return h

func _opt_text(v: Variant) -> String:
	if typeof(v) == TYPE_INT:
		return "Walang limit" if int(v) == 0 else "%d fps" % int(v)
	return String(v).replace("_", " ").capitalize()

func _num(x: float, rng: Array) -> String:
	if float(rng[1]) <= 3.0 and float(rng[2]) < 1.0:
		return "%d%%" % roundi(x * 100.0) if float(rng[1]) <= 1.3 else "%.1f" % x
	return "%d" % roundi(x)

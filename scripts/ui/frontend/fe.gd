class_name FE
extends RefCounted

## Front-end toolkit (docs/RESBAK.md § 6 "Front end", § 13 strings): palette, theme, the
## Filipino-over-English label rule, button builders, scene routing with the 0.3 s chalk
## wipe, and Settings application (display, volumes, key bindings). Presentation only.

## Palette. INK* are backgrounds and panels, CHALK* the text on them; Settings > Accessibility >
## Menu theme (dark or light, also asked in first-time setup) swaps them through apply_theme().
## OUTLINE and ON_ACCENT stay dark in both themes (logo outlines, text on yellow buttons).
static var INK := Color("15141c")
static var INK2 := Color("25222f")
static var INK3 := Color("34303f")
static var CHALK := Color("f1ebdd")
static var CHALK_DIM := Color("b9b2a3")
static var GOLD := Color("ffd34d")
static var GREY := Color("77747f")
static var ORANGE := Color("ff8a3d")
static var SILVER := Color("c9d1da")
static var light := false
const DILAW := Color("f5c518")
const LILA := Color("9b59d6")
const OUTLINE := Color("15141c")
const ON_ACCENT := Color("15141c")

const THEMES := {
	"dark": {"INK": "15141c", "INK2": "25222f", "INK3": "34303f", "CHALK": "f1ebdd", "CHALK_DIM": "b9b2a3",
		"GOLD": "ffd34d", "GREY": "77747f", "ORANGE": "ff8a3d", "SILVER": "c9d1da"},
	"light": {"INK": "f3ece0", "INK2": "fffaf1", "INK3": "eadfcc", "CHALK": "211e29", "CHALK_DIM": "5b5566",
		"GOLD": "a86f00", "GREY": "8d8796", "ORANGE": "c4520f", "SILVER": "596270"},
}

const SCENE_DIR := "res://scenes/frontend/"
const VERSION := "0.1.2 (Demo build)"

## Apply the saved menu theme ("dark" / "light"). Rebuilds the shared Theme.
static func apply_theme(mode := "") -> void:
	if mode == "":
		mode = String(setting("accessibility", "theme"))
	if not THEMES.has(mode):
		mode = "dark"
	var p: Dictionary = THEMES[mode]
	INK = Color(p.INK)
	INK2 = Color(p.INK2)
	INK3 = Color(p.INK3)
	CHALK = Color(p.CHALK)
	CHALK_DIM = Color(p.CHALK_DIM)
	GOLD = Color(p.GOLD)
	GREY = Color(p.GREY)
	ORANGE = Color(p.ORANGE)
	SILVER = Color(p.SILVER)
	light = mode == "light"
	_theme = null

## Maps: id -> display. Only maps the match scene can load are playable.
const MAP_POOL := [
	{"id": "barangay_court", "fil": "Barangay Court", "en": "Barangay Court", "line": "Sa Barangay Court tayo!"},
	{"id": "construction_site", "fil": "Konstruksyon", "en": "Construction Site", "line": "Sa Konstruksyon tayo!"},
	{"id": "plaza", "fil": "Plaza", "en": "Plaza", "line": "Sa Plaza tayo!"},
	{"id": "tambakan", "fil": "Tambakan", "en": "Tambakan", "line": "Sa Tambakan tayo!"},
]
const DIFFICULTIES := [
	{"fil": "Madali", "en": "Easy"},
	{"fil": "Katamtaman", "en": "Normal"},
	{"fil": "Mahirap", "en": "Hard"},
]

## Where Settings returns to (set by whoever opens it).
static var back_to := "home"
static var _theme: Theme

# ---- autoload access (static code can't rely on globals in every context) ---------------
static func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root

static func save() -> Node:
	return _root().get_node_or_null("Save")

static func session() -> Node:
	return _root().get_node_or_null("Session")

static func setting(section: String, key: String) -> Variant:
	var s := save()
	return s.get_setting(section, key) if s else Save.SETTINGS_DEFAULTS.get(section, {}).get(key)

# ---- text -------------------------------------------------------------------------------
## [primary, secondary] for a Filipino/English pair under the Interface language setting.
static func pair(fil: String, en: String) -> Array:
	if en == "" or fil == en:
		return [fil, ""]
	match String(setting("language_network", "language")):
		"en":
			return [en, ""]
		"fil":
			return [fil, ""]
	return [fil, en]

static func available_maps() -> Array:
	var ids: Array = (load("res://scripts/match/match_scene.gd").MAPS as Dictionary).keys()
	var out: Array = []
	for m in MAP_POOL:
		if m.id in ids:
			out.append(m)
	return out

static func map_info(id: String) -> Dictionary:
	for m in MAP_POOL:
		if m.id == id:
			return m
	return MAP_POOL[0]

# ---- widgets ----------------------------------------------------------------------------
static func label(text: String, size := 24, color := CHALK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Outlined chalk-poster text for logos and banners.
static func shout(text: String, size: int, color := GOLD, outline := OUTLINE) -> Label:
	var l := label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", UiFonts.display())
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", maxi(6, size / 8))
	return l

## Filipino line with the smaller English line under it.
static func bi_box(fil: String, en: String, fsize := 28, color := CHALK, align := HORIZONTAL_ALIGNMENT_CENTER) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -2)
	var p := pair(fil, en)
	var l1 := label(p[0], fsize, color, align)
	l1.name = "Fil"
	box.add_child(l1)
	var l2 := label(p[1], maxi(18, int(fsize * 0.62)), _secondary(color), align)
	l2.name = "En"
	l2.visible = p[1] != ""
	box.add_child(l2)
	return box

## The smaller English line under a Filipino label: a quieter shade of the same colour.
static func _secondary(color: Color) -> Color:
	if color == ON_ACCENT:
		return Color(ON_ACCENT, 0.75)
	return color.darkened(0.25) if not light else color.lightened(0.25)

static func set_bi(box: Node, fil: String, en: String) -> void:
	var p := pair(fil, en)
	(box.get_node("Fil") as Label).text = p[0]
	var l2 := box.get_node("En") as Label
	l2.text = p[1]
	l2.visible = p[1] != ""

static func box_style(fill: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.set_border_width_all(bw)
	s.border_color = border
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func panel(fill := INK2, border := CHALK_DIM, bw := 2, radius := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_style(fill, border, bw, radius))
	return p

## A bilingual button. `greyed` = inert "Malapit na" (disabled, dimmed, tagged).
static func button(fil: String, en := "", size := Vector2(300, 72), fsize := 30, greyed := false, primary := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.set_meta("fil", fil)
	b.clip_contents = true
	var box := bi_box(fil, en, fsize, ON_ACCENT if primary else CHALK)
	(box.get_node("Fil") as Label).add_theme_font_override("font", UiFonts.display())
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.name = "Text"
	b.add_child(box)
	if primary:
		b.add_theme_stylebox_override("normal", box_style(DILAW, OUTLINE, 3))
		b.add_theme_stylebox_override("hover", box_style(DILAW.lightened(0.18), OUTLINE, 4))
		b.add_theme_stylebox_override("pressed", box_style(DILAW.darkened(0.15), OUTLINE, 3))
		b.add_theme_stylebox_override("focus", box_style(DILAW.lightened(0.1), OUTLINE, 6))
	if greyed:
		set_greyed(b, true)
	return b

static func set_greyed(b: Button, greyed: bool) -> void:
	b.disabled = greyed
	b.focus_mode = Control.FOCUS_NONE if greyed else Control.FOCUS_ALL
	b.modulate = Color(1, 1, 1, 0.42) if greyed else Color.WHITE
	b.tooltip_text = "Malapit na" if greyed else ""
	var tag := b.get_node_or_null("SoonTag") as Label
	if greyed and tag == null:
		tag = label("Malapit na", 18, ORANGE, HORIZONTAL_ALIGNMENT_RIGHT)
		tag.name = "SoonTag"
		tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		tag.offset_left = -170
		tag.offset_right = -10
		tag.offset_top = 4
		if b.custom_minimum_size.x < 320.0: # small tiles: the tag sits under the label
			tag.add_theme_font_size_override("font_size", 16)
			tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.offset_top = -22
			tag.offset_bottom = -2
		b.add_child(tag)
	elif not greyed and tag:
		tag.queue_free()

static func set_button_text(b: Button, fil: String, en := "") -> void:
	b.set_meta("fil", fil)
	set_bi(b.get_node("Text"), fil, en)

static func spacer(h := 0, w := 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# ---- theme ------------------------------------------------------------------------------
static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.set_default_font(UiFonts.body())
	t.set_default_font_size(24)
	t.set_color("font_color", "Label", CHALK)
	t.set_color("font_color", "Button", CHALK)
	t.set_color("font_hover_color", "Button", CHALK if light else Color.WHITE)
	t.set_color("font_focus_color", "Button", CHALK if light else Color.WHITE)
	t.set_color("font_pressed_color", "Button", CHALK if light else Color.WHITE)
	t.set_color("font_disabled_color", "Button", GREY)
	t.set_font_size("font_size", "Button", 24)
	t.set_stylebox("normal", "Button", box_style(INK2, Color(CHALK, 0.45), 2))
	t.set_stylebox("hover", "Button", box_style(INK3, CHALK, 3))
	t.set_stylebox("pressed", "Button", box_style(INK, DILAW, 3))
	t.set_stylebox("disabled", "Button", box_style(INK2.darkened(0.2), Color(GREY, 0.5), 2))
	t.set_stylebox("focus", "Button", box_style(INK3, DILAW, 5))
	t.set_color("font_color", "LineEdit", CHALK)
	t.set_font_size("font_size", "LineEdit", 32)
	t.set_stylebox("normal", "LineEdit", box_style(INK, CHALK_DIM, 2, 10))
	t.set_stylebox("focus", "LineEdit", box_style(INK, DILAW, 4, 10))
	# sliders: a chunky groove and a round grabber
	var groove := box_style(INK, Color(CHALK_DIM, 0.6), 2, 8)
	groove.content_margin_top = 8
	groove.content_margin_bottom = 8
	t.set_stylebox("slider", "HSlider", groove)
	t.set_stylebox("grabber_area", "HSlider", box_style(DILAW.darkened(0.2), Color(0, 0, 0, 0), 0, 8))
	t.set_stylebox("grabber_area_highlight", "HSlider", box_style(DILAW, Color(0, 0, 0, 0), 0, 8))
	var knob := _knob(30, CHALK)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", _knob(34, DILAW))
	t.set_icon("grabber_disabled", "HSlider", _knob(30, GREY))
	t.set_constant("center_grabber", "HSlider", 0)
	t.set_stylebox("panel", "PanelContainer", box_style(INK2, CHALK_DIM, 2, 18))
	_theme = t
	return t

static func _knob(d: int, c: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in range(d):
		for x in range(d):
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if dist <= r - 1.0:
				img.set_pixel(x, y, c if dist < r - 4.0 else INK)
	return ImageTexture.create_from_image(img)

# ---- routing + chalk wipe ---------------------------------------------------------------
static func scene_path(screen: String) -> String:
	return screen if screen.begins_with("res://") else SCENE_DIR + screen + ".tscn"

static func wipe() -> ChalkWipe:
	var root := _root()
	var w := root.get_node_or_null("ChalkWipe") as ChalkWipe
	if w == null:
		w = ChalkWipe.new()
		w.name = "ChalkWipe"
		root.add_child(w)
	return w

## Change to a front-end screen ("home", "settings", ...) or any res:// scene through the wipe.
static func go(node: Node, screen: String) -> void:
	var tree := node.get_tree()
	var path := scene_path(screen)
	wipe().run(func(): tree.change_scene_to_file(path))

## Run any callable at the wipe's midpoint (e.g. Session.start_match).
static func go_call(_node: Node, action: Callable) -> void:
	wipe().run(action)

# ---- applying settings ------------------------------------------------------------------
const QUALITY_PRESETS := {
	"mababa": {"shadows": "off", "effects": "low", "render_scale": 0.75},
	"katamtaman": {"shadows": "low", "effects": "low", "render_scale": 1.0},
	"mataas": {"shadows": "high", "effects": "high", "render_scale": 1.0},
}

static func apply_all() -> void:
	apply_theme()
	apply_display()
	apply_audio()
	apply_bindings()

static func apply_audio() -> void:
	var a := _root().get_node_or_null("Audio")
	if a and a.has_method("apply_volumes"):
		a.apply_volumes()

static func apply_display() -> void:
	var root := _root()
	var mode := String(setting("video", "display_mode"))
	match mode:
		"windowed":
			root.mode = Window.MODE_WINDOWED
			root.borderless = false
		"fullscreen":
			root.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			root.borderless = true
			root.mode = Window.MODE_FULLSCREEN
	if mode == "windowed":
		var res := String(setting("video", "resolution"))
		if res != "monitor" and "x" in res:
			var wh := res.split("x")
			root.size = Vector2i(int(wh[0]), int(wh[1]))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(setting("video", "vsync")) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(setting("video", "frame_cap"))
	root.scaling_3d_scale = clampf(float(setting("video", "render_scale")), 0.5, 1.0)
	root.content_scale_factor = clampf(float(setting("video", "interface_size")), 0.8, 1.3)

## Re-apply saved keyboard rebinds (controls.bind_<action> = physical keycode).
static func apply_bindings() -> void:
	Controls.ensure()
	var s := save()
	if s == null:
		return
	for action in Controls.DEFS:
		var code: Variant = s.get_setting("controls", "bind_" + action)
		if code != null:
			set_binding(action, int(code), false)

static func binding_of(action: String) -> int:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return (e as InputEventKey).physical_keycode
	return KEY_NONE

static func set_binding(action: String, keycode: int, persist := true) -> void:
	Controls.ensure()
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode as Key
	InputMap.action_add_event(action, ev)
	if persist and save():
		save().set_setting("controls", "bind_" + action, keycode)

static func reset_bindings() -> void:
	for action in Controls.DEFS:
		var keys: Array = Controls.DEFS[action].get("keys", [])
		if keys.is_empty():
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
		for k in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

# ---- logo -------------------------------------------------------------------------------
## The RESBAK! wordmark: chalk-yellow poster lettering, orange offset shadow, slight tilt.
static func logo(size := 180) -> Label:
	var l := shout("RESBAK!", size, Color("ffd34d"), OUTLINE)
	l.add_theme_color_override("font_shadow_color", ORANGE)
	l.add_theme_constant_override("shadow_offset_x", maxi(4, size / 22))
	l.add_theme_constant_override("shadow_offset_y", maxi(4, size / 22))
	l.name = "Logo"
	l.resized.connect(func(): l.pivot_offset = l.size * 0.5)
	l.rotation = deg_to_rad(-2.5)
	return l

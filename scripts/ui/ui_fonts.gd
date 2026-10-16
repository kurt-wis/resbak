class_name UiFonts
extends RefCounted

## The game's two typefaces, taken from the system (Windows ships Bahnschrift and Segoe UI;
## nothing is bundled). `display` is the sporty condensed face for numbers, titles and the
## HUD; `body` is the readable face for menus. Missing fonts fall back to Godot's default.

static var _display: Font
static var _body: Font

static func display() -> Font:
	if _display == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Black", "Arial Black", "Sans-Serif"])
		f.font_weight = 700
		f.font_stretch = 87
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.allow_system_fallback = true
		_display = f
	return _display

static func body() -> Font:
	if _body == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "Bahnschrift", "Arial", "Sans-Serif"])
		f.font_weight = 600
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.allow_system_fallback = true
		_body = f
	return _body

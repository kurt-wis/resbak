class_name HomeSkin
extends RefCounted

## The Home screen's street-sticker and cardboard look (spec § 6 "Home"): hand-cut paper stickers with
## a dark outline and a hard drop shadow, on corrugated cardboard held down with masking tape. Shared by
## Home and the hero picker. Colours here are the sticker palette; text on a sticker is always dark ink.

const CARDBOARD := "res://assets/ui/home/cardboard.png"
const CARDBOARD_DARK := "res://assets/ui/home/cardboard_dark.png"
const TAPE := "res://assets/ui/home/tape.png"
const CARD_MARGIN := 30 ## 9-slice margin of the cardboard texture, px

const INK := Color("2a1a0e")
const PAPER := Color("f3e3c0")
const YELLOW := Color("ffd23f")
const RED := Color("d9452f")
const SHADOW := Color(0, 0, 0, 0.45)

static func font() -> Font:
	return UiFonts.home_display()

## A paper sticker: fill, dark outline, hard drop shadow `lift` px down-right.
static func sticker(fill: Color, border := INK, bw := 4, radius := 16, lift := 7) -> StyleBoxFlat:
	var s := FE.box_style(fill, border, bw, radius)
	s.shadow_color = SHADOW
	s.shadow_size = 1
	s.shadow_offset = Vector2(lift * 0.7, lift)
	return s

## Corrugated cardboard, 9-sliced (falls back to a flat brown box if the texture is missing).
static func cardboard(dark := false) -> StyleBox:
	var path := CARDBOARD_DARK if dark else CARDBOARD
	if not ResourceLoader.exists(path):
		return FE.box_style(Color("b98c5c"), INK, 3, 22)
	var s := StyleBoxTexture.new()
	s.texture = load(path)
	s.set_texture_margin_all(CARD_MARGIN)
	s.set_content_margin_all(24)
	return s

## A piece of masking tape stuck across a corner (decorative, ignores the mouse).
static func tape(parent: Control, pos: Vector2, deg: float) -> TextureRect:
	var t := TextureRect.new()
	t.name = "Tape"
	if ResourceLoader.exists(TAPE):
		t.texture = load(TAPE)
	t.size = Vector2(100, 34)
	t.position = pos
	t.pivot_offset = t.size * 0.5
	t.rotation_degrees = deg
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

## A round outlined badge (the reference's stat circles: a ring with the number inside).
static func ring(diameter: float, fill: Color, border := INK, bw := 3) -> StyleBoxFlat:
	var s := FE.box_style(fill, border, bw, int(diameter * 0.5))
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s

## Re-skin an FE.button as a sticker. kind: "primary" (yellow PLAY), "paper" (cream), "locked"
## (translucent, for tiles that are not built yet) or "settings".
## `english_main` swaps the emphasis of the two label lines: the reference labels the Home column in
## English with the Filipino name as the smaller line, while the rest of the front end is Filipino-first.
static func skin_button(b: Button, kind := "paper", english_main := false) -> void:
	var fil := b.get_node_or_null("Text/Fil") as Label
	var en := b.get_node_or_null("Text/En") as Label
	var two := en != null and en.visible
	if fil:
		fil.add_theme_font_override("font", font())
	if en:
		en.add_theme_font_override("font", font())
	if kind == "locked":
		var fill := Color(0.86, 0.87, 0.89, 0.30)
		var edge := Color(1, 1, 1, 0.46)
		for st in ["normal", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, FE.box_style(fill, edge, 2, 14))
		b.add_theme_stylebox_override("hover", FE.box_style(Color(0.90, 0.91, 0.93, 0.38), edge, 2, 14))
		b.add_theme_stylebox_override("focus", FE.box_style(fill, Color(1, 1, 1, 0.85), 4, 14))
		if fil:
			fil.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
			fil.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.11, 0.55))
		if en:
			en.add_theme_color_override("font_color", Color(1, 1, 1, 0.70))
		return
	var fill := YELLOW if kind == "primary" else PAPER
	var edge := Color("fff6dc") if kind == "primary" else INK
	var bw := 8 if kind == "primary" else 4
	var lift := 9 if kind == "primary" else 7
	var radius := 26 if kind == "primary" else 18
	b.add_theme_stylebox_override("normal", sticker(fill, edge, bw, radius, lift))
	b.add_theme_stylebox_override("hover", sticker(fill.lightened(0.14), edge, bw, radius, lift + 2))
	b.add_theme_stylebox_override("pressed", sticker(fill.darkened(0.12), edge, bw, radius, maxf(2, lift - 5)))
	b.add_theme_stylebox_override("focus", sticker(fill.lightened(0.1), Color.WHITE, bw + 3, radius, lift + 2))
	b.add_theme_stylebox_override("disabled", sticker(fill, edge, bw, radius, lift))
	if english_main and two and fil and en:
		var big := fil.get_theme_font_size("font_size")
		fil.add_theme_font_size_override("font_size", maxi(12, int(big * 0.42)))
		en.add_theme_font_size_override("font_size", big)
		fil.add_theme_color_override("font_color", Color(INK, 0.66))
		en.add_theme_color_override("font_color", INK)
		return
	if fil:
		fil.add_theme_color_override("font_color", INK)
	if en:
		en.add_theme_color_override("font_color", Color(INK, 0.72))

## Lettering for stickers: cream fill with a dark outline, in the Home display face.
static func shout(text: String, size: int, color := PAPER, outline := INK) -> Label:
	var l := FE.shout(text, size, color, outline)
	l.add_theme_font_override("font", font())
	return l

## Rotate a control around its centre (re-pivoting whenever it is resized).
static func tilt(c: Control, deg: float) -> void:
	c.rotation_degrees = deg
	c.pivot_offset = c.size * 0.5
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)

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

## Re-skin an FE.button as a sticker. kind: "primary" (yellow) or "paper" (cream).
static func skin_button(b: Button, kind := "paper") -> void:
	var fill := YELLOW if kind == "primary" else PAPER
	b.add_theme_stylebox_override("normal", sticker(fill))
	b.add_theme_stylebox_override("hover", sticker(fill.lightened(0.14), INK, 5, 16, 9))
	b.add_theme_stylebox_override("pressed", sticker(fill.darkened(0.12), INK, 5, 16, 2))
	b.add_theme_stylebox_override("focus", sticker(fill.lightened(0.1), Color.WHITE, 7, 16, 9))
	b.add_theme_stylebox_override("disabled", sticker(fill))
	var fil := b.get_node_or_null("Text/Fil") as Label
	if fil:
		fil.add_theme_font_override("font", font())
		fil.add_theme_color_override("font_color", INK)
	var en := b.get_node_or_null("Text/En") as Label
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

class_name HudStyle
extends RefCounted

## Shared look and drawing helpers for the match HUD (docs/RESBAK.md § 7, § 10: UI text is
## sans-serif and at least 18 px at 1080p, contrast >= 4.5:1 -> light text, dark outline,
## dark panels). Every font size goes through MIN_FONT. v0.1.1: bigger, rounded panels and the
## condensed display face (UiFonts) so the HUD reads at a glance without covering the court.

const MIN_FONT := 18
const INK := Color("18232c")
const PANEL := Color(0.06, 0.07, 0.1, 0.82)
const PANEL_EDGE := Color(1, 1, 1, 0.22)
const GOLD := Color("ffd34d")
const ORANGE := Color("ff8a1f")
const GREY := Color("8c8c96")
const DIM := Color(0.8, 0.82, 0.88)
const RED := Color("ff5a3c")
const GREEN := Color("6ee08a")
const RADIUS := 14

static func font() -> Font:
	return UiFonts.display()

## A Label with outline, a size of at least MIN_FONT, ignoring the mouse.
static func label(parent: Node, size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, color: Color = Color.WHITE, outline := 8) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", maxi(size, MIN_FONT))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(l)
	return l

static func set_color(l: Label, color: Color) -> void:
	l.add_theme_color_override("font_color", color)

## draw_string with an outline. `pos` is the baseline start (or the centre line for
## centred text with `width`).
static func text(ci: CanvasItem, s: String, pos: Vector2, size: int, color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 8) -> void:
	var sz := maxi(size, MIN_FONT)
	if outline > 0:
		ci.draw_string_outline(font(), pos, s, align, width, sz, outline, INK)
	ci.draw_string(font(), pos, s, align, width, sz, color)

static func text_width(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(size, MIN_FONT)).x

## Text centred in a rect.
static func text_in(ci: CanvasItem, s: String, rect: Rect2, size: int, color: Color = Color.WHITE, outline := 8) -> void:
	var sz := maxi(size, MIN_FONT)
	text(ci, s, Vector2(rect.position.x, rect.get_center().y + sz * 0.36), sz, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, outline)

static var _box := StyleBoxFlat.new()

## A rounded panel (fill + edge).
static func panel(ci: CanvasItem, rect: Rect2, edge: Color = PANEL_EDGE, fill: Color = PANEL, radius := RADIUS, edge_w := 2) -> void:
	_box.bg_color = fill
	_box.border_color = edge
	_box.set_border_width_all(edge_w)
	_box.set_corner_radius_all(radius)
	_box.anti_aliasing = true
	_box.draw(ci.get_canvas_item(), rect)

## Clockwise cooldown overlay: the part of `rect` still to sweep, `remaining` 0..1, starting
## at 12 o'clock when remaining = 1.
static func sweep_polygon(rect: Rect2, remaining: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := rect.get_center()
	pts.append(c)
	var steps := 48
	var a_start := -PI / 2.0 + TAU * (1.0 - remaining)
	var a_end := -PI / 2.0 + TAU
	for i in range(steps + 1):
		var a := lerpf(a_start, a_end, float(i) / steps)
		var d := Vector2(cos(a), sin(a))
		var tx := INF if absf(d.x) < 0.0001 else rect.size.x * 0.5 / absf(d.x)
		var ty := INF if absf(d.y) < 0.0001 else rect.size.y * 0.5 / absf(d.y)
		pts.append(c + d * minf(tx, ty))
	return pts

## Ring arc from 12 o'clock, clockwise, `fraction` of a turn.
static func arc(ci: CanvasItem, c: Vector2, radius: float, fraction: float, width: float, color: Color) -> void:
	if fraction <= 0.0:
		return
	ci.draw_arc(c, radius, -PI / 2.0, -PI / 2.0 + TAU * clampf(fraction, 0.0, 1.0), 48, color, width, true)

static func initials(h: Hero) -> String:
	var n := h.data.display_name if h.data else h.display_name
	return n.substr(0, 2).to_upper()

## A small padlock (Tradisyonal: skills not allowed).
static func padlock(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_arc(c + Vector2(0, -s * 0.28), s * 0.32, PI, TAU, 16, color, s * 0.13, true)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.45, -s * 0.28), Vector2(s * 0.9, s * 0.72)), color)
	ci.draw_circle(c + Vector2(0, s * 0.05), s * 0.1, INK)

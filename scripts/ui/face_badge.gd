class_name FaceBadge
extends Control

## A round hero portrait for menus (profile card, draft, results): the hero's rendered face
## clipped to a circle on a coloured disc with a ring. Redraws itself when the face finishes
## rendering (Portraits renders on first use).

var hero_id := ""
var bg := Color("2b2733")
var ring := Color.WHITE
var ring_width := 4.0
var dim := 0.0

func _init(p_hero := "", p_size := 96.0) -> void:
	hero_id = p_hero
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var s := Portraits.studio()
	if s and not s.ready_face.is_connected(_on_face):
		s.ready_face.connect(_on_face)

func set_hero(id: String, p_bg := Color(-1, 0, 0), p_ring := Color(-1, 0, 0)) -> void:
	hero_id = id
	if p_bg.r >= 0.0:
		bg = p_bg
	if p_ring.r >= 0.0:
		ring = p_ring
	queue_redraw()

func _on_face(id: String) -> void:
	if id == hero_id:
		queue_redraw()

func _draw() -> void:
	if hero_id == "":
		return
	var r := minf(size.x, size.y) * 0.5 - ring_width * 0.5
	Portraits.draw_face(self, hero_id, size * 0.5, r, bg, ring, ring_width, dim, UiFonts.display())

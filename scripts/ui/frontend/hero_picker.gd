class_name HeroPicker
extends Control

## The default-character picker (spec § 6 "Home"): opens over Home when the player card is clicked.
## The chosen hero is the one on the player card and the one ENSAYO plays. Focus, hover and press all
## move the selection, the BreakDance preview follows it, and Piliin saves it (Bumalik / Esc keeps the
## old one). The breakdance lives here now instead of on the Home screen's centre stage.

signal chosen(id: String)
signal closed

const POP_TIME := 0.2
const POP_FROM := 0.9
const CARD_SIZE := Vector2(1240, 820)
const BADGE := 100.0

var selected := "jm"
var preview: HeroPreview
var card: Control
var name_label: Label
var role_label: Label
var badges := {} ## hero id -> Button
var confirm_btn: Button
var cancel_btn: Button
var _closing := false

func _init(p_current := "jm") -> void:
	selected = p_current if p_current in HeroData.ORDER else "jm"
	name = "HeroPicker"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_build_card()
	_refresh()
	confirm_btn.grab_focus.call_deferred()
	card.pivot_offset = CARD_SIZE * 0.5
	card.scale = Vector2.ONE * POP_FROM
	card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, POP_TIME)
	tw.tween_property(card, "modulate:a", 1.0, POP_TIME)

func _build_card() -> void:
	card = Control.new()
	card.name = "Card"
	card.size = CARD_SIZE
	card.position = (Vector2(1920, 1080) - CARD_SIZE) * 0.5
	add_child(card)
	var board := Panel.new()
	board.add_theme_stylebox_override("panel", HomeSkin.cardboard())
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(board)
	HomeSkin.tape(card, Vector2(-26, 8), -38)
	HomeSkin.tape(card, Vector2(CARD_SIZE.x - 78, 8), 36)

	var title := HomeSkin.shout("PILIIN ANG KATROPA MO", 64, HomeSkin.PAPER)
	title.name = "Title"
	title.position = Vector2(0, 34)
	title.size = Vector2(CARD_SIZE.x, 80)
	card.add_child(title)
	var sub := FE.label("Choose your default character  ·  siya ang kasama mo sa Ensayo", 24, HomeSkin.INK, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 114)
	sub.size = Vector2(CARD_SIZE.x, 34)
	card.add_child(sub)

	var pad := Panel.new()
	pad.add_theme_stylebox_override("panel", HomeSkin.cardboard(true))
	pad.position = Vector2(60, 168)
	pad.size = Vector2(520, 560)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pad)
	preview = HeroPreview.new()
	preview.name = "PickerPreview"
	preview.position = Vector2(70, 178)
	preview.size = Vector2(500, 540)
	card.add_child(preview)

	name_label = HomeSkin.shout("", 84, HomeSkin.PAPER)
	name_label.name = "PickerName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.position = Vector2(630, 190)
	name_label.size = Vector2(560, 100)
	card.add_child(name_label)
	role_label = FE.label("", 28, HomeSkin.INK)
	role_label.name = "PickerRole"
	role_label.position = Vector2(630, 296)
	role_label.size = Vector2(560, 80)
	role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(role_label)

	var row := HBoxContainer.new()
	row.name = "Badges"
	row.position = Vector2(620, 400)
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	for id in HeroData.ORDER:
		row.add_child(_make_badge(id))
	for i in range(HeroData.ORDER.size()):
		var b := badges[HeroData.ORDER[i]] as Button
		b.focus_neighbor_left = badges[HeroData.ORDER[wrapi(i - 1, 0, HeroData.ORDER.size())]].get_path()
		b.focus_neighbor_right = badges[HeroData.ORDER[wrapi(i + 1, 0, HeroData.ORDER.size())]].get_path()

	confirm_btn = FE.button("Piliin", "Choose", Vector2(360, 110), 48, false, true)
	confirm_btn.name = "Piliin"
	confirm_btn.position = Vector2(630, 560)
	HomeSkin.skin_button(confirm_btn, "primary")
	card.add_child(confirm_btn)
	cancel_btn = FE.button("Bumalik", "Back", Vector2(260, 84), 36)
	cancel_btn.name = "Bumalik"
	cancel_btn.position = Vector2(630, 686)
	HomeSkin.skin_button(cancel_btn)
	card.add_child(cancel_btn)
	confirm_btn.pressed.connect(confirm)
	cancel_btn.pressed.connect(close)
	for id in HeroData.ORDER:
		var b := badges[id] as Button
		b.focus_neighbor_bottom = confirm_btn.get_path()
	confirm_btn.focus_neighbor_top = badges[selected].get_path()
	confirm_btn.focus_neighbor_bottom = cancel_btn.get_path()
	cancel_btn.focus_neighbor_top = confirm_btn.get_path()
	cancel_btn.focus_neighbor_bottom = cancel_btn.get_path()

func _make_badge(id: String) -> Button:
	var b := Button.new()
	b.name = "Badge_" + id
	b.custom_minimum_size = Vector2(BADGE, BADGE)
	b.flat = true
	var plain := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, plain)
	b.add_theme_stylebox_override("focus", plain)
	var face := FaceBadge.new(id, BADGE - 12.0)
	face.name = "Face"
	face.position = Vector2(6, 6)
	face.size = Vector2(BADGE - 12.0, BADGE - 12.0)
	face.ring_width = 6.0
	b.add_child(face)
	badges[id] = b
	b.mouse_entered.connect(func(): preview_hero(id))
	b.focus_entered.connect(func(): preview_hero(id))
	b.pressed.connect(func(): pick(id))
	return b

## Move the selection (and the preview) to `id`.
func preview_hero(id: String) -> void:
	if id == selected and preview.hero_id == id:
		return
	selected = id
	_refresh()

## A press on a portrait: select it and hand focus to Piliin.
func pick(id: String) -> void:
	preview_hero(id)
	if confirm_btn and confirm_btn.is_inside_tree():
		confirm_btn.grab_focus()

func confirm() -> void:
	chosen.emit(selected)
	close()

func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()

func _refresh() -> void:
	var data := HeroData.load_hero(selected)
	preview.show_hero(selected, "BreakDance")
	name_label.text = data.display_name.to_upper()
	var nick := ("\"%s\"\n" % data.nickname) if data.nickname != "" else ""
	role_label.text = "%s%s / %s" % [nick, data.role, data.secondary_role]
	for id in HeroData.ORDER:
		var face := (badges[id] as Button).get_node("Face") as FaceBadge
		var d := HeroData.load_hero(id)
		var on: bool = id == selected
		face.set_hero(id, d.color.darkened(0.25), HomeSkin.YELLOW if on else HomeSkin.INK)
		(badges[id] as Button).scale = Vector2.ONE * (1.12 if on else 1.0)
		(badges[id] as Button).pivot_offset = Vector2(BADGE, BADGE) * 0.5
	if confirm_btn:
		confirm_btn.focus_neighbor_top = (badges[selected] as Button).get_path()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

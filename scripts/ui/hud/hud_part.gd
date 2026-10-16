class_name HudPart
extends Control

## Base of every full-screen HUD piece (built in code, docs/RESBAK.md § 7). Each part fills
## the HUD root, lays itself out from its size (1920x1080 reference), refreshes from the
## host every frame and may react to host events.

var hud: Hud

func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind(p_hud: Hud) -> void:
	hud = p_hud

func _ready() -> void:
	resized.connect(_layout)
	_layout()

## The canvas size (the 1920x1080 reference unless the window is wider).
func sz() -> Vector2:
	return size if size.x > 200.0 and size.y > 200.0 else Vector2(1920, 1080)

func _layout() -> void:
	pass

## Called by Hud every frame.
func refresh(_delta: float) -> void:
	pass

func on_event(_kind: String, _d: Dictionary) -> void:
	pass

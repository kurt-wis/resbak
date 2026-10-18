class_name ChalkWipe
extends CanvasLayer

## The 0.3 s chalk wipe between front-end screens (docs/RESBAK.md § 6 Navigation): a dark slab
## with a chalk edge sweeps in from the left, the scene changes behind it, it sweeps out to the
## right. Lives on the root window so it survives change_scene. Reduce motion = a plain cut.

const DURATION := 0.3

var slab: ColorRect
var busy := false

func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	slab = ColorRect.new()
	slab.color = FE.INK
	slab.set_anchors_preset(Control.PRESET_FULL_RECT)
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab.visible = false
	add_child(slab)
	var edge := ColorRect.new()
	edge.color = FE.DILAW
	edge.anchor_left = 1.0
	edge.anchor_right = 1.0
	edge.anchor_bottom = 1.0
	edge.offset_left = -18.0
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab.add_child(edge)
	var chalk := ColorRect.new()
	chalk.color = FE.CHALK
	chalk.anchor_left = 1.0
	chalk.anchor_right = 1.0
	chalk.anchor_bottom = 1.0
	chalk.offset_left = -26.0
	chalk.offset_right = -18.0
	chalk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab.add_child(chalk)

func run(midpoint: Callable) -> void:
	if busy:
		return
	var reduce := bool(FE.setting("accessibility", "reduce_motion"))
	if reduce:
		midpoint.call()
		return
	busy = true
	slab.visible = true
	slab.mouse_filter = Control.MOUSE_FILTER_STOP ## swallow clicks during the wipe
	slab.anchor_left = 0.0
	slab.anchor_right = 0.0
	var tw := create_tween()
	tw.tween_property(slab, "anchor_right", 1.0, DURATION * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(midpoint)
	tw.tween_interval(0.05)
	tw.tween_callback(func():
		slab.anchor_right = 1.0
		slab.anchor_left = 0.0)
	tw.tween_property(slab, "anchor_left", 1.0, DURATION * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		slab.visible = false
		slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		busy = false)

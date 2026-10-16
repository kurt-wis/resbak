extends FrontScreen

## Map roulette (docs/RESBAK.md § 6 "Roulette and draft"). Map wheel 4 s with the Kuya Tanod
## map line; then the overhead view shows the map's fixed bases for 2 s (v0.2: bases no longer
## roll, docs/status.md); the draft starts 1 s later. A chosen map skips the wheel and shows its
## choice for 2 s. No repeat of the previous map (Session.last_map) when more than one map can
## be played. Writes Session.settings.map (and base_mode = 1 for older readers).

const WHEEL_SECS := 4.0
const SHOW_SECS := 2.0
const FLICKER_SECS := 2.0
const DRAFT_DELAY := 1.0

enum Phase { MAP, BASE, LOCKED, DONE }

var phase := Phase.MAP
var phase_time := 0.0
var map_spins := true
var base_spins := true
var map_id := "barangay_court"
var site := 1
var wheel_pos := 0.0
var rng := RandomNumberGenerator.new()
var overhead: Overhead
var wheel_labels: Array[Label] = []
var line_label: Label
var status_box: VBoxContainer
var _flick := 1
var _line_said := false

signal finished

## The overhead schematic: court, centre circle and each side's fixed base.
class Overhead extends Control:
	var site_hi := 0 ## highlighted site (1..3), 0 = none
	var locked := false
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("c9a86a"))
		draw_rect(r.grow(-6), FE.CHALK, false, 6.0)
		draw_line(Vector2(size.x * 0.5, 6), Vector2(size.x * 0.5, size.y - 6), FE.CHALK, 5.0)
		draw_arc(size * 0.5, size.y * 0.16, 0, TAU, 48, FE.CHALK, 5.0)
		for team in range(2):
			var x := size.x * (0.13 if team == 0 else 0.87)
			var col: Color = RB.TEAM_COLORS[team]
			var c := Vector2(x, size.y * 0.5)
			var on := site_hi > 0
			draw_circle(c, 34.0 if on else 24.0, Color(col, 1.0 if on else 0.35))
			draw_arc(c, 34.0 if on else 24.0, 0, TAU, 32, FE.INK, 4.0 if on else 2.0)
			if on and locked:
				draw_arc(c, 46.0, 0, TAU, 32, FE.CHALK, 5.0)

func build() -> void:
	var s := Session
	var seed_v := int(s.settings.get("seed", 0))
	if seed_v != 0:
		rng.seed = seed_v
	else:
		rng.randomize()
	var map_choice := String(s.settings.get("map_choice", "roulette"))
	map_spins = map_choice == "roulette"
	base_spins = false # v0.2: fixed bases
	map_id = _pick_map(map_choice)
	site = 1
	_flick = site
	_build_ui()
	_enter(Phase.MAP)

func _pick_map(choice: String) -> String:
	var avail: Array = FE.available_maps().map(func(m): return m.id)
	if choice != "roulette" and choice in avail:
		return choice
	var pool := avail.duplicate()
	var last := String(Session.last_map)
	if pool.size() > 1 and last in pool:
		pool.erase(last)
	return pool[rng.randi() % pool.size()]

func _build_ui() -> void:
	var title := FE.bi_box("Mapa at Base", "Map and base", 56, FE.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	title.position = Vector2(100, 50)
	title.size = Vector2(900, 130)
	content.add_child(title)
	# overhead view (right)
	overhead = Overhead.new()
	overhead.name = "Overhead"
	overhead.position = Vector2(820, 200)
	overhead.size = Vector2(1000, 640)
	content.add_child(overhead)
	# wheel (left): 5 visible rows around the centre
	var reel := VBoxContainer.new()
	reel.name = "Wheel"
	reel.position = Vector2(100, 250)
	reel.size = Vector2(640, 520)
	reel.add_theme_constant_override("separation", 6)
	content.add_child(reel)
	for i in range(5):
		var l := FE.label("", 44, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_LEFT)
		l.custom_minimum_size = Vector2(0, 100)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reel.add_child(l)
		wheel_labels.append(l)
	var mark := ColorRect.new()
	mark.color = Color(FE.DILAW, 0.18)
	mark.position = Vector2(80, 250 + 2 * 106 - 2)
	mark.size = Vector2(700, 104)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(mark)
	content.move_child(mark, 0)
	status_box = FE.bi_box("", "", 44, FE.CHALK, HORIZONTAL_ALIGNMENT_LEFT)
	status_box.name = "Status"
	status_box.position = Vector2(100, 800)
	status_box.size = Vector2(800, 120)
	content.add_child(status_box)
	line_label = FE.shout("", 56, FE.GOLD, FE.INK)
	line_label.name = "MapLine"
	line_label.position = Vector2(820, 870)
	line_label.size = Vector2(1000, 90)
	content.add_child(line_label)
	var hint := FE.label("Esc: lumabas  Leave", 20, FE.GREY, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.position = Vector2(1500, 1020)
	hint.size = Vector2(380, 30)
	content.add_child(hint)

func on_back() -> void:
	ask("Aalis ka na?", "Leaving?", func(): go("home"))

# ---- timeline ---------------------------------------------------------------------------
func phase_length() -> float:
	match phase:
		Phase.MAP:
			return WHEEL_SECS if map_spins else SHOW_SECS
		Phase.BASE:
			return FLICKER_SECS if base_spins else SHOW_SECS
		Phase.LOCKED:
			return DRAFT_DELAY
	return 0.0

func _enter(p: Phase) -> void:
	phase = p
	phase_time = 0.0
	match p:
		Phase.MAP:
			if map_spins:
				_set_status("Iikot ang mapa...", "Spinning the map")
			else:
				_set_status("Napili ang mapa", "Map chosen")
			overhead.site_hi = 0
			overhead.queue_redraw()
			_update_wheel()
		Phase.BASE:
			Session.settings["map"] = map_id
			Session.last_map = map_id
			_say_line()
			_set_status("Nakapirming base", "Fixed bases")
		Phase.LOCKED:
			Session.settings["base_mode"] = site
			overhead.site_hi = site
			overhead.locked = true
			overhead.queue_redraw()
			_set_status("Tara na!", "Bases set")
		Phase.DONE:
			finished.emit()
			go("draft")

func _set_status(fil: String, en: String) -> void:
	FE.set_bi(status_box, fil, en)

func _say_line() -> void:
	if _line_said:
		return
	_line_said = true
	var line: String = FE.map_info(map_id).line
	line_label.text = line
	Audio.announce("kuya_tanod_map_" + map_id, line)

func _process(delta: float) -> void:
	advance(delta)

## Advance the timeline (tests call this with big steps; transitions cascade).
func advance(delta: float) -> void:
	var left := delta
	while phase != Phase.DONE:
		var plen := phase_length()
		var step := minf(left, plen - phase_time)
		phase_time += step
		left -= step
		_animate()
		if phase_time >= plen - 0.00001:
			_enter((phase + 1) as Phase)
		else:
			break

func _animate() -> void:
	match phase:
		Phase.MAP:
			_update_wheel()
		Phase.BASE:
			if base_spins:
				_flick = 1 + int(phase_time / 0.11) % 3
				if phase_time > FLICKER_SECS - 0.4: ## the last 0.4 s settle on the locked site
					_flick = site
				overhead.site_hi = _flick
			else:
				overhead.site_hi = site
			overhead.queue_redraw()

func _update_wheel() -> void:
	var n := FE.MAP_POOL.size()
	var target := float(_pool_index(map_id))
	if map_spins:
		var u := clampf(phase_time / WHEEL_SECS, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - u, 3.0)
		wheel_pos = eased * (target + float(n * 4))
	else:
		wheel_pos = target
	var base := int(floor(wheel_pos + 0.5))
	for i in range(5):
		var idx := wrapi(base + i - 2, 0, n)
		var m: Dictionary = FE.MAP_POOL[idx]
		var playable := FE.available_maps().any(func(a): return a.id == m.id)
		var l := wheel_labels[i]
		l.text = m.fil + ("" if playable else "   Malapit na")
		var centre := i == 2
		l.add_theme_font_size_override("font_size", 56 if centre else 38)
		l.add_theme_color_override("font_color", (FE.GOLD if playable else FE.GREY) if centre else FE.CHALK_DIM.darkened(0.2))

func _pool_index(id: String) -> int:
	for i in range(FE.MAP_POOL.size()):
		if FE.MAP_POOL[i].id == id:
			return i
	return 0

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if dialog or phase == Phase.DONE:
		return
	# Interact / accept skips ahead to the end of the current step.
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		advance(phase_length() - phase_time)

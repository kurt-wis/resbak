class_name Tutorial
extends Node

## "Turo ni Kuya Tanod": the short first-time tutorial (docs/RESBAK.md § 8 "Tutorial lessons",
## trimmed to six quick steps for the v0.1.1 demo). It runs on the normal MatchHost in practice
## mode (no round ends, the clock stands still) with you, one bot teammate and two enemy
## dummies, and checks each lesson against host events:
##   1 Takbo (move to the marker)  2 Unahan (tag the dummy)  3 Taya (capture the enemy ball)
##   4 Huli ka (you're caught: as the chain tip, reach for your rescuer)  5 Resbak (rescue your
##   caught teammate by touching the tip)  6 Mga galing (use a skill).
## Each lesson resets the court, shows its instructions in a panel on the left, and moves on
## 1.6 s after it is done. At the end the profile records the lessons and you go back Home.
## Dummies send empty input frames; the teammate is scripted (it waits for you to reach out
## in lesson 4 and stretches toward you in lesson 5). Same rules, same frames as a real match.

signal finished

const HOME_SCENE := "res://scenes/frontend/home.tscn"
const LESSONS := [
	{"title": "Takbo!", "en": "Run", "text": "Gumalaw gamit ang W A S D (o ang kaliwang stick). Puntahan ang kumikinang na bilog."},
	{"title": "Unahan!", "en": "First tag wins", "text": "Itutok ang mouse sa kalaban at pindutin ang LEFT CLICK para manghuli. Lapitan muna: dapat abot ng kamay mo!"},
	{"title": "Taya!", "en": "Capture", "text": "Tumakbo sa BOLA ng kalaban (kanan). Tumayo sa tabi nito at HAWAKAN ang F hanggang mapuno ang bilog."},
	{"title": "Huli ka!", "en": "You're caught", "text": "Nahuli ka at nasa kulungan ka na. Ikaw ang DULO ng kadena: gumalaw papunta sa kakampi mo para mahawakan ka niya."},
	{"title": "Resbak!", "en": "Rescue", "text": "Nahuli ang kakampi mo! Tumakbo sa kulungan ng kalaban at HAWAKAN ang dulo ng kadena para iligtas siya."},
	{"title": "Mga galing", "en": "Skills", "text": "Bawat katropa ay may dalawang galing. Pindutin ang Q o E para gamitin ang isa."},
]

var host: MatchHost
var local: Hero
var hud: Hud
var mate: Hero ## the bot teammate
var dummies: Array[Hero] = []
var lesson := -1
var done_at := -1.0
var _marker: Node3D
var _ui: CanvasLayer
var _panel: PanelContainer
var _count_label: Label
var _title_label: Label
var _text_label: Label
var _status_label: Label
var _hint_label: Label
var _t := 0.0
var _started := false

## Session for a tutorial match with `hero_id` (the player's bench hero).
static func prepare_session(hero_id: String) -> void:
	var s := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Session")
	if s == null:
		return
	s.mode = "tutorial"
	s.reset_settings()
	s.settings["practice"] = true
	s.settings["skills"] = true
	s.settings["hazards"] = false
	s.settings["base_mode"] = 1
	s.settings["round_time"] = 600.0
	s.settings["map"] = "barangay_court"
	var mate_id := "inday" if hero_id != "inday" else "tutoy"
	var foes := ["nene", "nathan"] if hero_id != "nene" else ["jm", "nathan"]
	s.lineup = [
		{"hero_id": hero_id, "team": RB.DILAW, "team_slot": 0, "is_bot": false, "name": s.player_name()},
		{"hero_id": mate_id, "team": RB.DILAW, "team_slot": 1, "is_bot": true, "name": HeroData.load_hero(mate_id).display_name + " (Bot)"},
		{"hero_id": foes[0], "team": RB.LILA, "team_slot": 0, "is_bot": true, "name": "Dummy 1"},
		{"hero_id": foes[1], "team": RB.LILA, "team_slot": 1, "is_bot": true, "name": "Dummy 2"},
	]
	s.local_slot = 0

func setup(p_host: MatchHost, p_local: Hero, p_hud: Hud) -> void:
	host = p_host
	local = p_local
	hud = p_hud
	name = "Tutorial"
	for h in host.heroes:
		if h == local:
			continue
		if h.team == local.team:
			mate = h
		else:
			dummies.append(h)
		host.input_sources[h.slot] = self
	host.event.connect(_on_event)
	_build_ui()
	_show_intro()

# ---- input for the scripted heroes --------------------------------------------------------
func frame_for(h: Hero, _host: MatchHost) -> InputFrame:
	var f := InputFrame.new()
	if h != mate or not host.round_live():
		return f
	var goal := Vector3.INF
	match lesson:
		3: # wait near the jail until you reach out, then grab your hand
			var tip := host.jail_system.rescue_point(RB.other_team(local.team))
			if tip == Vector3.INF or not mate.is_free():
				return f
			var post := host.jail_system.post(RB.other_team(local.team))
			var wait := post + host.jail_system.out_dir(RB.other_team(local.team)) * 4.2
			goal = tip if RB.flat_dist(tip, post) > 1.0 else wait
		4: # chained: stretch toward you
			if host.jail_system.can_steer(mate):
				goal = local.global_position
	if goal != Vector3.INF:
		var d := RB.flat(goal - h.global_position)
		if d.length() > 0.3:
			f.move = Vector2(d.x, d.z).normalized()
			f.aim_point = goal
			f.has_aim = true
	return f

# ---- lessons ------------------------------------------------------------------------------
func _show_intro() -> void:
	_count_label.text = "TURO NI KUYA TANOD"
	_title_label.text = "Handa ka na ba?"
	_text_label.text = "Anim na mabilis na aralin. Pindutin ang Esc para huminto."
	_status_label.text = ""

func _process(delta: float) -> void:
	_t += delta
	if host == null:
		return
	if not _started and host.round_live():
		_started = true
		_begin(0)
	if lesson < 0:
		return
	if done_at < 0.0 and _check():
		_complete()
	elif done_at >= 0.0 and _t - done_at >= 1.6:
		_begin(lesson + 1)
	if _marker:
		_marker.scale = Vector3.ONE * (1.0 + 0.08 * sin(_t * 5.0))

func _reset_court() -> void:
	host.round_flow._reset_world()
	for d in dummies:
		Place.put(d, host.layout.spawns[d.team][1])

func _begin(i: int) -> void:
	if i >= LESSONS.size():
		_finish()
		return
	lesson = i
	done_at = -1.0
	_clear_marker()
	_reset_court()
	var info: Dictionary = LESSONS[i]
	_count_label.text = "ARALIN %d / %d" % [i + 1, LESSONS.size()]
	_title_label.text = "%s  (%s)" % [info.title, info.en]
	_text_label.text = info.text
	_status_label.text = ""
	_hint_label.text = ""
	_panel.modulate = Color.WHITE
	var dilaw_mid := Vector3(-8.0, 0, 1.5)
	match i:
		0:
			_place_marker(dilaw_mid)
		1:
			Place.put(dummies[0], local.global_position + Vector3(4.0, 0, 0))
		2:
			pass
		3:
			local.on_tagged(dummies[0])
			Place.put(mate, host.layout.jail_centre(RB.LILA) + Vector3(-6.0, 0, 3.0))
		4:
			mate.on_tagged(dummies[0])
			Place.put(local, Vector3(4.0, 0, -2.0))
		5:
			pass

func _check() -> bool:
	match lesson:
		0:
			return _marker != null and RB.flat_dist(local.global_position, _marker.global_position) <= 1.4
	return false # the others finish on events

func _on_event(kind: String, d: Dictionary) -> void:
	if lesson < 0 or done_at >= 0.0:
		return
	match lesson:
		1:
			if kind == "tag" and d.tagger == local:
				_complete()
			elif kind == "tag_failed" and d.tagger == local:
				_hint_label.text = "Lapitan pa! Dapat abot ng kamay mo ang kalaban."
		2:
			if kind == "capture" and d.hero == local:
				host.base_system.cancel_capture(local, "practice")
				_complete()
			elif kind == "capture_cancel" and d.hero == local and d.reason == "released":
				_hint_label.text = "Huwag bitawan ang F hanggang mapuno!"
		3:
			if kind == "rescue" and (d.freed as Array).has(local):
				_complete()
		4:
			if kind == "rescue" and d.rescuer == local:
				_complete()
		5:
			if kind == "skill_cast" and d.hero == local:
				_complete()

func _complete() -> void:
	done_at = _t
	_status_label.text = "✓  Magaling!"
	_hint_label.text = ""
	_clear_marker()
	if hud:
		hud.show_banner("MAGALING!", HudStyle.GREEN, 1.2)

func _finish() -> void:
	lesson = LESSONS.size()
	_count_label.text = "TAPOS NA!"
	_title_label.text = "Handa ka na sa laban!"
	_text_label.text = "Tandaan: unahan lang 'yan, iligtas ang kakampi, at agawin ang bola nila. Babalik ka sa Tambayan."
	_status_label.text = "✓"
	var save := get_node_or_null("/root/Save")
	if save:
		var lessons: Array = []
		for i in range(LESSONS.size()):
			lessons.append(i + 1)
		save.profile["tutorial_lessons_done"] = lessons
		save.save_profile()
	finished.emit()
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		host.paused = true
		FE.go(self, HOME_SCENE)

func _place_marker(at: Vector3) -> void:
	_marker = Vfx.ground_ring(host.world, at, 1.0, Color(1.0, 0.84, 0.3, 0.95), 0.18, 0.25)
	var l := Label3D.new()
	l.text = "DITO!"
	l.font_size = 96
	l.outline_size = 18
	l.modulate = Color("ffd34d")
	l.outline_modulate = Color("1a1020")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 1.6, 0)
	_marker.add_child(l)

func _clear_marker() -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null

# ---- UI ----------------------------------------------------------------------------------
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 11
	add_child(_ui)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.9)
	sb.border_color = Color("ffd34d")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(24, 360)
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	_count_label = HudStyle.label(v, 22, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.GOLD, 6)
	_title_label = HudStyle.label(v, 40, HORIZONTAL_ALIGNMENT_LEFT, Color.WHITE, 8)
	_text_label = Label.new()
	_text_label.add_theme_font_override("font", UiFonts.body())
	_text_label.add_theme_font_size_override("font_size", 25)
	_text_label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.96))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(510, 0)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text_label)
	_hint_label = HudStyle.label(v, 22, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.ORANGE, 6)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(510, 0)
	_status_label = HudStyle.label(v, 34, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.GREEN, 8)

## Put a hero exactly at a spot, stopped (the game never loads test helpers).
class Place:
	static func put(h: Hero, at: Vector3) -> void:
		h.teleport(Vector3(at.x, 0.05, at.z))

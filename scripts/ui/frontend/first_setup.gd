extends FrontScreen

## First-time setup (docs/RESBAK.md § 6 Setup): Wika, Pangalan, readability (colour mode),
## Kontrol. Skip keeps the default (at Pangalan it takes the dice name); Back = previous step;
## the last step writes profile.setup_done. Never prompts the tutorial.

const STEPS := [
	{"fil": "Wika", "en": "Language"},
	{"fil": "Pangalan", "en": "Name"},
	{"fil": "Linaw ng Kulay", "en": "Readability"},
	{"fil": "Kontrol", "en": "Controls"},
]
const LANGS := [
	{"v": "fil_en", "fil": "Filipino", "en": "with English labels"},
	{"v": "en", "fil": "English", "en": ""},
	{"v": "fil", "fil": "Filipino", "en": ""},
]
## Colour modes (spec § 10) and the two outline colours each one shows in the preview.
const COLOUR_MODES := [
	{"v": "default", "fil": "Default", "a": Color("ff8a3d"), "b": Color("8d8a96")},
	{"v": "deuteranopia", "fil": "Deuteranopia", "a": Color("3d8bff"), "b": Color("f2d13a")},
	{"v": "protanopia", "fil": "Protanopia", "a": Color("2f9bff"), "b": Color("f0e060")},
	{"v": "tritanopia", "fil": "Tritanopia", "a": Color("ff5a7a"), "b": Color("3fd0d0")},
	{"v": "high_contrast", "fil": "High contrast", "a": Color("ffffff"), "b": Color("000000")},
]

var step := 0
var name_edit: LineEdit
var msg: Label
var next_btn: Button
var back_btn: Button
var skip_btn: Button
var body: VBoxContainer
var title_box: VBoxContainer
var step_label: Label
var pname := ""
var colour_idx := 0
var device := "keyboard"
var _rng := RandomNumberGenerator.new()

func build() -> void:
	_rng.randomize()
	var s := FE.save()
	pname = String(s.get_profile().get("player_name", "")) if s else ""
	if not NameRules.validate(pname).ok or pname == "Manlalaro":
		pname = NameRules.dice(_rng)
	for i in range(COLOUR_MODES.size()):
		if COLOUR_MODES[i].v == String(FE.setting("accessibility", "colour_mode")):
			colour_idx = i
	device = "gamepad" if Input.get_connected_joypads().size() > 0 else "keyboard"
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(center)
	var p := FE.panel(FE.INK2, FE.CHALK_DIM, 3, 26)
	p.custom_minimum_size = Vector2(1100, 700)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	p.add_child(v)
	step_label = FE.label("", 22, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	step_label.name = "StepLabel"
	v.add_child(step_label)
	title_box = FE.bi_box("", "", 64, FE.GOLD)
	title_box.name = "StepTitle"
	v.add_child(title_box)
	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	v.add_child(body)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 20)
	v.add_child(nav)
	back_btn = btn("Back", "Bumalik", "Back", Vector2(240, 76), 28)
	skip_btn = btn("Skip", "Laktawan", "Skip", Vector2(240, 76), 28)
	next_btn = btn("Next", "Susunod", "Next", Vector2(300, 76), 32, false, true)
	nav.add_child(back_btn)
	nav.add_child(FE.spacer(0, 0))
	(nav.get_child(1) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(skip_btn)
	nav.add_child(next_btn)
	back_btn.pressed.connect(on_back)
	skip_btn.pressed.connect(skip_step)
	next_btn.pressed.connect(next_step)
	show_step(0)

func first_focus() -> Control:
	if step == 1 and name_edit:
		return name_edit
	return next_btn

func on_back() -> void:
	if step == 0:
		go("title")
	else:
		show_step(step - 1)

func show_step(i: int) -> void:
	step = clampi(i, 0, STEPS.size() - 1)
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	name_edit = null
	msg = null
	step_label.text = "%d / %d" % [step + 1, STEPS.size()]
	FE.set_bi(title_box, STEPS[step].fil, STEPS[step].en)
	next_btn.disabled = false
	next_btn.modulate.a = 1.0
	var last := step == STEPS.size() - 1
	FE.set_button_text(next_btn, "Tapos" if last else "Susunod", "Done" if last else "Next")
	match step:
		0: _build_language()
		1: _build_name()
		2: _build_colour()
		3: _build_controls()
	_focus_first.call_deferred()

# ---- step bodies ------------------------------------------------------------------------
func _option_button(key: String, fil: String, en: String, selected: bool) -> Button:
	var b := btn(key, ("✓  " if selected else "") + fil, en, Vector2(0, 92), 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if selected:
		b.add_theme_stylebox_override("normal", FE.box_style(FE.INK3, FE.DILAW, 4))
	return b

func _build_language() -> void:
	var cur := String(FE.setting("language_network", "language"))
	for l in LANGS:
		var b := _option_button("Lang_" + l.v, l.fil, l.en, l.v == cur)
		b.pressed.connect(func():
			FE.save().set_setting("language_network", "language", l.v)
			show_step(0))
		body.add_child(b)

func _build_name() -> void:
	var hint := FE.label("3 hanggang 16 na letra, numero o espasyo.  3 to 16 letters, digits or spaces.", 22, FE.CHALK_DIM)
	body.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	name_edit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.max_length = NameRules.MAX_LEN
	name_edit.text = pname
	name_edit.placeholder_text = "Pangalan"
	name_edit.custom_minimum_size = Vector2(0, 84)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.text_submitted.connect(func(_t): next_step())
	row.add_child(name_edit)
	var dice := btn("Dice", "Ibang pangalan", "Random name", Vector2(320, 84), 28)
	row.add_child(dice)
	dice.pressed.connect(func():
		pname = NameRules.dice(_rng, pname)
		name_edit.text = pname
		_on_name_changed(pname))
	msg = FE.label("", 24, FE.ORANGE)
	msg.name = "NameMsg"
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(msg)
	_on_name_changed(pname)

func _on_name_changed(t: String) -> void:
	pname = t
	var r := NameRules.validate(t)
	msg.text = "" if r.ok else r.reason
	next_btn.disabled = not r.ok
	next_btn.modulate.a = 1.0 if r.ok else 0.5

func _build_colour() -> void:
	var m: Dictionary = COLOUR_MODES[colour_idx]
	body.add_child(FE.label("Alin ang mas malinaw: ang kalaban o ang kakampi?  Which outline is clearer: enemy or ally?", 22, FE.CHALK_DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 80)
	row.custom_minimum_size = Vector2(0, 180)
	body.add_child(row)
	for pair in [["Kalaban", "Enemy", m.a], ["Kakampi", "Ally", m.b]]:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var sw := Panel.new()
		sw.custom_minimum_size = Vector2(150, 150)
		sw.add_theme_stylebox_override("panel", FE.box_style(FE.INK, pair[2], 12, 28))
		col.add_child(sw)
		col.add_child(FE.bi_box(pair[0], pair[1], 24))
		row.add_child(col)
	var cycle := btn("Cycle", m.fil, "Pindutin para palitan  Press to change", Vector2(0, 92), 34)
	cycle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cycle.pressed.connect(func():
		colour_idx = (colour_idx + 1) % COLOUR_MODES.size()
		FE.save().set_setting("accessibility", "colour_mode", COLOUR_MODES[colour_idx].v)
		show_step(2)
		buttons["Cycle"].grab_focus.call_deferred())
	body.add_child(cycle)

func _build_controls() -> void:
	body.add_child(FE.label("Anong gamit mo ngayon?  What are you playing with?", 24, FE.CHALK_DIM))
	for d in [["keyboard", "Keyboard at mouse", "Keyboard and mouse"], ["gamepad", "Gamepad", "Controller"]]:
		var b := _option_button("Dev_" + d[0], d[1], d[2], device == d[0])
		b.pressed.connect(func():
			device = d[0]
			show_step(3))
		body.add_child(b)

# ---- flow -------------------------------------------------------------------------------
func skip_step() -> void:
	if step == 1:
		pname = NameRules.dice(_rng)
	next_step(true)

func next_step(skipped := false) -> void:
	if step == 1 and not skipped and not NameRules.validate(pname).ok:
		return
	if step < STEPS.size() - 1:
		show_step(step + 1)
	else:
		finish()

func finish() -> void:
	var s := FE.save()
	if s:
		var r := NameRules.validate(pname)
		s.profile["player_name"] = r.name if r.ok else NameRules.dice(_rng)
		s.profile["setup_done"] = true
		s.save_profile()
		s.set_setting("controls", "last_device", device)
	go("home")

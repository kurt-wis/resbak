class_name HudSkills
extends HudPart

## Bottom centre (docs/RESBAK.md § 7; v0.1.1 sizes): passive card, S1 and S2 with the key, a
## clockwise cooldown sweep with the seconds left, and a READY glow. Above the cards a row of
## status chips says what is happening to you right now (protected, capture lockout, slowed,
## sped up, stunned, can't tag). Countdown greys the skills. Tradisyonal (skills off) keeps the
## cards but greys them out with a padlock: no skills in the traditional game. In jail the
## cards give way to the chain card (are you the tip, who steers).

const BOX_W := 236.0
const BOX_H := 128.0
const GAP := 16.0

## "skills" (S1/S2), "chain" (jailed) or "locked" (skills off, Tradisyonal).
var mode := "skills"
var greyed := false
var passive_state := {"fill": 0.0, "on": false, "note": ""}
var chips: Array = [] ## [detail text, color]
var _detail := ""
var _hit_regions: Array[Dictionary] = []
var _pointer_down := false

func _top() -> float:
	return sz().y - 28.0 - BOX_H

func skill_rect(i: int) -> Rect2:
	var cx := sz().x * 0.5 + (BOX_W + GAP) * 0.5
	return Rect2(cx - GAP * 0.5 - BOX_W if i == 0 else cx + GAP * 0.5, _top(), BOX_W, BOX_H)

func passive_rect() -> Rect2:
	if hud and hud.touch and hud.touch.visible:
		return Rect2(sz().x * 0.5 - BOX_W * 0.5, _top(), BOX_W, BOX_H)
	return Rect2(skill_rect(0).position.x - GAP - BOX_W, _top(), BOX_W, BOX_H)

func refresh(_delta: float) -> void:
	var me := hud.local
	visible = me != null
	if me == null:
		return
	if me.state == Hero.State.JAILED or me.state == Hero.State.CHAINED:
		mode = "chain"
	elif not hud.host.skills_enabled():
		mode = "locked"
	else:
		mode = "skills"
	greyed = not hud.host.round_live()
	if me.passive:
		passive_state = me.passive.hud_state()
	chips = _chips(me)
	queue_redraw()

func _chips(me: Hero) -> Array:
	var out: Array = []
	if not me.is_free() or not hud.host.round_live():
		return out
	if me.has_ep():
		out.append(["PROTEKTADO %ds" % ceili(RB.seconds(me.ep_ticks)), Color("7fd0ff")])
	if me.is_immune():
		out.append(["GALIT! DI MAHULI %ds" % ceili(RB.seconds(me.immune_ticks)), HudStyle.RED])
	if me.lockout_ticks > 0:
		out.append(["BAWAL MAG-AGAW %ds" % ceili(RB.seconds(me.lockout_ticks)), HudStyle.GREY])
	if me.is_stunned():
		out.append(["HILO!", HudStyle.ORANGE])
	elif me.is_stumbling():
		out.append(["NADAPA", HudStyle.ORANGE])
	if me.tag_block_ticks > 0:
		out.append(["DI MAKATAYA %ds" % ceili(RB.seconds(me.tag_block_ticks)), HudStyle.GREY])
	if me.cast_lock_ticks > 0:
		out.append(["RECOVERING %.1f s: planted briefly; opponents can still tag you." % RB.seconds(me.cast_lock_ticks), HudStyle.DIM])
	var slow := me.strongest_slow()
	if slow > 0.01:
		out.append(["BAGAL -%d%%" % roundi(slow * 100.0), HudStyle.ORANGE])
	var bonus := me.biggest_bonus()
	if bonus > 0.01:
		out.append(["BILIS +%d%%" % roundi(bonus * 100.0), HudStyle.GREEN])
	if me.capturing:
		var prog := float(me.capture_ticks) / RB.ticks(hud.host.tuning.capture_hold)
		out.append(["INAAGAW %d%%" % roundi(prog * 100.0), HudStyle.GOLD])
	if me.blind_ticks > 0:
		out.append(["BLINDED %.1f s: powdered sugar blocks your vision." % RB.seconds(me.blind_ticks), Color.WHITE])
	if me.hallucinate_ticks > 0:
		out.append(["DIZZY: movement directions are reversed.", HudStyle.RED])
	if hud.host.tag_system.wind_disadvantaged(me):
		out.append(["WIND: slowed 25%; an unaffected opponent wins a simultaneous reciprocal tag.", Color("a5e6ff")])
	for object in hud.host.objects:
		if object is UboCloud and object.contains(me.global_position):
			out.append(["IN POWDER: you can see enemies inside your own smoke." if object.owner_hero == me else "IN POWDER: this smoke blocks hero vision.", Color.WHITE])
			break
	return out

func _draw() -> void:
	var me := hud.local
	if me == null or hud.host == null:
		return
	match mode:
		"skills", "locked":
			_draw_passive(me)
			for i in range(2):
				if hud.touch and hud.touch.visible:
					continue # use the actual skill buttons rather than duplicate keyboard cards
				_draw_skill(me.skills[i], skill_rect(i), hud.key_label("skill_%d" % (i + 1)), mode == "locked")
			if mode == "locked":
				var r := Rect2(skill_rect(0).position + Vector2(0, -34), Vector2(BOX_W * 2.0 + GAP, 28))
				HudStyle.text_in(self, "TRADISYONAL: BAWAL ANG MGA GALING", r, 20, HudStyle.DIM)
		"chain":
			_draw_chain(me)
	_draw_chips()

func _draw_chips() -> void:
	_hit_regions.clear()
	if mode == "chain":
		return
	var total := chips.size() * 62.0
	var x := sz().x * 0.5 - total * 0.5
	for i in range(chips.size()):
		var r := Rect2(x, _top() - 70.0, 52, 52)
		HudStyle.panel(self, r, chips[i][1], Color(0.05, 0.06, 0.09, 0.9), 18, 2)
		SkillAim.draw_icon(self, _status_icon(chips[i][0]), r.get_center(), 15.0, chips[i][1])
		_hit_regions.append({"rect": r, "detail": chips[i][0]})
		x += 62.0
	_hit_regions.append({"rect": Rect2(sz().x * 0.5 - 36, _top() + 26, 72, 72), "detail": hud.local.data.passive_name + " - " + hud.local.data.passive_text})
	if _detail != "":
		var r := Rect2(sz().x * 0.5 - 300.0, _top() - 232.0, 600, 145)
		HudStyle.panel(self, r, Color(1, 1, 1, 0.35), Color(0.04, 0.05, 0.08, 0.96), 22, 2)
		var label := _detail_label()
		label.position = r.position + Vector2(18, 12)
		label.size = r.size - Vector2(36, 24)
		label.text = _detail
		label.visible = true
	elif has_node("EffectDetail"):
		get_node("EffectDetail").visible = false

func _detail_label() -> Label:
	var label := get_node_or_null("EffectDetail") as Label
	if label == null:
		label = HudStyle.label(self, 22)
		label.name = "EffectDetail"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _status_icon(detail: String) -> String:
	if detail.begins_with("BILIS"):
		return "sprint"
	if detail.begins_with("BAGAL") or detail.begins_with("WIND"):
		return "wind"
	if detail.begins_with("HILO") or detail.begins_with("DIZZY") or detail.begins_with("NADAPA"):
		return "impact"
	if detail.begins_with("BLINDED"):
		return "cloud"
	return "shield"

func contains_status(at: Vector2) -> bool:
	for region in _hit_regions:
		if region.rect.has_point(at):
			return true
	return false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or hud == null or hud.input_source == null:
		return
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event.pressed:
		for region in _hit_regions:
			if region.rect.has_point(at):
				_detail = "" if _detail == region.detail else region.detail
				_pointer_down = true
				hud.input_source.ui_pointer_captured = true
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
		_detail = ""
	elif _pointer_down:
		_pointer_down = false
		hud.input_source.ui_pointer_captured = false
		get_viewport().set_input_as_handled()
	queue_redraw()

func _key_badge(p: Vector2, key: String, accent: Color) -> void:
	var w := maxf(42.0, HudStyle.text_width(key, 26) + 18.0)
	var b := Rect2(p, Vector2(w, 40.0))
	HudStyle.panel(self, b, accent, HudStyle.INK, 8, 2)
	HudStyle.text_in(self, key, b, 26, Color.WHITE, 0)

static func kind_text(s: Skill) -> String:
	match s.kind():
		RB.SkillKind.OFFENSIVE:
			return "ATAKE"
		RB.SkillKind.MOVEMENT:
			return "GALAW"
	return "DISKARTE"

func _draw_skill(s: Skill, r: Rect2, key: String, locked: bool) -> void:
	var ready := s.is_ready() and not greyed and not locked
	var accent := HudStyle.GOLD if (s.active or ready) else Color(0.55, 0.56, 0.62)
	if locked or greyed:
		accent = Color(0.42, 0.42, 0.48)
	var fill := Color(0.06, 0.07, 0.1, 0.86)
	if ready:
		fill = Color(0.1, 0.09, 0.05, 0.9)
	HudStyle.panel(self, r, accent, fill, 16, 3 if ready else 2)
	_key_badge(r.position + Vector2(10, 10), key, accent)
	HudStyle.text(self, "", Vector2(r.position.x, r.position.y + 34), 18, Color(accent, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12, 0)
	var name_col := Color.WHITE if not (greyed or locked) else Color(0.62, 0.62, 0.68)
	HudStyle.text(self, "", Vector2(r.position.x, r.end.y - 16.0), 28, name_col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	SkillAim.draw_icon(self, str(SkillAim.profile(s).icon), r.get_center(), 28.0, accent)
	var inner := Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6))
	if locked:
		draw_rect(inner, Color(0.1, 0.1, 0.12, 0.5))
		HudStyle.padlock(self, r.get_center() + Vector2(0, -8), 34.0, Color(0.75, 0.75, 0.8))
		return
	if s.cd_ticks > 0 and not greyed:
		draw_colored_polygon(HudStyle.sweep_polygon(inner, s.cd_fraction()), Color(0, 0, 0, 0.55))
		var secs := ceili(RB.seconds(s.cd_ticks))
		HudStyle.text(self, str(secs), Vector2(r.position.x, r.position.y + 78.0), 50, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10)
	elif s.active:
		var note := s.hud_note()
		HudStyle.text(self, "", Vector2(r.position.x, r.position.y + 74.0), 30, HudStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	elif ready:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 260.0)
		HudStyle.text(self, "", Vector2(r.position.x, r.position.y + 72.0), 24, Color(HudStyle.GOLD, pulse), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 0)
	if greyed:
		draw_rect(inner, Color(0.1, 0.1, 0.12, 0.45))

func _draw_passive(me: Hero) -> void:
	var r := passive_rect()
	r.position = Vector2(sz().x * 0.5 - 36, _top() + 26)
	r.size = Vector2(72, 72)
	var on: bool = passive_state.get("on", false)
	HudStyle.panel(self, r, HudStyle.GOLD if on else Color(1, 1, 1, 0.3), Color(0.06, 0.07, 0.1, 0.86), 24, 2)
	var symbols := {"jm": "shield", "nene": "hand", "nathan": "cloud", "tutoy": "sprint", "inday": "wind"}
	SkillAim.draw_icon(self, symbols[me.data.id], r.get_center(), 22.0, HudStyle.GOLD if on else me.data.color.lightened(0.4))
	HudStyle.arc(self, r.get_center(), 29.0, float(passive_state.get("fill", 0.0)), 3.0, HudStyle.GOLD)

func _draw_chain(me: Hero) -> void:
	var js := hud.host.jail_system
	var owner := RB.other_team(me.team)
	var c: Array = js.chain(owner)
	var w := BOX_W * 3.0 + GAP * 2.0
	var r := Rect2(sz().x * 0.5 - w * 0.5, _top(), w, BOX_H)
	var tip := js.is_tip(me)
	HudStyle.panel(self, r, HudStyle.GOLD if tip else Color(1, 1, 1, 0.3), Color(0.06, 0.07, 0.1, 0.9), 16, 3 if tip else 2)
	HudStyle.text(self, "NAKAKULONG", Vector2(r.position.x + 20, r.position.y + 38), 26, HudStyle.DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	HudStyle.text(self, "Kadena %d" % c.size(), Vector2(r.position.x, r.position.y + 38), 26, HudStyle.DIM, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20, 0)
	var line := ""
	var sub := ""
	if tip:
		line = "IKAW ANG DULO!"
		if hud.use_gamepad():
			sub = "Igalaw papunta sa kakampi para mahawakan ka"
		else:
			sub = "Gumalaw papunta sa kakampi (WASD): ikaw ang hahawakan nila"
	elif not c.is_empty():
		var t: Hero = c[-1]
		line = "NAKAKAPIT KA"
		sub = "Si %s ang dulo: siya ang gumagalaw at aabutin ng kakampi" % t.display_name
	HudStyle.text(self, line, Vector2(r.position.x, r.position.y + 82), 40, HudStyle.GOLD if tip else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	HudStyle.text(self, sub, Vector2(r.position.x, r.end.y - 14), 22, HudStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 6)

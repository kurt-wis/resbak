from pathlib import Path
R=Path(__file__).resolve().parents[1]
p=R/'scripts/ui/hud/hud_skills.gd';s=p.read_text(encoding='utf-8')
s=s.replace('var chips: Array = [] ## [text, color]','var chips: Array = [] ## [detail text, color]\nvar _detail := ""\nvar _hit_regions: Array[Dictionary] = []\nvar _pointer_down := false')
a=s.index('\tvar input := hud.input_source as PlayerInput',s.index('func _chips'));b=s.index('\tif me.has_ep():',a);s=s[:a]+s[b:]
a=s.index('\treturn out',s.index('\tvar bonus :=',s.index('func _chips')))
s=s[:a]+'''\tif me.blind_ticks > 0:
		out.append(["BLINDED %.1f s: powdered sugar blocks your vision." % RB.seconds(me.blind_ticks), Color.WHITE])
	if me.hallucinate_ticks > 0:
		out.append(["DIZZY: movement directions are reversed.", HudStyle.RED])
	if hud.host.tag_system.wind_disadvantaged(me):
		out.append(["WIND: slowed 25%; an unaffected opponent wins a simultaneous reciprocal tag.", Color("a5e6ff")])
'''+s[a:]
a=s.index('func _draw_chips()');b=s.index('func _key_badge',a)
s=s[:a]+'''func _draw_chips() -> void:
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
	_hit_regions.append({"rect": passive_rect(), "detail": hud.local.data.passive_name + "\n" + hud.local.data.passive_text})
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
	return "guard"

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

'''+s[b:]
a=s.index('func _draw_passive(');b=s.index('func _draw_chain(',a)
s=s[:a]+'''func _draw_passive(me: Hero) -> void:
	var r := passive_rect()
	r.position = Vector2(sz().x * 0.5 - 36, _top() + 26)
	r.size = Vector2(72, 72)
	var on: bool = passive_state.get("on", false)
	HudStyle.panel(self, r, HudStyle.GOLD if on else Color(1, 1, 1, 0.3), Color(0.06, 0.07, 0.1, 0.86), 24, 2)
	SkillAim.draw_icon(self, "guard", r.get_center(), 22.0, HudStyle.GOLD if on else me.data.color.lightened(0.4))
	HudStyle.arc(self, r.get_center(), 29.0, float(passive_state.get("fill", 0.0)), 3.0, HudStyle.GOLD)

'''+s[b:]
# The interactive passive region matches its displayed icon.
s=s.replace('"rect": passive_rect(), "detail"','"rect": Rect2(sz().x * 0.5 - 36, _top() + 26, 72, 72), "detail"')
s=s.replace('HudStyle.text(self, kind_text(s),','HudStyle.text(self, "",').replace('HudStyle.text(self, s.skill_name(),','HudStyle.text(self, "",').replace('note if note != "" else "AKTIBO"','""').replace('HudStyle.text(self, "HANDA",','HudStyle.text(self, "",')
s=s.replace('\tvar inner := Rect2(r.position', '\tSkillAim.draw_icon(self, str(SkillAim.profile(s).icon), r.get_center(), 28.0, accent)\n\tvar inner := Rect2(r.position')
p.write_text(s,encoding='utf-8')
p=R/'scripts/match/player_input.gd';s=p.read_text(encoding='utf-8').replace('if Input.is_action_just_pressed("tag") and hero.can_press_tag():','if Input.is_action_just_pressed("tag") and hero.can_press_tag() and not ui_pointer_captured:');p.write_text(s,encoding='utf-8')
p=R/'scripts/match/hero_feedback.gd';s=p.read_text(encoding='utf-8');a=s.index('\tvar captions:');b=s.index('\tlabel.modulate',a)
s=s[:a]+'''\tvar captions: PackedStringArray = []
	if hero.is_free():
		if hero.stun_ticks > 0:
			captions.append("✦")
		if hero.blind_ticks > 0:
			captions.append("◉")
		if hero.hallucinate_ticks > 0:
			captions.append("↻")
		if hero.strongest_slow() > 0.0:
			captions.append("↓")
		for object in hero.host.objects:
			if object is UboCloud and object.contains(hero.global_position):
				captions.append("≋")
				break
	label.text = " ".join(captions)
'''+s[b:];s=s.replace('stars[i].visible = hero.is_free() and (hero.stun_ticks > 0 or hero.hallucinate_ticks > 0 or hero.has_modifier("tamaraw_daze"))','stars[i].visible = false');p.write_text(s,encoding='utf-8')
print('Status UI revised')

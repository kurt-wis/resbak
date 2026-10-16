class_name HudSkills
extends HudPart

## Bottom centre (docs/RESBAK.md § 7): passive icon, S1 and S2 with a clockwise cooldown
## sweep and the key label (Controls.label, per last-used device). Greyed outside live play
## (countdown), hidden in Tradisyonal (skills off), replaced by the chain controls while the
## local hero is jailed. The passive icon reads Passive.hud_state(): {fill, on, note}.

const BOX_W := 170.0
const BOX_H := 88.0
const GAP := 12.0

## "skills" (S1/S2), "chain" (jailed: Interact controls) or "none" (skills off, Tradisyonal).
var mode := "skills"
var greyed := false
var passive_state := {"fill": 0.0, "on": false, "note": ""}

func _top() -> float:
	return sz().y - 24.0 - BOX_H

func skill_rect(i: int) -> Rect2:
	var cx := sz().x * 0.5
	return Rect2(cx - GAP * 0.5 - BOX_W if i == 0 else cx + GAP * 0.5, _top(), BOX_W, BOX_H)

func passive_rect() -> Rect2:
	return Rect2(skill_rect(0).position.x - GAP - BOX_W, _top(), BOX_W, BOX_H)

func refresh(_delta: float) -> void:
	var me := hud.local
	visible = me != null
	if me == null:
		return
	if me.state == Hero.State.JAILED or me.state == Hero.State.CHAINED:
		mode = "chain"
	elif not hud.host.skills_enabled():
		mode = "none"
	else:
		mode = "skills"
	greyed = not hud.host.round_live()
	if me.passive:
		passive_state = me.passive.hud_state()
	queue_redraw()

func _draw() -> void:
	var me := hud.local
	if me == null or hud.host == null:
		return
	_draw_passive(me)
	match mode:
		"skills":
			for i in range(2):
				_draw_skill(me.skills[i], skill_rect(i), hud.key_label("skill_%d" % (i + 1)))
		"chain":
			var r := Rect2(skill_rect(0).position, Vector2(BOX_W * 2.0 + GAP, BOX_H))
			var acting := "KUMAPIT" if me.state == Hero.State.JAILED else "BUMITAW"
			HudStyle.panel(self, r, HudStyle.GOLD)
			_key_badge(Vector2(r.position.x + 12.0, r.position.y + 10.0), hud.key_label("interact"), HudStyle.GOLD)
			HudStyle.text_in(self, acting, Rect2(r.position + Vector2(0, 40), Vector2(r.size.x, 40)), 30, Color.WHITE)

func _key_badge(p: Vector2, key: String, accent: Color) -> void:
	var w := maxf(34.0, HudStyle.text_width(key, 22) + 14.0)
	var b := Rect2(p, Vector2(w, 32.0))
	draw_rect(b, HudStyle.INK)
	draw_rect(b, accent, false, 2.0)
	HudStyle.text_in(self, key, b, 22)

func _draw_skill(s: Skill, r: Rect2, key: String) -> void:
	var can_go := s.is_ready() and not greyed
	var accent := HudStyle.GOLD if (s.active or can_go) else HudStyle.GREY
	if greyed:
		accent = Color(0.45, 0.45, 0.5)
	HudStyle.panel(self, r, accent)
	_key_badge(r.position + Vector2(8, 8), key, accent)
	var name_col := Color.WHITE if not greyed else Color(0.6, 0.6, 0.66)
	HudStyle.text(self, s.skill_name(), Vector2(r.position.x, r.end.y - 14.0), 20, name_col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var inner := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
	if s.cd_ticks > 0 and not greyed:
		draw_colored_polygon(HudStyle.sweep_polygon(inner, s.cd_fraction()), Color(0, 0, 0, 0.55))
		var secs := ceili(RB.seconds(s.cd_ticks))
		HudStyle.text(self, str(secs), Vector2(r.end.x - 70.0, r.position.y + 36.0), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 62.0)
	elif s.active:
		var note := s.hud_note()
		if note != "":
			HudStyle.text(self, note, Vector2(r.end.x - 90.0, r.position.y + 34.0), 24, HudStyle.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 82.0)
	if greyed:
		draw_rect(inner, Color(0.1, 0.1, 0.12, 0.55))

func _draw_passive(me: Hero) -> void:
	var r := passive_rect()
	var on: bool = passive_state.get("on", false)
	var fill: float = clampf(float(passive_state.get("fill", 0.0)), 0.0, 1.0)
	var note: String = str(passive_state.get("note", ""))
	HudStyle.panel(self, r, HudStyle.GOLD if on else HudStyle.PANEL_EDGE)
	HudStyle.text(self, "PASIBO", r.position + Vector2(8, 26), 18, HudStyle.DIM)
	if note != "":
		HudStyle.text(self, note, Vector2(r.end.x - 90.0, r.position.y + 26.0), 20, HudStyle.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 82.0)
	var bar := Rect2(r.position + Vector2(8, 36), Vector2(r.size.x - 16.0, 12))
	draw_rect(bar, HudStyle.INK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), me.data.color.lightened(0.2) if not on else HudStyle.GOLD)
	draw_rect(bar, Color(1, 1, 1, 0.4), false, 1.5)
	HudStyle.text(self, me.passive.passive_name() if me.passive else "", Vector2(r.position.x, r.end.y - 12.0), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

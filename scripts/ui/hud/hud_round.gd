class_name HudRound
extends HudPart

## Countdown and the between-rounds sequence (docs/RESBAK.md § 6, § 7).
## Countdown: 3, 2, 1 centre screen (KABOOM! is the banner). Between rounds, timed in host
## ticks from the round_end event: [capture slow motion 0.5 s], result banner 2 s (winner
## colour, draw white TABLA! Ulit!), freeze frame 2 s (letterbox), score update + round best
## player card 3 s. A draw has the banner only.

var stage := "" ## "", "countdown", "slowmo", "banner", "freeze", "card"
var result := {}
var total_ticks := 0
var slow_secs := 0.0

var count_label: Label
var round_label: Label
var result_label: Label
var sub_label: Label
var card_title: Label
var card_score_left: Label
var card_dash: Label
var card_score_right: Label
var card_head: Label
var card_name: Label
var card_stats: Label
var card_hero: Label

var _card := Rect2()
var _best: Hero
var _card_labels: Array[Label] = []

func _init() -> void:
	count_label = HudStyle.label(self, 240, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.GOLD, 18)
	round_label = HudStyle.label(self, 40, HORIZONTAL_ALIGNMENT_CENTER)
	result_label = HudStyle.label(self, 110, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, 14)
	sub_label = HudStyle.label(self, 40, HORIZONTAL_ALIGNMENT_CENTER)
	card_title = HudStyle.label(self, 34, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.DIM)
	card_score_left = HudStyle.label(self, 96, HORIZONTAL_ALIGNMENT_RIGHT)
	card_dash = HudStyle.label(self, 80, HORIZONTAL_ALIGNMENT_CENTER)
	card_score_right = HudStyle.label(self, 96, HORIZONTAL_ALIGNMENT_LEFT)
	card_head = HudStyle.label(self, 28, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.GOLD)
	card_name = HudStyle.label(self, 40, HORIZONTAL_ALIGNMENT_LEFT)
	card_stats = HudStyle.label(self, 26, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.DIM)
	card_hero = HudStyle.label(self, 26, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.DIM)
	card_dash.text = "-"
	_card_labels = [card_title, card_score_left, card_dash, card_score_right, card_head, card_name, card_stats, card_hero]
	for l in [count_label, round_label, result_label, sub_label] + _card_labels:
		(l as Label).visible = false

func _layout() -> void:
	var s := sz()
	count_label.position = Vector2(0, s.y * 0.5 - 220.0)
	count_label.size = Vector2(s.x, 300)
	count_label.pivot_offset = count_label.size * 0.5
	round_label.position = Vector2(0, s.y * 0.5 - 300.0)
	round_label.size = Vector2(s.x, 60)
	result_label.position = Vector2(0, s.y * 0.3)
	result_label.size = Vector2(s.x, 150)
	result_label.pivot_offset = result_label.size * 0.5
	sub_label.position = Vector2(0, s.y * 0.3 + 140.0)
	sub_label.size = Vector2(s.x, 56)
	_card = Rect2((s.x - 860.0) * 0.5, s.y * 0.5 - 220.0, 860.0, 440.0)
	card_title.position = _card.position + Vector2(0, 14)
	card_title.size = Vector2(_card.size.x, 50)
	card_score_left.position = _card.position + Vector2(0, 66)
	card_score_left.size = Vector2(_card.size.x * 0.5 - 40.0, 120)
	card_dash.position = _card.position + Vector2(_card.size.x * 0.5 - 40.0, 66)
	card_dash.size = Vector2(80, 120)
	card_score_right.position = _card.position + Vector2(_card.size.x * 0.5 + 40.0, 66)
	card_score_right.size = Vector2(_card.size.x * 0.5 - 40.0, 120)
	card_head.position = _card.position + Vector2(190, 214)
	card_head.size = Vector2(620, 40)
	card_name.position = _card.position + Vector2(190, 256)
	card_name.size = Vector2(620, 54)
	card_hero.position = _card.position + Vector2(190, 310)
	card_hero.size = Vector2(620, 40)
	card_stats.position = _card.position + Vector2(190, 352)
	card_stats.size = Vector2(620, 40)

func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"countdown":
			result = {}
		"round_end":
			result = d.duplicate()
			total_ticks = hud.host.round_flow.phase_ticks
			var won_by_capture: bool = int(d.winner) >= 0 and d.reason == "capture"
			slow_secs = hud.host.tuning.capture_slow_motion if won_by_capture else 0.0
			_best = hud.host.hero_by_slot(int(d.get("best", -1)))

func result_text() -> String:
	if result.is_empty():
		return ""
	if int(result.winner) < 0:
		return "TABLA! Ulit!"
	match result.reason:
		"capture":
			return "NAKUHA ANG BASE!"
		"lockdown":
			return "LOCKDOWN!"
		"sunset":
			return "UWI NA!"
		"sudden_death":
			return "TAKIPSILIM!"
	return "NAKUHA ANG BASE!"

func _stage(rf: RoundFlow) -> String:
	match rf.phase:
		RoundFlow.Phase.COUNTDOWN:
			return "countdown"
		RoundFlow.Phase.ROUND_OVER:
			if result.is_empty():
				return ""
			var t := hud.host.tuning
			var e := RB.seconds(total_ticks - rf.phase_ticks)
			if e < slow_secs:
				return "slowmo"
			if e < slow_secs + t.between_rounds_banner:
				return "banner"
			if int(result.winner) < 0:
				return ""
			if e < slow_secs + t.between_rounds_banner + t.between_rounds_freeze:
				return "freeze"
			return "card"
	return ""

func refresh(_delta: float) -> void:
	var host := hud.host
	var rf := host.round_flow
	stage = _stage(rf)
	count_label.visible = stage == "countdown"
	round_label.visible = stage == "countdown"
	result_label.visible = stage == "banner"
	sub_label.visible = stage == "banner" and int(result.get("winner", -1)) >= 0
	var card := stage == "card"
	for l in _card_labels:
		l.visible = card
	if count_label.visible:
		var left := RB.seconds(rf.phase_ticks)
		var n := ceili(left)
		count_label.text = str(maxi(n, 1))
		var within := float(n) - left # 0 at the start of each number
		var sc := lerpf(1.5, 1.0, minf(within * 4.0, 1.0))
		count_label.scale = Vector2(sc, sc)
		count_label.modulate.a = 1.0 - maxf(0.0, within - 0.7) / 0.3
		round_label.text = "RONDA %d" % rf.round_number
	if result_label.visible:
		result_label.text = result_text()
		var win := int(result.winner)
		HudStyle.set_color(result_label, hud.team_color(win) if win >= 0 else Color.WHITE)
		if win >= 0:
			sub_label.text = "%s +1" % RB.TEAM_FULL_NAMES[win]
			HudStyle.set_color(sub_label, hud.team_color(win))
		var e := RB.seconds(total_ticks - rf.phase_ticks) - slow_secs
		var sc2 := lerpf(1.35, 1.0, clampf(e / 0.18, 0.0, 1.0))
		result_label.scale = Vector2(sc2, sc2)
	if card:
		_refresh_card()
	queue_redraw()

func _refresh_card() -> void:
	var host := hud.host
	var rf := host.round_flow
	var lt := hud.left_team()
	var rt := RB.other_team(lt)
	var score: Array = result.get("score", rf.score)
	card_title.text = "RONDA %d" % int(result.get("round", rf.round_number))
	card_score_left.text = str(score[lt])
	card_score_right.text = str(score[rt])
	HudStyle.set_color(card_score_left, hud.team_color(lt))
	HudStyle.set_color(card_score_right, hud.team_color(rt))
	if _best:
		var st: Dictionary = host.stats[_best.slot]
		card_head.text = "BIDA NG RONDA"
		card_name.text = _best.display_name
		HudStyle.set_color(card_name, hud.team_color(_best.team))
		card_hero.text = _best.data.display_name
		card_stats.text = "Impact +%d   Tag %d   Resbak %d   Taya %d" % [st.round_impact, st.tags, st.rescues, st.captures]
	else:
		card_head.text = ""
		card_name.text = ""
		card_hero.text = ""
		card_stats.text = ""

func _draw() -> void:
	var s := sz()
	if stage == "freeze":
		draw_rect(Rect2(0, 0, s.x, 90), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(0, s.y - 90, s.x, 90), Color(0, 0, 0, 0.7))
		var win := int(result.get("winner", -1))
		HudStyle.text(self, result_text(), Vector2(0, s.y - 32), 44, hud.team_color(win) if win >= 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	elif stage == "card":
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.4))
		HudStyle.panel(self, _card, HudStyle.PANEL_EDGE, Color(0.05, 0.07, 0.1, 0.92), 24)
		if _best:
			var c := _card.position + Vector2(100, 300)
			Portraits.draw_face(self, _best.data.id, c, 64.0, _best.data.color.darkened(0.3), hud.team_color(_best.team), 5.0, 0.0, HudStyle.font())

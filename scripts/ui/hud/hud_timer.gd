class_name HudTimer
extends HudPart

## Top centre scorebug (docs/RESBAK.md § 7; v0.1.1 layout): own team left. Each side shows the
## team name, its score and one pip per point to win. The middle shows the round number, the
## m:ss clock and a time bar that drains from gold to red as the sun sets (it replaced the
## small sun picture, which players read as a mystery icon). Sudden death turns the middle red
## and says TAKIPSILIM with its 30 s count; an untimed sudden death shows no number.

const W := 640.0
const H := 124.0
const MID := 230.0 ## width of the middle block

var score_left: Label
var score_right: Label
var name_left: Label
var name_right: Label
var timer_label: Label
var round_label: Label
var sd_label: Label ## kept for older callers; the round label shows TAKIPSILIM now
var sun_fraction := 0.0 ## 0 = round start, 1 = sunset (time bar)
var _sudden_seen := false
var _rect := Rect2()

func _init() -> void:
	score_left = HudStyle.label(self, 78, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, 12)
	score_right = HudStyle.label(self, 78, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, 12)
	name_left = HudStyle.label(self, 20, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, 6)
	name_right = HudStyle.label(self, 20, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, 6)
	timer_label = HudStyle.label(self, 58, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, 10)
	round_label = HudStyle.label(self, 20, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.DIM, 6)
	sd_label = round_label

func _layout() -> void:
	var cx := sz().x * 0.5
	_rect = Rect2(cx - W * 0.5, 10.0, W, H)
	var side := (W - MID) * 0.5
	name_left.position = Vector2(_rect.position.x, 16)
	name_left.size = Vector2(side, 26)
	name_right.position = Vector2(_rect.end.x - side, 16)
	name_right.size = Vector2(side, 26)
	score_left.position = Vector2(_rect.position.x, 34)
	score_left.size = Vector2(side, 72)
	score_right.position = Vector2(_rect.end.x - side, 34)
	score_right.size = Vector2(side, 72)
	round_label.position = Vector2(cx - MID * 0.5, 16)
	round_label.size = Vector2(MID, 26)
	timer_label.position = Vector2(cx - MID * 0.5, 40)
	timer_label.size = Vector2(MID, 62)

func _fmt(secs: float) -> String:
	var s := ceili(secs)
	return "%d:%02d" % [s / 60, s % 60]

func panel_rect() -> Rect2:
	return _rect

func refresh(_delta: float) -> void:
	var host := hud.host
	var rf := host.round_flow
	var lt := hud.left_team()
	var rt := RB.other_team(lt)
	score_left.text = str(rf.score[lt])
	score_right.text = str(rf.score[rt])
	HudStyle.set_color(score_left, hud.team_color(lt))
	HudStyle.set_color(score_right, hud.team_color(rt))
	name_left.text = RB.TEAM_FULL_NAMES[lt].to_upper()
	name_right.text = RB.TEAM_FULL_NAMES[rt].to_upper()
	HudStyle.set_color(name_left, hud.team_color(lt).lightened(0.25))
	HudStyle.set_color(name_right, hud.team_color(rt).lightened(0.25))
	if rf.phase == RoundFlow.Phase.COUNTDOWN:
		_sudden_seen = false
	var sudden := rf.phase == RoundFlow.Phase.SUDDEN_DEATH
	if sudden:
		_sudden_seen = true
		timer_label.text = "" if rf.timer_ticks < 0 else _fmt(rf.clock_seconds())
		round_label.text = "TAKIPSILIM"
		HudStyle.set_color(round_label, HudStyle.RED)
		HudStyle.set_color(timer_label, HudStyle.RED)
	else:
		timer_label.text = _fmt(rf.clock_seconds())
		round_label.text = "RONDA %d" % maxi(rf.round_number, 1)
		HudStyle.set_color(round_label, HudStyle.DIM)
		var low := rf.phase == RoundFlow.Phase.PLAYING and rf.clock_seconds() <= 30.0
		HudStyle.set_color(timer_label, HudStyle.ORANGE if low else Color.WHITE)
	var total := RB.ticks(float(host.settings.get("round_time", host.tuning.round_time)))
	if _sudden_seen:
		sun_fraction = 1.0
	elif total > 0 and rf.phase != RoundFlow.Phase.COUNTDOWN:
		sun_fraction = clampf(1.0 - float(rf.timer_ticks) / total, 0.0, 1.0)
	else:
		sun_fraction = 0.0
	queue_redraw()

func _draw() -> void:
	if hud == null or hud.host == null:
		return
	var rf := hud.host.round_flow
	var cx := sz().x * 0.5
	var lt := hud.left_team()
	var rt := RB.other_team(lt)
	var side := (W - MID) * 0.5
	HudStyle.panel(self, _rect, Color(1, 1, 1, 0.18), HudStyle.PANEL, 18)
	# team colour bands along the top of each side
	draw_rect(Rect2(_rect.position.x + 14, _rect.position.y + 3, side - 28, 5), hud.team_color(lt))
	draw_rect(Rect2(_rect.end.x - side + 14, _rect.position.y + 3, side - 28, 5), hud.team_color(rt))
	# middle block
	var mid := Rect2(cx - MID * 0.5 + 8, _rect.position.y + 8, MID - 16, H - 16)
	HudStyle.panel(self, mid, Color(0, 0, 0, 0), Color(0, 0, 0, 0.35), 12, 0)
	# time bar: drains from right to left, gold -> orange -> red, a sun dot rides its end
	var bar := Rect2(cx - 86, _rect.end.y - 22, 172, 9)
	draw_rect(bar, Color(0, 0, 0, 0.55))
	var left := 1.0 - sun_fraction
	var col := Color("ffd34d").lerp(Color("ff6a2a"), clampf(sun_fraction * 1.3, 0.0, 1.0))
	if rf.phase == RoundFlow.Phase.SUDDEN_DEATH:
		col = HudStyle.RED
		left = 1.0 if rf.timer_ticks < 0 else clampf(float(rf.timer_ticks) / RB.ticks(hud.host.tuning.sudden_death_time), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), col)
	draw_circle(Vector2(bar.position.x + bar.size.x * left, bar.get_center().y), 8.0, col.lightened(0.2))
	draw_arc(Vector2(bar.position.x + bar.size.x * left, bar.get_center().y), 8.0, 0.0, TAU, 20, HudStyle.INK, 2.0, true)
	# point pips under each score
	var pts := rf.points_to_win()
	for side_i in range(2):
		var team := lt if side_i == 0 else rt
		var centre_x := _rect.position.x + side * 0.5 if side_i == 0 else _rect.end.x - side * 0.5
		var span := (pts - 1) * 24.0
		for i in range(pts):
			_dot(Vector2(centre_x - span * 0.5 + i * 24.0, _rect.end.y - 14), hud.team_color(team), i < rf.score[team])

func _dot(c: Vector2, color: Color, filled: bool) -> void:
	draw_circle(c, 9.0, HudStyle.INK)
	if filled:
		draw_circle(c, 7.0, color)
	else:
		draw_arc(c, 6.5, 0.0, TAU, 20, Color(color, 0.8), 2.0, true)

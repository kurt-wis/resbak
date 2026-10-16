class_name HudTimer
extends HudPart

## Top centre (docs/RESBAK.md § 7): sinking-sun timer, both scores (own team left), m:ss
## below the sun, one dot per point to win under each score. Sudden death shows its 30 s
## countdown and a TAKIPSILIM line; an untimed sudden death shows no number.

## The sun badge. A child so its own rect clips the sun as it sinks behind the horizon.
class SunBadge extends Control:
	var frac := 0.0 ## 0 = round start, 1 = sunk
	var sudden := false

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(120, 86)
		custom_minimum_size = size

	func _draw() -> void:
		var h := size.y * 0.7
		var top := Color("3a2a6e").lerp(Color("4a0c10"), 1.0 if sudden else frac * 0.5)
		var low := Color("ffb35c").lerp(Color("c0392b"), 1.0 if sudden else frac)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, h), Vector2(0, h)]), PackedColorArray([top, top, low, low]))
		var r := 24.0
		var sun := Color("ffd34d").lerp(Color("ff6a2a"), frac)
		if sudden:
			sun = Color("a31616")
		draw_circle(Vector2(size.x * 0.5, lerpf(h - r * 1.05, h + r + 3.0, frac)), r, sun)
		draw_rect(Rect2(0, h, size.x, size.y - h), Color("1a1520"))
		draw_line(Vector2(0, h), Vector2(size.x, h), Color(1, 0.85, 0.6, 0.7), 2.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.3), false, 2.0)

var badge: SunBadge
var score_left: Label
var score_right: Label
var name_left: Label
var name_right: Label
var timer_label: Label
var sd_label: Label
var sun_fraction := 0.0
var _sudden_seen := false

func _init() -> void:
	badge = SunBadge.new()
	badge.name = "Sun"
	add_child(badge)
	score_left = HudStyle.label(self, 64, HORIZONTAL_ALIGNMENT_RIGHT)
	score_right = HudStyle.label(self, 64, HORIZONTAL_ALIGNMENT_LEFT)
	name_left = HudStyle.label(self, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	name_right = HudStyle.label(self, 20, HORIZONTAL_ALIGNMENT_LEFT)
	timer_label = HudStyle.label(self, 40, HORIZONTAL_ALIGNMENT_CENTER)
	sd_label = HudStyle.label(self, 30, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.RED)

func _layout() -> void:
	var cx := sz().x * 0.5
	badge.position = Vector2(cx - 60.0, 6.0)
	score_left.position = Vector2(cx - 70.0 - 130.0, 2.0)
	score_left.size = Vector2(130, 80)
	score_right.position = Vector2(cx + 70.0, 2.0)
	score_right.size = Vector2(130, 80)
	name_left.position = Vector2(cx - 70.0 - 200.0, 80.0)
	name_left.size = Vector2(200, 28)
	name_right.position = Vector2(cx + 70.0, 80.0)
	name_right.size = Vector2(200, 28)
	timer_label.position = Vector2(cx - 90.0, 92.0)
	timer_label.size = Vector2(180, 48)
	sd_label.position = Vector2(cx - 200.0, 142.0)
	sd_label.size = Vector2(400, 38)

func _fmt(secs: float) -> String:
	var s := ceili(secs)
	return "%d:%02d" % [s / 60, s % 60]

func refresh(_delta: float) -> void:
	var host := hud.host
	var rf := host.round_flow
	var lt := hud.left_team()
	var rt := RB.other_team(lt)
	score_left.text = str(rf.score[lt])
	score_right.text = str(rf.score[rt])
	HudStyle.set_color(score_left, hud.team_color(lt))
	HudStyle.set_color(score_right, hud.team_color(rt))
	name_left.text = RB.TEAM_NAMES[lt].to_upper()
	name_right.text = RB.TEAM_NAMES[rt].to_upper()
	HudStyle.set_color(name_left, hud.team_color(lt))
	HudStyle.set_color(name_right, hud.team_color(rt))
	if rf.phase == RoundFlow.Phase.COUNTDOWN:
		_sudden_seen = false
	if rf.phase == RoundFlow.Phase.SUDDEN_DEATH:
		_sudden_seen = true
		timer_label.text = "" if rf.timer_ticks < 0 else _fmt(rf.clock_seconds())
		sd_label.text = "TAKIPSILIM"
	else:
		timer_label.text = _fmt(rf.clock_seconds())
		sd_label.text = ""
	var total := RB.ticks(float(host.settings.get("round_time", host.tuning.round_time)))
	if _sudden_seen:
		sun_fraction = 1.0
	elif total > 0 and rf.phase != RoundFlow.Phase.COUNTDOWN:
		sun_fraction = clampf(1.0 - float(rf.timer_ticks) / total, 0.0, 1.0)
	else:
		sun_fraction = 0.0
	badge.frac = sun_fraction
	badge.sudden = rf.phase == RoundFlow.Phase.SUDDEN_DEATH
	badge.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if hud == null or hud.host == null:
		return
	var rf := hud.host.round_flow
	var cx := sz().x * 0.5
	var lt := hud.left_team()
	var rt := RB.other_team(lt)
	var pts := rf.points_to_win()
	for i in range(pts):
		var lx := cx - 76.0 - i * 26.0
		var rx := cx + 76.0 + i * 26.0
		_dot(Vector2(lx, 132), hud.team_color(lt), i < rf.score[lt])
		_dot(Vector2(rx, 132), hud.team_color(rt), i < rf.score[rt])

func _dot(c: Vector2, color: Color, filled: bool) -> void:
	draw_circle(c, 10.0, HudStyle.INK)
	if filled:
		draw_circle(c, 8.0, color)
	else:
		draw_arc(c, 8.0, 0.0, TAU, 20, color, 2.0, true)

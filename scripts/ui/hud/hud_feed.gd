class_name HudFeed
extends HudPart

## Tag feed on the left (docs/RESBAK.md § 7, strings § 13): tags (guard breaks too), rescues,
## captures and lockdown, both teams. 5 s per line, at most 5 lines; times count in host
## ticks so a paused match keeps its lines. Each line is a dark pill with a stripe in the
## acting team's colour.

const MARGIN := 24.0
const TOP := 150.0
const LINE_H := 40.0
const FONT := 24

var lines: Array[Dictionary] = [] ## {text, color, tick}

func line_rect(index: int) -> Rect2:
	var map_rect := hud.minimap.rect
	var width := maxf(map_rect.size.x, 350.0)
	return Rect2(sz().x - MARGIN - width, map_rect.end.y + 14.0 + index * (LINE_H + 6.0), width, LINE_H)

func texts() -> PackedStringArray:
	var out := PackedStringArray()
	for l in lines:
		out.append(l.text)
	return out

func add_line(text: String, color: Color) -> void:
	lines.append({"text": text, "color": color, "tick": hud.host.tick})
	var max_lines := hud.host.tuning.tag_feed_lines
	while lines.size() > max_lines:
		lines.pop_front()

func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"tag":
			var tagger: Hero = d.tagger
			var target: Hero = d.target
			add_line("%s HINULI si %s" % [tagger.display_name, target.display_name], hud.team_color(tagger.team))
		"guard_break":
			var tagger: Hero = d.tagger
			add_line("%s SINIRA ang bantay ni JM" % tagger.display_name, hud.team_color(tagger.team))
		"rescue":
			var rescuer: Hero = d.rescuer
			add_line("%s RESBAK x%d" % [rescuer.display_name, (d.freed as Array).size()], hud.team_color(rescuer.team))
		"capture":
			var h: Hero = d.hero
			add_line("%s NAKUHA ANG BASE!" % h.display_name, hud.team_color(h.team))
		"round_end":
			if d.reason == "lockdown" and d.winner >= 0:
				add_line("LOCKDOWN!", hud.team_color(d.winner))
		"countdown":
			lines.clear()

func refresh(_delta: float) -> void:
	var life := RB.ticks(hud.host.tuning.tag_feed_seconds)
	var now := hud.host.tick
	for i in range(lines.size() - 1, -1, -1):
		if now - int(lines[i].tick) >= life:
			lines.remove_at(i)
	visible = hud.feed_visible
	queue_redraw()

func _draw() -> void:
	if hud == null or hud.host == null:
		return
	var life := RB.ticks(hud.host.tuning.tag_feed_seconds)
	var now := hud.host.tick
	for i in range(lines.size()):
		var l: Dictionary = lines[i]
		var left := life - (now - int(l.tick))
		var a := clampf(float(left) / 30.0, 0.0, 1.0)
		var r := line_rect(i)
		HudStyle.panel(self, r, Color(0, 0, 0, 0), Color(0.05, 0.06, 0.09, 0.72 * a), 10, 0)
		draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(6, LINE_H - 8)), Color(l.color, a))
		HudStyle.text(self, l.text, Vector2(r.position.x + 20, r.get_center().y + FONT * 0.36), FONT, Color(l.color.lightened(0.15), a), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 6 if a > 0.5 else 0)

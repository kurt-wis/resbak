class_name HudFeed
extends HudPart

## Tag feed on the left (docs/RESBAK.md § 7, strings § 13): tags (guard breaks too), rescues,
## captures and lockdown, both teams. 5 s per line, at most 5 lines; times count in host
## ticks so a paused match keeps its lines.

const MARGIN := 24.0

var lines: Array[Dictionary] = [] ## {text, color, tick}
var labels: Array[Label] = []

func _init() -> void:
	for i in range(8):
		var l := HudStyle.label(self, 24, HORIZONTAL_ALIGNMENT_LEFT)
		l.visible = false
		labels.append(l)

func _layout() -> void:
	for i in range(labels.size()):
		labels[i].position = Vector2(MARGIN, 250.0 + i * 36.0)
		labels[i].size = Vector2(700, 34)

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
	for i in range(labels.size()):
		var l := labels[i]
		if i < lines.size():
			l.visible = true
			l.text = lines[i].text
			HudStyle.set_color(l, lines[i].color)
			var left := life - (now - int(lines[i].tick))
			l.modulate.a = clampf(float(left) / 30.0, 0.0, 1.0)
		else:
			l.visible = false

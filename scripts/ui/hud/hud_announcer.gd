class_name HudAnnouncer
extends HudPart

## MOBA-style announcer banners (v0.2, docs/status.md): a slanted ribbon in the actor's team
## colour slides in under the scorebug with a big call and a small line saying who. Calls
## queue so they never overlap, and each one also goes to Audio.announce (subtitle cue, plus a
## voice line once assets/audio/announcer_<id> exists). Presentation only: it counts streaks
## from host events and never changes game state. Numbers: Tuning "HUD and senses".
##   UNANG HULI!       first tag of the round
##   DOBLENG / TRIPLENG HULI!  2 / 3+ tags by one player, each within announce_multi_window
##   MAINIT! / HALIMAW! / DI MAPIGILAN!  streak of tags without being caught (hot/beast/unstoppable)
##   PINAHINTO!        catching a player who was on a streak (hot or more)
##   RESBAK!           a rescue
##   NAAGAW ANG BASE!  a base capture
##   LAHAT HULI!       a round won by lockdown (every enemy caught)

const SLIDE := 0.16 ## s, ribbon slide-in
const FADE := 0.25 ## s, fade-out at the end
const WIDTH := 820.0
const HEIGHT := 96.0
const SKEW := 36.0
const TITLE_FONT := 64
const SUB_FONT := 26

var queue: Array[Dictionary] = [] ## {id, title, sub, color}
var current: Dictionary = {} ## the call on screen, empty when none
var history: PackedStringArray = [] ## every call id made this match (tests, debugging)
var _age := 0.0 ## seconds the current call has been up

var _first_tag_done := false
var _streak := {} ## Hero -> tags since last caught
var _multi := {} ## Hero -> {count, tick}

func on_event(kind: String, d: Dictionary) -> void:
	for c in calls_for(kind, d):
		push(c)

## The calls one host event makes, in the order they play, and the streak bookkeeping.
func calls_for(kind: String, d: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := hud.host.tuning
	match kind:
		"countdown":
			_first_tag_done = false
			_streak.clear()
			_multi.clear()
		"tag":
			var tagger: Hero = d.tagger
			var target: Hero = d.target
			var col := hud.team_color(tagger.team)
			var victim_streak := int(_streak.get(target, 0))
			_streak[target] = 0
			_multi.erase(target)
			var streak := int(_streak.get(tagger, 0)) + 1
			_streak[tagger] = streak
			var m: Dictionary = _multi.get(tagger, {"count": 0, "tick": -1_000_000})
			var count := 1
			if hud.host.tick - int(m.tick) <= RB.ticks(t.announce_multi_window):
				count = int(m.count) + 1
			_multi[tagger] = {"count": count, "tick": hud.host.tick}
			if not _first_tag_done:
				_first_tag_done = true
				out.append(_call("first_tag", "UNANG HULI!", "%s ang unang nakahuli" % tagger.display_name, col))
			if victim_streak >= t.announce_streak_hot:
				out.append(_call("shutdown", "PINAHINTO!", "%s pinahinto si %s" % [tagger.display_name, target.display_name], col))
			if count == 2:
				out.append(_call("double", "DOBLENG HULI!", tagger.display_name, col))
			elif count >= 3:
				out.append(_call("triple", "TRIPLENG HULI!", tagger.display_name, col))
			if streak == t.announce_streak_hot:
				out.append(_call("hot", "MAINIT!", "%s: %d sunod-sunod" % [tagger.display_name, streak], col))
			elif streak == t.announce_streak_beast:
				out.append(_call("beast", "HALIMAW!", "%s: %d sunod-sunod" % [tagger.display_name, streak], col))
			elif streak >= t.announce_streak_unstoppable and (streak - t.announce_streak_unstoppable) % 2 == 0:
				out.append(_call("unstoppable", "DI MAPIGILAN!", "%s: %d sunod-sunod" % [tagger.display_name, streak], col))
		"rescue":
			var rescuer: Hero = d.rescuer
			var n := (d.freed as Array).size()
			out.append(_call("rescue", "RESBAK!", "%s nagligtas ng %d" % [rescuer.display_name, n], hud.team_color(rescuer.team)))
		"capture":
			var h: Hero = d.hero
			out.append(_call("capture", "NAAGAW ANG BASE!", h.display_name, hud.team_color(h.team)))
		"round_end":
			if str(d.get("reason", "")) == "lockdown" and int(d.get("winner", -1)) >= 0:
				out.append(_call("ace", "LAHAT HULI!", "Huli ang buong koponan", hud.team_color(int(d.winner))))
	return out

func _call(id: String, title: String, sub: String, color: Color) -> Dictionary:
	return {"id": id, "title": title, "sub": sub, "color": color}

func push(c: Dictionary) -> void:
	history.append(c.id)
	var audio := get_node_or_null("/root/Audio") if is_inside_tree() else null
	if audio:
		audio.announce("announcer_" + str(c.id), str(c.title))
	queue.append(c)
	while queue.size() > hud.host.tuning.announce_queue_max:
		queue.pop_front() # stale calls drop; the newest moments win
	if current.is_empty():
		_next()

func _next() -> void:
	current = {} if queue.is_empty() else queue.pop_front()
	_age = 0.0

func refresh(delta: float) -> void:
	if not current.is_empty():
		_age += delta
		if _age >= hud.host.tuning.announce_banner_time:
			_next()
	queue_redraw()

func _draw() -> void:
	if current.is_empty() or hud == null:
		return
	var s := sz()
	var life: float = hud.host.tuning.announce_banner_time
	var slide := clampf(_age / SLIDE, 0.0, 1.0)
	var k := 1.0 - pow(1.0 - slide, 3.0)
	var alpha := clampf((life - _age) / FADE, 0.0, 1.0)
	var cx := s.x * 0.5 + (1.0 - k) * -260.0
	var cy := s.y * 0.22 # under the scorebug, above the centre banner (KABOOM!, PANALO!)
	var col: Color = current.color
	var x0 := cx - WIDTH * 0.5
	var x1 := cx + WIDTH * 0.5
	var y0 := cy - HEIGHT * 0.5
	var y1 := cy + HEIGHT * 0.5
	# back plate, a coloured edge band, then the dark face
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + SKEW - 10, y0 - 8), Vector2(x1 + 10, y0 - 8), Vector2(x1 - SKEW + 10, y1 + 8), Vector2(x0 - 10, y1 + 8)]), Color(col.darkened(0.45), 0.85 * alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + SKEW, y0), Vector2(x1, y0), Vector2(x1 - SKEW, y1), Vector2(x0, y1)]), Color(col, 0.95 * alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + SKEW + 14, y0 + 8), Vector2(x1 - 14, y0 + 8), Vector2(x1 - SKEW - 14, y1 - 8), Vector2(x0 + 14, y1 - 8)]), Color(HudStyle.INK, 0.88 * alpha))
	# a light sweep across the face while it slides in
	if slide < 1.0:
		var sx := lerpf(x0, x1, slide)
		draw_colored_polygon(PackedVector2Array([Vector2(sx, y0 + 8), Vector2(sx + 60, y0 + 8), Vector2(sx + 60 - SKEW, y1 - 8), Vector2(sx - SKEW, y1 - 8)]), Color(1, 1, 1, 0.25 * alpha))
	var title_col := Color(col.lightened(0.35), alpha)
	HudStyle.text(self, str(current.title), Vector2(x0, cy + TITLE_FONT * 0.36), TITLE_FONT, title_col, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 10)
	# the who-line on a small tab under the ribbon
	var sub := str(current.sub)
	if sub != "":
		var w := HudStyle.text_width(sub, SUB_FONT) + 40.0
		var tab := Rect2(cx - w * 0.5, y1 + 4, w, SUB_FONT + 14)
		draw_rect(tab, Color(HudStyle.INK, 0.85 * alpha))
		draw_rect(Rect2(tab.position, Vector2(tab.size.x, 3)), Color(col, alpha))
		HudStyle.text_in(self, sub, tab, SUB_FONT, Color(1, 1, 1, alpha), 6)

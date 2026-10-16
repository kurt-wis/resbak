class_name HudTracker
extends HudPart

## Prisoner tracker beside the score (docs/RESBAK.md § 7): five portraits per team, own team
## left. Colour = free, bars = jailed (Tagged and Jailed), linked hands = chained, a bot badge
## when bot-controlled. Portraits use the hero colour and initials.

const PORTRAIT := 48.0
const GAP := 6.0
const INSET := 190.0 ## from the screen centre to the nearest portrait

func state_of(h: Hero) -> String:
	match h.state:
		Hero.State.JAILED, Hero.State.TAGGED:
			return "jailed"
		Hero.State.CHAINED:
			return "chained"
	return "free"

## The team's heroes in team-slot order.
func lineup(team: int) -> Array[Hero]:
	var out := hud.host.team_heroes(team)
	out.sort_custom(func(a: Hero, b: Hero) -> bool: return a.team_slot < b.team_slot)
	return out

func portrait_rect(side: int, index: int) -> Rect2:
	var cx := sz().x * 0.5
	var y := 14.0
	if side == 0:
		var x := cx - INSET - PORTRAIT - index * (PORTRAIT + GAP)
		return Rect2(x, y, PORTRAIT, PORTRAIT)
	return Rect2(cx + INSET + index * (PORTRAIT + GAP), y, PORTRAIT, PORTRAIT)

func refresh(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if hud == null or hud.host == null:
		return
	var lt := hud.left_team()
	for side in range(2):
		var team := lt if side == 0 else RB.other_team(lt)
		var heroes := lineup(team)
		for i in range(heroes.size()):
			_portrait(heroes[i], portrait_rect(side, i), hud.team_color(team))

func _portrait(h: Hero, r: Rect2, team_color: Color) -> void:
	var st := state_of(h)
	var c := r.get_center()
	var col: Color = h.data.color
	draw_circle(c, PORTRAIT * 0.5 + 3.0, team_color)
	draw_circle(c, PORTRAIT * 0.5, col.darkened(0.15) if st == "free" else col.darkened(0.55))
	HudStyle.text_in(self, HudStyle.initials(h), r, 20, Color.WHITE if st == "free" else Color(0.8, 0.8, 0.85))
	if h == hud.local:
		draw_arc(c, PORTRAIT * 0.5 + 6.0, 0.0, TAU, 32, Color.WHITE, 2.0, true)
	match st:
		"jailed":
			for k in range(-2, 3):
				var x := c.x + k * 10.0
				var half := sqrt(maxf(0.0, pow(PORTRAIT * 0.5, 2) - pow(k * 10.0, 2)))
				draw_line(Vector2(x, c.y - half), Vector2(x, c.y + half), Color(0.9, 0.92, 0.96), 4.0)
		"chained":
			# linked hands: two interlocked rings
			draw_arc(c + Vector2(-7, 0), 10.0, 0.0, TAU, 20, Color(1, 1, 1), 4.0, true)
			draw_arc(c + Vector2(7, 0), 10.0, 0.0, TAU, 20, Color(1, 1, 1), 4.0, true)
	if h.is_bot:
		var b := Rect2(r.end.x - 20.0, r.position.y - 4.0, 22.0, 18.0)
		draw_rect(b, Color(0.1, 0.12, 0.16))
		draw_rect(b, Color.WHITE, false, 1.5)
		draw_circle(b.position + Vector2(6, 9), 2.5, Color.WHITE)
		draw_circle(b.position + Vector2(16, 9), 2.5, Color.WHITE)
		draw_line(b.position + Vector2(11, 0), b.position + Vector2(11, -4), Color.WHITE, 2.0)

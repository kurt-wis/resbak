class_name HudTracker
extends HudPart

## Prisoner tracker beside the scorebug (docs/RESBAK.md § 7): five faces per team, own team
## left, nearest the score = team slot 1. Each face is the hero's rendered portrait (Portraits;
## initials until it renders). Free = full colour; Tagged/Jailed = darkened with bars; Chained
## = darkened with a chain-link badge; a BOT tag when bot-controlled; the local player wears a
## white ring and a small arrow.

const R := 31.0 ## portrait radius
const STEP := 68.0
const GAP := 20.0 ## from the scorebug edge to the first face

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
	var edge := HudTimer.W * 0.5 + GAP + R
	var x := cx - edge - index * STEP if side == 0 else cx + edge + index * STEP
	return Rect2(x - R, 72.0 - R, R * 2.0, R * 2.0)

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
	draw_circle(c, R + 5.0, HudStyle.INK)
	var dim := 0.0 if st == "free" else 0.6
	Portraits.draw_face(self, h.data.id, c, R, h.data.color.darkened(0.35), team_color, 4.0, dim, HudStyle.font())
	if h == hud.local:
		draw_arc(c, R + 6.0, 0.0, TAU, 40, Color.WHITE, 3.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8, R + 10), c + Vector2(8, R + 10), c + Vector2(0, R + 2)]), Color.WHITE)
	match st:
		"jailed":
			for k in range(-2, 3):
				var x := c.x + k * 12.0
				var half := sqrt(maxf(0.0, R * R - pow(k * 12.0, 2)))
				draw_line(Vector2(x, c.y - half), Vector2(x, c.y + half), Color(0.92, 0.94, 0.98, 0.9), 4.0)
		"chained":
			var b := c + Vector2(R * 0.62, R * 0.62)
			draw_circle(b, 13.0, HudStyle.INK)
			draw_arc(b + Vector2(-4, 0), 6.0, 0.0, TAU, 16, HudStyle.GOLD, 2.5, true)
			draw_arc(b + Vector2(4, 0), 6.0, 0.0, TAU, 16, HudStyle.GOLD, 2.5, true)
	if h.has_ep() or h.is_immune():
		var s := c + Vector2(-R * 0.62, -R * 0.62)
		draw_circle(s, 10.0, Color("7fd0ff"))
		draw_arc(s, 10.0, 0.0, TAU, 16, HudStyle.INK, 2.0, true)
	if h.is_bot and h != hud.local:
		var tag := Rect2(c.x - 18.0, c.y + R - 4.0, 36.0, 18.0)
		HudStyle.panel(self, tag, Color(1, 1, 1, 0.5), Color(0.08, 0.09, 0.12, 0.95), 6, 1)
		HudStyle.text_in(self, "BOT", tag, 18, HudStyle.DIM, 0)

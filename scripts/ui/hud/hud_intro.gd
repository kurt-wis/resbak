class_name HudIntro
extends HudPart

## Round-1 intro overlay (docs/status.md, 2026-10-17): letterbox bars, the map title, one
## banner per team (team name + its heroes) and the faceoff while MatchView flies the camera,
## plus the skip prompt for a lone human. Reads RoundFlow's INTRO phase; draws nothing outside it.

const BAR := 128.0

var active := false
var stage := -1 ## RoundFlow.IntroStage while active
var u := 0.0 ## progress through the stage
var title_text := "" ## what the banner shows (tests read it)
var sub_text := ""
var skip_text := "" ## "" when the intro can't be skipped here

func map_title() -> String:
	var id := String(hud.host.settings.get("map", "barangay_court"))
	return String(id).replace("_", " ").to_upper() if id != "construction_site" else "KONSTRUKSYON"

func refresh(_delta: float) -> void:
	var rf := hud.host.round_flow
	active = rf.phase == RoundFlow.Phase.INTRO
	visible = active
	if not active:
		stage = -1
		title_text = ""
		sub_text = ""
		skip_text = ""
		return
	var st := rf.intro_stage_at(rf.intro_elapsed())
	stage = int(st.stage)
	u = float(st.u)
	var own := hud.local.team if hud.local else RB.DILAW
	match stage:
		RoundFlow.IntroStage.ARENA:
			title_text = map_title()
			sub_text = "RONDA %d" % rf.round_number
		RoundFlow.IntroStage.TEAM_A, RoundFlow.IntroStage.TEAM_B:
			var team := own if stage == RoundFlow.IntroStage.TEAM_A else RB.other_team(own)
			title_text = RB.TEAM_FULL_NAMES[team].to_upper()
			var names: PackedStringArray = []
			for h in hud.host.team_heroes(team):
				names.append(h.display_name)
			sub_text = "  -  ".join(names)
		_:
			title_text = "%s  VS  %s" % [RB.TEAM_FULL_NAMES[own].to_upper(), RB.TEAM_FULL_NAMES[RB.other_team(own)].to_upper()]
			sub_text = "Handa na!"
	skip_text = "[%s]  Laktawan" % hud.key_label("interact") if rf.sole_human() != null else ""
	queue_redraw()

func _team_for_stage() -> int:
	var own := hud.local.team if hud.local else RB.DILAW
	return own if stage != RoundFlow.IntroStage.TEAM_B else RB.other_team(own)

func _draw() -> void:
	if not active or hud == null:
		return
	var s := sz()
	draw_rect(Rect2(0, 0, s.x, BAR), Color(0, 0, 0, 0.92))
	draw_rect(Rect2(0, s.y - BAR, s.x, BAR), Color(0, 0, 0, 0.92))
	var slide := 1.0 - pow(1.0 - clampf(u * 4.0, 0.0, 1.0), 3.0) # eases in over the first quarter
	var fade := clampf((1.0 - u) * 6.0, 0.0, 1.0) * clampf(u * 8.0, 0.0, 1.0)
	var col := Color.WHITE
	if stage == RoundFlow.IntroStage.TEAM_A or stage == RoundFlow.IntroStage.TEAM_B:
		col = hud.team_color(_team_for_stage())
	elif stage == RoundFlow.IntroStage.ARENA:
		col = HudStyle.GOLD
	var x_off := (1.0 - slide) * -240.0
	var c := Color(col.r, col.g, col.b, fade)
	var base_y := s.y - BAR + 72.0
	HudStyle.text(self, title_text, Vector2(x_off, base_y), 84, c, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	HudStyle.text(self, sub_text, Vector2(x_off, base_y + 40.0), 30, Color(HudStyle.DIM.r, HudStyle.DIM.g, HudStyle.DIM.b, fade), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if skip_text != "":
		HudStyle.text(self, skip_text, Vector2(0, 74.0), 24, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, s.x - 48.0)

extends RefCounted

## Match HUD: builds on a test match, timer/score follow the host, tag feed shows a tag,
## scoreboard toggles, F10 hide, pause overlay.

func run(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "tutoy", "team": RB.DILAW}, {"hero_id": "nene", "team": RB.LILA}])
	var local: Hero = host.heroes[0]
	var view := MatchView.new()
	host.get_parent().add_child(view)
	view.setup(host, local, null)
	var hud := Hud.new()
	host.get_parent().add_child(hud)
	hud.setup(host, local, view)
	await t.frames(2)
	t.check(hud.timer != null and hud.feed != null and hud.scoreboard != null and hud.minimap != null and hud.tracker != null, "HUD parts exist")
	t.go_live(host)
	t.steps(host, 60)
	await t.frames(2)
	t.check(hud.timer_label.text.begins_with("1:5"), "timer counts down from 2:00 (got '%s')" % hud.timer_label.text)
	# a tag shows in the feed
	var foe: Hero = host.heroes[1]
	TestCtx.put(local, 0, 0)
	TestCtx.put(foe, 1.2, 0)
	t.inputs(host).aim_at(local, Vector3(5, 0, 0))
	t.steps(host, 1)
	t.inputs(host).press(local, RB.BTN_TAG)
	t.steps(host, RB.ticks(host.tuning.tag_windup) + 2) # v0.2: the slower hampas windup
	await t.frames(2)
	t.check(foe.state == Hero.State.TAGGED, "the tag landed")
	var feed_text := "\n".join(hud.feed.texts())
	t.check("HINULI" in feed_text, "tag feed shows '[Tagger] HINULI si [Target]' (got '%s')" % feed_text)
	hud.force_scoreboard = true
	await t.frames(2)
	t.check(hud.scoreboard.held and hud.scoreboard.visible, "scoreboard shows while held")
	hud.force_scoreboard = false
	await t.frames(2)
	t.check(not hud.scoreboard.held, "scoreboard hides on release")
	hud.toggle_hidden()
	t.check(hud.is_hidden(), "F10 hides the HUD")
	hud.toggle_hidden()
	hud.set_pause_open(true)
	t.check(hud.is_pause_open(), "pause overlay opens")
	hud.set_pause_open(false)
	t.ok("HUD: timer, tag feed, scoreboard, hide, pause")
	_announcer(t, host, hud)
	await t.free_match(host)
	await _intro(t)
	await _aim_arrow(t)

## Round-1 intro (2026-10-17): the overlay names the map, each team and the faceoff, offers the
## skip to a lone human, and MatchView drives the camera's flyover pose and releases it after.
func _intro(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "tutoy", "team": RB.DILAW}, {"hero_id": "nene", "team": RB.LILA, "is_bot": true}], {"skip_intro": false})
	var local: Hero = host.heroes[0]
	var cam := MatchCamera.new()
	host.get_parent().add_child(cam)
	var view := MatchView.new()
	host.get_parent().add_child(view)
	view.setup(host, local, cam)
	var hud := Hud.new()
	host.get_parent().add_child(hud)
	hud.setup(host, local, view)
	t.steps(host, 30) # the flyover blends in over the first 0.4 s
	await t.frames(2)
	var ui := hud.intro_ui
	t.check(ui != null and ui.active and ui.stage == RoundFlow.IntroStage.ARENA and ui.title_text == "BARANGAY COURT", "intro overlay opens on the map title (got '%s')" % ui.title_text)
	t.check(ui.skip_text.contains("Laktawan"), "a lone human sees the skip prompt (got '%s')" % ui.skip_text)
	t.check(cam.intro_w > 0.0, "the camera is blended toward the flyover pose (w %.2f)" % cam.intro_w)
	t.steps(host, RB.ticks(host.tuning.intro_arena + 0.2) - 30)
	await t.frames(2)
	t.check(ui.stage == RoundFlow.IntroStage.TEAM_A and ui.title_text == RB.TEAM_FULL_NAMES[RB.DILAW].to_upper() and ui.sub_text.contains(local.display_name), "then our team's banner (got '%s' / '%s')" % [ui.title_text, ui.sub_text])
	t.steps(host, RB.ticks(host.tuning.intro_team))
	await t.frames(2)
	t.check(ui.stage == RoundFlow.IntroStage.TEAM_B and ui.title_text == RB.TEAM_FULL_NAMES[RB.LILA].to_upper(), "then the enemy team's banner (got '%s')" % ui.title_text)
	t.steps(host, host.round_flow.phase_ticks + 1)
	await t.frames(2)
	t.check(not ui.active and cam.intro_w == 0.0 and host.round_flow.phase == RoundFlow.Phase.COUNTDOWN, "the overlay and the flyover end with the intro")
	t.ok("HUD: round-1 intro overlay and camera flyover")
	await t.free_match(host)

## Tag aim arrow (2026-10-17): replaces the fan; points along the aim, its tip is the reach of a
## swing released now, and it fills in as the hampas charge builds.
func _aim_arrow(t: TestCtx) -> void:
	var host := t.make_match([{"hero_id": "tutoy", "team": RB.DILAW}, {"hero_id": "nene", "team": RB.LILA}])
	var local: Hero = host.heroes[0]
	var view := MatchView.new()
	host.get_parent().add_child(view)
	view.setup(host, local, null)
	await t.frames(2)
	t.check(view.aim_arrow_alpha == 0.0 and not view.aim_marker.visible, "no arrow while the round is not live (alpha %.2f)" % view.aim_arrow_alpha)
	t.go_live(host)
	TestCtx.put(local, 0, 0)
	TestCtx.put(host.heroes[1], 12, 8)
	t.inputs(host).aim_at(local, Vector3(5, 0, 0))
	t.steps(host, 2)
	await t.frames(2)
	var arrow := view.aim_marker.get_node_or_null("AimArrow") as MeshInstance3D
	t.check(arrow != null, "the aim marker is an arrow")
	var fans := 0
	for c in view.aim_marker.get_children():
		if c.name != "AimArrow":
			fans += 1
	t.check(fans == 0, "the old fan is gone")
	# two layers so the arrow reads on every floor: a bright core over a dark, wider outline
	var outline := arrow.get_node_or_null("AimArrowOutline") as MeshInstance3D
	t.check(outline != null, "the arrow has a dark outline layer")
	if outline != null:
		var fill_box := arrow.mesh.get_aabb()
		var ink_box := outline.mesh.get_aabb()
		t.check(ink_box.size.x > fill_box.size.x, "the outline is wider than the fill (%.2f > %.2f)" % [ink_box.size.x, fill_box.size.x])
		t.check(outline.position.y < arrow.position.y, "the outline sits under the fill")
		var fill_mat := arrow.material_override as StandardMaterial3D
		var ink_mat := outline.material_override as StandardMaterial3D
		t.check(fill_mat != null and ink_mat != null and fill_mat.render_priority > ink_mat.render_priority, "the fill draws over the outline")
		t.check(fill_mat != null and ink_mat != null and fill_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and ink_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "both arrow layers fade with the charge")
	var tip := func() -> float: return arrow.mesh.get_aabb().end.z
	var reach := local.charged_reach() + host.tuning.body_radius * 2.0
	t.check(t.near(tip.call(), reach, 0.02), "the arrow tip is the tap reach (%.2f of %.2f)" % [tip.call(), reach])
	t.check(view.aim_marker.visible and t.near(view.aim_marker.rotation.y, atan2(local.aim.x, local.aim.z), 0.01), "the arrow points along the aim")
	var idle_alpha := view.aim_arrow_alpha
	# the fill reads as the team's colour, not a pale cream (playtest note, 2026-10-17)
	var fill_col := (arrow.material_override as StandardMaterial3D).albedo_color
	var team_col: Color = RB.TEAM_COLORS[local.team]
	var to_team := Vector3(fill_col.r - team_col.r, fill_col.g - team_col.g, fill_col.b - team_col.b).length()
	var to_white := Vector3(fill_col.r - 1.0, fill_col.g - 1.0, fill_col.b - 1.0).length()
	t.check(to_team < to_white * 0.5, "the arrow fill is the team colour (%.2f from it, %.2f from white)" % [to_team, to_white])
	t.inputs(host).hold(local, RB.BTN_TAG)
	t.steps(host, RB.ticks(host.tuning.tag_charge_time))
	await t.frames(2)
	var full_reach := local.charged_reach() + host.tuning.body_radius * 2.0
	t.check(full_reach > reach and t.near(tip.call(), full_reach, 0.02), "a full charge lengthens the arrow (%.2f -> %.2f)" % [reach, tip.call()])
	t.check(view.aim_arrow_alpha > idle_alpha + 0.3, "the arrow fills in with the charge (alpha %.2f -> %.2f)" % [idle_alpha, view.aim_arrow_alpha])
	t.check(view.aim_arrow_alpha >= 0.8, "the arrow is bright at full charge (alpha %.2f)" % view.aim_arrow_alpha)
	# TagCharge hook (clip optional): while charging, the visual asks for it only if the rig has it
	var want: Array = local.visual._desired()
	t.check(local.visual.has_clip("TagCharge") == (want[0] == "TagCharge"), "a charging hero plays TagCharge when the clip exists, else falls back (wants '%s')" % want[0])
	t.inputs(host).release(local, RB.BTN_TAG)
	t.steps(host, RB.ticks(host.tuning.tag_windup) + 4)
	await t.frames(2)
	t.check(t.near(tip.call(), reach, 0.02), "the arrow shrinks back after the swing")
	local.on_tagged(host.heroes[1])
	await t.frames(2)
	t.check(not view.aim_marker.visible and view.aim_arrow_alpha == 0.0, "no arrow while jailed (alpha %.2f)" % view.aim_arrow_alpha)
	t.ok("aim arrow: replaces the fan, reach and charge feedback")
	await t.free_match(host)

## v0.2 MOBA-style announcer: the real tag above was the round's first; then synthetic host
## events drive streaks, multi-tags, the shutdown, rescue, capture and lockdown calls.
func _announcer(t: TestCtx, host: MatchHost, hud: Hud) -> void:
	var ann := hud.announcer
	t.check(ann != null and ann.history.size() >= 1 and ann.history[0] == "first_tag", "the round's first tag calls UNANG HULI! (%s)" % str(ann.history))
	var a: Hero = host.heroes[0]
	var b: Hero = host.heroes[1]
	ann.on_event("countdown", {"round": 2, "seconds": 3.0})
	ann.history.clear()
	ann.queue.clear()
	ann.current = {}
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history == PackedStringArray(["first_tag"]), "streaks reset each round; the new round's first tag calls UNANG HULI! again")
	t.check(not ann.current.is_empty() and ann.current.title == "UNANG HULI!", "the banner shows the call")
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history[-1] == "double", "a second tag inside the window calls DOBLENG HULI!")
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history.has("triple") and ann.history[-1] == "hot", "a third calls TRIPLENG HULI! then MAINIT! (%s)" % str(ann.history))
	t.check(ann.queue.size() <= host.tuning.announce_queue_max, "the queue is capped at %d" % host.tuning.announce_queue_max)
	host.tick += RB.ticks(host.tuning.announce_multi_window) + 1
	var before := ann.history.size()
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history.size() == before, "a 4th tag after the window chains no multi and is no streak step")
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history[-1] == "beast", "5 in a row calls HALIMAW!")
	ann.on_event("tag", {"tagger": a, "target": b})
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history[-1] == "unstoppable", "7 in a row calls DI MAPIGILAN!")
	ann.on_event("tag", {"tagger": b, "target": a})
	t.check(ann.history.has("shutdown"), "catching a player on a streak calls PINAHINTO!")
	ann.on_event("tag", {"tagger": a, "target": b})
	t.check(ann.history[-1] != "hot" and ann.history[-1] != "beast", "being caught resets the streak")
	ann.on_event("rescue", {"rescuer": b, "freed": [a], "by_skill": false})
	t.check(ann.history[-1] == "rescue", "a rescue calls RESBAK!")
	ann.on_event("capture", {"hero": a, "team": a.team})
	t.check(ann.history[-1] == "capture", "a capture calls NAAGAW ANG BASE!")
	ann.on_event("round_end", {"reason": "lockdown", "winner": a.team})
	t.check(ann.history[-1] == "ace", "a lockdown win calls LAHAT HULI!")
	before = ann.history.size()
	ann.on_event("round_end", {"reason": "capture", "winner": a.team})
	t.check(ann.history.size() == before, "other round ends make no LAHAT HULI!")
	# the banner plays each call for announce_banner_time, one at a time
	var shown: String = ann.current.id
	ann.refresh(host.tuning.announce_banner_time + 0.01)
	t.check(ann.current.is_empty() or ann.current.id != shown or ann.queue.is_empty(), "the banner moves on after %.1f s" % host.tuning.announce_banner_time)
	for i in range(10):
		ann.refresh(host.tuning.announce_banner_time + 0.01)
	t.check(ann.current.is_empty() and ann.queue.is_empty(), "the queue drains")
	t.ok("announcer: UNANG HULI!, DOBLENG/TRIPLENG, MAINIT!/HALIMAW!/DI MAPIGILAN!, PINAHINTO!, RESBAK!, NAAGAW ANG BASE!, LAHAT HULI!")

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

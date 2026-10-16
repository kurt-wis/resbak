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
	t.steps(host, 12)
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
	await t.free_match(host)

extends RefCounted

## The core Agawan Base rules against docs/RESBAK.md section 2, in small 2v2 / 2v4 matches on the
## grey test arena (TestCtx.make_match): manual stepping, scripted input, exact tick counts.
## Arena facts: fixed bases -> Dilaw pole (-12, 0), Lila pole (12, 0); Jail_Dilaw holds Lila
## prisoners. The arena has no JailLine, so its jail line is the straight fallback along the
## back of the yard box (x -19.0, z 5.2..9.2); the post starts at its middle (-19.0, 7.2).

const D := RB.DILAW
const L := RB.LILA
const TAG := RB.BTN_TAG
const USE := RB.BTN_INTERACT

var log_events: Array = []

func run(t: TestCtx) -> void:
	await _countdown(t)
	await _intro(t)
	await _movement(t)
	await _can_tag_table(t)
	await _tag_hit_and_jail(t)
	await _tag_geometry(t)
	await _failed_tag(t)
	await _charged_tag(t)
	await _escape_protection(t)
	await _sabay(t)
	await _barrier(t)
	await _capture(t)
	await _capture_cancel(t)
	await _chain_and_rescue(t)
	await _post_slide(t)
	await _lone_prisoner_rescue(t)
	await _same_tick_rescue(t)
	await _lockdown(t)
	await _timer_and_sudden_death(t)
	await _round_reset(t)
	await _match_end(t)

# ---- helpers ---------------------------------------------------------------------------
func _lineup(d_ids: Array, l_ids: Array) -> Array:
	var out: Array = []
	for id in d_ids:
		out.append({"hero_id": id, "team": D})
	for id in l_ids:
		out.append({"hero_id": id, "team": L})
	return out

## A live match with every hero parked on a row at z = -10 (out of everybody's way).
func _live(t: TestCtx, d_ids: Array, l_ids: Array, settings: Dictionary = {}) -> MatchHost:
	var host := t.make_match(_lineup(d_ids, l_ids), settings)
	log_events = []
	host.event.connect(func(kind: String, data: Dictionary): log_events.append(kind))
	t.go_live(host)
	_park(host)
	return host

func _park(host: MatchHost) -> void:
	for i in range(host.heroes.size()):
		TestCtx.put(host.heroes[i], -9.0 + 2.0 * i, -10.0)

func _count(kind: String) -> int:
	return log_events.count(kind)

func _face_east(t: TestCtx, host: MatchHost, h: Hero) -> void:
	t.inputs(host).aim_at(h, h.global_position + Vector3(5, 0, 0))

func _face_west(t: TestCtx, host: MatchHost, h: Hero) -> void:
	t.inputs(host).aim_at(h, h.global_position + Vector3(-5, 0, 0))

## Step until `cond` is true; returns the steps taken or -1.
func _until(host: MatchHost, cond: Callable, limit := 2000) -> int:
	for i in range(limit):
		if cond.call():
			return i
		host.step()
	return -1

## Tag tap, then step to the landing tick (press tick + tag_windup ticks).
func _tag(t: TestCtx, host: MatchHost, h: Hero) -> void:
	t.inputs(host).press(h, TAG)
	t.steps(host, RB.ticks(host.tuning.tag_windup) + 1)

## Tag `victim` for real (landing + freeze), then step until it is Jailed.
func _jail(t: TestCtx, host: MatchHost, tagger: Hero, victims: Array) -> void:
	for v in victims:
		(v as Hero).on_tagged(tagger)
	t.steps(host, 49)

# ---- tests -----------------------------------------------------------------------------
func _countdown(t: TestCtx) -> void:
	var host := t.make_match(_lineup(["nene", "inday"], ["nathan", "nene"]))
	log_events = []
	host.event.connect(func(kind: String, data: Dictionary): log_events.append(kind))
	var a: Hero = host.heroes[0]
	t.check(host.round_flow.phase == RoundFlow.Phase.COUNTDOWN, "a match starts in COUNTDOWN")
	t.check(not host.round_live(), "round is not live during the countdown")
	TestCtx.put(a, -5, 0)
	var inp := t.inputs(host)
	inp.move(a, Vector2(1, 0))
	inp.press(a, TAG)
	t.steps(host, 100)
	t.check(t.near(a.global_position.x, -5.0, 0.05), "heroes are frozen during the countdown (moved to %.2f)" % a.global_position.x)
	t.check(not a.is_winding_up(), "no tag wind-up during the countdown")
	t.steps(host, 79)
	t.check(not host.round_live() and _count("kaboom") == 0, "still counting down after 179 ticks")
	t.steps(host, 1)
	t.check(host.round_live(), "KABOOM: live after 3 s = 180 ticks")
	t.check(_count("kaboom") == 1, "kaboom event fires once")
	t.check(host.round_flow.round_number == 1, "round 1")
	# the 2 min timer starts at KABOOM
	t.check(host.round_flow.timer_ticks == 7200, "round clock starts at 120 s (7200 ticks), got %d" % host.round_flow.timer_ticks)
	t.steps(host, 60)
	t.check(host.round_flow.timer_ticks == 7140, "round clock counts down from KABOOM, got %d" % host.round_flow.timer_ticks)
	t.check(a.global_position.x > -5.0, "hero moves once live")
	t.ok("countdown 3 s -> KABOOM, frozen until then")
	await t.free_match(host)

## Round 1 INTRO (2026-10-17): 8 s frozen flyover, then the 3 s countdown; Interact skips it
## only when exactly one human is in the match; the settings leave it out.
func _intro(t: TestCtx) -> void:
	var host := t.make_match(_lineup(["nene", "inday"], ["nathan", "nene"]), {"skip_intro": false})
	log_events = []
	host.event.connect(func(kind: String, data: Dictionary): log_events.append(kind))
	var rf := host.round_flow
	var a: Hero = host.heroes[0]
	t.check(rf.phase == RoundFlow.Phase.INTRO and not host.round_live(), "round 1 starts in INTRO (not live)")
	t.check(rf.intro_total_ticks() == 480, "the intro is 2 + 2 x 2.5 + 1 = 8 s = 480 ticks (got %d)" % rf.intro_total_ticks())
	t.check(rf.intro_stage_at(0.5).stage == RoundFlow.IntroStage.ARENA and rf.intro_stage_at(3.0).stage == RoundFlow.IntroStage.TEAM_A 		and rf.intro_stage_at(5.5).stage == RoundFlow.IntroStage.TEAM_B and rf.intro_stage_at(7.5).stage == RoundFlow.IntroStage.FACEOFF, "stages run arena, team, team, faceoff")
	TestCtx.put(a, -5, 0)
	var inp := t.inputs(host)
	inp.move(a, Vector2(1, 0))
	inp.press(a, TAG)
	inp.press(a, USE) # two humans: Interact must not skip
	t.steps(host, 200)
	t.check(rf.phase == RoundFlow.Phase.INTRO and t.near(a.global_position.x, -5.0, 0.05) and not a.is_winding_up(), "heroes stay frozen and can't tag in the intro")
	t.check(host.round_flow.timer_ticks == 7200, "the round clock does not run in the intro")
	t.steps(host, 279)
	t.check(rf.phase == RoundFlow.Phase.INTRO and not log_events.has("intro_end"), "still INTRO after 479 ticks")
	t.steps(host, 1)
	t.check(rf.phase == RoundFlow.Phase.COUNTDOWN and log_events.count("intro_end") == 1 and log_events.count("countdown") == 1, "INTRO -> COUNTDOWN with intro_end and countdown events")
	t.check(rf.phase_ticks == 180, "the 3 s countdown follows (%d ticks)" % rf.phase_ticks)
	t.steps(host, 180)
	t.check(host.round_live() and log_events.count("kaboom") == 1, "then KABOOM")
	await t.free_match(host)
	# one human among bots: Interact skips
	var lineup := _lineup(["nene", "inday"], ["nathan", "nene"])
	for i in range(1, lineup.size()):
		lineup[i]["is_bot"] = true
	host = t.make_match(lineup, {"skip_intro": false})
	log_events = []
	host.event.connect(func(kind: String, data: Dictionary): log_events.append(kind))
	a = host.heroes[0]
	t.steps(host, 30)
	t.check(host.round_flow.phase == RoundFlow.Phase.INTRO, "no skip without a press")
	t.inputs(host).press(a, USE)
	t.steps(host, 2)
	t.check(host.round_flow.phase == RoundFlow.Phase.COUNTDOWN and log_events.has("intro_end"), "the lone human skips the intro with Interact")
	await t.free_match(host)
	# practice (tutorial) never plays it; later rounds never play it
	host = t.make_match(lineup, {"skip_intro": false, "practice": true})
	t.check(host.round_flow.phase == RoundFlow.Phase.COUNTDOWN, "practice (tutorial) skips the intro")
	await t.free_match(host)
	host = t.make_match(_lineup(["nene", "inday"], ["nathan", "nene"]), {"skip_intro": false})
	t.steps(host, 480 + 180)
	host.round_flow.score[0] = 0
	host.round_flow._end_round(D, "capture")
	t.steps(host, host.round_flow.phase_ticks + 1)
	t.check(host.round_flow.round_number == 2 and host.round_flow.phase == RoundFlow.Phase.COUNTDOWN, "round 2 goes straight to the countdown")
	await t.free_match(host)
	t.ok("round-1 intro: 8 s frozen, skip rules, practice and later rounds without it")

func _movement(t: TestCtx) -> void:
	for sheet in [["nene", 4.5], ["jm", 4.15], ["nathan", 4.5], ["inday", 4.5], ["tutoy", 4.85]]:
		var host := _live(t, [sheet[0], "inday"], ["nathan", "nene"])
		var pair := [sheet[0], sheet[1] * host.tuning.move_speed_scale] # v0.2: everyone x move_speed_scale
		var a: Hero = host.heroes[0]
		TestCtx.put(a, -6, 2)
		var inp := t.inputs(host)
		inp.move(a, Vector2(1, 0))
		t.steps(host, 20)
		if pair[0] == "tutoy": # DIRE-DIRETSO climbs up to +15 % over 3 s
			t.check(a.ground_speed() >= pair[1] - 0.05 and a.ground_speed() <= pair[1] * 1.15 + 0.05, "tutoy reaches run speed %.2f (+ Dire-Diretso), got %.2f" % [pair[1], a.ground_speed()])
		else:
			t.check(t.near(a.ground_speed(), pair[1], 0.05), "%s reaches run speed %.1f (got %.2f)" % [pair[0], pair[1], a.ground_speed()])
		t.check(absf(a.global_position.z - 2.0) < 0.1, "%s runs straight" % pair[0])
		inp.move(a, Vector2.ZERO)
		t.steps(host, 15)
		t.check(a.ground_speed() < 0.05, "%s stops when the input stops" % pair[0])
		# gamepad half-tilt walks at half speed
		inp.gamepad = true
		inp.move(a, Vector2(0.3, 0))
		t.steps(host, 20)
		t.check(a.ground_speed() >= pair[1] * 0.5 - 0.05 and a.ground_speed() <= pair[1] * 0.5 * 1.15 + 0.05, "%s walks at half speed on a light stick tilt (got %.2f)" % [pair[0], a.ground_speed()])
		inp.move(a, Vector2(0.1, 0)) # inside the dead zone
		t.steps(host, 15)
		t.check(a.ground_speed() < 0.05, "%s ignores the 15 %% dead zone" % pair[0])
		await t.free_match(host)
	t.ok("movement reaches run speed, stops, gamepad walk")

func _can_tag_table(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var b: Hero = host.heroes[1]
	var c: Hero = host.heroes[2]
	TestCtx.put(a, 0, 0)
	TestCtx.put(c, 1.5, 0)
	t.check(host.can_tag(a, c), "free enemy is taggable")
	t.check(not host.can_tag(a, b), "an ally is not taggable")
	t.check(not host.can_tag(a, a), "self is not taggable")
	c.ep_ticks = 100
	t.check(not host.can_tag(a, c), "an enemy under EP is not taggable")
	c.ep_ticks = 0
	c.global_position.y = 1.5
	t.check(not host.can_tag(a, c), "height gap > 1 m: no tag")
	c.global_position.y = 0.05
	c.set_state(Hero.State.JAILED)
	t.check(not host.can_tag(a, c), "a Jailed enemy is not taggable")
	c.set_state(Hero.State.FREE)
	a.set_state(Hero.State.TAGGED)
	t.check(not host.can_tag(a, c), "a Tagged tagger cannot tag")
	a.set_state(Hero.State.FREE)
	t.ok("can_tag rule table")
	await t.free_match(host)

func _tag_hit_and_jail(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	TestCtx.put(a, 0, 0)
	TestCtx.put(c, 1.9, 0) # centres 1.9 apart = 1.1 m edge to edge, inside the 1.2 m reach
	_face_east(t, host, a)
	var windup := RB.ticks(host.tuning.tag_windup)
	t.inputs(host).press(a, TAG)
	t.steps(host, windup)
	t.check(c.state == Hero.State.FREE, "the tag has not landed during the %d-tick wind-up" % windup)
	t.check(a.is_winding_up(), "tagger is winding up")
	t.steps(host, 1)
	t.check(c.state == Hero.State.TAGGED, "a tapped tag lands tag_windup (%d ticks) after the press" % windup)
	t.check(not a.is_winding_up(), "wind-up over")
	t.check(_count("tag") == 1, "tag event")
	t.check(host.stats[a.slot].tags == 1, "tagger's tags stat")
	var frozen_at := c.global_position
	t.inputs(host).move(c, Vector2(0, 1))
	t.steps(host, 47)
	t.check(c.state == Hero.State.TAGGED, "still frozen 47 ticks after the landing")
	t.check(RB.flat_dist(c.global_position, frozen_at) < 0.05, "a Tagged hero cannot move")
	t.check(not host.can_tag(a, c), "a Tagged hero is untaggable")
	t.steps(host, 1)
	t.check(c.state == Hero.State.CHAINED, "after 0.8 s = 48 ticks the prisoner holds the jail post (chained)")
	t.inputs(host).move(c, Vector2.ZERO)
	t.check(host.layout.in_jail(D, c.global_position), "the victim is inside the TAGGER's jail (Jail_Dilaw holds Lila), at %s" % c.global_position)
	t.check(_count("jailed") == 1, "jailed event")
	t.check(host.jail_system.jailed_count(L) == 1, "jailed count")
	# prisoners cannot tag or capture
	t.inputs(host).press(c, TAG)
	t.steps(host, 15)
	t.check(not c.is_winding_up(), "a prisoner cannot press Tag")
	# the post barrier keeps free heroes off the post
	var b: Hero = host.heroes[1]
	var post := host.jail_system.post(D)
	TestCtx.put(b, post.x + 2.5, post.z)
	t.inputs(host).move(b, Vector2(-1, 0))
	t.steps(host, 90)
	var keep := host.tuning.jail_post_barrier + host.tuning.body_radius
	t.check(RB.flat_dist(b.global_position, post) >= keep - 0.02, "free heroes are kept %.1f m from the jail post (%.2f)" % [keep, RB.flat_dist(b.global_position, post)])
	t.ok("tag hit -> 0.8 s freeze -> tagger's jail post, post barrier")
	await t.free_match(host)

func _tag_geometry(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene", "tutoy"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var d: Hero = host.heroes[3]
	# arc: 40 deg hits, 50 deg misses (45 deg either side)
	for case in [[40.0, true], [50.0, false], [-40.0, true], [-50.0, false]]:
		TestCtx.put(a, 0, 0)
		var ang := deg_to_rad(case[0])
		TestCtx.put(c, cos(ang) * 1.6, sin(ang) * 1.6)
		_face_east(t, host, a)
		_tag(t, host, a)
		t.check((c.state == Hero.State.TAGGED) == case[1], "tag at %d deg off the lunge %s" % [case[0], "hits" if case[1] else "misses"])
		c.reset_for_round(Vector3(0, 0.05, 6), Vector3.RIGHT)
		a.reset_for_round(Vector3(0, 0.05, 0), Vector3.RIGHT)
	# the nearest of two enemies in reach is the one tagged
	TestCtx.put(a, 0, 0)
	TestCtx.put(c, 1.9, 0)
	TestCtx.put(d, 1.3, 0.55)
	_face_east(t, host, a)
	_tag(t, host, a)
	t.check(d.state == Hero.State.TAGGED and c.state == Hero.State.FREE, "the nearest taggable enemy is tagged")
	await t.free_match(host)

	# reach: exactly inside / just outside (edge to edge), Tutoy has 1.0
	for case in [["nene", 1.95, true], ["nene", 2.1, false], ["tutoy", 1.75, true], ["tutoy", 1.9, false]]:
		var h2 := _live(t, [case[0], "inday"], ["nathan", "nene"])
		var a2: Hero = h2.heroes[0]
		var c2: Hero = h2.heroes[2]
		TestCtx.put(a2, 0, 0)
		TestCtx.put(c2, case[1], 0)
		_face_east(t, h2, a2)
		_tag(t, h2, a2)
		t.check((c2.state == Hero.State.TAGGED) == case[2], "%s tag at centre distance %.2f %s" % [case[0], case[1], "hits" if case[2] else "misses"])
		await t.free_match(h2)
	t.ok("tag arc 45 deg, reach edge to edge, nearest wins")

func _failed_tag(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	TestCtx.put(a, 0, 0)
	TestCtx.put(c, 4, 0) # well out of reach
	_face_east(t, host, a)
	_tag(t, host, a)
	t.check(c.state == Hero.State.FREE, "a tag out of reach tags nobody")
	t.check(a.stumble_ticks == 30, "failed tag: stumble 0.5 s = 30 ticks (got %d)" % a.stumble_ticks)
	t.check(_count("tag_failed") == 1, "tag_failed event")
	t.inputs(host).move(a, Vector2(1, 0))
	t.inputs(host).press(a, TAG)
	t.steps(host, 20)
	t.check(t.near(a.global_position.x, 0.0, 0.05), "a stumbling hero cannot move")
	t.check(not a.is_winding_up(), "a stumbling hero cannot tag")
	t.steps(host, 9)
	t.check(a.is_stumbling(), "stumble lasts the full 30 ticks")
	t.steps(host, 1)
	t.check(not a.is_stumbling(), "stumble over after 0.5 s")
	t.steps(host, 30)
	t.check(a.global_position.x > 0.5, "moves again after the stumble")
	# a stumble does not stack: the longer remaining time applies
	a.stumble(0.5)
	var left := a.stumble_ticks
	a.stumble(0.2)
	t.check(a.stumble_ticks == left, "stumble does not stack (longer remaining applies)")
	t.ok("failed tag -> 0.5 s stumble")
	await t.free_match(host)

## v0.2 charged hampas: hold Tag to charge (slower while charging), release to swing with
## up to tag_charge_reach_bonus more reach; the charge bar reads charge_fraction().
func _charged_tag(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var tu := host.tuning
	var inp := t.inputs(host)
	var full := RB.ticks(tu.tag_charge_time)
	var plain_edge := a.tag_reach()
	# out of tap reach, inside full-charge reach
	var gap := plain_edge * (1.0 + tu.tag_charge_reach_bonus * 0.5)
	TestCtx.put(a, 0, 0)
	TestCtx.put(c, gap + tu.body_radius * 2.0, 0)
	_face_east(t, host, a)
	inp.hold(a, TAG)
	t.steps(host, full / 2)
	t.check(a.is_charging() and not a.is_winding_up(), "holding Tag charges, no swing yet")
	t.check(a.charge_fraction() > 0.3 and a.charge_fraction() < 0.7, "half-way charge reads about 0.5 (got %.2f)" % a.charge_fraction())
	t.steps(host, full)
	t.check(t.near(a.charge_fraction(), 1.0, 0.001), "the charge caps at full")
	t.check(t.near(a.charged_reach(), plain_edge * (1.0 + tu.tag_charge_reach_bonus), 0.001), "a full charge adds tag_charge_reach_bonus x reach")
	# moving while charging is slower
	inp.move(a, Vector2(0, 1))
	t.steps(host, 20)
	var slow := a.ground_speed()
	inp.move(a, Vector2.ZERO)
	t.steps(host, 15)
	var run := a.data.run_speed * tu.move_speed_scale
	t.check(t.near(slow, run * (1.0 - tu.tag_charge_slow), 0.08), "charging slows you to %.2f m/s (got %.2f)" % [run * (1.0 - tu.tag_charge_slow), slow])
	TestCtx.put(a, 0, 0)
	_face_east(t, host, a)
	inp.release(a, TAG)
	t.steps(host, 1)
	t.check(a.is_winding_up() and not a.is_charging(), "release swings")
	t.steps(host, RB.ticks(tu.tag_windup))
	t.check(c.state == Hero.State.TAGGED, "a charged swing tags beyond the tap reach (gap %.2f m)" % gap)
	await t.free_match(host)
	# the same gap with a tap misses
	var h2 := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a2: Hero = h2.heroes[0]
	var c2: Hero = h2.heroes[2]
	TestCtx.put(a2, 0, 0)
	TestCtx.put(c2, gap + tu.body_radius * 2.0, 0)
	_face_east(t, h2, a2)
	_tag(t, h2, a2)
	t.check(c2.state == Hero.State.FREE, "a tap at the same gap misses")
	t.ok("charged hampas: hold to charge, slower, longer reach on release")
	await t.free_match(h2)

func _escape_protection(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	TestCtx.put(a, 0, 0)
	TestCtx.put(c, 1.6, 0)
	c.ep_ticks = 600
	c._update_collision()
	t.check(c.collision_layer == RB.L_GHOST and (c.collision_mask & RB.L_HERO) == 0, "EP: passes through players")
	_face_east(t, host, a)
	_tag(t, host, a)
	t.check(c.state == Hero.State.FREE and a.stumble_ticks > 0, "EP blocks the tag (failed tag for the tagger)")
	t.check(c.has_ep(), "EP still on")
	# EP ends on the owner's Tag press
	t.inputs(host).press(c, TAG)
	t.steps(host, 1)
	t.check(not c.has_ep(), "EP ends on the owner's Tag press")
	t.check(c.collision_layer == RB.L_HERO, "solid again after EP")
	# EP ends on capture start
	c.ep_ticks = 600
	c._update_collision()
	TestCtx.put(c, -10.6, 0) # in capture range of the Dilaw pole
	c.windup_end_tick = -1
	t.inputs(host).hold(c, USE)
	t.steps(host, 2)
	t.check(c.capturing and not c.has_ep(), "EP ends when a capture starts")
	t.ok("EP blocks tags and ends on Tag press / capture start")
	await t.free_match(host)

func _sabay(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var b: Hero = host.heroes[1]
	var c: Hero = host.heroes[2]
	var d: Hero = host.heroes[3]
	TestCtx.put(a, 0, 0)
	TestCtx.put(c, 1.6, 0)
	TestCtx.put(b, -6, -4)
	TestCtx.put(d, -4.2, -4)
	_face_east(t, host, a)
	_face_west(t, host, c)
	_face_east(t, host, b)
	var inp := t.inputs(host)
	inp.press(a, TAG)
	inp.press(c, TAG)
	inp.press(b, TAG)
	t.steps(host, RB.ticks(host.tuning.tag_windup) + 1)
	t.check(a.state == Hero.State.FREE and c.state == Hero.State.FREE, "Sabay: nobody is jailed")
	t.check(a.stumble_ticks > 0 and c.stumble_ticks > 0, "Sabay: both stumble")
	t.check(_count("sabay") == 1, "one sabay event")
	t.check(d.state == Hero.State.TAGGED, "other tags apply on a Sabay tick")
	t.ok("Sabay")
	await t.free_match(host)

func _barrier(t: TestCtx) -> void:
	# 2026-10-17: the own-ring barrier is gone on every map (spec deviation, docs/decisions.md).
	# Defenders walk into their own ring, up to the solid pole, and tag a capturer from inside it.
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var pole := host.base_system.pole_pos(D)
	t.check(t.near(pole.x, -12.0) and t.near(pole.z, 0.0), "Dilaw pole at site 1")
	TestCtx.put(a, -6, 0)
	t.inputs(host).move(a, Vector2(-1, 0))
	t.steps(host, 200)
	var da := RB.flat_dist(a.global_position, pole)
	t.check(da < host.tuning.base_ring_radius and da > host.tuning.pole_radius + host.tuning.body_radius - 0.1, "a defender walks into its own ring and stops at the solid pole (%.2f m)" % da)
	t.check(host.base_system.in_own_ring(a), "in_own_ring is true inside the ring")
	t.check(_count("barrier_bump") == 0, "no barrier bump events")
	t.inputs(host).move(a, Vector2.ZERO)
	# a defender inside the ring tags a capturer
	TestCtx.put(a, -11.4, 1.2)
	TestCtx.put(c, -10.6, 0)
	t.check(host.base_system.in_own_ring(a), "defender stands inside its ring")
	t.inputs(host).hold(c, USE)
	t.steps(host, 30)
	t.check(c.capturing, "the enemy is capturing")
	t.inputs(host).aim_at(a, c.global_position)
	_tag(t, host, a)
	t.check(c.state == Hero.State.TAGGED and not c.capturing, "a defender inside its own ring tags the capturer")
	t.check(host.stats[a.slot].saves == 1, "and it counts as a save")
	t.ok("no own-ring barrier: defenders fight inside the ring")
	await t.free_match(host)

func _capture(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var c: Hero = host.heroes[2]
	TestCtx.put(c, -10.6, 0) # gap 1.4 - 0.4 - 0.2 = 0.8 m <= 1
	var inp := t.inputs(host)
	t.check(host.base_system.in_capture_range(c), "in capture range at 0.8 m gap")
	inp.hold(c, USE)
	inp.move(c, Vector2(0, 1))
	var hold := RB.ticks(host.tuning.capture_hold)
	t.steps(host, hold - 1)
	t.check(c.capturing and c.capture_ticks == hold - 1, "capturing, progress %d ticks (got %d)" % [hold - 1, c.capture_ticks])
	t.check(host.round_flow.phase == RoundFlow.Phase.PLAYING and host.round_flow.score == [0, 0], "not captured one tick early")
	t.check(t.near(c.global_position.z, 0.0, 0.1), "a capturing hero cannot move")
	t.check(t.near(host.base_system.capture_progress(L), float(hold - 1) / hold, 0.001), "capture progress for the HUD")
	t.steps(host, 1)
	t.check(host.round_flow.phase == RoundFlow.Phase.ROUND_OVER, "capture completes at capture_hold (%d ticks): round over" % hold)
	t.check(host.round_flow.score == [0, 1], "capturers get +1 (Lila)")
	t.check(host.round_flow.last_result.winner == L and host.round_flow.last_result.reason == "capture", "round result: Lila by capture")
	t.check(_count("capture") == 1 and _count("round_end") == 1, "capture and round_end events")
	t.check(not c.capturing, "capture cleared at round end")
	t.ok("holding the capture for capture_hold wins the round")
	await t.free_match(host)

func _capture_cancel(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var inp := t.inputs(host)
	# release cancels and resets progress
	TestCtx.put(c, -10.6, 0)
	inp.hold(c, USE)
	t.steps(host, 40)
	t.check(c.capturing, "capturing")
	inp.release(c, USE)
	t.steps(host, 1)
	t.check(not c.capturing and c.capture_ticks == 0, "releasing Interact cancels and resets progress")
	t.check(_count("capture_cancel") == 1, "capture_cancel event")
	inp.hold(c, USE)
	t.steps(host, 89)
	t.check(host.round_flow.phase == RoundFlow.Phase.PLAYING and c.capture_ticks == 89, "progress restarted from 0 after a cancel")
	# a push out of range cancels
	t.steps(host, 0)
	inp.release(c, USE)
	t.steps(host, 2)
	inp.hold(c, USE)
	t.steps(host, 10)
	t.check(c.capturing, "capturing again")
	c.apply_push(Vector3.RIGHT, 2.0)
	t.steps(host, 15)
	t.check(not c.capturing, "a push to gap > 1 m cancels the capture")
	inp.release(c, USE)
	t.steps(host, 2)
	# being tagged cancels (and counts as a save)
	TestCtx.put(c, -10.6, 0)
	TestCtx.put(a, -8.8, 0)
	inp.hold(c, USE)
	t.steps(host, 30)
	t.check(c.capturing, "capturing before the tag")
	_face_west(t, host, a)
	_tag(t, host, a)
	t.check(c.state == Hero.State.TAGGED and not c.capturing, "a tag cancels the capture")
	t.check(host.stats[a.slot].saves == 1, "tagging a capturer counts as a save")
	t.ok("capture cancels on release, push and tag; progress resets")
	await t.free_match(host)

func _chain_and_rescue(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene", "tutoy", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var d: Hero = host.heroes[3]
	var e: Hero = host.heroes[4]
	var f: Hero = host.heroes[5]
	var inp := t.inputs(host)
	var js := host.jail_system
	var tu := host.tuning
	var post := js.post(D)
	var mid := host.layout.line_point(D, host.layout.line_length(D) * 0.5)
	t.check(RB.flat_dist(post, mid) < 0.01, "the post starts at the middle of Dilaw's jail line (%s)" % post)
	_jail(t, host, a, [c, d, e])
	t.check(c.state == Hero.State.CHAINED and d.state == Hero.State.CHAINED and e.state == Hero.State.CHAINED, "every prisoner joins the chain by itself")
	t.check(js.chain(D) == [c, d, e], "chain order = order caught: first holds the post, the last caught is the tip")
	t.check(RB.flat_dist(c.global_position, post) <= tu.post_hold_offset + 0.36, "the first prisoner holds the post (%.2f m)" % RB.flat_dist(c.global_position, post))
	t.check(js.can_steer(e) and js.can_steer(c) and not js.can_steer(d), "the tip and the post holder steer; middle links do not")
	t.check(not host.can_tag(a, d), "a Chained hero is untaggable")
	inp.press(e, USE)
	t.steps(host, 2)
	t.check(e.state == Hero.State.CHAINED and js.chain(D).size() == 3, "Interact does nothing in jail: nobody can let go")
	# links in the middle do not move by themselves
	var d_at := d.global_position
	inp.move(d, Vector2(1, 0))
	t.steps(host, 30)
	inp.move(d, Vector2.ZERO)
	t.check(RB.flat_dist(d.global_position, d_at) < 0.05, "a middle link ignores its own input")
	# the tip drags the chain out, slowly, link by link
	var e0 := e.global_position
	var d0 := d.global_position
	inp.move(e, Vector2(1, 0))
	t.steps(host, 6)
	t.check(RB.flat_dist(e.global_position, e0) > RB.flat_dist(d.global_position, d0), "the tip moves first, the next link follows after")
	t.steps(host, 150)
	inp.move(e, Vector2.ZERO)
	t.steps(host, 30)
	var reach := RB.flat_dist(e.global_position, post)
	t.check(reach > 3.0, "the tip stretched the chain out (%.2f m from the post)" % reach)
	t.check(reach <= tu.post_hold_offset + 0.35 + tu.chain_link * 2.0 + 0.05, "the tip reaches at most one link per prisoner (%.2f)" % reach)
	t.check(RB.flat_dist(c.global_position, post) <= tu.post_hold_offset + 0.36, "the post holder never lets go of the post")
	t.check(RB.flat_dist(c.global_position, d.global_position) <= tu.chain_link + 0.02 and RB.flat_dist(d.global_position, e.global_position) <= tu.chain_link + 0.02, "neighbours stay within one link")
	# the chain looks like real hand-holding (visual only: hero_visual.gd)
	var gc: Array = c.visual.chain_grips()
	var gd: Array = d.visual.chain_grips()
	var ge: Array = e.visual.chain_grips()
	t.check(gc.size() == 2 and gd.size() == 2 and ge.size() == 2, "every prisoner has a rear and a front grip")
	t.check(c.visual.arm_ik != null and d.visual.arm_ik != null and e.visual.arm_ik != null, "the chain arm IK is built on every prisoner (the rig's bone names resolve)")
	for p in [c, d, e]:
		(p.visual as HeroVisual).settle_chain_draw()
	await t.frames(4) # let the animations and the IK modifiers settle
	var visc := c.visual as HeroVisual
	var visd := d.visual as HeroVisual
	var vise := e.visual as HeroVisual
	# the IK really moves the hands: this is what silently did nothing while the bone names were wrong
	t.check(visc.hand_target_error(0) < 0.12 and visc.hand_target_error(1) < 0.12, "the post holder's hands sit on their grips (%.3f / %.3f m off)" % [visc.hand_target_error(0), visc.hand_target_error(1)])
	t.check(visd.hand_target_error(0) < 0.12 and visd.hand_target_error(1) < 0.12, "the middle link's hands sit on their grips (%.3f / %.3f m off)" % [visd.hand_target_error(0), visd.hand_target_error(1)])
	if gc.size() == 2 and gd.size() == 2 and ge.size() == 2:
		t.check(gc[0].y > c.global_position.y + 0.7 and gc[0].y < c.global_position.y + 1.05, "hands are held at hip height, below the chest (%.2f m)" % (gc[0].y - c.global_position.y))
	for p in [c, d, e]:
		var vis = p.visual
		var face: Vector3 = vis.chain_facing()
		var k: int = js.chain(D).find(p)
		var axis := RB.flat(p.global_position - js.link_before(D, k)).normalized()
		t.check(absf(face.dot(axis)) < 0.05 and face.length() > 0.99, "chained prisoner %d faces across the chain, not along it" % k)
		var grips: Array = vis.chain_grips()
		var map: Array = vis.arm_grip_indices()
		var right := face.cross(Vector3.UP).normalized()
		var rear_side := RB.flat(grips[0] - vis.global_position).dot(right)
		var front_side := RB.flat(grips[1] - vis.global_position).dot(right)
		t.check(map[0] != map[1], "the two arms take different grips")
		if k < 2: # the tip's front grip can point anywhere (toward a rescuer)
			var right_side: float = rear_side if map[0] == 0 else front_side
			t.check(right_side >= 0.0, "the right arm takes the grip on the right side of the body")
	# both gripping hands stay below the shoulder and inside the arm's reach: no more airplane arms
	for p in [c, d, e]:
		var hvis := p.visual as HeroVisual
		var shoulder := maxf(hvis.bone_world("RightArm").y, hvis.bone_world("LeftArm").y)
		t.check(hvis.grip_hand(0).y < shoulder - 0.05 and hvis.grip_hand(1).y < shoulder - 0.05, "link %d holds both hands below its shoulders (%.2f / %.2f < %.2f)" % [js.chain(D).find(p), hvis.grip_hand(0).y, hvis.grip_hand(1).y, shoulder])
		t.check(hvis.arm_ik.influence > 0.9, "the chain IK is at full strength while chained (%.2f)" % hvis.arm_ik.influence)
	# at the real chain_link spacing the chain is DRAWN pulled in so the hands still meet
	# (presentation only: the host positions above stay one link apart)
	var gap_real_cd := visc.grip_hand(1).distance_to(visd.grip_hand(0))
	var gap_real_de := visd.grip_hand(1).distance_to(vise.grip_hand(0))
	t.check(gap_real_cd < 0.15, "a stretched chain still links the post holder's hand to the next link's (%.3f m apart)" % gap_real_cd)
	t.check(gap_real_de < 0.15, "a stretched chain still links the middle link's hand to the tip's (%.3f m apart)" % gap_real_de)
	t.check(RB.flat_dist(vise.global_position, e.global_position) > 0.2, "the stretched tip is drawn pulled toward the post (%.2f m)" % RB.flat_dist(vise.global_position, e.global_position))
	t.check(RB.flat_dist(e.global_position, post) > 3.0, "drawing the chain shorter leaves the tip's real position alone")
	# a bunched chain links hands for real (links cannot stand closer than 2 x body_radius = 0.8 m)
	var tight := RB.flat(e.global_position - c.global_position).normalized()
	if tight.length() < 0.5:
		tight = Vector3.RIGHT
	TestCtx.put(c, post.x, post.z)
	TestCtx.put(d, post.x + tight.x * 0.9, post.z + tight.z * 0.9)
	TestCtx.put(e, post.x + tight.x * 1.8, post.z + tight.z * 1.8)
	t.steps(host, 4)
	for p in [c, d, e]:
		(p.visual as HeroVisual).settle_chain_draw()
	await t.frames(8)
	var gap_cd := visc.grip_hand(1).distance_to(visd.grip_hand(0))
	var gap_de := visd.grip_hand(1).distance_to(vise.grip_hand(0))
	t.check(gap_cd < 0.15, "a bunched chain links the post holder's hand to the next link's hand (%.3f m apart)" % gap_cd)
	t.check(gap_de < 0.15, "a bunched chain links the middle link's hand to the tip's hand (%.3f m apart)" % gap_de)
	t.check(RB.flat_dist(visc.grip_hand(1), visd.grip_hand(0)) < 0.15, "the two gripping hands converge on one point")
	t.check(absf(visc.grip_hand(1).y - visd.grip_hand(0).y) < 0.12, "the two gripping hands meet at the same height (%.3f m)" % absf(visc.grip_hand(1).y - visd.grip_hand(0).y))
	# the tip walks slowly
	var p0 := e.global_position
	inp.move(e, Vector2(0, -1))
	t.steps(host, 60)
	inp.move(e, Vector2.ZERO)
	t.check(RB.flat_dist(e.global_position, p0) <= tu.chain_tip_speed + 0.05, "the tip moves at most chain_tip_speed (%.2f m in 1 s)" % RB.flat_dist(e.global_position, p0))
	# the chain never leaves the play area
	inp.move(e, Vector2(0, 1))
	t.steps(host, 240)
	inp.move(e, Vector2.ZERO)
	var inside := true
	for p in js.chain(D):
		inside = inside and host.layout.bounds.grow(0.01).has_point(Vector2((p as Hero).global_position.x, (p as Hero).global_position.z))
	t.check(inside, "every link stays inside the play bounds")
	# steer back out and get rescued
	inp.move(e, Vector2(1, 0))
	t.steps(host, 120)
	inp.move(e, Vector2.ZERO)
	t.steps(host, 30)
	var tip := e.global_position
	TestCtx.put(f, tip.x + 1.5, tip.z)
	t.steps(host, 3)
	t.check(e.state == Hero.State.CHAINED, "a teammate 1.5 m from the tip does not rescue")
	t.check(js.find_rescues().is_empty(), "no rescue yet")
	TestCtx.put(f, e.global_position.x + 0.6, e.global_position.z)
	t.steps(host, 1)
	t.check(c.state == Hero.State.FREE and d.state == Hero.State.FREE and e.state == Hero.State.FREE, "touching the tip frees the whole chain")
	t.check(js.chain(D).is_empty(), "chain cleared")
	t.check(RB.flat_dist(c.global_position, post) >= tu.jail_post_barrier + tu.body_radius, "freed heroes are moved off the post")
	t.check(c.ep_ticks == 240 and d.ep_ticks == 240, "freed heroes get 4 s = 240 ticks of EP (got %d)" % c.ep_ticks)
	t.check(c.lockout_ticks == 240 and d.lockout_ticks == 240, "capture lockout 4 s after a rescue")
	t.check(not host.can_tag(a, c), "freed heroes are untaggable (EP)")
	t.check(_count("rescue") == 1, "rescue event")
	t.check(host.stats[f.slot].rescues == 3, "rescuer's rescue stat counts all three freed")
	# lockout: a freed hero cannot start a capture for 4 s
	TestCtx.put(c, -10.6, 0)
	inp.hold(c, USE)
	t.steps(host, 60)
	t.check(not c.capturing, "capture lockout: cannot start a capture in the first 4 s")
	t.steps(host, 190)
	t.check(c.ep_ticks == 0 and c.lockout_ticks == 0, "EP and lockout expire after 240 ticks")
	t.steps(host, 2)
	t.check(c.capturing, "can capture once the lockout is over")
	t.ok("automatic chain: post holder slides the post, tip steering, drag, bounds, rescue, EP and lockout")
	await t.free_match(host)

## v0.2 jail line: the post holder walks the post along the map's jail line at
## chain_post_speed; the post never leaves the line and the holder keeps a hand on it.
func _post_slide(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene", "jm"]) # a third Lila: no lockdown
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var d: Hero = host.heroes[3]
	var js := host.jail_system
	var tu := host.tuning
	var inp := t.inputs(host)
	_jail(t, host, a, [c, d])
	t.check(js.is_post_holder(c) and js.can_steer(c), "the first prisoner holds the post and can steer")
	var s0: float = js.anchor_s[D]
	var post0 := js.post(D)
	inp.move(c, Vector2(0, -1))
	t.steps(host, 60)
	inp.move(c, Vector2.ZERO)
	var slid := RB.flat_dist(js.post(D), post0)
	t.check(float(js.anchor_s[D]) < s0 - 0.3, "the post holder drags the post along the jail line (%.2f -> %.2f m)" % [s0, js.anchor_s[D]])
	t.check(slid <= tu.chain_post_speed + 0.05, "the post slides at most chain_post_speed (%.2f m in 1 s)" % slid)
	t.check(host.layout.line_distance(D, js.post(D)) < 0.01, "the post stays on the jail line")
	t.check(RB.flat_dist(c.global_position, js.post(D)) <= tu.post_hold_offset + 0.36, "the holder keeps a hand on the moving post")
	t.check(RB.flat_dist(d.global_position, c.global_position) <= tu.chain_link + 0.02, "the tip is dragged along with the post")
	inp.move(c, Vector2(0, -1))
	t.steps(host, 600)
	inp.move(c, Vector2.ZERO)
	t.check(t.near(float(js.anchor_s[D]), 0.0, 0.01), "the post stops at the end of the line")
	t.check(host.layout.in_jail(D, c.global_position), "the holder is still in jail at the end of the line")
	t.ok("jail line: the post holder slides the post along the line")
	await t.free_match(host)

func _lone_prisoner_rescue(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene", "tutoy"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var f: Hero = host.heroes[4]
	var inp := t.inputs(host)
	var tu := host.tuning
	var post := host.jail_system.post(D)
	_jail(t, host, a, [c])
	t.check(host.jail_system.chain(D) == [c] and host.jail_system.can_steer(c), "a lone prisoner holds the post and is the tip")
	inp.move(c, Vector2(1, 0))
	t.steps(host, 120)
	inp.move(c, Vector2.ZERO)
	t.check(RB.flat_dist(c.global_position, post) <= tu.chain_link + 0.02, "a lone prisoner leans at most one link from the post (%.2f)" % RB.flat_dist(c.global_position, post))
	t.check(RB.flat_dist(c.global_position, post) > tu.jail_post_barrier + tu.body_radius, "and can reach past the post barrier")
	t.check(RB.flat_dist(host.jail_system.rescue_point(D), c.global_position) < 0.01, "the rescue point is the prisoner")
	TestCtx.put(f, c.global_position.x + 0.6, c.global_position.z)
	t.steps(host, 1)
	t.check(c.state == Hero.State.FREE and c.has_ep(), "touching the lone prisoner frees it")
	t.ok("lone prisoner rescue")
	await t.free_match(host)

func _same_tick_rescue(t: TestCtx) -> void:
	var host := _live(t, ["nene"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[1]
	var d: Hero = host.heroes[2]
	var inp := t.inputs(host)
	_jail(t, host, a, [c])
	inp.move(c, Vector2(1, 0))
	t.steps(host, 60)
	inp.move(c, Vector2.ZERO)
	t.steps(host, 2)
	var tip := c.global_position
	TestCtx.put(a, tip.x + 1.7, tip.z)
	TestCtx.put(d, tip.x + 4.0, tip.z)
	inp.aim_at(a, tip)
	inp.press(a, TAG)
	t.steps(host, RB.ticks(host.tuning.tag_windup))
	t.check(host.round_flow.phase == RoundFlow.Phase.PLAYING, "still playing before the tag lands")
	TestCtx.put(d, tip.x + 0.6, tip.z) # the last free Lila hero touches the tip on the landing tick
	t.steps(host, 1)
	t.check(d.state == Hero.State.TAGGED, "the last free hero is tagged on the same tick")
	t.check(c.state == Hero.State.FREE, "the same-tick rescue freed the prisoner")
	t.check(host.round_flow.phase == RoundFlow.Phase.PLAYING, "a same-tick rescue beats lockdown")
	t.ok("same-tick rescue beats lockdown")
	await t.free_match(host)
func _lockdown(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var d: Hero = host.heroes[3]
	c.on_tagged(a)
	t.steps(host, 5)
	t.check(host.round_flow.phase == RoundFlow.Phase.PLAYING, "one prisoner is not a lockdown")
	d.on_tagged(a)
	t.steps(host, 1)
	t.check(host.round_flow.phase == RoundFlow.Phase.ROUND_OVER, "every Lila hero Tagged/Jailed/Chained ends the round")
	t.check(host.round_flow.score == [1, 0], "lockdown: the other team gets +1")
	t.check(host.round_flow.last_result.reason == "lockdown", "reason: lockdown")
	t.ok("lockdown ends the round")
	await t.free_match(host)

func _timer_and_sudden_death(t: TestCtx) -> void:
	# spec § 7: the music turns tense with 30 s left on the round clock (final_stretch, once)
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"], {"round_time": 32.0})
	var stretch := RB.ticks(32.0) - RB.ticks(host.tuning.final_stretch_time)
	t.steps(host, stretch - 1)
	t.check(_count("final_stretch") == 0, "no final_stretch before %.0f s left" % host.tuning.final_stretch_time)
	t.steps(host, 1)
	t.check(_count("final_stretch") == 1, "final_stretch fires on the tick the clock reaches %.0f s left" % host.tuning.final_stretch_time)
	t.steps(host, 60)
	t.check(_count("final_stretch") == 1, "and only once")
	await t.free_match(host)

	# fewer jailed at 0:00 wins
	host = _live(t, ["nene", "inday"], ["nathan", "nene"], {"round_time": 4.0})
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	c.on_tagged(a)
	t.steps(host, 4 * 60 - 1)
	t.check(host.round_flow.phase == RoundFlow.Phase.PLAYING, "timer still running at 3.98 s")
	t.steps(host, 1)
	t.check(host.round_flow.phase == RoundFlow.Phase.ROUND_OVER and host.round_flow.score == [1, 0], "timer at 0: fewer jailed wins (+1)")
	t.check(host.round_flow.last_result.reason == "sunset", "reason: sunset")
	await t.free_match(host)

	# equal -> sudden death 30 s; first tag wins
	host = _live(t, ["nene", "inday"], ["nathan", "nene"], {"round_time": 3.0})
	a = host.heroes[0]
	c = host.heroes[2]
	t.steps(host, 180)
	t.check(host.round_flow.phase == RoundFlow.Phase.SUDDEN_DEATH, "equal jailed at 0:00: sudden death")
	t.check(host.round_flow.timer_ticks == 1800, "sudden death lasts 30 s = 1800 ticks (got %d)" % host.round_flow.timer_ticks)
	t.check(_count("sudden_death") == 1, "sudden_death event")
	t.check(_count("final_stretch") == 0, "a round shorter than the stretch never fires final_stretch (sudden death turns the music tense instead)")
	TestCtx.put(a, 0, 0)
	TestCtx.put(c, 1.6, 0)
	_face_east(t, host, a)
	_tag(t, host, a)
	t.check(host.round_flow.phase == RoundFlow.Phase.ROUND_OVER and host.round_flow.score == [1, 0], "sudden death: the first successful tag wins")
	t.check(host.round_flow.last_result.reason == "sudden_death", "reason: sudden_death")
	await t.free_match(host)

	# neither -> draw, no point, replay; after 2 draws sudden death is untimed
	host = _live(t, ["nene", "inday"], ["nathan", "nene"], {"round_time": 2.0})
	for draw in range(2):
		var n := _until(host, func(): return host.round_flow.phase == RoundFlow.Phase.SUDDEN_DEATH)
		t.check(n >= 0, "draw %d: reaches sudden death" % (draw + 1))
		t.check(host.round_flow.timer_ticks == 1800, "draw %d: timed sudden death" % (draw + 1))
		n = _until(host, func(): return host.round_flow.phase == RoundFlow.Phase.ROUND_OVER, 2000)
		t.check(n >= 0 and host.round_flow.last_result.winner == -1, "draw %d: sudden death times out as a draw" % (draw + 1))
		t.check(host.round_flow.score == [0, 0], "a draw gives no point")
		t.check(host.round_flow.draws == draw + 1, "draw counter")
		n = _until(host, func(): return host.round_flow.phase == RoundFlow.Phase.COUNTDOWN, 1000)
		t.check(n >= 0 and host.round_flow.round_number == draw + 2, "a drawn round is replayed (round %d)" % host.round_flow.round_number)
		t.go_live(host)
	var n2 := _until(host, func(): return host.round_flow.phase == RoundFlow.Phase.SUDDEN_DEATH)
	t.check(n2 >= 0 and host.round_flow.timer_ticks == -1, "after 2 draws sudden death is untimed")
	t.ok("round timer, sunset, sudden death, draws")
	await t.free_match(host)

func _round_reset(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday", "tutoy"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[3]
	var inp := t.inputs(host)
	TestCtx.put(c, -10.6, 0)
	inp.hold(c, USE)
	t.steps(host, RB.ticks(host.tuning.capture_hold))
	t.check(host.round_flow.score == [0, 1], "Lila captured")
	a.ep_ticks = 100
	a.stumble_ticks = 50
	host.heroes[1].on_tagged(c) # a Tagged hero at round end
	var n := _until(host, func(): return host.round_flow.phase == RoundFlow.Phase.COUNTDOWN, 1000)
	t.check(n >= 0 and host.round_flow.round_number == 2, "the next round starts after the between-rounds time")
	t.check(host.round_flow.phase_ticks > 150, "countdown restarts at 3 s")
	for h in host.heroes:
		t.check(h.state == Hero.State.FREE and h.ep_ticks == 0 and h.stumble_ticks == 0 and h.lockout_ticks == 0 and not h.capturing, "%s reset to a clean Free state" % h.name)
	var sp: Array = host.layout.spawns[D]
	t.check(RB.flat_dist(host.heroes[0].global_position, sp[0]) < 0.1, "Dilaw slot 1 at spawn 1")
	t.check(RB.flat_dist(host.heroes[1].global_position, sp[0]) <= 1.3 and RB.flat_dist(host.heroes[1].global_position, sp[0]) > 0.5, "Dilaw slot 2 shares spawn 1")
	var spl: Array = host.layout.spawns[L]
	t.check(RB.flat_dist(host.heroes[3].global_position, spl[0]) < 0.1, "Lila slot 1 at its spawn 1")
	t.check(host.jail_system.chain(D).is_empty() and host.jail_system.chain(L).is_empty(), "chains cleared")
	t.check(host.round_flow.score == [0, 1], "scores persist across rounds")
	for h in host.heroes:
		t.check(not host.base_system.in_own_ring(h), "spawns are outside every ring")
	t.ok("round reset: spawns, free, clean state")
	await t.free_match(host)

func _match_end(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	for rd in range(3):
		t.check(host.round_flow.phase == RoundFlow.Phase.PLAYING, "round %d is live" % (rd + 1))
		for c in [host.heroes[2], host.heroes[3]]:
			(c as Hero).on_tagged(a)
		t.steps(host, 1)
		t.check(host.round_flow.score == [rd + 1, 0], "score after round %d: %s" % [rd + 1, host.round_flow.score])
		var n := _until(host, func(): return host.round_flow.phase != RoundFlow.Phase.ROUND_OVER, 1000)
		t.check(n >= 0, "between-rounds time ends")
		if rd < 2:
			t.check(host.round_flow.phase == RoundFlow.Phase.COUNTDOWN and host.round_flow.round_number == rd + 2, "first to 3: play continues at %d point(s)" % (rd + 1))
			t.go_live(host)
			_park(host)
	t.check(host.round_flow.phase == RoundFlow.Phase.MATCH_OVER, "first to 3 ends the match")
	t.check(host.round_flow.winner == D, "Dilaw wins the match")
	t.check(_count("match_end") == 1, "match_end event")
	t.ok("first to 3 ends the match")
	await t.free_match(host)

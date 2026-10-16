extends RefCounted

## The core Agawan Base rules against docs/RESBAK.md section 2, in small 2v2 / 2v4 matches on the
## grey test arena (TestCtx.make_match): manual stepping, scripted input, exact tick counts.
## Arena facts: base_mode 1 -> Dilaw pole (-12, 0), Lila pole (12, 0); Jail_Dilaw holds Lila
## prisoners (x -19.6..-13.6, z 5.2..9.2), marker (-13.6, 7.2), hand point (-12.1, 7.2).

const D := RB.DILAW
const L := RB.LILA
const TAG := RB.BTN_TAG
const USE := RB.BTN_INTERACT

var log_events: Array = []

func run(t: TestCtx) -> void:
	await _countdown(t)
	await _movement(t)
	await _can_tag_table(t)
	await _tag_hit_and_jail(t)
	await _tag_geometry(t)
	await _failed_tag(t)
	await _escape_protection(t)
	await _sabay(t)
	await _barrier(t)
	await _capture(t)
	await _capture_cancel(t)
	await _chain_and_rescue(t)
	await _anchor_let_go(t)
	await _lone_anchor_rescue(t)
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

## Tag press, then step to the landing tick (press tick + 9 wind-up ticks). 10 steps.
func _tag(t: TestCtx, host: MatchHost, h: Hero) -> void:
	t.inputs(host).press(h, TAG)
	t.steps(host, 10)

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

func _movement(t: TestCtx) -> void:
	for pair in [["nene", 5.0], ["jm", 4.6], ["nathan", 5.0], ["inday", 5.0], ["tutoy", 5.4]]:
		var host := _live(t, [pair[0], "inday"], ["nathan", "nene"])
		var a: Hero = host.heroes[0]
		TestCtx.put(a, -6, 2)
		var inp := t.inputs(host)
		inp.move(a, Vector2(1, 0))
		t.steps(host, 20)
		if pair[0] == "tutoy": # DIRE-DIRETSO climbs up to +15 % over 3 s
			t.check(a.ground_speed() >= pair[1] - 0.05 and a.ground_speed() <= pair[1] * 1.15 + 0.05, "tutoy reaches run speed 5.4 (+ Dire-Diretso), got %.2f" % a.ground_speed())
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
	t.inputs(host).press(a, TAG)
	t.steps(host, 9)
	t.check(c.state == Hero.State.FREE, "the tag has not landed during the 9-tick wind-up")
	t.check(a.is_winding_up(), "tagger is winding up")
	t.steps(host, 1)
	t.check(c.state == Hero.State.TAGGED, "tag lands on tick 9 after the press")
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
	t.check(c.state == Hero.State.JAILED, "jailed after 0.8 s = 48 ticks")
	t.inputs(host).move(c, Vector2.ZERO)
	t.check(host.layout.in_jail(D, c.global_position), "the victim is inside the TAGGER's jail (Jail_Dilaw holds Lila), at %s" % c.global_position)
	t.check(_count("jailed") == 1, "jailed event")
	t.check(host.jail_system.jailed_count(L) == 1, "jailed count")
	# Jailed heroes move but cannot tag or capture
	t.inputs(host).press(c, TAG)
	t.steps(host, 15)
	t.check(not c.is_winding_up(), "a Jailed hero cannot press Tag")
	# jail barrier keeps free heroes out
	var b: Hero = host.heroes[1]
	TestCtx.put(b, -16.6, 3.0)
	t.inputs(host).move(b, Vector2(0, 1))
	t.steps(host, 90)
	t.check(not host.layout.in_jail(D, b.global_position), "the jail barrier blocks free heroes (at %s)" % b.global_position)
	t.ok("tag hit -> 0.8 s freeze -> tagger's jail, barrier")
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
	t.steps(host, 10)
	t.check(a.state == Hero.State.FREE and c.state == Hero.State.FREE, "Sabay: nobody is jailed")
	t.check(a.stumble_ticks > 0 and c.stumble_ticks > 0, "Sabay: both stumble")
	t.check(_count("sabay") == 1, "one sabay event")
	t.check(d.state == Hero.State.TAGGED, "other tags apply on a Sabay tick")
	t.ok("Sabay")
	await t.free_match(host)

func _barrier(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var pole := host.base_system.pole_pos(D)
	t.check(t.near(pole.x, -12.0) and t.near(pole.z, 0.0), "Dilaw pole at site 1")
	TestCtx.put(a, -6, 0)
	t.inputs(host).move(a, Vector2(-1, 0))
	t.steps(host, 150)
	var da := RB.flat_dist(a.global_position, pole)
	t.check(da >= 2.39 and da < 2.6, "own-base barrier holds the team >= 2.4 m from its pole (%.2f)" % da)
	t.check(_count("barrier_bump") > 0, "barrier bump event")
	t.inputs(host).move(a, Vector2.ZERO)
	TestCtx.put(c, -7.0, 2.5)
	t.inputs(host).move(c, Vector2(-5.0, -2.5).normalized())
	t.steps(host, 150)
	var dc := RB.flat_dist(c.global_position, pole)
	t.check(dc < 1.0, "an enemy passes the other team's barrier (%.2f m from the pole)" % dc)
	t.ok("own-base barrier blocks own team only")
	await t.free_match(host)

func _capture(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"])
	var c: Hero = host.heroes[2]
	TestCtx.put(c, -10.6, 0) # gap 1.4 - 0.4 - 0.2 = 0.8 m <= 1
	var inp := t.inputs(host)
	t.check(host.base_system.in_capture_range(c), "in capture range at 0.8 m gap")
	inp.hold(c, USE)
	inp.move(c, Vector2(0, 1))
	t.steps(host, 89)
	t.check(c.capturing and c.capture_ticks == 89, "capturing, progress 89 ticks (got %d)" % c.capture_ticks)
	t.check(host.round_flow.phase == RoundFlow.Phase.PLAYING and host.round_flow.score == [0, 0], "not captured at 89 ticks")
	t.check(t.near(c.global_position.z, 0.0, 0.1), "a capturing hero cannot move")
	t.check(t.near(host.base_system.capture_progress(L), 89.0 / 90.0, 0.001), "capture progress for the HUD")
	t.steps(host, 1)
	t.check(host.round_flow.phase == RoundFlow.Phase.ROUND_OVER, "capture completes at 1.5 s = 90 ticks: round over")
	t.check(host.round_flow.score == [0, 1], "capturers get +1 (Lila)")
	t.check(host.round_flow.last_result.winner == L and host.round_flow.last_result.reason == "capture", "round result: Lila by capture")
	t.check(_count("capture") == 1 and _count("round_end") == 1, "capture and round_end events")
	t.check(not c.capturing, "capture cleared at round end")
	t.ok("capture 1.5 s wins the round")
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
	_jail(t, host, a, [c, d, e])
	t.check(c.state == Hero.State.JAILED and d.state == Hero.State.JAILED and e.state == Hero.State.JAILED, "three prisoners in jail")
	var marker := host.layout.marker(D)
	var hand := host.jail_system.hand_point(D)
	t.check(t.near(marker.x, -13.6) and t.near(marker.z, 7.2), "marker on the prisoners' side of Jail_Dilaw")
	t.check(t.near(hand.x, -12.1) and t.near(hand.z, 7.2), "hand point 1.5 m outside the marker")
	# too far from the marker: no anchor
	TestCtx.put(e, -18.5, 5.8)
	inp.press(e, USE)
	t.steps(host, 2)
	t.check(e.state == Hero.State.JAILED and host.jail_system.chain(D).is_empty(), "Interact far from the marker does not anchor")
	# anchor within 1 m of the marker
	TestCtx.put(c, -14.0, 7.2)
	inp.press(c, USE)
	t.steps(host, 1)
	t.check(c.state == Hero.State.CHAINED and host.jail_system.chain(D) == [c], "Interact near the marker makes the anchor")
	t.check(not host.jail_system.can_steer(c), "a lone anchor does not move")
	# join within 1.5 m of the anchor
	TestCtx.put(d, -15.0, 7.2)
	inp.press(d, USE)
	t.steps(host, 1)
	t.check(d.state == Hero.State.CHAINED and host.jail_system.chain(D) == [c, d], "Interact near the anchor joins the chain; the joiner is the tip")
	t.check(RB.flat_dist(d.global_position, hand) <= 1.5 + 0.01, "tip is within 1.5 m of the hand point (%.2f)" % RB.flat_dist(d.global_position, hand))
	# a prisoner too far from anchor and tip cannot join
	inp.press(e, USE)
	t.steps(host, 1)
	t.check(e.state == Hero.State.JAILED, "too far from the anchor or tip: cannot join")
	# a chained hero can't be tagged, tag, or use skills
	t.check(not host.can_tag(a, d), "a Chained hero is untaggable")
	# the tip steers and crosses the jail barrier; the anchor stays
	var anchor_at := c.global_position
	inp.move(d, Vector2(1, 0))
	t.steps(host, 90)
	inp.move(d, Vector2.ZERO)
	t.steps(host, 15)
	var reach := RB.flat_dist(d.global_position, hand)
	t.check(reach <= 1.5 + 0.02, "the tip stays within 1.5 m of the hand point (%.2f)" % reach)
	t.check(d.global_position.x > -13.0, "the chained tip crosses the jail barrier (x %.2f)" % d.global_position.x)
	t.check(RB.flat_dist(c.global_position, anchor_at) < 0.05, "the anchor is immobile")
	# let go: the tip returns to a jail spot, the chain shrinks
	inp.press(d, USE)
	t.steps(host, 1)
	t.check(d.state == Hero.State.JAILED and host.jail_system.chain(D) == [c], "letting go returns the tip to jail")
	t.check(host.layout.in_jail(D, d.global_position), "the one who let go is back in the jail")
	# rejoin and walk the tip out
	TestCtx.put(d, -15.0, 7.2)
	inp.press(d, USE)
	t.steps(host, 1)
	inp.move(d, Vector2(1, 0))
	t.steps(host, 90)
	inp.move(d, Vector2.ZERO)
	t.steps(host, 15)
	var tip := d.global_position
	# a free teammate 1.5 m from the tip does nothing; touching (<= 0.8) frees the whole chain
	TestCtx.put(f, tip.x + 1.5, tip.z)
	t.steps(host, 3)
	t.check(d.state == Hero.State.CHAINED, "a teammate 1.5 m from the tip does not rescue")
	t.check(host.jail_system.find_rescues().is_empty(), "no rescue yet")
	TestCtx.put(f, tip.x + 0.6, tip.z)
	t.steps(host, 1)
	t.check(c.state == Hero.State.FREE and d.state == Hero.State.FREE, "touching the tip frees the whole chain")
	t.check(e.state == Hero.State.JAILED, "unchained prisoners stay in jail")
	t.check(host.jail_system.chain(D).is_empty(), "chain cleared")
	t.check(c.ep_ticks == 240 and d.ep_ticks == 240, "freed heroes get 4 s = 240 ticks of EP (got %d)" % c.ep_ticks)
	t.check(c.lockout_ticks == 240 and d.lockout_ticks == 240, "capture lockout 4 s after a rescue")
	t.check(not host.can_tag(a, c), "freed heroes are untaggable (EP)")
	t.check(_count("rescue") == 1, "rescue event")
	t.check(host.stats[f.slot].rescues == 2, "rescuer's rescue stat counts both freed")
	# lockout: a freed hero cannot start a capture for 4 s
	TestCtx.put(c, -10.6, 0)
	inp.hold(c, USE)
	t.steps(host, 60)
	t.check(not c.capturing, "capture lockout: cannot start a capture in the first 4 s")
	t.steps(host, 190)
	t.check(c.ep_ticks == 0 and c.lockout_ticks == 0, "EP and lockout expire after 240 ticks")
	t.steps(host, 2)
	t.check(c.capturing, "can capture once the lockout is over")
	t.ok("chain anchor / join / steer / let go, rescue by touching the tip, EP and lockout")
	await t.free_match(host)

func _anchor_let_go(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene", "tutoy", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var d: Hero = host.heroes[3]
	var inp := t.inputs(host)
	_jail(t, host, a, [c, d])
	TestCtx.put(c, -14.0, 7.2)
	inp.press(c, USE)
	t.steps(host, 1)
	TestCtx.put(d, -15.0, 7.2)
	inp.press(d, USE)
	t.steps(host, 1)
	t.check(host.jail_system.chain(D).size() == 2, "two chained")
	inp.press(c, USE)
	t.steps(host, 1)
	t.check(host.jail_system.chain(D).is_empty() and c.state == Hero.State.JAILED and d.state == Hero.State.JAILED, "the anchor letting go returns everyone to jail")
	t.ok("anchor let go returns all")
	await t.free_match(host)

func _lone_anchor_rescue(t: TestCtx) -> void:
	var host := _live(t, ["nene", "inday"], ["nathan", "nene", "tutoy"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	var f: Hero = host.heroes[4]
	var inp := t.inputs(host)
	_jail(t, host, a, [c])
	TestCtx.put(c, -14.0, 7.2)
	inp.press(c, USE)
	t.steps(host, 1)
	var hand := host.jail_system.hand_point(D)
	t.check(t.near(host.jail_system.rescue_point(D).x, hand.x), "the rescue point of a lone anchor is the hand point")
	TestCtx.put(f, hand.x + 0.6, hand.z)
	t.steps(host, 3)
	t.check(c.state == Hero.State.CHAINED, "a lone anchor needs the rescuer within 0.4 m of the hand point (0.6 is too far)")
	TestCtx.put(f, hand.x + 0.3, hand.z)
	t.steps(host, 1)
	t.check(c.state == Hero.State.FREE and c.has_ep(), "within 0.4 m of the hand point frees the lone anchor")
	t.ok("lone anchor rescue point")
	await t.free_match(host)

func _same_tick_rescue(t: TestCtx) -> void:
	var host := _live(t, ["nene"], ["nathan", "nene"])
	var a: Hero = host.heroes[0]
	var c: Hero = host.heroes[1]
	var d: Hero = host.heroes[2]
	var inp := t.inputs(host)
	_jail(t, host, a, [c])
	TestCtx.put(c, -14.0, 7.2)
	inp.press(c, USE)
	t.steps(host, 1)
	var hand := host.jail_system.hand_point(D)
	TestCtx.put(a, hand.x + 1.7, hand.z)
	TestCtx.put(d, hand.x + 4.0, hand.z)
	inp.aim_at(a, hand)
	inp.press(a, TAG)
	t.steps(host, 9)
	t.check(host.round_flow.phase == RoundFlow.Phase.PLAYING, "still playing before the tag lands")
	TestCtx.put(d, hand.x, hand.z) # the last free Lila hero arrives on the landing tick
	t.steps(host, 1)
	t.check(d.state == Hero.State.TAGGED, "the last free hero is tagged on the same tick")
	t.check(c.state == Hero.State.FREE, "the same-tick rescue freed the anchor")
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
	# fewer jailed at 0:00 wins
	var host := _live(t, ["nene", "inday"], ["nathan", "nene"], {"round_time": 4.0})
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
	t.steps(host, 90)
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

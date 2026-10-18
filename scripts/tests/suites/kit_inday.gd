extends RefCounted

## Inday's kit against docs/RESBAK.md § 4 Inday: IHIP! (wind lane, +25 % for free allies, stands
## still, walls cut it, ends on recast / tag / push / stun), HILA! (v0.2: a 9 m stretched hand that
## pulls the first teammate it touches and rescues a chain tip it touches) and TAKBO NA! (+20 % for 2 s for her and the freed, +1 s EP, no stacking).
## Manual stepping on the grey arena (TestCtx.make_match), exact tick counts.

const D := RB.DILAW
const L := RB.LILA
const S1 := RB.BTN_SKILL1
const S2 := RB.BTN_SKILL2
const TAG := RB.BTN_TAG
const USE := RB.BTN_INTERACT

var log_events: Array = []
var log_data: Array = []

func run(t: TestCtx) -> void:
	await _data(t)
	await _ihip_basics(t)
	await _ihip_lane(t)
	await _ihip_aim_turn(t)
	await _ihip_wall(t)
	await _ihip_ends(t)
	await _ihip_no_stack(t)
	await _hila_cast(t)
	await _hila_pull_ally(t)
	await _hila_rescue(t)
	await _hila_wall(t)
	await _takbo_touch(t)
	await _takbo_other_rescuer(t)

# ---- helpers ---------------------------------------------------------------------------
## Dilaw: nene, nathan (enemies). Lila: inday (slot 2), tutoy (3), nene (4), nathan (5).
func _live(t: TestCtx) -> MatchHost:
	var lineup := [
		{"hero_id": "nene", "team": D}, {"hero_id": "nathan", "team": D},
		{"hero_id": "inday", "team": L}, {"hero_id": "tutoy", "team": L},
		{"hero_id": "nene", "team": L}, {"hero_id": "nathan", "team": L},
	]
	var host := t.make_match(lineup)
	log_events = []
	log_data = []
	host.event.connect(func(kind: String, data: Dictionary):
		log_events.append(kind)
		log_data.append(data))
	t.go_live(host)
	for i in range(host.heroes.size()):
		TestCtx.put(host.heroes[i], -9.0 + 3.0 * i, -10.0)
	return host

func _inday(host: MatchHost) -> Hero:
	return host.heroes[2]

func _ihip(h: Hero) -> Skill:
	return h.skills[0]

func _hila(h: Hero) -> Skill:
	return h.skills[1]

func _has(h: Hero, source: String) -> bool:
	return h.has_modifier(source)

func _count(kind: String) -> int:
	return log_events.count(kind)

## Fresh cooldown, press the skill and run the cast tick.
func _cast(t: TestCtx, host: MatchHost, h: Hero, slot: int) -> void:
	h.skills[slot].cd_ticks = 0
	t.inputs(host).press(h, S1 if slot == 0 else S2)
	t.steps(host, 1)

func _wall(host: MatchHost, at: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "TestWall"
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	wall.add_child(cs)
	host.world.add_child(wall)
	wall.global_position = at
	wall.force_update_transform() # Jolt takes the new transform now, not next physics frame
	return wall

## Lila chain of two stretched out in Jail_Dilaw: post holder Nene (slot 4), tip Nathan (slot 5).
## Returns the tip position. Dilaw's Nene (slot 0) is the tagger.
func _chain_out(t: TestCtx, host: MatchHost) -> Vector3:
	var inp := t.inputs(host)
	var tagger: Hero = host.heroes[0]
	var c: Hero = host.heroes[4]
	var d: Hero = host.heroes[5]
	c.on_tagged(tagger)
	d.on_tagged(tagger)
	t.steps(host, 49)
	inp.move(d, Vector2(1, 0))
	t.steps(host, 120)
	inp.move(d, Vector2.ZERO)
	t.steps(host, 15)
	return d.global_position

# ---- tests -----------------------------------------------------------------------------
func _data(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	t.check(inday.data.id == "inday" and inday.data.run_speed == 4.5, "Inday runs at 4.5 m/s")
	t.check(inday.skills[0].cooldown == 15.0 and inday.skills[1].cooldown == 14.0, "IHIP! 15 s, HILA! 14 s cooldowns")
	t.check(inday.skills[0].kind() == RB.SkillKind.MOVEMENT, "IHIP! is a Movement skill")
	t.check(inday.skills[1].kind() == RB.SkillKind.NEITHER, "HILA! is neither Offensive nor Movement")
	t.check(_hila(inday).rescue_touch_point() == Vector3.INF, "HILA! gives no rescue touch while idle")
	t.check(t.near(inday.passive.extra_rescue_protection(), 1.0), "TAKBO NA! gives +1 s of EP")
	t.ok("Inday data: speed, cooldowns, kinds")
	await t.free_match(host)

func _ihip_basics(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var inp := t.inputs(host)
	TestCtx.put(inday, -4, 0)
	inp.aim_at(inday, Vector3(5, 0, 0))
	_cast(t, host, inday, 0)
	var s := _ihip(inday)
	t.check(s.active and s.controls_movement(), "IHIP! starts and drives movement")
	t.check(s.cd_ticks > 880 and s.cd_ticks <= 900, "IHIP! cooldown (15 s = 900 ticks) starts on cast (%d)" % s.cd_ticks)
	t.check(s.lane_active() and t.near(s.lane_length(), 10.0, 0.05), "the lane is 10 m long in the open (%.2f)" % s.lane_length())
	var lane := host.world.get_node_or_null("IhipLane")
	t.check(lane != null and lane.visible, "wind lane VFX exists while blowing")
	# stands still
	var at := inday.global_position
	inp.move(inday, Vector2(1, 0))
	t.steps(host, 30)
	t.check(RB.flat_dist(inday.global_position, at) < 0.02, "can't move while blowing (moved %.2f)" % RB.flat_dist(inday.global_position, at))
	t.check(_ihip(inday).active, "still blowing after 0.5 s of move input")
	# can't tag
	inp.press(inday, TAG)
	t.steps(host, 2)
	t.check(not inday.is_winding_up() and not inday.can_press_tag(), "can't tag while blowing")
	# can't cast the other skill
	_hila(inday).cd_ticks = 0
	inp.press(inday, S2)
	t.steps(host, 2)
	t.check(_hands(host).is_empty() and _hila(inday).cd_ticks == 0, "can't cast HILA! while blowing")
	t.check(not inday.can_use_skills(), "no skills while blowing")
	# stays taggable
	t.check(inday.is_taggable(), "Inday is still taggable while blowing")
	inp.move(inday, Vector2.ZERO)
	t.ok("IHIP! cast: lane, cooldown, stands still, no tag, no other skill, taggable")
	await t.free_match(host)

func _ihip_lane(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var ally_in: Hero = host.heroes[3] # tutoy
	var ally_side: Hero = host.heroes[4]
	var ally_far: Hero = host.heroes[5]
	var enemy: Hero = host.heroes[0]
	var inp := t.inputs(host)
	TestCtx.put(inday, -4, 0)
	TestCtx.put(ally_in, 2, 1.3) # along 6, side 1.3 -> inside
	TestCtx.put(ally_side, 2, -1.9) # side 1.9 > 1.5 -> outside
	TestCtx.put(ally_far, 6.4, 0) # along 10.4 -> past the end
	TestCtx.put(enemy, 0, 0.4) # inside, but an enemy
	inp.aim_at(inday, Vector3(5, 0, 0))
	_cast(t, host, inday, 0)
	t.check(_has(ally_in, "ihip"), "a free ally inside the lane gets the IHIP! bonus")
	t.check(t.near(ally_in.biggest_bonus(), 0.25), "bonus is +25 %% (%.2f)" % ally_in.biggest_bonus())
	t.check(t.near(ally_in.current_speed(), 4.85 * 1.25 * Tuning.get_default().move_speed_scale, 0.001), "Tutoy runs 4.85 x 1.25 inside the lane (%.3f)" % ally_in.current_speed())
	t.check(not _has(ally_side, "ihip"), "an ally 1.9 m off the centre line is outside the 3 m wide lane")
	t.check(not _has(ally_far, "ihip"), "an ally past 10 m is outside the lane")
	t.check(not _has(enemy, "ihip"), "enemies inside the lane get nothing")
	t.check(not _has(inday, "ihip"), "Inday does not buff herself")
	t.check(_ihip(inday).in_lane(Vector3(5.9, 0, 1.4)) and not _ihip(inday).in_lane(Vector3(6.1, 0, 0)), "lane edges: 10 m long, 1.5 m each side")
	# the ally leaves the lane: bonus gone that tick
	TestCtx.put(ally_in, 2, 2.5)
	t.steps(host, 1)
	t.check(not _has(ally_in, "ihip") and t.near(ally_in.biggest_bonus(), 0.0), "leaving the lane drops the bonus at once")
	TestCtx.put(ally_in, 2, 0.5)
	t.steps(host, 1)
	t.check(_has(ally_in, "ihip"), "re-entering the lane gives the bonus again")
	# a real run: speed over 60 ticks matches 1.25x
	TestCtx.put(ally_side, -2, -1.2)
	inp.move(ally_side, Vector2(1, 0))
	var x0 := ally_side.global_position.x
	t.steps(host, 60)
	var run_inside := ally_side.global_position.x - x0
	t.check(run_inside > 4.85 * Tuning.get_default().move_speed_scale, "an ally running in the lane covers more than base speed in 1 s (%.2f m)" % run_inside)
	inp.move(ally_side, Vector2.ZERO)
	t.ok("IHIP! lane: free allies +25 %, enemies and outsiders nothing, leaving drops it")
	await t.free_match(host)

func _ihip_aim_turn(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var ally: Hero = host.heroes[3]
	var inp := t.inputs(host)
	TestCtx.put(inday, -4, 0)
	TestCtx.put(ally, 2, 0)
	inp.aim_at(inday, Vector3(5, 0, 0))
	_cast(t, host, inday, 0)
	t.check(_has(ally, "ihip"), "ally east of Inday is in the east lane")
	# turn north (-Z): the lane turns with the aim
	TestCtx.put(ally, -4, -5)
	inp.aim_at(inday, Vector3(-4, 0, -5))
	t.steps(host, 1)
	t.check(t.near(_ihip(inday).lane_dir().z, -1.0, 0.01), "lane direction follows the aim")
	t.check(_has(ally, "ihip"), "an ally in the turned lane gets the bonus")
	TestCtx.put(ally, 2, 0)
	t.steps(host, 1)
	t.check(not _has(ally, "ihip"), "the old east lane is gone after turning")
	# and she can still aim without moving
	t.check(RB.flat_dist(inday.global_position, Vector3(-4, 0.05, 0)) < 0.05, "Inday stayed where she was while turning")
	t.ok("IHIP! lane turns with aim")
	await t.free_match(host)

func _ihip_wall(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var before: Hero = host.heroes[3]
	var behind: Hero = host.heroes[4]
	var inp := t.inputs(host)
	TestCtx.put(inday, -4, 0)
	TestCtx.put(before, -2, 0.5)
	TestCtx.put(behind, 2, 0.5)
	var wall := _wall(host, Vector3(0, 1, 0), Vector3(0.4, 2, 8))
	inp.aim_at(inday, Vector3(5, 0, 0))
	_cast(t, host, inday, 0)
	var cut: float = _ihip(inday).lane_length()
	t.check(t.near(cut, 3.8, 0.1), "a wall 4 m ahead cuts the lane to its near face (%.2f)" % cut)
	t.check(_has(before, "ihip"), "an ally before the wall is in the lane")
	t.check(not _has(behind, "ihip"), "an ally behind the wall is not")
	wall.queue_free()
	t.ok("IHIP! lane is cut by walls")
	await t.free_match(host)

func _ihip_ends(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var ally: Hero = host.heroes[3]
	var enemy: Hero = host.heroes[0]
	var inp := t.inputs(host)
	TestCtx.put(inday, -4, 0)
	TestCtx.put(ally, 1, 0)
	inp.aim_at(inday, Vector3(5, 0, 0))
	# runs out after 4 s = 240 ticks
	_cast(t, host, inday, 0)
	t.steps(host, 239)
	t.check(_ihip(inday).active and _has(ally, "ihip"), "still blowing after 240 ticks")
	t.steps(host, 1)
	t.check(not _ihip(inday).active, "IHIP! ends after 4 s (241st tick)")
	t.check(host.world.get_node_or_null("IhipLane") == null, "lane gone when it expires")
	t.check(not _has(ally, "ihip"), "bonus gone when it expires")
	# pressing S1 again ends it, lane and bonus gone the same tick
	_cast(t, host, inday, 0)
	t.check(_ihip(inday).active and _has(ally, "ihip"), "recast setup")
	var cd := _ihip(inday).cd_ticks
	inp.press(inday, S1)
	t.steps(host, 1)
	t.check(not _ihip(inday).active, "S1 again ends IHIP!")
	t.check(host.world.get_node_or_null("IhipLane") == null and not _has(ally, "ihip"), "lane and bonus are gone the same tick")
	t.check(_ihip(inday).cd_ticks >= cd - 2, "ending early does not refund the cooldown")
	# pushed
	_cast(t, host, inday, 0)
	inday.apply_push(Vector3(1, 0, 0), 2.0, true)
	t.check(not _ihip(inday).active, "a push ends IHIP!")
	t.check(host.world.get_node_or_null("IhipLane") == null and not _has(ally, "ihip"), "pushed: lane and bonus gone at once")
	t.steps(host, 30)
	# stunned
	TestCtx.put(inday, -4, 0)
	_cast(t, host, inday, 0)
	inday.stun(1.0, true)
	t.check(not _ihip(inday).active, "a stun ends IHIP!")
	t.check(not _has(ally, "ihip"), "stunned: bonus gone at once")
	t.steps(host, 70)
	# round-end style cancel and reset
	TestCtx.put(inday, -4, 0)
	_cast(t, host, inday, 0)
	_ihip(inday).end("round_end")
	t.check(not _ihip(inday).active and not _has(ally, "ihip"), "round end cancels it cleanly")
	# tagged
	TestCtx.put(inday, -4, 0)
	_cast(t, host, inday, 0)
	t.check(_ihip(inday).active, "recast before tag")
	inday.on_tagged(enemy)
	t.check(not _ihip(inday).active, "being tagged ends IHIP!")
	t.check(host.world.get_node_or_null("IhipLane") == null and not _has(ally, "ihip"), "tagged: lane and bonus gone the same tick")
	t.ok("IHIP! ends on timeout (240 ticks), S1, push, stun, round end, tag")
	await t.free_match(host)

func _ihip_no_stack(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var ally: Hero = host.heroes[3]
	var inp := t.inputs(host)
	TestCtx.put(inday, -4, 0)
	TestCtx.put(ally, 1, 0)
	ally.add_speed_bonus(0.2, 2.0, "takbo")
	inp.aim_at(inday, Vector3(5, 0, 0))
	_cast(t, host, inday, 0)
	t.check(t.near(ally.biggest_bonus(), 0.25), "IHIP! +25 %% and TAKBO NA! +20 %% do not stack: biggest applies (%.2f)" % ally.biggest_bonus())
	t.check(t.near(ally.current_speed(), 4.85 * 1.25 * Tuning.get_default().move_speed_scale, 0.001), "speed is base x 1.25, not x 1.45")
	t.ok("IHIP! and TAKBO NA! take the biggest bonus")
	await t.free_match(host)

func _hands(host: MatchHost) -> Array:
	var out: Array = []
	for o in host.objects:
		if o is HilaHand and not o.expired:
			out.append(o)
	return out

func _hila_cast(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var inp := t.inputs(host)
	TestCtx.put(inday, -6, 0)
	inp.aim_at(inday, Vector3(5, 0, 0))
	_cast(t, host, inday, 1)
	var s := _hila(inday)
	t.check(s.cd_ticks > 820 and s.cd_ticks <= 840, "HILA! cooldown (14 s = 840 ticks) starts on cast (%d)" % s.cd_ticks)
	t.check(_hands(host).size() == 1 and _count("hila") == 1, "HILA! sends out one hand")
	t.check(inday.can_press_tag(), "HILA! does not stop her tagging")
	var hand: HilaHand = _hands(host)[0]
	t.steps(host, 10)
	var x1 := hand.global_position.x
	t.check(not hand.holding and x1 > -6.0 + 2.5, "the hand flies out along her aim (x %.2f)" % x1)
	t.steps(host, 25)
	t.check(hand.holding and _count("hila_open") == 1, "the hand opens at the end of its reach")
	t.check(t.near(RB.flat_dist(hand.global_position, inday.global_position), 9.0 + host.tuning.body_radius, 0.4), "reach is 9 m (%.2f)" % RB.flat_dist(hand.global_position, inday.global_position))
	t.check(t.near(s.rescue_touch_point().x, hand.global_position.x), "the open hand is HILA!'s rescue touch point")
	t.steps(host, 100)
	t.check(not hand.expired, "the hand stays open for its 2 s")
	t.steps(host, 30)
	t.check(hand.expired and _hands(host).is_empty() and s.rescue_touch_point() == Vector3.INF, "the hand closes after 2 s")
	t.ok("HILA! hand: 9 m reach, holds 2 s, 14 s cooldown")
	await t.free_match(host)

func _hila_pull_ally(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var ally: Hero = host.heroes[3] # tutoy
	var inp := t.inputs(host)
	TestCtx.put(inday, -6, 0)
	TestCtx.put(ally, 0, 0)
	inp.aim_at(inday, Vector3(5, 0, 0))
	_cast(t, host, inday, 1)
	t.steps(host, 40)
	var d := RB.flat_dist(ally.global_position, inday.global_position)
	t.check(_count("hila_pull") == 1, "the hand grabs the teammate it touches")
	t.check(d < 1.4, "the teammate is yanked to Inday (%.2f m left)" % d)
	t.check(_hands(host).is_empty(), "the hand closes after a pull")
	t.check(ally.is_free() and not ally.is_stunned(), "a pulled teammate is not stunned")
	# an enemy in the way is not grabbed
	var enemy: Hero = host.heroes[1]
	TestCtx.put(enemy, 0, 3)
	TestCtx.put(inday, -6, 3)
	inp.aim_at(inday, Vector3(5, 0, 3))
	log_events.clear()
	log_data.clear()
	_cast(t, host, inday, 1)
	t.steps(host, 40)
	t.check(_count("hila_pull") == 0 and RB.flat_dist(enemy.global_position, Vector3(0, 0, 3)) < 0.1, "enemies are not grabbed")
	t.ok("HILA! pulls the first teammate it touches")
	await t.free_match(host)

func _hila_rescue(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var c: Hero = host.heroes[4]
	var d: Hero = host.heroes[5]
	var inp := t.inputs(host)
	var tip := _chain_out(t, host)
	t.check(c.state == Hero.State.CHAINED and d.state == Hero.State.CHAINED, "chain of two walked out (%s)" % str(tip))
	TestCtx.put(inday, tip.x + 6.0, tip.z)
	inp.aim_at(inday, tip)
	log_events.clear()
	log_data.clear()
	_cast(t, host, inday, 1)
	var n := 0
	while n < 40 and d.state == Hero.State.CHAINED:
		t.steps(host, 1)
		n += 1
	t.check(d.state == Hero.State.FREE and c.state == Hero.State.FREE, "the hand touching the tip rescues the whole chain (%d ticks)" % n)
	var ev: Dictionary = {}
	for i in range(log_events.size()):
		if log_events[i] == "rescue":
			ev = log_data[i]
	t.check(ev.get("by_skill", false) == true and ev.get("rescuer") == inday, "the rescue is by Inday's skill")
	t.check(c.ep_ticks >= 295 and d.ep_ticks >= 295, "Inday's freed prisoners get 5 s of EP (got %d)" % d.ep_ticks)
	t.check(_has(c, "takbo") and _has(inday, "takbo"), "TAKBO NA! follows a HILA! rescue")
	t.steps(host, 20)
	t.check(_count("hila_pull") == 1 and RB.flat_dist(d.global_position, inday.global_position) < 2.0, "the freed tip is pulled in to Inday (%.2f m)" % RB.flat_dist(d.global_position, inday.global_position))
	t.ok("HILA! rescues a chain tip it touches, then pulls it in")
	await t.free_match(host)

func _hila_wall(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var d: Hero = host.heroes[5]
	var inp := t.inputs(host)
	var tip := _chain_out(t, host)
	TestCtx.put(inday, tip.x + 6.0, tip.z)
	_wall(host, Vector3(tip.x + 3.0, 1, tip.z), Vector3(0.3, 2, 4))
	inp.aim_at(inday, tip)
	log_events.clear()
	log_data.clear()
	_cast(t, host, inday, 1)
	t.steps(host, 30)
	var hands := _hands(host)
	t.check(hands.size() == 1 and (hands[0] as HilaHand).holding, "a wall stops the hand, which opens there")
	t.check(hands.size() == 1 and (hands[0] as HilaHand).global_position.x > tip.x + 3.0, "the hand stays on Inday's side of the wall")
	t.steps(host, 60)
	t.check(d.state == Hero.State.CHAINED and _count("rescue") == 0, "no rescue through a wall")
	# the hand closes when Inday is tagged
	_cast(t, host, inday, 1)
	t.steps(host, 2)
	inday.on_tagged(host.heroes[0])
	t.steps(host, 1)
	t.check(_hands(host).is_empty(), "the hand closes when Inday is no longer free")
	t.ok("HILA! is stopped by walls and closes when Inday is tagged")
	await t.free_match(host)

func _takbo_touch(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var c: Hero = host.heroes[4]
	var d: Hero = host.heroes[5]
	var tip := _chain_out(t, host)
	TestCtx.put(inday, tip.x + 0.6, tip.z)
	t.steps(host, 1)
	t.check(c.state == Hero.State.FREE and d.state == Hero.State.FREE, "Inday frees the chain by touch as usual")
	t.check(c.ep_ticks == 300 and d.ep_ticks == 300, "touch rescue by Inday also gives 5 s EP (%d)" % c.ep_ticks)
	t.check(_has(c, "takbo") and _has(d, "takbo") and _has(inday, "takbo"), "TAKBO NA! applies after a touch rescue too")
	t.check(t.near(inday.current_speed(), 4.5 * 1.2 * Tuning.get_default().move_speed_scale, 0.001), "Inday runs 4.5 x 1.2 for 2 s (%.3f)" % inday.current_speed())
	var hud: Dictionary = inday.passive.hud_state()
	t.check(hud.on and hud.fill > 0.9, "HUD passive icon shows the boost")
	t.ok("TAKBO NA! after a touch rescue")
	await t.free_match(host)

func _takbo_other_rescuer(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var c: Hero = host.heroes[4]
	var d: Hero = host.heroes[5]
	var other: Hero = host.heroes[3] # tutoy rescues instead
	var tip := _chain_out(t, host)
	TestCtx.put(other, tip.x + 0.6, tip.z)
	t.steps(host, 1)
	t.check(c.state == Hero.State.FREE and d.state == Hero.State.FREE, "Tutoy freed the chain")
	t.check(c.ep_ticks == 240 and d.ep_ticks == 240, "only Inday's rescues give 5 s EP (got %d)" % c.ep_ticks)
	t.check(not _has(c, "takbo") and not _has(inday, "takbo") and not _has(other, "takbo"), "TAKBO NA! only follows Inday's own rescues")
	t.ok("another hero's rescue gives no TAKBO NA! and 4 s EP")
	await t.free_match(host)

extends RefCounted

## Inday's kit against docs/RESBAK.md § 4 Inday: IHIP! (wind lane, +25 % for free allies, stands
## still, walls cut it, ends on recast / tag / push / stun), SAGIP! (4 s ranged rescue from 3 m
## with a clear line) and TAKBO NA! (+20 % for 2 s for her and the freed, +1 s EP, no stacking).
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
	await _sagip_time(t)
	await _sagip_ranged_rescue(t)
	await _sagip_wall(t)
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

func _sagip(h: Hero) -> Skill:
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

## Lila chain of two walked out of the Jail_Dilaw: anchor Nene (slot 4), tip Nathan (slot 5).
## Returns the tip position. Dilaw's Nene (slot 0) is the tagger.
func _chain_out(t: TestCtx, host: MatchHost) -> Vector3:
	var inp := t.inputs(host)
	var tagger: Hero = host.heroes[0]
	var c: Hero = host.heroes[4]
	var d: Hero = host.heroes[5]
	c.on_tagged(tagger)
	d.on_tagged(tagger)
	t.steps(host, 49)
	TestCtx.put(c, -14.0, 7.2)
	inp.press(c, USE)
	t.steps(host, 1)
	TestCtx.put(d, -15.0, 7.2)
	inp.press(d, USE)
	t.steps(host, 1)
	inp.move(d, Vector2(1, 0))
	t.steps(host, 90)
	inp.move(d, Vector2.ZERO)
	t.steps(host, 15)
	return d.global_position

# ---- tests -----------------------------------------------------------------------------
func _data(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	t.check(inday.data.id == "inday" and inday.data.run_speed == 5.0, "Inday runs at 5.0 m/s")
	t.check(inday.skills[0].cooldown == 15.0 and inday.skills[1].cooldown == 12.0, "IHIP! 15 s, SAGIP! 12 s cooldowns")
	t.check(inday.skills[0].kind() == RB.SkillKind.MOVEMENT, "IHIP! is a Movement skill")
	t.check(inday.skills[1].kind() == RB.SkillKind.NEITHER, "SAGIP! is neither Offensive nor Movement")
	t.check(not _sagip(inday).active and _sagip(inday).ranged_rescue_reach() < 0.0, "SAGIP! gives no ranged reach while idle")
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
	_sagip(inday).cd_ticks = 0
	inp.press(inday, S2)
	t.steps(host, 2)
	t.check(not _sagip(inday).active and _sagip(inday).cd_ticks == 0, "can't cast SAGIP! while blowing")
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
	t.check(t.near(ally_in.current_speed(), 5.4 * 1.25, 0.001), "Tutoy runs 5.4 x 1.25 inside the lane (%.3f)" % ally_in.current_speed())
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
	t.check(run_inside > 5.0 * 1.0, "an ally running in the lane covers more than base speed in 1 s (%.2f m)" % run_inside)
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
	t.check(t.near(ally.current_speed(), 5.4 * 1.25, 0.001), "speed is base x 1.25, not x 1.45")
	t.ok("IHIP! and TAKBO NA! take the biggest bonus")
	await t.free_match(host)

func _sagip_time(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	TestCtx.put(inday, -4, 0)
	_cast(t, host, inday, 1)
	var s := _sagip(inday)
	t.check(s.active and t.near(s.ranged_rescue_reach(), 3.0), "SAGIP! active: ranged rescue reach 3 m")
	t.check(s.cd_ticks > 700 and s.cd_ticks <= 720, "SAGIP! cooldown (12 s) starts on cast (%d)" % s.cd_ticks)
	t.check(host.world.get_node_or_null("SagipAura") != null, "aura VFX while active")
	t.check(inday.can_press_tag(), "SAGIP! does not stop her tagging")
	t.steps(host, 239)
	t.check(s.active, "SAGIP! still active after 240 ticks")
	t.steps(host, 1)
	t.check(not s.active and s.ranged_rescue_reach() < 0.0, "SAGIP! ends after 4 s")
	t.check(host.world.get_node_or_null("SagipAura") == null, "aura gone when it ends")
	t.ok("SAGIP! lasts 4 s with a 3 m reach")
	await t.free_match(host)

func _sagip_ranged_rescue(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var c: Hero = host.heroes[4]
	var d: Hero = host.heroes[5]
	var blocker: Hero = host.heroes[1] # a Dilaw player standing on the line
	var tip := _chain_out(t, host)
	t.check(c.state == Hero.State.CHAINED and d.state == Hero.State.CHAINED, "chain of two walked out (%s)" % str(tip))
	# 2.8 m from the tip, clear line, no SAGIP!: nothing happens
	TestCtx.put(inday, tip.x + 2.8, tip.z)
	TestCtx.put(blocker, tip.x + 1.4, tip.z) # players don't block the line
	log_events.clear()
	log_data.clear()
	t.steps(host, 5)
	t.check(d.state == Hero.State.CHAINED and _count("rescue") == 0, "without SAGIP! 2.8 m is too far to rescue")
	_cast(t, host, inday, 1)
	t.check(d.state == Hero.State.FREE and c.state == Hero.State.FREE, "SAGIP! rescues the whole chain from 2.8 m with a clear line, same tick")
	t.check(_count("rescue") == 1, "one rescue event")
	var ev: Dictionary = {}
	for i in range(log_events.size()):
		if log_events[i] == "rescue":
			ev = log_data[i]
	t.check(ev.get("by_skill", false) == true and ev.get("rescuer") == inday, "the rescue is by Inday's skill")
	t.check(c.ep_ticks == 300 and d.ep_ticks == 300, "Inday's freed prisoners get 5 s = 300 ticks of EP (got %d)" % c.ep_ticks)
	t.check(c.lockout_ticks == 240 and d.lockout_ticks == 240, "capture lockout is still 4 s")
	t.check(t.near(c.biggest_bonus(), 0.2) and t.near(d.biggest_bonus(), 0.2), "freed prisoners get TAKBO NA! +20 %")
	t.check(t.near(inday.biggest_bonus(), 0.2), "Inday gets TAKBO NA! +20 %")
	t.check(_sagip(inday).active, "SAGIP! keeps running after the rescue")
	# the bonus is 2 s
	t.steps(host, 118)
	t.check(_has(c, "takbo") and _has(inday, "takbo"), "TAKBO NA! still on late in its 2 s")
	t.steps(host, 2)
	t.check(not _has(c, "takbo") and not _has(d, "takbo") and not _has(inday, "takbo"), "TAKBO NA! over after 2 s (120 ticks)")
	t.check(c.ep_ticks == 180, "EP counts down from 5 s (%d left)" % c.ep_ticks)
	t.ok("SAGIP! ranged rescue with a clear line (players don't block), 5 s EP, TAKBO NA!")
	await t.free_match(host)

func _sagip_wall(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var c: Hero = host.heroes[4]
	var d: Hero = host.heroes[5]
	var tip := _chain_out(t, host)
	TestCtx.put(inday, tip.x + 2.8, tip.z)
	var wall := _wall(host, Vector3(tip.x + 1.4, 1, tip.z), Vector3(0.3, 2, 4))
	_cast(t, host, inday, 1)
	t.steps(host, 20)
	t.check(d.state == Hero.State.CHAINED and c.state == Hero.State.CHAINED, "a wall in the line blocks the SAGIP! rescue")
	t.check(_sagip(inday).active, "SAGIP! is still running while blocked")
	# too far even with a clear line
	wall.free()
	TestCtx.put(inday, tip.x + 3.4, tip.z)
	t.steps(host, 5)
	t.check(d.state == Hero.State.CHAINED, "3.4 m is outside the 3 m reach")
	# step in: clear line, in reach -> freed
	TestCtx.put(inday, tip.x + 2.9, tip.z)
	t.steps(host, 1)
	t.check(d.state == Hero.State.FREE and c.state == Hero.State.FREE, "clear line within 3 m: rescued")
	t.ok("SAGIP! needs a clear line and 3 m")
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
	t.check(t.near(inday.current_speed(), 5.0 * 1.2, 0.001), "Inday runs 5.0 x 1.2 for 2 s (%.3f)" % inday.current_speed())
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

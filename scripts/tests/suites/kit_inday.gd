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
	await _placed_wind(t)
	await _wind_priority(t)
	await _hila_cast(t)
	await _hila_animation_phases(t)
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

func _hands(host: MatchHost) -> Array[HilaHand]:
	var out: Array[HilaHand] = []
	for object in host.objects:
		if object is HilaHand:
			out.append(object)
	return out

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
	t.check(inday.skills[0].cooldown == 24.0 and inday.skills[1].cooldown == 14.0, "IHIP! 24 s, HILA! 14 s cooldowns")
	t.check(inday.skills[0].kind() == RB.SkillKind.MOVEMENT, "IHIP! is a Movement skill")
	t.check(inday.skills[1].kind() == RB.SkillKind.NEITHER, "HILA! is neither Offensive nor Movement")
	t.check(_hila(inday).rescue_touch_point() == Vector3.INF, "HILA! gives no rescue touch while idle")
	t.check(t.near(inday.passive.extra_rescue_protection(), 1.0), "TAKBO NA! gives +1 s of EP")
	t.ok("Inday data: speed, cooldowns, kinds")
	await t.free_match(host)

func _placed_wind(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var ally: Hero = host.heroes[3]
	var enemy: Hero = host.heroes[0]
	var inp := t.inputs(host)
	TestCtx.put(inday, -4, 0)
	TestCtx.put(ally, 2, 2.0)
	TestCtx.put(enemy, 0, 0.7)
	inp.aim_at(inday, Vector3(8, 0, 0))
	_cast(t, host, inday, 0)
	var skill := _ihip(inday)
	var lane: SkillObject = skill.last_lane
	var origin := lane.global_position
	t.check(skill.lane_active() and not skill.active and not skill.controls_movement(), "IHIP places an independent lane")
	t.check(t.near(skill.lane_length(), 12.0) and t.near(lane.width_m, 4.5), "approved 12 m by 4.5 m lane")
	t.check(skill.cd_ticks == RB.ticks(24.0) - 1, "24 s cooldown starts at placement")
	t.check(t.near(ally.biggest_bonus(), 0.4), "teammate receives +40% speed")
	t.check(t.near(enemy.strongest_slow(), 0.25) and t.near(inday.strongest_slow(), 0.25), "enemies and owner receive 25% slow")
	t.check(not inday.can_move() and inday.is_taggable(), "brief casting plant retains tag eligibility")
	inp.move(inday, Vector2(0, -1))
	inp.aim_at(inday, Vector3(-4, 0, 10))
	t.steps(host, 45)
	t.check(inday.global_position.distance_to(origin) > 0.2 and inday.can_press_tag(), "Inday moves and tags after the cast plant")
	t.check(lane.global_position.is_equal_approx(origin) and skill.lane_dir().dot(Vector3.RIGHT) > 0.99, "placed wind never follows owner or later aim")
	TestCtx.put(ally, 2, 2.4)
	t.steps(host, 1)
	t.check(t.near(ally.biggest_bonus(), 0.0), "bonus removed immediately on lane exit")
	TestCtx.put(enemy, 0, 2.4)
	t.steps(host, 1)
	t.check(t.near(enemy.strongest_slow(), 0.0) and not host.tag_system.wind_disadvantaged(enemy), "enemy exit removes slow and priority disadvantage")
	inday.on_tagged(enemy)
	t.steps(host, 1)
	t.check(skill.lane_active(), "placed wind persists after owner is tagged")
	t.steps(host, lane.ticks_left)
	t.check(not skill.lane_active(), "placed wind expires at its five-second lifetime")
	await t.free_match(host)
	# Obstacle clamp uses the fixed cast line.
	host = _live(t)
	inday = _inday(host)
	TestCtx.put(inday, -4, 0)
	_wall(host, Vector3(1, 1, 0), Vector3(0.2, 2, 8))
	t.inputs(host).aim_at(inday, Vector3(8, 0, 0))
	_cast(t, host, inday, 0)
	t.check(_ihip(inday).lane_length() < 5.1 and not _ihip(inday).in_lane(Vector3(2, 0, 0)), "solid wall clips the placed lane")
	await t.free_match(host)
	t.ok("placed wind: tuning, movement, lifetime, membership and wall clamp")

func _land_pair(host: MatchHost, a: Hero, b: Hero, simultaneous := true) -> Array:
	for h in [a, b]:
		h.tag_started_tick = host.tick - RB.ticks(host.tuning.tag_windup)
		h.windup_end_tick = host.tick
		h.strike_reach = h.tag_reach()
	a.lunge_dir = RB.flat(b.global_position - a.global_position).normalized()
	b.lunge_dir = -a.lunge_dir
	a.strike_target_slot = b.slot
	b.strike_target_slot = a.slot
	if not simultaneous:
		b.windup_end_tick += 1
	return host.tag_system.resolve()

func _wind_priority(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	var ally: Hero = host.heroes[3]
	var enemy: Hero = host.heroes[0]
	TestCtx.put(inday, -4, 0)
	t.inputs(host).aim_at(inday, Vector3(8, 0, 0))
	_cast(t, host, inday, 0)
	TestCtx.put(ally, 1, 0)
	TestCtx.put(enemy, 2, 0)
	var results := _land_pair(host, ally, enemy)
	t.check(results.size() == 2 and results[0].type == "outprioritized" and results[1].type == "hit", "unaffected ally wins reciprocal same-tick tag against enemy in lane")
	TestCtx.put(inday, 1, 0)
	TestCtx.put(ally, -9, -10)
	results = _land_pair(host, inday, enemy)
	t.check(results.size() == 2 and results[0].type == "sabay" and results[1].type == "sabay", "two disadvantaged fighters retain Sabay")
	results = _land_pair(host, enemy, inday, false)
	t.check(results.size() == 1 and results[0].type == "hit", "earlier clean hit wins even for a disadvantaged fighter")
	TestCtx.put(inday, -4, -5)
	TestCtx.put(ally, 1, 3)
	TestCtx.put(enemy, 2, 3)
	results = _land_pair(host, ally, enemy)
	t.check(results.size() == 2 and results[0].type == "sabay" and results[1].type == "sabay", "two fighters outside wind retain Sabay")
	await t.free_match(host)
	t.ok("wind priority only breaks an otherwise simultaneous reciprocal tie")

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
	t.check(not inday.can_press_tag(), "HILA briefly plants her during casting")
	var hand: HilaHand = _hands(host)[0]
	t.steps(host, 10)
	var x1 := hand.global_position.x
	t.check(not hand.holding and x1 > -6.0 + 2.5, "the hand flies out along her aim (x %.2f)" % x1)
	t.steps(host, 25)
	t.check(_hands(host).is_empty() and _count("hila_open") == 1, "a missed reach returns immediately at maximum range")
	t.check(s.rescue_touch_point() == Vector3.INF, "return has no gameplay touch point")
	t.check(_count("hila_close") == 1, "miss closes once without a two-second wait")
	t.ok("HILA immediate miss return with normal cooldown")
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
	t.check(hands.is_empty(), "wall contact immediately returns the missed hand")
	t.check(_count("hila_close") == 1, "wall contact closes exactly once")
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

## Extend/hold/retract are presentation only and leave the existing touch/pull timing intact.
func _hila_animation_phases(t: TestCtx) -> void:
	var host := _live(t)
	var inday := _inday(host)
	TestCtx.put(inday, -6, -5)
	t.inputs(host).aim_at(inday, Vector3(10, 0, -5))
	_cast(t, host, inday, 1)
	var hand: HilaHand = _hands(host)[0]
	var visual: HeroVisual = inday.visual
	t.check(visual.hila_pose_active() and visual.is_upper_action("Sagip"), "HILA! uses an upper-body pose with independent locomotion")
	var early := visual.hila_clip_position()
	t.steps(host, 8)
	t.check(visual.hila_clip_position() > early and not hand.holding, "extension advances the arm pose with hand travel")
	inday.velocity = Vector3.RIGHT * 2.0
	visual._update_animation()
	t.check(float(visual.tree.get("parameters/Loco/blend_position")) > 0.0, "Inday's legs keep moving while her hand extends")
	t.check(visual.elastic_arm != null, "HILA deforms Inday's actual weighted arm")
	await t.physics_frames(3)
	t.check(float(visual.elastic_arm.get_meta("target_error", INF)) < 0.05, "rendered skinned hand meets the authoritative reach target")
	hand._close("test")
	t.check(hand.expired and _hila(inday).rescue_touch_point() == Vector3.INF, "retraction immediately disables all gameplay touch points")
	t.check(visual.hila_pose_active() and host.world.get_node_or_null("HilaReturn") == null, "the same skinned hand retracts without a detached duplicate")
	await t.free_match(host)
	t.ok("HILA moving extend and same-arm recovery")

extends RefCounted

## Nathan's kit against docs/RESBAK.md section 4 (Nathan): BUGA!, UBO! UBO!, MAY TIRA PA!.
## 2v2 matches on the grey test arena with manual stepping and scripted input. Slot map in
## _live(): heroes[0] Nathan, [1] Tutoy (ally), [2] Nene and [3] Inday (enemies, Lila).
## Arena facts: base_mode 1 puts the Dilaw pole at (-12, 0) and the Lila pole at (12, 0).

const D := RB.DILAW
const L := RB.LILA
const S1 := RB.BTN_SKILL1
const S2 := RB.BTN_SKILL2
const USE := RB.BTN_INTERACT
const BUGA_SCRIPT := "res://scripts/match/skills/nathan/buga.gd"

var log_events: Array = []
var last: Dictionary = {}

func run(t: TestCtx) -> void:
	await _data(t)
	await _buga_timing(t)
	await _buga_cone(t)
	await _buga_wall(t)
	await _buga_no_capture_cancel(t)
	await _buga_interrupts(t)
	await _ubo_landing(t)
	await _ubo_vision_and_cough(t)
	await _ubo_cough_rules(t)
	await _passive_turn(t)
	await _passive_patch(t)

# ---- helpers ---------------------------------------------------------------------------
func _live(t: TestCtx) -> MatchHost:
	var host := t.make_match([
		{"hero_id": "nathan", "team": D}, {"hero_id": "tutoy", "team": D},
		{"hero_id": "nene", "team": L}, {"hero_id": "inday", "team": L}])
	log_events = []
	last = {}
	host.event.connect(func(kind: String, data: Dictionary):
		log_events.append(kind)
		last[kind] = data)
	t.go_live(host)
	for i in range(host.heroes.size()):
		TestCtx.put(host.heroes[i], -9.0 + 2.0 * i, -10.0)
	return host

func _count(kind: String) -> int:
	return log_events.count(kind)

func _wall(t: TestCtx, host: MatchHost, pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	b.add_child(cs)
	b.position = pos
	host.map_root.add_child(b)
	await t.physics_frames(2)

func _objs_of(host: MatchHost, script: Script) -> Array:
	var out: Array = []
	for o in host.objects:
		if is_instance_valid(o) and not o.expired and o.get_script() == script:
			out.append(o)
	return out

func _cast(t: TestCtx, host: MatchHost, n: Hero, button: int) -> void:
	t.inputs(host).press(n, button)
	t.steps(host, 1)

func _aim(t: TestCtx, host: MatchHost, n: Hero, offset: Vector3) -> void:
	t.inputs(host).aim_at(n, n.global_position + offset)

# ---- data ------------------------------------------------------------------------------
func _data(t: TestCtx) -> void:
	var d := HeroData.load_hero("nathan")
	t.check(d != null and d.id == "nathan", "nathan.tres loads")
	t.check(d.skill1_cooldown == 10.0 and d.skill2_cooldown == 18.0 and d.run_speed == 4.5 and d.tag_reach == 1.2, "Nathan CDs 10 / 18 s, 4.5 m/s, reach 1.2 m")
	t.check(d.v("buga_length") == 5.0 and d.v("buga_width_deg") == 60.0 and d.v("buga_slow") == 0.3 and d.v("buga_slow_time") == 1.5 and d.v("buga_trail_time") == 4.0, "BUGA! numbers")
	t.check(d.v("ubo_range") == 9.0 and d.v("ubo_radius") == 3.5 and d.v("ubo_cloud_time") == 5.0 and d.v("ubo_inside_sight") == 2.0 and d.v("ubo_cough_after") == 1.0, "UBO! UBO! numbers")
	t.check(d.v("tira_turn_deg") == 90.0 and d.v("tira_turn_window") == 0.5 and d.v("tira_patch_radius") == 1.0 and d.v("tira_reveal_time") == 2.0, "MAY TIRA PA! numbers")
	var buga = load(BUGA_SCRIPT)
	var o := Vector3.ZERO
	var east := Vector3(1, 0, 0)
	t.check(buga.in_cone(o, east, Vector3(5, 0, 0), 5.0, 60.0), "cone: 5.0 m straight ahead is in")
	t.check(not buga.in_cone(o, east, Vector3(5.1, 0, 0), 5.0, 60.0), "cone: 5.1 m is out")
	t.check(buga.in_cone(o, east, Vector3(4, 0, 2.3), 5.0, 60.0), "cone: 29.9 deg is in")
	t.check(not buga.in_cone(o, east, Vector3(4, 0, 2.4), 5.0, 60.0), "cone: 31 deg is out")
	t.check(not buga.in_cone(o, east, Vector3(-2, 0, 0), 5.0, 60.0), "cone: behind is out")
	t.ok("Nathan data and the cone test")

# ---- BUGA! -----------------------------------------------------------------------------
func _buga_timing(t: TestCtx) -> void:
	var host := _live(t)
	var n: Hero = host.heroes[0]
	var ally: Hero = host.heroes[1]
	var e1: Hero = host.heroes[2]
	var e2: Hero = host.heroes[3]
	TestCtx.put(n, 0, 0)
	TestCtx.put(e1, 4.9, 0)
	TestCtx.put(e2, 3.0, 1.2) # in the cone, hit too
	TestCtx.put(ally, 2.0, -0.8) # in the cone, but an ally
	_aim(t, host, n, Vector3(5, 0, 0))
	var s: Skill = n.skills[0]
	t.check(s.kind() == RB.SkillKind.OFFENSIVE, "BUGA! is Offensive")
	_cast(t, host, n, S1)
	var cast_tick := host.tick
	t.check(s.active and _count("buga_inhale") == 1, "inhale starts at once, event buga_inhale for enemies to see and hear")
	t.check(s.cd_ticks >= 598 and s.cd_ticks <= 600, "cooldown 10 s = 600 ticks starts on cast (got %d)" % s.cd_ticks)
	t.check(n.ep_ticks == 0, "an Offensive skill ends EP (none here)")
	t.steps(host, 22)
	t.check(host.tick == cast_tick + 22 and e1.strongest_slow() == 0.0 and _count("buga_blow") == 0, "no powder during the 24-tick inhale")
	# Nathan can move while inhaling
	t.inputs(host).move(n, Vector2(0, 1))
	t.steps(host, 1)
	t.inputs(host).move(n, Vector2.ZERO)
	t.check(n.global_position.z > 0.0, "Nathan can move while inhaling")
	TestCtx.put(n, 0, 0)
	t.steps(host, 1)
	t.check(host.tick == cast_tick + 24 and _count("buga_blow") == 1 and not s.active, "the cone blows on tick cast + 24 (0.4 s)")
	var hit_tick := host.tick
	t.check(t.near(e1.strongest_slow(), 0.3, 0.0001) and t.near(e2.strongest_slow(), 0.3, 0.0001), "both enemies in the cone are slowed 30 %")
	t.check(ally.strongest_slow() == 0.0 and not ally.is_revealed_to(D), "the ally is untouched")
	t.check(e1.is_revealed_to(D) and e2.is_revealed_to(D) and not e1.is_revealed_to(L), "hit enemies are revealed to Nathan's team only")
	t.check(host.visibility(n, e1) == 1.0 and _count("buga_hit") == 2, "buga_hit events; Nathan's team sees them")
	t.check(e1.state == Hero.State.FREE and not e1.is_disabled() and e1.windup_end_tick < 0, "no tag, no stun, no stumble")
	t.check(_objs_of(host, PowderTrail).size() == 2, "a powder trail on each hit enemy (visible to all)")
	t.steps(host, 80)
	t.check(e1.strongest_slow() > 0.0, "slow still on at 1.33 s")
	t.steps(host, 15)
	t.check(e1.strongest_slow() == 0.0, "slow gone after 1.5 s")
	t.check(e1.is_revealed_to(D) and _objs_of(host, PowderTrail).size() == 2, "reveal and trail outlast the slow (4 s)")
	t.steps(host, 130)
	t.check(host.tick - hit_tick == 225 and e1.is_revealed_to(D), "still revealed at 3.75 s")
	t.steps(host, 20)
	t.check(not e1.is_revealed_to(D) and _objs_of(host, PowderTrail).is_empty(), "reveal and trail end after 4 s")
	t.ok("BUGA! timing, slow, reveal, trail")
	await t.free_match(host)

func _buga_cone(t: TestCtx) -> void:
	var host := _live(t)
	var n: Hero = host.heroes[0]
	var e1: Hero = host.heroes[2]
	var e2: Hero = host.heroes[3]
	var s: Skill = n.skills[0]
	TestCtx.put(n, 0, 0)
	# in: 29 deg at 4 m, 4.9 m ahead; out: 31 deg, 5.3 m, behind
	var cases := [
		[Vector3(4 * cos(deg_to_rad(29)), 0, 4 * sin(deg_to_rad(29))), true, "29 deg"],
		[Vector3(4 * cos(deg_to_rad(31)), 0, -4 * sin(deg_to_rad(31))), false, "31 deg"],
		[Vector3(4.9, 0, 0), true, "4.9 m"],
		[Vector3(5.3, 0, 0), false, "5.3 m"],
		[Vector3(-3, 0, 0), false, "behind"],
	]
	for c in cases:
		for e in [e1, e2]:
			e.clear_modifier("buga")
			e.revealed_ticks = [0, 0]
		TestCtx.put(e1, c[0].x, c[0].z)
		TestCtx.put(e2, -9, -10)
		s.cd_ticks = 0
		_aim(t, host, n, Vector3(5, 0, 0))
		_cast(t, host, n, S1)
		t.steps(host, 24)
		var hit := e1.strongest_slow() > 0.0
		t.check(hit == c[1], "cone %s: hit = %s" % [c[2], c[1]])
	# aim is read when the powder blows: turn during the inhale
	e1.clear_modifier("buga")
	TestCtx.put(e1, 0, 4)
	s.cd_ticks = 0
	_cast(t, host, n, S1)
	t.steps(host, 10)
	_aim(t, host, n, Vector3(0, 0, 5))
	t.steps(host, 14)
	t.check(e1.strongest_slow() > 0.0, "the cone follows the aim at the moment of the blow")
	t.ok("BUGA! cone 5 m x 60 deg")
	await t.free_match(host)

func _buga_wall(t: TestCtx) -> void:
	var host := _live(t)
	var n: Hero = host.heroes[0]
	var e1: Hero = host.heroes[2]
	var e2: Hero = host.heroes[3]
	await _wall(t, host, Vector3(2, 1, 0), Vector3(0.4, 2, 1.0))
	TestCtx.put(n, 0, 0)
	TestCtx.put(e1, 4, 0) # straight behind the wall
	TestCtx.put(e2, 4, 1.9) # same cone, clear line past the wall's end
	_aim(t, host, n, Vector3(5, 0, 0))
	_cast(t, host, n, S1)
	t.steps(host, 24)
	t.check(e1.strongest_slow() == 0.0 and not e1.is_revealed_to(D), "a wall blocks the powder (no slow, no reveal)")
	t.check(e2.strongest_slow() > 0.0, "an enemy with a clear line past the wall is hit")
	t.ok("BUGA! walls block per target")
	await t.free_match(host)

func _buga_no_capture_cancel(t: TestCtx) -> void:
	var host := _live(t)
	var n: Hero = host.heroes[0]
	var c: Hero = host.heroes[2]
	TestCtx.put(n, -7.5, 0)
	TestCtx.put(c, -10.6, 0) # capturing the Dilaw pole at (-12, 0)
	t.inputs(host).hold(c, USE)
	t.steps(host, 20)
	t.check(c.capturing, "the enemy is capturing")
	_aim(t, host, n, Vector3(-5, 0, 0))
	_cast(t, host, n, S1)
	t.steps(host, 24)
	t.check(c.strongest_slow() > 0.0 and c.capturing, "BUGA! slows a capturer but does not cancel the capture")
	t.steps(host, 10)
	t.check(c.capturing and c.state == Hero.State.FREE, "the capture keeps running")
	t.ok("BUGA! has no capture cancel and no tag")
	await t.free_match(host)

func _buga_interrupts(t: TestCtx) -> void:
	var host := _live(t)
	var n: Hero = host.heroes[0]
	var e1: Hero = host.heroes[2]
	var s: Skill = n.skills[0]
	TestCtx.put(n, 0, 0)
	TestCtx.put(e1, 3, 0)
	_aim(t, host, n, Vector3(5, 0, 0))
	_cast(t, host, n, S1)
	t.steps(host, 5)
	n.on_tagged(e1)
	t.check(not s.active, "being tagged during the inhale cancels it")
	t.steps(host, 30)
	t.check(_count("buga_blow") == 0 and e1.strongest_slow() == 0.0, "no powder after a tag")
	await t.free_match(host)
	# a stun cancels the inhale too
	host = _live(t)
	n = host.heroes[0]
	e1 = host.heroes[2]
	s = n.skills[0]
	TestCtx.put(n, 0, 0)
	TestCtx.put(e1, 3, 0)
	_aim(t, host, n, Vector3(5, 0, 0))
	_cast(t, host, n, S1)
	t.steps(host, 5)
	n.stun(0.5, true)
	t.steps(host, 2)
	t.check(not s.active, "a stun during the inhale cancels it")
	t.steps(host, 40)
	t.check(_count("buga_blow") == 0 and e1.strongest_slow() == 0.0, "no powder after a stun")
	t.ok("BUGA! interrupts")
	await t.free_match(host)

# ---- UBO! UBO! ---------------------------------------------------------------------------
func _ubo_landing(t: TestCtx) -> void:
	var host := _live(t)
	var n: Hero = host.heroes[0]
	var s: Skill = n.skills[1]
	# 1. past range = max range 9 m, lands 0.5 s later
	TestCtx.put(n, 8, -8)
	_aim(t, host, n, Vector3(0, 0, 20))
	_cast(t, host, n, S2)
	var cast_tick := host.tick
	t.check(s.kind() == RB.SkillKind.OFFENSIVE and not s.active, "UBO! UBO! is Offensive and instant")
	t.check(s.cd_ticks >= 1078 and s.cd_ticks <= 1080, "cooldown 18 s = 1080 ticks (got %d)" % s.cd_ticks)
	t.check(_count("ubo_throw") == 1 and last.ubo_throw.flight_ticks == 30, "packet thrown, 30-tick flight")
	t.check(t.near(last.ubo_throw.to.z, 1.0, 0.01), "aim past range lands at the 9 m maximum (z = %.2f)" % last.ubo_throw.to.z)
	t.check(_objs_of(host, UboPacket).size() == 1, "a packet is in the air")
	t.steps(host, 29)
	t.check(host.tick == cast_tick + 29 and _objs_of(host, UboCloud).is_empty(), "still flying at 29 ticks")
	t.steps(host, 1)
	var land_tick := host.tick
	var clouds := _objs_of(host, UboCloud)
	t.check(land_tick == cast_tick + 30 and clouds.size() == 1 and _count("ubo_land") == 1, "the cloud forms 0.5 s (30 ticks) after the throw")
	t.check(_objs_of(host, UboPacket).is_empty(), "the packet is gone")
	var cloud: UboCloud = clouds[0]
	t.check(t.near(cloud.radius, 3.5) and t.near(cloud.global_position.z, 1.0, 0.01) and t.near(cloud.global_position.x, 8.0, 0.01), "cloud r 3.5 m at the landing spot")
	t.steps(host, 296)
	t.check(not cloud.expired, "cloud still there at 4.9 s")
	t.steps(host, 6)
	t.check(cloud.expired and _objs_of(host, UboCloud).is_empty(), "cloud lasts 5 s")
	# 2. aim short = lands at the aim point
	s.cd_ticks = 0
	TestCtx.put(n, 8, -8)
	_aim(t, host, n, Vector3(0, 0, 5))
	_cast(t, host, n, S2)
	t.check(t.near(last.ubo_throw.to.z, -3.0, 0.01), "a 5 m aim lands 5 m away")
	await t.free_match(host)
	# 3. a wall in the path: lands at the wall, sooner
	host = _live(t)
	n = host.heroes[0]
	s = n.skills[1]
	await _wall(t, host, Vector3(0, 1, -4.2), Vector3(6, 2, 0.4))
	TestCtx.put(n, 0, -8)
	_aim(t, host, n, Vector3(0, 0, 20))
	_cast(t, host, n, S2)
	cast_tick = host.tick
	var flight: int = last.ubo_throw.flight_ticks
	t.check(t.near(last.ubo_throw.to.z, -4.7, 0.1), "lands at the first wall, not through it (z = %.2f)" % last.ubo_throw.to.z)
	t.check(flight < 30 and flight > 5, "it lands sooner than 0.5 s (%d ticks)" % flight)
	t.steps(host, flight - 1)
	t.check(_objs_of(host, UboCloud).is_empty(), "no cloud before landing")
	t.steps(host, 1)
	t.check(_objs_of(host, UboCloud).size() == 1, "cloud at the wall on tick cast + %d" % flight)
	t.ok("UBO! UBO! range, flight time, wall landing, 5 s cloud")
	await t.free_match(host)

func _ubo_vision_and_cough(t: TestCtx) -> void:
	var host := _live(t)
	var n: Hero = host.heroes[0]
	var ally: Hero = host.heroes[1]
	var e1: Hero = host.heroes[2]
	var e2: Hero = host.heroes[3]
	var s: Skill = n.skills[1]
	TestCtx.put(n, 0, -8)
	_aim(t, host, n, Vector3(0, 0, 20)) # cloud centre (0, 0, 1)
	_cast(t, host, n, S2)
	t.steps(host, 30)
	var cloud: UboCloud = _objs_of(host, UboCloud)[0]
	var land := host.tick
	TestCtx.put(e1, 0, 1) # inside
	TestCtx.put(e2, 0, 6) # outside (5 m)
	TestCtx.put(ally, 3, 1) # inside, 3 m from e1
	t.steps(host, 1)
	# vision
	t.check(host.visibility(n, e1) == 0.0, "an outside viewer cannot see an enemy whose centre is inside")
	t.check(host.visibility(n, e2) == 1.0, "outside sees outside")
	t.check(host.visibility(e2, ally) == 0.0, "an enemy outside cannot see Nathan's ally inside: both teams are hidden")
	t.check(host.visibility(ally, n) == 1.0 and host.visibility(n, ally) == 1.0, "allies always see each other")
	t.check(host.visibility(e1, ally) == 0.0, "an inside viewer sees only within 2 m (ally at 3 m: hidden)")
	TestCtx.put(ally, 1.5, 1)
	t.steps(host, 1)
	t.check(host.visibility(e1, ally) == 1.0, "an inside viewer sees a target 1.5 m away")
	t.check(host.visibility(e1, n) == 0.0, "an inside viewer does not see an outside enemy 9 m away")
	t.check(cloud.hides(null, Vector3(0, 0, 2.0)) and not cloud.hides(null, Vector3(0, 0, 5.0)), "hides(): inside hidden, outside not")
	t.check(cloud.hides(null, Vector3(3.4, 0, 1.0)) and not cloud.hides(null, Vector3(3.6, 0, 1.0)), "radius 3.5 m on the centre")
	TestCtx.put(ally, 9, -10)
	# cough after 1 continuous second
	var inside := host.tick - land
	t.steps(host, 60 - inside)
	t.check(_count("cough") == 0 and not e1.is_revealed_to(D), "no cough at 1.0 s inside")
	t.steps(host, 3)
	t.check(_count("cough") == 1 and last.cough.hero == e1, "coughs after more than 1 s inside, once")
	t.check(e1.is_revealed_to(D) and not e1.is_revealed_to(L) and host.visibility(n, e1) == 1.0, "shown to Nathan's team through the cloud")
	t.check(e1.revealed_ticks[D] >= 115 and e1.revealed_ticks[D] <= 120, "for 2 s (%d ticks)" % e1.revealed_ticks[D])
	t.check(e1.state == Hero.State.FREE and not e1.is_disabled() and e1.can_use_skills(), "a coughing enemy can still act")
	t.steps(host, 100)
	t.check(_count("cough") == 1, "one cough per cloud, however long the enemy stays")
	t.steps(host, 40)
	t.check(not e1.is_revealed_to(D) and host.visibility(n, e1) == 0.0, "after 2 s the cloud hides it again")
	# a second cloud means a second cough
	s.cd_ticks = 0
	TestCtx.put(n, 0, -8)
	_aim(t, host, n, Vector3(0, 0, 20))
	t.steps(host, 15) # cloud 1 (5 s) is about to end; throw now so the new one overlaps
	_cast(t, host, n, S2)
	t.steps(host, 30 + 55)
	t.check(_count("cough") == 1, "no cough yet in the new cloud (55 ticks)")
	t.steps(host, 10)
	t.check(_count("cough") == 2, "the second cloud makes the enemy cough again")
	t.ok("UBO! UBO! vision rules and cough")
	await t.free_match(host)

func _ubo_cough_rules(t: TestCtx) -> void:
	var host := _live(t)
	var n: Hero = host.heroes[0]
	var e2: Hero = host.heroes[3]
	TestCtx.put(n, 0, -8)
	_aim(t, host, n, Vector3(0, 0, 20))
	_cast(t, host, n, S2)
	t.steps(host, 30)
	# the inside time must be continuous
	TestCtx.put(e2, 1.5, 1)
	t.steps(host, 50)
	TestCtx.put(e2, 1.5, 6)
	t.steps(host, 1)
	TestCtx.put(e2, 1.5, 1)
	t.steps(host, 50)
	t.check(_count("cough") == 0, "leaving resets the continuous timer (50 + 50 ticks, no cough)")
	t.steps(host, 15)
	t.check(_count("cough") == 1 and last.cough.hero == e2, "65 continuous ticks coughs")
	# the cloud lasts its full time even if Nathan is tagged
	var n_tagger: Hero = host.heroes[2]
	n.on_tagged(n_tagger)
	t.check(not _objs_of(host, UboCloud).is_empty(), "tagging Nathan does not remove the cloud")
	t.steps(host, 100)
	t.check(not _objs_of(host, UboCloud).is_empty(), "the cloud keeps its full time")
	t.ok("UBO! UBO! cough timer and cloud persistence")
	await t.free_match(host)
	# a packet already in the air still lands when Nathan is tagged
	host = _live(t)
	n = host.heroes[0]
	TestCtx.put(n, 0, -8)
	_aim(t, host, n, Vector3(0, 0, 20))
	_cast(t, host, n, S2)
	t.steps(host, 5)
	n.on_tagged(host.heroes[2])
	t.steps(host, 26)
	t.check(_objs_of(host, UboCloud).size() == 1, "a packet in flight still lands after Nathan is tagged")
	await t.free_match(host)

# ---- MAY TIRA PA! ----------------------------------------------------------------------------
## Runs one turn scenario on a reset Nathan; returns whether a patch was dropped.
func _turn(t: TestCtx, host: MatchHost, first: Vector2, button: int, gap: int, second: Vector2) -> bool:
	var n: Hero = host.heroes[0]
	var pas = n.passive # untyped: calls has_patch() of MayTiraPa
	pas.on_round_reset()
	host.clear_objects()
	for s in n.skills:
		s.cd_ticks = 0
		s.active = false
	TestCtx.put(n, -4, -4)
	var inp := t.inputs(host)
	inp.move(n, first)
	t.steps(host, 15)
	if button != 0:
		inp.press(n, button)
		t.steps(host, 1)
	t.steps(host, gap)
	inp.move(n, second)
	t.steps(host, 1)
	inp.move(n, Vector2.ZERO)
	return pas.has_patch()

func _passive_turn(t: TestCtx) -> void:
	var host := _live(t)
	var n: Hero = host.heroes[0]
	var pas = n.passive # untyped: calls has_patch() of MayTiraPa
	var inp := t.inputs(host)
	_aim(t, host, n, Vector3(5, 0, 0))
	t.check(pas.hud_state().on == false, "hud: no patch ready at the start")
	t.check(_turn(t, host, Vector2(1, 0), S2, 5, Vector2(-1, 0)), "skill, then a 180 deg turn 5 ticks later drops a patch")
	t.check(t.near(RB.flat_dist(n.global_position, pas.patch.global_position), 0.0, 0.01) and _count("patch_drop") == 1, "the patch is where Nathan turned; patch_drop event")
	var hs: Dictionary = pas.hud_state()
	t.check(hs.on and hs.placed, "hud_state shows the patch ready")
	t.check(_turn(t, host, Vector2(1, 0), S1, 5, Vector2(-1, 0)), "BUGA! arms it too (any skill)")
	t.check(not _turn(t, host, Vector2(1, 0), 0, 5, Vector2(-1, 0)), "no skill, no patch")
	t.check(_turn(t, host, Vector2(1, 0), S2, 29, Vector2(-1, 0)), "a turn exactly 0.5 s after the cast still counts")
	t.check(not _turn(t, host, Vector2(1, 0), S2, 31, Vector2(-1, 0)), "a turn after 0.5 s does not")
	t.check(not _turn(t, host, Vector2(1, 0), S2, 5, Vector2(0, 1)), "a 90 deg turn is not more than 90 deg")
	t.check(_turn(t, host, Vector2(1, 0), S2, 5, Vector2(cos(deg_to_rad(100)), sin(deg_to_rad(100)))), "a 100 deg turn drops a patch")
	t.check(not _turn(t, host, Vector2(1, 0), S2, 5, Vector2(cos(deg_to_rad(80)), sin(deg_to_rad(80)))), "an 80 deg turn does not")
	t.check(not _turn(t, host, Vector2(1, 0), S2, 5, Vector2(1, 0)), "running straight does not")
	# one patch only, the new one replaces the old
	_turn(t, host, Vector2(1, 0), S2, 5, Vector2(-1, 0))
	var first: TiraPatch = pas.patch
	n.skills[0].cd_ticks = 0
	inp.move(n, Vector2(1, 0))
	t.steps(host, 15)
	inp.press(n, S1)
	t.steps(host, 4)
	inp.move(n, Vector2(-1, 0))
	t.steps(host, 1)
	inp.move(n, Vector2.ZERO)
	t.check(pas.has_patch() and pas.patch != first and first.expired, "a new patch replaces the old one")
	t.check(_objs_of(host, TiraPatch).size() == 1, "only one patch exists")
	# hud while armed
	pas.on_round_reset()
	host.clear_objects()
	n.skills[1].cd_ticks = 0
	_cast(t, host, n, S2)
	var armed: Dictionary = pas.hud_state()
	t.check(armed.on and armed.armed and not armed.placed, "hud: armed right after a skill")
	t.steps(host, 40)
	t.check(not pas.hud_state().on, "hud: the window closed")
	pas.on_round_reset()
	t.check(not pas.has_patch() and not pas.hud_state().on, "round reset clears the passive")
	t.ok("MAY TIRA PA! turn rules")
	await t.free_match(host)

func _passive_patch(t: TestCtx) -> void:
	var host := _live(t)
	var n: Hero = host.heroes[0]
	var ally: Hero = host.heroes[1]
	var e1: Hero = host.heroes[2]
	var pas = n.passive # untyped: calls has_patch() of MayTiraPa
	_aim(t, host, n, Vector3(5, 0, 0))
	t.check(_turn(t, host, Vector2(1, 0), S2, 5, Vector2(-1, 0)), "patch dropped")
	var at: Vector3 = pas.patch.global_position
	var patch: TiraPatch = pas.patch
	t.check(t.near(patch.radius, 1.0), "patch radius 1 m")
	# Nathan and his ally walking over it do nothing; the owner already stands in it
	TestCtx.put(ally, at.x + 0.3, at.z)
	t.steps(host, 5)
	t.check(not patch.expired and _count("loud_footstep") == 0, "Nathan and his ally do not set it off")
	TestCtx.put(ally, -9, -10)
	TestCtx.put(n, -9, -7)
	# an enemy just outside the radius does not
	TestCtx.put(e1, at.x + 1.2, at.z)
	t.steps(host, 5)
	t.check(not patch.expired and _count("loud_footstep") == 0, "an enemy centre 1.2 m away does not trigger it")
	t.steps(host, 700)
	t.check(not patch.expired, "the patch lasts until triggered (well past 10 s)")
	# an enemy centre inside does
	TestCtx.put(e1, at.x + 0.9, at.z)
	t.steps(host, 1)
	t.check(patch.expired and not pas.has_patch(), "the first enemy centre inside sets it off and the patch is gone")
	t.check(_count("loud_footstep") == 1 and last.loud_footstep.hero == e1 and _count("patch_trigger") == 1, "puff and a loud footstep event")
	t.check(e1.is_revealed_to(D) and not e1.is_revealed_to(L), "the enemy is shown to Nathan's team")
	t.check(e1.revealed_ticks[D] >= 115 and e1.revealed_ticks[D] <= 120, "for 2 s (%d ticks)" % e1.revealed_ticks[D])
	t.check(e1.strongest_slow() == 0.0 and e1.state == Hero.State.FREE and not e1.is_disabled(), "no slow, no tag, no stumble")
	t.check(not pas.hud_state().on, "hud: patch used")
	t.steps(host, 125)
	t.check(not e1.is_revealed_to(D), "the reveal ends after 2 s")
	t.check(_objs_of(host, TiraPatch).is_empty(), "no patch left")
	t.ok("MAY TIRA PA! patch trigger")
	await t.free_match(host)

extends RefCounted

## Tutoy's kit against docs/RESBAK.md § 4 Tutoy: HARUROT! (S1), LUSOT! (S2, incl. the perfect
## slide), DIRE-DIRETSO (passive). Manual host stepping on the grey arena (TestCtx.make_match),
## exact tick counts. Arena facts: base_mode 1 -> Dilaw pole (-12, 0), Lila pole (12, 0);
## walls inner faces at x = +-20, z = +-12.

const D := RB.DILAW
const L := RB.LILA
const TAG := RB.BTN_TAG
const S1 := RB.BTN_SKILL1
const S2 := RB.BTN_SKILL2

var log_events: Array = []

func run(t: TestCtx) -> void:
	_data(t)
	await _harurot_basics(t)
	await _harurot_trail(t)
	await _harurot_tagging(t)
	await _harurot_modifiers(t)
	await _lusot_basics(t)
	await _lusot_no_tag_after(t)
	await _lusot_obstacles(t)
	await _lusot_vault(t)
	await _lusot_perfect(t)
	await _lusot_perfect_edges(t)
	await _dire_ramp(t)
	await _dire_resets(t)

# ---- helpers ---------------------------------------------------------------------------
## Dilaw: Tutoy + Inday, Lila: Nathan + Nene. Live round, everybody parked on a row at z = -10.
func _live(t: TestCtx) -> MatchHost:
	var lineup: Array = []
	for id in ["tutoy", "inday"]:
		lineup.append({"hero_id": id, "team": D})
	for id in ["nathan", "nene"]:
		lineup.append({"hero_id": id, "team": L})
	var host := t.make_match(lineup)
	log_events = []
	host.event.connect(func(kind: String, _data: Dictionary): log_events.append(kind))
	t.go_live(host)
	for i in range(host.heroes.size()):
		TestCtx.put(host.heroes[i], -9.0 + 2.0 * i, -10.0)
	t.steps(host, 2) # settle on the floor
	return host

## Hero bodies are kinematic: Jolt only moves them to their new place on a real physics step,
## so tests that need hero-vs-hero blocking let a physics frame pass after every host tick.
func _ps(t: TestCtx, host: MatchHost, n: int) -> void:
	for i in range(n):
		host.step()
		await t.physics_frames(1)

func _count(kind: String) -> int:
	return log_events.count(kind)

## Place Tutoy and settle him (no input) so he is standing still on the floor.
func _stand(t: TestCtx, host: MatchHost, x: float, z: float) -> Hero:
	var tu: Hero = host.heroes[0]
	TestCtx.put(tu, x, z)
	t.inputs(host).move(tu, Vector2.ZERO)
	t.steps(host, 3)
	return tu

func _objects_of_trail(host: MatchHost) -> int:
	var n := 0
	for o in host.objects:
		if o is HarurotTrail:
			n += 1
	return n

# ---- data ------------------------------------------------------------------------------
func _data(t: TestCtx) -> void:
	var d := HeroData.load_hero("tutoy")
	t.check(d != null, "tutoy.tres loads")
	if d == null:
		return
	t.check(t.near(d.run_speed, 5.4), "Tutoy runs at 5.4 m/s")
	t.check(t.near(d.tag_reach, 1.0), "Tutoy tag reach is 1.0 m")
	t.check(t.near(d.skill1_cooldown, 8.0) and t.near(d.skill2_cooldown, 6.0), "HARUROT! cooldown 8 s, LUSOT! cooldown 6 s")
	var want := {
		"harurot_speed": 9.0, "harurot_time": 1.2, "harurot_trail_part_time": 2.0,
		"lusot_distance": 4.0, "lusot_time": 0.4, "lusot_no_tag_after": 0.3,
		"lusot_perfect_window": 0.1, "lusot_perfect_stun": 0.6,
		"dire_max_bonus": 0.15, "dire_build_time": 3.0, "dire_sharp_turn_deg": 45.0, "dire_sharp_turn_window": 0.5}
	for k in want:
		t.check(d.values.has(k) and t.near(float(d.values[k]), want[k], 0.0001), "tutoy value %s = %s (got %s)" % [k, want[k], d.values.get(k)])
	t.check(RB.ticks(float(d.values.harurot_time)) == 72 and RB.ticks(float(d.values.lusot_time)) == 24, "HARUROT! 72 ticks, LUSOT! 24 ticks")
	t.check(RB.ticks(float(d.values.lusot_perfect_window)) == 6 and RB.ticks(float(d.values.lusot_no_tag_after)) == 18, "perfect window 6 ticks, no-tag recovery 18 ticks")
	t.ok("tutoy data matches spec § 4")

# ---- HARUROT! --------------------------------------------------------------------------
func _harurot_basics(t: TestCtx) -> void:
	var host := _live(t)
	var tu := _stand(t, host, -15, -6)
	var inp := t.inputs(host)
	var hs: Skill = tu.skills[0]
	t.check(hs.kind() == RB.SkillKind.MOVEMENT, "HARUROT! is a Movement skill")
	inp.move(tu, Vector2(1, 0))
	t.steps(host, 4)
	var x0 := tu.global_position.x
	inp.press(tu, S1)
	t.steps(host, 1)
	t.check(hs.active, "HARUROT! is active after the press")
	t.check(is_equal_approx(hs.fixed_speed(), 9.0), "fixed speed 9 m/s")
	t.steps(host, 3)
	t.check(t.near(tu.ground_speed(), 9.0, 0.05), "9 m/s straight away, no acceleration ramp (got %.2f)" % tu.ground_speed())
	# no turn limit: swing the stick 90 degrees, the very next tick runs the new heading
	inp.move(tu, Vector2(0, 1))
	t.steps(host, 1)
	t.check(tu.velocity.z > 8.9 and absf(tu.velocity.x) < 0.1, "turns 90 deg in one tick, still 9 m/s (v=%s)" % tu.velocity)
	inp.move(tu, Vector2(-1, 0))
	t.steps(host, 1)
	t.check(tu.velocity.x < -8.9 and absf(tu.velocity.z) < 0.1, "turns 90 deg again in one tick")
	inp.move(tu, Vector2.ZERO)
	t.steps(host, 2)
	t.check(t.near(tu.ground_speed(), 9.0, 0.05), "releasing the stick keeps the burst heading at 9 m/s")
	# 72 ticks in total, counting the cast tick: 1 + 3 + 1 + 1 + 2 = 8 steps done so far
	t.steps(host, 63)
	t.check(hs.active, "still active 71 ticks after the cast press")
	t.steps(host, 1)
	t.check(not hs.active, "HARUROT! ends after exactly 72 ticks (1.2 s)")
	await t.free_match(host)

	# straight-line distance 9 m/s x 1.2 s = 10.8 m, and the cooldown
	host = _live(t)
	tu = _stand(t, host, -15, -6)
	hs = tu.skills[0]
	inp = t.inputs(host)
	inp.move(tu, Vector2(1, 0))
	t.steps(host, 4) # reach top speed first
	var start := tu.global_position
	inp.press(tu, S1)
	t.steps(host, 72)
	var run := RB.flat_dist(start, tu.global_position)
	# the 4 steps before the press already ran; the burst itself is 72 ticks of 9 m/s
	t.check(t.near(run, 10.8, 0.15), "HARUROT! covers 10.8 m in 1.2 s (got %.2f)" % run)
	t.check(not hs.active, "inactive after 72 steps")
	inp.move(tu, Vector2.ZERO)
	var n := 0
	while not hs.is_ready() and n < 1000:
		host.step()
		n += 1
	t.check(n + 72 == 480, "HARUROT! cooldown is 8 s = 480 ticks from the cast (ready after %d)" % (n + 72))
	t.check(_count("skill_cast") == 1, "one skill_cast event")
	t.ok("HARUROT! 9 m/s, 72 ticks, no turn limit, 10.8 m, 8 s cooldown")
	await t.free_match(host)

func _harurot_trail(t: TestCtx) -> void:
	var host := _live(t)
	var tu := _stand(t, host, -17, -6)
	var inp := t.inputs(host)
	inp.move(tu, Vector2(1, 0))
	inp.press(tu, S1)
	t.steps(host, 1)
	t.check(_objects_of_trail(host) == 1, "a trail part drops on the cast tick")
	t.steps(host, 71)
	var parts := _objects_of_trail(host)
	t.check(parts == 18, "18 trail parts over the 72-tick burst (every 4 ticks), got %d" % parts)
	var first: HarurotTrail = null
	for o in host.objects:
		if o is HarurotTrail:
			first = o
			break
	t.check(first != null and first.ticks_left <= 120 and first.ticks_left > 40, "trail parts last 2 s = 120 ticks (first has %d left)" % (first.ticks_left if first else -1))
	t.check(first != null and first.team == D and first.owner_hero == tu and not first.hides(host.heroes[2], first.global_position), "the trail is the owner's and hides nobody")
	t.check(first != null and first.global_position.x < tu.global_position.x, "the trail is left behind the runner")
	# visible to everybody: a Lila viewer sees Tutoy normally and the parts exist in the world
	t.check(first != null and first.is_inside_tree() and first.get_child_count() >= 2, "trail meshes are in the world")
	# parts last their full 2 s even though the burst is over; the first one is gone at +120
	t.steps(host, 48)
	t.check(_objects_of_trail(host) > 0, "parts still there 120 ticks after the cast")
	t.steps(host, 5)
	t.check(not is_instance_valid(first) or first.expired, "the first part expired 2 s after it dropped")
	t.steps(host, 72 + 5)
	t.check(_objects_of_trail(host) == 0, "every trail part is gone after 2 s more")
	t.ok("HARUROT! wind trail: 18 parts, 2 s each")
	await t.free_match(host)

func _harurot_tagging(t: TestCtx) -> void:
	# can tag during the burst
	var host := _live(t)
	var tu := _stand(t, host, -6, 0)
	var foe: Hero = host.heroes[2]
	TestCtx.put(foe, -3.0, 0)
	var inp := t.inputs(host)
	inp.move(tu, Vector2(1, 0))
	inp.aim_at(tu, Vector3(5, 0, 0))
	inp.press(tu, S1)
	t.steps(host, 2)
	inp.press(tu, TAG)
	t.steps(host, 10)
	t.check(foe.state == Hero.State.TAGGED, "Tutoy can tag during HARUROT! (foe state %d)" % foe.state)
	await t.free_match(host)
	# and be tagged: the burst ends
	host = _live(t)
	tu = _stand(t, host, -6, 0)
	foe = host.heroes[2]
	TestCtx.put(foe, 0.0, 0)
	inp = t.inputs(host)
	inp.move(tu, Vector2(1, 0))
	inp.aim_at(foe, Vector3(-5, 0, 0))
	inp.press(tu, S1)
	t.steps(host, 21)
	inp.press(foe, TAG)
	t.steps(host, 10) # lands on step 31: Tutoy is about 1.35 m away by then
	t.check(tu.state == Hero.State.TAGGED, "Tutoy can be tagged during HARUROT! (state %d, x %.2f)" % [tu.state, tu.global_position.x])
	t.check(not tu.skills[0].active, "being tagged ends HARUROT!")
	t.ok("HARUROT! can tag and be tagged")
	await t.free_match(host)

func _harurot_modifiers(t: TestCtx) -> void:
	var host := _live(t)
	var tu := _stand(t, host, -19, -6)
	var inp := t.inputs(host)
	inp.move(tu, Vector2(1, 0))
	t.steps(host, 190) # DIRE-DIRETSO at +15 %
	t.check(t.near(tu.passive.speed_bonus(), 0.15, 0.001), "DIRE-DIRETSO is full before the burst")
	inp.press(tu, S1)
	t.steps(host, 5)
	t.check(t.near(tu.ground_speed(), 9.0, 0.05), "HARUROT! is 9 m/s flat, no DIRE-DIRETSO bonus on top (got %.2f)" % tu.ground_speed())
	tu.add_slow(0.3, 1.0, "test_slow", true)
	t.steps(host, 3)
	t.check(t.near(tu.ground_speed(), 6.3, 0.1), "slows still apply to the burst (9 x 0.7 = 6.3, got %.2f)" % tu.ground_speed())
	tu.clear_modifier("test_slow")
	# a stun ends it
	tu.stun(0.2, true)
	t.check(not tu.skills[0].active, "a stun ends HARUROT!")
	await t.free_match(host)
	# round reset clears it and the cooldown
	host = _live(t)
	tu = _stand(t, host, -15, -6)
	t.inputs(host).press(tu, S1)
	t.steps(host, 5)
	tu.reset_for_round(Vector3(-15, 0.05, -6), Vector3.RIGHT)
	t.check(not tu.skills[0].active and tu.skills[0].is_ready(), "round reset ends HARUROT! and clears the cooldown")
	t.ok("HARUROT! fixed speed, slows, stun, reset")
	await t.free_match(host)

# ---- LUSOT! ----------------------------------------------------------------------------
func _lusot_basics(t: TestCtx) -> void:
	var host := _live(t)
	var tu := _stand(t, host, -15, -6)
	var inp := t.inputs(host)
	var ls: Skill = tu.skills[1]
	t.check(ls.kind() == RB.SkillKind.MOVEMENT, "LUSOT! is a Movement skill")
	# standing still: slides along the aim
	inp.aim_at(tu, tu.global_position + Vector3(0, 0, 5)) # +z
	var start := tu.global_position
	inp.press(tu, S2)
	t.steps(host, 1)
	t.check(ls.active, "LUSOT! is active after the press")
	t.steps(host, 5)
	t.check(t.near(RB.flat_dist(start, tu.global_position), 1.0, 0.05), "slides at 10 m/s (1.0 m after 6 ticks, got %.2f)" % RB.flat_dist(start, tu.global_position))
	t.steps(host, 17)
	t.check(ls.active, "still sliding after 23 ticks")
	t.steps(host, 1)
	t.check(not ls.active, "slide over after exactly 24 ticks (0.4 s)")
	var moved := tu.global_position - start
	t.check(t.near(moved.z, 4.0, 0.05) and absf(moved.x) < 0.05, "standing still slides 4 m along the aim (got %s)" % moved)
	# cooldown 6 s = 360 ticks from the cast
	var n := 24
	while not ls.is_ready() and n < 1000:
		host.step()
		n += 1
	t.check(n == 360, "LUSOT! cooldown is 6 s = 360 ticks (ready after %d)" % n)
	await t.free_match(host)

	# moving: slides along the movement, not the aim
	host = _live(t)
	tu = _stand(t, host, -15, -6)
	inp = t.inputs(host)
	ls = tu.skills[1]
	inp.aim_at(tu, Vector3(5, 0, -6)) # aim east
	inp.move(tu, Vector2(0, 1)) # but run +z
	t.steps(host, 4)
	start = tu.global_position
	inp.press(tu, S2)
	t.steps(host, 24)
	moved = tu.global_position - start
	t.check(t.near(moved.z, 4.0, 0.05) and absf(moved.x) < 0.1, "moving: slides 4 m along the movement, not the aim (got %s)" % moved)
	t.check(t.near(ls.distance_done, 4.0, 0.05), "distance_done reports the slide length")
	# diagonal input slides diagonally, still 4 m
	inp.move(tu, Vector2.ZERO)
	t.steps(host, 20)
	TestCtx.put(tu, -17, -9)
	tu.skills[1].cd_ticks = 0
	inp.move(tu, Vector2(1, 1))
	t.steps(host, 3)
	start = tu.global_position
	inp.press(tu, S2)
	t.steps(host, 24)
	t.check(t.near(RB.flat_dist(start, tu.global_position), 4.0, 0.1), "diagonal slide is also 4 m (got %.2f)" % RB.flat_dist(start, tu.global_position))
	t.ok("LUSOT! slide 4 m / 0.4 s, along movement (aim if still), 6 s cooldown")
	await t.free_match(host)

func _lusot_no_tag_after(t: TestCtx) -> void:
	var host := _live(t)
	var tu := _stand(t, host, -15, -6)
	var inp := t.inputs(host)
	var ls: Skill = tu.skills[1]
	inp.aim_at(tu, tu.global_position + Vector3(0, 0, 5))
	inp.press(tu, S2)
	t.steps(host, 5)
	inp.press(tu, TAG)
	t.steps(host, 1)
	t.check(ls.active and not tu.is_winding_up(), "no tagging during the slide")
	t.steps(host, 18) # the slide ends on the 24th tick
	t.check(not ls.active and tu.tag_block_ticks > 0, "slide over, tag block running (%d ticks)" % tu.tag_block_ticks)
	t.check(tu.tag_block_ticks == 18, "tag block is 0.3 s = 18 ticks (got %d)" % tu.tag_block_ticks)
	inp.press(tu, TAG)
	t.steps(host, 1)
	t.check(not tu.is_winding_up(), "no tagging in the first tick after the slide")
	t.steps(host, 16) # presses on ticks +2 ... +17 are blocked too: block ends exactly after 18 ticks
	inp.press(tu, TAG)
	t.steps(host, 1) # this is the 18th tick after the slide
	t.check(not tu.is_winding_up(), "still blocked on the 18th tick after the slide")
	inp.press(tu, TAG)
	t.steps(host, 1)
	t.check(tu.is_winding_up(), "tagging is possible again 19 ticks after the slide ended")
	t.ok("LUSOT!: no tagging during and 0.3 s after")
	await t.free_match(host)

func _lusot_obstacles(t: TestCtx) -> void:
	# stops at a player
	var host := _live(t)
	var tu := _stand(t, host, -10, -6)
	var foe: Hero = host.heroes[2]
	TestCtx.put(foe, -7.0, -6)
	var inp := t.inputs(host)
	inp.aim_at(tu, Vector3(5, 0, -6))
	await _ps(t, host, 1)
	inp.press(tu, S2)
	await _ps(t, host, 24)
	t.check(tu.global_position.x < -7.0 - 0.8 + 0.05, "the slide stops at a player (x=%.2f)" % tu.global_position.x)
	t.check(tu.global_position.x > -7.9, "...right against the player (x=%.2f)" % tu.global_position.x)
	t.check(not tu.skills[1].active, "slide ended")
	t.check(tu.tag_block_ticks > 0, "the 0.3 s no-tag still applies after a blocked slide")
	await t.free_match(host)
	# stops at the wall
	host = _live(t)
	tu = _stand(t, host, -19, -6)
	inp = t.inputs(host)
	inp.aim_at(tu, Vector3(-30, 0, -6))
	inp.press(tu, S2)
	t.steps(host, 24)
	t.check(tu.global_position.x >= -19.65 and tu.global_position.x < -19.4, "the slide stops at the map edge (x=%.2f)" % tu.global_position.x)
	t.check(not tu.skills[1].active, "slide ended at the wall")
	t.ok("LUSOT! stops at players and walls")
	await t.free_match(host)

func _add_prop(host: MatchHost, layer: int, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.position = pos # set before entering the tree: statics sync on entry
	host.get_parent().add_child(body)
	return body

func _lusot_vault(t: TestCtx) -> void:
	# a vaultable crate: running into it stops everyone, sliding passes
	var host := _live(t)
	var tu := _stand(t, host, -10, 2)
	var inp := t.inputs(host)
	_add_prop(host, RB.L_VAULTABLE, Vector3(-7.5, 0.3, 2), Vector3(0.6, 0.6, 2.0))
	inp.move(tu, Vector2(1, 0))
	t.steps(host, 50)
	t.check(tu.global_position.x < -7.8 - 0.35, "a vaultable prop blocks normal running (x=%.2f)" % tu.global_position.x)
	await t.free_match(host)

	host = _live(t)
	tu = _stand(t, host, -10, 2)
	inp = t.inputs(host)
	_add_prop(host, RB.L_VAULTABLE, Vector3(-7.5, 0.3, 2), Vector3(0.6, 0.6, 2.0))
	inp.aim_at(tu, Vector3(5, 0, 2))
	inp.press(tu, S2)
	t.steps(host, 1)
	t.check(tu.skills[1].vaulting, "LUSOT! knows the path holds a vaultable prop (vault clip)")
	t.check(tu.collision_mask & RB.L_VAULTABLE == 0, "the vaultable mask bit is dropped during the slide")
	t.steps(host, 23)
	t.check(t.near(tu.global_position.x, -6.0, 0.06), "LUSOT! vaults the prop and lands 4 m on (x=%.2f)" % tu.global_position.x)
	t.check(tu.collision_mask & RB.L_VAULTABLE != 0, "the vaultable mask bit is back after the slide")
	await t.free_match(host)

	# not vaultable (world layer): the slide stops at it
	host = _live(t)
	tu = _stand(t, host, -10, 2)
	inp = t.inputs(host)
	_add_prop(host, RB.L_WORLD, Vector3(-7.5, 0.3, 2), Vector3(0.6, 0.6, 2.0))
	inp.aim_at(tu, Vector3(5, 0, 2))
	inp.press(tu, S2)
	t.steps(host, 24)
	t.check(tu.global_position.x < -7.8 - 0.35 and not tu.skills[1].vaulting, "a non-vaultable prop stops the slide (x=%.2f)" % tu.global_position.x)
	await t.free_match(host)

	# a slide that would end inside the prop keeps gliding until clear
	host = _live(t)
	tu = _stand(t, host, -10, 2)
	inp = t.inputs(host)
	_add_prop(host, RB.L_VAULTABLE, Vector3(-6.0, 0.3, 2), Vector3(0.8, 0.6, 2.0)) # spans x -6.4 .. -5.6; slide ends at -6
	inp.aim_at(tu, Vector3(5, 0, 2))
	inp.press(tu, S2)
	t.steps(host, 24)
	t.check(tu.skills[1].active, "the slide goes on while its body is inside the prop")
	t.steps(host, 30)
	t.check(not tu.skills[1].active and tu.global_position.x >= -5.6 + 0.4 - 0.02, "...and ends clear of it (x=%.2f)" % tu.global_position.x)
	t.check(tu.collision_mask & RB.L_VAULTABLE != 0, "mask restored")
	t.ok("LUSOT! vaults L_VAULTABLE props, blocked by others")
	await t.free_match(host)

# ---- perfect slide ---------------------------------------------------------------------
## Foe (Lila Nathan) at (1.5, 0) winds up a tag west at Tutoy standing at (0, 0). Tutoy casts
## LUSOT! `k` ticks after the foe's press tick P (the tag lands on tick P + 9).
## dir = Tutoy's slide direction. Returns the host (caller frees it) after the landing tick.
func _perfect_setup(t: TestCtx, k: int, dir: Vector2) -> MatchHost:
	var host := _live(t)
	var tu := _stand(t, host, 0, 0)
	var foe: Hero = host.heroes[2]
	TestCtx.put(foe, 1.5, 0)
	var inp := t.inputs(host)
	inp.aim_at(foe, Vector3(-5, 0, 0))
	inp.aim_at(tu, Vector3(5, 0, 0))
	t.steps(host, 2)
	log_events = []
	await _ps(t, host, 1)
	inp.press(foe, TAG)
	await _ps(t, host, k)
	inp.move(tu, dir)
	inp.press(tu, S2)
	await _ps(t, host, 10 - k)
	return host

func _lusot_perfect(t: TestCtx) -> void:
	# cast 5 ticks before the landing tick (inside the 6-tick window): perfect, sideways
	var host := await _perfect_setup(t, 4, Vector2(0, 1))
	var tu: Hero = host.heroes[0]
	var foe: Hero = host.heroes[2]
	t.check(tu.state == Hero.State.FREE, "perfect slide: Tutoy is not tagged")
	t.check(_count("perfect_slide") == 1 and _count("tag") == 0, "perfect_slide event, no tag event")
	t.check(foe.stun_ticks == 36, "the tagger is stunned 0.6 s = 36 ticks (got %d)" % foe.stun_ticks)
	t.check(foe.state == Hero.State.FREE and host.stats[foe.slot].tags == 0, "a stun is not a tag: the tagger is free and scored nothing")
	t.check(foe.stumble_ticks == 0, "stun replaces the 0.5 s stumble")
	t.check(tu.passive != null and tu.skills[1].cd_ticks > 0, "LUSOT! is on cooldown")
	await t.free_match(host)

	# cast on the landing tick itself: still perfect
	host = await _perfect_setup(t, 9, Vector2(0, 1))
	tu = host.heroes[0]
	foe = host.heroes[2]
	t.check(tu.state == Hero.State.FREE and foe.stun_ticks == 36 and _count("perfect_slide") == 1, "casting on the landing tick is still perfect (stun %d)" % foe.stun_ticks)
	await t.free_match(host)

	# cast 6 ticks before the landing: outside the window, tag checked against the new position
	host = await _perfect_setup(t, 3, Vector2(0, 1))
	tu = host.heroes[0]
	foe = host.heroes[2]
	t.check(_count("perfect_slide") == 0, "cast 6 ticks before the landing is not a perfect slide")
	t.check(tu.state == Hero.State.TAGGED, "...and the tag still hits the slid-to position (Tutoy state %d, z=%.2f)" % [tu.state, tu.global_position.z])
	await t.free_match(host)

	# slide passes through the tagger
	host = await _perfect_setup(t, 4, Vector2(1, 0))
	tu = host.heroes[0]
	foe = host.heroes[2]
	t.check(_count("perfect_slide") == 1 and foe.stun_ticks == 36, "perfect slide through the tagger")
	await _ps(t, host, 20) # let the 24-tick slide finish
	t.check(tu.global_position.x > 3.8, "the perfect slide passes through the tagger (x=%.2f)" % tu.global_position.x)
	t.steps(host, 18)
	t.check(tu.get_collision_exceptions().is_empty(), "the pass-through is removed once the slide is over")
	await t.free_match(host)

	# a slide away from the same situation but outside the window: normal slide, tag whiffs
	host = await _perfect_setup(t, 3, Vector2(-1, 0))
	tu = host.heroes[0]
	foe = host.heroes[2]
	t.check(tu.state == Hero.State.FREE and _count("perfect_slide") == 0, "a late slide away just dodges normally")
	t.check(foe.stumble_ticks == 30 and foe.stun_ticks == 0, "...the tagger gets the ordinary 0.5 s stumble, not the stun (stumble %d)" % foe.stumble_ticks)
	t.ok("perfect slide: inside the 6-tick window incl. the landing tick, stun 0.6 s, passes through, else a normal slide")
	await t.free_match(host)

func _lusot_perfect_edges(t: TestCtx) -> void:
	# the tag would not have hit Tutoy at the slide start (out of reach): no perfect
	var host := _live(t)
	var tu := _stand(t, host, 0, 0)
	var foe: Hero = host.heroes[2]
	TestCtx.put(foe, 3.5, 0) # 2.7 m edge to edge
	var inp := t.inputs(host)
	inp.aim_at(foe, Vector3(-5, 0, 0))
	inp.aim_at(tu, Vector3(0, 0, 5))
	t.steps(host, 2)
	log_events = []
	inp.press(foe, TAG)
	t.steps(host, 4)
	inp.press(tu, S2)
	t.steps(host, 6)
	t.check(_count("perfect_slide") == 0 and foe.stun_ticks == 0, "no perfect dodge of a tag that would not have reached")
	t.check(foe.stumble_ticks == 30, "that tag is an ordinary failed tag")
	await t.free_match(host)

	# an ally's tag press is not an enemy tag
	host = _live(t)
	tu = _stand(t, host, 0, 0)
	var ally: Hero = host.heroes[1]
	TestCtx.put(ally, 1.5, 0)
	inp = t.inputs(host)
	inp.aim_at(ally, Vector3(-5, 0, 0))
	inp.press(ally, TAG)
	t.steps(host, 4)
	inp.aim_at(tu, Vector3(0, 0, 5))
	inp.press(tu, S2)
	t.steps(host, 6)
	t.check(_count("perfect_slide") == 0, "an ally's wind-up never counts as a perfect dodge")
	await t.free_match(host)

	# two enemies whose tags would both have hit: both stunned
	host = _live(t)
	tu = _stand(t, host, 0, 0)
	var f1: Hero = host.heroes[2]
	var f2: Hero = host.heroes[3]
	TestCtx.put(f1, 1.5, 0)
	TestCtx.put(f2, 1.5, -1.2)
	inp = t.inputs(host)
	inp.aim_at(f1, Vector3(-5, 0, 0))
	inp.aim_at(f2, Vector3(0, 0, 0))
	inp.aim_at(tu, Vector3(0, 0, 5))
	t.steps(host, 2)
	log_events = []
	inp.press(f1, TAG)
	inp.press(f2, TAG)
	t.steps(host, 5)
	inp.press(tu, S2)
	t.steps(host, 5)
	t.check(tu.state == Hero.State.FREE and f1.stun_ticks == 36 and f2.stun_ticks == 36, "each enemy whose tag would have hit is stunned 0.6 s (%d, %d)" % [f1.stun_ticks, f2.stun_ticks])
	t.check(_count("perfect_slide") == 2, "one perfect_slide event per tagger")
	t.ok("perfect slide edge cases: out of reach, ally, two taggers")
	await t.free_match(host)

# ---- DIRE-DIRETSO ----------------------------------------------------------------------
func _bonus(tu: Hero) -> float:
	return tu.passive.speed_bonus()

func _dire_ramp(t: TestCtx) -> void:
	var host := _live(t)
	var tu := _stand(t, host, -19.4, -6)
	var inp := t.inputs(host)
	t.check(is_zero_approx(_bonus(tu)) and tu.passive.hud_state().on == false, "no bonus while standing")
	inp.move(tu, Vector2(1, 0))
	t.steps(host, 90)
	t.check(t.near(_bonus(tu), 0.075, 0.002), "halfway (1.5 s) = +7.5 %% (got %.4f)" % _bonus(tu))
	var hud: Dictionary = tu.passive.hud_state()
	t.check(t.near(hud.fill, 0.5, 0.02) and hud.on, "HUD fill is 0.5 halfway (got %.3f)" % hud.fill)
	t.steps(host, 90)
	t.check(t.near(_bonus(tu), 0.15, 0.0005), "full +15 %% after 3 s = 180 ticks (got %.4f)" % _bonus(tu))
	t.check(t.near(tu.passive.hud_state().fill, 1.0, 0.01), "HUD fill is 1.0 at full")
	t.check(t.near(tu.current_speed(), 5.4 * 1.15, 0.01), "current speed is 5.4 x 1.15 = 6.21 (got %.3f)" % tu.current_speed())
	t.steps(host, 60)
	t.check(t.near(tu.ground_speed(), 6.21, 0.05), "actually runs at 6.21 m/s (got %.2f)" % tu.ground_speed())
	t.check(t.near(_bonus(tu), 0.15, 0.0005), "the bonus holds at +15 %")
	# it rose evenly: sample the middle of a fresh ramp
	inp.move(tu, Vector2.ZERO)
	t.steps(host, 2)
	t.check(is_zero_approx(_bonus(tu)), "stopping resets it")
	t.check(not tu.passive.hud_state().on, "HUD off after reset")
	await t.free_match(host)

	# a 40 degree turn is not sharp; a 90 degree turn is
	host = _live(t)
	tu = _stand(t, host, -19.4, -6)
	inp = t.inputs(host)
	inp.move(tu, Vector2(1, 0))
	t.steps(host, 60)
	var before := _bonus(tu)
	inp.move(tu, Vector2(cos(deg_to_rad(40)), sin(deg_to_rad(40))))
	t.steps(host, 5)
	t.check(_bonus(tu) > before, "a 40 deg turn is not sharp: bonus keeps rising (%.4f -> %.4f)" % [before, _bonus(tu)])
	inp.move(tu, Vector2(1, 0))
	t.steps(host, 5)
	t.check(_bonus(tu) > before, "turning back 40 deg inside the same 0.5 s is still under 45 deg")
	inp.move(tu, Vector2(0, 1))
	t.steps(host, 1)
	t.check(_bonus(tu) < 0.01, "a 90 deg turn resets it at once (got %.4f)" % _bonus(tu))
	t.steps(host, 30)
	t.check(_bonus(tu) > 0.02 and _bonus(tu) < 0.04, "...then it climbs again from zero (got %.4f after 30 ticks)" % _bonus(tu))
	await t.free_match(host)

	# a slow curve adding up to more than 45 deg inside 0.5 s is a sharp turn too
	host = _live(t)
	tu = _stand(t, host, -19.4, -6)
	inp = t.inputs(host)
	inp.move(tu, Vector2(1, 0))
	t.steps(host, 60)
	var worst := _bonus(tu)
	var reset_seen := false
	for i in range(1, 31):
		var a := deg_to_rad(4.0 * i) # 4 deg per tick: 120 deg total
		inp.move(tu, Vector2(cos(a), sin(a)))
		host.step()
		if _bonus(tu) < worst * 0.5:
			reset_seen = true
			break
		worst = maxf(worst, _bonus(tu))
	t.check(reset_seen, "a curve of more than 45 deg inside 0.5 s resets the bonus")
	t.ok("DIRE-DIRETSO: 0 -> +15 % over 3 s, holds, resets on stop and on sharp turns")
	await t.free_match(host)

func _dire_resets(t: TestCtx) -> void:
	var host := _live(t)
	var tu := _stand(t, host, -19.4, -6)
	var inp := t.inputs(host)
	var foe: Hero = host.heroes[2]
	inp.move(tu, Vector2(1, 0))
	t.steps(host, 100)
	var b := _bonus(tu)
	t.check(b > 0.08, "built up some bonus (%.4f)" % b)
	# terrain / hazard effects do not reset it
	tu.add_slow(0.3, 0.5, "mud", false)
	t.steps(host, 1)
	t.check(_bonus(tu) > b, "a terrain slow does not reset it")
	tu.apply_push(Vector3.LEFT, 0.5, false)
	t.steps(host, 1)
	t.check(_bonus(tu) > b, "a hazard push does not reset it")
	tu.passive.on_stunned(false)
	t.check(_bonus(tu) > b, "a hazard stun does not reset it")
	t.steps(host, 20)
	b = _bonus(tu)
	# an enemy skill slow resets it
	tu.add_slow(0.3, 0.5, "buga_test", true)
	t.check(is_zero_approx(_bonus(tu)), "a slow by an enemy skill resets it")
	t.steps(host, 40)
	b = _bonus(tu)
	t.check(b > 0.03, "builds again (%.4f)" % b)
	# enemy push
	tu.apply_push(Vector3.LEFT, 0.5, true)
	t.check(is_zero_approx(_bonus(tu)), "a push by an enemy skill resets it")
	t.steps(host, 40)
	# enemy stun hook
	t.check(_bonus(tu) > 0.0, "builds again after the push")
	tu.passive.on_stunned(true)
	t.check(is_zero_approx(_bonus(tu)), "a stun by an enemy skill resets it")
	# tag press
	t.steps(host, 40)
	t.check(_bonus(tu) > 0.0, "builds again after the stun hook")
	inp.press(tu, TAG)
	t.steps(host, 1)
	t.check(is_zero_approx(_bonus(tu)) or _bonus(tu) < 0.002, "pressing Tag resets it (got %.4f)" % _bonus(tu))
	# capture start
	t.steps(host, 60)
	t.check(_bonus(tu) > 0.0, "builds again after tagging")
	tu.notify_capture_start()
	t.check(is_zero_approx(_bonus(tu)), "starting a capture resets it")
	await t.free_match(host)

	# running into a wall is a stop; Tagged resets
	host = _live(t)
	tu = _stand(t, host, -17.0, -6)
	inp = t.inputs(host)
	inp.move(tu, Vector2(-1, 0))
	t.steps(host, 40)
	t.check(is_zero_approx(_bonus(tu)), "pressing into a wall is not moving: no bonus")
	await t.free_match(host)

	# during HARUROT! it keeps counting but the burst speed is fixed
	host = _live(t)
	tu = _stand(t, host, -19.4, -6)
	inp = t.inputs(host)
	inp.move(tu, Vector2(1, 0))
	t.steps(host, 30)
	inp.press(tu, S1)
	t.steps(host, 30)
	t.check(_bonus(tu) > 0.049, "DIRE-DIRETSO keeps building through HARUROT! (%.4f)" % _bonus(tu))
	t.ok("DIRE-DIRETSO resets: enemy slow / push / stun, Tag press, capture start, stop; not terrain")
	await t.free_match(host)

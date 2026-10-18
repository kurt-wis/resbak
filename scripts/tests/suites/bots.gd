extends RefCounted

## Bots (docs/RESBAK.md § 11): roles, perception and reaction, tagging, retreat, the jail chain,
## rescues, the Mahirap Pain rule, a skill, and a full 5v5 bot-only match on the grey arena.
## Positions: Dilaw pole (-12, 0), Lila pole (12, 0); Jail_Dilaw (-16.6, 7.2) holds Lila,
## Jail_Lila (16.6, -7.2) holds Dilaw (see TestCtx.build_arena).

func run(t: TestCtx) -> void:
	await _roles(t)
	await _perception(t)
	await _hunts_stationary(t)
	await _bantay_tags(t)
	await _retreat(t)
	await _chain(t)
	await _rescue(t)
	await _pain_rule(t)
	await _skill_use(t)
	await _full_match(t)

# ---- helpers ----------------------------------------------------------------------------------
func _entry(id: String, team: int) -> Dictionary:
	return {"hero_id": id, "team": team}

## Replace the scripted input of the given slots (null = all) with BotBrains.
func _install(host: MatchHost, slots: Variant, diff: int) -> Dictionary:
	var out := {}
	for h in host.heroes:
		if slots != null and not (h.slot in slots):
			continue
		var b := BotBrain.new()
		host.get_parent().add_child(b)
		b.setup(h, host, diff)
		host.input_sources[h.slot] = b
		out[h.slot] = b
	return out

func _watch(host: MatchHost) -> Array:
	var events: Array = []
	host.event.connect(func(kind: String, d: Dictionary): events.append({"kind": kind, "data": d}))
	return events

func _count(events: Array, kind: String) -> int:
	var n := 0
	for e in events:
		if e.kind == kind:
			n += 1
	return n

# ---- roles ---------------------------------------------------------------------------------------
func _roles(t: TestCtx) -> void:
	var R := BotCoord.Role
	var lineup: Array = []
	for id in ["tutoy", "nene", "nathan", "jm", "inday"]:
		lineup.append(_entry(id, RB.DILAW))
	lineup.append(_entry("nene", RB.LILA))
	var host := t.make_match(lineup)
	var pos := [Vector2(-9, 0), Vector2(-5, 3), Vector2(-4, -3), Vector2(8, -6), Vector2(-6, 6)]
	for i in range(5):
		TestCtx.put(host.heroes[i], pos[i].x, pos[i].y)
	TestCtx.put(host.heroes[5], 18, 11)
	var brains := _install(host, [0, 1, 2, 3, 4], 1)
	t.go_live(host)
	t.steps(host, 1)
	var roles := BotCoord.of(host).roles
	t.check(roles[0] == R.BANTAY, "the bot nearest its own base is Bantay (got %s)" % BotCoord.ROLE_NAMES[roles[0]])
	var rest := [roles[1], roles[2], roles[3], roles[4]]
	t.check(rest == [R.ATAKE, R.PAIN, R.ATAKE, R.PAIN], "the rest alternate Atake, Pain, Atake first (got %s)" % str(rest))
	t.check((brains[0] as BotBrain).role == R.BANTAY and (brains[1] as BotBrain).role == R.ATAKE, "each brain reports its role")
	# a jailed teammate: nearest-to-enemy-jail bot becomes Resbak, the jailed one is Kapit
	host.heroes[4].on_tagged(host.heroes[5])
	t.steps(host, 70)
	t.check(host.heroes[4].is_jailed_like(), "the tagged bot is jailed")
	t.check((brains[4] as BotBrain).role == R.KAPIT, "a jailed bot is Kapit")
	t.check(roles[3] == R.RESBAK, "the free bot nearest the enemy jail is Resbak (got %s)" % BotCoord.ROLE_NAMES[roles[3]])
	t.check(roles[0] == R.BANTAY, "Bantay stays the bot nearest its base")
	t.check([roles[1], roles[2]] == [R.ATAKE, R.PAIN], "the remaining bots alternate Atake, Pain (got %s)" % str([roles[1], roles[2]]))
	t.ok("roles: Bantay / Resbak / Kapit / Atake-Pain alternation")
	await t.free_match(host)

# ---- perception ------------------------------------------------------------------------------------
func _perception(t: TestCtx) -> void:
	var host := t.make_match([_entry("jm", RB.DILAW), _entry("nene", RB.LILA)])
	TestCtx.put(host.heroes[0], -2, 0)
	TestCtx.put(host.heroes[1], 6, 0)
	var brains := _install(host, [0], 1)
	var brain: BotBrain = brains[0]
	t.go_live(host)
	var n := 0
	while n < 80 and not (host.heroes[1] in brain.perceived):
		t.steps(host, 1)
		n += 1
	var react := RB.ticks(host.tuning.bot_reaction[1])
	t.check(absi(n - react) <= 1, "a newly seen enemy registers after the reaction time (%d ticks, wanted %d)" % [n, react])
	await t.free_match(host)

	host = t.make_match([_entry("jm", RB.DILAW), _entry("nene", RB.LILA)])
	TestCtx.put(host.heroes[0], -2, 0)
	TestCtx.put(host.heroes[1], 6, 0)
	host.heroes[1].enemy_alpha = 0.25 # see-through: visibility 0.25 < 0.5
	brain = _install(host, [0], 1)[0]
	t.go_live(host)
	t.steps(host, 150) # long enough for the bot to settle on its guard spot
	t.check(not (host.heroes[1] in brain.perceived), "a see-through enemy 8 m away is not seen")
	TestCtx.put(host.heroes[1], host.heroes[0].global_position.x + 2.0, host.heroes[0].global_position.z)
	t.steps(host, 40)
	t.check(host.heroes[1] in brain.perceived, "an unseen enemy within 2.5 m is noticed")
	t.ok("perception: reaction delay and the visibility rule")
	await t.free_match(host)

# ---- tagging ---------------------------------------------------------------------------------------
func _hunts_stationary(t: TestCtx) -> void:
	var host := t.make_match([_entry("tutoy", RB.DILAW), _entry("tutoy", RB.DILAW), _entry("nene", RB.LILA)])
	TestCtx.put(host.heroes[0], -9, 0)
	TestCtx.put(host.heroes[1], -5, 3)
	TestCtx.put(host.heroes[2], 0, 1)
	var events := _watch(host)
	_install(host, [0, 1], 1)
	t.go_live(host)
	var n := 0
	while n < 900 and host.heroes[2].is_free():
		t.steps(host, 1)
		n += 1
	t.check(not host.heroes[2].is_free(), "bots tag a stationary enemy (%d ticks)" % n)
	var tagged_by_bot := false
	for e in events:
		if e.kind == "tag" and e.data.target == host.heroes[2] and e.data.tagger.slot in [0, 1]:
			tagged_by_bot = true
	t.check(tagged_by_bot, "the tag event names a bot as the tagger")
	t.ok("an Atake bot hunts a stationary blocker and tags it in %d ticks" % n)
	await t.free_match(host)

func _bantay_tags(t: TestCtx) -> void:
	var host := t.make_match([_entry("inday", RB.DILAW), _entry("nathan", RB.LILA)])
	TestCtx.put(host.heroes[0], -9, 0)
	TestCtx.put(host.heroes[1], -6.5, 4)
	var brain: BotBrain = _install(host, [0], 1)[0]
	t.go_live(host)
	t.steps(host, 3)
	t.check(brain.role == BotCoord.Role.BANTAY, "a lone free bot guards its base")
	var n := 0
	while n < 600 and host.heroes[1].is_free():
		t.steps(host, 1)
		n += 1
	t.check(not host.heroes[1].is_free(), "Bantay tags an attacker near its pole (%d ticks)" % n)
	t.ok("Bantay tags an attacker within 8 m of its pole")
	await t.free_match(host)

# ---- retreat ---------------------------------------------------------------------------------------
func _retreat(t: TestCtx) -> void:
	# JM (4.15 m/s, 1.2 reach) against a standing Tutoy (4.85 m/s, 1.0): the Tutoy lands first,
	# there is no skill to use (Tradisyonal), Mahirap never ignores the rule -> back away.
	var host := t.make_match([_entry("jm", RB.DILAW), _entry("tutoy", RB.LILA)], {"skills": false, "difficulty": 2})
	TestCtx.put(host.heroes[0], -5, 0)
	TestCtx.put(host.heroes[1], -0.5, 0) # within 6 m even after JM's first steps home (v0.2 speeds)
	var brain: BotBrain = _install(host, [0], 2)[0]
	for k in range(30): # real navmesh, not the unsynced always-walkable fallback
		if brain.nav.synced():
			break
		await t.tree.physics_frame
	t.check(brain.nav.synced() and brain.nav.walkable(Vector3(-8, 0, 0)), "the bot navmesh syncs with its region (queries no longer answer the origin)")
	t.go_live(host)
	var retreated := false
	for i in range(60):
		t.steps(host, 1)
		retreated = retreated or brain.mode == "retreat"
	var gap := RB.flat_dist(host.heroes[0].global_position, host.heroes[1].global_position)
	t.check(retreated, "a bot with no skill ready backs off from a free enemy within 6 m that lands first")
	t.check(gap > 6.5, "the retreat opens the gap (%.2f m)" % gap)
	await t.free_match(host)

	# the enemy is stumbling: this bot's tag lands first, so it does not retreat
	host = t.make_match([_entry("jm", RB.DILAW), _entry("tutoy", RB.LILA)], {"skills": false, "difficulty": 2})
	TestCtx.put(host.heroes[0], -5, 0)
	TestCtx.put(host.heroes[1], 0.2, 0)
	brain = _install(host, [0], 2)[0]
	t.go_live(host)
	host.heroes[1].stumble(2.0)
	retreated = false
	for i in range(40):
		t.steps(host, 1)
		retreated = retreated or brain.mode == "retreat"
	t.check(not retreated, "no retreat when its own tag lands first")
	await t.free_match(host)

	# a ready skill keeps the bot in the fight
	host = t.make_match([_entry("jm", RB.DILAW), _entry("tutoy", RB.LILA)], {"difficulty": 2})
	TestCtx.put(host.heroes[0], -5, 0)
	TestCtx.put(host.heroes[1], 0.2, 0)
	brain = _install(host, [0], 2)[0]
	t.go_live(host)
	retreated = false
	for i in range(30):
		t.steps(host, 1)
		retreated = retreated or brain.mode == "retreat"
	t.check(not retreated, "a bot with a skill ready does not retreat")
	t.ok("retreat rule: backs off, unless its tag lands first or a skill is ready")
	await t.free_match(host)

# ---- jail chain and rescue -------------------------------------------------------------------------
func _chain(t: TestCtx) -> void:
	var lineup: Array = [_entry("tutoy", RB.DILAW)]
	for i in range(4):
		lineup.append(_entry("nene", RB.LILA))
	var host := t.make_match(lineup)
	TestCtx.put(host.heroes[0], -18, -10)
	TestCtx.put(host.heroes[4], 18, 10)
	_install(host, [host.heroes[1].slot, host.heroes[2].slot, host.heroes[3].slot], 1)
	t.go_live(host)
	for i in [1, 2, 3]:
		host.heroes[i].on_tagged(host.heroes[0])
	t.steps(host, 600)
	var chain: Array = host.jail_system.chain(RB.DILAW)
	t.check(chain.size() == 3, "jailed bots form a chain of three (got %d)" % chain.size())
	var all_chained := true
	for i in [1, 2, 3]:
		all_chained = all_chained and host.heroes[i].state == Hero.State.CHAINED
	t.check(all_chained, "every jailed bot ends up chained")
	if chain.size() == 3:
		var post := host.jail_system.post(RB.DILAW)
		var tip: Hero = chain[-1]
		t.check(tip.global_position.x > post.x + 3.0, "the tip stretches toward the nearest free teammate (tip x %.2f, post x %.2f)" % [tip.global_position.x, post.x])
	t.ok("Kapit: jailed bots chain up and the tip steers")
	await t.free_match(host)

func _rescue(t: TestCtx) -> void:
	var lineup: Array = [_entry("tutoy", RB.DILAW)]
	for i in range(3):
		lineup.append(_entry("nene", RB.LILA))
	var host := t.make_match(lineup)
	TestCtx.put(host.heroes[0], -5, -9)
	TestCtx.put(host.heroes[3], 0, 0)
	var events := _watch(host)
	var brains := _install(host, [host.heroes[1].slot, host.heroes[2].slot, host.heroes[3].slot], 1)
	t.go_live(host)
	host.heroes[1].on_tagged(host.heroes[0])
	host.heroes[2].on_tagged(host.heroes[0])
	var n := 0
	while n < 1800 and _count(events, "rescue") == 0:
		t.steps(host, 1)
		n += 1
	t.check((brains[host.heroes[3].slot] as BotBrain).role == BotCoord.Role.RESBAK, "the free teammate is Resbak")
	var rescuer_ok := false
	for e in events:
		if e.kind == "rescue" and e.data.rescuer == host.heroes[3] and e.data.freed.size() == 2:
			rescuer_ok = true
	t.check(rescuer_ok, "a Resbak bot rescues the whole chain (%d ticks)" % n)
	t.check(host.heroes[1].is_free() and host.heroes[2].is_free(), "the rescued bots are free again")
	t.ok("Resbak runs to the chain tip and rescues in %d ticks" % n)
	await t.free_match(host)

# ---- difficulty rule: Pain only with a teammate near the enemy base on Mahirap ---------------------
func _pain_rule(t: TestCtx) -> void:
	var lila_pole := Vector3(12, 0, 0)
	for diff in [2, 1]:
		var lineup: Array = [_entry("tutoy", RB.DILAW), _entry("nene", RB.DILAW), _entry("nathan", RB.DILAW), _entry("jm", RB.LILA)]
		var host := t.make_match(lineup, {"difficulty": diff})
		TestCtx.put(host.heroes[0], -9, 0)
		TestCtx.put(host.heroes[1], -6, 4)
		TestCtx.put(host.heroes[2], -6, -4)
		TestCtx.put(host.heroes[3], 18, 11)
		var brains := _install(host, [0, 1, 2], diff)
		t.go_live(host)
		t.steps(host, 2)
		var pain: BotBrain = brains[2]
		t.check(pain.role == BotCoord.Role.PAIN, "slot 2 is Pain")
		var d := RB.flat_dist(pain._goal, lila_pole)
		if diff == 2:
			t.check(d < 2.0, "Mahirap Pain with no teammate near the enemy base acts as Atake (goal %.1f m from the pole)" % d)
		else:
			t.check(absf(d - 10.0) < 1.0, "Katamtaman Pain stages 10 m from the enemy base (goal %.1f m)" % d)
		await t.free_match(host)
	t.ok("Pain rule per difficulty")

# ---- skills ----------------------------------------------------------------------------------------
func _skill_use(t: TestCtx) -> void:
	# Nathan (Mahirap: 90 % of chances) blows BUGA! at a close attacker.
	var host := t.make_match([_entry("nathan", RB.DILAW), _entry("jm", RB.LILA)], {"difficulty": 2})
	TestCtx.put(host.heroes[0], -9, 0)
	TestCtx.put(host.heroes[1], -6, 2)
	var events := _watch(host)
	_install(host, [0], 2)
	t.go_live(host)
	var n := 0
	while n < 300 and _count(events, "skill_cast") == 0 and host.heroes[1].is_free():
		t.steps(host, 1)
		n += 1
	t.check(_count(events, "skill_cast") > 0, "a Mahirap Nathan uses a skill on a nearby enemy")
	var casts_by_bot := true
	for e in events:
		if e.kind == "skill_cast" and e.data.hero != host.heroes[0]:
			casts_by_bot = false
	t.check(casts_by_bot, "only the bot cast")
	t.ok("bots press skills with an aim point")
	await t.free_match(host)

# ---- a whole bot-only match -------------------------------------------------------------------------
func _full_match(t: TestCtx) -> void:
	var lineup: Array = []
	for team in range(2):
		for id in ["tutoy", "nene", "nathan", "jm", "inday"]:
			lineup.append(_entry(id, team))
	var host := t.make_match(lineup, {"round_time": 60.0, "difficulty": 1})
	var events := _watch(host)
	_install(host, null, 1)
	var limit := 120 * RB.TICK_RATE
	var n := 0
	while n < limit and (_count(events, "tag") == 0 or _count(events, "round_end") == 0):
		host.step()
		n += 1
	var tags := _count(events, "tag")
	var ends := _count(events, "round_end")
	t.check(tags >= 1, "a 5v5 bot match produces a tag (%d tags in %.0f s)" % [tags, RB.seconds(n)])
	t.check(ends >= 1, "a 5v5 bot match ends a round within 120 s (%d round ends, %.0f s)" % [ends, RB.seconds(n)])
	var kinds := {}
	for e in events:
		kinds[e.kind] = int(kinds.get(e.kind, 0)) + 1
	t.ok("5v5 bots: %.0f s simulated, events %s" % [RB.seconds(n), str(kinds)])
	await t.free_match(host)

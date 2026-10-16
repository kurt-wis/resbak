extends RefCounted

## Nene's kit against docs/RESBAK.md § 4 Nene: IYAK! (crying decoy + see-through), SUMBONG KITA!
## (fake alert, fake rescuer), SALING-PUSA (silent footsteps). Small 2v2 matches on the grey
## arena (TestCtx.make_match), manual stepping, exact tick counts. Dilaw = nene + inday, Lila =
## nathan + tutoy. Jail_Lila holds Dilaw prisoners (the jail Nene's fake rescuer runs to).

const D := RB.DILAW
const L := RB.LILA
const TAG := RB.BTN_TAG
const S1 := RB.BTN_SKILL1
const S2 := RB.BTN_SKILL2
const USE := RB.BTN_INTERACT

var events: Array = []

func run(t: TestCtx) -> void:
	await _data(t)
	await _no_cast_in_countdown(t)
	await _iyak_cast(t)
	await _iyak_early_end(t)
	await _iyak_decoy_tag(t)
	await _sumbong_alert(t)
	await _sumbong_jail_choice(t)
	await _sumbong_fake_rescuer(t)
	await _sumbong_fake_rescuer_chain(t)
	await _saling_pusa(t)
	await _saling_pusa_tradisyonal(t)

# ---- helpers -----------------------------------------------------------------------------
func _lineup() -> Array:
	return [
		{"hero_id": "nene", "team": D}, {"hero_id": "inday", "team": D},
		{"hero_id": "nathan", "team": L}, {"hero_id": "tutoy", "team": L},
	]

func _make(t: TestCtx, settings: Dictionary = {}) -> MatchHost:
	var host := t.make_match(_lineup(), settings)
	events = []
	host.event.connect(func(kind: String, data: Dictionary): events.append({"kind": kind, "data": data}))
	return host

## Live round, everybody parked far apart: nene (-15,-10), inday (-13,-10), nathan (15,10), tutoy (17,10).
func _live(t: TestCtx, settings: Dictionary = {}) -> MatchHost:
	var host := _make(t, settings)
	t.go_live(host)
	_park(host)
	return host

func _park(host: MatchHost) -> void:
	TestCtx.put(host.heroes[0], -15, -10)
	TestCtx.put(host.heroes[1], -13, -10)
	TestCtx.put(host.heroes[2], 15, 10)
	TestCtx.put(host.heroes[3], 17, 10)

func _count(kind: String) -> int:
	var n := 0
	for e in events:
		if e.kind == kind:
			n += 1
	return n

func _last(kind: String) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		if events[i].kind == kind:
			return events[i].data
	return {}

func _decoys(host: MatchHost) -> Array:
	return host.objects.filter(func(o): return o is IyakDecoy)

func _alerts(host: MatchHost) -> Array:
	return host.objects.filter(func(o): return o is FakeAlert)

func _fakes(host: MatchHost) -> Array:
	return host.objects.filter(func(o): return o is NeneFakeRescuer)

func _st(h: Hero) -> bool: ## IYAK! see-through running
	return h.skills[0].call("see_through_active")

func _press(t: TestCtx, host: MatchHost, h: Hero, button: int, n := 1) -> void:
	t.inputs(host).press(h, button)
	t.steps(host, n)

# ---- data --------------------------------------------------------------------------------
func _data(t: TestCtx) -> void:
	var hd := HeroData.load_hero("nene")
	var want := {"iyak_see_through_time": 3.0, "iyak_see_through_alpha": 0.25, "iyak_decoy_time": 5.0,
		"sumbong_range": 12.0, "sumbong_alert_time": 3.0, "sumbong_jail_radius": 8.0,
		"sumbong_fake_speed": 5.0, "sumbong_fake_time": 3.0, "saling_pusa_quiet_time": 4.0,
		"saling_pusa_clear_radius": 8.0, "saling_pusa_break_radius": 4.0}
	for k in want:
		t.check(hd.values.has(k) and t.near(float(hd.values[k]), want[k]), "nene.tres %s = %s" % [k, str(want[k])])
	t.check(t.near(hd.skill1_cooldown, 14.0) and t.near(hd.skill2_cooldown, 10.0) and t.near(hd.run_speed, 5.0) and t.near(hd.tag_reach, 1.2), "Nene: 5.0 m/s, 1.2 m reach, CD 14 s / 10 s")
	var host := _make(t)
	var nene: Hero = host.heroes[0]
	t.check(nene.skills[0].kind() == RB.SkillKind.NEITHER and nene.skills[1].kind() == RB.SkillKind.NEITHER, "IYAK! and SUMBONG KITA! are type Neither")
	t.check(nene.skills[0].skill_name() == "IYAK!" and nene.skills[1].skill_name() == "SUMBONG KITA!", "skill names")
	t.check(nene.passive.hud_state().has("fill") and not nene.footsteps_silent(), "SALING-PUSA has a HUD state and starts audible")
	t.ok("Nene data and wiring")
	await t.free_match(host)

func _no_cast_in_countdown(t: TestCtx) -> void:
	var host := _make(t)
	var nene: Hero = host.heroes[0]
	_press(t, host, nene, S1, 5)
	_press(t, host, nene, S2, 5)
	t.check(host.objects.is_empty() and nene.enemy_alpha == 1.0 and nene.skills[0].cd_ticks == 0, "no skills in the countdown")
	await t.free_match(host)

# ---- IYAK! -------------------------------------------------------------------------------
func _iyak_cast(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var inday: Hero = host.heroes[1]
	var nathan: Hero = host.heroes[2]
	TestCtx.put(nene, -10, -8)
	_press(t, host, nene, S1)
	var decoys := _decoys(host)
	if not t.check(decoys.size() == 1, "IYAK! leaves one decoy"):
		await t.free_match(host)
		return
	var decoy: IyakDecoy = decoys[0]
	t.check(RB.flat_dist(decoy.global_position, Vector3(-10, 0, -8)) < 0.05, "the decoy is left where Nene stood")
	t.check(decoy.is_tag_decoy and decoy.team == D and decoy.owner_hero == nene, "the decoy is a tag decoy of Nene's team")
	t.check(decoy.minimap_as_hero == nene, "the decoy shows on the enemy minimap as Nene")
	t.check(decoy.find_children("*", "CollisionObject3D", true, false).is_empty(), "the decoy has no collision")
	t.check(decoy.model != null, "the decoy shows a Nene model")
	t.check(_st(nene) and t.near(nene.enemy_alpha, 0.25), "Nene turns see-through (enemies see 25 %)")
	t.check(t.near(host.visibility(nathan, nene), 0.25) and t.near(host.visibility(inday, nene), 1.0), "enemies see 25 % of her, allies 100 %")
	t.check(nene.skills[0].hud_note() != "", "the HUD shows the see-through time left")
	# the decoy stays put while she walks away
	t.inputs(host).move(nene, Vector2(1, 0))
	t.steps(host, 30)
	t.inputs(host).move(nene, Vector2.ZERO)
	t.check(nene.global_position.x > -9.0 and RB.flat_dist(decoy.global_position, Vector3(-10, 0, -8)) < 0.05, "the decoy stays still while Nene leaves")
	# see-through lasts 3 s = 180 ticks, counted from the cast tick
	t.steps(host, 148) # 1 + 30 + 148 = 179 steps
	t.check(_st(nene) and t.near(nene.enemy_alpha, 0.25), "still see-through after 179 ticks")
	t.steps(host, 1)
	t.check(not _st(nene) and nene.enemy_alpha == 1.0, "see-through ends after 180 ticks (3 s)")
	t.check(t.near(host.visibility(nathan, nene), 1.0), "enemies see her fully again")
	# the decoy cries 5 s = 300 ticks
	t.steps(host, 119) # 299
	t.check(_decoys(host).size() == 1, "the decoy is still there after 299 ticks")
	t.steps(host, 1)
	t.check(_decoys(host).is_empty() and decoy.expired, "the decoy is gone after 300 ticks (5 s)")
	# cooldown 14 s = 840 ticks from the cast
	t.check(not nene.skills[0].is_ready(), "IYAK! is still on cooldown at tick 300")
	t.steps(host, 539) # 839
	t.check(not nene.skills[0].is_ready(), "not ready after 839 ticks")
	t.steps(host, 1)
	t.check(nene.skills[0].is_ready(), "ready after 840 ticks (14 s)")
	t.ok("IYAK! decoy, see-through and timing")
	await t.free_match(host)

func _iyak_early_end(t: TestCtx) -> void:
	# Tag press
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	TestCtx.put(nene, -10, -8)
	_press(t, host, nene, S1, 10)
	t.check(t.near(nene.enemy_alpha, 0.25), "see-through is on")
	_press(t, host, nene, TAG)
	t.check(nene.enemy_alpha == 1.0 and not _st(nene), "a Tag press ends see-through")
	t.check(_decoys(host).size() == 1, "the placed decoy stays")
	await t.free_match(host)
	# Her other skill
	host = _live(t)
	nene = host.heroes[0]
	TestCtx.put(nene, -10, -8)
	_press(t, host, nene, S1, 10)
	_press(t, host, nene, S2)
	t.check(nene.enemy_alpha == 1.0 and not _st(nene), "casting SUMBONG KITA! ends see-through")
	t.check(_decoys(host).size() == 1, "the decoy stays after the other skill")
	await t.free_match(host)
	# Capture start
	host = _live(t)
	nene = host.heroes[0]
	TestCtx.put(nene, 10.6, 0)
	_press(t, host, nene, S1, 5)
	t.check(t.near(nene.enemy_alpha, 0.25), "see-through is on at the Lila base")
	t.inputs(host).hold(nene, USE)
	t.steps(host, 2)
	t.check(nene.capturing, "Nene is capturing")
	t.check(nene.enemy_alpha == 1.0 and not _st(nene), "starting a capture ends see-through")
	await t.free_match(host)
	# Rescue
	host = _live(t)
	nene = host.heroes[0]
	TestCtx.put(nene, -10, -8)
	_press(t, host, nene, S1, 5)
	nene.notify_rescued_others([host.heroes[1]], false)
	t.check(nene.enemy_alpha == 1.0 and not _st(nene), "a rescue ends see-through")
	await t.free_match(host)
	# Tagged: see-through ends, decoy lasts its full time
	host = _live(t)
	nene = host.heroes[0]
	TestCtx.put(nene, -10, -8)
	_press(t, host, nene, S1, 5)
	nene.on_tagged(host.heroes[2])
	t.check(nene.enemy_alpha == 1.0 and not _st(nene), "being tagged ends see-through")
	t.steps(host, 200)
	t.check(_decoys(host).size() == 1, "the decoy lasts its full time after Nene is tagged")
	await t.free_match(host)
	# Stun and push do not end it
	host = _live(t)
	nene = host.heroes[0]
	TestCtx.put(nene, -10, -8)
	_press(t, host, nene, S1, 5)
	nene.stun(0.5)
	nene.apply_push(Vector3(1, 0, 0), 1.0)
	t.steps(host, 5)
	t.check(_st(nene) and t.near(nene.enemy_alpha, 0.25), "stun and push do not end see-through")
	t.ok("IYAK! see-through ends early on Tag, skill, capture, rescue and tag")
	await t.free_match(host)

func _iyak_decoy_tag(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	TestCtx.put(nene, -10, -8)
	_press(t, host, nene, S1)
	TestCtx.put(nene, -10, -2) # Nene steps away; only the decoy is near the attacker
	TestCtx.put(nathan, -9.0, -8)
	t.inputs(host).aim_at(nathan, Vector3(-20, 0, -8))
	_press(t, host, nathan, TAG, 10)
	t.check(nathan.is_stumbling() and nathan.is_free(), "tagging the decoy is a failed tag: the tagger stumbles")
	t.check(_count("tag_failed") == 1 and _last("tag_failed").decoy == true and _count("tag") == 0, "tag_failed event with decoy = true, no tag")
	t.check(_decoys(host).size() == 1 and nene.is_free(), "the decoy stays and Nene is untouched")
	await t.free_match(host)

# ---- SUMBONG KITA! -------------------------------------------------------------------------
func _sumbong_alert(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	TestCtx.put(nene, -10, -8)
	nene.ep_ticks = 600 # a Neither skill does not end Escape Protection
	t.inputs(host).aim_at(nene, Vector3(30, 0, -8)) # 40 m away: clamped to 12 m
	_press(t, host, nene, S2)
	t.check(_count("fake_alert") == 1, "SUMBONG KITA! emits one fake_alert")
	var d := _last("fake_alert")
	t.check(t.near(d.point.x, 2.0, 0.01) and t.near(d.point.z, -8.0, 0.01), "aim past range: the alert lands at 12 m (%s)" % str(d.point))
	t.check(d.team == D and t.near(d.seconds, 3.0), "event carries the team and 3 s")
	t.check(nene.ep_ticks > 0, "Escape Protection is not ended (type Neither)")
	var alerts := _alerts(host)
	t.check(alerts.size() == 1 and (alerts[0] as FakeAlert).visible_to_team == L, "the alert icon is for Lila (Nene's enemies) only")
	t.check(not (alerts[0] as FakeAlert).is_tag_decoy and (alerts[0] as FakeAlert).visible_to_local(), "the alert is not a tag target")
	t.check(nene.skills[1].cd_ticks == 599 and _count("tag") == 0 and _count("capture") == 0 and host.round_flow.score == [0, 0], "it never scores")
	t.steps(host, 178)
	t.check(_alerts(host).size() == 1, "the alert lasts through tick 179")
	t.steps(host, 1)
	t.check(_alerts(host).is_empty(), "the alert is gone after 180 ticks (3 s)")
	# a nearer aim point is used as is
	nene.skills[1].cd_ticks = 0
	t.inputs(host).aim_at(nene, Vector3(-5, 0, -8))
	_press(t, host, nene, S2)
	t.check(t.near(_last("fake_alert").point.x, -5.0, 0.01), "a point inside range is used exactly")
	# tagging an alert is a plain failed tag (no decoy)
	TestCtx.put(nathan, -4.0, -8)
	t.inputs(host).aim_at(nathan, Vector3(-20, 0, -8))
	_press(t, host, nathan, TAG, 10)
	t.check(nathan.is_stumbling() and _count("tag_failed") == 1 and _last("tag_failed").decoy == false, "an alert is not a tag target (plain failed tag)")
	t.ok("SUMBONG KITA! fake alert")
	await t.free_match(host)

func _jailed_inday(t: TestCtx, host: MatchHost) -> void:
	host.heroes[1].on_tagged(host.heroes[2])
	t.steps(host, 49)

func _sumbong_jail_choice(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var inday: Hero = host.heroes[1]
	var r: Rect2 = host.layout.jail_rect(L)
	var mz := r.get_center().y
	# nobody jailed: even next to the jail it is a plain alert
	TestCtx.put(nene, r.position.x - 6.0, mz)
	t.inputs(host).aim_at(nene, Vector3(r.position.x - 2.0, 0, mz))
	_press(t, host, nene, S2)
	t.check(_count("fake_alert") == 1 and _count("fake_rescuer") == 0, "no prisoners: a plain alert next to the jail")
	_jailed_inday(t, host)
	t.check(inday.state == Hero.State.JAILED, "Inday is jailed in Jail_Lila")
	# far from the jail (> 8 m): alert
	nene.skills[1].cd_ticks = 0
	TestCtx.put(nene, r.position.x - 16.0, mz)
	t.inputs(host).aim_at(nene, Vector3(r.position.x - 8.1, 0, mz))
	_press(t, host, nene, S2)
	t.check(_count("fake_alert") == 2 and _count("fake_rescuer") == 0, "8.1 m from the jail: still an alert")
	# within 8 m: fake rescuer
	nene.skills[1].cd_ticks = 0
	t.inputs(host).aim_at(nene, Vector3(r.position.x - 7.9, 0, mz))
	_press(t, host, nene, S2)
	t.check(_count("fake_rescuer") == 1 and _count("fake_alert") == 2, "7.9 m from the jail with a prisoner: fake rescuer instead of an alert")
	t.check(_fakes(host).size() == 1, "one fake rescuer exists")
	# a jail holding ENEMIES does not count: Tutoy in Jail_Dilaw, Nene casts next to it
	var host2 := _live(t)
	var nene2: Hero = host2.heroes[0]
	var r2: Rect2 = host2.layout.jail_rect(D)
	host2.heroes[3].on_tagged(nene2)
	t.steps(host2, 49)
	t.check(host2.heroes[3].state == Hero.State.JAILED, "Tutoy is held in Jail_Dilaw")
	TestCtx.put(nene2, r2.end.x + 6.0, r2.get_center().y)
	t.inputs(host2).aim_at(nene2, Vector3(r2.end.x + 2.0, 0, r2.get_center().y))
	events = []
	_press(t, host2, nene2, S2)
	t.check(_count("fake_alert") == 1 and _count("fake_rescuer") == 0, "a jail holding enemies gives a plain alert")
	await t.free_match(host2)
	t.ok("SUMBONG KITA! chooses alert or fake rescuer by the 8 m jail rule")
	await t.free_match(host)

func _sumbong_fake_rescuer(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var inday: Hero = host.heroes[1]
	var nathan: Hero = host.heroes[2]
	var r: Rect2 = host.layout.jail_rect(L)
	var marker := host.layout.marker(L)
	_jailed_inday(t, host)
	var from := Vector3(marker.x - 5.6, 0, marker.z)
	TestCtx.put(nene, from.x - 10.0, from.z)
	t.inputs(host).aim_at(nene, from)
	t.check(RB.flat_dist(nene.global_position, from) < 10.01, "(setup: aim 10 m away)")
	events = []
	_press(t, host, nene, S2)
	var fakes := _fakes(host)
	if not t.check(fakes.size() == 1 and _alerts(host).is_empty(), "a fake rescuer, no alert"):
		await t.free_match(host)
		return
	var fake: NeneFakeRescuer = fakes[0]
	t.check(fake.team == D and fake.is_tag_decoy, "the fake belongs to Nene's team and is a tag decoy")
	t.check(fake.find_children("*", "CollisionObject3D", true, false).is_empty(), "the fake has no collision")
	var shadows := true
	for mi in fake.find_children("*", "MeshInstance3D", true, false):
		shadows = shadows and (mi as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.check(shadows, "the fake casts no shadow")
	t.check(t.near(fake.speed, 5.0), "the fake runs at 5.0 m/s")
	t.steps(host, 29) # 30 ticks since the cast = 0.5 s = 2.5 m
	t.check(t.near(fake.global_position.x - from.x, 2.5, 0.06), "it runs 2.5 m in 0.5 s toward the marker (%.2f)" % (fake.global_position.x - from.x))
	t.check(RB.flat_dist(fake.global_position, marker) < RB.flat_dist(from, marker), "(closer to the marker)")
	t.steps(host, 70) # 100 ticks: arrived (5.6 m takes 68 ticks) and waits at the marker
	t.check(RB.flat_dist(fake.global_position, marker) < 0.06, "with no chain it runs to the jail marker and waits (%.2f)" % RB.flat_dist(fake.global_position, marker))
	t.check(inday.state == Hero.State.JAILED and _count("rescue") == 0, "the fake rescues nobody")
	t.steps(host, 79) # 179
	t.check(_fakes(host).size() == 1, "the fake is still there at 179 ticks")
	t.steps(host, 1)
	t.check(_fakes(host).is_empty(), "the fake vanishes after 180 ticks (3 s)")
	# tagging the fake is a failed tag
	nene.skills[1].cd_ticks = 0
	TestCtx.put(nene, from.x - 10.0, from.z)
	t.inputs(host).aim_at(nene, from)
	events = []
	_press(t, host, nene, S2)
	fake = _fakes(host)[0]
	TestCtx.put(nathan, from.x + 1.5, from.z)
	t.inputs(host).aim_at(nathan, Vector3(from.x - 10.0, 0, from.z))
	_press(t, host, nathan, TAG, 10)
	t.check(nathan.is_stumbling() and _count("tag_failed") == 1 and _last("tag_failed").decoy == true and _count("tag") == 0, "tagging the fake rescuer is a failed tag")
	t.check(_fakes(host).size() == 1, "the fake stays after being tagged")
	t.ok("SUMBONG KITA! fake rescuer runs to the marker, vanishes, fails tags")
	await t.free_match(host)

func _sumbong_fake_rescuer_chain(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var inday: Hero = host.heroes[1]
	var marker := host.layout.marker(L)
	_jailed_inday(t, host)
	# Inday anchors the chain (lone anchor: the rescue point is the hand point)
	TestCtx.put(inday, marker.x - 0.5 * host.layout.out_dir(L).x, marker.z)
	_press(t, host, inday, USE)
	t.check(inday.state == Hero.State.CHAINED and host.jail_system.chain(L) == [inday], "Inday is the lone anchor")
	var hand := host.jail_system.hand_point(L)
	var from := Vector3(hand.x - 4.1 - 1.5, 0, hand.z)
	TestCtx.put(nene, from.x - 10.0, from.z)
	t.inputs(host).aim_at(nene, from)
	events = []
	_press(t, host, nene, S2)
	var fakes := _fakes(host)
	if not t.check(fakes.size() == 1, "a fake rescuer with a chain present"):
		await t.free_match(host)
		return
	var fake: NeneFakeRescuer = fakes[0]
	var best := INF
	for i in range(90):
		t.steps(host, 1)
		best = minf(best, RB.flat_dist(fake.global_position, hand))
	t.check(best < 0.06, "it runs to the chain's rescue point (closest %.2f m)" % best)
	t.check(inday.state == Hero.State.CHAINED and _count("rescue") == 0 and host.jail_system.chain(L) == [inday], "touching the chain does not rescue: no collision, no rescue")
	t.ok("fake rescuer follows the chain and never rescues")
	await t.free_match(host)

# ---- SALING-PUSA ----------------------------------------------------------------------------
func _saling_pusa(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	var p: Passive = nene.passive
	# an enemy at 6 m keeps resetting the timer
	TestCtx.put(nene, -5, -8)
	TestCtx.put(nathan, 1, -8)
	t.steps(host, 300)
	t.check(not nene.footsteps_silent() and t.near(p.hud_state().fill, 0.0), "a free enemy within 8 m: never silent")
	# enemy leaves: 4 s = 240 ticks
	TestCtx.put(nathan, 15, 10)
	t.steps(host, 119)
	t.check(not nene.footsteps_silent() and t.near(float(p.hud_state().fill), 119.0 / 240.0, 0.01), "119 quiet ticks: not silent, HUD fill %.2f" % float(p.hud_state().fill))
	t.steps(host, 120)
	t.check(not nene.footsteps_silent(), "239 quiet ticks: not silent yet")
	t.steps(host, 1)
	t.check(nene.footsteps_silent() and p.hud_state().on == true, "footsteps are silent after 240 quiet ticks (4 s)")
	# an enemy between 4 m and 8 m does not break it
	TestCtx.put(nathan, 1, -8) # 6 m
	t.steps(host, 30)
	t.check(nene.footsteps_silent(), "a free enemy at 6 m does not break the silence")
	# a jailed-like enemy within 4 m does not break it either
	var tutoy: Hero = host.heroes[3]
	tutoy.on_tagged(nene)
	TestCtx.put(tutoy, -6, -8)
	t.steps(host, 5)
	t.check(nene.footsteps_silent(), "an enemy who is not Free does not count")
	# a free enemy within 4 m breaks it
	TestCtx.put(nathan, -2, -8) # 3 m
	t.steps(host, 1)
	t.check(not nene.footsteps_silent() and p.hud_state().on == false, "a free enemy within 4 m breaks the silence at once")
	# restart needs another full 4 s
	TestCtx.put(nathan, 15, 10)
	t.steps(host, 239)
	t.check(not nene.footsteps_silent(), "239 ticks after the break: still audible")
	t.steps(host, 1)
	t.check(nene.footsteps_silent(), "silent again after another 240 ticks")
	# a skill breaks it (S2 here; IYAK! too)
	_press(t, host, nene, S2)
	t.check(not nene.footsteps_silent(), "casting a skill breaks the silence")
	t.steps(host, 240)
	t.check(nene.footsteps_silent(), "...and it restarts after 4 s")
	nene.skills[0].cd_ticks = 0
	_press(t, host, nene, S1)
	t.check(not nene.footsteps_silent(), "IYAK! breaks the silence too")
	# jailed: no silence
	t.steps(host, 240)
	t.check(nene.footsteps_silent(), "silent again")
	nene.on_tagged(host.heroes[3])
	t.check(not nene.footsteps_silent(), "a tagged Nene is not silent")
	t.ok("SALING-PUSA silent footsteps")
	await t.free_match(host)

func _saling_pusa_tradisyonal(t: TestCtx) -> void:
	var host := _live(t, {"skills": false})
	var nene: Hero = host.heroes[0]
	TestCtx.put(nene, -5, -8)
	TestCtx.put(host.heroes[2], 1, -8) # an enemy at 6 m restarts the count
	t.steps(host, 2)
	TestCtx.put(host.heroes[2], 15, 10)
	t.steps(host, 239)
	t.check(not nene.footsteps_silent(), "Tradisyonal: not silent at 239 ticks")
	t.steps(host, 1)
	t.check(nene.footsteps_silent(), "the passive stays on when Skills are Off")
	_press(t, host, nene, S1)
	_press(t, host, nene, S2)
	t.check(host.objects.is_empty() and nene.footsteps_silent(), "actives are off in Tradisyonal and do not break the silence")
	await t.free_match(host)

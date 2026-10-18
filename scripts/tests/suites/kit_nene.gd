extends RefCounted

## Nene's kit (v0.2, docs/status.md): SIGAW! (a shouted word: enemy stun, teammate dash),
## BAWAL! (a "don't hit me" sign: a tag on her curses the tagger with hallucination) and
## SALING-PUSA (silent footsteps, docs/RESBAK.md § 4 Nene). Small 2v2 matches on the grey
## arena (TestCtx.make_match), manual stepping, exact tick counts. Dilaw = nene + inday,
## Lila = nathan + tutoy.

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
	await _sigaw_stun(t)
	await _sigaw_first_hit(t)
	await _sigaw_ally_dash(t)
	await _sigaw_range(t)
	await _bawal_curse(t)
	await _bawal_drops(t)
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

## Live round, everybody parked far apart: nene (-15,-10), inday (-13,-13), nathan (15,10), tutoy (17,10).
func _live(t: TestCtx, settings: Dictionary = {}) -> MatchHost:
	var host := _make(t, settings)
	t.go_live(host)
	_park(host)
	return host

func _park(host: MatchHost) -> void:
	TestCtx.put(host.heroes[0], -15, -10)
	TestCtx.put(host.heroes[1], -13, -13) # off the -10 row SIGAW! tests shoot along
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

func _words(host: MatchHost) -> Array:
	return host.objects.filter(func(o): return o is SigawWord and not o.expired)

func _press(t: TestCtx, host: MatchHost, h: Hero, button: int, n := 1) -> void:
	t.inputs(host).press(h, button)
	t.steps(host, n)

## Step until an event of `kind` shows up (or `cap` ticks); returns the ticks it took, -1 if never.
func _until(t: TestCtx, host: MatchHost, kind: String, cap: int) -> int:
	var n0 := _count(kind)
	for i in range(cap):
		t.steps(host, 1)
		if _count(kind) > n0:
			return i + 1
	return -1

# ---- data --------------------------------------------------------------------------------
func _data(t: TestCtx) -> void:
	var hd := HeroData.load_hero("nene")
	var want := {"sigaw_speed": 18.0, "sigaw_range": 12.0, "sigaw_radius": 0.35, "sigaw_stun": 0.5,
		"sigaw_dash_distance": 3.0, "bawal_time": 3.0, "bawal_hallucinate_time": 3.0,
		"saling_pusa_quiet_time": 4.0, "saling_pusa_clear_radius": 8.0, "saling_pusa_break_radius": 4.0}
	for k in want:
		t.check(hd.values.has(k) and t.near(float(hd.values[k]), want[k]), "nene.tres %s = %s" % [k, str(want[k])])
	t.check(t.near(hd.skill1_cooldown, 10.0) and t.near(hd.skill2_cooldown, 14.0) and t.near(hd.run_speed, 4.5) and t.near(hd.tag_reach, 1.2), "Nene: 4.5 m/s, 1.2 m reach, CD 10 s / 14 s")
	var host := _make(t)
	var nene: Hero = host.heroes[0]
	t.check(nene.skills[0].kind() == RB.SkillKind.OFFENSIVE and nene.skills[1].kind() == RB.SkillKind.NEITHER, "SIGAW! is Offensive, BAWAL! is Neither")
	t.check(nene.skills[0].skill_name() == "SIGAW!" and nene.skills[1].skill_name() == "BAWAL!", "skill names")
	t.check(nene.passive.hud_state().has("fill") and not nene.footsteps_silent(), "SALING-PUSA has a HUD state and starts audible")
	t.ok("Nene data and wiring")
	await t.free_match(host)

func _no_cast_in_countdown(t: TestCtx) -> void:
	var host := _make(t)
	var nene: Hero = host.heroes[0]
	_press(t, host, nene, S1, 5)
	_press(t, host, nene, S2, 5)
	t.check(host.objects.is_empty() and not nene.is_warded() and nene.skills[0].cd_ticks == 0, "no skills in the countdown")
	await t.free_match(host)

# ---- SIGAW! ------------------------------------------------------------------------------
func _sigaw_stun(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	TestCtx.put(nathan, -9, -10)
	t.inputs(host).aim_at(nene, nathan.global_position)
	_press(t, host, nene, S1)
	t.check(_count("sigaw") == 1 and _words(host).size() == 1, "SIGAW! sends one word flying")
	t.check(nene.skills[0].cd_ticks > 0 and nene.is_free(), "cooldown starts; Nene keeps moving freely")
	var took := _until(t, host, "sigaw_hit", 40)
	# 6 m apart: the word (0.35 m) meets Nathan's body after ~4.85 m at 18 m/s = ~16 ticks
	t.check(took > 0 and took <= 18, "the word reaches an enemy 6 m away in about a quarter second (%d ticks)" % took)
	var d := _last("sigaw_hit")
	t.check(d.get("target") == nathan and bool(d.get("enemy", false)), "the hit names the enemy")
	t.check(nathan.is_stunned() and nathan.stun_ticks >= RB.ticks(0.5) - 2 and nathan.stun_ticks <= RB.ticks(0.5), "the enemy is stunned for 0.5 s (%d ticks left)" % nathan.stun_ticks)
	t.check(_words(host).is_empty(), "the word is used up on the hit")
	t.steps(host, RB.ticks(0.5) + 1)
	t.check(not nathan.is_stunned(), "the stun wears off after 0.5 s")
	await t.free_match(host)

func _sigaw_first_hit(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	var tutoy: Hero = host.heroes[3]
	TestCtx.put(nathan, -11, -10)
	TestCtx.put(tutoy, -7, -10)
	t.inputs(host).aim_at(nene, tutoy.global_position)
	_press(t, host, nene, S1)
	_until(t, host, "sigaw_hit", 40)
	t.check(_last("sigaw_hit").get("target") == nathan, "the nearer enemy on the line takes the word")
	t.steps(host, 30)
	t.check(_count("sigaw_hit") == 1 and not tutoy.is_stunned(), "one word, one hit: the enemy behind is untouched")
	await t.free_match(host)

func _sigaw_ally_dash(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var inday: Hero = host.heroes[1]
	TestCtx.put(inday, -10, -10)
	t.inputs(host).move(inday, Vector2(0, 1)) # running +z
	t.steps(host, 20)
	t.inputs(host).aim_at(nene, inday.global_position + Vector3(0, 0, 1.2))
	_press(t, host, nene, S1)
	var took := _until(t, host, "sigaw_hit", 40)
	var d := _last("sigaw_hit")
	t.check(took > 0 and d.get("target") == inday and not bool(d.get("enemy", true)), "the word lands on a teammate")
	t.check(not inday.is_stunned() and inday.is_free(), "a teammate is never stunned by it")
	var z0 := inday.global_position.z
	var push_ticks := RB.ticks(host.tuning.push_time)
	t.steps(host, push_ticks)
	var gained := inday.global_position.z - z0
	var run_only := inday.data.run_speed * host.tuning.move_speed_scale * host.tuning.push_time
	t.check(gained > run_only + 2.0, "the teammate dashes about 3 m the way they run (%.2f m in %.2f s; a plain run covers %.2f m)" % [gained, host.tuning.push_time, run_only])
	t.check(absf(inday.global_position.x - (-10.0)) < 0.6, "the dash follows their run, not the word's flight")
	await t.free_match(host)

func _sigaw_range(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	t.inputs(host).aim_at(nene, Vector3(30, 0, -10))
	_press(t, host, nene, S1)
	var took := _until(t, host, "sigaw_fizzle", 80)
	var fz := _last("sigaw_fizzle")
	t.check(took > 0 and _count("sigaw_hit") == 0, "a word that meets nobody fizzles")
	var fx: float = fz.pos.x if not fz.is_empty() else 0.0
	t.check(t.near(fx, -15.0 + 0.4 + 12.0, 0.4), "it flies 12 m (fizzled at x %.2f)" % fx)
	t.check(_words(host).is_empty(), "and is gone")
	await t.free_match(host)

# ---- BAWAL! ------------------------------------------------------------------------------
func _tap_tag(t: TestCtx, host: MatchHost, tagger: Hero, victim: Hero) -> void:
	t.inputs(host).aim_at(tagger, victim.global_position)
	t.inputs(host).press(tagger, TAG)
	t.steps(host, RB.ticks(host.tuning.tag_windup) + 1)

func _bawal_curse(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	var nathan: Hero = host.heroes[2]
	_press(t, host, nene, S2)
	var sk = nene.skills[1]
	t.check(_count("bawal") == 1 and nene.is_warded(), "BAWAL! puts up the sign")
	t.check(sk.sign_label == null and nene.is_warded(), "BAWAL uses body glow without a floating sign")
	TestCtx.put(nathan, -14, -10)
	_tap_tag(t, host, nathan, nene)
	t.check(nene.is_free() and _count("tag") == 0, "a tag on a warded Nene does not count")
	t.check(_count("bawal_curse") == 1 and _last("bawal_curse").get("tagger") == nathan, "the tagger is cursed")
	t.check(nathan.is_hallucinating() and nathan.hallucinate_ticks > RB.ticks(3.0) - 3, "the tagger hallucinates for 3 s")
	t.check(not nathan.is_stumbling(), "no failed-tag stumble on top")
	t.check(not nene.is_warded() and sk.sign_label == null, "one curse per cast: the sign drops")
	t.check(int(host.stats[nathan.slot].tags) == 0, "no tag stat for the cursed swing")
	# the curse turns the stick around
	TestCtx.put(nathan, 5, 5)
	t.inputs(host).move(nathan, Vector2(1, 0))
	t.steps(host, 20)
	t.check(nathan.velocity.x < -1.0, "pushing right walks a hallucinating hero left (vx %.2f)" % nathan.velocity.x)
	t.steps(host, RB.ticks(3.0))
	t.check(not nathan.is_hallucinating(), "the curse wears off")
	t.steps(host, 30)
	t.check(nathan.velocity.x > 1.0, "and the stick is the right way round again (vx %.2f)" % nathan.velocity.x)
	t.inputs(host).move(nathan, Vector2.ZERO)
	# without the sign the next tag lands
	TestCtx.put(nathan, -14, -10)
	t.steps(host, 2)
	_tap_tag(t, host, nathan, nene)
	t.check(nene.state == Hero.State.TAGGED, "with the sign down she can be tagged again")
	await t.free_match(host)

func _bawal_drops(t: TestCtx) -> void:
	var host := _live(t)
	var nene: Hero = host.heroes[0]
	_press(t, host, nene, S2)
	t.steps(host, RB.ticks(3.0) - 2)
	t.check(nene.is_warded(), "the sign is still up just before 3 s")
	t.steps(host, 2)
	t.check(not nene.is_warded() and _count("bawal_curse") == 0, "the sign drops after 3 s")
	nene.skills[1].cd_ticks = 0
	_press(t, host, nene, S2)
	t.check(nene.is_warded(), "cast again")
	t.check(not nene.can_press_tag(), "ward cast briefly plants Nene")
	t.steps(host, nene.cast_lock_ticks)
	_press(t, host, nene, TAG)
	t.check(not nene.is_warded(), "pressing Tag drops the sign (no hitting from behind it)")
	await t.free_match(host)

# ---- SALING-PUSA -------------------------------------------------------------------------
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
	# a skill breaks it (S2 here; SIGAW! too)
	_press(t, host, nene, S2)
	t.check(not nene.footsteps_silent(), "casting a skill breaks the silence")
	t.steps(host, 240)
	t.check(nene.footsteps_silent(), "...and it restarts after 4 s")
	nene.skills[0].cd_ticks = 0
	_press(t, host, nene, S1)
	t.check(not nene.footsteps_silent(), "SIGAW! breaks the silence too")
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

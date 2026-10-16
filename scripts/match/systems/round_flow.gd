class_name RoundFlow
extends RefCounted

## Rounds and match (docs/RESBAK.md § 2 "Round end and match", § 6 "Loading, intro,
## countdown" and "Between rounds").
## COUNTDOWN 3 s frozen (aim and ping only) -> KABOOM -> PLAYING (timer from KABOOM)
## -> end by capture, lockdown, or the timer: fewer jailed wins, equal -> SUDDEN_DEATH
## (Takipsilim, 30 s, untimed after 2 draws; first successful tag or capture wins; neither
## = draw) -> ROUND_OVER (between rounds: 7 s, 5 s after a draw) -> reset -> COUNTDOWN ...
## First to points_to_win -> MATCH_OVER.

enum Phase { COUNTDOWN, PLAYING, SUDDEN_DEATH, ROUND_OVER, MATCH_OVER }
const PHASE_NAMES := ["countdown", "playing", "sudden_death", "round_over", "match_over"]

var host: MatchHost
var phase := Phase.COUNTDOWN
var phase_ticks := 0 ## ticks left in COUNTDOWN / ROUND_OVER
var timer_ticks := 0 ## round clock (PLAYING) or sudden-death clock (-1 = untimed)
var round_number := 0
var score := [0, 0]
var draws := 0
var last_result := {} ## {winner: -1/0/1, reason: String, round: int}
var winner := -1 ## match winner once MATCH_OVER
var round_log: Array = [] ## one entry per finished round

func _init(p_host: MatchHost) -> void:
	host = p_host

func points_to_win() -> int:
	return int(host.settings.get("points_to_win", host.tuning.points_to_win))

func is_live() -> bool:
	return phase == Phase.PLAYING or phase == Phase.SUDDEN_DEATH

func accepts_actions() -> bool:
	return true ## step 2 still runs in countdown for aim and ping; rules check round_live()

func heroes_frozen() -> bool:
	return phase == Phase.COUNTDOWN or phase == Phase.ROUND_OVER or phase == Phase.MATCH_OVER

func phase_name() -> String:
	return PHASE_NAMES[phase]

## Seconds on the visible clock (sudden death shows its own 30 s; untimed shows -1).
func clock_seconds() -> float:
	if phase == Phase.SUDDEN_DEATH and timer_ticks < 0:
		return -1.0
	return maxf(0.0, RB.seconds(timer_ticks))

func start_match() -> void:
	score = [0, 0]
	draws = 0
	round_number = 0
	winner = -1
	round_log.clear()
	_begin_round()

func _begin_round() -> void:
	round_number += 1
	_reset_world()
	phase = Phase.COUNTDOWN
	phase_ticks = RB.ticks(host.tuning.countdown)
	timer_ticks = RB.ticks(float(host.settings.get("round_time", host.tuning.round_time)))
	host.emit_event("countdown", {"round": round_number, "seconds": host.tuning.countdown})

## Spec § 2 "Reset": free prisoners, clear chains, reset cooldowns, end every effect;
## spawns hold up to 3 (slots 1-3 spawn 1, slots 4-5 spawn 2). Bases stay.
func _reset_world() -> void:
	host.clear_objects()
	host.jail_system.reset_round()
	host.base_system.reset_round()
	var used := {}
	for h in host.heroes:
		var spawn_idx := 0 if h.team_slot < 3 else 1
		var key := "%d_%d" % [h.team, spawn_idx]
		var n: int = used.get(key, 0)
		used[key] = n + 1
		var base: Vector3 = host.layout.spawns[h.team][spawn_idx]
		var offs := [Vector3.ZERO, Vector3(0, 0, -1), Vector3(0, 0, 1)]
		var at: Vector3 = base + offs[n % 3] * host.tuning.spawn_spacing + Vector3(0, 0.05, 0)
		var face := Vector3.RIGHT if h.team == RB.DILAW else Vector3.LEFT
		h.reset_for_round(at, face)
		host.stats[h.slot].round_impact = 0

func pre_tick() -> void:
	match phase:
		Phase.COUNTDOWN:
			phase_ticks -= 1
			if phase_ticks <= 0:
				phase = Phase.PLAYING
				host.emit_event("kaboom", {"round": round_number})
		Phase.PLAYING:
			if not bool(host.settings.get("practice", false)):
				timer_ticks -= 1
		Phase.SUDDEN_DEATH:
			if timer_ticks > 0:
				timer_ticks -= 1
		Phase.ROUND_OVER:
			phase_ticks -= 1
			if phase_ticks <= 0:
				if score[0] >= points_to_win() or score[1] >= points_to_win():
					phase = Phase.MATCH_OVER
					winner = 0 if score[0] > score[1] else 1
					host.emit_event("match_end", {"winner": winner, "score": score.duplicate()})
				else:
					_begin_round()

func post_tick() -> void:
	pass

## Step 9. landed = successful tags this tick (TagSystem.apply); captured = teams that
## completed a capture this tick (BaseSystem.tick_captures).
func check_end(landed: Array, captured: Array) -> void:
	if not is_live() or bool(host.settings.get("practice", false)):
		return # practice (tutorial): nothing ends the round; the lesson script runs the show
	var meets := [false, false]
	var reason := ["", ""]
	for team in captured:
		meets[team] = true
		reason[team] = "capture"
	for team in range(2):
		if host.jail_system.team_locked_down(RB.other_team(team)):
			meets[team] = true
			if reason[team] == "":
				reason[team] = "lockdown"
	if phase == Phase.SUDDEN_DEATH:
		for t in landed:
			var tagger: Hero = t.tagger
			meets[tagger.team] = true
			if reason[tagger.team] == "":
				reason[tagger.team] = "sudden_death"
	if meets[0] and meets[1]:
		_end_round(-1, "simultaneous")
		return
	for team in range(2):
		if meets[team]:
			_end_round(team, reason[team])
			return
	if phase == Phase.PLAYING and timer_ticks <= 0:
		var j0 := host.jail_system.jailed_count(RB.DILAW)
		var j1 := host.jail_system.jailed_count(RB.LILA)
		if j0 != j1:
			_end_round(RB.DILAW if j0 < j1 else RB.LILA, "sunset")
		else:
			phase = Phase.SUDDEN_DEATH
			timer_ticks = -1 if draws >= host.tuning.untimed_sudden_death_after_draws else RB.ticks(host.tuning.sudden_death_time)
			host.emit_event("sudden_death", {"timed": timer_ticks > 0})
	elif phase == Phase.SUDDEN_DEATH and timer_ticks == 0:
		_end_round(-1, "sudden_death_timeout")

## Round-end tick: all play stops; unfinished captures, wind-ups and skills give nothing.
func _end_round(win_team: int, reason: String) -> void:
	for h in host.heroes:
		h.windup_end_tick = -1
		h.charge_ticks = -1
		if h.capturing:
			host.base_system.cancel_capture(h, "round_end")
		for s in h.skills:
			if s.active:
				s.end("round_end")
	if win_team >= 0:
		score[win_team] += 1
	else:
		draws += 1
	last_result = {"winner": win_team, "reason": reason, "round": round_number, "score": score.duplicate(), "best": _round_best(win_team)}
	round_log.append(last_result)
	phase = Phase.ROUND_OVER
	var t := host.tuning
	var secs := t.between_rounds_banner + (0.0 if win_team < 0 else t.between_rounds_freeze + t.between_rounds_score)
	if win_team >= 0 and reason == "capture":
		secs += t.capture_slow_motion
	phase_ticks = RB.ticks(secs if win_team >= 0 else 5.0)
	host.emit_event("round_end", last_result)

## Round best player: winning team's top round Impact; tie -> more rescues, lower slot.
func _round_best(win_team: int) -> int:
	if win_team < 0:
		return -1
	var best: Hero = null
	for h in host.team_heroes(win_team):
		if best == null:
			best = h
			continue
		var a: Dictionary = host.stats[h.slot]
		var b: Dictionary = host.stats[best.slot]
		if a.round_impact > b.round_impact or (a.round_impact == b.round_impact and (a.rescues > b.rescues or (a.rescues == b.rescues and h.slot < best.slot))):
			best = h
	return best.slot if best else -1

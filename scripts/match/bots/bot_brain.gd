class_name BotBrain
extends Node

## Bot input source (docs/RESBAK.md § 11): the same rules and InputFrames as players.
## Roles come from BotCoord every second per team: Bantay guards the own base, Atake goes for
## the enemy base and captures, Pain runs at defenders to pull them off, Resbak runs to the
## chain tip, Kapit (jailed) joins the chain and steers the tip toward a free teammate.
## Difficulty (tuning.bot_reaction / bot_retreat_ignore / bot_skill_use): how long a newly seen
## enemy takes to register, how often the retreat rule is ignored, how many valid skill chances
## are taken. Bots only react to enemies they can see (visibility >= 0.5, or within 2.5 m).
## Pathing uses BotNav (baked once per match); straight steering is the fallback.

const SEE_CLOSE := 2.5 ## unseen enemies still register this close
const GUARD_OFFSET := 3.6 ## Bantay stands this far from the pole toward the court centre
const TIE_TIME := 0.04 ## "my tag lands first" ties inside this are settled by a pair hash

var hero: Hero
var host: MatchHost
var difficulty := 1
var role := BotCoord.Role.ATAKE
var mode := "idle" ## idle go hunt retreat base capture rescue guard kapit (for tests/debug)
var perceived: Array[Hero] = [] ## free enemies this bot has seen for longer than its reaction time
var retreat_enabled := true
var coord: BotCoord
var nav: BotNav
var rng := RandomNumberGenerator.new()

var _seen := {} ## enemy slot -> tick first seen (continuously)
var _goal := Vector3.INF
var _target: Hero = null ## who this bot is hunting
var _threat: Hero = null ## who this bot is backing away from
var _want_capture := false
var _exempt_retreat := false
var _path := PackedVector3Array()
var _path_goal := Vector3.INF
var _path_tick := -1000
var _last_move := Vector2.ZERO
var _probe_pos := Vector3.ZERO
var _probe_tick := 0
var _strafe_until := 0
var _strafe_sign := 1.0
var _stuck_count := 0
var _rolls := {} ## chance key -> [last tick, result]
var _retreat_last := -1000
var _retreat_ignore := false
var _tag_candidate := -1
var _tag_ready_tick := -1
var _recovering_sabay := false
var _reposition_until := -1
var _reposition_dir := Vector2.ZERO

func setup(p_hero: Hero, p_host: MatchHost, p_difficulty: int) -> void:
	hero = p_hero
	host = p_host
	difficulty = clampi(p_difficulty, 0, 2)
	name = "Bot_%d" % hero.slot
	rng.seed = int(host.settings.get("seed", 0)) * 7919 + hero.slot * 104729 + 17
	coord = BotCoord.of(host)
	nav = coord.nav

func frame_for(h: Hero, p_host: MatchHost) -> InputFrame:
	if host == null:
		host = p_host
	if h != hero or coord == null:
		hero = h
		coord = BotCoord.of(host)
		nav = coord.nav
	var f := InputFrame.new()
	if not host.round_live():
		_seen.clear()
		_rolls.clear()
		mode = "idle"
		_tag_candidate = -1
		_tag_ready_tick = -1
		_recovering_sabay = false
		_reposition_until = -1
		return f
	if not h.is_free():
		_tag_candidate = -1
		_tag_ready_tick = -1
		_reposition_until = -1
		_recovering_sabay = false
	_update_tag_recovery(h)
	_sense(h)
	role = coord.role_of(h)
	match h.state:
		Hero.State.FREE:
			_free(h, f)
		Hero.State.JAILED, Hero.State.CHAINED:
			_jailed(h, f)
		_:
			mode = "idle"
	if f.move != Vector2.ZERO and not f.has_aim:
		f.aim_point = h.global_position + Vector3(f.move.x, 0.0, f.move.y) * 6.0
		f.has_aim = true
	_last_move = f.move
	if mode == "hunt" and _target and RB.flat_dist(h.global_position, _target.global_position) < 2.5:
		_last_move = Vector2.ZERO # pressing into the enemy is not "stuck"
	_unstick_probe(h)
	return f

# ---- senses ---------------------------------------------------------------------------------
func _reaction_ticks() -> int:
	return RB.ticks(host.tuning.bot_reaction[difficulty])

func _sense(h: Hero) -> void:
	perceived.clear()
	var react := _reaction_ticks()
	for e in host.enemies_of(h):
		var seen := false
		if e.is_free():
			var alpha := host.visibility(h, e)
			seen = alpha >= 0.5 or (alpha > 0.0 and RB.flat_dist(h.global_position, e.global_position) <= SEE_CLOSE)
		if seen:
			if not _seen.has(e.slot):
				_seen[e.slot] = host.tick
			if host.tick - int(_seen[e.slot]) >= react:
				perceived.append(e)
		else:
			_seen.erase(e.slot)

## Falls for BAWAL! (hits the warded hero anyway): bot_fooled_chance per difficulty, rolled
## once per episode like _chance.
func _fooled(e: Hero) -> bool:
	var key := "fooled_%d" % e.slot
	var r: Variant = _rolls.get(key)
	if r == null or host.tick - int(r[0]) > 40:
		r = [host.tick, rng.randf() < host.tuning.bot_fooled_chance[difficulty]]
	else:
		r[0] = host.tick
	_rolls[key] = r
	return bool(r[1])

## A random chance that holds for the whole "episode" (re-rolled after 40 ticks without asking):
## bot_skill_use of the valid chances are taken.
func _chance(key: String) -> bool:
	var r: Variant = _rolls.get(key)
	if r == null or host.tick - int(r[0]) > 40:
		r = [host.tick, rng.randf() < host.tuning.bot_skill_use[difficulty]]
	else:
		r[0] = host.tick
	_rolls[key] = r
	return bool(r[1])

# ---- free heroes ------------------------------------------------------------------------------
func _free(h: Hero, f: InputFrame) -> void:
	_goal = Vector3.INF
	_target = null
	_threat = null
	_want_capture = false
	_exempt_retreat = false
	mode = "idle"
	if h.capturing:
		mode = "capture"
		if not bool(host.settings.get("capture_toggle", false)):
			f.held |= RB.BTN_INTERACT
		return
	if host.tick < _reposition_until and h.can_move():
		mode = "reposition"
		f.move = _reposition_dir
		return
	if _ihip_standing(h, f):
		return
	_try_tag(h, f)
	match role:
		BotCoord.Role.BANTAY:
			_plan_bantay(h)
		BotCoord.Role.PAIN:
			_plan_pain(h)
		BotCoord.Role.RESBAK:
			_plan_resbak(h)
		_:
			_plan_atake(h)
	if _retreat_check(h) and _retreat_move(h, f):
		mode = "retreat"
	elif _want_capture:
		mode = "base"
		if h.can_start_capture():
			f.held |= RB.BTN_INTERACT
			f.pressed |= RB.BTN_INTERACT
	elif _goal != Vector3.INF:
		var stop := 0.0
		if mode == "guard":
			stop = 0.5
		elif mode == "base" or mode == "rescue" or mode == "go":
			stop = 0.25
		_move_to(h, f, _goal, stop)
	if f.pressed & RB.BTN_TAG == 0:
		_use_skills(h, f)

# ---- tagging --------------------------------------------------------------------------------
## Tap Tag when an enemy will be inside normal reach when the swing lands.
func _try_tag(h: Hero, f: InputFrame) -> void:
	if not h.can_press_tag():
		_tag_candidate = -1
		return
	var max_reach := h.tag_reach()
	var lead := host.tuning.tag_windup
	var r := host.tuning.body_radius
	var my_p := h.global_position # commitment plants the attacker; do not predict a forward run
	var best: Hero = null
	var best_edge := INF
	var best_pt := Vector3.ZERO
	for e in perceived:
		if not host.can_tag(h, e) or not host.tag_system.reach_clear(h, e.global_position):
			continue
		if e.is_warded() and not _fooled(e):
			continue # BAWAL!: a wary bot doesn't hit the warded Nene
		var ep := e.global_position + RB.flat(e.velocity) * lead
		var edge := RB.flat_dist(my_p, ep) - 2.0 * r
		if edge > max_reach - 0.12 or edge >= best_edge:
			continue
		var dir := RB.flat(ep - h.global_position)
		var land := RB.flat(ep - my_p)
		if dir.length() > 0.05 and land.length() > 0.05 and rad_to_deg(dir.angle_to(land)) > 30.0:
			continue
		best = e
		best_edge = edge
		best_pt = ep
	if best == null:
		_tag_candidate = -1
		return
	if _tag_candidate != best.slot:
		_tag_candidate = best.slot
		_tag_ready_tick = maxi(_tag_ready_tick, host.tick + _tag_delay_ticks())
	if host.tick < _tag_ready_tick:
		return
	f.pressed |= RB.BTN_TAG
	f.aim_point = best_pt
	f.has_aim = true
	_tag_candidate = -1

func _tag_delay_ticks() -> int:
	var t := host.tuning
	return maxi(1, RB.ticks(rng.randf_range(t.bot_tag_delay_min[difficulty], t.bot_tag_delay_max[difficulty])))

func _update_tag_recovery(h: Hero) -> void:
	if h.sabay_ticks > 0 and not _recovering_sabay:
		_recovering_sabay = true
		_tag_candidate = -1
		var t := host.tuning
		var recovery_end := host.tick + h.sabay_ticks
		_reposition_until = recovery_end + RB.ticks(rng.randf_range(t.bot_sabay_reposition_min, t.bot_sabay_reposition_max))
		_tag_ready_tick = _reposition_until + _tag_delay_ticks()
		var side := h.facing.cross(Vector3.UP).normalized() * (-1.0 if rng.randf() < 0.5 else 1.0)
		_reposition_dir = Vector2(side.x, side.z)
		# Do not deliberately sidestep into map walls; ordinary body collision remains authoritative.
		var probe := h.global_position + side * h.current_speed() * t.bot_sabay_reposition_max
		if not host.los_clear(h.global_position, probe, RB.L_WORLD | RB.L_SKILL_WALL):
			_reposition_dir = -_reposition_dir
	elif h.sabay_ticks <= 0:
		_recovering_sabay = false

## Who lands a tag first if both go for it now (reach, speed, wind-up already running, stun).
func _i_land_first(h: Hero, e: Hero) -> bool:
	var t := host.tuning
	var edge := RB.flat_dist(h.global_position, e.global_position) - 2.0 * t.body_radius
	var my_t := t.tag_windup + maxf(0.0, edge - h.tag_reach()) / maxf(0.1, h.current_speed())
	my_t += RB.seconds(maxi(h.stumble_ticks, h.stun_ticks))
	var en_t := INF
	if e.is_winding_up():
		en_t = RB.seconds(maxi(0, e.windup_end_tick - host.tick))
	else:
		var v := RB.flat(e.velocity)
		var to_me := RB.flat(h.global_position - e.global_position)
		var fleeing := v.length() > 0.8 and to_me.length() > 0.01 and v.normalized().dot(to_me.normalized()) < -0.3
		if not fleeing:
			en_t = t.tag_windup + maxf(0.0, edge - e.tag_reach()) / maxf(0.1, e.current_speed())
	if en_t < INF:
		en_t += RB.seconds(maxi(e.stumble_ticks, e.stun_ticks))
	if absf(my_t - en_t) <= TIE_TIME:
		var a := mini(h.slot, e.slot)
		var b := maxi(h.slot, e.slot)
		var low_wins := (a * 31 + b * 17 + host.tick / 90) % 2 == 0
		return (h.slot < e.slot) == low_wins
	return my_t < en_t

func _any_skill_ready(h: Hero) -> bool:
	for s in h.skills:
		if s.can_cast():
			return true
	return false

# ---- retreat ----------------------------------------------------------------------------------
## Spec § 11 retreat: a free bot that is not capturing/rescuing and has no skill ready backs
## away from a free enemy within 6 m unless its own tag lands first. Sets _threat.
func _retreat_check(h: Hero) -> bool:
	_threat = null
	if not retreat_enabled or _exempt_retreat or _want_capture or _any_skill_ready(h):
		return false
	var best: Hero = null
	var bd := INF
	for e in perceived:
		if not host.can_tag(e, h):
			continue
		var d := RB.flat_dist(h.global_position, e.global_position)
		if d <= host.tuning.bot_retreat_range and d < bd:
			bd = d
			best = e
	if best == null or _i_land_first(h, best):
		return false
	if host.tick - _retreat_last > 60: # a new encounter: roll once whether this one is ignored
		_retreat_ignore = rng.randf() < host.tuning.bot_retreat_ignore[difficulty]
	_retreat_last = host.tick
	if _retreat_ignore:
		return false
	_threat = best
	return true

## Run away from nearby threats (leaning toward the own base), staying on walkable ground.
## False when cornered, so the bot fights instead.
func _retreat_move(h: Hero, f: InputFrame) -> bool:
	var pos := h.global_position
	var away := Vector3.ZERO
	for e in perceived:
		var d := RB.flat_dist(pos, e.global_position)
		if d <= host.tuning.bot_retreat_range and e.is_free():
			away += RB.flat(pos - e.global_position).normalized() / maxf(d, 0.5)
	if away.length() < 0.001:
		away = RB.flat(pos - _threat.global_position)
	away = away.normalized()
	var home := RB.flat(host.base_system.pole_pos(h.team) - pos).normalized()
	var best_dir := Vector3.ZERO
	var best_score := 0.0
	for a in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0]:
		var dir := away.rotated(Vector3.UP, deg_to_rad(a))
		if not nav.walkable(pos + dir * 3.0) or not nav.walkable(pos + dir * 1.5):
			continue
		var score := dir.dot(away) + 0.25 * dir.dot(home)
		for e in perceived:
			if RB.flat_dist(pos + dir * 1.5, e.global_position) < RB.flat_dist(pos, e.global_position) - 0.3:
				score -= 0.4
		if score > best_score:
			best_score = score
			best_dir = dir
	if best_dir == Vector3.ZERO:
		return false
	f.move = Vector2(best_dir.x, best_dir.z)
	return true

# ---- role plans ---------------------------------------------------------------------------------
func _enemy_pole(h: Hero) -> Vector3:
	return host.base_system.pole_pos(RB.other_team(h.team))

## Where an attacker stands to capture: just outside the pole, on the side it comes from.
func _stand_point(h: Hero, pole: Vector3) -> Vector3:
	var t := host.tuning
	var dir := RB.flat(h.global_position - pole)
	if dir.length() < 0.01:
		dir = Vector3.RIGHT if h.team == RB.DILAW else Vector3.LEFT
	return pole + dir.normalized() * (t.pole_radius + t.body_radius + 0.55)

## Nearest perceived free enemy within `clearance` of the straight line from h to `goal`.
func _path_blocker(h: Hero, goal: Vector3) -> Hero:
	var a := Vector2(h.global_position.x, h.global_position.z)
	var b := Vector2(goal.x, goal.z)
	var best: Hero = null
	var bd := INF
	for e in perceived:
		var p := Vector2(e.global_position.x, e.global_position.z)
		var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
		if p.distance_to(closest) <= host.tuning.bot_atake_clearance:
			var d := a.distance_to(p)
			if d < bd:
				bd = d
				best = e
	return best

func _hunt(e: Hero) -> void:
	_target = e
	_goal = e.global_position + RB.flat(e.velocity) * 0.2
	mode = "hunt"

func _plan_atake(h: Hero) -> void:
	var pole := _enemy_pole(h)
	var stand := _stand_point(h, pole)
	var blocker := _path_blocker(h, stand)
	if blocker:
		_hunt(blocker)
		return
	_goal = stand
	mode = "go"
	if host.base_system.in_capture_range(h):
		_want_capture = true

func _plan_pain(h: Hero) -> void:
	var pole := _enemy_pole(h)
	if difficulty == 2 and not _teammate_near(h, pole, host.tuning.bot_pain_teammate_range):
		_plan_atake(h) # Mahirap: Pain only with a teammate within 15 m of the enemy base
		return
	var best: Hero = null
	var bd := INF
	for e in perceived:
		var dp := RB.flat_dist(e.global_position, pole)
		if dp <= 14.0 and dp < bd:
			bd = dp
			best = e
	if best:
		_hunt(best)
		return
	var out := RB.flat(h.global_position - pole)
	if out.length() < 0.01:
		out = Vector3.RIGHT
	_goal = pole + out.normalized() * 10.0
	mode = "go"

func _teammate_near(h: Hero, p: Vector3, radius: float) -> bool:
	for a in host.allies_of(h):
		if a.is_free() and RB.flat_dist(a.global_position, p) <= radius:
			return true
	return false

func _guard_point(h: Hero) -> Vector3:
	var pole := host.base_system.pole_pos(h.team)
	var dir := RB.flat(Vector3.ZERO - pole)
	if dir.length() < 0.01:
		dir = Vector3.RIGHT if h.team == RB.DILAW else Vector3.LEFT
	return pole + dir.normalized() * GUARD_OFFSET

func _plan_bantay(h: Hero) -> void:
	var pole := host.base_system.pole_pos(h.team)
	var radius := host.tuning.bot_bantay_radius
	var best: Hero = null
	var bd := INF
	if RB.flat_dist(h.global_position, pole) <= radius + 4.0: # leash
		for e in perceived:
			var dp := RB.flat_dist(e.global_position, pole)
			if dp > radius:
				continue
			if e.capturing:
				dp -= 100.0
			if dp < bd:
				bd = dp
				best = e
	if best:
		_hunt(best)
		return
	_goal = _guard_point(h)
	mode = "guard"

func _plan_resbak(h: Hero) -> void:
	var jail_owner := RB.other_team(h.team)
	var rp := host.jail_system.rescue_point(jail_owner)
	if rp == Vector3.INF:
		rp = host.jail_system.post_spot(jail_owner) # wait where the first prisoner will stand
	_goal = rp
	mode = "rescue"
	if RB.flat_dist(h.global_position, rp) <= 8.0:
		_exempt_retreat = true # rushing the rescue

# ---- jailed heroes ----------------------------------------------------------------------------
## The chain forms by itself; the tip (last caught) and the post holder (first caught) steer.
## The tip stretches toward the teammate coming to the rescue (the Resbak, else the nearest
## free ally); the post holder walks the post along the jail line toward that teammate.
func _jailed(h: Hero, f: InputFrame) -> void:
	mode = "kapit"
	if not host.jail_system.can_steer(h):
		return
	var best: Hero = null
	var bd := INF
	for a in host.allies_of(h):
		if not a.is_free():
			continue
		var d := RB.flat_dist(a.global_position, h.global_position)
		if coord.roles.get(a.slot, -1) == BotCoord.Role.RESBAK:
			d -= 6.0 # the rescuer coming for us beats a closer ally doing something else
		if d < bd:
			bd = d
			best = a
	var owner := RB.other_team(h.team)
	var goal := host.jail_system.post(owner) + host.jail_system.out_dir(owner) * 6.0
	if best:
		goal = best.global_position
	# v0.2 jail line: a post holder (not also the tip) walks the post along the line to the
	# point nearest the rescuer, so the tip starts its reach from there
	if host.jail_system.is_post_holder(h) and not host.jail_system.is_tip(h):
		var s := host.layout.line_project(owner, goal)
		goal = host.layout.line_point(owner, s) + host.layout.line_normal(owner, s) * host.tuning.post_hold_offset
	if RB.flat_dist(h.global_position, goal) > 0.5:
		_steer_direct(h, f, goal)

func _steer_direct(h: Hero, f: InputFrame, to: Vector3) -> void:
	var d := RB.flat(to - h.global_position)
	if d.length() > 0.1:
		f.move = Vector2(d.x, d.z).normalized()

# ---- movement and unstick -----------------------------------------------------------------------
func _move_to(h: Hero, f: InputFrame, goal: Vector3, stop: float) -> void:
	var pos := h.global_position
	var dist := RB.flat_dist(pos, goal)
	if dist <= stop:
		return
	var wp := goal
	var at_end := true
	if nav.ready and dist > 1.2:
		var res := _next_waypoint(pos, goal)
		wp = res[0]
		at_end = res[1]
	var d := RB.flat(wp - pos)
	if d.length() < 0.3 and at_end:
		return
	if d.length() < 0.01:
		return
	var dir := Vector2(d.x, d.z).normalized()
	if host.tick < _strafe_until:
		var ang := deg_to_rad(80.0 if _stuck_count < 3 else 150.0) * _strafe_sign
		dir = dir.rotated(ang)
	f.move = dir

## [next corner, is it the final corner]
func _next_waypoint(pos: Vector3, goal: Vector3) -> Array:
	if host.tick - _path_tick >= 20 or _path.size() < 2 or RB.flat_dist(_path_goal, goal) > 0.8:
		_path = nav.path(pos, goal)
		_path_goal = goal
		_path_tick = host.tick
	if _path.size() < 2:
		return [goal, true]
	for i in range(1, _path.size()):
		if i == _path.size() - 1 or RB.flat_dist(pos, _path[i]) > 0.45:
			return [_path[i], i == _path.size() - 1]
	return [goal, true]

## Every half second: wanted to move but barely did -> sidestep for a moment and re-path.
func _unstick_probe(h: Hero) -> void:
	if host.tick - _probe_tick < 30:
		return
	var moved := RB.flat_dist(h.global_position, _probe_pos)
	_probe_pos = h.global_position
	_probe_tick = host.tick
	if _last_move.length() > 0.5 and moved < 0.3 and h.can_move() and not h.is_being_pushed() and h.state == Hero.State.FREE:
		_stuck_count += 1
		_strafe_until = host.tick + 25
		_strafe_sign = 1.0 if rng.randf() < 0.5 else -1.0
		_path_tick = -1000
	elif moved > 0.6:
		_stuck_count = 0

# ---- skills -------------------------------------------------------------------------------------
func _cast(f: InputFrame, slot: int, aim_point := Vector3.INF) -> void:
	var btn := RB.BTN_SKILL1 if slot == 0 else RB.BTN_SKILL2
	f.pressed |= btn
	f.held |= btn
	if aim_point != Vector3.INF:
		f.aim_point = aim_point
		f.has_aim = true

func _use_skills(h: Hero, f: InputFrame) -> void:
	if not host.skills_enabled() or not h.can_use_skills():
		return
	match h.data.id:
		"tutoy":
			_skills_tutoy(h, f)
		"nene":
			_skills_nene(h, f)
		"nathan":
			_skills_nathan(h, f)
		"jm":
			_skills_jm(h, f)
		"inday":
			_skills_inday(h, f)

func _dist_to(h: Hero, e: Hero) -> float:
	return RB.flat_dist(h.global_position, e.global_position)

func _is_chased(h: Hero) -> bool:
	if mode == "retreat":
		return true
	for e in perceived:
		if not host.can_tag(e, h) or _dist_to(h, e) > 5.0:
			continue
		var toward := RB.flat(h.global_position - e.global_position).normalized()
		if RB.flat(e.velocity).dot(toward) > 1.0:
			return true
	return false

func _goal_dist(h: Hero) -> float:
	return RB.flat_dist(h.global_position, _goal) if _goal != Vector3.INF else 0.0

func _nearest_perceived(h: Hero, max_d: float) -> Hero:
	var best: Hero = null
	var bd := max_d
	for e in perceived:
		var d := _dist_to(h, e)
		if d <= bd and host.can_tag(h, e):
			bd = d
			best = e
	return best

func _skills_tutoy(h: Hero, f: InputFrame) -> void:
	var s1 := h.skills[0]
	var s2 := h.skills[1]
	if s2.can_cast(): # LUSOT! perfect slide: slide through a tag in its last 6 ticks
		for e in perceived:
			if not e.is_winding_up():
				continue
			var left := e.windup_end_tick - host.tick
			if left >= 0 and left <= 5 and host.tag_system.in_tag_shape(e, e.lunge_dir, h.global_position, host.tuning.body_radius):
				if _chance("lusot_perfect"):
					var dir := RB.flat(e.global_position - h.global_position)
					dir = dir.normalized() if dir.length() > 0.05 else e.lunge_dir
					f.move = Vector2(dir.x, dir.z)
					_cast(f, 1, h.global_position + dir * 4.0)
					return
	if s1.can_cast(): # HARUROT!: chase, flee, or cross the court
		if mode == "hunt" and _target and host.can_tag(h, _target):
			var d := _dist_to(h, _target)
			if d >= 3.0 and d <= 9.0 and _chance("harurot_hunt"):
				_cast(f, 0, _target.global_position)
				return
		if mode == "retreat" and _threat and _dist_to(h, _threat) <= 4.5 and _chance("harurot_flee"):
			_cast(f, 0)
			return
		if (mode == "go" or mode == "rescue") and _goal_dist(h) >= 12.0 and _nearest_perceived(h, 10.0) == null and _chance("harurot_go"):
			_cast(f, 0, _goal)
			return
	if s2.can_cast() and mode == "retreat" and _threat and _dist_to(h, _threat) <= 2.5 and _chance("lusot_flee"):
		_cast(f, 1)

func _skills_nene(h: Hero, f: InputFrame) -> void:
	var s1 := h.skills[0]
	var s2 := h.skills[1]
	# BAWAL!: a chaser about to swing gets cursed
	if s2.can_cast() and _is_chased(h) and _threat and _dist_to(h, _threat) <= 3.5 and _chance("bawal"):
		_cast(f, 1)
		return
	if not s1.can_cast():
		return
	var reach: float = h.data.v("sigaw_range")
	# SIGAW! at a chaser (stun) ...
	if _threat and _is_chased(h) and _dist_to(h, _threat) <= reach * 0.7 and _clear_shot(h, _threat) and _chance("sigaw_stun"):
		_cast(f, 0, _threat.global_position + RB.flat(_threat.velocity) * 0.2)
		return
	# ... or at a teammate running for a rescue or a capture (a dash)
	for a in host.team_heroes(h.team):
		if a == h or not a.is_free() or RB.flat(a.velocity).length() < 2.0:
			continue
		var d := _dist_to(h, a)
		if d >= 2.0 and d <= reach * 0.6 and _clear_shot(h, a) and _chance("sigaw_dash"):
			_cast(f, 0, a.global_position + RB.flat(a.velocity) * 0.2)
			return

## Nothing else stands between h and target for a straight shot (walls or other heroes).
func _clear_shot(h: Hero, target: Hero) -> bool:
	if not host.los_clear(h.global_position, target.global_position, RB.L_WORLD | RB.L_SKILL_WALL):
		return false
	var seg := RB.flat(target.global_position - h.global_position)
	for o in host.heroes:
		if o == h or o == target or not o.is_free():
			continue
		var rel := RB.flat(o.global_position - h.global_position)
		var k := clampf(rel.dot(seg) / maxf(0.0001, seg.length_squared()), 0.0, 1.0)
		if rel.distance_to(seg * k) < 0.9:
			return false
	return true

func _skills_nathan(h: Hero, f: InputFrame) -> void:
	var s1 := h.skills[0]
	var s2 := h.skills[1]
	if s1.can_cast():
		var e := _threat if mode == "retreat" else _nearest_perceived(h, 4.5)
		if e and _dist_to(h, e) <= 4.5 and _chance("buga"):
			_cast(f, 0, e.global_position + RB.flat(e.velocity) * 0.3)
			return
	if s2.can_cast():
		if mode == "retreat" and _threat and _dist_to(h, _threat) <= 7.0 and _chance("ubo_flee"):
			_cast(f, 1, h.global_position.lerp(_threat.global_position, 0.6))
			return
		var pole := _enemy_pole(h)
		if (role == BotCoord.Role.ATAKE or role == BotCoord.Role.PAIN) and RB.flat_dist(h.global_position, pole) <= 8.5 and _nearest_perceived(h, 10.0) != null and _chance("ubo_cover"):
			_cast(f, 1, pole)

func _skills_jm(h: Hero, f: InputFrame) -> void:
	var s1 := h.skills[0]
	var s2 := h.skills[1]
	if s1.can_cast() and mode == "hunt" and _target and host.can_tag(h, _target):
		var d := _dist_to(h, _target)
		if d >= 2.6 and d <= 6.0 and _chance("talbog"):
			_cast(f, 0, _target.global_position)
			return
	if s2.can_cast():
		if mode == "hunt" and _target and host.can_tag(h, _target):
			var d := _dist_to(h, _target)
			if d >= 5.5 and d <= 13.0 and _chance("tamaraw_hunt"):
				_cast(f, 1, _target.global_position)
				return
		if (mode == "go" or mode == "rescue") and _goal != Vector3.INF:
			var gd := _goal_dist(h)
			if gd >= 6.0 and gd <= 13.0 and _enemy_near_line(h, _goal, 3.5) and _chance("tamaraw_go"):
				_cast(f, 1, _goal)

func _enemy_near_line(h: Hero, goal: Vector3, width: float) -> bool:
	var a := Vector2(h.global_position.x, h.global_position.z)
	var b := Vector2(goal.x, goal.z)
	for e in perceived:
		var p := Vector2(e.global_position.x, e.global_position.z)
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= width:
			return true
	return false

func _skills_inday(h: Hero, f: InputFrame) -> void:
	var s1 := h.skills[0]
	var s2 := h.skills[1]
	if s2.can_cast():
		# HILA! at a chain tip within reach (a rescue by hand) ...
		var reach: float = float(h.data.v("hila_range")) * 0.9
		var rp := host.jail_system.rescue_point(RB.other_team(h.team))
		if rp != Vector3.INF and RB.flat_dist(h.global_position, rp) <= reach and host.los_clear(h.global_position, rp) and _chance("hila_rescue"):
			_cast(f, 1, rp)
			return
		# ... or at a teammate an enemy is about to tag (pull them out)
		for a in host.allies_of(h):
			if not a.is_free():
				continue
			var d := _dist_to(h, a)
			if d < 3.0 or d > reach or not _clear_shot(h, a):
				continue
			for e in perceived:
				if host.can_tag(e, a) and RB.flat_dist(e.global_position, a.global_position) <= 2.5 and _chance("hila_save"):
					_cast(f, 1, a.global_position)
					return
	if s1.can_cast() and _nearest_perceived(h, 9.0) == null and (mode == "go" or mode == "rescue"):
		var dir := RB.flat(_enemy_pole(h) - h.global_position)
		if dir.length() < 8.0:
			return
		dir = dir.normalized()
		var n := 0
		for a in host.allies_of(h):
			if not a.is_free():
				continue
			var rel := RB.flat(a.global_position - h.global_position)
			var along := rel.dot(dir)
			var lateral := absf(rel.dot(dir.rotated(Vector3.UP, deg_to_rad(90.0))))
			if along >= 1.0 and along <= 10.0 and lateral <= 1.2 and RB.flat(a.velocity).dot(dir) > 2.0:
				n += 1
		if n >= 2 and _chance("ihip"):
			_cast(f, 0, h.global_position + dir * 8.0)

## IHIP! stands still blowing; end it (press S1 again) if an enemy gets close, else just wait.
func _ihip_standing(h: Hero, f: InputFrame) -> bool:
	if h.data.id != "inday" or h.skills.size() < 1 or not h.skills[0].active:
		return false
	mode = "idle"
	for e in perceived:
		if _dist_to(h, e) < 6.0:
			_cast(f, 0)
			return true
	f.aim_point = h.global_position + h.aim * 5.0
	f.has_aim = true
	return true

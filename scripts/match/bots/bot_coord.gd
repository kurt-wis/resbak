class_name BotCoord
extends RefCounted

## Per-match bot coordination (docs/RESBAK.md § 11): the shared navigation mesh and the team
## roles. Every 1 s per team: if a teammate is jailed, the free bot nearest the enemy jail is
## Resbak (two Resbak once two or more teammates are caught and the team can spare them); if the
## team is holding prisoners and has three or more free bots, the one nearest its own jail is
## Tanod (guards the chain tip: a v0.1.1 addition, logged in docs/status.md); the free bot
## nearest its own base is Bantay; the rest alternate Atake, Pain (Atake first). A jailed bot is
## Kapit. Stored on the host, shared by every BotBrain.

enum Role { ATAKE, PAIN, BANTAY, RESBAK, KAPIT, TANOD }
const ROLE_NAMES := ["Atake", "Pain", "Bantay", "Resbak", "Kapit", "Tanod"]

var host: MatchHost
var nav: BotNav
var roles := {} ## slot -> Role
var _assigned_tick := [-100000, -100000]

static func of(p_host: MatchHost) -> BotCoord:
	if p_host.has_meta("bot_coord"):
		return p_host.get_meta("bot_coord")
	var c := BotCoord.new()
	c.host = p_host
	c.nav = BotNav.of(p_host)
	p_host.set_meta("bot_coord", c)
	return c

## The role of `h` right now (re-assigning its team's roles when the 1 s interval is up).
func role_of(h: Hero) -> int:
	if h.is_jailed_like():
		return Role.KAPIT
	var gap := RB.ticks(host.tuning.bot_role_interval)
	if host.tick - _assigned_tick[h.team] >= gap or host.tick < _assigned_tick[h.team]:
		_assign(h.team)
		_assigned_tick[h.team] = host.tick
	return roles.get(h.slot, Role.ATAKE)

func _is_bot(h: Hero) -> bool:
	return host.input_sources.get(h.slot) is BotBrain

func _assign(team: int) -> void:
	var rest: Array[Hero] = []
	for h in host.team_heroes(team):
		if h.is_free() and _is_bot(h):
			rest.append(h)
	rest.sort_custom(func(a: Hero, b: Hero): return a.slot < b.slot)
	var caught := host.jail_system.jailed_count(team)
	if caught > 0 and not rest.is_empty():
		var jail := host.jail_system.post(RB.other_team(team)) # v0.2: the post moves along the jail line
		var rescuers := 2 if caught >= 2 and rest.size() >= 4 else 1
		for i in range(rescuers):
			var pick := _nearest(rest, jail)
			roles[pick.slot] = Role.RESBAK
			rest.erase(pick)
	if host.jail_system.jailed_count(RB.other_team(team)) > 0 and rest.size() >= 3:
		var pick := _nearest(rest, host.jail_system.post(team))
		roles[pick.slot] = Role.TANOD
		rest.erase(pick)
	if not rest.is_empty():
		var pick := _nearest(rest, host.base_system.pole_pos(team))
		roles[pick.slot] = Role.BANTAY
		rest.erase(pick)
	var atake_next := true
	for h in rest:
		roles[h.slot] = Role.ATAKE if atake_next else Role.PAIN
		atake_next = not atake_next

func _nearest(list: Array[Hero], p: Vector3) -> Hero:
	var best: Hero = null
	var bd := INF
	for h in list:
		var d := RB.flat_dist(h.global_position, p)
		if d < bd:
			bd = d
			best = h
	return best

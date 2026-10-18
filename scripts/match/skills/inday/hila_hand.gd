class_name HilaHand
extends SkillObject

## Inday's stretched hand (HILA!, Inday S2). It shoots out along her aim at a fixed speed in
## step 3 and stops at a wall or after `range` metres, then returns on a miss after that tick's rescue resolution.
## The first Free teammate whose body touches it (within `grab` of its centre, edge to edge)
## is yanked to her (a push toward Inday), and the hand closes. A chain tip it touches counts
## as Inday's touch: the JailSystem asks HILA! for the hand's position in step 6 (a rescue by
## skill), and the freed tip is then grabbed and pulled in on the next tick.
## The hand closes early when Inday stops being Free.

var dir := Vector3.RIGHT
var cfg := {}
var travelled := 0.0
var holding := false
var _hold_left := 0
var _palm: Marker3D
var _close_reason := "cancelled"

func begin(p_host: MatchHost, p_owner: Hero, p_dir: Vector3, p_cfg: Dictionary) -> void:
	setup(p_host, p_owner, -1.0)
	name = "HilaHand"
	dir = p_dir
	cfg = p_cfg
	# Gameplay target only: the hero's actual skinned hand and arm provide the visuals.
	_palm = Marker3D.new()
	_palm.position = Vector3.UP
	add_child(_palm)

func tick(dt: float) -> void:
	if expired:
		return
	if owner_hero == null or not owner_hero.is_free():
		_close("owner")
		return
	if not holding:
		var from := global_position
		var to := from + dir * minf(float(cfg.speed) * dt, maxf(0.0, float(cfg.range) - travelled))
		var wall := host.ray_hit(from, to, RB.L_WORLD | RB.L_SKILL_WALL)
		if not wall.is_empty():
			to = RB.flat(wall.position) - dir * 0.05 + Vector3(0, from.y, 0)
		global_position = to
		travelled += from.distance_to(to)
		if not wall.is_empty() or travelled >= float(cfg.range):
			holding = true
			_hold_left = 1 # Keep the endpoint through this tick's rescue resolution, never a stationary hold.
			host.emit_event("hila_open", {"hero": owner_hero, "pos": global_position})
	else:
		_hold_left -= 1
		if _hold_left <= 0:
			_close("expired")
			return
	var ally := _touching_ally()
	if ally:
		_pull(ally)

## The nearest Free teammate (not Inday) touching the hand.
func _touching_ally() -> Hero:
	var best: Hero = null
	var bd := INF
	var reach := float(cfg.grab) + host.tuning.body_radius
	for h in host.team_heroes(team):
		if h == owner_hero or h.state != Hero.State.FREE:
			continue
		if absf(h.global_position.y - global_position.y) > host.tuning.height_gap:
			continue
		var d := RB.flat_dist(h.global_position, global_position)
		if d <= reach and d < bd:
			bd = d
			best = h
	return best

func _pull(h: Hero) -> void:
	var to_inday := RB.flat(owner_hero.global_position - h.global_position)
	var dist := to_inday.length() - 2.0 * host.tuning.body_radius - float(cfg.gap)
	if dist > 0.05:
		h.apply_push(to_inday.normalized(), dist, false)
	host.emit_event("hila_pull", {"hero": owner_hero, "target": h, "distance": maxf(0.0, dist)})
	_close("pulled")

func _close(reason: String) -> void:
	if expired:
		return
	_close_reason = reason
	expire()

func palm_position() -> Vector3:
	return _palm.global_position if is_instance_valid(_palm) else global_position + Vector3.UP

func _on_expire() -> void:
	host.emit_event("hila_close", {"hero": owner_hero, "reason": _close_reason, "pos": palm_position()})
	# HeroVisual retracts the same skinned arm. No detached duplicate palm or beam.

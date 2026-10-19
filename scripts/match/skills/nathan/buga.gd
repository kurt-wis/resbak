extends Skill

## Nathan S1 BUGA! (docs/RESBAK.md § 4 Nathan). Offensive.
## Planted 0.75 s inhale/spit, with a 0.4 s inhale, then a Kimkim
## powder cone 5 m long and 60 deg wide along his committed aim. Walls block it
## (host.los_clear per target). Every free enemy whose centre is in the cone is slowed 30 % for
## 1.5 s, leaves a powder trail everyone can see for 4 s, and is revealed to Nathan's team for
## the same 4 s (hiding spots, clouds, minimap). No tag, no capture cancel, no stun.
## A tag, a stun or a stumble during the inhale cancels the blow (the cooldown is spent).

var _blow_tick := -1
var _finish_tick := -1
var _direction := Vector3.ZERO
var _trails := {} ## target slot -> PowderTrail

func kind() -> int:
	return RB.SkillKind.OFFENSIVE

func cast_plant_seconds() -> float:
	return float(v("buga_action_time"))

## The committed direction holds for the whole inhale/spit, including its last tick.
func locked_facing() -> Vector3:
	return _direction if _finish_tick >= 0 and host.tick < _finish_tick else Vector3.ZERO

func _cast(frame: InputFrame) -> void:
	active = true
	_direction = frame.aim_direction(hero.global_position)
	if _direction == Vector3.ZERO:
		_direction = hero.aim if hero.aim != Vector3.ZERO else hero.facing
	_direction = RB.flat(_direction).normalized()
	hero.aim = _direction
	hero.facing = _direction
	_blow_tick = host.tick + RB.ticks(v("buga_inhale"))
	_finish_tick = host.tick + RB.ticks(v("buga_action_time"))
	hero.visual.play_action("Buga", float(v("buga_action_time")))
	PowderFx.inhale_ring(host.world, hero.global_position, 1.6, float(v("buga_inhale")))
	host.emit_event("buga_inhale", {"hero": hero, "pos": hero.global_position})

func tick_action(_frame: InputFrame) -> void:
	if not active:
		return
	if not hero.is_free() or hero.is_disabled():
		end("disrupted")
		return
	if _blow_tick >= 0 and host.tick >= _blow_tick:
		_blow()
	if host.tick + 1 >= _finish_tick:
		# The cast plant ends on the next tick; release here so a press on that tick casts
		# instead of being read as a recast of a finished spit.
		active = false

func _blow() -> void:
	_blow_tick = -1
	var origin := hero.global_position
	var dir := _direction
	var length: float = v("buga_length")
	var width: float = v("buga_width_deg")
	var hits: Array[Hero] = []
	for e in host.enemies_of(hero):
		if e.is_free() and in_cone(origin, dir, e.global_position, length, width) and host.los_clear(origin, e.global_position):
			hits.append(e)
	PowderFx.blow_cone(host.world, origin, dir, length, width)
	host.emit_event("buga_blow", {"hero": hero, "pos": origin, "dir": dir, "hits": hits})
	for e in hits:
		_hit(e)

## Is `pos` (a hero's centre) inside the cone: flat distance <= length, angle <= width / 2.
static func in_cone(origin: Vector3, dir: Vector3, pos: Vector3, length: float, width_deg: float) -> bool:
	var to := RB.flat(pos - origin)
	var d := to.length()
	if d > length:
		return false
	if d < 0.001:
		return true
	return rad_to_deg(dir.angle_to(to / d)) <= width_deg * 0.5 + 0.001

func _hit(e: Hero) -> void:
	var trail_time: float = v("buga_trail_time")
	e.add_slow(float(v("buga_slow")), float(v("buga_slow_time")), "buga", true)
	e.reveal_to(hero.team, trail_time)
	var trail = _trails.get(e.slot) # untyped: may be a freed instance
	if trail != null and is_instance_valid(trail) and not trail.expired:
		trail.refresh(trail_time)
	else:
		var fresh := PowderTrail.new()
		fresh.begin(host, hero, e, trail_time)
		host.spawn_object(fresh, e.global_position)
		fresh.build_visuals()
		_trails[e.slot] = fresh
	host.emit_event("buga_hit", {"hero": hero, "target": e})

func end(_reason: String) -> void:
	if active:
		hero.visual.stop_action("Buga")
	active = false
	_blow_tick = -1
	_finish_tick = -1
	committed_until_tick = -1

func hud_note() -> String:
	if not active:
		return ""
	return "%.1f s" % RB.seconds(maxi(0, _finish_tick - host.tick))

extends Skill

## Nathan S1 BUGA! (docs/RESBAK.md § 4 Nathan). Offensive.
## Inhale 0.4 s (Nathan can move; enemies see and hear it: event 'buga_inhale'), then a Kimkim
## powder cone 5 m long and 60 deg wide along his aim at the moment he blows. Walls block it
## (host.los_clear per target). Every free enemy whose centre is in the cone is slowed 30 % for
## 1.5 s, leaves a powder trail everyone can see for 4 s, and is revealed to Nathan's team for
## the same 4 s (hiding spots, clouds, minimap). No tag, no capture cancel, no stun.
## A tag, a stun or a stumble during the inhale cancels the blow (the cooldown is spent).

var _blow_tick := -1
var _trails := {} ## target slot -> PowderTrail

func kind() -> int:
	return RB.SkillKind.OFFENSIVE

func _cast(_frame: InputFrame) -> void:
	active = true
	hero.plant_cast(float(v("buga_inhale")))
	_blow_tick = host.tick + RB.ticks(v("buga_inhale"))
	if hero.aim != Vector3.ZERO:
		hero.facing = hero.aim
	hero.visual.play_action("Buga", float(v("buga_inhale")) + 0.35)
	PowderFx.inhale_ring(host.world, hero.global_position, 1.6, float(v("buga_inhale")))
	host.emit_event("buga_inhale", {"hero": hero, "pos": hero.global_position})

func tick_action(_frame: InputFrame) -> void:
	if not active:
		return
	if hero.is_disabled():
		end("disrupted")
		return
	if host.tick >= _blow_tick:
		_blow()

func _blow() -> void:
	active = false
	_blow_tick = -1
	var origin := hero.global_position
	var dir := RB.flat(hero.aim).normalized()
	if dir == Vector3.ZERO:
		dir = RB.flat(hero.facing).normalized()
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

func hud_note() -> String:
	if not active:
		return ""
	return "%.1f s" % RB.seconds(maxi(0, _blow_tick - host.tick))

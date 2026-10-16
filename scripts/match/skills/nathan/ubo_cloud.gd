class_name UboCloud
extends SkillObject

## The UBO! UBO! powder cloud (docs/RESBAK.md § 4 Nathan): radius 3.5 m for 5 s, for both
## teams including Nathan. A viewer outside cannot see anyone whose centre is inside; a viewer
## inside sees only within 2 m (anyone, in or out of the cloud). An enemy of Nathan inside for
## more than 1 continuous second coughs once per cloud: revealed to Nathan's team for 2 s
## (reveal beats the cloud) and the 'cough' event fires. Coughers can still act.
## Allies always see each other: MatchHost.visibility() checks that before asking us.

var radius := 3.5
var sight := 2.0
var cough_ticks := 60
var cough_reveal := 2.0
var _inside := {} ## hero slot -> continuous ticks inside
var _coughed := {} ## hero slot -> true
var emitter: CPUParticles3D
var disc: Node3D

func begin(p_host: MatchHost, p_owner: Hero, cfg: Dictionary) -> void:
	radius = cfg.radius
	sight = cfg.sight
	cough_ticks = RB.ticks(cfg.cough_after)
	cough_reveal = cfg.cough_reveal
	setup(p_host, p_owner, cfg.time)
	name = "UboCloud"

## Call after host.spawn_object().
func build_visuals() -> void:
	disc = Vfx.ground_ring(self, global_position, radius, Color(PowderFx.PINK.r, PowderFx.PINK.g, PowderFx.PINK.b, 0.5), 0.2, 0.16)
	emitter = PowderFx.volume_emitter(self, radius * 0.85, PowderFx.PINK_SOFT, 150, 2.4, 1.7, 0.3)
	Vfx.burst(self, global_position + Vector3(0, 0.8, 0), PowderFx.PINK, 40, 4.0, 0.8, 0.9, 0.0, 180.0)

func contains(pos: Vector3) -> bool:
	return RB.flat_dist(global_position, pos) <= radius

func hides(viewer: Hero, target_pos: Vector3) -> bool:
	if viewer != null and contains(viewer.global_position):
		return RB.flat_dist(viewer.global_position, target_pos) > sight
	return contains(target_pos)

func tick(dt: float) -> void:
	for e in host.enemies_of(owner_hero):
		var slot := e.slot
		if e.is_free() and contains(e.global_position):
			_inside[slot] = int(_inside.get(slot, 0)) + 1
			if _inside[slot] > cough_ticks and not _coughed.has(slot):
				_coughed[slot] = true
				e.reveal_to(team, cough_reveal)
				Vfx.popup_text(host.world, e.global_position, "*UBO!*", PowderFx.PINK, 90, 0.9)
				host.emit_event("cough", {"hero": e, "owner": owner_hero, "cloud": self, "pos": e.global_position})
		else:
			_inside.erase(slot)
	super.tick(dt)
	if emitter and ticks_left > 0 and ticks_left <= RB.ticks(0.8):
		emitter.emitting = false

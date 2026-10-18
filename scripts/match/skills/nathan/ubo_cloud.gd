class_name UboCloud
extends SkillObject

## UBO powder: the caster inside sees targets inside, subject to solid line of sight.
## Every other inside viewer loses hero vision; outsiders cannot see into the cloud.
## Initial landing burst blinds enemies once. Cough reveal never defeats smoke concealment.
## Approved 2026-10-18 deviations are recorded in docs/status.md.

var radius := 3.5
var sight := 2.0
var cough_ticks := 60
var cough_reveal := 2.0
var blind_time := 0.0
var _inside := {} ## hero slot -> continuous ticks inside
var _coughed := {} ## hero slot -> true
var emitter: CPUParticles3D
var disc: Node3D
var _owner_view := false

func begin(p_host: MatchHost, p_owner: Hero, cfg: Dictionary) -> void:
	radius = cfg.radius
	sight = cfg.sight
	cough_ticks = RB.ticks(cfg.cough_after)
	cough_reveal = cfg.cough_reveal
	blind_time = float(cfg.get("blind_time", 0.0))
	setup(p_host, p_owner, cfg.time)
	name = "UboCloud"

## Call after host.spawn_object().
func apply_initial_burst() -> void:
	# One burst only. Walking back into this cloud never refreshes the blind.
	for enemy in host.enemies_of(owner_hero):
		if contains(enemy.global_position):
			enemy.blind(blind_time)
			enemy.cough_ticks = RB.ticks(host.tuning.smoke_cough_animation)

func build_visuals() -> void:
	disc = Vfx.ground_ring(self, global_position, radius, Color(PowderFx.PINK.r, PowderFx.PINK.g, PowderFx.PINK.b, 0.5), 0.2, 0.16)
	emitter = PowderFx.volume_emitter(self, radius * 0.85, PowderFx.PINK_SOFT, 150, 2.4, 1.7, 0.3)
	Vfx.burst(self, global_position + Vector3(0, 0.8, 0), PowderFx.PINK, 40, 4.0, 0.8, 0.9, 0.0, 180.0)

func contains(pos: Vector3) -> bool:
	return RB.flat_dist(global_position, pos) <= radius

func set_viewer(viewer: Hero) -> void:
	var owner_view := viewer == owner_hero and contains(viewer.global_position) if viewer else false
	if _owner_view == owner_view or not is_instance_valid(emitter):
		return
	_owner_view = owner_view
	# Thin the actual puffs too, so owner immunity is visually usable.
	emitter.color_ramp = PowderFx._envelope(PowderFx.WHITE, 0.055 if owner_view else 0.3)

func hides(viewer: Hero, target_pos: Vector3) -> bool:
	if viewer != null and contains(viewer.global_position):
		return not (viewer == owner_hero and contains(target_pos) and host.los_clear(viewer.global_position, target_pos))
	return contains(target_pos)

func tick(dt: float) -> void:
	for e in host.enemies_of(owner_hero):
		var slot := e.slot
		if e.is_free() and contains(e.global_position):
			_inside[slot] = int(_inside.get(slot, 0)) + 1
			if _inside[slot] > cough_ticks and not _coughed.has(slot):
				_coughed[slot] = true
				e.reveal_to(team, cough_reveal)
				e.cough_ticks = RB.ticks(host.tuning.smoke_cough_animation)
				host.emit_event("cough", {"hero": e, "owner": owner_hero, "cloud": self, "pos": e.global_position})
		else:
			_inside.erase(slot)
	super.tick(dt)
	if emitter and ticks_left > 0 and ticks_left <= RB.ticks(0.8):
		emitter.emitting = false

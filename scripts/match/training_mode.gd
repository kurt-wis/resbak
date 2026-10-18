class_name TrainingMode
extends RefCounted

## Host-tick training scenario. UI requests resets; only post_tick mutates simulation.
var host: MatchHost
var reset_requested := false
var reset_at := -1
var starts := {}
var facings := {}

func _init(value: MatchHost) -> void:
	host = value
	var local := host.hero_by_slot(0)
	var marker := host.map_root.get_node_or_null("Gameplay/TrainingSpawn") as Node3D
	var origin := marker.global_position if marker else local.global_position
	var forward := RB.flat(marker.global_basis.z if marker else host.base_system.pole_pos(RB.LILA) - origin).normalized()
	var side := forward.cross(Vector3.UP)
	starts[local.slot] = origin
	facings[local.slot] = forward
	for i in range(1, host.heroes.size()):
		var h: Hero = host.heroes[i]
		starts[h.slot] = origin + forward * host.tuning.training_dummy_distance + side * (i - 2) * host.tuning.training_dummy_spacing
		facings[h.slot] = -forward
	for h in host.heroes:
		for skill in h.skills:
			skill.cooldown *= host.tuning.training_cooldown_scale
	host.event.connect(_on_event)
	reset()

func _on_event(kind: String, _data: Dictionary) -> void:
	if kind in ["tag", "capture", "guard_break"] and reset_at < 0:
		reset_at = host.tick + RB.ticks(host.tuning.training_reset_delay)

func post_tick() -> void:
	if reset_requested or (reset_at >= 0 and host.tick >= reset_at):
		reset()

func reset() -> void:
	host.round_flow._reset_world()
	for h in host.heroes:
		h.reset_for_round(starts[h.slot], facings[h.slot])
		host.stats[h.slot] = host._new_stats()
	host.round_flow.phase = RoundFlow.Phase.PLAYING
	host.round_flow.phase_ticks = 0
	host.round_flow.score = [0, 0]
	reset_at = -1
	reset_requested = false
	host.emit_event("round_reset", {})

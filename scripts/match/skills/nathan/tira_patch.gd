class_name TiraPatch
extends SkillObject

## MAY TIRA PA! powder patch (docs/RESBAK.md § 4 Nathan): radius 1 m, visible to all, lasts
## until triggered or round end (ticks_left stays -1). The first enemy whose centre is inside
## sets it off: puff, a loud footstep, the enemy shown to Nathan's team for 2 s, patch gone.
## No slow, no tag.

var radius := 1.0
var reveal_secs := 2.0
var disc: Node3D

func begin(p_host: MatchHost, p_owner: Hero, p_radius: float, p_reveal_secs: float) -> void:
	setup(p_host, p_owner, -1.0)
	name = "TiraPatch"
	radius = p_radius
	reveal_secs = p_reveal_secs

## Call after host.spawn_object().
func build_visuals() -> void:
	disc = Vfx.ground_ring(self, global_position, radius, Color(PowderFx.PINK.r, PowderFx.PINK.g, PowderFx.PINK.b, 0.7), 0.16, 0.45)
	var glow := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.55
	cyl.bottom_radius = radius * 0.55
	cyl.height = 0.012
	glow.mesh = cyl
	glow.material_override = Vfx.flat_material(Color(1.0, 0.97, 1.0, 0.55))
	glow.position = Vector3(0, 0.075, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	var sparkle := Vfx.emitter(self, PowderFx.WHITE, 8, 1.2, 0.12, 0.3, Vector3(0, 0.1, 0), false)
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkle.emission_sphere_radius = radius * 0.7
	sparkle.emitting = true

func tick(dt: float) -> void:
	var best: Hero = null
	var best_d := INF
	for e in host.enemies_of(owner_hero):
		if not e.is_free():
			continue
		if absf(e.global_position.y - global_position.y) > 1.0:
			continue
		var d := RB.flat_dist(e.global_position, global_position)
		if d <= radius and d < best_d:
			best = e
			best_d = d
	if best:
		_trigger(best)
		return
	super.tick(dt)

func _trigger(e: Hero) -> void:
	e.reveal_to(team, reveal_secs)
	Vfx.burst(host.world, global_position + Vector3(0, 0.3, 0), PowderFx.PINK, 40, 3.5, 0.7, 0.6, 0.5, 70.0)
	Vfx.burst(host.world, global_position + Vector3(0, 0.3, 0), PowderFx.WHITE, 20, 2.5, 0.6, 0.4, 0.3, 90.0)
	Vfx.popup_text(host.world, e.global_position, "PUFF!", PowderFx.PINK, 100, 0.8)
	host.emit_event("loud_footstep", {"hero": e, "owner": owner_hero, "pos": global_position, "silent": e.footsteps_silent()})
	host.emit_event("patch_trigger", {"hero": e, "owner": owner_hero, "pos": global_position})
	expire()

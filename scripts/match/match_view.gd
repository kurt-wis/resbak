class_name MatchView
extends Node3D

## What the local player sees of the host state (docs/RESBAK.md Â§ 2 "Outlines", Â§ 7 Feedback):
## per-hero visibility (clouds hide, IYAK! see-through at 25 %, reveals), outline colour
## (taggable enemy orange + "!" icon, untaggable grey, EP shield), the local aim marker, and
## world feedback for host events (HULI!, whiff, NAKUHA!, RESBAK!, guard break, PERFECT!).
## Presentation only: reads the host, never changes it.

const ORANGE := Color("ff8a1f")
const GREY := Color(0.24, 0.24, 0.3) ## untaggable: a dark slate (a light grey bleeds through hair on the hull outline)
const INK := Color(0.055, 0.045, 0.075)

var host: MatchHost
var local: Hero
var camera: MatchCamera
var aim_marker: Node3D
var arena: ArenaArt
var danger := false ## any enemy within danger range can tag the local hero (HUD reads it)

func setup(p_host: MatchHost, p_local: Hero, p_camera: MatchCamera) -> void:
	host = p_host
	local = p_local
	camera = p_camera
	host.event.connect(_on_event)
	arena = ArenaArt.new()
	add_child(arena)
	arena.setup(host)
	aim_marker = Node3D.new()
	aim_marker.name = "AimMarker"
	add_child(aim_marker)
	var fan := Vfx.fan_mesh(1.0, host.tuning.tag_arc_deg * 2.0, Color(1, 1, 1, 0.18))
	fan.position.y = 0.05
	aim_marker.add_child(fan)
	if local:
		local.visual.set_ring_color(Color.WHITE.lerp(RB.TEAM_COLORS[local.team], 0.35))

func _process(delta: float) -> void:
	if host == null:
		return
	if arena:
		arena.refresh(delta)
	danger = false
	for h in host.heroes:
		var alpha := host.visibility(local, h) if local else 1.0
		h.visual.set_view_alpha(alpha)
		if local == null or h.team == local.team:
			h.visual.set_outline(INK)
			h.visual.set_markers(false, h.has_ep() or h.is_immune())
			continue
		var taggable := host.can_tag(local, h)
		h.visual.set_outline(ORANGE if taggable else GREY)
		h.visual.set_markers(taggable, h.has_ep() or h.is_immune())
		if local.is_free() and host.can_tag(h, local) and RB.flat_dist(h.global_position, local.global_position) <= host.tuning.danger_border_range:
			danger = true
	_update_aim()

func _update_aim() -> void:
	if local == null:
		aim_marker.visible = false
		return
	aim_marker.visible = local.is_free() and host.round_live()
	var reach := local.charged_reach() + host.tuning.body_radius * 2.0 # grows with the hampas charge
	aim_marker.global_position = local.global_position
	aim_marker.scale = Vector3(reach, 1, reach)
	aim_marker.rotation.y = atan2(local.aim.x, local.aim.z)

func _on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"kaboom":
			_confetti()
		"tag":
			Vfx.popup_text(self, d.target.global_position, "HULI!", ORANGE)
			Vfx.burst(self, d.target.global_position + Vector3(0, 1.0, 0), Color("ffd27a"), 30, 4.0, 0.5)
			if camera and (d.target == local or d.tagger == local):
				camera.shake(0.25, 0.2)
		"guard_break":
			Vfx.popup_text(self, d.target.global_position, "SIRA!", Color("9fd8ff"))
			Vfx.burst(self, d.target.global_position + Vector3(0, 1.0, 0), Color("9fd8ff"), 36, 5.0, 0.6)
		"tag_failed":
			Vfx.burst(self, d.tagger.global_position + d.tagger.lunge_dir * 1.0 + Vector3(0, 0.9, 0), Color(1, 1, 1, 0.7), 10, 2.0, 0.3, 0.1)
		"sabay":
			Vfx.popup_text(self, (d.a.global_position + d.b.global_position) * 0.5, "SABAY!", Color.WHITE)
		"perfect_slide":
			Vfx.popup_text(self, d.evader.global_position, "PERFECT!", Color("ffd700"), 120)
			Vfx.burst(self, d.evader.global_position + Vector3(0, 0.5, 0), Color("ffd700"), 40, 5.0, 0.6)
		"rescue":
			Vfx.popup_text(self, d.rescuer.global_position, "RESBAK!", RB.TEAM_COLORS[d.rescuer.team], 120)
			for f in d.freed:
				Vfx.burst(self, f.global_position + Vector3(0, 1.0, 0), RB.TEAM_COLORS[f.team], 20, 3.0, 0.5)
		"capture":
			Vfx.popup_text(self, d.hero.global_position, "NAKUHA!", RB.TEAM_COLORS[d.team], 140, 1.4)
			Vfx.ring_pulse(self, host.base_system.pole_pos(RB.other_team(d.team)), 6.0, RB.TEAM_COLORS[d.team], 0.8)
		"capture_start":
			Vfx.ring_pulse(self, host.base_system.pole_pos(RB.other_team(d.hero.team)), 2.0, RB.TEAM_COLORS[d.hero.team], 0.4)
		"jailed":
			Vfx.burst(self, d.hero.global_position + Vector3(0, 0.8, 0), Color(0.8, 0.9, 1.0, 0.8), 16, 2.0, 0.4)
		"barrier_bump":
			pass

## KABOOM! confetti (spec Â§ 7); none with Reduce flashing or Reduce camera motion.
func _confetti() -> void:
	var save := get_node_or_null("/root/Save")
	if save and (bool(save.get_setting("accessibility", "reduce_flashing")) or bool(save.get_setting("accessibility", "reduce_motion"))):
		return
	var centre := local.global_position if local else Vector3.ZERO
	Vfx.confetti(self, centre + Vector3(0, 3.0, 0), [Color("ffd34d"), Color("9b59d6"), Color("ff5a3c"), Color("5ad1ff"), Color("ffffff")], 110)

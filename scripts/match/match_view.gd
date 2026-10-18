class_name MatchView
extends Node3D

## What the local player sees of the host state (docs/RESBAK.md Â§ 2 "Outlines", Â§ 7 Feedback):
## per-hero visibility (clouds hide, IYAK! see-through at 25 %, reveals), outline colour
## (selected overhead nametag, muted enemy outline, EP shield), the local aim strip, and
## world feedback for host events (HULI!, whiff, NAKUHA!, RESBAK!, guard break, PERFECT!).
## Presentation only: reads the host, never changes it.

const ORANGE := Color("ff8a1f")
const GREY := Color(0.24, 0.24, 0.3) ## untaggable: a dark slate (a light grey bleeds through hair on the hull outline)
const INK := Color(0.055, 0.045, 0.075)

var host: MatchHost
var local: Hero
var camera: MatchCamera
var aim_marker: Node3D
var _border: MeshInstance3D
var _strip: MeshInstance3D
var _strip_mat: StandardMaterial3D
var _strip_reach := -1.0
var aim_strip_alpha := 0.0
var preview_target: Hero

var skill_aim: SkillAimView
var arena: ArenaArt
var danger := false ## any enemy within danger range can tag the local hero (HUD reads it)

func setup(p_host: MatchHost, p_local: Hero, p_camera: MatchCamera) -> void:
	host = p_host
	local = p_local
	camera = p_camera
	host.event.connect(_on_event)
	skill_aim = SkillAimView.new()
	add_child(skill_aim)
	skill_aim.setup(host, local)
	arena = ArenaArt.new()
	add_child(arena)
	arena.setup(host)
	aim_marker = Node3D.new()
	aim_marker.name = "AimMarker"
	aim_marker.visible = false
	add_child(aim_marker)
	_strip = Vfx.tag_strip(1.0, host.tuning.tag_strip_half_width, Color(0.94, 0.12, 0.12, host.tuning.tag_strip_fill_alpha))
	_strip.name = "TagStrip"
	_strip.position.y = 0.05
	aim_marker.add_child(_strip)
	_strip_mat = _strip.material_override as StandardMaterial3D
	_strip_mat.render_priority = 2
	_border = Vfx.tag_strip_border(1.0, host.tuning.tag_strip_half_width, host.tuning.tag_strip_outline_width, Color(0.94, 0.12, 0.12, host.tuning.tag_strip_outline_alpha))
	_border.name = "TagOutline"
	_border.position.y = 0.052
	aim_marker.add_child(_border)
	(_border.material_override as StandardMaterial3D).render_priority = 3

func _process(delta: float) -> void:
	if host == null:
		return
	if arena:
		arena.refresh(delta)
	_update_aim()
	skill_aim.refresh()
	danger = false
	for h in host.heroes:
		var alpha := host.visibility(local, h) if local else 1.0
		h.visual.set_view_alpha(alpha)
		if local == null or h.team == local.team:
			h.visual.set_outline(INK)
			h.visual.set_markers(false, h.has_ep() or h.is_immune())
			continue
		var taggable := h == preview_target
		h.visual.set_outline(GREY)
		h.visual.set_markers(taggable, h.has_ep() or h.is_immune())
		if local.is_free() and host.can_tag(h, local) and RB.flat_dist(h.global_position, local.global_position) <= host.tuning.danger_border_range:
			danger = true
	_update_intro()

## Round-1 flyover pose (presentation only): the arena from the enemy end to our own, each
## team's spawn, then the faceoff at the centre, easing back to the hero over the last 0.7 s.
func _update_intro() -> void:
	if camera == null:
		return
	var rf := host.round_flow
	if rf.phase != RoundFlow.Phase.INTRO:
		camera.intro_w = 0.0
		return
	var secs := rf.intro_elapsed()
	var st := rf.intro_stage_at(secs)
	var u: float = smoothstep(0.0, 1.0, float(st.u))
	var own_team := local.team if local else RB.DILAW
	var own_pole := host.base_system.pole_pos(own_team)
	var enemy_pole := host.base_system.pole_pos(RB.other_team(own_team))
	var centre := (own_pole + enemy_pole) * 0.5
	match int(st.stage):
		RoundFlow.IntroStage.ARENA:
			camera.intro_focus = enemy_pole.lerp(own_pole, u)
			camera.intro_size = lerpf(17.0, 14.0, u)
		RoundFlow.IntroStage.TEAM_A:
			camera.intro_focus = _spawn_centre(own_team).lerp(_spawn_centre(own_team) + Vector3(0, 0, 1.0), u)
			camera.intro_size = lerpf(8.5, 7.5, u)
		RoundFlow.IntroStage.TEAM_B:
			var other := RB.other_team(own_team)
			camera.intro_focus = _spawn_centre(other).lerp(_spawn_centre(other) + Vector3(0, 0, 1.0), u)
			camera.intro_size = lerpf(8.5, 7.5, u)
		_:
			camera.intro_focus = centre
			camera.intro_size = lerpf(13.0, 11.0, u)
	camera.intro_focus.y = 1.0
	var total := RB.seconds(rf.intro_total_ticks())
	var fade_in := clampf(secs / 0.4, 0.0, 1.0)
	var fade_out := clampf((total - secs) / 0.7, 0.0, 1.0)
	camera.intro_w = smoothstep(0.0, 1.0, minf(fade_in, fade_out))

func _spawn_centre(team: int) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for h in host.team_heroes(team):
		sum += h.global_position
		n += 1
	return sum / float(maxi(n, 1))

func _update_aim() -> void:
	aim_strip_alpha = 0.0
	preview_target = null
	if local == null or not local.is_free() or not host.round_live() or (not local.can_press_tag() and not local.is_winding_up()):
		aim_marker.visible = false
		return
	var winding := local.is_winding_up()
	var input := host.input_sources.get(local.slot) as PlayerInput
	if not winding and not (input and input.tag_aiming):
		aim_marker.visible = false
		return
	aim_marker.visible = true
	var direction := local.lunge_dir if winding else host.tag_system.aim_direction(local)
	var reach := (local.strike_reach if winding else local.tag_reach()) + host.tuning.body_radius * 2.0
	aim_marker.global_position = local.global_position
	aim_marker.rotation.y = atan2(direction.x, direction.z)
	if absf(reach - _strip_reach) > 0.005:
		_strip_reach = reach
		var mesh := Vfx.tag_strip(reach, host.tuning.tag_strip_half_width, Color.WHITE)
		_strip.mesh = mesh.mesh
		mesh.free()
		var border := Vfx.tag_strip_border(reach, host.tuning.tag_strip_half_width, host.tuning.tag_strip_outline_width, Color.WHITE)
		_border.mesh = border.mesh
		border.free()
	preview_target = host.tag_system.preview_target(local, direction)
	var source := host.input_sources.get(local.slot) as PlayerInput
	if not winding and source and source.valid_touch_target(local, host, source.touch_target, reach):
		preview_target = source.touch_target
		var toward := RB.flat(preview_target.global_position - local.global_position).normalized()
		aim_marker.rotation.y = atan2(toward.x, toward.z)
	if source and source.tag_aim_cancelled:
		preview_target = null
		_strip_mat.albedo_color = Color(1, 0.2, 0.2, host.tuning.tag_strip_fill_alpha)
		return
	if preview_target and (host.visibility(local, preview_target) <= 0.01 or preview_target.is_warded()):
		preview_target = null
	aim_strip_alpha = host.tuning.tag_strip_attack_alpha if winding else host.tuning.tag_strip_fill_alpha
	_strip_mat.albedo_color = Color(0.94, 0.12, 0.12, aim_strip_alpha)
	(_border.material_override as StandardMaterial3D).albedo_color = Color(0.94, 0.12, 0.12, host.tuning.tag_strip_outline_alpha)

## Event -> sound name (res://assets/audio/<name>.ogg|wav; silent until the file lands, every
## play still raises Audio.cue for subtitles). Candidates and slots: docs/status.md "Audio".
const SFX := {
	"kaboom": "sfx_kaboom", "tag": "sfx_tag_hit", "tag_windup": "sfx_tag_swing", "tag_failed": "sfx_tag_miss",
	"jailed": "sfx_jailed", "rescue": "sfx_rescue", "capture_start": "sfx_capture_start",
	"capture_cancel": "sfx_capture_cancel", "capture": "sfx_capture", "sudden_death": "sfx_sudden_death",
	"guard_break": "sfx_guard_break", "sabay": "sfx_sabay", "perfect_slide": "sfx_perfect",
}

func _sfx(kind: String, d: Dictionary) -> void:
	if not SFX.has(kind):
		return
	var audio := get_node_or_null("/root/Audio")
	if audio == null:
		return
	var at := Vector3.INF
	for k in ["target", "hero", "rescuer", "tagger", "evader"]:
		if d.get(k) is Hero:
			at = (d[k] as Hero).global_position
			break
	audio.play(SFX[kind], "", at)
	if kind == "capture" and arena and arena.has_prop(RB.other_team(d.team)):
		audio.play("sfx_castle_crumble", "", host.base_system.pole_pos(RB.other_team(d.team)))

func _on_event(kind: String, d: Dictionary) -> void:
	_sfx(kind, d)
	match kind:
		"kaboom":
			_confetti()
		"tag":
			Vfx.popup_text(self, d.target.global_position, "HULI!", ORANGE)
			Vfx.burst(self, d.get("point", d.target.global_position + Vector3(0, 1.0, 0)), Color("ffd27a"), 30, 4.0, 0.5)
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
			if arena:
				arena.crumble(RB.other_team(d.team)) # a map base prop (sand castle) crumbles
		"capture_start":
			Vfx.ring_pulse(self, host.base_system.pole_pos(RB.other_team(d.hero.team)), 2.0, RB.TEAM_COLORS[d.hero.team], 0.4)
		"jailed":
			Vfx.burst(self, d.hero.global_position + Vector3(0, 0.8, 0), Color(0.8, 0.9, 1.0, 0.8), 16, 2.0, 0.4)

## KABOOM! confetti (spec Â§ 7); none with Reduce flashing or Reduce camera motion.
func _confetti() -> void:
	var save := get_node_or_null("/root/Save")
	if save and (bool(save.get_setting("accessibility", "reduce_flashing")) or bool(save.get_setting("accessibility", "reduce_motion"))):
		return
	var centre := local.global_position if local else Vector3.ZERO
	Vfx.confetti(self, centre + Vector3(0, 3.0, 0), [Color("ffd34d"), Color("9b59d6"), Color("ff5a3c"), Color("5ad1ff"), Color("ffffff")], 110)

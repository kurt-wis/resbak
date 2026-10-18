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
const ARROW_WIDTH := 0.22 ## aim arrow: shaft width, head size and where the shaft starts (m)
const ARROW_HEAD := 0.5
const ARROW_HEAD_WIDTH := 0.8
const ARROW_START := 0.55
const ARROW_OUTSET := 1.4 ## the ink outline is this much wider than the bright fill
const ARROW_INK_EDGE := 0.05 ## and this much longer, so the tip keeps its dark edge
const ARROW_IDLE_ALPHA := 0.2 ## opacity with no charge
const ARROW_FULL_ALPHA := 0.85 ## opacity at full charge
const ARROW_PULSE_ALPHA := 0.08 ## extra opacity of the full-charge pulse
const ARROW_PULSE_WHITE := 0.45 ## how far the fill turns white in that pulse
const ARROW_PULSE_HZ := 16.0
const ARROW_CORE_TINT := 0.85 ## how much team colour the fill carries (rest is white: it lifts the colour off dark floors)

var host: MatchHost
var local: Hero
var camera: MatchCamera
var aim_marker: Node3D
var _arrow: MeshInstance3D
var _arrow_rim: MeshInstance3D
var _arrow_mat: StandardMaterial3D
var _arrow_rim_mat: StandardMaterial3D
var _arrow_len := -1.0
var _arrow_t := 0.0
var aim_arrow_alpha := 0.0 ## current arrow opacity (tests)
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
	# the tag aim arrow (2026-10-17: replaces the old fan): points where the lunge goes, reaches
	# as far as a swing released now would, and fills in as the hampas charge builds. Two layers
	# (dark outline under a bright core) so it stays readable on the orange Konstruksyon floor.
	var meshes := Vfx.aim_arrow_meshes(1.0, ARROW_WIDTH, ARROW_HEAD, ARROW_HEAD_WIDTH, ARROW_START,
			ARROW_OUTSET, ARROW_INK_EDGE)
	_arrow = _arrow_layer("AimArrow", meshes[0], Color.WHITE, 2)
	_arrow_rim = _arrow_layer("AimArrowOutline", meshes[1], INK, 1)
	_arrow.position.y = 0.05
	_arrow_rim.position.y = -0.01
	_arrow.add_child(_arrow_rim) ## the outline rides just under the fill
	aim_marker.add_child(_arrow)
	_arrow_mat = _arrow.material_override as StandardMaterial3D
	_arrow_rim_mat = _arrow_rim.material_override as StandardMaterial3D
	if local:
		local.visual.set_ring_color(Color.WHITE.lerp(RB.TEAM_COLORS[local.team], 0.35))

## One layer of the aim arrow: a flat unshaded quad in `color`, drawn at `priority` among the
## transparent floor decals (the fill draws over the outline).
func _arrow_layer(node_name: String, mesh: ArrayMesh, color: Color, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := Vfx.flat_material(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = priority
	mi.material_override = mat
	return mi

## Resize both arrow layers: the reach grows with the charge and the outline is a little longer.
func _build_arrow(reach: float) -> void:
	_arrow_len = reach
	var meshes := Vfx.aim_arrow_meshes(reach, ARROW_WIDTH, ARROW_HEAD, ARROW_HEAD_WIDTH, ARROW_START,
			ARROW_OUTSET, ARROW_INK_EDGE)
	_arrow.mesh = meshes[0]
	_arrow_rim.mesh = meshes[1]

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
	aim_arrow_alpha = 0.0
	if local == null or not local.is_free() or not host.round_live():
		aim_marker.visible = false
		return
	aim_marker.visible = true
	var reach := local.charged_reach() + host.tuning.body_radius * 2.0 # grows with the hampas charge
	aim_marker.global_position = local.global_position
	aim_marker.rotation.y = atan2(local.aim.x, local.aim.z)
	if absf(reach - _arrow_len) > 0.005:
		_build_arrow(reach)
	# a team-coloured fill at rest, filling in as the charge builds and pulsing when full
	var f := local.charge_fraction()
	var team_col: Color = RB.TEAM_COLORS[local.team]
	var core := Color.WHITE.lerp(team_col, ARROW_CORE_TINT)
	var alpha := ARROW_IDLE_ALPHA + (ARROW_FULL_ALPHA - ARROW_IDLE_ALPHA) * f
	_arrow_t += get_process_delta_time()
	if f >= 1.0:
		var pulse := 0.5 + 0.5 * sin(_arrow_t * ARROW_PULSE_HZ)
		alpha = minf(1.0, alpha + ARROW_PULSE_ALPHA * pulse)
		core = core.lerp(Color.WHITE, ARROW_PULSE_WHITE * pulse)
	core.a = alpha
	_arrow_mat.albedo_color = core
	_arrow_rim_mat.albedo_color = Color(INK.r, INK.g, INK.b, alpha)
	aim_arrow_alpha = alpha

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

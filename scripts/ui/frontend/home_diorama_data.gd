class_name HomeDioramaData
extends Resource

## Every tuning number of the Home diorama (docs/plans/2026-10-17-home-diorama.md). One resource,
## data/home_diorama.tres; the defaults here are what the .tres ships with, so a script that
## builds one with HomeDioramaData.new() (QC tools) sees the same numbers.
## World frame: the camera looks down -Z, +X is screen-right, the court's heroes face +Z (the
## camera), the road runs along X behind them.

const PATH := "res://data/home_diorama.tres"
const SPEECH_TALK := "talk"
const SPEECH_LAUGH := "laugh"
const SPEECH_SMILE := "smile"

static func load_data() -> HomeDioramaData:
	if ResourceLoader.exists(PATH):
		var d := load(PATH) as HomeDioramaData
		if d:
			return d
	return HomeDioramaData.new()

@export_group("Loop")
@export var loop_length := 48.0 ## seconds; the Timeline animation is exactly this long
@export var quiet_start := 2.0 ## nothing starts before this (the screen settles)...
@export var quiet_end := 46.0 ## ...and everything has finished by this

@export_group("Camera")
## Solved against the reference with the projection solver (renders/qc/fit_layout.py): 1.7 m eye
## height, 2.4 degrees down, horizon at reference y 340. `--home-ref` overlays the reference to check.
@export var cam_position := Vector3(0.75, 1.70, 7.2)
@export var cam_target := Vector3(0.75, 1.40, 0.0)
@export var cam_fov := 40.0
@export var ref_overlay := "res://source_art/reference/home_target.webp" ## drawn by --home-ref only
@export var ref_overlay_alpha := 0.5

@export_group("Light")
@export var sun_color := Color("ffc27a")
@export var sun_energy := 1.30
@export var sun_rotation := Vector3(-20.0, 128.0, 0.0) ## degrees: elevation 20, from screen-right and behind
@export var sun_shadow_max := 40.0
@export var sun_shadow_opacity := 0.82
@export var fill_color := Color("9fc0e6") ## cool fill from camera-left, no shadow
@export var fill_energy := 0.34
@export var fill_rotation := Vector3(-18.0, -35.0, 0.0)
@export var ambient_color := Color("8fb4d9")
@export var ambient_energy := 0.52
@export var exposure := 1.12 ## filmic tonemap exposure (keeps the sky from washing out)
@export var sky_top := Color("5d86b8")
@export var sky_horizon := Color("f0a566")
@export var fog_color := Color("f0c9a0") ## warm-peach depth haze
@export var fog_density := 0.0035
@export var sky_mid := Color("7f9cc4") ## the blue the gradient reaches a few degrees above the horizon
@export var sky_glow := Color("ffb866") ## low-sun glow added around the sun and under the clouds
@export var sky_cloud_lit := Color("ffe2b8")
@export var sky_cloud_shade := Color("b9837f")
@export var sky_cloud_cover := 0.62 ## 0 clear .. 1 overcast
@export var dof_enabled := true ## depth blur behind the heroes (shaders/diorama_dof.gdshader)
@export var dof_start := 9.0 ## metres from the camera where defocus begins (heroes sit at 5-7)
@export var dof_end := 26.0 ## metres where it reaches full strength
@export var dof_radius := 0.0065 ## full-strength blur radius as a fraction of viewport height (~7 px at 1080p)
@export var window_light_color := Color("ffb15a")
@export var window_light_energy := 1.6
@export var window_light_range := 6.0
@export var window_light_pos := Vector3(1.0, 1.7, -0.9)
@export var bulb_pos := Vector3(2.7, 2.35, -1.2) ## emissive bulb under the store awning
@export var bulb_color := Color("ffd9a0")
@export var bulb_visible := false ## the light stays on; the bare glowing dot read as a stray speck
@export var dust_amount := 36
@export var dust_box := Vector3(5.0, 1.6, 3.5)
@export var dust_pos := Vector3(1.2, 1.7, 0.2)
@export var scale_3d := 1.0 ## 3D resolution scale; lowered only if the 60 fps check needs it

@export_group("Ground")
## [name, centre, size (x, z), colour, texture?, tile?]: flat toon slabs under the set. The near
## street carries the Meshy-painted decal (chalk hopscotch, paint splats, dirt verge, assets/props/
## home/street_decal.png) instead of the old concrete tile; `tile` is metres per texture repeat.
@export var ground := [
	{"name": "Street", "pos": Vector3(0.0, -0.01, 0.5), "size": Vector2(60, 26), "color": Color("a9a69f"),
			"texture": "res://assets/props/home/street_decal.png", "tile": 10.0},
	{"name": "Road", "pos": Vector3(0, 0.0, -11.2), "size": Vector2(70, 6.6), "color": Color("4b4d58")},
	{"name": "SideRoad", "pos": Vector3(9.1, 0.0, -11.0), "size": Vector2(6.2, 26), "color": Color("4b4d58")},
	{"name": "FarGround", "pos": Vector3(0, -0.01, -19.0), "size": Vector2(70, 8), "color": Color("b79468"),
			"texture": "res://assets/props/home/ground_dirt.png", "tile": 4.0},
]
@export var side_road_dash_x := 9.1 ## dashes down the middle of the side street (along Z)
## Flat painted boxes: {name, pos (centre), size (w, h, thickness), yaw, texture}. Unused now: the
## graffiti is a real Meshy 3D wall (set piece `graffiti_wall`), not a texture plastered on a box.
@export var walls := []
## Cardboard stacks and crates: {pos, size, yaw, color}. Flat toon boxes.
@export var boxes := [
	{"pos": Vector3(-2.3, 0.28, -0.35), "size": Vector3(0.95, 0.56, 0.75), "yaw": 14.0, "color": Color("b98a58")},
	{"pos": Vector3(-2.2, 0.76, -0.38), "size": Vector3(0.7, 0.4, 0.6), "yaw": -9.0, "color": Color("c79a66")},
	{"pos": Vector3(-1.5, 0.22, -0.55), "size": Vector3(0.5, 0.44, 0.5), "yaw": 30.0, "color": Color("a97a4c")},
]
@export var splat_fade := 0.5 ## 0..1: how far splats blend toward the yard colour (weathered paint)
## Paint splatter on the ground: {pos, r, color}. Flat discs just above the yard.
@export var splats := [
	{"pos": Vector3(-0.8, 0, 1.6), "r": 0.28, "color": Color("ff3fa4")},
	{"pos": Vector3(-0.3, 0, 2.1), "r": 0.09, "color": Color("ff3fa4")},
	{"pos": Vector3(1.8, 0, 2.2), "r": 0.25, "color": Color("ffd21f")},
	{"pos": Vector3(2.3, 0, 1.6), "r": 0.08, "color": Color("ffd21f")},
	{"pos": Vector3(3.4, 0, 2.0), "r": 0.30, "color": Color("3a6bff")},
	{"pos": Vector3(4.1, 0, 2.5), "r": 0.10, "color": Color("3a6bff")},
	{"pos": Vector3(-2.0, 0, 1.2), "r": 0.21, "color": Color("5fd64a")},
	{"pos": Vector3(0.6, 0, 3.0), "r": 0.20, "color": Color("ff8a1f")},
	{"pos": Vector3(2.9, 0, 3.4), "r": 0.15, "color": Color("9b4dff")},
	{"pos": Vector3(-1.2, 0, 2.8), "r": 0.11, "color": Color("ffd21f")},
	{"pos": Vector3(1.2, 0, 1.3), "r": 0.10, "color": Color("5fd64a")},
	{"pos": Vector3(4.6, 0, 1.2), "r": 0.14, "color": Color("ff3fa4")},
]
## The street wall behind the court: one building per entry, front plane at `backdrop_z`. {x (centre),
## w, h, tex (a..e = assets/props/home/facade_<tex>.png), color (the side walls), tank (rooftop water tank)}.
## Gaps are left at x 6.2..12.4 for the side street the background tricycle drives down.
@export var backdrop_z := -17.6
@export var backdrop_depth := 5.0
@export var backdrop := [
	{"x": -26.5, "w": 7.0, "h": 6.5, "tex": "a", "color": Color("a89c84"), "tank": false},
	{"x": -19.25, "w": 7.5, "h": 7.5, "tex": "c", "color": Color("b09184"), "tank": true},
	{"x": -11.75, "w": 7.5, "h": 5.5, "tex": "b", "color": Color("b8946c"), "tank": false},
	{"x": -4.25, "w": 7.5, "h": 7.0, "tex": "e", "color": Color("8e9c88"), "tank": true},
	{"x": 2.85, "w": 6.7, "h": 6.0, "tex": "d", "color": Color("b8b09c"), "tank": false},
	{"x": 15.9, "w": 7.0, "h": 6.8, "tex": "a", "color": Color("a89c84"), "tank": false},
	{"x": 23.4, "w": 8.0, "h": 5.8, "tex": "c", "color": Color("b09184"), "tank": true},
	{"x": 31.4, "w": 8.0, "h": 7.5, "tex": "e", "color": Color("8e9c88"), "tank": false},
]
@export var road_dash_z := -11.2
@export var road_dash_len := 2.4
@export var road_dash_gap := 2.2
@export var road_dash_color := Color("e7d7a8")

@export_group("Set")
@export var set_saturation := 0.95 ## light grade only: the meshy-7.1 textures already carry the reference palette
## {scene, pos, yaw (deg), scale (float or Vector3), outline, toon, sat, tint, path}: props from
## assets/props/home. `toon` keeps the hero toon shader (plants, stools); every other piece uses the
## graded diorama_set shader. The palette remap is off now that the textures are generated from the
## reference itself (add "remap": true to a piece to bring it back).
@export var set_pieces := [
	# The store, raised on its procedural counter (`store_base`) and scaled so the reference crop's
	# box lands on the reference's: base floating 1.11 m up at z -3.875, roof line at reference y 37.
	{"scene": "store_base", "pos": Vector3(2.32, 0, -3.05), "yaw": 0.0, "scale": 1.05},
	{"scene": "store", "pos": Vector3(2.32, 0.80, -3.875), "yaw": 0.0, "scale": 1.27},
	# Red/blue crate stack at the store's right, one empty stool between Nene and Nathan.
	{"scene": "crate_stack", "pos": Vector3(3.64, 0, -0.27), "yaw": -6.0, "scale": Vector3(0.67, 1.0, 1.20)},
	{"scene": "plastic_stool", "pos": Vector3(0.96, 0, -0.77), "yaw": 24.0, "scale": 1.0, "toon": true,
			"tint": Color("3568b0")},
	# Parked tricycles: one at the left edge, one far down the side street at the right (the
	# reference's right-hand pair sits about 20 m out).
	{"scene": "tricycle_blue", "pos": Vector3(-2.45, 0, 0.55), "yaw": 14.0, "scale": 0.97},
	{"scene": "tricycle_right", "pos": Vector3(11.8, 0, -11.6), "yaw": 168.0, "scale": 0.96},
	# The reference's wooden jalousie house stands behind the left menu card.
	{"scene": "house_left", "pos": Vector3(-3.3, 0, -6.0), "yaw": 8.0, "scale": 0.85},
	# Bananas right of the store: the crop was wider than tall, so the clump model is stretched up.
	{"scene": "banana_plant", "pos": Vector3(6.45, 1.35, -3.4), "yaw": 18.0, "scale": Vector3(0.78, 2.62, 0.78), "toon": true},
	{"scene": "banana_plant", "pos": Vector3(6.95, 1.35, -5.4), "yaw": 130.0, "scale": Vector3(0.72, 2.60, 0.72), "toon": true},
	{"scene": "croton_plant", "pos": Vector3(4.5, 0, -0.70), "yaw": 0.0, "scale": 1.0, "toon": true,
			"path": "res://assets/props/neighborhood/croton_plant.tscn"},
	# Power poles (scaled so the cross-arm and transformer sit in frame, as in the reference) with
	# catenary spans between them: Meshy cannot make a thin sagging cable, so these stay procedural.
	{"scene": "power_pole", "pos": Vector3(-0.39, 0, -6.60), "yaw": 0.0, "scale": 0.72},
	{"scene": "power_pole", "pos": Vector3(9.6, 0, -5.4), "yaw": 0.0, "scale": 0.72},
	{"scene": "wire_span", "pos": Vector3(-6.20, 0, -6.6), "scale": 0.75},
	{"scene": "wire_span", "pos": Vector3(0.00, 0, -6.6), "scale": 0.75},
	{"scene": "wire_span", "pos": Vector3(6.20, 0, -6.4), "scale": 0.75},
	# Skyline fill far behind the set.
	{"scene": "mango_tree", "pos": Vector3(-9.5, 0, -9.5), "yaw": 30.0, "scale": 1.0, "toon": true},
	{"scene": "coconut_palm", "pos": Vector3(-7.5, 0, -6.0), "yaw": 20.0, "scale": 0.95, "toon": true},
	{"scene": "mango_tree", "pos": Vector3(16.8, 0, -12.5), "yaw": 100.0, "scale": 1.05, "toon": true},
	{"scene": "coconut_palm", "pos": Vector3(15.0, 0, -6.2), "yaw": 70.0, "scale": 1.05, "toon": true},
]

@export_group("Cast")
## One entry per hero: pos (the hero root, on the ground), yaw (deg), base idle clip, idle cycles per
## loop (so the base pose is identical at the wrap), stool prop, hand props. The seat height is not
## tuned here: home_diorama reads the stool's seat from its own mesh and the hero's pelvis from frame
## 0 of the sit clip, puts the stool under the pelvis and scales it so seat_top = pelvis - seat_pad.
@export var seat_pad := 0.06 ## metres of thigh compression: the pelvis rides this far above the seat
@export var cast := {
	"inday": {"pos": Vector3(-0.27, 0, 1.41), "yaw": 60.0, "base": "Menu_StandIdle", "cycles": 16,
			"stool": "", "hero_dy": 0.0, "prop": {}},
	"nene": {"pos": Vector3(0.19, 0, 0.08), "yaw": 18.0, "base": "Menu_SitIdle", "cycles": 8,
			"stool": "plastic_stool", "stool_tint": Color("d0402c"), "hero_dy": 0.0, "prop": {}},
	"jm": {"pos": Vector3(1.53, 0, -0.43), "yaw": 6.0, "base": "Menu_SitIdle", "cycles": 32,
			"stool": "plastic_stool", "stool_tint": Color("2f7f8f"), "hero_dy": 0.0, "prop": {}},
	"nathan": {"pos": Vector3(2.59, 0, -0.27), "yaw": -20.0, "base": "Menu_SitIdle", "cycles": 32,
			"stool": "plastic_stool", "stool_tint": Color("3a6fbd"), "hero_dy": 0.0, "prop": {}},
	"tutoy": {"pos": Vector3(3.83, 0, 1.22), "yaw": -50.0, "base": "Menu_StandIdle", "cycles": 16,
			"stool": "", "hero_dy": 0.0, "prop": {}},
}
@export var look_default := Vector3(1.6, 1.2, 0.4) ## where everyone looks when nobody speaks
@export var look_yaw_limit := 30.0 ## degrees the head may turn toward a speaker
@export var look_pitch_limit := 15.0
@export var look_rate := 2.5 ## 1/s: how fast the gaze target eases to the next speaker
@export var gesture_fade_in := 0.5
@export var gesture_fade_out := 0.5
@export var gesture_fade_smooth := true ## ease-in-out fades (a linear ramp kinks the hand's velocity at both ends)
@export var look_off_rate := 4.0 ## 1/s: look-at influence easing to 0 during full-body clips

@export_group("Schedule")
## {t, hero, clip, dur, full}: gestures never overlap on one hero and stay inside the quiet window.
## `dur` can end a long clip early (the one-shot fades out). Few and long: five short gestures in a
## row read as twitching, so each hero gets one unhurried turn.
@export var gestures := [
	{"t": 2.4, "hero": "inday", "clip": "Menu_TalkHandsOpen", "dur": 3.96},
	{"t": 4.2, "hero": "tutoy", "clip": "Menu_Listen", "dur": 5.0},
	{"t": 9.6, "hero": "inday", "clip": "Menu_TalkHip", "dur": 5.17},
	{"t": 12.0, "hero": "nene", "clip": "Menu_ArmsCrossed", "dur": 2.375},
	{"t": 17.0, "hero": "nathan", "clip": "Menu_Answer", "dur": 7.208},
	{"t": 25.0, "hero": "inday", "clip": "Menu_TalkRaised", "dur": 4.625},
	{"t": 30.0, "hero": "jm", "clip": "Menu_DozeOff", "dur": 5.0},
	{"t": 31.4, "hero": "tutoy", "clip": "Menu_TalkPassionate", "dur": 6.208},
	{"t": 34.0, "hero": "nathan", "clip": "Menu_CheerLeft", "dur": 2.667},
	{"t": 38.0, "hero": "jm", "clip": "Menu_LeanBackLaugh", "dur": 4.0},
	{"t": 39.0, "hero": "tutoy", "clip": "Menu_StandChat", "dur": 5.167},
	{"t": 42.4, "hero": "nathan", "clip": "Menu_ThumbsUp", "dur": 3.417},
	{"t": 42.6, "hero": "nene", "clip": "Menu_FingerWag", "dur": 3.208},
]
## {t0, t1, hero, mode}: who moves their mouth when. While a hero talks or laughs the others
## look at them (the gaze follows the latest speaker).
@export var speech := [
	{"t0": 2.6, "t1": 8.6, "hero": "inday", "mode": "talk"},
	{"t0": 9.8, "t1": 15.9, "hero": "inday", "mode": "talk"},
	{"t0": 9.8, "t1": 15.9, "hero": "nene", "mode": "smile"},
	{"t0": 17.2, "t1": 24.0, "hero": "nathan", "mode": "talk"},
	{"t0": 17.2, "t1": 24.0, "hero": "jm", "mode": "smile"},
	{"t0": 25.2, "t1": 30.9, "hero": "inday", "mode": "talk"},
	{"t0": 25.2, "t1": 30.9, "hero": "tutoy", "mode": "smile"},
	{"t0": 31.6, "t1": 37.5, "hero": "tutoy", "mode": "talk"},
	{"t0": 31.6, "t1": 37.5, "hero": "nathan", "mode": "smile"},
	{"t0": 38.2, "t1": 41.9, "hero": "jm", "mode": "laugh"},
	{"t0": 38.2, "t1": 41.9, "hero": "nene", "mode": "smile"},
	{"t0": 38.2, "t1": 41.9, "hero": "inday", "mode": "smile"},
	{"t0": 38.2, "t1": 41.9, "hero": "tutoy", "mode": "smile"},
	{"t0": 38.2, "t1": 41.9, "hero": "nathan", "mode": "smile"},
	{"t0": 42.4, "t1": 45.6, "hero": "nene", "mode": "talk"},
	{"t0": 42.4, "t1": 45.7, "hero": "nathan", "mode": "smile"},
	{"t0": 42.6, "t1": 45.7, "hero": "inday", "mode": "smile"},
]

@export_group("Bystanders")
## Walkers: from -> to at `speed` m/s (the measured planted-foot speed, so the feet don't slide),
## starting at loop time t0, hidden outside the walk. The tindera keeps the stall counter, standing
## on the street in front of its left end (the store itself is raised on the counter now).
@export var bystanders := {
	"tindera": {"pos": Vector3(1.35, 0.0, -3.35), "yaw": 8.0, "clip": "Fan", "speed": 0.0, "cycles": 14,
			"prop": {"scene": "paper_fan", "bone": "RightHand", "pos": Vector3(0, 0, 0), "rot": Vector3(0, 0, 0), "scale": 1.0}},
	"student": {"from": Vector3(6.5, 0.0, -19.0), "to": Vector3(6.5, 0.0, 4.0), "t0": 6.0, "speed": 1.30, "clip": "Walk",
			"prop": {"scene": "backpack", "bone": "Spine02", "pos": Vector3(0, 0, 0), "rot": Vector3(0, 0, 0), "scale": 1.0}},
	"manong": {"from": Vector3(7.3, 0.0, 4.0), "to": Vector3(7.3, 0.0, -19.0), "t0": 25.0, "speed": 1.28, "clip": "Walk",
			"prop": {"scene": "water_gallon", "bone": "RightHand", "pos": Vector3(0, 0, 0), "rot": Vector3(0, 0, 0), "scale": 1.0}},
	"lola": {"from": Vector3(-14.0, 0.14, -15.2), "to": Vector3(14.0, 0.14, -15.2), "t0": 24.0, "speed": 1.21, "clip": "Walk",
			"prop": {"scene": "payong", "bone": "RightHand", "pos": Vector3(0, 0, 0), "rot": Vector3(0, 0, 0), "scale": 1.0}},
}
@export var bystander_height_fix := 1.0 ## scale applied to every bystander model
@export var bystander_toon := true

@export_group("Pass")
## A tricycle cruises the road behind the cast (the reference itself shows only parked tricycles;
## this keeps the street alive). It reuses the synthesised engine/horn bed built for the old jeepney
## pass - a passing motor sounds the same either way.
@export var pass_scene := "res://assets/props/home/tricycle_blue.tscn"
@export var pass_from := Vector3(24.0, 0.0, -9.6) ## right to left along the back road, entering and leaving off frame
@export var pass_to := Vector3(-24.0, 0.0, -9.6)
@export var pass_t0 := 15.0
@export var pass_speed := 3.2 ## m/s: a slow cruise, about 15 s in view
@export var pass_yaw := 180.0 ## model front is +X; it drives toward -X
@export var pass_bob_amp := 0.02 ## metres of body bob
@export var pass_bob_hz := 2.4
@export var pass_pitch_deg := 0.4
@export var pass_scale := 1.0
@export var pass_horn_u := 6.0 ## seconds into the pass when the horn sounds (beep-beep)
@export var pass_audio_range := 38.0 ## metres: the engine is audible within this

@export_group("Audio")
@export var chatter_pitch := {"inday": 1.28, "nene": 1.45, "jm": 0.78, "nathan": 0.9, "tutoy": 1.12} ## per-hero pitch of the babble grains
@export var chatter_db := -8.0
@export var ambience_db := -16.0 ## looping daylight bed under the music
@export var music_fade_in := 2.0
@export var music_fade_out := 0.5

@export_group("Faces")
## Mouth flipbook frames (atlas order from tools/build_face_cards.py).
@export var mouth_closed := 0
@export var mouth_small := 1
@export var mouth_wide := 2
@export var mouth_o := 3
@export var mouth_smile := 4
@export var mouth_laugh := 5
## Eyelid frames: open / half / closed.
@export var lid_open := 0
@export var lid_half := 1
@export var lid_closed := 2
@export var mouth_atlas_cols := 3
@export var mouth_atlas_rows := 2
@export var lid_atlas_cols := 3
@export var lid_atlas_rows := 1
## Mouth shape changes per second while speaking, and the chance each step picks a shape.
@export var mouth_rate := 7.0
@export var mouth_pick_closed := 0.14
@export var mouth_pick_small := 0.34
@export var mouth_pick_wide := 0.30
@export var mouth_pick_o := 0.12 ## the rest is a smile
@export var laugh_rate := 9.0 ## laugh alternates laugh / wide-open at this rate
@export var blink_min := 2.5
@export var blink_max := 5.0
@export var blink_duration := 0.12
@export var face_depth_bias := 0.0004
## Per-hero RNG seeds (blinks and mouth shapes).
@export var face_seeds := {"tutoy": 11, "nene": 23, "nathan": 37, "jm": 41, "inday": 53}

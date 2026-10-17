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
@export var cam_position := Vector3(1.0, 1.05, 6.4) ## low and close, like the reference: kids fill the lower half
@export var cam_target := Vector3(1.1, 1.3, 0.0)
@export var cam_fov := 40.0

@export_group("Light")
@export var sun_color := Color("ffc27a")
@export var sun_energy := 1.15
@export var sun_rotation := Vector3(-20.0, 128.0, 0.0) ## degrees: elevation 20, from screen-right and behind
@export var sun_shadow_max := 40.0
@export var sun_shadow_opacity := 0.82
@export var fill_color := Color("9fc0e6") ## cool fill from camera-left, no shadow
@export var fill_energy := 0.28
@export var fill_rotation := Vector3(-18.0, -35.0, 0.0)
@export var ambient_color := Color("8fb4d9")
@export var ambient_energy := 0.42
@export var exposure := 0.9 ## filmic tonemap exposure (keeps the sky from washing out)
@export var sky_top := Color("5d86b8")
@export var sky_horizon := Color("f0a566")
@export var fog_color := Color("f0c9a0") ## warm-peach depth haze
@export var fog_density := 0.008
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
## [name, centre, size (x, z), colour]; flat toon-shaded slabs under the set.
@export var ground := [
	{"name": "Yard", "pos": Vector3(0, -0.01, 0.5), "size": Vector2(60, 18), "color": Color("b9a68c"),
			"texture": "res://assets/props/home/ground_concrete.png", "tile": 8.0},
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
## Gaps are left at x 6.2..12.4 for the side street the jeep drives down.
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
@export var set_saturation := 0.62 ## default saturation of graded set pieces (the Meshy palettes are candy-bright)
## {scene, pos, yaw (deg), scale, outline, toon, remap, sat}: Meshy and procedural props from
## assets/props/home. `toon` keeps the hero toon shader (plants, stools); every other piece uses
## the graded diorama_set shader, `remap` re-colours teal/orange Meshy textures, `outline` adds ink.
@export var set_pieces := [
	{"scene": "store", "pos": Vector3(1.4, 0, -4.9), "yaw": 0.0, "scale": 1.35, "remap": true, "sat": 0.75},
	{"scene": "sign_sari_sari", "pos": Vector3(1.55, 2.75, -1.3), "yaw": 0.0, "scale": 1.35},
	{"scene": "sidewalk", "pos": Vector3(-8, 0, -15.8), "yaw": 180.0},
	{"scene": "sidewalk", "pos": Vector3(8, 0, -15.8), "yaw": 180.0},
	{"scene": "facade_teal", "pos": Vector3(-5.2, 0, -10.2), "scale": 0.85, "remap": true, "sat": 0.55},
	{"scene": "facade_pink", "pos": Vector3(5.6, 0, -11.0), "scale": 1.3, "remap": true, "sat": 0.55},
	{"scene": "fruit_stall", "pos": Vector3(9.3, 0, -17.6), "yaw": 6.0},
	{"scene": "payong", "pos": Vector3(9.3, 1.6, -17.6), "scale": 1.8},
	{"scene": "sign_tindahan", "pos": Vector3(-0.5, 3.1, -16.8)},
	{"scene": "power_pole", "pos": Vector3(-6.0, 0, -15.4)},
	{"scene": "power_pole", "pos": Vector3(2.0, 0, -15.4)},
	{"scene": "power_pole", "pos": Vector3(10.0, 0, -15.4)},
	{"scene": "wire_span", "pos": Vector3(-6.0, 0, -15.4)},
	{"scene": "wire_span", "pos": Vector3(2.0, 0, -15.4)},
	{"scene": "bottle_crate", "pos": Vector3(-0.85, 0, -0.75), "yaw": 10.0},
	{"scene": "graffiti_wall", "pos": Vector3(3.95, 0, -3.3), "yaw": -10.0, "scale": 1.1, "sat": 0.9},
	{"scene": "bench", "pos": Vector3(1.5, 0, -0.95), "yaw": 0.0},
	{"scene": "potted_plant", "pos": Vector3(3.95, 0, -0.9), "toon": true, "path": "res://assets/props/potted_plant.tscn"},
	{"scene": "stool_24", "pos": Vector3(4.9, 0, 3.0), "yaw": 30.0, "scale": 1.5, "toon": true},
	# Vegetation: the map's painted neighborhood assets (unit-height models, scale = metres tall).
	{"scene": "mango_tree", "pos": Vector3(13.2, 0, -7.5), "yaw": 30.0, "scale": 1.0, "toon": true},
	{"scene": "coconut_palm", "pos": Vector3(15.0, 0, -4.2), "yaw": 70.0, "scale": 1.05, "toon": true},
	{"scene": "banana_plant", "pos": Vector3(5.2, 0, -6.2), "yaw": 15.0, "scale": 2.6, "toon": true, "path": "res://assets/props/neighborhood/banana_plant.tscn"},
	{"scene": "banana_plant", "pos": Vector3(4.2, 0, -8.0), "yaw": 140.0, "scale": 2.0, "toon": true, "path": "res://assets/props/neighborhood/banana_plant.tscn"},
	{"scene": "coconut_palm", "pos": Vector3(-7.5, 0, -9.0), "yaw": 20.0, "scale": 0.95, "toon": true},
	{"scene": "mango_tree", "pos": Vector3(16.8, 0, -12.5), "yaw": 100.0, "scale": 1.05, "toon": true},
	{"scene": "croton_plant", "pos": Vector3(-0.2, 0, -0.9), "yaw": 0.0, "scale": 1.0, "toon": true, "path": "res://assets/props/neighborhood/croton_plant.tscn"},
]

@export_group("Cast")
## One entry per hero: pos, yaw (deg), base idle clip, idle cycles per loop (so the base pose is
## identical at the wrap), stool prop, offsets, held prop.
@export var cast := {
	"inday": {"pos": Vector3(0.05, 0, 1.3), "yaw": 55.0, "base": "Menu_StandIdle", "cycles": 16,
			"stool": "", "stool_dy": 0.0, "hero_dy": 0.0, "prop": {}},
	"nene": {"pos": Vector3(0.7, 0, -0.1), "yaw": 32.0, "base": "Menu_SitIdle", "cycles": 8,
			"stool": "stool_18", "stool_dy": 0.0, "hero_dy": 0.0,
			"prop": {"scene": "palamig_bag", "bone": "mixamorig_RightHand", "pos": Vector3(0, 0, 0), "rot": Vector3(0, 0, 0), "scale": 1.0}},
	"jm": {"pos": Vector3(1.75, 0, 0.3), "yaw": -8.0, "base": "Menu_SitIdle", "cycles": 32,
			"stool": "stool_19", "stool_dy": 0.0, "hero_dy": 0.0,
			"prop": {"scene": "soda_bottle", "bone": "mixamorig_RightHand", "pos": Vector3(0, 0, 0), "rot": Vector3(0, 0, 0), "scale": 1.0}},
	"nathan": {"pos": Vector3(2.85, 0, -0.15), "yaw": -34.0, "base": "Menu_SitIdle", "cycles": 32,
			"stool": "stool_24", "stool_dy": 0.0, "hero_dy": 0.0, "prop": {}},
	"tutoy": {"pos": Vector3(4.0, 0, 0.9), "yaw": -52.0, "base": "Menu_StandIdle", "cycles": 16,
			"stool": "", "stool_dy": 0.0, "hero_dy": 0.0, "prop": {}},
}
@export var look_default := Vector3(1.6, 1.2, 0.4) ## where everyone looks when nobody speaks
@export var look_yaw_limit := 45.0 ## degrees the head may turn toward a speaker
@export var look_pitch_limit := 20.0
@export var look_rate := 5.0 ## 1/s: how fast the gaze target eases to the next speaker
@export var gesture_fade_in := 0.25
@export var gesture_fade_out := 0.30
@export var look_off_rate := 6.0 ## 1/s: look-at influence easing to 0 during full-body clips

@export_group("Schedule")
## {t, hero, clip, dur, full}: gestures never overlap on one hero and stay inside the quiet
## window. `dur` can end a long clip early (the one-shot fades out).
@export var gestures := [
	{"t": 2.2, "hero": "inday", "clip": "Menu_TalkHandsOpen", "dur": 3.9},
	{"t": 6.3, "hero": "inday", "clip": "Menu_TalkHip", "dur": 5.1},
	{"t": 11.6, "hero": "nathan", "clip": "Menu_Answer", "dur": 9.6},
	{"t": 12.2, "hero": "nene", "clip": "Menu_SitDrink", "dur": 11.1},
	{"t": 15.2, "hero": "jm", "clip": "Menu_LeanBackLaugh", "dur": 4.7},
	{"t": 21.0, "hero": "jm", "clip": "Menu_SitDrink", "dur": 8.5},
	{"t": 25.2, "hero": "nene", "clip": "Menu_FingerWag", "dur": 3.9},
	{"t": 25.5, "hero": "inday", "clip": "Menu_TalkRightOpen", "dur": 3.7},
	{"t": 30.0, "hero": "tutoy", "clip": "Menu_TalkPassionate", "dur": 3.9},
	{"t": 34.3, "hero": "tutoy", "clip": "Menu_HandstandFlip", "dur": 3.2, "full": true},
	{"t": 38.0, "hero": "tutoy", "clip": "Menu_Cheer", "dur": 1.3},
	{"t": 38.1, "hero": "nathan", "clip": "Menu_Clap", "dur": 3.2},
	{"t": 38.2, "hero": "jm", "clip": "Menu_Clap", "dur": 3.2},
	{"t": 38.3, "hero": "nene", "clip": "Menu_Clap", "dur": 3.2},
	{"t": 41.7, "hero": "nathan", "clip": "Menu_ThumbsUp", "dur": 3.8},
	{"t": 42.2, "hero": "inday", "clip": "Menu_TalkHandsOpen", "dur": 3.5},
]
## {t0, t1, hero, mode}: who moves their mouth when. While a hero talks or laughs the others
## look at them (the gaze follows the latest speaker).
@export var speech := [
	{"t0": 2.4, "t1": 10.9, "hero": "inday", "mode": "talk"},
	{"t0": 11.8, "t1": 16.0, "hero": "nathan", "mode": "talk"},
	{"t0": 16.0, "t1": 19.2, "hero": "nathan", "mode": "smile"},
	{"t0": 15.5, "t1": 19.6, "hero": "jm", "mode": "laugh"},
	{"t0": 16.0, "t1": 18.8, "hero": "nene", "mode": "laugh"},
	{"t0": 15.5, "t1": 19.5, "hero": "inday", "mode": "smile"},
	{"t0": 15.5, "t1": 19.5, "hero": "tutoy", "mode": "smile"},
	{"t0": 25.4, "t1": 27.4, "hero": "nene", "mode": "talk"},
	{"t0": 27.4, "t1": 29.2, "hero": "inday", "mode": "talk"},
	{"t0": 30.2, "t1": 33.9, "hero": "tutoy", "mode": "talk"},
	{"t0": 38.1, "t1": 39.4, "hero": "tutoy", "mode": "laugh"},
	{"t0": 38.0, "t1": 41.5, "hero": "nathan", "mode": "smile"},
	{"t0": 38.0, "t1": 41.5, "hero": "jm", "mode": "smile"},
	{"t0": 38.0, "t1": 41.5, "hero": "nene", "mode": "smile"},
	{"t0": 41.8, "t1": 45.5, "hero": "nathan", "mode": "smile"},
	{"t0": 42.4, "t1": 45.7, "hero": "inday", "mode": "talk"},
	{"t0": 43.0, "t1": 45.5, "hero": "nene", "mode": "smile"},
]

@export_group("Bystanders")
## Walkers: from -> to at `speed` m/s (the measured planted-foot speed, so the feet don't slide),
## starting at loop time t0, hidden outside the walk. The tindera stays in the store window.
@export var bystanders := {
	"tindera": {"pos": Vector3(0.3, 0.2, -2.8), "yaw": 0.0, "clip": "Fan", "speed": 0.0, "cycles": 14,
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

@export_group("Jeepney")
@export var jeep_scene := "res://assets/props/vehicles/jeepney.tscn"
@export var jeep_from := Vector3(9.1, 0.0, -26.0) ## down the side street toward the camera; starts and ends outside the frame
@export var jeep_to := Vector3(9.1, 0.0, 1.0)
@export var jeep_t0 := 16.5
@export var jeep_speed := 3.6 ## m/s: a slow cruise, so it stays on screen about 4 s after clearing the wall
@export var jeep_yaw := -90.0 ## model front is +X; it drives toward +Z
@export var jeep_bob_amp := 0.018 ## metres of body bob
@export var jeep_bob_hz := 2.1
@export var jeep_pitch_deg := 0.35
@export var jeep_scale := 1.0
@export var jeep_horn_u := 4.6 ## seconds into the pass when the horn sounds (beep-beep)
@export var jeep_audio_range := 38.0 ## metres: the engine is audible within this

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

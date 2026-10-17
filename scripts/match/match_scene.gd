extends Node3D

## The match scene (scenes/match.tscn, docs/RESBAK.md § 12 "Project structure": map, 10 heroes,
## HUD, host-only MatchHost). Reads Session (lineup, settings, local slot); run directly it
## builds a quick vs Bots lineup. User args (after --): --hero=<id> --difficulty=0|1|2
## --seed=<n> --tradisyonal --no-shadows --autoplay (the local hero is a bot too, for demos).

const MAPS := {"barangay_court": "res://scenes/barangay_court.tscn", "construction_site": "res://scenes/construction_site.tscn"}
const AMBIENCE := {
	"barangay_court": "res://assets/audio/barangay_daylight.wav",
	"construction_site": "res://assets/audio/construction_ambience.ogg", # harbour, engines, distant hammering
}
## Match music per map (Audio.play_music names). With final_stretch_time left on the round clock
## (spec § 7: "faster music") the base crossfades to its "<name>_tension" stem, which carries on
## through sudden death; the next countdown crossfades back.
const MUSIC := {"barangay_court": "music_barangay_court", "construction_site": "music_construction_site"}
const RESULTS_SCENE := "res://scenes/frontend/results.tscn"
const TITLE_SCENE := "res://scenes/frontend/title.tscn"
const HOME_SCENE := "res://scenes/frontend/home.tscn"

var host: MatchHost
var world: Node3D
var map_root: Node3D
var camera: MatchCamera
var view: MatchView
var hud: Hud
var player_input: PlayerInput
var local_hero: Hero
var bots: Array[BotBrain] = []
var tutorial: Tutorial
var _music_started := false
var occlusion: OcclusionFade ## tall props fade when they hide the hero (maps that opt in)

func _ready() -> void:
	Controls.ensure()
	Portraits.request_all()
	var session := get_node_or_null("/root/Session")
	var args := OS.get_cmdline_user_args()
	var settings: Dictionary = session.settings.duplicate() if session else MatchHost.default_settings()
	var lineup: Array = session.lineup if session and not session.lineup.is_empty() else []
	var local_slot: int = session.local_slot if session else 0
	var hero_arg := "tutoy"
	for a in args:
		if a.begins_with("--hero="):
			hero_arg = a.trim_prefix("--hero=")
		elif a.begins_with("--difficulty="):
			settings["difficulty"] = int(a.trim_prefix("--difficulty="))
		elif a.begins_with("--seed="):
			settings["seed"] = int(a.trim_prefix("--seed="))
		elif a == "--skip-intro" or a == "--autoplay":
			settings["skip_intro"] = true
		elif a == "--tradisyonal":
			settings["skills"] = false
			settings["hazards"] = false
			settings["base_mode"] = 1
	if lineup.is_empty():
		lineup = session.quick_lineup(hero_arg) if session else _fallback_lineup(hero_arg)
		local_slot = 0
	var map_id := String(settings.get("map", "barangay_court"))
	if not MAPS.has(map_id):
		map_id = "barangay_court"
	map_root = (load(MAPS[map_id]) as PackedScene).instantiate()
	MapDressing.disable_map_cameras(map_root)
	MapDressing.add_lighting(self, not ("--no-shadows" in args), map_root)
	add_child(map_root)
	MapDressing.dress_court(map_root)
	if AMBIENCE.has(map_id):
		MapDressing.add_ambience(self, AMBIENCE[map_id])
	if MUSIC.has(map_id):
		var audio := get_node_or_null("/root/Audio")
		if audio:
			audio.play_music(MUSIC[map_id])
			_music_started = true
	var gameplay := map_root.get_node_or_null("Gameplay")
	if gameplay and bool(gameplay.get_meta("dust", false)):
		MapDressing.add_dust(map_root, _play_bounds(gameplay))
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	host = MatchHost.new()
	host.name = "MatchHost"
	add_child(host)
	host.setup(world, map_root, lineup, settings)
	local_hero = host.hero_by_slot(local_slot)
	if session:
		session.last_map = map_id
	camera = MatchCamera.new()
	camera.name = "MatchCamera"
	camera.target = local_hero
	camera.bounds = host.layout.bounds
	if local_hero:
		var own := host.base_system.pole_pos(local_hero.team)
		var enemy := host.base_system.pole_pos(RB.other_team(local_hero.team))
		camera.enemy_dir = RB.flat(enemy - own).normalized()
	add_child(camera)
	camera.ink = MapDressing.add_ink_edges(camera, host.layout.bounds)
	camera.snap()
	player_input = PlayerInput.new()
	player_input.name = "PlayerInput"
	player_input.camera = camera
	add_child(player_input)
	var autoplay := "--autoplay" in args
	for h in host.heroes:
		if h == local_hero and not autoplay:
			host.input_sources[h.slot] = player_input
			continue
		var brain := BotBrain.new()
		add_child(brain)
		brain.setup(h, host, int(settings.get("difficulty", 1)))
		host.input_sources[h.slot] = brain
		bots.append(brain)
	view = MatchView.new()
	view.name = "MatchView"
	add_child(view)
	view.setup(host, local_hero, camera)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(host, local_hero, view)
	hud.input_source = player_input
	if OcclusionFade.wanted(map_root):
		occlusion = OcclusionFade.new()
		occlusion.name = "OcclusionFade"
		add_child(occlusion)
		occlusion.setup(camera, map_root, local_hero, host.layout.bounds)
	hud.resume_requested.connect(_set_pause.bind(false))
	hud.leave_requested.connect(_leave_match)
	host.event.connect(_on_event)
	if session and session.mode == "tutorial":
		tutorial = Tutorial.new()
		add_child(tutorial)
		tutorial.setup(host, local_hero, hud)

func _play_bounds(gameplay: Node) -> Rect2:
	return gameplay.get_meta("play_bounds", Rect2(-19.5, -11.5, 39.0, 29.0))

func _fallback_lineup(local: String) -> Array:
	var out: Array = []
	for team in range(2):
		for ts in range(5):
			var hid: String = HeroData.ORDER[ts]
			if team == RB.DILAW and ts == 0:
				hid = local
			elif team == RB.DILAW and hid == local:
				hid = HeroData.ORDER[0]
			out.append({"hero_id": hid, "team": team, "team_slot": ts, "is_bot": not (team == 0 and ts == 0), "name": hid.capitalize()})
	return out

func _exit_tree() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio and _music_started:
		audio.stop_music(0.4)

func _on_event(kind: String, d: Dictionary) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio and audio.music_name != "":
		if kind == "final_stretch" or kind == "sudden_death": # sudden death: if a round skipped the stretch
			audio.set_music_layer("tension", true)
		elif kind == "round_end" or kind == "countdown":
			audio.set_music_layer("tension", false)
	if kind != "match_end":
		return
	var session := get_node_or_null("/root/Session")
	if session:
		session.last_results = {"winner": d.winner, "score": d.score, "stats": host.stats.duplicate(true),
			"lineup": session.lineup.duplicate(true) if not session.lineup.is_empty() else [],
			"heroes": _hero_summaries(), "local_slot": local_hero.slot if local_hero else 0,
			"rounds": host.round_flow.round_log.duplicate(true)}
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	if ResourceLoader.exists(RESULTS_SCENE):
		get_tree().change_scene_to_file(RESULTS_SCENE)
	elif ResourceLoader.exists(TITLE_SCENE):
		get_tree().change_scene_to_file(TITLE_SCENE)

func _hero_summaries() -> Array:
	var out: Array = []
	for h in host.heroes:
		out.append({"slot": h.slot, "team": h.team, "hero_id": h.data.id, "name": h.display_name, "is_bot": h.is_bot})
	return out

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and host and hud:
		_set_pause(not hud.is_pause_open())

## Escape overlay (spec § 7): vs Bots / tutorial stop the host tick; Custom Room runs on
## without this player's input.
func _set_pause(on: bool) -> void:
	if hud == null or hud.is_pause_open() == on:
		return
	hud.set_pause_open(on)
	if _is_offline():
		host.paused = on
	if player_input:
		player_input.enabled = not on

## UMALIS confirmed: vs Bots / tutorial end with no result and return to the origin menu
## (Home). Leaving steps back one screen at a time: match -> Home -> title -> quit.
func _leave_match() -> void:
	host.paused = true
	var to := HOME_SCENE if ResourceLoader.exists(HOME_SCENE) else TITLE_SCENE
	if ResourceLoader.exists(to):
		FE.go(self, to)
	else:
		get_tree().quit()

func _is_offline() -> bool:
	var session := get_node_or_null("/root/Session")
	return session == null or session.mode != "custom_room"

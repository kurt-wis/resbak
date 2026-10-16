extends Node

## Session autoload (docs/RESBAK.md § 12 "Project structure"): the current room settings,
## slots and lineup, map and base, score and results, carried between front-end scenes and
## the match. Offline (vs Bots) the local player is always slot 0 on Dilaw (spec § 6 draft).

const MATCH_SCENE := "res://scenes/match.tscn"

var mode := "vs_bots" ## "vs_bots", "custom_room", "tutorial"
var settings := {} ## room settings, see MatchHost.default_settings()
var lineup: Array = [] ## [{hero_id, team, team_slot, name, is_bot}], Dilaw 0-4 then Lila 0-4
var local_slot := 0
var last_results := {} ## filled by the match at MATCH_OVER, read by the results screen
var last_map := ""

func _ready() -> void:
	Controls.ensure()
	reset_settings()

func reset_settings() -> void:
	settings = MatchHost.default_settings()

## Tradisyonal preset (spec § 8): Skills Off, Hazards Off, Base Fixed site 1.
func apply_tradisyonal() -> void:
	settings["skills"] = false
	settings["hazards"] = false
	settings["base_mode"] = 1

## A full 5v5 lineup with the local player on Dilaw slot 0 and bots everywhere else, no
## duplicate hero within a team (enemy picks allowed). Used by quick play and tests;
## the draft builds its own lineup with the same shape.
func quick_lineup(local_hero: String, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var out: Array = []
	for team in range(2):
		var pool := HeroData.ORDER.duplicate()
		if team == RB.DILAW:
			pool.erase(local_hero)
		_shuffle(pool, rng)
		for ts in range(5):
			var hid: String
			if team == RB.DILAW and ts == 0:
				hid = local_hero
			else:
				hid = pool.pop_back()
			var data := HeroData.load_hero(hid)
			var is_bot := not (team == RB.DILAW and ts == 0)
			out.append({"hero_id": hid, "team": team, "team_slot": ts, "is_bot": is_bot,
				"name": (data.display_name + " (Bot)") if is_bot else player_name()})
	return out

func player_name() -> String:
	var save := get_node_or_null("/root/Save")
	if save and save.has_method("get_profile"):
		return String(save.get_profile().get("player_name", "Manlalaro"))
	return "Manlalaro"

func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

## Start a match with the current lineup and settings.
func start_match() -> void:
	if lineup.is_empty():
		lineup = quick_lineup("tutoy")
	get_tree().change_scene_to_file(MATCH_SCENE)

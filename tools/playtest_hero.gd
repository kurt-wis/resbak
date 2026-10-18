extends SceneTree

## Open a playable Ensayo session without changing the user's saved hero selection.
## godot --path . -s tools/playtest_hero.gd -- --hero=jm [--bots]
func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var hero := "jm"
	var bots := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hero="):
			hero = argument.trim_prefix("--hero=")
		elif argument == "--bots":
			bots = true
	if hero not in HeroData.ORDER:
		push_error("Unknown playtest hero: " + hero)
		quit(1)
		return
	root.get_node("Session").prepare_training(hero, "barangay_court", bots)
	change_scene_to_file("res://scenes/match.tscn")

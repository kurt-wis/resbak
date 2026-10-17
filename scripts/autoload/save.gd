extends Node

## Save autoload (docs/RESBAK.md § 12 "Save data"): user:// is %APPDATA%\RESBAK
## (use_custom_user_dir). settings.cfg = ConfigFile, one section per Settings tab, written on
## every change. profile.json = the local player's profile, written after setup, each lesson,
## each match and each rename. Writes go to .tmp then rename; an unloadable file is renamed
## .bak and defaults are used. No encryption, no cloud.

const PROFILE_PATH := "user://profile.json"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_VERSION := 1
## Demo / development builds (v0.1.1): every launch starts from a fresh profile (name, setup,
## tutorial, match totals), so each new player at the booth sees first-time setup and the
## tutorial offer, and stats never pile up. Settings (display, audio, controls) are kept.
## Set to false for a release build.
const DEMO_RESET_PROGRESS := true

## Settings rows and their defaults (spec § 10). Sections match the Settings tabs.
const SETTINGS_DEFAULTS := {
	"gameplay": {"danger_border": true, "skill_casting": "quick", "tag_assist": true, "camera_shake": 0.7,
		"minimap_size": "M", "minimap_position": "top_right", "tag_feed": true, "team_colours": "fixed"},
	"controls": {"mouse_sensitivity": 1.0, "stick_dead_zone": 0.15, "vibration": true, "button_icons": "auto"},
	"video": {"display_mode": "borderless", "resolution": "monitor", "render_scale": 1.0, "vsync": true,
		"frame_cap": 60, "quality": "auto", "shadows": "high", "effects": "high", "brightness": 50, "interface_size": 1.0},
	"audio": {"master": 50, "music": 60, "effects": 80, "voices": 80, "announcer": 80},
	"accessibility": {"colour_mode": "default", "subtitles": true, "subtitle_size": "M", "speaker_names": true,
		"sound_cues": false, "reduce_flashing": false, "reduce_motion": false, "capture_input": "hold",
		"theme": "dark"},
	"language_network": {"language": "fil_en", "show_ping": false},
}

var profile := {}
var settings := ConfigFile.new()

func _ready() -> void:
	if DEMO_RESET_PROGRESS and not _is_test_run():
		reset_progress()
	else:
		load_profile()
	load_settings()

## A fresh profile on disk (demo builds call this on every launch).
func reset_progress() -> void:
	profile = default_profile()
	save_profile()

func _is_test_run() -> bool:
	return OS.get_cmdline_args().has("res://scripts/tests/integration_test.gd") or OS.get_cmdline_args().has("scripts/tests/integration_test.gd")

# ---- profile ---------------------------------------------------------------------------
func default_profile() -> Dictionary:
	return {"save_version": SAVE_VERSION, "player_id": _uuid(), "player_name": "Manlalaro",
		"setup_done": false, "tutorial_lessons_done": [], "matches_played": 0, "last_hero": "",
		"home_hero": "jm", "last_map": "",
		"totals": {"matches": 0, "wins": 0, "tags": 0, "rescues": 0, "captures": 0, "mvps": 0}}

func get_profile() -> Dictionary:
	return profile

func load_profile() -> void:
	profile = default_profile()
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var text := FileAccess.get_file_as_string(PROFILE_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		_quarantine(PROFILE_PATH)
		return
	profile.merge(data, true)

func save_profile() -> void:
	_write_atomic(PROFILE_PATH, JSON.stringify(profile, "\t"))

## Called by the results flow with the local player's match stats.
func record_match(won: bool, stats: Dictionary, was_mvp: bool) -> void:
	profile.matches_played = int(profile.matches_played) + 1
	var t: Dictionary = profile.totals
	t.matches = int(t.matches) + 1
	t.wins = int(t.wins) + (1 if won else 0)
	t.tags = int(t.tags) + int(stats.get("tags", 0))
	t.rescues = int(t.rescues) + int(stats.get("rescues", 0))
	t.captures = int(t.captures) + int(stats.get("captures", 0))
	t.mvps = int(t.mvps) + (1 if was_mvp else 0)
	save_profile()

# ---- settings --------------------------------------------------------------------------
func load_settings() -> void:
	settings = ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_PATH) and settings.load(SETTINGS_PATH) != OK:
		_quarantine(SETTINGS_PATH)
		settings = ConfigFile.new()

func get_setting(section: String, key: String) -> Variant:
	var fallback: Variant = SETTINGS_DEFAULTS.get(section, {}).get(key)
	if fallback == null and not settings.has_section_key(section, key):
		return null # no default and never set (e.g. an unbound key)
	return settings.get_value(section, key, fallback)

func set_setting(section: String, key: String, value: Variant) -> void:
	settings.set_value(section, key, value)
	_write_atomic(SETTINGS_PATH, settings.encode_to_text())

func reset_section(section: String) -> void:
	if settings.has_section(section):
		settings.erase_section(section)
	_write_atomic(SETTINGS_PATH, settings.encode_to_text())

## Settings > Delete local data: wipe both files (the caller restarts at setup).
func delete_local_data() -> void:
	for p in [PROFILE_PATH, SETTINGS_PATH, PROFILE_PATH + ".bak", SETTINGS_PATH + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	profile = default_profile()
	settings = ConfigFile.new()

# ---- helpers ---------------------------------------------------------------------------
func _write_atomic(path: String, text: String) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save: can't write %s" % tmp)
		return
	f.store_string(text)
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	DirAccess.rename_absolute(abs_tmp, abs_path)

func _quarantine(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.rename_absolute(abs_path, abs_path + ".bak")
	push_warning("Save: %s was unreadable; kept as .bak, using defaults" % path)

func _uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var b := PackedByteArray()
	for i in range(16):
		b.append(rng.randi() & 0xff)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

extends Node

## Audio autoload (docs/RESBAK.md § 12): buses Master, Music, Effects, Voices, Announcer and
## an announcer queue. Sounds are looked up by name in res://assets/audio/<name>.(ogg|wav);
## until the team's audio lands a missing name is silent, but every call still emits
## `cue` so subtitles and "Sound cues on screen" (spec § 10) can show it.

signal cue(name: String, text: String, position: Vector3)

const BUSES := ["Music", "Effects", "Voices", "Announcer"]
const AUDIO_DIR := "res://assets/audio/"

const MUSIC_BUS := "Music"
const LAYER_SILENT_DB := -60.0
const MUSIC_LAYER_DB := 0.0 ## a stem replaces the base track at full level (the CC0 stems are separate tunes)

var _announce_queue: Array = []
var _announcer: AudioStreamPlayer
## Music (2026-10-17): one looping track plus optional stems ("<track>_<layer>") that run in sync
## and fade in or out, e.g. a tension stem for sudden death. Missing files are silent; the state
## below still updates so tests and the cue subtitles work without assets.
var music_name := ""
var music_layers := {} ## layer name -> bool (wanted on)
var _music_player: AudioStreamPlayer
var _layer_players := {} ## layer name -> AudioStreamPlayer

func _ready() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	_announcer = AudioStreamPlayer.new()
	_announcer.bus = "Announcer"
	add_child(_announcer)
	_announcer.finished.connect(_next_announcement)
	apply_volumes()

## Volumes from Settings > Audio (0-100).
func apply_volumes() -> void:
	var save := get_node_or_null("/root/Save")
	var keys := {"Master": "master", "Music": "music", "Effects": "effects", "Voices": "voices", "Announcer": "announcer"}
	for bus in keys:
		var idx := AudioServer.get_bus_index(bus)
		if idx == -1:
			continue
		var vol: float = float(save.get_setting("audio", keys[bus])) if save else 80.0
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(vol, 0.001) / 100.0))

func _stream(name: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var p: String = AUDIO_DIR + name + ext
		if ResourceLoader.exists(p):
			return load(p)
	return null

## One-shot effect. `at` = world position for 3D sounds (Vector3.INF = 2D).
func play(name: String, text := "", at := Vector3.INF, bus := "Effects", pitch := 1.0, volume_db := 0.0) -> void:
	cue.emit(name, text, at)
	var s := _stream(name)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.pitch_scale = pitch
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## Start looping music `name` (res://assets/audio/<name>.ogg|wav) on the Music bus, fading in over
## `fade` seconds and replacing any current track (same name: no restart).
func play_music(name: String, fade := 1.0) -> void:
	if name == music_name and _music_player != null:
		return
	stop_music(fade)
	music_name = name
	music_layers.clear()
	cue.emit(name, "", Vector3.INF)
	var s := _stream(name)
	if s == null:
		return
	_music_player = _loop_player(s, 0.0 if fade <= 0.0 else LAYER_SILENT_DB)
	_fade_player(_music_player, 0.0, fade)

## Fade the current track and every stem out and free them. Safe with nothing playing.
func stop_music(fade := 1.0) -> void:
	var old: Array = [_music_player]
	old.append_array(_layer_players.values())
	_music_player = null
	_layer_players.clear()
	music_layers.clear()
	music_name = ""
	for p in old:
		if p == null or not is_instance_valid(p):
			continue
		if fade <= 0.0:
			p.queue_free()
		else:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", LAYER_SILENT_DB, fade)
			tw.tween_callback(p.queue_free)

## Turn the stem `layer` of the current track on or off (a stem file "<track>_<layer>"
## starts in sync with the track the first time it is asked for, then only its volume moves).
func set_music_layer(layer: String, on: bool, fade := 0.5) -> void:
	if music_name == "":
		return
	music_layers[layer] = on
	var p: AudioStreamPlayer = _layer_players.get(layer)
	if p == null and on:
		var s := _stream("%s_%s" % [music_name, layer])
		if s == null:
			return
		p = _loop_player(s, LAYER_SILENT_DB)
		if _music_player != null:
			p.seek(_music_player.get_playback_position())
		_layer_players[layer] = p
	if p != null:
		_fade_player(p, MUSIC_LAYER_DB if on else LAYER_SILENT_DB, fade)
		if _music_player != null: ## the stem is a different tune, not a mix: crossfade, never overlap
			_fade_player(_music_player, LAYER_SILENT_DB if on else 0.0, fade)

func _loop_player(s: AudioStream, db: float) -> AudioStreamPlayer:
	if s is AudioStreamWAV:
		s = s.duplicate()
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int(s.get_length() * (s as AudioStreamWAV).mix_rate)
	elif s is AudioStreamOggVorbis:
		s = s.duplicate() # never flip loop on the cached resource other players share
		(s as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = MUSIC_BUS
	p.volume_db = db
	add_child(p)
	p.play()
	return p

func _fade_player(p: AudioStreamPlayer, to_db: float, fade: float) -> void:
	if fade <= 0.0:
		p.volume_db = to_db
		return
	create_tween().tween_property(p, "volume_db", to_db, fade)

## Announcer / Kuya Tanod line: queued so lines never overlap.
func announce(name: String, text: String) -> void:
	cue.emit(name, text, Vector3.INF)
	var s := _stream(name)
	if s == null:
		return
	_announce_queue.append(s)
	if not _announcer.playing:
		_next_announcement()

func _next_announcement() -> void:
	if _announce_queue.is_empty():
		return
	_announcer.stream = _announce_queue.pop_front()
	_announcer.play()

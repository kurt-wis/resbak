extends Node

## Audio autoload (docs/RESBAK.md § 12): buses Master, Music, Effects, Voices, Announcer and
## an announcer queue. Sounds are looked up by name in res://assets/audio/<name>.(ogg|wav);
## until the team's audio lands a missing name is silent, but every call still emits
## `cue` so subtitles and "Sound cues on screen" (spec § 10) can show it.

signal cue(name: String, text: String, position: Vector3)

const BUSES := ["Music", "Effects", "Voices", "Announcer"]
const AUDIO_DIR := "res://assets/audio/"

var _announce_queue: Array = []
var _announcer: AudioStreamPlayer

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
func play(name: String, text := "", at := Vector3.INF, bus := "Effects") -> void:
	cue.emit(name, text, at)
	var s := _stream(name)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

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

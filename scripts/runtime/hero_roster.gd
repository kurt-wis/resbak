class_name HeroRoster
extends RefCounted

## The playable roster for the character select. Models are built by tools/build_heroes.py.
## run_speed (m/s) comes from the design doc; walking is half of it.
## *_clip_speed = the planted-foot speed of each clip, measured with tools/qc_asset.py.
## `selected_id` carries the pick from scenes/character_select.tscn into the playtest.

const HEROES := [
	{"id": "tutoy", "name": "Tutoy", "role": "Movement", "glb": "res://assets/characters/tutoy.glb", "run_speed": 5.4, "walk_clip_speed": 1.30, "run_clip_speed": 5.27, "color": Color("e2463f")},
	{"id": "nene", "name": "Nene", "role": "Deception", "glb": "res://assets/characters/nene.glb", "run_speed": 5.0, "walk_clip_speed": 1.45, "run_clip_speed": 6.59, "color": Color("f28cb8")},
	{"id": "nathan", "name": "Nathan", "role": "Disruption", "glb": "res://assets/characters/nathan.glb", "run_speed": 5.0, "walk_clip_speed": 1.16, "run_clip_speed": 4.49, "color": Color("7b5cd6")},
	{"id": "jm", "name": "JM", "role": "Protection", "glb": "res://assets/characters/jm.glb", "run_speed": 4.6, "walk_clip_speed": 1.25, "run_clip_speed": 5.01, "color": Color("f2b632")},
	{"id": "inday", "name": "Inday", "role": "Rescue", "glb": "res://assets/characters/inday.glb", "run_speed": 5.0, "walk_clip_speed": 1.50, "run_clip_speed": 5.56, "color": Color("3f7fd9")},
]

static var selected_id: String = ""

static func get_hero(id: String) -> Dictionary:
	for h in HEROES:
		if h["id"] == id:
			return h
	return {}

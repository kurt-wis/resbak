class_name HeroRoster
extends RefCounted

## The playable roster for the character select. Models are built by tools/build_heroes.py.
## run_speed (m/s) comes from the design doc; walking is half of it.
## `selected_id` carries the pick from scenes/character_select.tscn into the playtest.

const HEROES := [
	{"id": "tutoy", "name": "Tutoy", "role": "Movement", "glb": "res://assets/characters/tutoy.glb", "run_speed": 5.4, "color": Color("e2463f")},
	{"id": "nene", "name": "Nene", "role": "Deception", "glb": "res://assets/characters/nene.glb", "run_speed": 5.0, "color": Color("f28cb8")},
	{"id": "nathan", "name": "Nathan", "role": "Disruption", "glb": "res://assets/characters/nathan.glb", "run_speed": 5.0, "color": Color("7b5cd6")},
	{"id": "jm", "name": "JM", "role": "Protection", "glb": "res://assets/characters/jm.glb", "run_speed": 4.6, "color": Color("f2b632")},
	{"id": "inday", "name": "Inday", "role": "Rescue", "glb": "res://assets/characters/inday.glb", "run_speed": 5.0, "color": Color("3f7fd9")},
]

static var selected_id: String = ""

static func get_hero(id: String) -> Dictionary:
	for h in HEROES:
		if h["id"] == id:
			return h
	return {}

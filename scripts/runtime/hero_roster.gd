class_name HeroRoster
extends RefCounted

## The playable roster for the character select. Models are built by tools/build_heroes.py.
## `selected_id` carries the pick from scenes/character_select.tscn into the playtest.

const HEROES := [
	{"id": "tutoy", "name": "Tutoy", "role": "Movement", "glb": "res://assets/characters/tutoy.glb", "color": Color("e2463f")},
	{"id": "nene", "name": "Nene", "role": "Deception", "glb": "res://assets/characters/nene.glb", "color": Color("f28cb8")},
	{"id": "nathan", "name": "Nathan", "role": "Disruption", "glb": "res://assets/characters/nathan.glb", "color": Color("7b5cd6")},
	{"id": "jm", "name": "JM", "role": "Protection", "glb": "res://assets/characters/jm.glb", "color": Color("f2b632")},
	{"id": "inday", "name": "Inday", "role": "Rescue", "glb": "res://assets/characters/inday.glb", "color": Color("3f7fd9")},
	# The skills prototype (Harurot / Lusot / Dire-Diretso) still lives on the old Batang Hamog rig.
	{"id": "hamog", "name": "Batang Hamog", "role": "Skills demo", "glb": "res://assets/characters/batang_hamog.glb", "color": Color("4a9a6a")},
]

static var selected_id: String = ""

static func get_hero(id: String) -> Dictionary:
	for h in HEROES:
		if h["id"] == id:
			return h
	return {}

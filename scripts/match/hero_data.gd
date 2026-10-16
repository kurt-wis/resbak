class_name HeroData
extends Resource

## One hero's numbers and wiring (docs/RESBAK.md § 4). One .tres per hero in data/heroes/.
## Skill scripts read their tuning through `v("key")`; every key used by a skill must exist
## in that hero's `values` (the gate checks the five .tres files load and carry their keys).

const DIR := "res://data/heroes/"
const ORDER := ["tutoy", "nene", "nathan", "jm", "inday"] ## roster order (select, draft, gate)

@export var id := ""
@export var display_name := ""
@export var nickname := "" ## e.g. JM "Botsog"
@export var role := ""
@export var secondary_role := ""
@export var color := Color.WHITE
@export_file("*.glb") var glb := ""
@export var model_height := 1.8

@export_group("Movement")
@export var run_speed := 5.0
@export var tag_reach := 1.2 ## edge to edge
## Planted-foot speed of the Walking / Running clips (tools/qc_asset.py), so playback
## can be scaled until the feet stop skating. 0 = unknown, play at 1x.
@export var walk_clip_speed := 0.0
@export var run_clip_speed := 0.0

@export_group("Skills")
@export var skill1_name := ""
@export var skill2_name := ""
@export var passive_name := ""
@export var skill1_cooldown := 10.0
@export var skill2_cooldown := 10.0
@export var skill1_script: Script
@export var skill2_script: Script
@export var passive_script: Script
@export_multiline var skill1_text := ""
@export_multiline var skill2_text := ""
@export_multiline var passive_text := ""
## Skill tuning numbers from the spec, snake_case keys (seconds, metres, fractions).
@export var values := {}

func v(key: String, fallback: Variant = null) -> Variant:
	if values.has(key):
		return values[key]
	assert(fallback != null, "HeroData %s has no value '%s'" % [id, key])
	return fallback

func walk_speed(tuning: Tuning) -> float:
	return run_speed * tuning.walk_fraction

static func load_hero(hero_id: String) -> HeroData:
	return load(DIR + hero_id + ".tres") as HeroData

static func all() -> Array[HeroData]:
	var out: Array[HeroData] = []
	for hid in ORDER:
		out.append(load_hero(hid))
	return out

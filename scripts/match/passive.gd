class_name Passive
extends Node

## Base for a hero's passive (MAKAPAL!, SALING-PUSA, DIRE-DIRETSO, MAY TIRA PA!, TAKBO NA!).
## One instance per hero, child of the Hero. The host and the Hero call these hooks;
## override what you need. Passives stay on when Skills are Off (Tradisyonal).

var hero: Hero
var host: MatchHost

func passive_name() -> String:
	return hero.data.passive_name if hero and hero.data else name

func v(key: String, fallback: Variant = null) -> Variant:
	return hero.data.v(key, fallback)

## Every tick after movement (step 3).
func tick(_dt: float) -> void:
	pass

## Speed bonus fraction this passive gives right now (0.15 = +15 %). Bonuses don't stack:
## the hero uses the biggest of all its bonuses.
func speed_bonus() -> float:
	return 0.0

# ---- event hooks ---------------------------------------------------------------------
func on_tag_pressed() -> void:
	pass

func on_skill_cast(_skill: Skill) -> void:
	pass

func on_capture_start() -> void:
	pass

## Pushed, slowed or stunned. by_enemy_skill is true when an enemy skill did it (terrain and
## hazards pass false), which is what resets DIRE-DIRETSO.
func on_pushed(_by_enemy_skill: bool) -> void:
	pass

func on_slowed(_by_enemy_skill: bool) -> void:
	pass

func on_stunned(_by_enemy_skill: bool) -> void:
	pass

## A successful tag landed on this hero. Return true to absorb it (MAKAPAL! guard break):
## the target is not jailed, the tagger does not stumble, and the TagSystem reports a
## guard break (it still counts as a successful tag for sudden death, Impact and badges).
func absorb_tag(_tagger: Hero) -> bool:
	return false

## This hero just freed `freed` (array of Hero) by touch or HILA!.
func on_rescue_performed(_freed: Array, _by_skill: bool) -> void:
	pass

## Extra Escape Protection seconds this hero's rescues give (TAKBO NA!: +1).
func extra_rescue_protection() -> float:
	return 0.0

## This hero was just freed from jail.
func on_freed(_rescuer: Hero) -> void:
	pass

## This hero was just put in jail.
func on_jailed() -> void:
	pass

## True while this hero's footsteps make no sound or on-screen cue (SALING-PUSA).
func footsteps_silent() -> bool:
	return false

func on_round_reset() -> void:
	pass

## For the HUD passive icon: {"fill": 0..1, "on": bool, "note": String}.
func hud_state() -> Dictionary:
	return {"fill": 0.0, "on": false, "note": ""}

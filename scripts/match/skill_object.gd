class_name SkillObject
extends Node3D

## Base for anything a skill leaves in the world: TALBOG! walls, IYAK! decoys, SUMBONG KITA!
## fakes, UBO! UBO! packets and clouds, BUGA! trails, MAY TIRA PA! patches, IHIP! lanes.
## Spawn with host.spawn_object(obj); the host ticks it in step 3 and removes it when it
## expires, at round reset and at round end. Objects are part of the host's world state,
## so they must only change in tick(), never in _process (that is presentation only).

var host: MatchHost
var owner_hero: Hero
var team := 0
var ticks_left := -1 ## -1 = lasts until round reset
var expired := false

## Tag targets: Nene's decoy and fake rescuer count as tag candidates of their team, but
## tagging them is a failed tag (spec § 2 Tagging). The TagSystem reads these.
var is_tag_decoy := false
var decoy_radius := 0.4

func setup(p_host: MatchHost, p_owner: Hero, seconds: float = -1.0) -> void:
	host = p_host
	owner_hero = p_owner
	team = p_owner.team if p_owner else 0
	ticks_left = RB.ticks(seconds) if seconds > 0.0 else -1

## Step 3. Default: count down and expire.
func tick(_dt: float) -> void:
	if ticks_left > 0:
		ticks_left -= 1
		if ticks_left == 0:
			expire()

func expire() -> void:
	if expired:
		return
	expired = true
	_on_expire()
	if host:
		host.remove_object(self)
	queue_free()

## Override for end-of-life effects (fade out, collision off).
func _on_expire() -> void:
	pass

## Vision: true if this object hides a hero standing at target_pos from `viewer`
## (UBO! UBO! cloud). viewer may be null for "an observer outside everything".
func hides(_viewer: Hero, _target_pos: Vector3) -> bool:
	return false

## A decoy was tagged (a failed tag). Decoys stay; override for feedback.
func on_decoy_tagged(_tagger: Hero) -> void:
	pass

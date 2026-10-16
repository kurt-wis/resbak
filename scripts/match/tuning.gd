class_name Tuning
extends Resource

## Every shared tuning number (docs/RESBAK.md § 3 "Numbers at a glance", plus the rule
## timings in § 2, § 6, § 7 and § 11). The values live in data/tuning.tres; the defaults
## below match the spec so a missing .tres still plays by the rules.
## Per-hero numbers (speed, reach, cooldowns, skill values) live in HeroData instead.

const PATH := "res://data/tuning.tres"

@export_group("Movement")
@export var walk_fraction := 0.5 ## walking speed = run speed x this (gamepad only)
@export var stick_dead_zone := 0.15
@export var stick_run_tilt := 0.5 ## tilt >= this runs, below walks
@export var acceleration := 40.0 ## m/s^2 toward the wanted velocity
@export var deceleration := 50.0
@export var body_radius := 0.4
@export var height_gap := 1.0 ## > this vertical gap: no collision, tag or rescue
@export var push_time := 0.2

@export_group("Tagging")
@export var tag_arc_deg := 45.0 ## either side of the lunge
@export var tag_windup := 0.15
@export var tagged_freeze := 0.8
@export var failed_tag_stumble := 0.5
@export var danger_border_range := 10.0
@export var tag_assist_range := 2.4
@export var tag_assist_angle_deg := 30.0
@export var tag_assist_turn_deg := 15.0

@export_group("Bases")
@export var base_ring_radius := 2.0
@export var base_barrier_radius := 2.4 ## own team kept this far (centre to centre) from its own pole
@export var pole_radius := 0.2
@export var capture_range := 1.0 ## gap, attacker body to pole
@export var capture_hold := 1.5

@export_group("Jail and chain")
@export var anchor_range := 1.0 ## within this of the marker to become the anchor
@export var join_range := 1.5 ## within this of the anchor or tip to join
@export var hand_point_offset := 1.5 ## hand point is this far outside the barrier
@export var chain_link := 1.5
@export var chain_max := 4
@export var rescue_touch := 0.8 ## centres
@export var lone_anchor_touch := 0.4 ## rescuer centre to hand point
@export var escape_protection := 4.0
@export var capture_lockout := 4.0

@export_group("Rounds and match")
@export var countdown := 3.0
@export var round_time := 120.0
@export var sudden_death_time := 30.0
@export var untimed_sudden_death_after_draws := 2
@export var points_to_win := 3
@export var between_rounds_banner := 2.0
@export var between_rounds_freeze := 2.0
@export var between_rounds_score := 3.0
@export var capture_slow_motion := 0.5
@export var spawn_spacing := 1.2 ## metres between heroes sharing a spawn

@export_group("HUD and senses")
@export var footstep_range := 15.0
@export var minimap_ally_sight := 12.0 ## enemies show on the minimap within this of an ally
@export var chase_music_range := 10.0
@export var tag_feed_seconds := 5.0
@export var tag_feed_lines := 5

@export_group("Bots")
@export var bot_role_interval := 1.0
@export var bot_bantay_radius := 8.0
@export var bot_atake_clearance := 8.0
@export var bot_retreat_range := 6.0
@export var bot_pain_teammate_range := 15.0
## index 0 Madali, 1 Katamtaman, 2 Mahirap (spec § 11 table)
@export var bot_reaction := PackedFloat32Array([0.6, 0.35, 0.2])
@export var bot_retreat_ignore := PackedFloat32Array([0.3, 0.1, 0.0])
@export var bot_skill_use := PackedFloat32Array([0.2, 0.5, 0.9])

static var _cached: Tuning

## The project tuning, loaded once and shared.
static func get_default() -> Tuning:
	if _cached == null:
		_cached = load(PATH) as Tuning if ResourceLoader.exists(PATH) else Tuning.new()
	return _cached

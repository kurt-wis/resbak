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
## Everyone moves at this fraction of their sheet speed (v0.2 playtest: the court felt too fast).
## Applies to run, walk and skill-fixed speeds; the chain has its own speeds below.
@export var move_speed_scale := 0.8

@export_group("Tagging")
@export var tag_arc_deg := 45.0 ## either side of the lunge
@export var tag_strip_fill_alpha := 0.12
@export var tag_strip_attack_alpha := 0.18
@export var tag_strip_outline_alpha := 0.9
@export var tag_strip_outline_width := 0.025
@export var tag_strip_half_width := 0.16 ## narrow straight sweep, expanded by the target body radius
@export var tag_aim_drag_pixels := 22.0 ## reference UI pixels before manual selection
@export var tag_aim_cancel_pixels := 210.0 ## legacy aim-pad extent (not a cancellation threshold)
@export var tag_followthrough := 0.18
@export var tag_contact_fraction := 0.55 ## source Tag clip pose at impact
@export var tag_contact_height := 0.65 ## fraction of the tagged model height
@export var hila_retract_time := 0.2 ## presentation only; rescue/pull ends immediately
@export var tag_windup := 0.3 ## v0.2: a slower, readable hampas (spec 0.15)
@export var tagged_freeze := 0.8
@export var failed_tag_stumble := 0.5
@export var danger_border_range := 10.0
@export var tag_assist_range := 2.4
@export var tag_assist_angle_deg := 30.0
@export var tag_assist_turn_deg := 15.0
## Touch can keep aiming at an acquired visible enemy while moving away. This is aim only.
@export var touch_target_release_range := 3.0

@export_group("Character presentation")
@export var character_pose_fps := 24.0 ## stepped poses; simulation and rendering retain their own rates
@export var character_outline_pixels := 1.0
@export var locomotion_idle_blend_speed := 0.12

@export_group("Bases")
@export var base_ring_radius := 2.0
@export var pole_radius := 0.2
@export var capture_range := 1.0 ## gap, attacker body to pole
@export var capture_hold := 1.5

@export_group("Jail and chain")
@export var chain_link := 1.5 ## max centre gap between neighbours (the post counts as link 0)
@export var chain_max := 4 ## longest chain that still reaches out (5 jailed = lockdown)
@export var chain_tip_speed := 2.6 ## the last prisoner caught steers the chain this slowly
@export var chain_follow_speed := 2.1 ## how fast a pulled link catches up (the drag)
@export var chain_slack := 0.85 ## a link only moves once its neighbour is this x chain_link away
@export var post_hold_offset := 0.55 ## the first prisoner stands this far out from the post
## Jail line (v0.2): the post slides along the map's JailLine_<team>; the first prisoner drags
## it this fast. "In jail" = within jail_band of the line.
@export var chain_post_speed := 1.6
@export var jail_band := 1.4
@export var jail_post_barrier := 1.0 ## free players are kept this far from the post
@export var rescue_touch := 0.8 ## centres
@export var escape_protection := 4.0
@export var capture_lockout := 4.0

@export_group("Rounds and match")
@export var countdown := 3.0
## Round-1 intro flyover (2026-10-17): the arena, each team's spawn (x2), then the faceoff.
@export var intro_arena := 2.0
@export var intro_team := 2.5
@export var intro_faceoff := 1.0
@export var round_time := 120.0
@export var sudden_death_time := 30.0
@export var final_stretch_time := 30.0 ## round-clock seconds left when the music turns tense (spec § 7)
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
@export var announce_banner_time := 1.8 ## s each announcer banner stays up (v0.2)
@export var announce_queue_max := 3 ## announcer calls waiting; older ones drop
@export var announce_multi_window := 4.0 ## s between tags that chain DOBLENG / TRIPLENG HULI!
@export var announce_streak_hot := 3 ## tags without being caught: MAINIT!
@export var announce_streak_beast := 5 ## HALIMAW!
@export var announce_streak_unstoppable := 7 ## DI MAPIGILAN! (and every 2 more)

@export_group("Bots")
@export var bot_role_interval := 1.0
@export var bot_bantay_radius := 8.0
@export var bot_atake_clearance := 8.0
@export var bot_retreat_range := 6.0
@export var bot_pain_teammate_range := 15.0
## index 0 Madali, 1 Katamtaman, 2 Mahirap (spec § 11 table)
## Per-attempt decision delay and post-Sabay sidestep break synchronized retry loops.
@export var bot_tag_delay_min := PackedFloat32Array([0.12, 0.08, 0.04])
@export var bot_tag_delay_max := PackedFloat32Array([0.28, 0.2, 0.14])
@export var bot_sabay_reposition_min := 0.12
@export var bot_sabay_reposition_max := 0.3
@export var bot_reaction := PackedFloat32Array([0.6, 0.35, 0.2])
@export var bot_retreat_ignore := PackedFloat32Array([0.3, 0.1, 0.0])
@export var bot_skill_use := PackedFloat32Array([0.2, 0.5, 0.9])
## v0.1.1 bot brains (docs/status.md): chance a bot falls for a trick (BAWAL! bait), per
## difficulty; how long a chase may go without closing in before the bot gives up;
## the jail guard (Tanod) leash around the chain tip; no capture start with an enemy this close.
@export var bot_fooled_chance := PackedFloat32Array([0.9, 0.6, 0.3])
@export var bot_chase_give_up := 2.5
@export var bot_tanod_radius := 7.0
@export var bot_capture_safety := 3.0

static var _cached: Tuning

## The project tuning, loaded once and shared.
static func get_default() -> Tuning:
	if _cached == null:
		_cached = load(PATH) as Tuning if ResourceLoader.exists(PATH) else Tuning.new()
	return _cached

@export_group("Free training")
@export var training_reset_delay := 3.0
@export var training_cooldown_scale := 0.5
@export var training_dummy_distance := 3.0
@export var training_dummy_spacing := 2.5

@export_group("Skill aiming presentation")
@export var skill_aim_pad_radius := 130.0
@export var skill_preview_fill_alpha := 0.12
@export var skill_preview_outline_alpha := 0.9
@export var skill_preview_wall_alpha := 0.22
@export var skill_preview_line_width := 0.045

@export var touch_cancel_radius := 54.0

@export_group("Cast animation timing")
@export var skill_cast_plant := 0.3
@export var smoke_visibility_fade := 0.25
@export var smoke_cough_animation := 0.7

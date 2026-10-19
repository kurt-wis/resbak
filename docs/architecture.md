# Runtime architecture

## Stepped character poses and JM cloth (2026-10-19)

`HeroVisual` drives its AnimationTree manually with accumulated fixed 1/24 s presentation steps. It retains fractional time across render frames and leaves host ticks, body transport, camera and UI untouched. `DioramaActor.step` uses the same tuning cadence for Home hero poses. Character cloth retains smooth secondary motion.

`HeroAccents` owns `jm_towel_motion.gd`: a fixed palm grip, damped world-space strand, distance constraints and torso contact rejection drive the rolled towel. Its actual finger hinge is skinned. `hair_motion.gd` runs after the elastic arm, modifying only four Head-descendant braid joints with inertia and back-of-blouse clearance. These nodes inherit visibility/pause and never decide gameplay contacts. Tamaraw miss feedback retains the existing host recovery.

Locomotion uses cyclic synchronization with measured walk speeds, early transition toward run poses and a smoothed blend position. Playback correction is capped at `locomotion_max_rate`. Tag/Miss clips share contact poses and longer recovery fades. Skill one-shots seek from host time, keeping release poses synchronized on slow render frames and pauses.

`Skill.cast_plant_seconds()` replaces a blanket plant: zero for moving BAWAL/traversal, one second for IHIP formation, 0.30 seconds for UBO preparation, otherwise the shared plant. UBO stores an InputFrame at cast and releases on its host deadline; disruption before release ends the pending skill. IHIP owns `age_ticks/form_ticks`, uses formed length for membership/priority and scales its surface/ribbons to that front. Its lifetime starts at placement; tagging its owner does not remove it.


## Hero presentation and control update (2026-10-18)
- `Hero` retains stick magnitude for proportional analog creep/walk/run after the dead zone. Keyboard and maximum speeds are unchanged. Locomotion blends against the scaled gameplay speeds; measured gait rates drive playback without speeding a tiny-stride character walk to extremes.
- TALBOG uses a downward terrain query shared by aiming, flight endpoint, public marker and impact. It pushes and stuns nearby enemies; no wall object or ghost is spawned. TAMARAW adds a once-per-enemy short slow and plays an animated spectral GLB around JM.
- `elastic_arm.gd` runs after animation/chain modifiers and stretches Inday's actual weighted right arm. `Sagip` is an authored reach/recovery clip. `HilaHand` is only the host-owned touch target; a miss retains its endpoint through that tick's rescue resolution, then closes next tick. No detached palm/beam is rendered. Final pose measurement uses `modification_processed`.
- `Hero.blind_ticks` is a host timer. UBO's initial burst applies it once; re-entry does not refresh it. Smoke concealment and blindness precede ally/reveal shortcuts in `visibility()`. Only the cloud owner inside sees other heroes inside, with solid LOS; overlapping hostile smoke still hides them. Bots cannot bypass zero visibility with their close-range perception shortcut. Minimap allies follow the same query.
- `hero_feedback.gd` attaches status icons under viewer-hidden extras; `hero_accents.gd` supplies the palm-held rolled towel and character wind ribbons. `hud_powder.gd` draws local white powder blindness/cloud obstruction. UBO puffs thin for the owner; the hologram uses a Compatibility spatial shader. These nodes never decide hits, rescues or movement.

As shipped. If this disagrees with the code, the code wins, so fix this file.

## Scene flow
`scenes/frontend/boot.tscn` (main scene) → `title` → `first_setup` (until `Save.profile.setup_done`) →
`home` → `play_menu` → `roulette` (map wheel, base site) → `draft` (snake A1 B1 B2 A2 A3 B3 B4 A4 A5 B5) →
`scenes/match.tscn` → `results` → `roulette` (LARO ULIT) or `home`. `settings` is reachable from title and home.
Home ENSAYO opens `training.tscn`: hero/map/target selection, Free Training or the existing Tutorial. `Session.prepare_training` bypasses roulette/draft; leaving free training returns to this menu.
Every screen extends `FrontScreen` (`scripts/ui/frontend/front_screen.gd`); `FE` holds the theme, colours,
routing (`FE.go`, chalk wipe) and settings application. Screens are built in code; the `.tscn` files are one node + script.

Autoloads: **Save** (settings.cfg + profile.json), **Session** (room settings, lineup, local slot, last results),
**Audio** (buses Music / Effects / Voices / Announcer, announcer queue, `cue` signal for subtitles).
`Controls.ensure()` registers the default bindings (spec § 9) at runtime so Settings can rebind them.

## Home (`scripts/ui/frontend/home.gd`)
Home is a `FrontScreen` that draws no backdrop of its own (`draws_backdrop()` is false). Behind the UI it hosts
a `SubViewportContainer` → `SubViewport` (own 3D world, MSAA 2×, 3D audio listener) holding a `HomeDiorama`;
headless runs skip the 3D view. `HomeDiorama` (`home_diorama.gd`) builds the store set, five `DioramaActor`s
(heroes) and four walkers (bystanders), the jeepney and ambient dust from `HomeDioramaData`
(`home_diorama_data.gd`, `data/home_diorama.tres`; all numbers live there). Time is the 48 s `Timeline`
AnimationPlayer, advanced by hand in `step(delta)`: gesture cues call `request_gesture` / `end_gesture` on the
actors, bystanders and the jeepney are positioned from the loop time, so `seek_to(t)` reproduces any frame.
The `turn_started(hero, line)` signal drives voice chatter and `jeep_started` the engine sound (live only;
tools and tests run with `manual = true`, silent). Colours come from `shaders/diorama_set.gdshader`. The sky
(`diorama_sky.gdshader`, `phase` set from the loop time) and the depth blur (`diorama_dof.gdshader`, a "DepthBlur"
quad child of the camera, `dof_*` in the data) are shaders because Compatibility has no built-in DoF.
The player card opens `HeroPicker` (`hero_picker.gd`, a child of Home: `chosen(id)` / `closed`), which saves
`profile.home_hero`; ENSAYO plays that hero. `HomeSkin` holds the sticker / cardboard styleboxes. Music and the
ambience start in `_start_audio` and fade out on navigation (Settings keeps them playing).

## The match (`scenes/match.tscn`, `scripts/match/match_scene.gd`)
Builds lighting (`MapDressing`), the map, a `World` node for heroes and skill objects, the **MatchHost**,
`PlayerInput` for the local slot and a `BotBrain` for every other slot, `MatchCamera`, `MatchView` and `Hud`.
At `match_end` it stores `Session.last_results` and changes to the results screen.

### MatchHost (`scripts/match/match_host.gd`)
One `step()` per `_physics_process` (60 ticks/s), in spec § 12 order:
1. inputs: `hero.set_frame(source.frame_for(hero, host))` for every slot (`input_sources[slot]`)
2. actions: skill presses (`Skill.try_cast` / `on_recast` / `tick_action`), Tag press → `TagSystem.handle_tag_button` → immediate `start_windup`, Interact → `BaseSystem.handle_interact` (free) or `JailSystem.handle_interact` (jailed)
3. movement: timers, `Hero.tick_move` (push > movement skill > normal running), chain layout and Tagged → jail, `SkillObject.tick`, skills' and passives' `tick`
4. barriers: jail barrier (the own-base ring barrier was removed 2026-10-17)
5. tags resolved (stored), 6. rescues found, 7. both applied, 8. captures, 9. round end (`RoundFlow.check_end`)
10. events are emitted as they happen through the `event(kind, data)` signal (HUD, view, audio, bots, tests listen)

`manual_step = true` lets tests drive `step()` tick by tick. State lives in the host and its children only;
`_process` code is presentation. Queries: `visibility(viewer, target)`, `can_tag`, `los_clear`, `ray_hit`,
`free_heroes_near`, `enemies_of`, `spawn_object`. Stats per slot feed the results screen.

### Systems (`scripts/match/systems/`)
`TagSystem` (release-committed narrow tag, shared `aim_direction` / `preview_target` queries, hit test, Sabay fall/recovery, evasion hook, guard-break hook, Impact), `BaseSystem` (active site,
pole and ring, barrier, capture), `JailSystem` (v0.2 jail line: `post(owner)` slides along `layout.lines[owner]`, `out_dir`, `is_post_holder`, `is_tip`, `can_steer`, `rescue_point`; chain, rescue incl. skill touch points), `RoundFlow`
(phases INTRO (round 1 only, unless the `skip_intro` setting is true) → COUNTDOWN → PLAYING → SUDDEN_DEATH → ROUND_OVER → MATCH_OVER, score, draws, reset to spawns).
`MapLayout` reads base sites, jails, markers and spawns from the map (spec names or the court's older names,
deriving what is missing) and puts small props on the vaultable layer. v0.2: one fixed `BaseSite_<team>` per team and a
`JailLine_<team>` Path3D per map end (`line_point`, `line_project`, `line_normal`, `line_length`).

### Heroes
`Hero` (CharacterBody3D, `scripts/match/hero.gd`): state FREE / TAGGED / JAILED / CHAINED, tick timers
(EP, capture lockout, stumble, stun, tag block), speed = base × (1 + biggest bonus) × (1 − strongest slow) or a
skill's fixed speed, `apply_push`, `add_slow`, `add_speed_bonus`, `stun`, `stumble`, `reveal_to`, collision
layers (solid when Free without EP). The body never rotates; `facing` and `aim` are vectors.
`Hero.stumble` captures `fall_facing` from the swing that missed (its lunge direction), and `_update_facing` holds that direction for the whole stumble, so a fallen hero cannot be turned by the aim stick or mouse until the recovery ends.
Sabay keeps both heroes Free and taggable, blocks actions for `failed_tag_stumble`, and counts down `sabay_ticks`; `HeroVisual` rolls each model down and upright from this host timer without changing collision bodies.
`HeroVisual`: outline width comes from `Tuning.character_outline_pixels` (1 px), also used by Home, portraits and legacy hero previews; the shared shader default used by map props is unchanged. Model normalised to 1.8 m, toon + outline materials (fade variant for see-through), an
AnimationTree with a continuously evaluated Idle/Walking/Running base, plus alternating seekable action slots through `Mode` into `ActionLayer`. The latter filters spine/arms/head for moving casts, Jailed and Chained, or uses full-body blending for slides/jumps/stuns/falls/capture. Source clips still animate the full skeleton. `locomotion_heading.gd` turns the hips toward travel and preserves the spine's action orientation before arm IK; backwards travel reverses the foot cycle. Locomotion speed updates while an action is playing, not just when clips change. Markers include overhead nametags, the EP shield and `extras`; legacy team-ring/icon nodes stay hidden.
`tag_started_tick` drives the Tag pose: `tag_contact_fraction` of the source clip lands at `tag_windup`, followed by `tag_followthrough`. Tag uses the authored full-body clip, with no procedural arm retargeting or forward model displacement. Commitment plants horizontal movement through wind-up plus follow-through (currently 0.43 s), blocks repeated attacks, new skills and capture, and releases movement automatically afterward. Forced push/stun rules remain authoritative. Aiming before release does not freeze movement. The authoritative `tag`/`guard_break` event carries the body contact `point` for impact effects. Chained always retains the holding layer over idle/walking, with existing hand-grip IK. HILA reuses Sagip as a seekable upper-body extend/hold/retract pose driven by the actual hand object; a returning hand is cosmetic only after gameplay expiration.

Each hero has two `Skill`s and a `Passive` (scripts in `scripts/match/skills/<hero>/`, wired in
`data/heroes/<id>.tres`). Skill hooks: `kind`, `_cast`, `on_recast`, `tick_action`, `controls_movement` +
`move`, `tick`, `end(reason)`, `blocks_tagging`, `blocks_other_skills`, `can_be_pushed`, `fixed_speed`,
`evade_tag` (LUSOT! perfect), `rescue_touch_point` + `rescue_touch_radius` (HILA!: a point that counts as touching a
chain tip), `absorb_tag` + `warded` (BAWAL!: cancel a landed tag; bots avoid warded heroes), `on_owner_event`. Passive hooks: `speed_bonus`,
`absorb_tag` (MAKAPAL!), `on_rescue_performed`, `extra_rescue_protection`, `footsteps_silent`, `hud_state`, ...
Placed things (walls, decoys, clouds, patches, lanes, trails) are `SkillObject`s spawned with `host.spawn_object`;
`is_tag_decoy` makes the TagSystem treat them as decoys, `hides()` drives cloud vision.

### Bots (`scripts/match/bots/`)
`BotCoord` assigns roles per team every second; `BotBrain` turns role + perception into an `InputFrame`;
`BotNav` bakes a navmesh from the map once per match. Same rules and frames as players. Each eligible tag attempt has a seed/slot-dependent decision delay from `bot_tag_delay_min/max`. After Sabay, bots schedule a short sidestep (`bot_sabay_reposition_min/max`) after the shared recovery, then reconsider their target. Pending decisions clear across jail/round changes; attack wind-up, reach and simultaneous-hit rules remain shared.

### Presentation
`MatchView` sets per-viewer alpha, outline colour, overhead nametags, a private filled `TagStrip` and world feedback. The straight strip has `tag_strip_half_width` on either side, shows actual centre-distance reach and uses a low-opacity red fill with a separate red outline. It appears only while holding aim or during the committed wind-up; other players' attack guides are never drawn. No character team/target rings are visible. The chosen enemy's nametag brightens locally. Body overlap with the narrow sweep determines contact, never the indicator mesh. During INTRO it also drives the camera flyover (`MatchCamera.intro_w` / `intro_focus` / `intro_size`) and calls `Audio.play` for host events (`SFX` table). `HudIntro` draws the INTRO banners (map title, both teams, faceoff) and the skip prompt. `ArenaArt` draws the bases: the court's basketball stand, or the map's `Gameplay.base_prop` scene (Konstruksyon's sand castle, which crumbles on capture). `OcclusionFade` (`scripts/match/occlusion_fade.gd`, maps with `Gameplay.occlusion_fade`) fades tall props between the camera and the local hero by swapping alpha-blended duplicate materials (the Compatibility renderer ignores `GeometryInstance3D.transparency`); presentation only. `MapDressing.add_dust` adds drifting dust when `Gameplay.dust` is set.
`Audio` (autoload): `play(name, text, pos)` cues, `play_music(name, fade)` / `stop_music(fade)` / `set_music_layer(layer, on, fade)` (a `<name>_<layer>` stem, e.g. `music_construction_site_tension`, that crossfades with the base track; `match_scene` turns it on at the host's `final_stretch` event, 30 s left, or at sudden death). `MatchScene.MUSIC` / `AMBIENCE` map a map id to its music name and ambience file. Missing audio files are silent, never errors.
`Hud` (`scripts/ui/hud/`) is a set of `HudPart`s on a CanvasLayer built for 1920×1080. `HudAnnouncer` turns host
events into queued MOBA-style call ribbons (streaks counted from events, numbers in Tuning "HUD and senses") and
sends each to `Audio.announce`. `MatchCamera` is Kurt's orthographic isometric camera, locked at view size 8 during gameplay (no wheel/pinch zoom or speed/elevation widening); follow, lead, swivel, flip, shake and the scripted intro flyover remain; `PlayerInput` reads its
`view_yaw()` so frames stay in world space.

## Physics layers (`RB`)
1 world · 2 hero solid · 3 hero ghost · 4 skill wall (TALBOG!) · 5 vaultable props · 6 base pole.
Skill line of sight uses world + skill wall + vaultable.

## Input (`scripts/autoload/controls.gd`, spec § 9)
Move WASD / left stick · aim mouse / right stick · tag LMB / RT · skills Q, E / LB, RB · interact F / A ·
ping G, MMB / D-pad up · scoreboard Tab / View · menu Esc / Start · hide HUD F10.
Touch match controls (`hud_touch.gd`, shown by default on all devices; Gameplay > On-screen controls can hide them on desktop, while touch devices and `--touch-controls` keep them available): left stick, TAG aim pad, S1/S2 and hold BASE. A quick TAG tap commits on release; holding and dragging previews direction and selects an opponent without charging or changing reach/speed. Dragging outside `tag_aim_cancel_pixels` cancels; returning inside resumes aim. Mouse/RT use the same release-to-commit input: hold and aim with cursor/right stick, cancel with RMB/B. Lost focus, pause, disabled input and unavailable tag actions discard pending aim.
`PlayerInput` quick taps select the nearest visible eligible enemy within actual tag reach in any direction; manual aiming selects by alignment in the forward aim cone, retaining that selection while retreating only while it stays in reach. Manual aim prefers angular alignment, then distance. Walls, hidden enemies, EP/immunity and BAWAL! prevent acquisition; disabling tag assist disables selection. Touch may also tap a visible opponent to switch without attacking. `InputFrame.tag_aim_dir` and `tag_target_slot` carry tag-only direction and selected identity independently of movement/skill aim. The host snapshots both at commitment; only that opponent can receive the attack, and must remain inside the fixed-direction body sweep at landing. Directional/bot attacks also snapshot an in-sweep target if present. An unselected directional swing can catch a body entering its path. No homing after release, no universal dodge button/invulnerability. Movement-based sidesteps, first landing and exact-tick Sabay remain shared. This is match input support, not an Android/iOS export or touch-ready front end.

Legacy actions `skill_harurot`, `skill_lusot`, `action_tag` stay in `project.godot` for the Batang Hamog prototype.

## Project settings worth knowing
Godot 4.7 Mono · `gl_compatibility` · Jolt Physics · 60 physics ticks/s · viewport **1920×1080**, stretch
`canvas_items` / `expand`, window mode borderless fullscreen · MSAA 4× · `user://` = `%APPDATA%\RESBAK` ·
editor plugin `addons/meshy-godot-plugin`.

## Legacy dev scenes
`scenes/character_select.tscn`, `court_playtest.tscn` (`HeroController`, `--hero=hamog` for the Batang Hamog
prototype) and `movement_test.tscn` predate the match and are kept for reference; the `legacy` suite still checks them.

## Free training
`Session.mode = training`, with `practice` and `free_training` settings, uses the normal match scene on either existing map. `MatchHost.training` (`TrainingMode`) starts live, freezes the practice clock, scales instantiated skill cooldowns by `training_cooldown_scale`, and positions three nearby opponents from the map's authored `Gameplay/TrainingSpawn` marker (position and forward +Z). Stationary mode supplies empty InputFrames; active mode installs the normal BotBrains. Tag/capture/guard-break events schedule a whole-scenario reset after `training_reset_delay`. The RESET button queues intent consumed by the host after its tick; it clears objects, jail chains, timers, cooldowns, stats and base presentation. Normal round scoring is disabled by existing practice rules; no results/progression screen is reached. Offline pause works normally. This is a local test sandbox, separate from the scripted tutorial and the future multiplayer Kanto feature.

### On-screen controls
The left movement joystick and right TAG aim pad support independent fingers. TAG and S1/S2 hold/drag to choose a direction and release once; releasing on the separate × target cancels; long drags remain valid aim. Skill aim uses `InputFrame.aim_dir` independently of movement; the normal skills still own their range and movement rules. Skill names, readiness and cooldown arcs appear on the actual buttons, replacing duplicate keyboard skill cards while controls are visible. BASE retains hold-to-capture. The MENU button emits `Hud.pause_requested` and uses the existing offline pause flow without a keyboard.
Mouse gestures over the pads are consumed locally and mirrored into the same control state for desktop testing; pointer capture prevents duplicate world-click attacks or device switching mid-drag. WASD remains available while a mouse pad is held. Touch state/skill previews/pointer capture clear on focus loss, pause, hiding the HUD or disabling input. The layout uses the HUD's reference canvas transform so hit areas track viewport scaling. This adds match controls, not a mobile export pipeline.

### Skill aiming contract
`SkillAim` maps the ten kit slots to icons, hints and preview geometry, reading range/width/radius from HeroData. `Skill.aim_preview(InputFrame)` is read-only; TALBOG and UBO override it with the same wall/range/trajectory query consumed by their real casts. `TalbogWall.segment_layout` supplies both ghost boxes and actual collision boxes. `SkillAimView` belongs to MatchView and renders only the local held, available skill; unchanged intent reuses its meshes. It never spawns gameplay objects. Self buffs use an overhead cue rather than a fabricated ground area.

There is no skill aim assistance. `SkillAim` only describes the shape a skill will use; the preview frame and the released frame carry the same direction or point, and the only assist in the game is `TagSystem._assisted` (gamepad tag assist, unchanged). Skills steered by the player's body say so with `Skill.aim_from_movement()`: TAMARAW!!! returns true, so `SkillAim.describe` and its cast read `HERO.wish_dir` (or `facing` when the stick is centred) and never the aim point. TAMARAW! also reports `mode: "self"`, so no shape is drawn for it, and `MatchView` skips its committed tell — like HARUROT! it only moves. Pressing S2 again still runs `on_recast`, cancelling the charge.

`Skill.try_cast` captures `committed_aim`, `committed_origin` and `committed_until_tick` (the longer of `cast_plant_seconds()` and the skill's tell time) before running `_cast`. This is the single source of truth for the committed direction and for the public tell; enemies may still dodge afterwards because nothing homes or re-acquires. BUGA! holds `locked_facing()` from the committed direction while its inhale/spit window is open and releases `active` on the last spit tick so a press on the plant's final tick casts instead of being read as a recast.

`MatchView._refresh_skill_tells` walks every hero's committed skills and keeps one `SkillAimView` per live commit (TALBOG! keeps its own flight marker and SIGAW!'s travelling fan is its own public tell). Public tells are drawn from `committed_aim` only, so they show the same shape and nothing private. `SkillAimView` draws each outline as a dark ink under-stroke (`skill_preview_ink_scale`, `skill_preview_ink_alpha`) plus the skill's bright opaque stroke over a restrained fill, all at fixed ground lifts so the layers never z-fight. There is no in-world text and no target highlight: the shape and its colour carry the state (skill colour, red for cancel, amber for blocked, cyan for max range).

`PlayerInput` retains skill-pad direction and normalized drag distance through release, populating aim points for point skills. `InputFrame.skill_aimed` distinguishes explicit skill aim: Tutoy's slide can use it, while Harurot uses only movement/velocity/facing. Release queues one cast unless cancelled on the dedicated × target. Preview state clears with the input lifecycle. Only TAMARAW exposes an early-stop recast; placed IHIP does not channel or recast.
During TALBOG flight, its skill-owned world marker shows landing/push radius and future wall to everyone; it is destroyed on landing or cancellation. This public committed tell is independent of the local-only preview. Other existing skill effects retain their visibility rules. Preview paths are initial intentions: dynamic movement, target interception and host collision handling still decide the outcome.

### Deliberate touch cancellation
The HUD owns a separate cancel target above the right controls, visible only during TAG/skill aiming. Drag distance never cancels; aim direction remains valid outside the pad and point selection saturates at maximum range. Each drag and final release position updates cancellation, so entering × turns the cue red, moving away restores aim, and only release inside × cancels. OS cancellation/focus loss/pause still discard the gesture. Target size is `Tuning.touch_cancel_radius` in reference-canvas pixels. The controls use dark backplates, kit-colored accent rims, high-contrast labels/icons and a brighter held state.

### Shared match atmosphere
Both maps now own their sun/WorldEnvironment under LightingAndEnvironment, so MapDressing.add_lighting only applies the no-shadows toggle and leaves authored lighting in place. Court uses the construction lighting model with cooler fill, less amber sunlight and lighter haze. Gameplay/presentation metadata feeds optional dust amount/color/size/speed and screen ink/haze overrides. MatchScene passes the map to add_ink_edges and the metadata to add_dust; defaults preserve the construction dust treatment. Particles are top-level because play bounds are world-space even for scaled/offset map roots. Both cameras use illustrated_edges.gdshader with a 0.8 pixel stroke and the existing focus update. Material-specific paint, sand, timber and water shaders remain appropriate to their surfaces. The court retains its barangay audio bed rather than construction harbor/engine sounds.

### Court summer surface overrides
Gameplay/presentation's summer_finish enables MapDressing.apply_court_summer after court dressing. It duplicates materials with a shared-per-instance cache, applies supported summer_wear/summer_breeze uniforms and conservative StandardMaterial color/roughness settings, and localizes MultiMesh mesh/material references. Source scene/prop materials are never mutated. Mesh collision and placement stay unchanged. The shader include court_summer.gdshaderinc supplies opt-in pigment/highlight/fine-grain treatment; existing paint/concrete, prop, timber, vehicle and neighborhood shaders add their surface-specific detail. Procedural fine detail is filtered by screen footprint to reduce aliasing. Bunting is visual-only and receives zero summer_breeze under Reduce motion. Other maps keep default-zero summer parameters.
### Hero casting and placed wind revision — 2026-10-19

Hero owns host-ticked `cast_lock_ticks` and presentation-only `cough_ticks`. `Skill.try_cast` plants stationary casts; traversal casts remain exempt. Recovery blocks voluntary move/tag/new cast/capture, while tag eligibility and forced pushes retain their own rules. InputFrame carries `tag_preparing`; HeroVisual filters TagCharge onto the upper skeleton over locomotion. Committed Tag remains full-body and uses the host landing tick.

IHIP now spawns `ihip_lane.gd`, an independent SkillObject with immutable cast position, direction, dimensions and lifetime. The object maintains source-specific speed modifiers, removes them on exit/expiry, and exposes a geometric disadvantage query. TagSystem only consults that query for reciprocal clean hits in the same resolve batch. Its winner logic never changes earlier landing ticks. The skill keeps a read-only last-lane handle for previews/QA; it does not channel or drive owner movement.

MatchView interpolates only the model's alpha. Host.visibility remains authoritative for target selection, nametags and minimap concealment. Character shader ward strength reads the existing ward query. HudSkills presents clickable effect/passive icons with rounded detail panels; its pointer handling prevents accidental attack input.

# Runtime architecture

As shipped. If this disagrees with the code, the code wins, so fix this file.

## Scene flow
`scenes/frontend/boot.tscn` (main scene) → `title` → `first_setup` (until `Save.profile.setup_done`) →
`home` → `play_menu` → `roulette` (map wheel, base site) → `draft` (snake A1 B1 B2 A2 A3 B3 B4 A4 A5 B5) →
`scenes/match.tscn` → `results` → `roulette` (LARO ULIT) or `home`. `settings` is reachable from title and home.
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
2. actions: skill presses (`Skill.try_cast` / `on_recast` / `tick_action`), Tag press → `TagSystem.start_windup`, Interact → `BaseSystem.handle_interact` (free) or `JailSystem.handle_interact` (jailed)
3. movement: timers, `Hero.tick_move` (push > movement skill > normal running), chain layout and Tagged → jail, `SkillObject.tick`, skills' and passives' `tick`
4. barriers: jail barrier (the own-base ring barrier was removed 2026-10-17)
5. tags resolved (stored), 6. rescues found, 7. both applied, 8. captures, 9. round end (`RoundFlow.check_end`)
10. events are emitted as they happen through the `event(kind, data)` signal (HUD, view, audio, bots, tests listen)

`manual_step = true` lets tests drive `step()` tick by tick. State lives in the host and its children only;
`_process` code is presentation. Queries: `visibility(viewer, target)`, `can_tag`, `los_clear`, `ray_hit`,
`free_heroes_near`, `enemies_of`, `spawn_object`. Stats per slot feed the results screen.

### Systems (`scripts/match/systems/`)
`TagSystem` (wind-up, hit test, Sabay, evasion hook, guard-break hook, Impact), `BaseSystem` (active site,
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
`HeroVisual`: model normalised to 1.8 m, toon + outline materials (fade variant for see-through), an
AnimationTree blending Idle/Walking/Running by speed (playback scaled to the clip's measured foot speed) and an
action layer for state and skill clips (`play_action(clip, duration)`), team ring, "!" icon, EP shield, `extras`.

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
`BotNav` bakes a navmesh from the map once per match. Same rules and frames as players.

### Presentation
`MatchView` sets per-viewer alpha, outline colour, icons, the aim arrow (tip = reach of a swing released now, fills in with the charge) and world feedback; during INTRO it also drives the camera flyover (`MatchCamera.intro_w` / `intro_focus` / `intro_size`) and calls `Audio.play` for host events (`SFX` table). `HudIntro` draws the INTRO banners (map title, both teams, faceoff) and the skip prompt. `ArenaArt` draws the bases: the court's basketball stand, or the map's `Gameplay.base_prop` scene (Konstruksyon's sand castle, which crumbles on capture). `OcclusionFade` (`scripts/match/occlusion_fade.gd`, maps with `Gameplay.occlusion_fade`) fades tall props between the camera and the local hero by swapping alpha-blended duplicate materials (the Compatibility renderer ignores `GeometryInstance3D.transparency`); presentation only. `MapDressing.add_dust` adds drifting dust when `Gameplay.dust` is set.
`Audio` (autoload): `play(name, text, pos)` cues, `play_music(name, fade)` / `stop_music(fade)` / `set_music_layer(layer, on, fade)` (a `<name>_<layer>` stem, e.g. `music_construction_site_tension`, that crossfades with the base track; `match_scene` turns it on at the host's `final_stretch` event, 30 s left, or at sudden death). `MatchScene.MUSIC` / `AMBIENCE` map a map id to its music name and ambience file. Missing audio files are silent, never errors.
`Hud` (`scripts/ui/hud/`) is a set of `HudPart`s on a CanvasLayer built for 1920×1080. `HudAnnouncer` turns host
events into queued MOBA-style call ribbons (streaks counted from events, numbers in Tuning "HUD and senses") and
sends each to `Audio.announce`. `MatchCamera` is Kurt's orthographic isometric camera; `PlayerInput` reads its
`view_yaw()` so frames stay in world space.

## Physics layers (`RB`)
1 world · 2 hero solid · 3 hero ghost · 4 skill wall (TALBOG!) · 5 vaultable props · 6 base pole.
Skill line of sight uses world + skill wall + vaultable.

## Input (`scripts/autoload/controls.gd`, spec § 9)
Move WASD / left stick · aim mouse / right stick · tag LMB / RT · skills Q, E / LB, RB · interact F / A ·
ping G, MMB / D-pad up · scoreboard Tab / View · menu Esc / Start · hide HUD F10.
Legacy actions `skill_harurot`, `skill_lusot`, `action_tag` stay in `project.godot` for the Batang Hamog prototype.

## Project settings worth knowing
Godot 4.7 Mono · `gl_compatibility` · Jolt Physics · 60 physics ticks/s · viewport **1920×1080**, stretch
`canvas_items` / `expand`, window mode borderless fullscreen · MSAA 4× · `user://` = `%APPDATA%\RESBAK` ·
editor plugin `addons/meshy-godot-plugin`.

## Legacy dev scenes
`scenes/character_select.tscn`, `court_playtest.tscn` (`HeroController`, `--hero=hamog` for the Batang Hamog
prototype) and `movement_test.tscn` predate the match and are kept for reference; the `legacy` suite still checks them.

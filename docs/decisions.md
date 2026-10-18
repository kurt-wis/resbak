# Decision log

Short, dated, newest first. Add an entry when you make a choice that a future reader
would otherwise reverse by accident.

## 2026-10-19: Home hands made seamless by measuring them
- **One method track per gesture.** `HomeDiorama._build_timeline` adds a track per gesture for `_cue_gesture` / `_cue_gesture_end`. **Why:** an Animation track holds one key per instant, so two cues at the same time silently dropped one; Tutoy's end cue was lost at 37.6 s and his hand snapped 12 m/s at 39 s. The `home` suite probes that every gesture releases the upper body after its end.
- **Measure, then set the limits.** `HomeMotion.measure` steps the manually driven diorama at 60 Hz and tracks the hands and first-finger bones; the gate fails above 8.0 m/s speed or 3.0 m/s change per frame (measured 6.99 / 2.5 after, 12.0 / 12.2 before). **Why:** pops are brief and invisible in a still, so a numeric check is the only way to keep them fixed.
- **Smoothstep OneShot fades, settled gestures, cross-faded idles.** Linear fades kicked the velocity at both ends, so `gesture_fade_smooth` eases them; gesture clips are eased to the base idle's mean pose at both ends (`settle`) and trimmed to their `dur`; the sit idles use `loop_crossfade` rather than `loop_blend`. **Why:** each removes a velocity discontinuity at a known boundary. `Menu_CheerLeft` is settled at its tail only: easing a large swing in from the idle slerped the hand across the body (9 m/s per frame).

## 2026-10-18: Home diorama rebuilt to the art reference
- **The reference image is the source of truth for Home.** It is in the repo at `source_art/reference/home_target.webp` (Godot-ignored, plain git: webp is small and needs no LFS) and every Home prop is a Meshy image-to-3D model made from a square crop of it (`tools/crop_home_reference.py` → `source_art/reference/home_crops/`, then `tools/build_home_props.py`). **Why:** v0.1.2's store came from a text-to-3D prompt because the image was not on disk; the crops are the least-lossy way to tell the generator what to make, and `crop_home_reference.py` blends the UI stickers and the seated cast out of the boxes it keeps instead of hiding them behind geometry.
- **Computed seat fit, not hand-tuned offsets.** `HomeDiorama._seat_actor` reads the seat top from the stool's AABB and the pelvis and soles from the sitter's own `Menu_SitIdle`, puts the stool under the pelvis in XZ (not under the hero root) and scales it so the seat sits `seat_pad` (0.06 m) below the pelvis; `home` asserts it within 3 cm all loop long. **Why:** the sitters floated above or sank into their stools because every offset in the data was 0 while the chair clips are authored on 0.18–0.24 m stools; a computed fit survives a new clip, a new stool or a rescaled hero.
- **A plinth under the store, because the crop has no bottom.** The store crop stops at the seated cast's heads, so the model is placed with its base 1.05 m up and a procedural counter (`store_base.glb`) fills the band. **Why:** the model's own aspect (1.72) cannot cover the reference's store box (1.10) at any camera distance; stretching 33–46 % would have been visible and a fresh 30-credit generation was not worth it.
- **One tricycle, two uses; the right-hand one is a retexture.** No clean tricycle crop exists (the left parked one is 74 % under the UI stickers, the right one is ~40×80 px), so the model came from a generated concept image (`meshy_api.py text-to-image`, 6 credits) and the second colourway is a 10-credit Meshy retexture. The background pass reuses this same model.
- **No soda logos.** The crate texture's light lettering is inpainted out at build time (`light_marks` in `tools/build_home_props.py`: mask = pixels brighter than a box blur of themselves, then fill from the neighbours). **Why:** the crate script is a *light tint of the panel colour*, so no whiteness or saturation threshold catches it without eating the panels and the plant.
- **Overhead cables stay procedural.** Meshy reads a thin cable as a flat strip, which is why the pole model needs `cut_radius` to remove its baked strips; the wires are the catenary `wire_span` prop. Logged in `docs/status.md` so a future pass does not "fix" it by generating more.
- **The palette remap is off.** The new textures already carry the reference's palette, so `remap` is false per set piece and `diorama_set.gdshader` only adds grain, grime, wrapped light and the filmic tonemap. **Why:** the v0.1.2 remap existed to rescue the old teal/orange store texture; keeping it over the new art would double-grade it.
- **Home's column is labelled in English** (PLAY, TRAINING, BACK TO TITLE) with the Filipino name on the smaller line, because the reference does. This deviates from the spec's LARO / ENSAYO / LUMABAS; the language setting still collapses it to one line, and it is logged in `docs/status.md`.
- **The jeepney pass became a tricycle pass**, and the data keys are `pass_*`. The synthesised engine and horn beds keep their `jeep_*.wav` names: renaming two audio files for a cosmetic reason is churn, and `docs/status.md` says why.
- **Few and long gestures.** Twelve gestures with 0.5 s fades, gaze rate 2.5 and a 30° yaw limit replaced the stack of short ones. **Why:** many short gestures in a row read as twitching, and the six new Meshy presets (`source_art/mocap/meshy/menu_extra.glb`) gave the seated cast calm variants — the action library has no hands-in-lap or leaning-forward seated idle at all, only the two `Chair_Sit_Idle` clips already in use.
- **A dev overlay instead of eyeballing.** `--home-ref` draws the reference at 50 % over the frame. **Why:** the camera and every prop position were solved numerically against the reference pixels (`renders/qc/fit_layout.py`, a scratch tool); without the overlay the last few centimetres are guesswork. The flag is opt-in, and `home` asserts the overlay is off without it.

## 2026-10-18: Home diorama (v0.1.2)
*(Superseded for Home's layout, props, camera, schedule and vehicle pass by the entry above; the picker, the seek-driven timeline and the audio still stand.)*
- **Picker, not a centre stage.** The breakdance hero left the Home screen for a default-character picker opened from the player card. **Why:** the diorama is the star of Home now; the picker keeps the breakdance and the choice without covering the scene. Deviation from spec § 6, logged in `docs/status.md`.
- **Seek-driven timeline.** `HomeDiorama` advances its `Timeline` by hand and derives bystanders and the jeepney from the loop time; `seek_to(t)` replays the schedule at 30 Hz. **Why:** QC stills match what a viewer sees at t seconds, and nothing accumulates drift, so the 48 s loop cannot pop.
- **Graded set shader, not retextured models.** Meshy's store texture is a baked teal/orange confetti, which read as blue and red plastic. `diorama_set.gdshader` hue-remaps it to dusty mint and terracotta, adds grain and grime, wraps the light and applies a filmic tonemap; the noisy outline pass was dropped. **Why:** fixes colour and "plastic" in one place for store, facades, boxes and ground without spending Meshy credits (465 of 500 used by the end of v0.1.2).
- **Depth blur and sky are shaders, not Environment settings.** Compatibility has no DoF, so `diorama_dof.gdshader` runs on a 2×2 quad parented to the camera (`POSITION = vec4(VERTEX.xy, 0, 1)`, depth test off, priority 127, reads the screen and depth textures). The sky is `diorama_sky.gdshader`, with `fog_sky_affect = 0` because fog otherwise washed it flat peach. **Why:** the user asked for a blurred background and a sky that reads as a sky; both loop seamlessly because they depend only on loop time.
- **Ground and façade textures are PIL-generated** (`tools/make_home_ground.py`) with mipmaps enabled in their `.import`, since shader-sampled textures alias without them. Façade fronts are QuadMeshes because BoxMesh UVs are an atlas per face.
- **Tighter, lower-camera composition** matched to the reference: UI keeps the left ~40 %, the cast sits right of centre, the jeepney and walkers use a side street so they never cross the actors.
- **Real tree assets.** Mango tree and coconut palm are Meshy text-to-3D (refined), decimated in Blender; the graffiti wall is a Meshy image. **Why:** the first blobs were placeholders and the user asked for proper trees.
- **Original synthesised audio.** `tools/make_home_audio.py` writes the music loop, UI ticks, chatter and jeep sounds with numpy only. **Why:** no sourcing or licence risk, loops are seamless by construction. Master volume now defaults to 50 (spec § 10).
- **Luckiest Guy (Apache 2.0) and PIL-drawn cardboard skins** for the sticker UI, bundled in the repo; `HomeSkin` falls back to flat boxes if a file is missing.

## 2026-10-17: Home diorama faces are painted cards, not a face rig
- The hero meshes have no blendshapes or face bones, so the Home diorama's talking and blinking are three alpha cards per head (`FaceRig`, `tools/build_face_cards.py`) parented to the head bone, flipping atlas frames from a seeded RNG. **Why:** no Meshy re-rig or blendshape bake needed; frames are a pure function of loop time, so the 48 s loop is seamless.
- **Alpha blend with a feathered skin-tint patch**, not alpha scissor: the closed/half lid and mouth frames paint a skin patch over the model's own eye/mouth, and a scissor edge would show as a hard outline. The shader pulls the cards toward the camera in clip space (`depth_bias`) instead of lifting them off the surface, so no gap shows at the 3/4 angle.
- **`rigid_head()` in `build_heroes.py`:** everything above the head joint is skinned to the Head bone alone. **Why:** JM had ~10 % Shoulder weight on his face, so a rigid card drifted off it when he sat; fixing the weights also stops his face smearing. Other heroes were already ~100 % Head, so the pass changes nothing for them.

## 2026-10-17: Home diorama bystanders and set pieces
- Bystanders keep Meshy's 24-bone rig instead of being retargeted to Mixamo names, and `build_bystanders.py` measures their loops itself. **Why:** they play one clip each, so a retarget buys nothing, and `qc_asset.py` misreads Meshy's 0.01-scaled rig.
- The manong was regenerated: the first model had the carried water gallon fused into his head in the raw Meshy source (not a decimation artefact). The new one carries nothing and the gallon is a procedural hand-held prop. Same for every other carried thing.
- Sign lettering is real text meshes rather than a texture, so it stays crisp at any distance and needs no image generation.
- The store comes from text-to-3D: the reference image from the brief is not on disk and its extras are ignored. *(2026-10-18: the reference is in the repo now; the store is Meshy image-to-3D from a crop of it.)*

## 2026-10-16: docs/RESBAK.md is the spec; the match runs on a host tick
- `docs/RESBAK.md` (the finalized concise spec) replaces `docs/design/RESBAK_GDD.md` as the single design source of truth. `docs/design/` is gone.
- **Match architecture:** one `MatchHost` runs the spec § 12 tick order at 60 ticks/s; players and bots both produce `InputFrame`s and gameplay never reads `Input`. **Why:** LAN play only has to send frames and draw snapshots, and tests can step exact ticks.
- **Numbers live in data:** `data/tuning.tres` (shared) and `data/heroes/<id>.tres` (per hero, skill values in `values`). **Why:** spec § 1 says starting values are named constants, never hard-coded.
- **Heroes' clips come from Meshy:** each hero GLB was auto-rigged by Meshy and given preset animations (plus two text-to-motion clips), then retargeted onto our rigs in `tools/build_heroes.py`. **Why:** Mixamo needed a sign-in we couldn't do; Meshy rigged the real heroes, so retargets are near-lossless. 147 credits, logged for Form 03 in `docs/pipelines/blender.md`.
- **Base resolution 1920×1080**, borderless fullscreen by default (spec § 10 default and § 12 target).
- **Gate is a suite runner:** `integration_test.gd` runs `scripts/tests/suites/*.gd`, counting failed checks instead of asserting, so a failure exits 1 instead of hanging.
- **Facing:** heroes face their movement while running and turn to the aim when standing, tagging or casting (spec says always face the cursor). Logged as a gap for a team decision.
- Hero bodies are kinematic under Jolt and only move in the physics server on a real physics step; tests that need hero-vs-hero blocking step with a physics frame between ticks.

## 2026-10-16: The GDD is the single design source of truth
- (Superseded the same day by `docs/RESBAK.md`.) `docs/design/RESBAK_GDD.md` became the only design doc: a condensed (~7k words) spec of the team's full GDD, written for agents (numbers, states, tick order, scope). The full GDD is a long PDF kept outside the repo, so it doesn't fill agent context. **Why:** the old design docs (summary, dossiers, rules spec) disagreed with each other and with the team's latest decisions (Unahan tag rule with own-base barrier, no sprint or stamina, Tutoy, rescue by touch, no flag).
- The superseded docs moved to `docs/archive/` unchanged. Don't implement from them.
- Removed the Meshy hero GLBs that had been copied into the repo root, with the textures and `.import` files Godot generated from them. The originals stay in `source_art/heroes/` (Godot-ignored). Put raw sources there, never in the root. `docs/` now has a `.gdignore`.
- The spec is regenerated from the full GDD whenever the GDD changes. Don't hand-edit `docs/design/`; ask for a GDD change instead, and note design and code gaps in `status.md`.

## 2026-10-16: Nathan's candy is "Kimkim", not Mik-Mik
- The docs renamed Nathan's powdered-milk candy from Mik-Mik to **Kimkim**. **Why:** Mik-Mik is a real trademark. Don't reintroduce the real name in docs, assets, textures, or code identifiers.

## 2026-10-15: Agent-friendly repo reorganization
- `scripts/` is split into `runtime/` (game code), `tests/` (gate + `legacy/`), and `map_pipeline/` (destructive one-shot builders). **Why:** the scene-overwriting batch scripts sat next to gameplay code with nothing marking them.
- Raw character sources moved from the repo root to `source_art/` (Godot-ignored). The `.blend` moved from `blender/`. The `tools/*.py` paths are now repo-relative.
- `AGENTS.md` was rewritten as a lean routing manual; `CLAUDE.md` imports it. Detailed facts now live in `docs/` (status, architecture, pipelines, glossary).
- The `legacy/verify_*.gd` scripts were found failing on the current map. They're kept for history and are not in the gate.
- Git LFS is enabled for `*.glb *.png *.jpg *.blend *.res`, with no history rewrite.

## 2026-10-14: Batang Hamog moveset
- Removed the `Slide` (baseball slide) and `Dash` (shoulder roll) clips. The gate asserts they're absent by exact name. Authored `Harurot`, `Lusot_Slide`, and `Lusot_Vault` in `tools/build_hamog_moveset.py`.
- Shift became Harurot, so the playtest has no sprint. Harurot recovery always plays Walking, never Running. **Why:** the hunched run pose read badly as a recovery.

## 2026-10-14: Design doc migration
- `AGAWAN BASE IDEA.md` was replaced by `docs/RESBAK.md`: the 3.8 MB embedded image was removed and the name no longer has spaces. Per-character numbers live in `docs/characters/`, and the dossiers win on numeric conflicts.

## 2026-10-17: v0.2 playtest changes (team requests)
- **New Nene and Inday skills** replace spec kits: SIGAW! (word projectile: stun enemy 0.5 s / dash teammate), BAWAL! (warning sign; a tag on her is cancelled and the tagger hallucinates), HILA! (stretched hand that pulls a teammate and rescues a chain tip it touches). **Why:** team playtest request; the old IYAK!/SUMBONG KITA!/SAGIP! read poorly. HILA! rescue reuses the JailSystem touch path through `Skill.rescue_touch_point()`, so it obeys the same step 6/7 order as a hand touch.
- **Jail line**: the jail is a map-authored line (`JailLine_<team>` Path3D) with a post that slides along it, instead of a fixed yard. The post holder and the tip both steer, so captured players can still play. **Why:** team request; lets each map shape its jail (straight, angled, snaking). Bot navmesh no longer carves the post (it moves).
- **Fixed bases**: one base per team (`BaseSite_<team>`); the roulette shows them without spinning. **Why:** team request; randomised sites made map learning harder.
- **Slower pace, charged hampas**: `move_speed_scale` 0.8, 0.3 s windup, hold to charge up to +60 % reach with a bar over the head. **Why:** team request; tags were too fast to read.
- **Announcer**: MOBA-style ribbons driven by host events in the HUD (presentation only, never game state). Calls are Filipino and go through `Audio.announce` so voice lines drop in later by file name (`announcer_<id>`).
- **Desktop only**: the project targets Windows desktop; no mobile or touch work.

## 2026-10-17: Konstruksyon overhaul and match polish
- **Own-ring barrier removed.** Teams may stand in their own base ring. **Why:** playtests showed defenders shoved off the pole and bots piling on the barrier (about 540 `barrier_bump` events per match). This deviates from spec § 2; logged in `docs/status.md` for the spec owner.
- **Aim arrow replaces the fan.** Its tip is the reach of a swing released now and it fills with the hampas charge, so the charge (optional, adds reach) is readable.
- **Round-1 intro** is a RoundFlow phase on the host tick (so a LAN host and clients agree on it); only the flyover camera and banners are presentation. `skip_intro` keeps tests and `--autoplay` fast.
- **Occlusion fade swaps alpha-blended duplicate materials** instead of setting `transparency`, because the GL Compatibility renderer ignores `GeometryInstance3D.transparency`. Instanced piles use their collider for bounds (headless MultiMesh AABBs are unreliable).
- **Sand castle on Konstruksyon only**, set through `Gameplay.base_prop` metadata; the court keeps its basketball stand. Collision and capture rules are unchanged.
- **TagCharge via Meshy text-to-motion**: no library clip fits a slap wind-up. Prep only until credits are approved.
- **Audio from CC0 sources**; the code API lands first and files drop in later (`Audio` ignores missing files).

## 2026-10-17: Chain hands, arrow legibility, CC0 files, map symmetry
- **Jail-chain hands resolve bones by name tail.** On import Godot renames Mixamo bones `mixamorig:Hips` → `mixamorig_Hips`, so `HeroVisual` looks each joint up by the tail after the last `:`/`_` (`_bone_by_tail()`), captures the arm chain's world pose on `Skeleton3D.skeleton_updated` into `_bones_world`, and drives one `TwoBoneIK3D` per arm at a hang point or at the chain's grip/tip point (`chain_relaxed_grip()`, `chain_grips()`). `jail_system` asks the visual for `chain_grips()` instead of doing joint math. **Why:** the hands lost the post after the first pull, so the grip and the "a rescuer is close" reach cue were unreadable; tune `HAND_HEIGHT 0.48`, `ELBOW_BEND 0.93`, `GRIP_BLEND 0.55`, `TIP_REACH_RANGE 6.0`.
- **The aim arrow is an ink outline under a bright core** (`ARROW_CORE_TINT 0.35`, `ARROW_FULL_ALPHA 0.85`, white pulse at full charge) instead of a flat team-coloured ribbon. **Why:** the old arrow read as scenery on both maps at 1920×1080.
- **20 CC0 audio files landed** (13 SFX + castle crumble + construction ambience + 4 music tracks) with sources and licences in `assets/audio/CREDITS.md` and `*.ogg` on Git LFS. The Freesound referee whistle for sudden death was skipped: it is CC0 but the download needs a signed-in account, and `sfx_sudden_death` reuses the thunder strike for now. `MUSIC_LAYER_DB = −3.0` keeps a stem under the base track and `MUSIC_LAYER_DUCK_DB = −6.0` ducks the base track while a stem plays. **Why:** an asset with no licence trail is not shippable, and a login is not worth one sound.
- **Konstruksyon mirror symmetry:** `MaterialPilesAndProps/GravelEarthPile` 8.0 → 9.0 m, `Gameplay/BaseSite_Lila` 17.5 → 17.0 m, `Gameplay/Spawn_Lila_1/2` 17.5 → 16.5 m, so both mid-field piles, both base sites and both spawn pairs mirror about the yard middle (x = −2.0) within 0.05 m; the `konstruksyon` suite now checks bases, piles and both spawn pairs that tightly. **Why:** the 1 m offset on one side read as a bug from the wide camera. The two `JailLine_*` paths stay deliberately different (each side shaped its own jail).
- **MultiMesh sub-resources set `instance_count = 0` before `transform_format = 1`** in `neighborhood_backdrop.tscn` (16 blocks) and `construction_site.tscn` (8). **Why:** `--import` logged 16 × `Instance count must be 0 to change the transform format` — the engine applies a scene's properties twice, and the second pass switched the format while instances existed. The runtime state was already correct; `transform_format` cannot be dropped because these buffers hold 12 floats per instance (3D), not the 2D stride-8 default.

## 2026-10-17: Audit follow-up (chain drawn shorter, tension music, arrow colour, SMPL retarget)
- **The jail chain is drawn shorter than it is.** Kid arms span about 1 m hand to hand, but `chain_link` stays 1.5 m (rescue reach and chain feel are tuned on it). `HeroVisual.chain_draw_position()` walks the real chain out from the post and cuts each step to what the two neighbours' arms can span (`half_span()` from the rest pose, × `GRIP_SLACK 0.92`); the visual node (model, ring, bars) eases to that spot (`PULL_RATE`). The pull lets go as a free ally closes from `TIP_REACH_RANGE` to `PULL_RELEASE_NEAR`, so the rescue touch lands where the tip really stands. Host positions, tagging and rescue never see it. Grips pick the neighbour's hand by grip (`grip_hand`), not by distance. **Why:** the hands only met in a bunched chain; the user chose this over shortening `chain_link` (option A).
- **Tension music at 30 s left, as a crossfade.** `RoundFlow` emits `final_stretch` when the round clock reaches `final_stretch_time` (30 s; spec § 7 "then faster music"); `match_scene` turns the `<track>_tension` stem on there (and at sudden death, for rounds shorter than the stretch) and off at the countdown. The stem fades in at 0 dB while the base fades to silent. **Why:** it fired only at sudden death, and the CC0 stems are different tunes, so a 6 dB duck played two songs at once.
- **Aim arrow fill is team-coloured** (`ARROW_CORE_TINT` 0.35 → 0.85); the ink outline and full-charge white pulse stay. **Why:** at 0.35 it read as pale cream for both teams.
- **SMPL-H clips retarget by bone-to-child direction** (`retarget_clip.py`). **Why:** Meshy Prime text-to-motion now ships SMPL-H, whose bones all rest pointing up; the old swing step folded the legs. See `docs/pipelines/blender.md` "TagCharge".

## 2026-10-17: Konstruksyon vehicles, distance focus
- **Mathew's Meshy vehicles are fitted into the old vehicles' footprints**, not placed at their own size. `tools/build_vehicle_props.py` turns each raw download to face +X, grounds it and scales it uniformly into the old box-built vehicle's local box (`FIT`); the scene keeps every vehicle node's name and transform, swaps its geometry for a `Model` instance and refits its one `StaticBody3D` box to the model (× 0.94 / 0.92 / 0.86, so mirrors and bumpers stay walk-round-able). **Why:** the lanes, routes, spawn checks and occlusion groups were tuned on those footprints; a same-size swap keeps every `konstruksyon` check meaningful.
- **Vehicle textures are downscaled to 1024 px** (Meshy ships 2048 px base colour, normal and roughness). **Why:** five trucks at 2048 px × 3 maps cost about 60 MB of VRAM for props that fill a few hundred pixels on screen.
- **Distance focus is radial world distance from the hero, not depth.** The ink pass reconstructs each pixel's world XZ and blurs by its distance from `focus_world` (the local hero, fed by `MatchCamera`). **Why:** Kurt asked for far things blurred and near things sharp; on the orthographic camera depth barely changes across the yard, so a depth-of-field blur was invisible.

## 2026-10-18: Fixed close gameplay framing
- Lock MatchCamera gameplay size at the former closest zoom (8). Remove user zoom and automatic speed/elevation widening while retaining positional and rotational dynamics and the scripted intro flyover. Why: requested consistent close framing without losing the camera style.

## 2026-10-18: Tap tags, fan and Sabay fall
- Replace charged hampas with one normal-reach swing per press for every input source, including bots. Keep the existing 0.3 s readable wind-up and 0.5 s miss/Sabay recovery. The first clean landing cancels a pending swing; only mutual valid landings on the same host tick are Sabay. Why: the user approved a mobile-friendly button-only interaction without stronger held attacks.
- Share aim/nearest-target queries with the fan preview rather than duplicating hit rules. Keep the committed fan direction fixed through wind-up; highlight only a visible eligible target within reach/arc and clear line of sight. Sabay uses a host-timed model roll and recovery, not a new physics/ragdoll state.
- Add touch match controls as an InputFrame producer, retaining mouse/controller input and camera-relative movement. This explicitly requested extension does not imply mobile exports or a complete front-end port. Touch input uses movement-facing aim with the last direction retained at rest; no second aiming stick is required.

## 2026-10-18: Fair aim assistance and restrained outlines
- Give touch a visible, bounded tag target lock so retreating no longer forces tag aim away from the pursuer. Acquire only inside the forward assist cone; permit explicit target switching by tapping. Drop invalid, blocked, protected or hidden targets. Carry tag-only direction separately in InputFrame so hero skills keep their directional controls. This compensates for mouse/right-stick independent aiming without auto-attacking or expanding reach.
- Show every visible committed wind-up as the actual moving fan. Keep exact-tick Sabay and existing impact/recovery timings until human playtests justify changing them: enlarging the tie window would cancel legitimate earlier hits, and blanket fall immunity would alter team counterplay. Hidden enemies must never be revealed by aim assistance or telegraphs.
- Tune character outline width to 1 px across match, Home and portraits, leaving the shared map/prop shader default alone. Why: requested subtler character edges that fit the environment; no character resizing or material/rig rebuild is needed.

## 2026-10-18: Private arc, moving actions and bot retry decisions
- Supersedes the visible opponent-fan decision above: only the local player sees a thin curved reach boundary, shown near opponents and during a swing. Enemy normal-attack ranges stay private; attack animations provide the tell. One swing still chooses the nearest eligible enemy at impact, even with two enemies inside the area.
- Replace full-body action/locomotion switching with a filtered upper-body layer for mobile casts, tagging and chain holding. Retain full-body source clips and the existing asset contract; use a pelvis-heading modifier before hand IK for sidesteps/backpedaling. A host-tick contact timeline and body-surface impact point prevent presentation timing from deciding tags. Model-only reach displacement is wall-clipped and bounded, with no host-motion or reach buff.
- HILA's returning palm and body recovery are cosmetic after gameplay expiration; do not extend rescue/grab eligibility for the duration of an animation. Reuse Sagip with runtime phase seeking rather than spending credits or rebuilding rigs for this functional pass.
- Bot-only seeded thinking delays and short post-Sabay repositions break repeated simultaneous retries. Shared 0.3 s wind-up, 0.5 s miss/fall recovery, range and exact-tick Sabay stay unchanged; never force a bot victory by mutating player attacks.

## 2026-10-18: Straight tagging and optional selection
User requested a filled straight guide, no character ground indicators, and optional hold-to-aim targeting. Quick taps fire on release so holds can preview without accidentally attacking. Holding never charges or changes reach/speed. Selection highlights an overhead nametag and commits one identity/direction; landing still validates body overlap and LOS. Movement can dodge without a universal dodge button. A crossing opponent cannot receive a selected attack. This supersedes the previous thin arc and TARGET ring; first landing and exact-tick Sabay remain authoritative.

## 2026-10-18: Local free training reuses real maps and host rules
ENSAYO now offers a local testing sandbox alongside the existing tutorial. Reusing the match scene on both available maps keeps tag/skill/movement testing representative. Three dummies (or normal bots) and a whole-scenario retry avoid maintaining a separate combat implementation or accumulating jailed targets. Resets are queued from UI and applied on the host tick; training never records competitive results. This is separate from the future multiplayer Kanto design.

## 2026-10-18: Plant tags instead of blending a moving reach
User reported glitching and requested a Brawl Stars-style aim/release flow. Tag now plays as a stationary full-body hit for the existing wind-up/follow-through interval; the prior cosmetic lunge and Tag arm IK are removed. A quick tap auto-selects nearest in-range, a held aim remains directional, and only aim/committed wind-up shows a faint red guide with a red outline. Other moving skills and chain overlays retain their animation layers. This supersedes the earlier moving-Tag presentation, without adding invulnerability or changing the single-target/Sabay rules.

## 2026-10-18: Make on-screen controls discoverable and testable
The user requested a visible mobile-style UI. Controls now default on for desktop as well as touch, with an optional desktop Gameplay toggle. The existing movement joystick and attack pad share the same InputFrame path as mouse-operated pads; captured UI mouse gestures never become duplicate world attacks. Skills use release-to-cast directional input while preserving their existing range/movement rules. Names and cooldowns live on the actual buttons, so duplicate keyboard skill cards are hidden. A MENU button uses the existing pause flow. This is a controls feature, not a mobile export or a change to host tick rules.

## 2026-10-18 — Kit-specific skill pads and committed landing tells
User requested dedicated character controls with visible landing/wall placement. Use read-only skill preview queries, sharing JM/Nathan landing calculations and JM wall segment geometry with actual casts, to prevent duplicate UI math drifting from gameplay. Keep pre-cast intent private and expose JM's committed landing/wall in the shared world for counterplay. Point-pad drag controls distance without charging power. Explicit Tutoy pad aim overrides initial movement-first direction while normal input and later steering retain their established behavior. Self buffs get an overhead cue, not an invented area of effect. Only skills that implement early stop advertise STOP.

## 2026-10-18 — Cancel with a separate release target
User reported rushed long aim drags could accidentally cancel. Remove radial cancellation for TAG and skills: clamp aim distance, keep direction, and cancel only when released inside the explicit × target. Moving across the target does not latch cancellation; leaving restores aim. Check the release location itself to tolerate coalesced pointer events. Preserve system-cancel/focus/pause cleanup. Dark control backplates and colored rims improve contrast against both maps without increasing the control footprint.
## 2026-10-18: Barangay court reference environment

- Keep a separate perspective ReferenceCamera for the supplied wide composition; the existing match camera and input scripts continue to own gameplay views.
- Let the map own sunlight/environment through the existing MapDressing environment check.
- Remove the non-reference center volleyball net and its collision only after explicit user approval. Preserve other gameplay interfaces and collision resources; relocate clutter with its colliders.
- Keep new murals and the vendor cart's trimmed/recolored mesh local to this scene. Reuse Meshy assets and leave their shared source resources intact.

## 2026-10-19: Court mural and street consistency

- Fit each mural to its surface; mirror continuous horizontal repeats because the artwork does not tile at its edges. Preserve motif aspect ratio and persist per-mesh shader bounds.
- Give side roads, planting and sidewalks separate space. Retain the original utility poles and cables by fitting the road around their verge; avoid broad architecture trimming.
- Replace road-overlapping neighborhood furniture with individual Meshy instances on sidewalks. Keep shared source scenes unchanged; store relocated clutter with its colliders on rear service aprons.

## 2026-10-19: Merge Mathew's Barangay Court, drop the duplicated baggage

- Took his court scene wholesale and re-inserted our `Gameplay/TrainingSpawn` marker (the training menu needs it).
- Did not take `ConstructionSite.tscn`, `assets/vehicles/`, `scenes/vehicles/` (Konstruksyon already ships the same Meshy vehicles under `assets/props/vehicles/`), `harbor_player` (stray prototype) or the `godot_mcp_toolkit` addon with its `MCPRuntimeServer` autoload (editor-only tooling must not run in the game). A `project` suite check now fails if any autoload points into `addons/`.
- Kept our `.import` files for the hero GLBs and court textures to avoid UID and compression churn.


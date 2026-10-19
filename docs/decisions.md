# Decision log

## 2026-10-19 — No skill aim assist, stick-driven TAMARAW, shorter skills, arm-length tags

The user asked for a fairer, more physical game: skill aim is the player's own, TAMARAW follows facing/movement, ranges shrink, and tag reach should be arm-length.

Skill aim assist is removed entirely; only the tag attack keeps its small gamepad assist. Every skill uses exactly the direction or point the player gave (the preview and the release frame are identical).

TAMARAW!!! no longer takes an aim direction and shows no direction indicator. Its control now matches Tutoy's HARUROT!: hold the skill button to open the cancel target, drag to CANCEL to drop it, release to charge; keep holding nothing extra, and press again mid-charge to stop. It charges where the movement stick points, or where JM faces when the stick is centred, and keeps steering toward the stick at its 90 deg/s limit; a mouse aim point never turns it. No arrow, lane or committed tell is drawn — it just moves — and S2 again still cancels the charge mid-run.

Ranges were shortened for fairness: HILA! 9 to 5 m, UBO! UBO! 9 to 6.5 m with the cloud radius 3.5 to 2.5 m, SIGAW! 12 to 7 m. Tag reach is now arm-length: 1.0 m edge to edge for four heroes and 0.9 m for Tutoy (was 1.2 / 1.0), so a tag needs the bodies within about 1.8 m instead of 2 m.

A HILA! that touches nothing retracts on its own: the hand carries a hard flight-time timeout (so no geometry case can leave it hanging), the missed reach closes on the tick after it opens, and the arm returns in 0.15 s.

A stumbling hero (failed tag or Sabay) freezes on the direction of the swing that missed: `Hero.stumble` captures `fall_facing`, `_update_facing` holds it for the whole stumble, and the model turns to it, so aiming away mid-fall no longer spins the body.

These override the spec's tag reach and skill ranges; RESBAK.md stays untouched and the deviations are logged in status.

## 2026-10-19 — Soft aim assist, no aim text, smaller SIGAW fan

The user replaced the earlier lock-on assistance with a soft assist, and asked for a quieter, fairer presentation.

Skill assist now works like the tag assist: if a visible, unobstructed enemy sits within 25° of the aim and inside the skill's own reach, the aim turns toward it by 60 % of that angle, never more than 10°. Nothing is selected or marked, nothing homes after the cast, the caller's frame is untouched, and mouse/keyboard aim is never altered. Only skills that aim at a hero are assisted (offensive skills toward enemies, HILA! toward teammates); IHIP!, HARUROT!, LUSOT! and BAWAL! keep the player's exact direction or spot.

All in-world skill text and target highlights were removed: no selected-enemy ring or gold outline, no skill-name or range labels on previews or committed tells. The shape and its colour carry the state (skill colour, red for cancel, amber for blocked, cyan for max range), in the comic ink style used by the rest of the game.

SIGAW! is now a fixed 7 m by 60° fan (was 12 m): one third of the previous area, a static fan outline with a fast front sweeping inside it, each hero affected once. This supersedes the 12 m fan approved earlier the same day and is logged in status; RESBAK.md stays untouched.

## 2026-10-19 — Skill commitment, aim assistance and committed tells

The user approved all five recommendations of the skill-readability round in one go, then confirmed Nene's wave rules separately.

1. BUGA! plants Nathan for the full 0.75 s inhale/spit and commits the aim direction at the cast. Facing, powder and hit cone stay aligned with that direction even if the player turns the stick mid-spit. Character cadence stays 24 poses/s.
2. SIGAW! is an expanding 60-degree sound fan that travels outward at her current 18 m/s to the 12 m range, instead of a straight word that stops at the first hero. Every hero the front reaches is affected once: enemies are stunned 0.5 s, teammates dash 3 m. Walls block the rays they cross, so a wall never kills the unobstructed side of the fan.
3. Offensive skills assist. An enemy that is visible, unobstructed and inside the displayed aim shape is selected (closest to the player's aiming direction wins), the preview highlights it, and the cast commits that direction or landing point. Enemies can still dodge after the cast. Aiming at empty ground stays exact. Assistance applies to quick casts and dragged aim alike.
4. HILA! assists toward valid allies and rescue-chain tips. BAWAL! stays self-targeted; slides, speed boosts and wind placement keep the player's intended movement or placement.
5. Aiming previews are private. A committed cast publishes a tell shaped like the real hit area, without the private target highlight, and every outline is drawn as a dark ink under-stroke plus the skill's bright stroke over a restrained fill.

These supersede RESBAK.md § 4 wording that SIGAW stops at the first hero it touches and that Nathan may move while inhaling. The spec file itself stays untouched; the deviation is logged in status.

## 2026-10-19 — Motion, secondary dynamics and cast readability

User confirmed the design in two grilling rounds. Keep 24 character poses/s and the 60 Hz host. Phase-synchronize walk/run around measured stride speeds with bounded playback correction. Inday uses grounded Quick_Walk and Lean_Forward_Sprint. Strikes coil backward before contact; miss recovery starts from contact and blends out.

Approved gameplay changes: tag wind-up 0.30 to 0.25 s, retaining planted commitment/reach; UBO prepares for 0.30 s and cancels if caught before release, after which projectile/cloud persist normally; IHIP plants the caster for one second while its effective area grows with the visible front, consuming the first second of its five-second lifetime; BAWAL casts while moving with pink rim/sign/orbit cues. These override the frozen spec and are logged in status; RESBAK.md stays untouched.

Secondary motion uses bounded presentation solvers. JM holds a loosely rolled towel with actual finger weights. Inday's braid belongs to Head, independently of her elastic arm. Explicit reviewed masks preserve UV seams and exclude clothing; a canonical pre-repair Inday library preserves vertex indices. Both maps share the illustrated finish/ink, with court sunshine/cool fill and construction amber/dust.

## 2026-10-18 — Five-hero animation and skill presentation redesign
User approved one continuous implementation with review/playtest at the end. TALBOG replaces the wall with the existing landing push plus a 2 s enemy stun. TAMARAW keeps its sideways shove and crash penalty, adding a 30% contact slow for 0.5 s, once per target per charge. The supplied Meshy Tamaraw becomes a 4,800-triangle animated golden projection around JM, rather than a separate animal. JM's towel tag preserves the normal hit rules and host timing.

Nathan's own cloud grants vision of its interior only while he is inside; other inside viewers lose sight of heroes, and outside viewers cannot see inside. Walls and hostile overlapping clouds still block his advantage. The initial UBO burst blinds enemies for 2 s, without refreshing on entry/re-entry; BUGA keeps its existing slow/tracking mechanics. These are explicit departures from the frozen spec, as are proportional analog movement and HILA's immediate return on a miss. The design spec is unchanged.

Inday uses her actual skinned arm with authored Blender anticipation/recovery and a runtime target-driven stretch. Keep one endpoint tick for the host's rescue resolution, preventing a maximum-range rescue from being lost when misses return. Nene uses comic shout/ward motifs, Tutoy wind/friction strokes, and all heroes share status feedback that obeys visibility.

Short, dated, newest first. Add an entry when you make a choice that a future reader
would otherwise reverse by accident.

## 2026-10-18: Home diorama (v0.1.2)
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
- The store comes from text-to-3D: the reference image from the brief is not on disk and its extras are ignored.

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

## 2026-10-18 — Share atmosphere systems, retain court identity
User requested construction-site shaders, lighting and ambience on the basketball court with suitable adaptation. Use the same illustrated screen shader, authored directional sun/environment model and CPU dust system. Put court tuning in its authored Environment/light and Gameplay/presentation metadata; do not replace painted basketball surfaces with sand/water shaders or play harbor machinery in the barangay. Cooler fill, softer amber light and lighter airborne particles keep the court's markings readable. Retain the existing dynamic focus and reduce-motion behavior.

## 2026-10-18 — Summer wear through map-local materials
After the grilling session, user approved clean bright summer light, coordinated individual object colors, subtle breeze, and authentic worn barangay surfaces without a style change. Keep existing textures and illustrated shaders, adding restrained procedural wear at plausible surface scales rather than replacing them with photographs or applying a yellow LUT. Localize material/MultiMesh references before setting court-only uniforms; preserve shared props on Konstruksyon. Filter fine noise at distance, preserve white gameplay markings, and disable decorative motion with Reduce motion.
## 2026-10-19 — cast recovery, prepared Hampas and fixed wind

The user confirmed fixed wind tuning (12 × 4.5 m, 5 s, +40% teammate speed, 25% owner/enemy slow, 24 s cooldown) and disadvantage only for reciprocal same-tick tag ties. Existing Unahan timing and equal-disadvantage Sabay remain. This is an explicit deviation from the immutable design spec and is tracked in status.md.

Use host timers for cast/recovery plants, InputFrame state for held preparation, and upper-skeleton filters for moving preparation/coughing. Visual animation requests alone cannot enforce movement rules. Smoke appearance fades without delaying authoritative concealment. Keep supplied JM/towel/KimKim geometry and textures; normalize naming, skin weights and exports inside Blender. Stage exports away from the active Godot importer before replacing runtime assets.

## 2026-10-19 — JM shoulder towel and stepped character cadence

The user approved 24 character poses per second while retaining responsive 60 Hz gameplay and smooth camera/UI. Use accumulated manual AnimationTree advancement, including Home heroes, instead of capping game FPS. Cloth retains smooth secondary response. JM's newly supplied shoulder rig replaces the simplified generic-joint adaptation while retaining his identity and existing full clip contract. The new towel source contributes its material to clean cloth topology. No-contact Tamaraw expiry/manual cancellation uses the existing half-second recovery for a dizzy animation; it adds no stun, protection, or punishment to successful contacts. Tamaraw is click-on-press with click-to-stop. These approved changes are documented as spec deviations in status; the spec itself is unchanged.


## 2026-10-19 — Reference tag, overhead throw and towel snap

The user approved the two supplied five-pose references: a planted lead-foot reach with an upright open palm for normal tags, and an above/behind-shoulder coil, overhead release and cross-body follow-through for Nathan and JM. Keep JM gripping the towel throughout. Allow the tag hit timing to breathe: wind-up is now 0.35 s (21 host ticks), with unchanged 0.18 s follow-through and 0.5 s miss penalty. Nathan still picks up the packet before the coil and releases on the authoritative 0.3 s boundary. These timings supersede the previous 0.25 s presentation revision, remain approved spec deviations, and retain 24 character pose samples/s. Stumble starts from the new contact pose. Exported-pose tests check upright fingers, raised coils and contact continuity.

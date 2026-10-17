# Home diorama: implementation brief (v0.1.2)

> After approval, the only thing this session does is copy this brief to
> `docs/plans/2026-10-17-home-diorama.md`, to hand to the implementing agent. This session
> implements nothing, commits nothing and pushes nothing.

## Context

Today the Home screen (`scenes/frontend/home.tscn` plus `scripts/ui/frontend/home.gd`) is a dark
chalk-line backdrop. It has a breakdancing hero in a `HeroPreview` at the centre, `<`/`>` arrows,
the hero's name, role and a hint, and a plain `StyleBoxFlat` player card at the top left.

The user generated a target image. In it, the five heroes hang around a **sari-sari store at
golden hour**, talking and drinking. A jeepney passes on the road behind them, bystanders walk
by, and the UI is a hand-made street-sticker and cardboard style.

The aim is a **real-time 3D diorama that loops seamlessly** behind a restyled Home UI:
- The heroes visibly talk: their mouths and eyes move.
- A jeepney goes by once per loop.
- Bystanders walk past.
- The breakdance hero leaves Home and moves into a new **default-character picker**, which opens
  when the player clicks the player card.

The image generator added a centre breakdancer, arrows and "JM" name text that aren't wanted.
**Ignore them.** Use the image only as the reference for layout, palette and UI style. The 3D
keeps the in-game toon look.

**The user can't review code.** They will playtest the finished build. So:
- Run every phase in sequence, with no check-ins. The only stop is the Meshy credit cap (§ 9).
- Quality bar: everything must be **seamless and fluid, never scuffed**. That means no visible
  loop pop, no props clipping through hands, no feet sliding, no T-pose frames, and no
  z-fighting.

Read first: `AGENTS.md`, `CLAUDE.md`, `docs/RESBAK.md` § 6 (Home), § 10 (Settings / audio
defaults) and § 12 (autoloads), `docs/architecture.md`, `docs/pipelines/blender.md` and
`docs/pipelines/assets.md`.

---

## 1. Existing code and assets to reuse

| What | Where | Use |
|---|---|---|
| Base screen class | `scripts/ui/frontend/front_screen.gd` | `draws_backdrop()` → return `false` on Home (no ChalkBackdrop); `build()`, `btn()`, `go()`, `ask()`, `dialog` |
| Theme, palette, helpers | `scripts/ui/frontend/fe.gd` | `FE.panel/box_style/button/set_greyed/shout/label/pair`, palette `INK/INK2/CHALK/GOLD/DILAW/LILA/OUTLINE`, `VERSION` (line 34) |
| Live 3D in a menu (pattern to copy) | `scripts/ui/frontend/title.gd:69-89` `_build_live_court()` | SubViewportContainer (stretch, full rect, mouse ignore) → SubViewport (`own_world_3d`, MSAA 2X); skip when `DisplayServer.get_name() == "headless"` |
| Menu environment precedent | `scripts/runtime/character_select.gd` (~line 112) | WorldEnvironment setup in a SubViewport |
| Sun and environment builder | `scripts/match/map_dressing.gd` `add_lighting()` | Copy its approach for the golden-hour rig (don't change the match lighting) |
| Breakdance preview | `scripts/ui/frontend/hero_preview.gd` (`HeroPreview`, `show_hero(id, clip)`) | Moves into the picker overlay. `draft.gd:190` also uses it, so keep the class |
| Portraits | `scripts/ui/face_badge.gd`, `scripts/ui/portraits.gd` | Card portrait and picker stickers |
| Fonts | `scripts/ui/ui_fonts.gd` | Add `home_display()` for Luckiest Guy; keep `display()` (Bahnschrift) and `body()` (Segoe UI) |
| Audio | `scripts/autoload/audio.gd` | `play(name, text, at, bus)`, `play_music(name, fade)`, `stop_music()`, `set_music_layer()`, `apply_volumes()`; buses Music / Effects / Voices / Announcer |
| Save defaults | `scripts/autoload/save.gd:25` | Master default 80 → 50 (fresh saves only) |
| Hero GLBs | `assets/characters/{tutoy,nene,nathan,jm,inday}.glb` | Mixamo rig (`mixamorig:*`); no face rig, mouths sculpted closed |
| Hero build | `tools/build_heroes.py` (`BREAKDANCE` dict lines 153-159, `CROSSFADE=8`, loop 428-434), `tools/retarget_clip.py` (`loop_blend` 404-417) | Add `Menu_*` clips and Nathan's new breakdance |
| Fallback mocap (CC0) | `source_art/mocap/quaternius/UAL1_Standard.glb` | `Sitting_Idle_Loop`, `Sitting_Talking_Loop`, `Idle_Talking_Loop`, `Walk_Loop` |
| Breakdance pack | `mixamo/breakdance-pack/` (35 moves) | Nathan's replacement move |
| Props | `assets/props/vehicles/jeepney` (6.32×2.47×2.81 m), `street_tricycle`, `blue_plastic_chair`, `neighborhood/{park_bench,palamig_cart,shade_tree,plants}` | Set dressing |
| Shaders | `shaders/character_toon*`, `painted_*`, `wall_graffiti`, `reference_asphalt`, `sidewalk_surface`, outline | Reuse; new: `face_flipbook.gdshader` |
| Asset tools | `tools/sanitize_asset.py` (Meshy props), `tools/qc_asset.py` (→ `renders/qc/<name>_sheet.png` and `.json`) | Every new model and clip |
| Ambience | `assets/audio/ambience/barangay_daylight.wav` (CC0) | Home ambience bed |
| Gate | `scripts/tests/integration_test.gd`, suites in `scripts/tests/suites/` (`frontend.gd`, `hero_assets.gd`) | Add a `home` suite |

---

## 2. Scene architecture

**New files:**
- `scenes/frontend/home_diorama.tscn`, the 3D set, authored as a scene (not code-built), so
  staging can be tuned in the editor.
- `scripts/ui/frontend/home_diorama.gd` drives it:
  - Root `Node3D`, with `WorldEnvironment`, a `DirectionalLight3D` sun, fill and practical lights,
    `Camera3D`, `Set`, `Heroes`, `Bystanders`, `Vehicles` and `FX` children.
  - **`Timeline`**, an `AnimationPlayer`. One animation, `loop`, 48.0 s long, with
    `loop_mode = LOOP_LINEAR`. It drives:
    - the conversation turn markers (method tracks → `turn_started(hero_id, line_id)`);
    - the jeepney path offset;
    - the bystander path offsets;
    - one-shot hero beats (gesture-layer requests);
    - audio cues.
  - Each hero has its own `AnimationTree` (§ 5). The timeline only *requests* gestures through a
    method track, so every crossfade is owned by the tree and never cut hard.
- `data/home_diorama.tres` holds every tuning number:
  - per-hero seat position, rotation and offsets, and grip offsets for held props;
  - gesture schedule times, crossfade length (0.4 s), look-at limits and blink interval range;
  - mouth flipbook rate;
  - jeepney start time and speed;
  - bystander speeds and stagger;
  - camera transform and fov;
  - light colours and energies, fog;
  - audio levels and fades.
  - Script: `scripts/ui/frontend/home_diorama_data.gd` (`class_name HomeDioramaData extends
    Resource`). **No literals in code.**

**Home integration** (`home.gd`):
- `draws_backdrop()` returns `false`.
- In `build()`, when not headless, add a full-rect `SubViewportContainer` (stretch, mouse
  ignore) as the **first** child of `content`:
  - a SubViewport with `own_world_3d` and MSAA 2X;
  - then instance `home_diorama.tscn`.
- Copy `title.gd:69-89`.
- When headless, still instance the diorama scene, without the viewport container, so the tests
  can inspect it. Skip `_process` work in that case.
- Add a soft vignette `TextureRect` or `ColorRect` gradient over the left 40 % so the nav stays
  readable. The heroes must remain uncovered.

**Determinism and seamless loop:**
- Everything is driven from `Timeline.current_animation_position`. There are no free-running
  `randf()` timers, except blinks, which use a seeded RNG reset at t = 0 so each loop repeats.
- Every hero is in its base pose at both t = 0 and t = 48:
  - No gesture overlaps the wrap.
  - Base loops are authored so 48 s is an integer number of cycles. Otherwise, the tree's base
    `AnimationNodeAnimation` is reset at the loop point under a 0.4 s blend that lands inside a
    "quiet" window with no gesture and no speech.
- The jeepney and bystanders are off-screen at the wrap.

---

## 3. Set, camera, lighting and shaders

**Layout** (match the image's framing; the camera is static):
- Foreground and middle:
  - The sari-sari store: storefront facing the camera, slightly angled.
  - A wooden bench against the storefront wall.
  - A blue monobloc chair facing the bench.
  - A plastic bottle crate used as a side table.
  - Stools.
  - The palamig cart to one side.
  - A parked tricycle.
- Background:
  - A two-lane road crossing the frame behind the store corner, with sidewalk and curb.
  - Facades across the road, with an umbrella vendor stall.
  - Power poles with sagging wires.
  - A shade tree and plants.
  - A painted graffiti wall section.
- Sky with distant haze.
- **Heroes sit centre-right.** The left nav column (x 80–640 px) and the top-right tiles must
  never cover a hero or a hero's face.
- Signs: **"SARI-SARI STORE"** (main sign board) and **"Tindahan ni Aling Charing"** (smaller
  painted sign). Both are textures on sign meshes, since GL Compatibility has no Decal node.

**Camera:**
- `Camera3D` with fov and transform from data. Set it by matching the target image composition
  (eye height about 1.4–1.6 m, looking slightly down).
- Static. A barely-perceptible breathing sway (≤ 0.02 m, period 48 s / n, so it stays seamless)
  is allowed but optional.

**Lighting: golden hour, about 4:30 pm:**
- Sun:
  - `DirectionalLight3D`, warm (about `#FFC27A`), low elevation (about 18–22°).
  - Coming from screen-right and behind, for long shadows toward camera-left and a rim on the
    heroes.
  - Shadows on, PSSM 2 splits, tuned for the small set: max distance about 40 m, bias tuned so
    there's no acne on the toon shader.
- Fill:
  - `WorldEnvironment` ambient from a cool sky colour (about `#8FB4D9`), energy low.
  - Tonemap filmic or ACES as the match uses (check `map_dressing.gd`), glow on lightly.
- Practical: a warm `OmniLight3D` bulb inside the store window (about `#FFB15A`, small range, no
  shadow), plus an emissive bulb mesh.
- Atmosphere:
  - Depth fog / haze tinted warm-peach at distance, so the background facades fall off.
  - Dust motes: a `GPUParticles3D`, or `CPUParticles3D` if GL Compat needs it. Sparse and slow, in
    the sunbeam volume near the store. It loops on its own; it doesn't need to sync to the
    timeline.
  - Optional: gentle leaf sway on the shade tree via the existing shader.
- Use the colour references in the target image for the sky gradient and shadow tint.

**Shaders:**
- Heroes and bystanders: `character_toon` (and outline), same as in-game.
- Set: `painted_*` surfaces for walls and wood; `wall_graffiti` for the graffiti wall;
  `reference_asphalt` for the road; `sidewalk_surface` for the sidewalk.
- New `shaders/face_flipbook.gdshader` (§ 4).
- No new post-processing beyond the environment settings above.

**Performance budget:** 60 fps at 1920×1080 with shadows on, on this machine, with the UI on top.
- Keep set props under about 150 k triangles total.
- Bake nothing that needs Forward+.
- If it misses 60 fps:
  - reduce the shadow splits or distance first;
  - then the particle count;
  - then the diorama SubViewport's `scaling_3d_scale` (not below 0.85).

---

## 4. Faces: talking and blinking (procedural face cards)

The hero meshes have no face rig, and their mouths are sculpted and painted shut. So add **face
cards**: small alpha-tested quads parented to the head.

- **`tools/build_face_cards.py`** (Blender headless, repo-relative paths) generates, per hero:
  1. **A mouth flipbook atlas** of 6 shapes in a 3×2 grid: closed, small-open, wide-open, O,
     smile, laugh.
     - Drawn procedurally as shapes, in the toon style: dark interior, tongue or teeth hint, thick
       outline matching the outline shader.
     - Lip and skin tint are **sampled from that hero's existing texture** around the painted
       mouth, so the card blends into the face.
  2. **Eyelid cards**: skin-tinted lids with a lash line, open / half / closed frames, to drive
     blinks.
  3. Output: `assets/characters/face_cards/<id>_mouth.png`, `<id>_lids.png` (LFS).
  4. A JSON of per-hero placement (offset, rotation and scale relative to `mixamorig:Head`),
     found by ray-casting from the front of the head toward the painted mouth and eye positions.
     Written into `data/home_diorama.tres`, or a sidecar the data resource loads.
- **`shaders/face_flipbook.gdshader`**:
  - unshaded-ish toon, with `frame` uniform plus `atlas_cols/rows`;
  - alpha scissor;
  - a slight depth offset toward the camera so the card never z-fights the face;
  - lit the same way as `character_toon` so it doesn't glow.
- **Runtime**, in `home_diorama.gd` or a small `FaceRig` script node per hero:
  - `BoneAttachment3D` on `mixamorig:Head` → mouth quad and two lid quads.
  - When that hero is speaking (the turn markers from the timeline), cycle mouth frames with a
    seeded pattern. Use the open shapes at the flipbook rate from data, with occasional O and
    smile shapes, then return to closed at the end of the turn.
  - Laugh beats use smile and laugh shapes.
  - Blinks every 2.5–5 s (data), 0.12 s long, from a seeded RNG reset at t = 0.
  - Listeners blink and occasionally smile.
  - Speech gibberish audio (§ 7) is triggered from the same turn events, so mouth and voice stay
    in sync.
- **QC**:
  - Render each hero's head close-up (front and 3/4) with each mouth frame from the diorama
    camera.
  - Save to `renders/home_diorama/faces/`.
  - Check that there is no visible card edge, no floating, and no z-fighting.

---

## 5. Hero animation (Meshy animate, then Blender, then layered in Godot)

### 5.1 Clips to generate

Use `meshy_animate` on the **5 existing SUCCEEDED rigging tasks** (find them with
`meshy_list_tasks` `task_types:["rigging"]`).

Before spending credits:
- Check each action's preview GIF in `meshy_list_animations` (free).
- Drop any whose sitting pose fights the bench height, or whose hands leave the body in a way that
  breaks the held prop.

Library action IDs:

| Hero / seat | Base loop (full body) | Gestures (upper body) |
|---|---|---|
| **Nene**, bench left. Legs swing; palamig in a plastic bag with a straw | `Chair_Sit_Idle_F` (32) | `Sit_Finger_Wag_No` (355), `Sitting_Clap` (354), `Sit_and_Drink` (343, sips the palamig) |
| **JM**, bench centre. Glass soda bottle | `Chair_Sit_Idle_M` (33) | `Sit_and_Drink` (343), `Sit_Hands_on_Head_Lean_Back` (356, the "laugh"), `Sitting_Clap` (354) |
| **Nathan**, bench right. The schemer | `Chair_Sit_Idle_M` (33) | `Scheming_Hand_Rub` (318), `Sitting_Answering_Questions` (307), `Sit_Thumbs_Up_Right` (357), `Sitting_Clap` (354) |
| **Inday**, monobloc, facing the bench. Tells the story | `Chair_Sit_Idle_F` (32) | `Talk_with_Hands_Open` (313), `Talk_with_Left_Hand_on_Hip` (309), `Talk_with_Right_Hand_Open` (314) |
| **Tutoy**, standing, restless | Standing idle: `Idle` from his GLB, or Quaternius `Idle_Talking_Loop` retargeted | `Talk_Passionately` (308), `Hand_on_Hip_Gesture` (315), **full-body** `Handstand_Flip` (375), `Cheer_with_Both_Hands_Up` (298) |

- That's about 4 actions per hero, 20–22 actions × 3 credits ≈ 66 credits.
- Fallback if a Meshy action is unusable: Quaternius `Sitting_Idle_Loop` / `Sitting_Talking_Loop`
  retargeted with `retarget_clip.py`.
- The Meshy library has no laugh clip. JM's laugh is `Sit_Hands_on_Head_Lean_Back` plus laugh
  mouth frames plus a chatter "haha" pitch pattern.

### 5.2 Blender pass

Extend `tools/build_heroes.py`, or add `tools/build_menu_clips.py` called by it, so the clips are
reproducible.

- Retarget each Meshy clip onto the hero GLB rig with `retarget_clip.py`. Keep the
  `mixamorig:*` names.
- **Trim** each clip to a stable stretch of **≥ 2 s** where the seated pelvis doesn't drift.
- **Lock the pelvis and legs** in seated clips (except Nene's leg swing) so the gesture layer
  never moves the hips.
- **Loop** base clips with `loop_blend` (CROSSFADE frames). Target seam **≤ 0.005 m** on QC.
- **Name** clips `Menu_<Action>`, for example `Menu_SitIdle`, `Menu_SitDrink`, `Menu_LeanBackLaugh`,
  `Menu_FingerWag`, `Menu_Clap`, `Menu_HandRub`, `Menu_Answer`, `Menu_ThumbsUp`,
  `Menu_TalkHandsOpen`, `Menu_TalkHip`, `Menu_TalkRightOpen`, `Menu_StandIdle`,
  `Menu_TalkPassionate`, `Menu_HandOnHip`, `Menu_HandstandFlip`, `Menu_Cheer`.
  - Never exactly `Slide` or `Dash`.
- Export as NLA tracks in the hero GLB. Every clip animates the full skeleton with **≥ 60 tracks**.
- Gesture clips start and end near the base pose (trim to those frames) so the 0.4 s blend
  hides the join.
- The full-body `Menu_HandstandFlip` must start and end in Tutoy's standing idle pose, with root
  motion removed and a net displacement of 0, so he lands where he started.
- Run `tools/qc_asset.py` on every hero after rebuild and **look at each sheet**. Fix any WARN
  on loop seam, foot slide or track count.

### 5.3 Godot layering (per hero `AnimationTree`)

- `AnimationNodeBlendTree`:
  - `Base` (`AnimationNodeAnimation`, looping base clip).
  - → `Gesture` `AnimationNodeOneShot` (fade-in/out **0.4 s**, from data) with a **bone filter**
    covering spine, spine1, spine2, neck, head, both shoulders, arms, forearms and hands.
    Add hips and legs only for full-body clips via a second OneShot with no filter.
  - → `Output`.
- A one-shot gesture is requested by the timeline method track:
  `request_gesture(hero_id, clip, full_body := false)`.
  - It sets the `Gesture` node's animation and fires it.
  - No gesture may be requested while one is active; the schedule in data guarantees this, and the
    gate checks it.
- **`LookAtModifier3D`** on `mixamorig:Head`, limited to about ±45° yaw and ±20° pitch, with
  smooth interpolation. The target is the current speaker's head (from turn markers). The
  speaker looks at the listener they address.
  - It turns off while a full-body clip plays.
- **Held props** via `BoneAttachment3D` on `mixamorig:RightHand` or `LeftHand`, with grip offsets
  from data:
  - Nene: palamig bag with straw.
  - JM: glass soda bottle.
  - Optionally Nathan: a chichirya snack pack.
  - During `Sit_and_Drink` the prop follows the hand. Verify the bottle actually reaches the lips
    with diorama-camera stills, and nudge the grip offset until it does.
- **Seat contact:** pelvis on the bench and feet on the ground. Verify with diorama-camera stills
  at t = 0, 12, 24, 36 and 47.9, saved to `renders/home_diorama/stills/`.

### 5.4 Conversation script: the 48 s loop

Times are from data. Tune them so the flow is natural.

| t (s) | Beat |
|---|---|
| 0–2 | Quiet window. Everyone in base pose; ambient blinks |
| 2–11 | **Inday** tells a story: `TalkHandsOpen` → `TalkHip`. Bench looks at her |
| 11–15 | **Nathan** chimes in: `HandRub` → `Answer`. Heads turn to Nathan |
| 15–19 | **JM** laughs: `LeanBackLaugh`, laugh mouth frames |
| 19–25 | **Jeepney passes** behind (§ 6). A couple of heads glance toward the road. JM `SitDrink` |
| 25–30 | **Nene** wags her finger "no" at Nathan: `FingerWag`. Inday `TalkRightOpen` |
| 30–34 | **Tutoy**: `TalkPassionate` ("watch this") |
| 34–39 | **Tutoy** `HandstandFlip` (full body) |
| 39–43 | Bench applauds: Nene, JM and Nathan `Clap`. Nathan `ThumbsUp`. Tutoy `Cheer` |
| 43–46 | Inday resumes talking softly. Nene sips the palamig |
| 46–48 | Quiet window. Everyone back in base pose for the wrap |

Bystanders and ambient blinks continue throughout.

---

## 6. Jeepney and bystanders

**Jeepney:**
- The existing `assets/props/vehicles/jeepney`.
- A `Path3D` / `PathFollow3D` along the background road, driven by the timeline.
- One pass per loop starting about t = 20 s, **right to left**, visible on screen for about
  4–5 s, at a constant speed with a slight ease-in and ease-out at the path ends, which are
  off-screen.
- Wheels spin from the distance travelled, if the wheel nodes are separate; otherwise skip.
- A slight body bob from a sine of the distance travelled.
- Off-screen and hidden at the loop wrap.

**Bystanders** (4, generated with Meshy text-to-3D, § 9):
1. **Tindera**, inside the store window behind the counter, fanning herself. Loops in place;
   occasionally leans on the counter.
2. **Lola** with a payong (umbrella), walks slowly left to right along the sidewalk across the
   road.
3. **Manong** carrying a water gallon on his shoulder, crosses at mid-depth, right to left.
4. **Student** in uniform with a backpack, walks along the near sidewalk edge, left to right,
   passing *behind* the heroes and never through them.

Pipeline for each:
- Meshy `text_to_3d` (`meshy-6`), then `refine`, then `rig` (gives walking and running), then
  `animate` for extra actions:
  - tindera: a fanning or idle-at-counter action;
  - lola, manong and student: their walk variants; the manong uses a carry walk if the library
    has one, otherwise a walk with the arm posed in Blender.
- Then `sanitize_asset.py` cleanup, a Mixamo-name check/rename if needed, `character_toon`
  materials and `qc_asset.py`.
- Output: `assets/characters/bystanders/<name>.glb`.
- Walk paths are `Path3D`s driven by the timeline:
  - Speeds are set so feet don't slide (match the walk clip's stride; check in stills).
  - Starts are staggered so there are never more than 2 on screen at once and none collide with
    the jeepney pass.
  - Each path either is fully off-screen at the wrap, or completes an integer number of passes
    per 48 s.
- Held props (payong, gallon, backpack) are part of the generation, or simple Blender props
  attached with `BoneAttachment3D`.

---

## 7. Audio

All sources are **CC0**. List every file with its source URL in `assets/audio/CREDITS.md`.
Output goes to `assets/audio/home/`.

| Sound | Bus | Notes |
|---|---|---|
| Ambience bed | Effects | Reuse or extend `assets/audio/ambience/barangay_daylight.wav`; seamless loop, distant traffic, birds, a far-off tricycle |
| Jeepney fly-by | Effects | `AudioStreamPlayer3D` on the jeepney, so pan and doppler follow its on-screen position. One soft "beep-beep" mid-pass |
| Gibberish chatter | Voices | Short syllable grains with per-hero pitch (data), triggered by turn markers, synced to mouth frames. JM laugh grains. Quiet |
| UI hover and click | Effects | Soft paper or cardboard tap for hover, a slightly firmer one for press; on all Home buttons and the picker |
| Menu music | Music | Light acoustic or OPM-ish loop; `Audio.play_music(...)` with a fade-in |
| Turn-start hook | — | Emit a `turn_started(hero_id, line_id)` signal so voiced lines can replace the gibberish later |

**Volume comfort.** The user's rule: "the default level for global sound should not irritate or
surprise the user."
- In `save.gd:25`, change the default **Master** to **50**, for **fresh saves only**. Existing
  `settings.cfg` values are untouched. This is a spec deviation (§ 10 says 80): log it in
  `docs/status.md`.
- Every Home sound **fades in over 2 s** when Home opens. No stingers or sudden hits.
- Loudness targets:
  - music about −23 LUFS integrated;
  - ambience about 6 dB under the music;
  - chatter quieter than the ambience peaks;
  - jeepney horn peak at or below the music level.
- Normalize the files to these targets, and set relative levels in data.
- Leaving Home (to Play, Settings or Title) fades the Home music and ambience out over 0.5 s.
  - Settings opened from Home may keep the music playing.
  - Make sure returning to Home doesn't restart or stack it: `play_music` with the same name is a
    no-op.

---

## 8. Home UI restyle

Applies to **Home only**; other screens stay as they are.

**Font:**
- Bundle **Luckiest Guy** (Google Fonts, Apache-2.0) as `assets/fonts/LuckiestGuy-Regular.ttf`,
  with `assets/fonts/LICENSE-LuckiestGuy.txt`.
- Add `UiFonts.home_display()`.
- Use it for display text on Home and the picker. Keep Bahnschrift and Segoe for small text.

**UI skins (Meshy text-to-image, `nano-banana-2`, 6 credits each, about 11 images):**
- Prompt for flat, front-on, high-contrast skins on a plain background, matching the target
  image's sticker and cardboard style.
- Clean each one in Python (PIL) or Blender: key out the background, trim, and add a 1 px safe
  margin.
- Save as transparent PNGs in `assets/ui/home/` (LFS).
- Use them as `StyleBoxTexture` (9-slice margins set in code from data) or `NinePatchRect`.

Skins:
1. PLAY yellow paint-splat banner
2. Tutorial dark chalk strip
3. Masking-tape piece
4. Cardboard plank (2 variants)
5. Graffiti scribble overlay
6. Hanging cardboard sign (Settings)
7. Black torn-paper sticker
8. Player-card dark sticker panel with white die-cut edge
9. Paint-splat accents (2)
10. Swap badge
11. Cardboard-box pad (the picker floor)

Mapping:
- **LARO / Play:**
  - A big yellow paint-splat banner, Luckiest Guy dark text, a slight tilt (about −2°).
  - Keep button name `Laro`, size about 560×150, preselected focus.
- **ENSAYO / Tutorial:** a dark chalk strip with tape at the corners; subtitle "Tutorial: Turo ni
  Kuya Tanod".
- **BARKADA / LOCKER / GAWAIN** (greyed) and **LUMABAS:**
  - Taped cardboard planks with a graffiti scribble, alternating small tilts.
  - Greyed buttons keep `FE.set_greyed`'s orange "Malapit na" tag, restyled as a small sticker.
- **Settings** (top right, about (1580,56)): a hanging cardboard sign on a string, with a gentle
  idle sway.
- **Tansan / Balita / Profile** (right column, greyed): black torn-paper stickers.
- Hover and focus on all of them:
  - Scale 1.04, tilt toward 0°, tween 0.12 s, plus the hover SFX.
  - Press: squash 0.96, plus the click SFX.
  - Controller and keyboard focus show the same state. Keep the focus order.

**Player card (top left)** is the button that opens the picker:
- A dark sticker panel with a white die-cut edge and paint-splat accents.
- `FaceBadge` portrait in a round sticker frame.
- **Display name in gold Luckiest Guy** with a dark outline.
- Stats (Laro / Panalo / MVP) below in the new style.
- A small **"palitan"** (swap) badge on the portrait corner.
- The **whole card** is clickable and focusable:
  - a hover wiggle (±1.5°, 0.3 s);
  - press opens the picker;
  - reachable by controller (focus neighbour of `Laro` upward).
- Keep the node names `PlayerCard`, `PlayerFace`, `PlayerName`, `Stats` and the hidden
  `PlayerStats` label, because tests and tools read them.

**Removed from Home:**
- `_build_bench()` and everything in it: pad, `BenchPreview`, `BenchName`, role label, hint,
  `BenchPrev` / `BenchNext`.
- Page Up / Down cycling in `_unhandled_input`.
- Keep `bench_id` and `profile.home_hero` (they drive the card face, the tutorial hero and the
  picker default).
- `start_tutorial()` still uses `bench_id`.
- Spec § 6 says Home has "bench hero (saved, JM first launch, pick from 5)". The pick now lives in
  the picker overlay. Log this deviation in `docs/status.md`.

**Default-character picker overlay** (new `scripts/ui/frontend/hero_picker.gd`, a `Control`
added to Home's content):
- A full-screen dim (about 55 % ink) over the diorama, which keeps animating behind it.
- Centre: a large `HeroPreview` (reuse the class) playing **`BreakDance`**, standing on the
  **flattened cardboard-box pad** skin, with a soft contact shadow.
- Hero name in Luckiest Guy, nickname in quotes, role / secondary role (reuse the text format from
  the old `_refresh_bench`).
- A row of **5 portrait stickers** (FaceBadge in the sticker frame). The current one is
  highlighted with a gold die-cut ring.
  - Left / right, a click or a pad selects it and the preview switches.
- Buttons:
  - **Piliin** (choose): saves `profile.home_hero` via the existing `set_bench` logic, updates the
    card face, closes the overlay with the hover/click SFX.
  - **Bumalik** (back), Esc or ui_cancel: closes without saving.
- Opening and closing tweens are a 0.2 s scale-pop plus fade.
- Focus goes into the picker while it's open and returns to the player card after it closes.
- `FrontScreen.on_back()` must close the picker first if it's open, not go to the title.

**Nathan's breakdance loop fix:**
- QC reports a loop-seam WARN of 0.026 m (`renders/qc/nathan_qc.json`).
- In `tools/build_heroes.py` `BREAKDANCE["nathan"]`, replace `breakdance 1990 + crossleg freeze`
  with **one** move from `mixamo/breakdance-pack/` that loops on its own. Try them in order:
  1. `breakdance swipes`
  2. `footwork 1`
  3. `breakdance 1990` alone
- Keep the first one that reaches a loop seam ≤ **0.005 m** on `qc_asset.py`, then look at the
  sheet.
- Fix the stale rows in `docs/pipelines/blender.md` (lines about 50 and 96, which say
  "footwork 1"), so they state what actually ships.

**Version:** `scripts/ui/frontend/fe.gd:34` becomes `const VERSION := "0.1.2 (Demo build)"`.

---

## 9. Meshy work and budget

- **Cap: 500 credits**, pre-approved by the user for this plan. The balance is 943; estimated use
  is about 450.
  - Models: `meshy-6` for 3D, `nano-banana-2` for images.
  - Run `meshy_check_balance` at the start and end.
  - **Stop and ask the user** before any call that would push the total past 500.
- **Rule 2:** never re-create a task after a timeout or 5xx without first checking
  `meshy_list_tasks` for it. A wait timeout means you poll the same `task_id` again.
- Formats: `glb` for everything 3D.

| Item | Route | Est. credits |
|---|---|---|
| Sari-sari store (roof, grille, counter, sachet strips, candy jars, sign board) | `image_to_3d` from a crop of the target image, + texture | 30 |
| Store retry headroom | | 30 |
| Facades across the road (2 variants) | `text_to_3d` + refine | 60 |
| Umbrella vendor stall | `text_to_3d` + refine | 30 |
| Glass soda bottle, palamig bag with straw, snack pack | `text_to_3d` + refine (or Blender procedural if simpler) | 0–90 |
| 4 bystanders | `text_to_3d` + refine + rig | 4 × 35 = 140 |
| Bystander extra actions (fan, carry walk, etc.) | `animate` | about 15 |
| Hero menu actions | `animate`, about 22 × 3 | about 66 |
| UI skins | `text_to_image` nano-banana-2, about 11 × 6 | about 66 |

**Blender procedural** (no credits; extend or add `tools/build_home_props.py`):
- wooden bench;
- stools;
- bottle crate;
- power poles with sagging catenary wires;
- sign boards: "SARI-SARI STORE" and "Tindahan ni Aling Charing" as painted textures on boards;
- simple sidewalk and curb pieces if needed.

**Existing assets:** palamig cart, monobloc chair, tricycle, jeepney, shade tree, plants,
graffiti wall shader, road and sidewalk shaders.

**All Meshy props:**
- `sanitize_asset.py` (scale to real metres, origin at the base, single mesh where possible);
- swap to project shaders (`painted_*` / toon);
- `qc_asset.py`, and look at the sheet;
- output to `assets/props/home/<name>/` (glb plus a `.tscn` wrapper, like the existing props), via
  LFS.

**Log** every task ID, type, model and credits charged in the report (§ 12).

---

## 10. Tests: the new `home` gate suite

Add `scripts/tests/suites/home.gd`, register it in `integration_test.gd`, and document it in
`scripts/tests/README.md`. The checks:

1. **Scene:** `home_diorama.tscn` loads and instances headless. It has `Timeline` with an
   animation `loop` of length 48.0 (±0.001) and `LOOP_LINEAR`, a camera, a sun and a
   WorldEnvironment.
2. **Data:** `data/home_diorama.tres` loads as `HomeDioramaData`, with an entry for every
   `HeroData.ORDER` id.
3. **Clips:** every `Menu_*` clip referenced in data exists in its hero GLB with ≥ 60 tracks. No
   clip is named exactly `Slide` or `Dash`.
4. **Seamless loop:**
   - For each hero, sample the skeleton pose with the tree evaluated at t = 0 and at t = 48 (or
     seek and process); the bone positions must match within 0.005 m and rotations within 1°.
   - No gesture window in data overlaps the [46, 48] ∪ [0, 2] quiet windows.
   - No two gestures for the same hero overlap.
5. **Jeepney and bystanders:** at t = 0 and t = 48 the jeepney is off-screen or hidden, and every
   bystander path is off-screen or at the same transform.
6. **Faces:** each hero has a mouth and lid card attached to `mixamorig:Head`, with the
   `face_flipbook` material and atlas textures loaded.
7. **Home UI:**
   - Home builds.
   - `BenchPreview`, `BenchPrev` and `BenchNext` don't exist.
   - `PlayerCard` is focusable or clickable.
   - Pressing it opens `HeroPicker`. Selecting a hero and pressing Piliin updates
     `profile.home_hero` (use a temporary save) and the card face. Back closes without saving.
     `on_back()` with the picker open closes the picker.
8. **Version:** `FE.VERSION == "0.1.2 (Demo build)"`.
9. **Audio defaults:** a fresh `Save` default Master is 50; the other defaults are unchanged.
10. Update `hero_assets.gd`:
    - expect the `Menu_*` clips;
    - Nathan's `BreakDance` still exists with ≥ 60 tracks.

Also update `frontend.gd` if it references removed nodes.

---

## 11. Docs to update in the same change

- `docs/status.md`:
  - the Home row (diorama, picker, restyle);
  - the deviations: the picker moved off Home centre (spec § 6), and Master default 50 (spec § 10);
  - any Meshy fallbacks used.
- `docs/architecture.md`: the Home diorama (SubViewport, Timeline, per-hero AnimationTree layering,
  face cards, data resource) and the picker.
- `docs/pipelines/blender.md`:
  - the clip table: the `Menu_*` clips and Nathan's new BreakDance; fix the stale "footwork 1"
    rows;
  - the `build_face_cards.py` and `build_home_props.py` tools.
- `docs/pipelines/assets.md`: Meshy props for Home, `assets/ui/home/`, `assets/fonts/`.
- `docs/decisions.md`, with dated (2026-10-17) entries:
  - face cards rather than a face rig;
  - Meshy animate plus the layered AnimationTree;
  - the picker overlay;
  - the Master default of 50;
  - bundling Luckiest Guy.
- `docs/glossary.md`: "sari-sari store", "tindera", "palamig", "payong", "palitan", "Piliin",
  "Bumalik" if missing.
- `AGENTS.md`:
  - the layout: `assets/ui/`, `assets/fonts/`, `assets/characters/bystanders/`, `face_cards/`,
    `assets/props/home/`;
  - the new tools in Commands, if they're user-run.
- `assets/audio/CREDITS.md`: every new sound.
- `tools/README.md`: the new tools.

---

## 12. Verification and delivery

1. Run `& $env:GODOT --headless --path . --import` after adding the `class_name` scripts and
   assets.
2. **Gate:** `& $env:GODOT --headless --path . -s scripts/tests/integration_test.gd`, in the
   background or with a long timeout.
   - Pass means exit code 0, the last line `All checks passed successfully (100%)!`, and no
     `SCRIPT ERROR`.
   - Iterate with `-- --only=home,hero_assets,frontend`, then run the full gate.
3. **QC sheets** for every new or changed model and clip: `tools/qc_asset.py`, then look at each
   sheet. No WARNs on loop seam, track count or scale.
4. **Stills** from the diorama camera at t = 0, 12, 24, 36 and 47.9 (`renders/home_diorama/stills/`)
   plus the face close-ups (`renders/home_diorama/faces/`). Inspect them for prop contact, seat
   contact, clipping and UI overlap with the heroes.
5. **Loop capture:** a 48 s 1080p capture with
   `& $env:GODOT --path . --write-movie renders/home_diorama/loop.avi --fixed-fps 60 ...`
   (start straight on Home, or with a small dev flag that opens Home), saved to
   `renders/home_diorama/`.
   - Watch the 47–49 s wrap specifically for pops.
   - Keep the capture out of git (renders/ is Godot-ignored; add it to .gitignore or LFS
     according to the existing renders policy).
6. **Performance:** run windowed at 1920×1080 with shadows on and confirm a steady 60 fps on Home
   (`Engine.get_frames_per_second()` logged for 10 s).
7. **Manual pass:**
   - Open the game → Title → Home. Music and ambience fade in and nothing is loud.
   - Hover and click every button, open the picker, choose another hero, check the card portrait
     changes and persists after a restart.
   - Laro and Ensayo still work.
   - Esc behaviour works in the picker and on Home.
8. **Report** (in the final message and at the end of this plan's file under "Report"):
   - the gate's exit code and final line;
   - QC results;
   - the Meshy task IDs and credits, with the balance before and after;
   - any fallbacks;
   - known issues;
   - paths to the stills and the capture, for the user's playtest review.

**Git: version and branch.** The user asked for this: "Set this as v0.1.2 and ALSO THE ORIGIN
rename it from project thread something to version 0.1.2", and "Push to that branch."
- Local `foundation` mirrors `origin/claude/project-thread-vrst5q` (commit 19ca036, 0/0).
  - Remote: `https://github.com/kurt-wis/resbak`.
- Before renaming:
  - Check for open PRs from that branch:
    `gh pr list --repo kurt-wis/resbak --head claude/project-thread-vrst5q`.
    If any exist, note that the rename retargets them; that's fine, since GitHub handles it.
  - Make sure the remote branch hasn't moved since 19ca036 (`git fetch`, compare).
- Rename on GitHub, which keeps PRs and adds a redirect:
  `gh api -X POST repos/kurt-wis/resbak/branches/claude/project-thread-vrst5q/rename -f new_name=v0.1.2`,
  then `git fetch --prune`.
- Commit on `foundation`:
  - Don't commit `.opencode/`, `__pycache__/`, `gate_*.txt` or a stray `dev/` folder.
  - Binaries go through LFS.
  - End the message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **After the gate passes**, push with `git push origin foundation:v0.1.2` and set the upstream.
- **No PR.**
- If the gate fails, don't push. Report it instead.

---

## Execution order (sequential, no check-ins)

1. Read the docs listed under Context. Check the Meshy balance and find the rigging tasks.
2. Nathan's breakdance fix, then QC.
3. Hero `Menu_*` clips: preview GIFs, `meshy_animate`, Blender trim/loop/export, QC.
4. Face cards: `build_face_cards.py`, shader, QC close-ups.
5. Set: Meshy store, facades, stall and small props; Blender procedural props; sanitize; QC.
6. Bystanders: Meshy, then rig, animate, sanitize, QC.
7. `home_diorama.tscn`, data resource, lighting, timeline, AnimationTrees, look-at, held props.
   Then stills and iteration until the contact is clean.
8. Audio: sourcing, normalising, wiring; Master default.
9. UI: font, Meshy skins and cleanup, Home restyle, player card, picker overlay, removals, version.
10. Tests: the `home` suite plus updates, then the gate.
11. Capture, performance check and manual pass.
12. Docs, then commit, branch rename and push. Then the report.


## Final report (2026-10-18)

**Gate:** `integration_test.gd`, exit code 0, last line `All checks passed successfully (100%)!` (15 suites, 1421 checks, 0 failed, 0 SCRIPT ERROR lines). Home screen holds ~140 fps average at 1080p on the RTX 4050 laptop (worst frame 57 ms at startup).

**Latest fixes (user feedback):** the diorama now has a depth-of-field blur (`shaders/diorama_dof.gdshader`, a post quad on the camera, since the Compatibility renderer has no DoF) and a real sky (`shaders/diorama_sky.gdshader`: blue gradient, low-sun glow, drifting clouds; `fog_sky_affect = 0`). Earlier: tree assets from Meshy, tighter low-camera composition, graded store colours (`diorama_set.gdshader` hue-remaps Meshy's baked saturated teal/orange to dusty mint and terracotta with grain, grime, wrapped light and a filmic tonemap), Inday clear of the buttons, a skyline backdrop with generated textures, and a Meshy 3D graffiti wall.

**Meshy:** 465 of 500 credits. Task ids: 366 earlier; tree previews `01a14aab-e516-74e6-90f9-19ebcc0eb49e`, `01a14aab-ed46-75e4-90b0-45989363e5b1`; tree refines `01a14aaf-3667-72fb-befb-349e53b54a32` (mango), `01a14aaf-3757-724a-992e-42d5f7b772bd` (palm); first graffiti image `01a14aaf-dc5c-763b-a819-00fdaeff39dd` (discarded); graffiti image `01a14ace-306d-72ab-b46e-6d2aa1df4b60`; graffiti wall image-to-3D `01a14ad0-6e2d-7384-901f-eb179031557d`.

**Fallbacks and deviations:** `Menu_HandRub` dropped; tindera uses Wave One Hand plus a paper fan; Nathan `Answer` runs long, Nene `SitDrink` at 12.2 s, JM's second `SitDrink` and Tutoy's `TalkPassionate` cut, Nene smiles instead of sipping at 43-46 s; alpha-blend face cards; JM rigid-head fix; `qc_asset` misreads Meshy rigs (checked with `build_bystanders.py` output instead); manong regenerated; sign letters are meshes; store from text-to-3D; jeepney and walkers on a side street, with the jeepney slowed to 3.6 m/s so it is visible about 4 s at the right edge (the store, wall and heroes cover the rest of the frame); synthesised audio; PIL cardboard skins and ground/façade textures.

**Stills:** `renders/home_diorama/` and the scratchpad `q0`-`q6` sets. No known issues beyond the above.

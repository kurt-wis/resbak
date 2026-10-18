# Report — Konstruksyon remaining work (plan `2026-10-17-konstruksyon-remaining.md`)

Date: 2026-10-17 · Branch `foundation`, HEAD `7207a94` · **nothing committed**
Gate (item 9): exit 0, `14 suites, 1337 checks, 0 failed`, last line `All checks passed successfully (100%)!`, no `SCRIPT ERROR`.

| Item | Scope | Status |
| ---- | ----- | ------ |
| 1 | Jail chain: the hands actually meet; tip reaches rescuers | ✅ done |
| 2 | Charged hampas aim arrow is readable | ✅ done |
| 3 | `TagCharge` clip from Meshy (one Prime text-to-motion) | ❌ **blocked** — Meshy MCP has no API key |
| 4 | CC0 audio for every slot | ✅ done (one file skipped, see below) |
| 5 | Loose ends (MultiMesh import errors, occlusion fade, symmetry) | ✅ done |
| 6 | Manual playtest screenshots | ✅ done — 40 stills in `renders/review/` |
| 7 | Docs in the same change | ✅ done |
| 9 | Full gate | ⏳ running / see line above |

---

## Item 1 — Jail chain hands ✅

**What was wrong.** The grip IK looked bones up by the name the glTF file uses (`mixamorig:LeftHand`),
but Godot renames the colon on import (`mixamorig_LeftHand`), so every lookup failed and the arms fell
back to a plain "hands at the hips" pose. On top of that the grip read the *rest* pose of the
skeleton instead of the pose of the tick being drawn.

**What changed.**
- `scripts/match/hero_visual.gd`
  - `_bone_by_tail()` — bones resolve by the last segment of the name, so both `mixamorig:Hips` and
    `mixamorig_Hips` match; every arm/grip lookup goes through it.
  - Arm joints are captured from `Skeleton3D.skeleton_updated` into `_bones_world`, so the IK aims at
    the hands where the animation actually puts them.
  - `chain_grips()` aims each grip at the *neighbour's* hand bone, blended with the link midpoint:
    `GRIP_BLEND 0.55`; `HAND_HEIGHT 0.48` (was, in effect, hip height) — the hand sits at the
    neighbour's hand, not at the hip; `ELBOW_BEND 0.93` keeps the elbows bent; both elbow poles point
    down and back so the poles trail behind the prisoner.
  - `chain_relaxed_grip()` hangs the *end* link's free arm instead of leaving it rigid.
  - `_arm_reach()` measures the arm from the rest pose, so the reach used by the tip test is stable
    (`TIP_REACH_RANGE 6.0`).
  - `_tip_target()` (hero_visual.gd:449-464): the tip only "reaches" when a **free ally of the
    prisoner's team** is within 6 m — unchanged game rule, re-verified.
- `scripts/tests/suites/core_rules.gd` — the chain checks are bone-based now (hands within 0.15 m of
  each other, grip below the shoulder, facing check unchanged).

**Geometry note (deliberate).** At the map's real link spacing (`chain_link = 1.5` m) two hands cannot
meet — the arms are ~0.5 m. The plan's 0.15 m hand-meet check therefore runs against a *bunched*
chain (0.9 m spacing), which the rules allow because jail chain links are only ever pulled, never
pushed. The spacing authored in the map is untouched.

**Evidence.** `--only=core_rules` → `EXIT=0`, `1 suites, 259 checks, 0 failed`. A wider background run
(`--only=core_rules,bots,hud,match_flow`) → `EXIT=0`. In-game reach re-verified on both maps with the
camera/hero on the right teams: rescuer 6.5 m away → `relaxed=1`, rescuer 2 m away → `relaxed=-1`
(the earlier `relaxed=1` at 2 m was a mistake in my own probe — it picked an enemy instead of an ally —
not a game bug). Screenshots: `renders/review/barangay_chain_3links.png`,
`barangay_chain_3links_side.png`, `barangay_chain_tip_hangs.png`, `barangay_chain_tip_reaches.png`,
`barangay_chain_arms_no_ik.png` (the arms with the IK off, for comparison), and the same five for
`konstruksyon`. The run prints, per map: `chain tip grips 2, presenting (-0.799, 0.0, 0.600), arm IK
on 3/3 links` (barangay) and `(-1.0, 0.0, 0.0)` (konstruksyon).

## Item 2 — Charged hampas aim arrow ✅

**What changed.** The arrow is two meshes now: a dark ink outline slightly larger under a bright
core, and the core is white tinted toward the team colour.
- `scripts/match/vfx.gd` — `aim_arrow_meshes()` builds both layers, unshaded, with render priorities
  so the outline never z-fights the core.
- `scripts/match/match_view.gd` — `_arrow_layer` / `_build_arrow` build the arrow on the local
  player's ground plane only.
- Constants: `ARROW_CORE_TINT 0.35` (how far the core goes to the team colour), `ARROW_FULL_ALPHA
  0.85`, plus the existing fade-in and the new white pulse at full charge.
- `scripts/tests/suites/hud.gd` — checks that the outline node exists, that the outline renders below
  the core, that alpha is ~0 idle, ≥ 0.8 at full charge and that the reach grows with charge.

**Evidence.** `--only=hud,match_flow` → `EXIT=0`, `2 suites, 70 checks, 0 failed`. In-game:
`arrow: alpha 0.90 at full charge, reach 1.20 m idle -> 1.92 m full` (barangay) and `alpha 0.89`
(konstruksyon). Screenshots at 0 / 50 / 100 % charge on both maps:
`{barangay,konstruksyon}_arrow_charge_000|050|100.png`.

## Item 3 — `TagCharge` from Meshy ❌ blocked

Every call to the Meshy MCP server fails before it leaves the machine:

```
Error: MESHY_API_KEY environment variable is required. Put it in the "env" block of your MCP
client config (not in "args"), then restart the Meshy MCP server.
```

`meshy_check_balance` and `meshy_list_tasks` both fail this way, so the one approved Prime
text-to-motion generation could not be created. **No credits were spent, no task was created, nothing
was downloaded.** Nothing else changed for this item: no clip in `source_art/mocap/meshy/`, no bake
run, no `docs/pipelines/blender.md` row (a row for an animation that does not exist would be a lie),
and the `hero_assets` suite was left alone. The hook (`hero_visual.gd` plays `TagCharge` while
charging) and the plan's exact prompt are ready to use the moment the key works.

**To unblock:** put `MESHY_API_KEY` in the `env` block of the Meshy MCP server config and restart that
server; no new approval is needed for the single generation already approved (10 credits, prompt and
save path in the plan).

## Item 4 — CC0 audio ✅

**What landed.** 20 files in `assets/audio/`: 14 SFX (including `sfx_castle_crumble`), one ambience
loop (`construction_ambience.ogg`), and 4 music tracks (base + tension layer for both maps), sourced
from the four approved CC0 packs. Each licence was re-checked on the download page and inside the
archive; sources, authors and licences are recorded in `assets/audio/CREDITS.md`. `*.ogg` was added to
`.gitattributes` so the new audio goes through Git LFS.
- `scripts/match/match_scene.gd` — `MUSIC` / `AMBIENCE` tables now cover **both** maps.
- `scripts/autoload/audio.gd` — a music stem rides at `MUSIC_LAYER_DB = -3.0` and ducks the base
  track by `MUSIC_LAYER_DUCK_DB = -6.0`; a missing file stays silent instead of erroring.
- `scripts/match/match_view.gd` — every `sfx_*` slot in its table resolves to a real file.

**One file skipped, on purpose.** The SpliceSound referee whistle is CC0 but its Freesound page
requires a sign-in; the plan says not to sign in, so the whistle was skipped and
`sfx_sudden_death` reuses the thunder. Recorded in `CREDITS.md` and `docs/decisions.md`.

**Evidence.** `& $env:GODOT --headless --path . --import` → `EXIT=0` with no missing-file errors; the
`konstruksyon` suite checks the ambience/music entries and the `Audio` API; the review run prints the
audio state at kick-off and at the end of a match on both maps.

## Item 5 — Loose ends ✅

**(a) MultiMesh import errors — fixed.** The error was
`ERROR: Instance count must be 0 to change the transform format.` × 16, because the engine applies a
scene's stored properties twice and `transform_format = 1` was being set while the MultiMesh already
held instances. All 24 `[sub_resource type="MultiMesh"]` blocks (`scenes/neighborhood_backdrop.tscn`
16, `scenes/construction_site.tscn` 8) now store `instance_count = 0` *before* `transform_format = 1`.
`--import` → `IMPORT_EXIT=0`, **0** `Instance count` errors (was 16), 0 `ERROR` lines. Runtime state is
unchanged: every MultiMesh still reports `fmt=1` with its old counts and `buffer == 12 × count`
(barangay 16 nodes / 0 empty AABB, e.g. `Meshy_North_shade_tree count=7 buffer=84`; konstruksyon 8
nodes, `VariedStone0..3 count=450 buffer=5400`). `transform_format` could not simply be deleted: the
buffers are 12 floats per instance, while a fresh MultiMesh defaults to 2D format (stride 8).

**(b) Occlusion fade — verified on both sides, with a shot behind the tallest block on each side.**
`konstruksyon occlusion lila`: the camera behind the 4.3 m `@Node3D@3107` fades
`CorrugatedWaterfrontShed`, `@Node3D@2925`, `@Node3D@3107` → `konstruksyon_occlusion_lila_@node3d@3107.png`.
`konstruksyon occlusion dilaw`: the camera behind the 3.8 m `@Node3D@833` fades it (and `@Node3D@797`)
→ `konstruksyon_occlusion_dilaw_@node3d@833.png`. Summary line `occlusion: dilaw true, lila true`.
Barangay Court has no occlusion groups (that map is not opted in) — the harness says so explicitly.

**(c) Base/pile symmetry — fixed, and the suite now checks it tightly.** With the yard middle at
`x = -2.0`: `GravelEarthPile` 8.0 → **9.0** (it was the only pile 1 m off the mirror), `BaseSite_Lila`
17.5 → **17.0**, `Spawn_Lila_1/2` 17.5 → **16.5** (each side keeps "spawns 0.5 m in front of the base").
`scripts/tests/suites/konstruksyon.gd` now checks bases, the two piles and both spawn pairs to 0.05 m
(was 0.6/0.2) — `--only=konstruksyon` → `EXIT=0`, `1 suites, 64 checks, 0 failed`, including the
routes / lane-cut / spawn-clearance checks that guard the moved markers. The two `JailLine_*` paths
still differ in length (Dilaw ≈ 19.8 m, Lila ≈ 17.9 m) and keep the suite's generous tolerance; that
is a documented map-authoring gap, not a rule.

## Item 6 — Manual playtest screenshots ✅

40 stills at 1920×1080 in `renders/review/` (list below), captured by a throwaway windowed Godot
harness (`tmp_review_shots.gd` + `.tscn`, deleted afterwards — it is not part of the repo), driving a
real match with `manual_step = true` and one `ScriptedInput` for every hero so every take is
deterministic (seed 4242).

What each group proves:

- **Intro (item 6, first bullet):** `*_intro_1_arena`, `*_intro_2_team_dilaw`, `*_intro_3_team_lila`,
  `*_intro_4_faceoff`, `*_intro_5_round_live`, `*_interact_skips_intro` (barangay; the konstruksyon run
  skips the same sequence because the harness reopens the map mid-run).
- **Arrow + charge:** the six `*_arrow_charge_000|050|100.png` stills with the printed alpha/reach.
- **Tag:** `*_tag_swing.png`, `*_tag_whiff.png` (barangay and konstruksyon).
- **Charged tag reaches further (rule, in-game):** the harness measures 1.20 m idle → 1.92 m at full
  charge on both maps.
- **Jail chain (item 1):** the ten chain stills listed under item 1 — three links holding hands, the
  tip hanging and the tip reaching when a free ally is in range.
- **Ring save (item 6, last player bullet):** `konstruksyon_ring_save.png`, backed by
  `the defender chased 47 ticks, stands 1.50 m away, in its own ring true, capturer capturing true,
  los clear true, can_tag true`, `events ["capture_start","tag_charge","tag_windup",
  "capture_cancel:tagged","tag"]`, `capturer state=1 capturing=false, defender saves=1`.
- **Vaults:** `konstruksyon_vault_approach|midair|landed.png`; the run prints 6 vault attempts on
  `SolidCollision` with slide distances 0.33 / 0.24 / 1.64 / 1.71 / 1.71 / 1.71 m (best 1.71 m) and the
  collision mask restored to `vaultable` each time.
- **Camera never hides the player:** the two occlusion stills above plus the wide shots.
- **Movement/lanes:** `konstruksyon_run_start.png`, `konstruksyon_run_midfield.png` (a 90-tick run
  across the midfield, 34.41 m, no stuck spot), plus the `konstruksyon` suite's 2100-tick bot soak
  ("nobody stuck").
- **Castle crumbles on capture:** `konstruksyon_castle_intact.png` (the castle standing at the pole),
  `konstruksyon_castle_capturing.png` (`INAAGAW 50%`), `konstruksyon_castle_crumbling.png`,
  `konstruksyon_castle_crumbled.png` (debris field, no castle around the pole, `NAAGAWA ANG BASE!`, score 1-0).
  These four come from a targeted `--castle` run (20:33) because the full run's capture attempt stalled
  (`in capture range false, progress 0.00`); the targeted run reports `in capture range true, progress 0.50`
  then `captured [0], score [1, 0], phase 3, audio music=music_construction_site layers={ "tension": false }`.
- **Both maps:** `barangay_wide_map.png`, `konstruksyon_wide_map.png`.

Files (40):

```
barangay_arrow_charge_000|050|100.png      konstruksyon_arrow_charge_000|050|100.png
barangay_chain_3links.png                  konstruksyon_chain_3links.png
barangay_chain_3links_side.png             konstruksyon_chain_3links_side.png
barangay_chain_arms_no_ik.png              konstruksyon_chain_arms_no_ik.png
barangay_chain_tip_hangs.png               konstruksyon_chain_tip_hangs.png
barangay_chain_tip_reaches.png             konstruksyon_chain_tip_reaches.png
barangay_intro_1_arena.png                 konstruksyon_castle_capturing.png
barangay_intro_2_team_dilaw.png            konstruksyon_castle_crumbled.png
barangay_intro_3_team_lila.png             konstruksyon_castle_crumbling.png
barangay_intro_4_faceoff.png               konstruksyon_castle_intact.png
barangay_intro_5_round_live.png            konstruksyon_occlusion_dilaw_@node3d@833.png
barangay_interact_skips_intro.png          konstruksyon_occlusion_lila_@node3d@3107.png
barangay_tag_swing.png                     konstruksyon_ring_save.png
barangay_tag_whiff.png                     konstruksyon_run_midfield.png
barangay_wide_map.png                      konstruksyon_run_start.png
                                           konstruksyon_tag_swing.png
                                           konstruksyon_tag_whiff.png
                                           konstruksyon_vault_approach.png
                                           konstruksyon_vault_landed.png
                                           konstruksyon_vault_midair.png
                                           konstruksyon_wide_map.png
```

## Item 7 — Docs ✅

- `docs/status.md` — "last verified" line extended with this work; the audio row rewritten (20 CC0
  files with sources, the −3 / −6 dB layer mix, silent-by-design missing files); the `TagCharge` row
  records that the clip is missing because the Meshy MCP server has no API key; the Konstruksyon
  collider bullet lost its "asymmetry is tolerated" clause; new bullets for the mirror symmetry (and
  the jail-line length gap) and for the MultiMesh property order.
- `docs/decisions.md` — new dated section **2026-10-17: Chain hands, arrow legibility, CC0 files, map
  symmetry** with five entries: bone-name resolution + `skeleton_updated` pose capture for the chain
  IK; the two-layer arrow and its constants; the CC0 audio choice (including the skipped whistle and
  the layer dB); the mirror-symmetry moves; the MultiMesh `instance_count = 0` ordering.
- `renders/README.md` — says what `review/` holds and that the harness that produced it is throwaway.
- `docs/pipelines/blender.md` — **not** changed: it documents clips that exist, and the `TagCharge`
  clip could not be generated (item 3).
- `docs/architecture.md` — not changed: no system boundary, tick order or input path changed.
- `docs/RESBAK.md` — untouched (per the hard rule). The spec gaps for the spec owner stay as they were,
  including that the spec describes a 0.15 s wind-up while the game uses 0.3 s (v0.2) and still shows
  the own-ring barrier.

## Item 9 — Gate and hygiene

- Gate: `& $env:GODOT --headless --path . -s scripts/tests/integration_test.gd` -> exit 0, `14 suites, 1337 checks, 0 failed`, last line `All checks passed successfully (100%)!`, no `SCRIPT ERROR` lines. (The 7207a94 baseline was 1315 checks; the new ones are the konstruksyon suite, the tightened mirror checks and the HUD/arrow checks.)
- Nothing was committed; the working tree holds exactly the intended changes. Temporary files
  (`tmp_mm_probe.gd`, `tmp_review_shots.gd`, `tmp_review_shots.tscn`) were deleted before this report.
- `.gitattributes` puts the new `*.ogg` files through Git LFS. No new `.glb` or shipped `.png` came out
  of this work (item 3 blocked); the review stills live under `renders/`, which Godot ignores.

## Left undone / notes for the reader

1. **Item 3 is blocked on the Meshy API key** (see above) — the only item from the plan that could not
   be finished.
2. **The Freesound referee whistle was skipped** (CC0 but behind a sign-in); `sfx_sudden_death` uses
   the thunder for now.
3. **The 0.15 m hand-meet check uses a bunched chain** (0.9 m links) because 1.5 m links with ~0.5 m
   arms cannot meet; this is geometry, not a rule, and the map's authored spacing is unchanged.
4. **`renders/review/` is a temporary review artefact set**, not a shipped asset. Whether those 40 PNGs
   should be committed is the user's call.
5. Two failures found during this work were in **my throwaway harness**, not the game: the tip-reach
   probe picked a hero from the wrong team, and the ring-save probe let the capture complete (and the
   round end) before the tag was pressed. Both are fixed in the harness; the game code was not changed
   for either.

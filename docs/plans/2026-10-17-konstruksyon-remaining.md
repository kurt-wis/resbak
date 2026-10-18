# Plan: Konstruksyon overhaul, remaining work (2026-10-17)

This plan picks up the Konstruksyon + match-polish work after the first build pass. It lists **everything not yet complete**, in the order to do it.

> **Status, 2026-10-17 (end of day):** items **1, 2, 4, 5, 6, 7 and 9 are done**. Item **3 is blocked** —
> the Meshy MCP server rejects every call with `MESHY_API_KEY environment variable is required`, so the
> approved `TagCharge` generation could not be created (no credits spent). Full write-up with evidence,
> the gate result and the list of the 40 review stills:
> [`2026-10-17-konstruksyon-remaining.REPORT.md`](2026-10-17-konstruksyon-remaining.REPORT.md).

> **Audit follow-up, 2026-10-17 (Claude):** item 3 is now done: the TagCharge clip was generated here (one Prime task, 10 credits), retargeted from SMPL-H and QC'd on all five heroes. Also: the chain is drawn pulled in so hands meet at the real 1.5 m link, the tension stem crossfades in at 30 s left, and the arrow fill is team-coloured (see `docs/decisions.md`). Still open: item 6's in-game screenshots of a real chain (the REPORT's chain stills were taken before anyone was jailed) and the manual playtest.

## Starting state
- Branch `foundation`, HEAD `7207a94`. Everything below sits on top of about 43 **uncommitted** changed or new files.
- Last gate run: exit 0, `14 suites, 1315 checks, 0 failed`, `All checks passed successfully (100%)!`, no `SCRIPT ERROR`.

**Done, and verified by checks and screenshots:**
- Own-ring barrier removed on all maps.
- Pre-match intro (`RoundFlow.Phase.INTRO`, camera flyover, `hud_intro.gd`, Interact to skip).
- Konstruksyon:
  - mirrored lanes, spawns and colliders
  - vaultables
  - hot dusty-afternoon fog, sun and dust
  - sand castle objective (`tools/build_sand_castle.py`, `assets/props/sand_castle.*`, `base_prop` metadata)
  - occlusion fade (`scripts/match/occlusion_fade.gd`)
  - `konstruksyon` suite, including a 45 s 10-bot soak
- Charge aim arrow (replaces the fan).
- `TagCharge` code hook in `hero_visual.gd`, plus the `tools/build_heroes.py` bake path.
- Music API on `Audio` (`play_music` / `stop_music` / `set_music_layer`), with the `MUSIC` / `AMBIENCE` tables in `match_scene.gd`.

**Approvals the user has given (2026-10-17):**
- **Meshy:** Prime text-to-motion for `TagCharge`, **10 credits** (balance was 953). Approved for one generation. A retry or a second generation needs a new approval.
- **CC0 downloads** (all four approved). Verify the licence on each page again at download time; if a page no longer says CC0, stop and ask.
  1. Kenney *Impact Sounds* + *Music Jingles* (kenney.nl)
  2. rubberduck *100 CC0 SFX #2* (opengameart.org/content/100-cc0-sfx-2, ~2.4 MB)
  3. SubspaceAudio *12 Music Loops* (opengameart.org/node/170803, ~33.5 MB)
  4. SpliceSound referee whistle (freesound.org/people/SpliceSound/sounds/218318, ~477 KB). If Freesound requires a sign-in, the **user** signs in or downloads the file; the agent never enters credentials.

## Execution model
- **Implementation:** one subagent, `model: "sonnet"`, `effort: "high"`, working the items below in order and running the affected suites after each one.
- **Orchestrator:** I review its diff, QC sheets and screenshots, re-run the full gate, and send fixes back to the same agent.
- **Read-only exploration:** `model: "haiku"`, `effort: "medium"`.
- **Never:**
  - run `scripts/map_pipeline/*.gd`
  - edit `docs/RESBAK.md`, `addons/` or `.godot/`
  - commit without the user's go-ahead
  - spend Meshy credits beyond the one approved generation

---

## 1. Jail chain: hands actually meet
**Problem.** Prisoners stand side-on, but their arms point out almost horizontally ("airplane"), and neighbouring hands don't touch.

**Cause.** `HAND_HEIGHT := 0.52` (of model height) is shoulder height for these proportions. Each grip also aims at the midpoint between links, not at the neighbour's hand.

**Work, in `scripts/match/hero_visual.gd` (presentation only; host state untouched):**
- Lower `HAND_HEIGHT` to about **0.40–0.45** of model height (waist to lower chest). Tune it by screenshot.
- In `chain_grips()`, aim each grip at the **neighbour's actual hand bone** (`mixamorig:LeftHand` / `mixamorig:RightHand` global position on the neighbour's `HeroVisual`), blended with the midpoint, so the two hands converge on one shared point.
  - Clamp the reach so the elbows stay slightly bent; never lock the arm straight.
- Move the `TwoBoneIK3D` ("ChainArms") elbow pole targets **down and back** so the arms hang, instead of pointing the elbows out sideways.
- The tip link keeps reaching toward rescuers. The end link's free arm relaxes, with no IK target.
- If the `Chained` clip's arms still fight the IK, mask or stiffen the upper body (see `docs/pipelines/blender.md` if the clip changes, then run `tools/qc_asset.py`).

**Checks** (jail-related suite, `core_rules` or wherever the chain checks live now):
- Adjacent links' gripping hand bones end within **0.15 m** of each other after the IK settles.
- The grip height is below the shoulder bone on every link.
- The existing facing check (interior links within ±20° of perpendicular) still passes.

**Evidence.** Before/after screenshots of a 3- to 4-link chain on **Barangay Court and Konstruksyon**.

## 2. Aim arrow: readable on every floor
**Problem.** The arrow is too faint on the orange Konstruksyon floor.

**Work, in `scripts/match/match_view.gd` (`AimArrow`) and `scripts/match/vfx.gd` (`arrow_mesh`):**
- Two-layer arrow: a dark outline (slightly larger, behind) plus a bright **team-colour** fill, or a white core with a team-colour rim. Pick whichever reads better in screenshots on both maps.
- Full-charge alpha around **0.85**. Keep the gradual fade-in while charging and the white pulse at full charge.
- Keep it unshaded and drawn over the floor markings (`render_priority`), and still local-player only.
- Read colours and alphas from consts or `tuning`, not scattered literals.

**Checks.** Update the existing `hud` / `match_flow` arrow checks: alpha at full charge ≥ 0.8, outline node present, alpha 0 when idle.

**Evidence.** Screenshots at 0 %, 50 % and 100 % charge on both maps, Dilaw and Lila.

## 3. `TagCharge` animation (Meshy, approved: Prime, 10 credits)
1. `meshy_text_to_motion`, `ai_model` prime. Prompt: *"a kid leaning back in a stable wide stance, right arm drawn far back at shoulder height with an open palm, left arm forward for balance, tense and ready to slap, subtle breathing loop"*, about 2 s, looping.
   - Follow the Meshy rules: poll the same `task_id` on a timeout, and check `meshy_list_tasks` before any re-create.
2. Save the download to `source_art/mocap/meshy/shared_tag_charge.glb` (LFS).
3. `& $env:BLENDER -b --python tools/build_heroes.py`. This bakes `TagCharge` onto all five heroes:
   - an NLA track
   - full skeleton, ≥ 60 tracks
   - looped
   - the name is exactly `TagCharge` (never `Slide` / `Dash`)
4. Run `tools/qc_asset.py` for **each** hero and look at every sheet. Watch for foot sliding, wrist flips and arm clipping through the body.
5. `hero_visual.gd` already plays `TagCharge` while `h.is_charging()`. Confirm the blend into `Tag` on release and while walking during a charge.
6. Update the `docs/pipelines/blender.md` clip table and the `hero_assets` suite (the clip exists on all five heroes, loops, has ≥ 60 tracks).

## 4. CC0 audio (approved packs)
1. Download each pack into its own new folder in the scratchpad.
   - Treat the contents as untrusted data: unzip only, never run anything inside.
   - Re-check the licence text in the archive or on the page.
2. Choose files and copy them into `assets/audio/`, keeping a `CREDITS.md` or `LICENSES.md` there (source URL, author, licence per file).
   - Prefer `.ogg` for loops; `.wav` is fine for short SFX.
   - Check `.gitattributes`; add audio extensions to LFS if the files are large.
3. Map files to the slot names the code already uses:
   - **Ambience:** `construction_ambience` (rubberduck construction loop), plus the Barangay Court ambience if one fits.
   - **Music:** `music_construction_site` and `music_construction_site_tension` (the 30-second-left layer). Also `music_barangay_court` and its tension layer (SubspaceAudio loops).
   - **SFX:** every `sfx_*` name in the `match_view.gd` SFX table (slap/HULI, charge, whiff, jail, rescue, capture, countdown, KABOOM), plus `sfx_castle_crumble`.
   - **Whistle:** the countdown start and/or sudden death.
4. Add the Barangay Court entries to `match_scene.gd`'s `MUSIC` / `AMBIENCE`.
5. Set bus volumes so the music sits under the SFX.
6. Run `--import` and confirm every slot resolves.

**Checks.** A suite check that every slot name in the SFX, `MUSIC` and `AMBIENCE` tables resolves to an existing imported stream, and that the music tension layer switches at 30 s left.

## 5. Loose ends
- **Import errors.** `--import` printed 16 × *"Instance count must be 0 to change the transform format"*.
  - Find the source: likely a `MultiMesh` whose `transform_format` is set after `instance_count` (the new dust or prop scattering in `construction_site.tscn` / `map_dressing.gd` / `arena_art.gd`).
  - Fix the property order, or set `instance_count = 0` first. Then re-run `--import` and confirm it's clean.
- **Occlusion fade, Lila side.** Verify `occlusion_fade.gd` with the camera on the Lila side (only Dilaw was checked). Take screenshots behind the tallest building on each side.
- **Konstruksyon symmetry.** Fix the small left/right imbalance in pile placement near the bases instead of tolerating it. Tighten the `konstruksyon` suite's mirror check accordingly.

## 6. Manual playtest (with screenshots for the user)
`& $env:GODOT --path . res://scenes/match.tscn -- --hero=nene` with the map set to `construction_site`, then again on Barangay Court:
- The intro plays (arena orbit → TEAM DILAW → TEAM LILA → face-off), the banner text shows, and Interact skips it.
- Charging shows the arrow plus `TagCharge`; releasing plays `Tag`; a charged tag reaches further.
- Get jailed: the chain holds hands and the tip reaches toward rescuers.
- A defender chases a capturer into its own ring and tags them.
- Konstruksyon:
  - no invisible walls or stuck spots
  - vaults work
  - the camera never hides the player
  - the castle crumbles on capture
  - ambience, music and SFX all play

Log anything found as a new item in this plan or in `docs/status.md`.

## 7. Docs (same change as the code)
- `docs/status.md`: chain fix, arrow, `TagCharge` shipped, audio shipped (with sources), import fix.
- `docs/pipelines/blender.md`: the `TagCharge` row.
- `docs/decisions.md`: dated entries for the arrow styling, Meshy as the `TagCharge` source, and the CC0 audio choice.
- `docs/architecture.md`: only if structure changes.
- Mark this plan's items done (or delete the plan once everything has shipped).

## 8. Spec gaps (user / spec owner, not the agent)
These are logged in `docs/status.md`. The spec owner decides on each; `docs/RESBAK.md` is never edited by agents.
- The spec has no Konstruksyon or sand-castle section.
- The charged hampas (optional charge adds reach) is undocumented.
- Swing wind-up: the spec says 0.15 s; the game uses 0.3 s.
- The spec still describes the own-ring barrier, which was removed on all maps.

## 9. Final gate and commit
- Full gate in the background: `& $env:GODOT --headless --path . -s scripts/tests/integration_test.gd`. Report the exit code and the final line, and make sure there are no `SCRIPT ERROR` lines.
- Commit on `foundation` **only after the user says so**. Don't commit `gate_*.txt`, `.opencode/`, `__pycache__/` or `dev/`. Confirm LFS picked up the new `.glb`, `.png` and audio files.

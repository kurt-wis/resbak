# scripts/tests/

`integration_test.gd` is **the gate**. It runs every suite in `suites/` (listed in its `SUITES`):

| Suite | Checks |
| ----- | ------ |
| `project` | 1920×1080, stretch, 60 ticks, Jolt, autoloads, input actions, key tuning numbers |
| `legacy` | Batang Hamog clips and controller, Dire-Diretso prototype, JM Botsog rig, character select, scene loads, main scene |
| `hero_assets` | five hero GLBs (clips, no Slide/Dash, one mesh), `data/heroes/*.tres` against spec § 4 |
| `core_rules` | narrow body tagging, selected identity/crossing enemy/movement dodge, planted attack/action lock and release, first landing/hold edges, Sabay fall/retry, EP, barriers, capture, chain, rescue, lockdown, timer, sudden death, draws, reset, match end |
| `kit_tutoy`, `kit_nene`, `kit_nathan`, `kit_jm`, `kit_inday` | each hero's skills and passive against spec § 4 |
| `bots` | seeded attack decisions/post-Sabay repositions, roles, perception, tagging, retreat, chain, rescue, a bot-only 5v5 |
| `hud` | HUD parts, timer, tag feed, scoreboard, hide, pause, announcer, round-1 intro overlay and flyover, fixed close camera zoom, attack-only transparent red strip/outline and overhead names (no ground rings or enemy ranges), layered moving actions/chain/backpedal, stationary full-body tick-aligned tag pose, default-visible touch/mouse pads, skill hold/drag/release/cancel, cooldown gating, MENU pause, and in-reach target lock, optional hold/drag/release/cancel selection |
| `hero_revision` | stationary cast/recovery plants, traversal exemptions, moving Hampas preparation, planted commitment, forced objective-facing capture, rounded ground guides, tappable status details, larger controls, 24-pose clock across render rates, shoulder cloth anchors, click-only Tamaraw and host-bounded miss recovery |
| `konstruksyon` | the real Konstruksyon map: mirrored bases, spawns and base rings clear, jail lines, vaultables, three 2 m routes between the halves, camera occlusion fade, sand-castle base prop and crumble, haze/sun/dust, music/ambience entries and the Audio music API, a 45 s bot soak (nobody stuck 3 s) |
| `frontend` | every front-end screen builds, draft, names, results maths, settings persist |
| `home` | Home diorama: 48 s loop schedule, cast/bystanders/jeepney build and hide at the seam, sky and depth-blur shaders wired, skyline backdrop, hero picker flow, version and Master-volume defaults |
| `match_flow` | `scenes/match.tscn` runs 600 frames with bots; free training on both maps, resets, dummy/bot sources, no scoring, half cooldowns and pause |

```powershell
& $env:GODOT --headless --path . -s scripts/tests/integration_test.gd                       # all
& $env:GODOT --headless --path . -s scripts/tests/integration_test.gd -- --only=core_rules,bots
```

Pass = exit 0 and the last line `All checks passed successfully (100%)!`. A suite is a `RefCounted` with
`func run(t: TestCtx)`; use `t.check(cond, msg)` (never `assert`), `t.make_match(...)` for a grey arena match with
`ScriptedInput` and manual stepping. After adding `class_name` scripts run `--import` first.

`legacy/verify_*.gd` are stale map snapshots, not part of the gate.

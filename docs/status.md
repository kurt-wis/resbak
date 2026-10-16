# Implementation status

What exists versus what is only designed in [`RESBAK.md`](RESBAK.md). Update this file in the same change as the code.
Legend: ✅ done · 🟡 partial · ❌ design only. "Suite" = the gate suite in `scripts/tests/suites/` that checks it.

_Last verified: 2026-10-16 (gate run in the commit that added this file)._

## Core rules (spec § 2, § 3)

| System | Status | Where | Suite |
| ------ | ------ | ----- | ----- |
| Host tick loop, 60 ticks/s, spec tick order (10 steps), InputFrames for players and bots | ✅ | `scripts/match/match_host.gd` | core_rules |
| Unahan tagging: 9-tick wind-up, reach edge to edge, 45° arc, nearest wins, failed tag stumble, Sabay, tag assist (gamepad) | ✅ | `systems/tag_system.gd` | core_rules |
| Bodies (r 0.4, solid when Free, ghost when Tagged/Jailed/Chained/EP), pushes (0.2 s, stop dead), strongest slow, biggest bonus, stun/stumble | ✅ | `scripts/match/hero.gd` | core_rules, kits |
| Bases: site roulette or Fixed, solid pole, own-ring barrier (2.4 m), capture (hold or toggle, 1.5 s, cancels), capture lockout | ✅ | `systems/base_system.gd` | core_rules |
| Jail: 0.8 s freeze then tagger's jail, jail barrier, anchor/join/let go, tip steering, 4-chain max, rescue by touching tip / lone-anchor hand point, EP 4 s (5 s Inday), lockout | ✅ | `systems/jail_system.gd` | core_rules |
| Round flow: countdown 3 s, KABOOM, 2 min timer, lockdown, sunset win, sudden death (Takipsilim, 30 s, untimed after 2 draws), draws, reset to spawns, first to 3 | ✅ | `systems/round_flow.gd` | core_rules |
| Results stats: Impact (tag 2, rescue 3/prisoner, capture 10, Saved +2, Clutch +5), Pader, Pasaway, tags-by for Nemesis | 🟡 Assists and Kidlat (longest chase) are not counted yet (always 0) | `match_host.gd`, systems | frontend |
| Taguan zones, high ground zoom, terrain, hazards (Baha) | ❌ | — | — |

## Heroes (spec § 4)

| Hero | Idle / Walk / Run (own clips) | Skill 1 | Skill 2 | Passive | Suite |
| ---- | ----------------------------- | ------- | ------- | ------- | ----- |
| **Tutoy** | Idle_5 / Quick Walk / Lean Forward Sprint | HARUROT! ✅ 9 m/s 1.2 s, wind trail | LUSOT! ✅ 4 m slide, vault, 0.3 s no-tag, PERFECT stun 0.6 s | DIRE-DIRETSO ✅ 0→15 % over 3 s | kit_tutoy |
| **Nene** | Happy Sway / Skip / Run Fast 7 | IYAK! ✅ crying decoy 5 s, see-through 3 s | SUMBONG KITA! ✅ fake alert 12 m / fake rescuer near jail | SALING-PUSA ✅ silent after 4 s | kit_nene |
| **Nathan** | Scheming / Sneaky Walk / Run Fast 9 | BUGA! ✅ 0.4 s inhale, 5 m 60° cone, slow + trail + reveal | UBO! UBO! ✅ 9 m packet, 3.5 m cloud 5 s, cough reveal | MAY TIRA PA! ✅ powder patch | kit_nathan |
| **JM "Botsog"** | Idle_11 / Proud Strut / Run Fast 4 | TALBOG! ✅ 6 m jump 0.6 s, push 3 m, crescent wall 4 s | TAMARAW!!! ✅ 9 m/s charge, side shove, wall stun | MAKAPAL! ✅ guard break, 15 s regen | kit_jm |
| **Inday** | Hand on Hip / Confident Strut / Run Fast 6 | IHIP! ✅ 10×3 m wind lane, +25 % allies | SAGIP! ✅ 3 m ranged rescue with clear line | TAKBO NA! ✅ +20 % 2 s, +1 s EP | kit_inday |

Every hero also has the core clips Tag, Tagged, Stumble, Stunned, Jailed, Chained, Capture, Victory, and BreakDance for menus (`docs/pipelines/blender.md`).

## Match presentation, bots, front end

| Area | Status | Where | Suite |
| ---- | ------ | ----- | ----- |
| Camera (55° pitch, 22 m, 40° FOV, never rotates), outlines (orange taggable / grey), "!" icon, EP shield, see-through, cloud hiding, world feedback (HULI!, RESBAK!, NAKUHA!, PERFECT!, confetti) | ✅ | `match_camera.gd`, `match_view.gd`, `hero_visual.gd` | match_flow, hud |
| HUD: sun timer + score + dots, prisoner tracker, minimap, tag feed, S1/S2 + passive, danger border, off-screen arrows, capture rings, jail prompt, countdown + between rounds, scoreboard (Tab), F10, pause overlay | ✅ | `scripts/ui/hud/` | hud |
| Bots: roles every 1 s (Bantay, Atake, Pain, Resbak, Kapit), reaction / retreat / skill-use by difficulty, visibility rule, runtime navmesh | ✅ | `scripts/match/bots/` | bots |
| Front end: boot, title, first-time setup, Home (bench hero), Play menu (vs Bots, Tradisyonal; Custom Room greyed), roulette, snake draft, results (3 steps), Settings (5 tabs) | ✅ offline | `scripts/ui/frontend/`, `scenes/frontend/` | frontend |
| Save (settings.cfg, profile.json, .tmp→rename, .bak), Session, Audio buses + announcer queue, Controls (rebindable defaults) | ✅ | `scripts/autoload/` | project, frontend |
| 1920×1080 base resolution, borderless fullscreen default | ✅ | `project.godot` | project |
| LAN (Net autoload, ENet, discovery, Custom Room, Kanto lobby, takeover, rejoin) | ❌ next step: the host already runs on InputFrames, so clients only need to send frames and draw snapshots | — | — |
| Tutorial lessons, Alam Mo Ba? pages, intro cinematic, credits, audio assets, voice lines | ❌ | — | — |
| Plaza and Tambakan maps | ❌ | — | — |

## Known design ↔ code gaps
- **Map size**: Barangay Court is about 39 × 29 m of play space; the spec says 56 × 32 m. Jails are 4 × 3.3 m (spec 6 × 4). Spawns and jail markers are derived by `MapLayout` (no `Spawn_*` / `JailMarker_*` nodes in the scene yet).
- **Facing**: the spec says the hero always faces the cursor. Heroes face their movement direction while running and turn to the aim when standing, tagging or casting; an aim fan under the local hero shows the lunge. Forward-only run clips look wrong when strafing. Team decision needed.
- **Slow walk cycles**: Nathan's Sneaky Walk and JM's Proud Strut have short strides, so at the spec walk speed they play about 8.9× and 4.4×. Walking only happens on a gamepad (15–50 % tilt). Fix: a faster Meshy walk preset (3 credits each) or another walk.
- **JM Talbog_Slam**: his fist dips up to 12 cm under the floor at impact (covered by the dust ring).
- **Assists and Kidlat** are not tracked yet, so those badges never appear.
- **Skill visuals are code-built** (CPUParticles, simple meshes). No authored VFX textures or sounds yet; `Audio.play()` names are placeholders until audio lands.
- **Legacy dev code**: `scripts/runtime/` (HeroController, HeroRoster, character select, Batang Hamog prototype, movement test) is kept for reference and the `legacy` suite; the match does not use it. `jm_botsog.glb` is unused.
- The `scripts/tests/legacy/verify_*.gd` checks fail against the current map; they are historical.

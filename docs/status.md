# Implementation status

What exists versus what is only designed. Update this file in the same change as the code.
Legend: ✅ done · 🟡 partial · ❌ design only. The "Gate" column says whether `scripts/tests/integration_test.gd` covers it.

_Last verified: 2026-10-16 (gate green)._

## Core game systems ([rules](design/RESBAK_GDD.md#2-core-rules))

| System | Status | Where | Gate |
| ------ | ------ | ----- | ---- |
| Barangay court map, props, collisions | ✅ | `scenes/barangay_court.tscn` | loads |
| Base pads (3 per team, 2 m ring, own-team barrier) / jails (Area3D markers) | 🟡 markers only, no logic | `BaseSites/*`, `JailZones/*` | — |
| Teams (Purok Dilaw yellow / Purok Lila purple) | ❌ | — | — |
| Unahan tag rule (first clean tag wins, Sabay) + tag resolution | ❌ | — | — |
| Jail, human chain, rescue by touching the chain tip, 4 s Escape Protection | ❌ | — | — |
| Win conditions (base capture, total jail lockdown, sunset tiebreak and sudden death) | ❌ | — | — |
| Flag carry (the GDD has no flag; capture is hold Interact 1.5 s at the pole) | 🟡 legacy `is_carrying_flag` flag on the controller only | `batang_hamog.gd` | ✅ (Dire reset) |
| Roof cutaway | 🟡 shader + toggle exist; roof not instanced in court | `court_playtest.gd`, `scenes/court_roof.tscn` | — |
| Multiplayer / networking | ❌ | — | — |
| Character select (demo) → playtest spawns the pick | ✅ main scene | `scenes/character_select.tscn`, `hero_roster.gd` | ✅ |

## Characters ([spec, Characters](design/RESBAK_GDD.md#4-characters))

| Character | Model / rig | Clips | Skill 1 | Skill 2 | Passive |
| --------- | ----------- | ----- | ------- | ------- | ------- |
| **Tutoy** (Meshy model; takes Batang Hamog's kit in the design doc) | ✅ `tutoy.glb` (66 bones) | Idle, Walking, Running, BreakDance ✅ `HeroController` blend (gate) | ❌ | ❌ | ❌ |
| [Batang Hamog](archive/characters/03_batang_hamog.md) (old rig, skills prototype; **not in the select**, `--hero=hamog` only) | ✅ `batang_hamog.glb` | Idle, Walking, Running, Harurot, Lusot_Slide, Lusot_Vault ✅ | **HARUROT!** ✅ `try_harurot` (gate) | **LUSOT!** ✅ slide + vault `try_lusot` (gate) | **DIRE-DIRETSO** ✅ `DireDiretsoComponent` (gate) |
| [JM (Botsog)](design/RESBAK_GDD.md#jm-botsog) | ✅ `jm.glb` (Meshy, 67 bones); older procedural `jm_botsog.glb` unused | Idle, Walking, Running, BreakDance ✅ `HeroController` blend (gate) | TALBOG! ❌ | TAMARAW!!! ❌ | MAKAPAL! ❌ |
| [Nene](design/RESBAK_GDD.md#nene) | ✅ `nene.glb` (66 bones) | Idle, Walking, Running, BreakDance ✅ `HeroController` blend (gate) | IYAK! ❌ | SUMBONG KITA! ❌ | SALING-PUSA ❌ |
| [Nathan](design/RESBAK_GDD.md#nathan) | ✅ `nathan.glb` (66 bones) | Idle, Walking, Running, BreakDance ✅ `HeroController` blend (gate) | BUGA! ❌ | UBO! UBO! ❌ | MAY TIRA PA! ❌ |
| [Inday](design/RESBAK_GDD.md#inday) | ✅ `inday.glb` (66 bones) | Idle, Walking, Running, BreakDance ✅ `HeroController` blend (gate) | IHIP! ❌ | SAGIP! ❌ | TAKBO NA! ❌ |

The five Meshy heroes move with the shared `HeroController` (no skills yet). Movement follows the
design doc's 2026-10-16 rule: always run (Tutoy 5.4, JM 4.6, others 5.0 m/s), a 15–50 % stick tilt
walks at half speed, under 15 % stands; keyboard always runs. On the character select each hero
plays the `BreakDance` clip. Skills exist only on the old Batang Hamog rig (`--hero=hamog`).
`source_art/heroes/KimKim_Asset.glb` is Nathan's Kimkim packet prop (not used in code yet).

## Known design ↔ code gaps
- **No flag in the GDD**: base capture is a 1.5 s Interact hold at the pole. There is no flag to carry, and no capture code exists yet.
- **`is_carrying_flag` is legacy**: it survives on `BatangHamogController` only because Dire-Diretso's reset (and its gate assert) uses it. Replace it when capture is built.
- **Tutoy vs Batang Hamog**: the design doc gives Tutoy the speed burst + slide kit, but Harurot / Lusot / Dire-Diretso still live in `BatangHamogController` on the old model. Porting them onto `tutoy.glb` needs Harurot/Lusot clips for the new rig.
- **Walk/run clips are shared**: every hero's Walking is retargeted from JM's walk, and JM's Running from Tutoy's; Idle is generated. Fine for the demo, but per-hero personality clips would read better.
- Walk/run playback is scaled to the measured foot speed (hero_roster *_clip_speed); walking plays near 1.9x until heroes get longer-stride walks.
- **Harurot speed**: the dossier says "120% speed multiplier"; the code reads it as +120%, `harurot_speed_multiplier = 2.2`. The clip is 1.0 s but the burst lasts 1.2 s, and the last 0.2 s holds the clip's final pose.
- **`movement_test.gd`** still has the pre-controller Shift-sprint rig and does not use `BatangHamogController`.
- The touch button labelled **DASH** triggers Harurot. That label is a leftover from before the rename.
- The `scripts/tests/legacy/verify_*.gd` checks fail against the current map; they are historical.

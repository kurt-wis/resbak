# Implementation status

What exists versus what is only designed. Update this file in the same change as the code.
Legend: ✅ done · 🟡 partial · ❌ design only. The "Gate" column says whether `scripts/tests/integration_test.gd` covers it.

_Last verified: 2026-10-15 (gate green)._

## Core game systems ([rules](gameplay/agawan_base_rules.md))

| System | Status | Where | Gate |
| ------ | ------ | ----- | ---- |
| Barangay court map, props, collisions | ✅ | `scenes/barangay_court.tscn` | loads |
| Base pads (3 per team) / jails (Area3D markers) | 🟡 markers only, no logic | `BaseSites/*`, `JailZones/*` | — |
| Teams (Yellow / Purple) | ❌ | — | — |
| Freshness (*Bago sa Base*) + tag resolution | ❌ | — | — |
| Jail, chain (*Kuryente*), rescue (*Sagip*), 2.0 s grace | ❌ | — | — |
| Win conditions (Dikit Base, Huli Lahat, time-out) | ❌ | — | — |
| Flag carry | 🟡 `is_carrying_flag` flag on the controller only | `batang_hamog.gd` | ✅ (Dire reset) |
| Roof cutaway | 🟡 shader + toggle exist; roof not instanced in court | `court_playtest.gd`, `scenes/court_roof.tscn` | — |
| Multiplayer / networking | ❌ | — | — |

## Characters ([RESBAK.md](RESBAK.md))

| Character | Model / rig | Clips | Skill 1 | Skill 2 | Passive |
| --------- | ----------- | ----- | ------- | ------- | ------- |
| [Batang Hamog](characters/03_batang_hamog.md) | ✅ `batang_hamog.glb` | Idle, Walking, Running, Harurot, Lusot_Slide, Lusot_Vault ✅ | **HARUROT!** ✅ `try_harurot` (gate) | **LUSOT!** ✅ slide + vault `try_lusot` (gate) | **DIRE-DIRETSO** ✅ `DireDiretsoComponent` (gate) |
| [JM (Botsog)](characters/01_jm_botsog.md) | ✅ `jm_botsog.glb` (55 bones + towel) | Idle, Walking, Running ✅ | TALBOG! ❌ | TAMARAW!!! ❌ | MAKAPAL! ❌ |
| [Nene](characters/02_nene.md) | ❌ | ❌ | IYAK! ❌ | SUMBONG KITA! ❌ | SALING-PUSA ❌ |
| [Nathan](characters/04_nathan.md) | ❌ | ❌ | BUGA! ❌ | UBO! UBO! ❌ | MAY TIRA PA! ❌ |
| [Inday](characters/05_inday.md) | ❌ | ❌ | IHIP! ❌ | SAGIP! ❌ | TAKBO NA! ❌ |

JM has a model only. No controller exists, and `court_playtest.gd` spawns only Batang Hamog.

## Known design ↔ code gaps
- **Harurot speed**: the dossier says "120% speed multiplier"; the code reads it as +120%, `harurot_speed_multiplier = 2.2`. The clip is 1.0 s but the burst lasts 1.2 s, and the last 0.2 s holds the clip's final pose.
- **`movement_test.gd`** still has the pre-controller Shift-sprint rig and does not use `BatangHamogController`.
- The touch button labelled **DASH** triggers Harurot. That label is a leftover from before the rename.
- The `scripts/tests/legacy/verify_*.gd` checks fail against the current map; they are historical.

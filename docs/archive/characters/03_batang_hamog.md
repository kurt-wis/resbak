# Character Dossier: Batang Hamog

## Overview & Identity
- **Name**: Batang Hamog
- **Archetype / Primary Role**: **Movement**
- **Secondary Specialty**: **Rescue**
- **Vibe & Concept**: The agile, fast-talking street kid who has grown up running through alleys, rooftops, and crowded barangay streets. He has unmatched burst speed, slick obstacle navigation, and relentless acceleration.

---

## Combat & Ability Specifications

### Active Skill 1: HARUROT!
- **Category**: High-Speed Dash / Escape Vector (implemented as an original keyframed dash burst)
- **Mechanics**:
  - Batang Hamog triggers an instantaneous explosive sprint burst, granting a 120% speed multiplier for 1.2 seconds.
  - Unlike straight dashes, Harurot preserves razor-sharp directional steering, allowing him to carve tight corners around bleachers and tricycle obstacles.
  - Leaves behind an intense stylized wind particle stream tracing his escape route.
  - Animation (`Harurot` clip, authored from scratch in Blender 5.2 via the MCP pipeline on 2026-10-14, structured from the Rivals Workshop *Anticipation, Action, Recovery* guide and Disney's 12 principles): frames 0-4 anticipation coil with the weight sinking and both arms loaded behind the body so the burst direction reads before he moves; frame 8 explosive push-off with the torso stretched forward, lead arm punched out and trailing leg fully extended; frame 13 airborne stride at the widest silhouette; frame 17 landing squash absorbing over the front leg; frame 20 a held low recovery pose that is clearly not idle; frame 24 a fast pop back to the exact Idle frame-0 stance so the blend out is seamless. The rise-up recovery window plays the upright walk clip (never the hunched run clip) until the character is fully standing.
  - The previous parkour shoulder-roll `Dash` clip and the baseball-slide `Slide` clip were removed from the GLB on 2026-10-14 and are asserted absent by the integration test.
- **Vulnerabilities**:
  - Does not grant invulnerability or tag immunity.
  - A skilled defender with fresh base priority can position themselves ahead of the wind trail and intercept him.

### Active Skill 2: LUSOT!
- **Category**: Mobility / Low Obstacle Navigation & Slide
- **Mechanics**:
  - In open space: Batang Hamog drops low to the ground and executes a fast knee slide (0.7s duration), kicking up dust and lowering his hurtbox height.
  - Near low cover: When directed toward a low wall, wooden crate, or monobloc chair, Batang Hamog vaults smoothly over the obstacle without losing forward velocity.
- **Implementation status**: `Lusot_Slide` (24f 0..23: 0-3 drop, 4-17 knee slide 0.7s, 18-23 pop to Idle) and `Lusot_Vault` (15f 0..14: reach/tuck/landing into Run) authored 2026-10-14 in `tools/build_hamog_moveset.py`; both ship in `assets/characters/batang_hamog.glb` with 65 tracks each. Legacy `Slide`/`Dash` remain purged (exact-name asserts).
- **Physical Bounds**:
  - Cannot pass through solid concrete walls, vehicle bodies, or other players.
  - A brief 0.25s recovery period prevents an immediate tag straight out of the slide.

### Passive Trait: DIRE-DIRETSO
- **Category**: Momentum Acceleration Engine
- **Mechanics**:
  - While running continuously in a consistent forward trajectory, Batang Hamog builds momentum stacks every 1.5 seconds (up to 4 stacks, granting +5% speed per stack up to a maximum +20%).
- **Reset Conditions**:
  - Momentum completely resets to zero if he:
    1. Stops or drops below baseline running speed.
    2. Makes a sharp 180° reversal.
    3. Attempts to tag an opponent.
    4. Is struck by an enemy skill (e.g., Nathan's powder blast or Botsog's ground slam).
- **Objective Balance**:
  - Dire-Diretso momentum bonus is disabled while carrying the enemy base flag.

---

## Implementation status

All three abilities ship and are gate-tested. Controller: `scripts/runtime/batang_hamog.gd` (`BatangHamogController`: `try_harurot`, `try_lusot`, `attempt_tag`); passive: `scripts/runtime/dire_diretso.gd` (`DireDiretsoComponent`); clips in `assets/characters/batang_hamog.glb`; tuning and known gaps in [`../architecture.md`](../architecture.md) and [`../status.md`](../status.md).

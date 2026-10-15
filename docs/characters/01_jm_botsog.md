# Character Dossier: JM (Botsog)

## Overview & Identity
- **Name**: JM (Street nickname: *Botsog*)
- **Archetype / Primary Role**: **Protection**
- **Secondary Specialty**: **Disruption**
- **Vibe & Concept**: The sturdy, heavyweight neighborhood defender. Botsog is the defensive anchor who controls space, raises physical cover, shoves intruders away from the base, and absorbs enemy tag attempts with his thick guard.

---

## Combat & Ability Specifications

### Active Skill 1: TALBOG!
- **Category**: Area-of-Effect Disruption & Cover Creation
- **Mechanics**:
  - Botsog jumps into the air and body-slams down onto the court pavement with immense force.
  - The impact triggers an outward radial shockwave that knocks back all nearby enemies by 4.0 meters.
  - At the point of impact, a temporary crescent-shaped earth wall erupts from the court facing his chosen aim direction.
- **Tactical Utility**:
  - The crescent wall blocks direct tag paths and enemy vision for 5.0 seconds.
  - Allies can take cover behind it to stage rescue runs or defend the home base pad.
  - Enemies can still maneuver around the open sides of the crescent.
- **Telegraphing & Counterplay**:
  - A bright circular landing marker appears on the ground for 0.4 seconds before Botsog lands, giving agile opponents a window to dodge.

### Active Skill 2: TAMARAW!!!
- **Category**: Line Charge & Crowd Displacement
- **Mechanics**:
  - Botsog lowers his head and charges forward with furious momentum, enveloped in the glowing spectral aura of a Philippine Tamaraw bull.
  - While charging, forward speed is increased by 80%, but steering inertia is heavy and difficult to turn sharply.
  - Any opponent struck by Botsog during the charge is violently pushed aside and displaced.
- **Wall Collision & Vulnerability**:
  - If Botsog crashes into a solid court wall, basketball post, or obstacle, the charge abruptly terminates with a localized shockwave that briefly slows nearby enemies.
  - After hitting a wall, Botsog undergoes a brief recovery stumble animation (0.6s) where he is completely vulnerable.
  - **Restriction**: Botsog **cannot tag** opponents during the Tamaraw charge; the skill is designed to clear space rather than automatically capture players.

### Passive Trait: MAKAPAL!
- **Category**: Defense / Tag Absorption Shield
- **Mechanics**:
  - Represents Botsog's tough build and thick guard.
  - When an enemy player executes a valid tag on Botsog, his guard breaks instead of sending him to jail.
  - Only a **second valid tag** while his guard is broken will capture and send him to the enemy jail.
- **Recovery Conditions**:
  - Immediately after his guard breaks, Botsog cannot tag opponents for 2.0 seconds.
  - His guard shield only regenerates after spending 3.0 uninterrupted seconds standing safely inside his team's deployed base pad.
  - A prominent UI guard icon above his head indicates to all players whether his guard shield is active or broken.
- **Objective Balance**:
  - Carrying the enemy flag or objective immediately disables Makapal! protection: any valid tag on a flag-carrying Botsog captures him instantly.

---

## Implementation status

Model + rig: `assets/characters/jm_botsog.glb` (built by `tools/build_jm_botsog.py`; Idle/Walking/Running, Mixamo + `Towel1_R`/`Towel2_R`). **No controller and no skills in code yet.** See [`../status.md`](../status.md).

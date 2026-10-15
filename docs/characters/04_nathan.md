# Character Dossier: Nathan

## Overview & Identity
- **Name**: Nathan
- **Archetype / Primary Role**: **Disruption**
- **Secondary Specialty**: **Deception**
- **Vibe & Concept**: The mischievous neighborhood kid perpetually clutching straw packets of powdery sweet Mik-Mik candy. Nathan turns everyday street snacks into battlefield hazards, blinding enemies, tracking them with candy powder trails, and laying footstep traps.

---

## Combat & Ability Specifications

### Active Skill 1: BUGA!
- **Category**: Frontal Cone Slow & Tracking
- **Mechanics**:
  - Nathan pauses briefly (0.35s inhale animation) and blows a wide forward cone (60° arc, 7.0-meter range) of powdered Mik-Mik.
  - Opponents caught in the powder blast suffer a 35% movement speed reduction for 3.0 seconds.
  - Affected enemies leave a bright, glowing powder footstep trail behind them, making their escape or flanking route obvious across the court.
- **Fair Play Constraints**:
  - The powder blast does not tag opponents and does not reset enemy flag captures.
  - The distinct inhale telegraph gives opponents a reactive window to sidestep out of the cone.

### Active Skill 2: UBO! UBO!
- **Category**: Area Obscuration & Cough Interruption
- **Mechanics**:
  - Nathan hurls a sealed Mik-Mik packet that bursts on impact into a lingering cloud of powder haze (4.0-meter radius, lasting 6.0 seconds).
  - Both allies and enemies inside the cloud experience restricted vision.
  - Enemies who remain inside the cloud for longer than 1.0 second trigger a coughing fit:
    - Coughing emits loud audio cues and ping markers revealing their exact position.
    - Coughing cancels any active sprinting, forcing them to baseline walk speed for 1.5 seconds.
    - Victims can still move, tag, and use skills.
- **Teamwork Note**:
  - Each enemy can trigger a cough only once per cloud instance. Careless cloud placement can block Nathan's own teammates' sightlines.

### Passive Trait: MAY TIRA PA!
- **Category**: Trap Deployment / Footstep Alarm
- **Mechanics**:
  - "There is still powder left in the packet." After casting an active skill, Nathan's next sharp turn (>75° direction shift) automatically deposits a small, visible patch of leftover powder on the ground.
  - The first enemy player to walk over the powder patch triggers a loud puff of dust and an audible shoe screech, pinging their position on Nathan's screen for 2.0 seconds.
- **Constraints**:
  - The powder patch does not damage, slow, or tag opponents.
  - Only one active powder patch can exist on the court at any time.

---

## Implementation status

Design only: no model, clips, or code yet. See [`../status.md`](../status.md).

# RESBAK — Agawan Base Design Specification (Canonical)

> Canonical game design document for RESBAK. Defines the 5 character archetypes,
> active skills, passives, and Agawan Base rules summary.
> Detail dossiers: `docs/characters/01–05_*.md`. Rules engine spec:
> `docs/gameplay/agawan_base_rules.md`. Index: `docs/README.md`.
> (Migrated 2026-10-14 from `AGAWAN BASE IDEA.md`: renamed to a
> space-free lowercase-consistent path, removed 3.8 MB embedded base64 image,
> normalized `\!` escapes to `!`, unified `—` section headers.)

## JM — Protection

*Secondary specialty: Disruption*

### **Skill 1 — TALBOG!**

* Botsog jumps and slams into the ground, pushing nearby enemies outward. The impact creates a temporary crescent-shaped earth wall facing his chosen direction.

* The wall provides cover for teammates, but enemies can go around its open sides. A landing marker warns opponents before impact.

### **Skill 2 — TAMARAW!!!**

* Botsog charges forward, surrounded by a tamaraw-shaped aura. Steering is heavy, and opponents struck are pushed aside.

* The charge ends when he hits a map wall or reaches its maximum duration. A wall collision creates a small shockwave that briefly slows nearby enemies, followed by a recovery animation that leaves Botsog vulnerable.

* Botsog cannot tag during the charge. The skill creates space rather than automatically capturing opponents.

### **Passive — MAKAPAL!**

* The first valid enemy tag breaks Botsog's guard instead of jailing him. A second valid tag captures him.

* After his guard breaks, Botsog briefly cannot tag. His guard only returns after spending a short uninterrupted time at his deployed base. A visible indicator shows whether the guard is ready.

* Carrying the flag disables this protection: a valid tag on the carrier still scores immediately.

---

## NENE — Deception

*Secondary specialty: Rescue*

### **Skill 1 — IYAK!**

* Nene begins a dramatic crying animation, creating a decoy at her position while the real Nene briefly becomes harder to see.

* The decoy continues crying and attracts attention. Nene remains taggable, and using another action ends her concealment.

### **Skill 2 — SUMBONG KITA!**

* Nene places a fake enemy alert at a nearby chosen location, accompanied by running footsteps. The alert can suggest an approaching attacker or rescue attempt, but cannot imitate an actual score or round-ending announcement.

* Observant opponents can spot a visual inconsistency and recognize the trick.

### **Passive — SALING-PUSA**

* After staying out of a chase for a short time, Nene's footsteps become quieter. Being spotted at close range or using a skill ends the effect.

---

## BATANG HAMOG — Movement

*Secondary specialty: Rescue*

### **Skill 1 — HARUROT!**

* A short burst of speed with sharp steering for crossing exposed areas or escaping pursuit.

* A visible wind trail reveals his route. The skill does not grant immunity, so a defender can still intercept him.

### **Skill 2 — LUSOT!**

* Vault over a low obstacle or perform a short slide in the chosen direction.

* He cannot pass through players, solid walls, or map gaps. A short recovery prevents an immediate tag straight out of the move.

### **Passive — DIRE-DIRETSO**

* Running continuously gradually builds a small movement bonus. Stopping, making a sharp reversal, tagging, or taking an enemy skill hit resets it.

* The bonus is disabled while carrying the flag.

---

## NATHAN — Disruption

*Secondary specialty: Deception*

### **Skill 1 — BUGA!**

* Nathan blows a cone of Kimkim powder in front of him.

* Enemies caught in the blast receive a brief movement slow and leave a visible powder trail, making their escape route easier to track. The blast does not tag or cancel a flag capture.

* Nathan pauses briefly to inhale before blowing, giving opponents time to dodge.

### **Skill 2 — UBO! UBO!**

* Nathan throws a Kimkim packet that bursts into a lingering powder cloud.

* Players inside have reduced vision through the cloud. Enemies who remain inside too long cough, briefly revealing their location and interrupting sprinting—but they can still move, tag, and use skills.

* Each enemy can trigger the cough only once per cloud. Both teams have difficulty seeing through it, so careless placement can obstruct Nathan's teammates.

### **Passive — MAY TIRA PA!**

* After using a skill, Nathan's next sharp turn drops a small, visible patch of leftover powder.

* The first enemy to step on it creates a powder puff and a loud footstep cue, revealing their position briefly. The patch does not slow or tag them.

* Only one patch can exist at a time.

---

## INDAY — Rescue

*Secondary specialty: Deception*

### **Skill 1 — IHIP!**

* Inday stands still and continuously blows wind in a chosen direction, creating a visible pathway that boosts her teammates' movement speed.
* **Only allies receive the boost.** Enemies can cross the pathway but gain no benefit.
* The pathway remains active only while she channels. Inday can aim the wind but cannot move, tag, or use another skill.
* She remains vulnerable to tagging. Cancelling the skill or being interrupted immediately removes the pathway.

### **Skill 2 — SAGIP!**

* Inday temporarily extends her rescue-touch range, allowing her to free a prisoner chain from slightly farther away.
* Upon a successful rescue, a decoy of Inday runs toward her chosen direction, creating fake footsteps to mislead jail defenders.
* The decoy cannot tag, rescue, or capture a flag. It disappears when touched by an enemy.

### **Passive — TAKBO NA!**

* After successfully rescuing a prisoner, Inday and the teammates she freed receive a short movement boost.
* This activates once per jailbreak, regardless of how many prisoners are freed.

* The boost does not stack with IHIP! and does not grant tag immunity.

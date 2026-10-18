# Agawan Base — Rules & Game Systems Specification

## 1. Game Concept & Objective
**Agawan Base** (*Base Stealing*) is an ancient, beloved Philippine street game played by children on neighborhood streets, basketball courts, and open fields. 

In **RESBAK**, two opposing teams (e.g., Team Barangay vs. Team Kabataan) face off on a stylized covered court. Each team defends their home base while sending runners to tag enemies, rescue captured allies, and touch the opponent's base to secure victory.

---

## 2. Spatial Layout & Arena Zones

The arena (e.g., `scenes/barangay_court.tscn`) is split into distinct gameplay zones:

```
+----------------------------------------------------------------------------------+
|                              TEAM A SIDE OF COURT                                |
|  [TEAM A BASE]             [TEAM A JAIL]                                         |
|  (Home Spawn & Safe Zone)  (Where tagged Team B players are held)               |
+----------------------------------------------------------------------------------+
|                                                                                  |
|                             NEUTRAL CONTESTED COURT                              |
|          (Open arena, bleachers, center line, props, and cover obstacles)        |
|                                                                                  |
+----------------------------------------------------------------------------------+
|                              TEAM B SIDE OF COURT                                |
|                            [TEAM B JAIL]              [TEAM B BASE]              |
|          (Where tagged Team A players are held)       (Home Spawn & Safe Zone)   |
+----------------------------------------------------------------------------------+
```

1. **Home Base (*Base*)**:
   - Stepping on your home base makes you completely safe from tags.
   - Stepping on your base refreshes your **Base Freshness Timestamp** (`last_base_touch_time = current_game_time`).
   - For JM (Botsog), standing uninterrupted at base recharges his **Makapal!** guard shield.

2. **Jail (*Kulungan*)**:
   - Positioned on the enemy's side near their base.
   - When a player is tagged in neutral or enemy territory, they are escorted to the enemy's jail.
   - Jailed players cannot tag opponents, use skills, or capture bases until rescued.

3. **Neutral Contested Arena**:
   - The central area containing obstacles, court markings, concrete planters, and chairs.
   - All players in this zone are vulnerable to tags based on the freshness hierarchy.

---

## 3. The Base Freshness Priority Engine (*Bago sa Base*)

The fundamental rule of Agawan Base is that tag authority is **temporal**:
- A player who left their base **more recently** has tag priority over a player who left earlier.
- In Tagalog, this is known as *"Mas bagong luto"* (fresher from the base).

### Mathematical Definition
Let $T_A$ be the timestamp when Player A stepped off their team base.
Let $T_B$ be the timestamp when Player B stepped off their team base.

When Player A and Player B collide:
$$\text{If } T_A > T_B: \quad \text{Player A tags Player B (Player B is Jailed)}$$
$$\text{If } T_B > T_A: \quad \text{Player B tags Player A (Player A is Jailed)}$$
$$\text{If } |T_A - T_B| \le \epsilon: \quad \text{Mutual recoil bounce / No tag occurs}$$

### Tactical Consequences
- Players must constantly decide whether to push forward deep into enemy territory or retreat to touch their base to refresh their tag authority.
- Baiting is a key strategy: older players pretend to be vulnerable to lure enemies forward, while a fresh teammate steps off base to intercept the chaser.

---

## 4. The Jailbreak System (*Kuryente & Sagip*)

Imprisonment is never permanent; rescue operations are the emotional heart of every Agawan Base match:

1. **The Prisoner Chain (*Kuryente*)**:
   - Jailed players can link hands to form an electrical wire (*Kuryente*), extending their reach out from the jail pad toward the court center.
   - Rule of Connection: At least one player in the chain must have one foot inside the jail zone. Every other prisoner in the chain must touch a linked ally.

2. **The Rescue Touch (*Sagip*)**:
   - Any unjailed teammate who manages to touch any linked prisoner in the chain triggers a **Jailbreak**.
   - Inday's skill **Sagip!** extends this rescue-touch range and spawns a runner decoy to distract guards.

3. **Post-Jailbreak Grace Period**:
   - Upon being rescued, all freed players gain a brief 2.0-second immunity window where they cannot be re-tagged, allowing them to scramble back across the center line.
   - Inday's passive **Takbo Na!** grants an additional burst of speed to all freed teammates.

---

## 5. Base Snatching & Victory Conditions (*Agawan*)

A round is won through one of three conditions:

1. **Direct Base Touch (*Dikit Base*)**:
   - An invading player touches the opponent's base pad while avoiding tags.
   - If the opponent base is unguarded, a single touch claims the base and awards the round.

2. **Total Team Capture (*Huli Lahat*)**:
   - All opposing team members are simultaneously held in jail.
   - If no enemy remains unjailed to attempt a rescue, the round ends in total capture victory.

3. **Time-Out Score Determination**:
   - If the round timer expires (e.g., 3 minutes), the team with fewer jailed members and more successful base approaches wins the round.

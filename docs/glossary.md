# Glossary: Filipino terms → game concepts → code

| Term | Meaning | Game concept | Code identifier (if any) |
| ---- | ------- | ------------ | ------------------------ |
| **Agawan Base** | "stealing bases" | The traditional game RESBAK adapts | — |
| **Resbak** | slang: backup / retaliation | Title; also the rescue theme | — |
| **Barangay** | village / district | Setting: the open-air Barangay Court | `scenes/barangay_court.tscn` |
| **Unahan** | "whoever is first" | Tag rule: anyone away from their base can be tagged; the first clean tag wins (replaces the old Bago sa Base freshness rule) | `TagSystem.can_tag()` |
| **Sabay** | "at the same time" | Two enemies tag each other on the same tick: both stumble, nobody is jailed | — |
| **Base** | home pad | Pole in a 2 m ring; a barrier keeps the base's own team out, enemies capture it | `BaseSites/{Yellow,Purple}_Site_N` |
| **Kulungan** | jail / cage | Where tagged players are held | `JailZones/{Yellow,Purple}Jail` |
| **Kuryente** | "electricity" | Prisoner chain: jailed players linking hands outward | — |
| **Sagip** | rescue | Touching the tip of the chain frees the whole chain; also Inday's skill 2 | — |
| **Dikit Base** | "stick to base" | Win: capture the enemy base (hold Interact 1.5 s at the pole) | — |
| **Huli Lahat** | "all caught" | Win: every opponent jailed at once | — |
| **Harurot** | to rev / zoom off | Tutoy skill 1 (prototyped on Batang Hamog), a steerable speed burst | `try_harurot`, `State.HARUROT`, clip `Harurot` |
| **Lusot** | to slip through | Tutoy skill 2 (prototyped on Batang Hamog), a slide or low vault | `try_lusot`, `State.LUSOT_*`, clips `Lusot_Slide` / `Lusot_Vault` |
| **Dire-Diretso** | "straight ahead, nonstop" | Hamog passive, a momentum stack | `DireDiretsoComponent` |
| **Batang Hamog** | street kid (lit. "child of the dew") | Movement-class character | `BatangHamogController` |
| **Botsog** | chubby | JM's nickname, Protection class | `jm_botsog.glb` |
| **Talbog** | bounce | JM skill 1, ground slam + crescent wall | — |
| **Tamaraw** | Mindoro dwarf buffalo | JM skill 2, a charge | — |
| **Makapal** | thick | JM passive, a one-tag guard | — |
| **Iyak** | cry | Nene skill 1, a crying decoy + camouflage | — |
| **Sumbong Kita** | "I'll tell on you" | Nene skill 2, a fake alert | — |
| **Saling-pusa** | a kid allowed to play "as a cat" (doesn't count) | Nene passive, silent footsteps | — |
| **Buga** | to blow out | Nathan skill 1, a powder cone slow | — |
| **Ubo** | cough | Nathan skill 2, a vision-restricting cloud | — |
| **May Tira Pa** | "there's some left" | Nathan passive, a leftover patch | — |
| **Kimkim** | invented brand: a parody of the real powdered-milk candy sold in straw packets | Nathan's powder candy, the source of his Buga, Ubo and May Tira Pa powder | planned `kimkim_packet.glb` |
| **Ihip** | blow (wind) | Inday skill 1, an ally speed tunnel | — |
| **Takbo Na** | "run now!" | Inday passive, a post-jailbreak surge | — |
| **Sari-sari store / tricycle / monobloc** | corner shop / motor-sidecar taxi / plastic chair | Environment props | `assets/props/*` |

| **Takipsilim** | sunset | Sudden death after a tied timer (30 s, untimed after 2 draws) | `RoundFlow.Phase.SUDDEN_DEATH` |
| **Tabla** | draw | A round with no winner (replayed, no point) | `RoundFlow` (`winner = -1`) |
| **Bantay / Atake / Pain / Resbak / Kapit** | guard / attack / bait / rescue / hold on | Bot roles (spec § 11) | `BotCoord.Role` |
| **Kimkim** | invented candy brand | Nathan's powder packet | `scripts/match/skills/nathan/` |

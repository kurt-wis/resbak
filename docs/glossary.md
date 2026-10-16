# Glossary: Filipino terms → game concepts → code

| Term | Meaning | Game concept | Code identifier (if any) |
| ---- | ------- | ------------ | ------------------------ |
| **Agawan Base** | "stealing bases" | The traditional game RESBAK adapts | — |
| **Resbak** | slang: backup / retaliation | Title; also the rescue theme | — |
| **Barangay** | village / district | Setting: the open-air Barangay Court | `scenes/barangay_court.tscn` |
| **Unahan** | "whoever is first" | Tag rule: anyone away from their base can be tagged; the first clean tag wins (replaces the old Bago sa Base freshness rule) | `TagSystem.can_tag()` |
| **Sabay** | "at the same time" | Two enemies tag each other on the same tick: both stumble, nobody is jailed | — |
| **Base** | home pad | Pole in a 2 m ring; a barrier keeps the base's own team out, enemies capture it | `BaseSites/{Yellow,Purple}_Site_N` |
| **Kulungan** | jail / cage | Where tagged players are held; v0.2 a line at the map's end with a sliding post | `JailLine_<team>`, `JailSystem.post()` |
| **Unang Huli / Dobleng / Tripleng Huli** | first / double / triple catch | Announcer calls (first tag, multi-tags) | `HudAnnouncer` |
| **Mainit / Halimaw / Di Mapigilan / Pinahinto** | hot / monster / unstoppable / stopped | Announcer streak calls (3 / 5 / 7 tags without being caught) and the shutdown | `HudAnnouncer` |
| **Naagaw ang Base / Lahat Huli** | the base was taken / all caught | Announcer calls for a capture and a lockdown win | `HudAnnouncer` |
| **Kuryente** | "electricity" | Prisoner chain: jailed players linking hands outward | — |
| **Sagip** | rescue | Touching the tip of the chain frees the whole chain (Inday's old skill 2, replaced by HILA! in v0.2) | — |
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
| **Sigaw** | shout | Nene skill 1 (v0.2), a word projectile: stuns an enemy, dashes a teammate | `skills/nene/sigaw.gd`, `SigawWord` |
| **Bawal** | forbidden / not allowed | Nene skill 2 (v0.2), a "don't hit me" sign; tagging her makes the tagger hallucinate | `skills/nene/bawal.gd`, `Hero.hallucinate` |
| **Nahihilo** | dizzy | The BAWAL! curse: reversed stick and a warped screen | `HudHallucinate` |
| **Hila** | pull | Inday skill 2 (v0.2), a stretched hand that pulls teammates and rescues a chain tip | `skills/inday/hila.gd`, `HilaHand` |
| **Iyak / Sumbong Kita** | cry / "I'll tell on you" | Nene's old spec skills (replaced in v0.2) | — |
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

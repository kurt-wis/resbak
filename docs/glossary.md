# Glossary: Filipino terms → game concepts → code

| Term | Meaning | Game concept | Code identifier (if any) |
| ---- | ------- | ------------ | ------------------------ |
| **Agawan Base** | "stealing bases" | The traditional game RESBAK adapts | — |
| **Resbak** | slang: backup / retaliation | Title; also the rescue theme | — |
| **Barangay** | village / district | Setting: the barangay covered court | `scenes/barangay_court.tscn` |
| **Bago sa Base** | "fresh from base" | Freshness hierarchy: whoever touched their own base most recently can tag older opponents | planned `last_base_touch_time` |
| **Base** | home pad | Safe zone; touching it refreshes freshness | `BaseSites/{Yellow,Purple}_Site_N` |
| **Kulungan** | jail / cage | Where tagged players are held | `JailZones/{Yellow,Purple}Jail` |
| **Kuryente** | "electricity" | Prisoner chain: jailed players linking hands outward | — |
| **Sagip** | rescue | Touching any chain member frees the whole chain (jailbreak); also Inday's skill 2 | — |
| **Dikit Base** | "stick to base" | Win: touch the enemy's unguarded base | — |
| **Huli Lahat** | "all caught" | Win: every opponent jailed at once | — |
| **Harurot** | to rev / zoom off | Batang Hamog skill 1, a steerable speed burst | `try_harurot`, `State.HARUROT`, clip `Harurot` |
| **Lusot** | to slip through | Batang Hamog skill 2, a slide or low vault | `try_lusot`, `State.LUSOT_*`, clips `Lusot_Slide` / `Lusot_Vault` |
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
| **Ihip** | blow (wind) | Inday skill 1, an ally speed tunnel | — |
| **Takbo Na** | "run now!" | Inday passive, a post-jailbreak surge | — |
| **Sari-sari store / tricycle / monobloc** | corner shop / motor-sidecar taxi / plastic chair | Environment props | `assets/props/*` |

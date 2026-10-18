# RESBAK! Agawan Base: concise spec

- Game: 5v5 round-based tag game from the Filipino street game Agawan Base; capture the enemy base or jail all opponents; Purok Dilaw (yellow) vs Purok Lila (purple).
- Engine: Godot 4.7.2 Mono, GDScript only, GL Compatibility, Jolt Physics; Windows x86_64.
- Entry scope: DOST LEVEL UP 3.0 entry due 25 Oct 2026, LAN plus bots; build only the "Competition entry" column of the scope table.
- Source: condensed spec of the team's full GDD (final draft 8, a long PDF kept outside the repo).
- If this file and the code disagree, ask; do not guess.

## 1. Overview and scope
- Camera: top-down three-quarter, hero centred, never rotates; 55 deg down pitch, 22 m from hero, 40 deg vertical FOV; long axis left-right, Dilaw side left for everyone.
- Match: best of 5, first to 3 points; draws (Tabla) not counted in the 5.
- Numbers are starting values: named constants in tuning.tres or HeroData .tres, never hard-coded. Player distances centre to centre unless stated. 1 unit = 1 m, Y up.
- EP = Escape Protection, CD = cooldown, S1/S2 = Skill 1/2.
- Feature freeze end of 22 Oct 2026; submit 25 Oct 2026; no engine change before 27 Nov.

### What ships when
Sole scope authority. Finals/Later items: no spec beyond stubs.

|Area|Competition entry|Finals|Later|
|---|---|---|---|
|Core rules|Unahan tag rule with Sabay, tagging, base barrier, body blocking, capture, jail, chain, rescue, Escape Protection, capture lockout, lockdown, sunset tiebreak, sudden death, draws, match scoring|Balancing||
|Heroes|All 5 with both skills and their passive, snake draft|More voice lines|10 heroes, draft bans|
|Maps|Barangay Court, Plaza and Tambakan with Taguan zones, terrain and high ground. Map roulette and base roulette.|Art polish and balancing|More maps|
|Hazards|Baha, market shutters and garbage truck, with the Hazards room setting. First to cut. If cut, hide the Hazards setting.|Any hazard cut from the entry|New hazards with new maps|
|Modes|vs Bots with 3 difficulties and pause, Custom Room on LAN (browser, IP, room code, PIN), Tradisyonal preset, tutorial lessons 1 to 5|Tutorial lessons 6 and 7 and the tutorial reward, Bakuran, tournament mode|Classic, Ranked, online wait in the Kanto|
|Front end|Boot splash, title, first-time setup, Home with unshipped buttons greyed, Play menu, Custom Room screens, Kanto lobby, draft with skill tips, loading, intro cinematic, countdown, results steps 1 to 3, Settings, Credits, 5 Alam Mo Ba? pages|Preparation phase, Paano laruin pages, Locker, Profile, Challenges, results steps 4 and 5|Barkada, matchmaking screens, News tile, more Alam Mo Ba? pages|
|Match interface|Full HUD, jail screen, key event feedback, smart ping, ping wheel, Escape overlay, between-rounds sequence, first-5-matches hints|Banter wheel, Nemesis marker and sound|Text chat, I-REPORT, block|
|Network and bots|LAN listen server, bots, bot takeover for disconnected and idle players, rejoin||Online play, dedicated servers|
|Progression|Results with MVP, badges and scoreboard. Profile totals saved locally.|Tansan from matches and challenges, Saludo, Locker with one extra skin per hero and three tag flares|Levels, hero mastery, all other cosmetics, seasons and tiers|
|Settings and accessibility|Every Settings tab (online-only rows greyed), all colour modes, subtitles, keyboard, mouse and gamepad with rebinding, tag assist|||
|Audio|Music, effects, hero voice lines, Kuya Tanod barks and announcer calls|Full tutorial narration||
|Recording and spectating|Clean camera with no interface|Spectator slots and spectator view (free camera, caster overlay, director camera, delay)|Replays|


### Code originality
- Write tagging, jail, chain and netcode yourselves; no core-mechanic code from open-source, tutorials or templates. Godot built-ins (high-level multiplayer API) are fine.
- Personal libraries only if team-written and never in a published/submitted game; declare them.
- Log every external asset/library and AI-assisted code/art for Form 03.

## 2. Core rules

### Tagging (Unahan: first clean tag wins)
- can_tag(tagger, target, tick): both Free, different teams, target not under EP. Sole decider, checked on landing tick. Anywhere, any time from KABOOM; bases irrelevant.
- Tag press: 0.15 s (9 ticks) wind-up while moving; lunge dir = aim at press (after tag assist).
- Landing: candidates = enemies and Nene decoys/fakes with body within reach (1.2 m, Tutoy 1.0 m, edge to edge) and within 45 deg either side of lunge. Nearest taggable enemy is tagged (to tagger's jail). Else (nothing, only decoy/fake, only untaggable) failed tag: stumble 0.5 s.
- No other tag CD (press again next tick). Tags never score. Host decides; no LAN lag compensation.
- Sabay: two enemies land valid tags on each other same tick: both stumble, nobody jailed; other tags apply.
- JM guard break = successful tag for sudden death, Impact, badges.
- Outlines: taggable enemy orange + exclamation icon; untaggable (Tagged, Jailed, Chained, EP) grey, no icon, EP adds shield icon. No fog of war; only Taguan zones and powder cloud hide.

### Bodies and states
- Bodies: circle r 0.4 m. Free players collide (blocking allowed); Tagged, Jailed, Chained, EP don't. Height gap > 1 m: no collision, tag, rescue.
- Push: straight over 0.2 s, stops at walls and jail barriers, no steering. Pushes and slows ignore chained, affect EP. Slows: strongest only (skill, terrain, hazard).

### Bases and capture
- 3 sites per side; after map roulette one site number is picked once per match (roulette or Fixed), mirrored; others inert. No flag.
- Active base: solid pole r 0.2 m, ring r 2 m (inside = centre ≤ 2 m from pole centre), team colour. Own-ring barrier blocks only own team (≥ 2.4 m from own pole, centre to centre); enemies pass; pushes toward own base stop at it. Spawns outside every ring.
- Capture: hold Interact, body-to-enemy-pole gap ≤ 1 m, 1.5 s (90 ticks): round ends, +1. Capturing: no move, tag, skills; pushable; defenders don't slow it.
- Cancel, progress 0: tagged, Interact released, pushed to gap > 1 m. Toggle input: tap start, tap stop. Several attackers: separate progress, no summing.

### Jail and chain
- Tagged: frozen 0.8 s, then random free spot in tagger's jail (own side, behind its sites; Jail_Dilaw holds Lila), Jailed. Jail barrier blocks all free players; only chained prisoners cross; exit only by rescue or reset.
- Jailed: move at normal speed, chain, ping; no tag, capture, skills.
- Marker: middle of jail side facing prisoners' home. Hand point: 1.5 m outside barrier, straight out from marker.
- Within 1 m of marker + Interact: anchor (one, immobile). Within 1.5 m of anchor or tip + Interact: moved to old tip position, becomes tip.
- Only tip steered (normal speed), within 1.5 m of hand point per link after anchor; other links spaced evenly on hand point to tip line. Max 4 chained, 6 m reach (5 jailed = lockdown).
- Chained: pass jail barrier, not walls/solid objects; can't be tagged, tag, capture, use skills.
- Interact again = let go: that prisoner and all beyond return to random jail spots, must rejoin; anchor letting go returns all. Lone anchor is the tip; rescue point = hand point.

### Rescue and EP
- Free teammate (EP ok) touches tip: centres ≤ 0.8 m; lone anchor: rescuer centre ≤ 0.4 m from hand point. No button, same tick.
- Frees whole chain; unchained stay. Freed keep positions; any inside jail moved to nearest point outside barrier. Works in sudden death but doesn't win it.
- EP 4 s (5 s if Inday rescued): untaggable, passes through players; ends early on Tag press, Offensive or Movement skill, capture start.
- Capture lockout 4 s (also after Inday). Both start on rescue tick.

### Round end and match
- Capture: capturers +1. Lockdown (all of a team's players Tagged/Jailed/Chained at once; bot filling Off: all it has): other team +1.
- Same-tick rescue beats lockdown. Both teams meet an end condition same tick: draw.
- Round-end tick: all play stops; unfinished capture, wind-up, active skill cancelled, give nothing.
- Timer starts at KABOOM. At 0: fewer Tagged/Jailed/Chained wins (+1). Equal: sudden death (Takipsilim) from next tick, 30 s, no reset, captures keep progress; first successful tag (guard break counts) or capture wins (+1). Neither: draw, no point, replay after reset. After 2 draws in a match, later sudden deaths untimed.
- First to Points to win. No side swap, no surrender.
- Reset: free prisoners, clear chains, reset CDs, restore JM guard; end all skill effects, slows, pushes, stuns, stumbles, EP, lockouts, capture progress, passive bonuses; restart hazard schedules. Spawns hold up to 3: slots 1 to 3 spawn 1, slots 4 and 5 spawn 2. Bases stay.
- States: Free (EP is a timer on Free); Tagged (0.8 s, can't act, untaggable, no collision); Jailed (unchained); Chained. Last three count as jailed. Timers in ticks (s x 60, rounded).
- Stumble and stun (perfect slide, TAMARAW!!! wall hit): no move, tag, skill, capture start; no stacking, longer remaining applies.
- Same-tick order: section 12 tick order only.

## 3. Numbers at a glance
|Value|Starting number|
|---|---|
|Host tick rate|60 ticks/s|
|Running speed|5.0 m/s (JM 4.6, Tutoy 5.4); always runs when moving; no sprint, no stamina|
|Walking speed|Half running speed; gamepad only, stick tilt 15 to 50%|
|Gamepad stick dead zone|15% of full tilt|
|Hero body radius|0.4 m|
|Tag reach|1.2 m (Tutoy 1.0), edge to edge|
|Tag arc|45 deg either side of lunge|
|Tag wind-up|0.15 s|
|Tagged freeze|0.8 s|
|Sabay|Two tags landing on same host tick (1/60 s)|
|Danger border range|10 m|
|Failed tag stumble|0.5 s|
|Base ring radius|2 m to player centre; barrier keeps own team ≥ 2.4 m from own pole|
|Base barrier|Blocks only own team; enemies pass|
|Capture range|1 m gap, attacker body to pole|
|Capture hold time|1.5 s|
|Chain link distance|1.5 m; anchor reaches 1.5 m through barrier|
|Chain tip reach|1.5 m outside barrier per chained prisoner, 6 m max|
|Rescue touch|Centres ≤ 0.8 m|
|Escape Protection|4 s, or 5 if rescued by Inday|
|Capture lockout after rescue|4 s, also after Inday rescue|
|Round timer|2 min (Custom Room: 1 to 3)|
|Sudden death|30 s, no limit after 2 draws in a match|
|Points to win|3 (Custom Room: 1 to 5)|
|Footstep hearing range|15 m, running footsteps|

## 4. Characters

### Roster rules
- Speed only via skills, passives, terrain, hazards: `current = base * (1 + biggest bonus) * (1 - strongest slow)`; bonuses don't stack, slows don't stack. HARUROT! and TAMARAW!!! fix 9 m/s: no bonus, slows apply.
- No skills in countdown, Tagged/Jailed/Chained, capturing, stumble, stun. CD starts on cast. Aim past range: max range.
- On tag, ongoing TAMARAW!!!, HARUROT!, IYAK! see-through, IHIP!, SAGIP! end; placed TALBOG! wall, IYAK! decoy, SUMBONG KITA! fake, clouds, patches last full time.
- Skills Off (Tradisyonal): actives off; passives, speed, reach stay.

|Hero|Role / secondary|Speed|Reach|S1 CD|S2 CD|
|---|---|---|---|---|---|
|JM "Botsog"|Protection / Disruption|4.6 m/s|1.2 m|12 s|16 s|
|Nene|Deception / Rescue|5.0 m/s|1.2 m|14 s|10 s|
|Tutoy|Movement / Rescue|5.4 m/s|1.0 m|8 s|6 s|
|Nathan|Disruption / Deception|5.0 m/s|1.2 m|10 s|18 s|
|Inday|Rescue / Movement|5.0 m/s|1.2 m|15 s|12 s|

- Types: Offensive TALBOG!, TAMARAW!!!, BUGA!, UBO! UBO!; Movement HARUROT!, LUSOT!, IHIP!; Neither IYAK!, SUMBONG KITA!, SAGIP!.

### JM "Botsog"
- S1 TALBOG!: jump to point ≤ 6 m, airborne 0.6 s, landing marker; can't steer, tag, be pushed; taggable; lands just before a blocking wall/jail barrier. Impact: enemies with centre within 2.5 m pushed 3 m away from landing point; crescent earth wall 5 m wide centre 1.5 m in front of landing point along aim, 1.5 m tall, curving around JM; solid for all, 4 s, open ends passable; overlapped players moved to nearer side.
- S2 TAMARAW!!!: charge along aim 9 m/s up to 1.5 s, max turn 90 deg/s; S2 again ends; can't tag. Enemies touched pushed 2 m sideways off path, once each; allies unaffected, don't block. Wall/solid hit: ends, enemies within 2.5 m slowed 40% 1 s, JM stunned 0.8 s.
- Passive MAKAPAL!: first successful tag breaks guard instead of jailing (no tagger stumble, no JM freeze); next jails. After break: can't tag 1.5 s; guard back 15 s after break; if jailed then, back when freed. Shield icon shows state to all. Tagged while capturing: jailed even with guard. Guard state kept in jail.

### Nene
- S1 IYAK!: crying decoy left in place; Nene see-through 3 s (enemies see 25% opacity; outline, minimap marker stay). Decoy: still, cries 5 s, Nene's outline, no collision, on enemy minimap as Nene; tagging it = failed tag, it stays. See-through ends early on Tag press, skill, capture start, rescue.
- S2 SUMBONG KITA!: fake alert at point ≤ 12 m: 3 s footstep icon + running sound for enemies; fakes only attacker or rescuer, never score or announcement. Point within 8 m of jail holding Nene's teammates: instead fake Nene rescuer runs from point toward chain tip (no chain: marker) at 5.0 m/s for 3 s, vanishes; no collision, rescue or shadow; tagging it = failed tag.
- Passive SALING-PUSA: after 4 continuous s with no free enemy within 8 m, footsteps silent (no sound or on-screen cue). Ends when free enemy within 4 m or she uses a skill; can restart after another 4 s.

### Tutoy
- S1 HARUROT!: 9 m/s for 1.2 s, no turn limit; wind trail visible to all, each part 2 s; can tag and be tagged.
- S2 LUSOT!: slide 4 m over 0.4 s along movement (aim if still); vaults objects marked vaultable. Normal slide stops at players, walls, map edges; no tagging 0.3 s after.
  - Perfect vs an enemy: their tag would have hit Tutoy at slide start, and slide starts in last 6 ticks (0.1 s) of its wind-up, incl. landing tick (host compares LUSOT! tick with tag landing tick). Passes through, tag misses, each such enemy stunned 0.6 s instead of 0.5 s stumble; stun is not a tag. Gold flash, LUSOT! shout, PERFECT! to both.
  - Otherwise normal slide; tag checked against new position.
- Passive DIRE-DIRETSO: moving without sharp turn (> 45 deg within 0.5 s), bonus rises evenly 0 to 15% over 3 s, holds. Resets on stop, sharp turn, Tag press, capture start, push/slow/stun by enemy skill. Terrain and hazard slows (mud, flood) don't reset it.

### Nathan
- Candy brand Kimkim (invented); never use a real brand anywhere.
- S1 BUGA!: inhale 0.4 s (can move; enemies see, hear), then powder cone 5 m long, 60 deg wide along aim; walls block. Hit: slowed 30% 1.5 s; powder trail (visible to all) 4 s, while Nathan's team sees them everywhere (hiding spots, clouds, minimap). No tag, no capture cancel.
- S2 UBO! UBO!: packet ≤ 9 m, lands 0.5 s later or at first wall; cloud r 3.5 m, 5 s. Outside players can't see anyone whose centre is inside (screen, minimap); inside players see only within 2 m; both teams incl. Nathan. Enemy inside > 1 continuous s coughs once per cloud: shown to Nathan's team on minimap and through cloud 2 s; can still act.
- Passive MAY TIRA PA!: after a skill, next movement turn > 90 deg within 0.5 s drops powder patch r 1 m (visible to all). First enemy centre entering: puff + loud footstep, shown to Nathan's team on minimap and through hiding spots 2 s; patch gone. No slow, no tag. One patch; new replaces old; lasts until triggered or round end.

### Inday
- S1 IHIP!: stands still blowing along aim up to 4 s: lane 10 m long, 3 m wide from Inday, turns with aim, walls cut it. Free allies inside +25% speed; enemies nothing. Can aim; can't move, tag, other skill; taggable. Ends on S1 again, tagged, pushed, stunned; lane gone same tick.
- S2 SAGIP!: 4 s; rescues when her centre ≤ 3 m from tip (or lone anchor's hand point), no button. Line must be clear: walls, solid objects, TALBOG! wall block; players, clouds don't.
- Passive TAKBO NA!: after any Inday rescue, she and every teammate she freed +20% speed 2 s, once per rescue; biggest bonus applies (no stack with IHIP!). Her freed prisoners get +1 s EP (5 s).

## 5. Maps

### All maps
- 56 x 32 m (length crossing 11.2 s at 5.0 m/s). Mirrored across centre line splitting the 56 m; only decoration differs.
- Per side: 3 base sites, 1 jail behind them, 2 spawns between sites and jail, outside every ring. Jail interior 6 m wide x 4 m deep, marker mid side facing prisoners' home.
- Each map: central clash zone, cover lane, flank route; high ground per side (camera zooms out 15%).
- One signature hazard; mud and speed strips are terrain (always on). Hazards setting toggles hazards only; unbuilt hazard: none.
- Sites numbered 1 to 3 as listed below (Tradisyonal = site 1). Decorative props never collide, block sight or hide.
- Taguan zones (marked areas: tarps, stalls, laundry lines, trash piles): centre inside = hidden from enemies on screen and minimap; revealed while any enemy within 2.5 m and 2 s after Tag press or skill. Footsteps audible. Allies always see each other.

### Barangay Court (showcase)
- Cover lane bleachers + stage (top edge); flank alley (bottom edge); high ground stage + mirror platform; no terrain. Sites: 1 free-throw line, 2 bleachers, 3 alley mouth.
- Hazard Baha: at 60 s remaining (at KABOOM if timer 1 min), yellow rainfall warning banner 10 s, then whole alley flank floods until round end, incl. sudden death. Water slows 35%, silences footsteps. No real agency name or logo.

### Plaza
- Cover lane bazaar; flank market street; vaultable benches, flower boxes; high ground stairs each side, overpass over middle walkable from both sides. Sites: 1 fountain edge, 2 bazaar arcade, 3 market stalls.
- Terrain, speed strips: crossing a pedestrian crossing moving within 45 deg of straight toward enemy side: +20% speed 1.5 s; recrossing restarts it.
- Hazard, market shutters: both sides close every 30 s after KABOOM (0:30, 1:00, 1:30 ..., incl. sudden death) for 10 s, cutting main path to jail; rattle 2 s before. Closed = walls; players under one pushed to nearer side.

### Tambakan
- A junkyard. Never use a real place name (no Payatas).
- Jeepney body blocks the line between bases; cover lane trash maze; flank truck road; high ground mounds. Sites: 1 maze exit, 2 beside mound, 3 truck road.
- Terrain, mud: dry waterway 4 m wide, full 56 m, through middle of each side; slows 15%.
- Hazard Trak ng Basura: twice per round along whole truck road, at 1/3 and 2/3 of round timer (40 s and 80 s after KABOOM in 2 min); horn 3 s before; 4 s to pass; alternates direction. Solid moving wall, pushes anyone in path to nearer roadside. No tag. Not in sudden death.

### Nodes
- Scenes barangay_court, plaza, tambakan, each with BaseSite_Dilaw_1 to 3, BaseSite_Lila_1 to 3, Jail_Dilaw, Jail_Lila, JailMarker_Dilaw, JailMarker_Lila, Spawn_Dilaw_1 and 2, Spawn_Lila_1 and 2, TaguanZone areas, HighGround areas, terrain areas, one Hazard node. Same site number = mirrors.

## 6. Match flow

### Front end
- Boot: logo 2 s, Godot credit 1 s, note 1 s, skippable. Title: live court, logo, shout, prompt, version, Settings, Quit; then setup (first launch) or Home.
- Setup (until step 4 done; Skip keeps default; back = previous): Wika [Filipino with English labels]; Pangalan (3 to 16 chars after trim, letters incl. Ñ ñ, digits, spaces; local Filipino+English blocklist, case-insensitive; dice from ≥ 20 names; Skip = dice); readability (orange vs grey outline, cycle colour modes, Default first); Kontrol (last-used device). Never prompts tutorial.
- Navigation: mouse, keys, pad; Escape/B/Circle back (Home: quit dialog; roulette to results: overlay); main action preselected, dialogs Hindi; chalk wipe 0.3 s. Filipino labels, smaller English under (≥ 18 px at 1080p).
- Home: bench hero (saved, JM first launch, pick from 5), player card (name + bench portrait), Settings, LARO (preselected), ENSAYO, LUMABAS. Greyed "Malapit na", inert: BARKADA, LOCKER, GAWAIN, Gawain bell, Profile link, Tansan counter, News tile, Bakuran, Classic, Ranked.
- Practice: Tutorial, Alam Mo Ba? (5 pages). Play cards: 5 s clip + summary on hover.

### Roulette and draft
- Map wheel 4 s + Kuya Tanod map line; overhead view, sites flicker 2 s, lock; draft 1 s later. No repeat of previous match's map in same room or vs Bots session (last_map). Chosen map skips wheel, Fixed skips base roulette; each shows choice 2 s. vs Bots: player makes host choices.
- Draft UI: own slots left, enemy right, grid centre, skills/passive/tips/6 s clip bottom, map top right.
- Snake (A = first pick): A1, B1, B2, A2, A3, B3, B4, A4, A5, B5; pick n = panel slot n (vs Bots player = slot 1); missing players skipped. vs Bots: player Dilaw, Dilaw first. Custom Room: first pick alternates per match, Dilaw first.
- 12 s per pick, double turn sequential (≤ 24 s); confirm locks, next starts. Timeout: hovered, else random available. Bots lock random 2 s in. Pre-turn hover visible to team. No duplicate within team; enemy picks allowed. Leaver: bot. No Preparation phase.

### Loading, intro, countdown
- Loading: posed lineups, progress bars; > 30 s = disconnected, bot plays until loaded. Tip every 5 s, alternating gameplay tip and Alam Mo Ba? fact.
- Intro 8 s, first round only: arena 2 s; team reveal 2.5 s each, Dilaw first, with team call; face-off 1 s. Unskippable with > 1 human; vs Bots: Interact skips (prompt bottom right).
- Countdown 3 s frozen (3, 2, 1): aim and ping only. Zero: KABOOM!, confetti, drum hit; round and timer start.

### Between rounds
- Play stops (scoreboard allowed); capture's 0.5 s slow motion first. 1: result banner 2 s, winner colour (draw white). 2: freeze frame 2 s on deciding moment in paused live scene (capturer, last lockdown tag, deciding sudden death tag/capture, or after sunset win the jail with losers' prisoners); draw skips. 3: score update + round best player card 3 s (winning team's top round Impact; tie: more rescues, lower slot); draw skips card. 4: reset, cut, countdown, KABOOM.
- Steps 1 to 3 = 7 s (5 s after draw). After match point, step 3 leads to Results.

### Results (steps 1 to 3)
- Timed steps skippable per player. 1: 4 s PANALO!/TALO! + score. 2: 6 s MVP card per team, then up to 3 badges. 3: scoreboard tabs Impact, Tags, Rescues, Captures, Assists, Saves; LARO ULIT, BUMALIK SA TAMBAYAN.
- LARO ULIT: vs Bots new match, same settings, at map roulette; Custom Room back to lobby, teams kept, Ready cleared. BUMALIK SA TAMBAYAN leaves; host leaving closes room.
- Impact: capture 10; rescue 3 per prisoner freed; tag (incl. guard break) 2; Saved +2 (tag on enemy holding a capture or within 5 m of tip of chain holding their teammates); Assist 1 (your skill slowed, pushed or revealed an enemy in the 3 s before a teammate tagged it, or before a teammate's rescue/capture while it was within 10 m of them; max 1 per teammate action; no body blocks); Clutch +5 (capture or rescue as team's last free player).
- MVP per team = top Impact; tie: more rescues, more captures, lower slot. Winners gold, first; losers silver "Bida ng Talo". Bots eligible. Stats belong to slot.
- Badges in order, max 3: Best Resbak (most freed); Pader (most tags within 10 m of own pole); Pasaway (most captures started); Kidlat (longest chase: unbroken time before the tag with target within 10 m and taggable); Nemesis (enemy pair, mutual tags ≥ 3 total, each ≥ 1). Count ≥ 1; tie: more Impact, else none.

## 7. HUD and feedback

### HUD
- Top centre: sinking-sun timer, scores each side (own left), m:ss below; sudden death: 30 s countdown + TAKIPSILIM banner; untimed: no number. Below: one dot per point to win per team, filled on score.
- Prisoner tracker beside score: 5 portraits per team (own left): colour free, bars jailed, linked hands chained, bot icon if bot-controlled.
- Minimap top right (setting: bottom right): active bases, jails, allies; enemies only within 12 m of an ally and not hidden (Taguan, cloud), or revealed by BUGA!, cough, patch.
- Tag feed left: tags (incl. guard breaks), rescues, captures, both teams; 5 s per line, max 5.
- Bottom centre S1/S2: CD sweep, key label; greyed in countdown; chain controls in jail; hidden in Tradisyonal. Passive icon: JM guard; Nene silent; Tutoy 0 to 15% fill; Nathan patch ready; Inday boost + 2 s timer.
- Danger border: orange while any enemy within 10 m can tag you.
- Off-screen arrows: own base, enemy jail holding a teammate, any capture. Scoreboard (hold): name, hero, tags, rescues, captures, state. F10 hides HUD locally (clean camera).
- Jail screen: Interact prompt only when it would act (hold-on / let-go string, key per device); chain length linked/prisoners (e.g. 2/3); whole metres tip (no chain: marker) to nearest free teammate.

### Feedback
- Border on: low tick. Tag: HULI! stamp, slap, crowd "Ooh!", "Huli!". Guard break: shield crack. Failed tag: whiff. Capture in progress: chalk circle, edge flash, rising megaphone tone, all players. Capture: 0.5 s slow motion, confetti, NAKUHA! stamp, jingle. Rescue: RESBAK! text and shouts. Lockdown: gate slam, LOCKDOWN!, drumroll.
- Sky golden to orange until 30 s left (then faster music); sudden death deep red, whistle, call; timer round end dims, mother's call. Chase music layer fades in/out over 1 s while a taggable enemy is within 10 m.
- Onboarding hint (first 5 completed matches, matches_played): first teammate jailed, 4 s above skills, no pause.

### Pings and overlay
- Team only, jailed allowed. Tap < 0.25 s smart ping, hold = wheel. Max 3 pings in any 5 s, extras ignored.
- Smart: target under cursor; gamepad: first target along aim within 20 m, else ground. Priority enemy, base, jail, ground. World + minimap marker 4 s, text, bark.
- Wheel: mouse/right stick, release sends, centre cancels; shown above hero and by tracker portrait 4 s, bark, no marker. No voice/text chat; banter key inert.
- Escape overlay: vs Bots/tutorial pause (host tick stops); Custom Room runs on without input, idle counts. BUMALIK; Settings (Audio, Controls, Video, Accessibility editable, rest view-only; Capture input applies next capture); UMALIS + quit dialog (vs Bots/tutorial: no result, back to origin menu; Custom Room: disconnect; host: ends match).

## 8. Modes and lobby
- vs Bots (you + 4 bots vs 5 bots): map or [Roulette]; Madali/[Katamtaman]/Mahirap; rest Custom Room defaults; SIMULAN. Offline host, LAN host code.
- Custom Room: 2 to 10 players, bots fill.
- Tradisyonal preset: Skills Off, Hazards Off, Base Fixed site 1; card asks bots or Custom Room, opens that setup preset; host may change.
- Room settings [default]: name 3 to 24 chars, player-name rules ["[Player name]'s room"]. PIN [none]/4 digits. Map any/[Roulette]. Base [Roulette]/Fixed site 1, 2 or 3. Points 1 to 5 [3]. Timer 1 to 3 min, 30 s steps [2 min]. Hazards [On]. Skills [On]. Fill with bots [On] (Off: uneven teams < 5, ≥ 1 each). Bot difficulty Easy/[Normal]/Hard. Spectator slots, Tournament mode hidden. Changes clear all Ready.
- Join: LAN browser (name, map, players, ping; refresh 2 s; drop after 6 s silent), host IP, or 6-char room code (matched via LAN discovery). Code charset: uppercase letters and digits without 0, O, 1, I. PIN asked first. 10 humans = full; joiner replaces a bot. Started match: rejoiners only. Duplicate names get number suffix. Host leaves lobby: room closes, all to Play menu.

### Kanto lobby
- Playable corner; players as last_hero or bench hero. 3 dummies, 2-dummy practice chain, pole; dummies/chain return after 3 s; capture resets, no score. Skills half CD, dummies only. Tags on players = miss.
- Mats (yellow Dilaw, purple Lila): stand 1 s to switch if free slot (bot slot free, bot removed); clears Ready. Joiner to team with fewer humans, Dilaw on tie.
- Panel: 2 x 5 slots, name + Ready tick; join order, host first, bots last. Ready: HANDA or hold Interact 1 s at ready sign; again unreadies.
- Host: shuffle (humans per team within 1), balance (latest joiners off larger team until within 1), remove (bot, or human to Play menu; may rejoin), add bot (selected slot), settings, SIMULAN (all non-host humans ready, each team ≥ 1; counts as host Ready; bots fill if On).

### Tutorial lessons 1 to 5
- Offline host, same rules, 3 min target, from lesson 1 always; checkmarks, next lesson 2 s after last; Escape pauses.
- 1 Takbo: run to the enemy base and step inside its ring. 2 Unahan: tag a bot first, get tagged first, bump own barrier. 3 Taya!: capture undefended enemy base. 4 Huli ka: get tagged, jail with 2 bot prisoners, anchor, bots join, bot teammate rescues. 5 Resbak: rescue undefended 3-bot chain.

## 9. Controls
- Move: WASD, always run. Pad left stick ≥ 50% run, 15 to 50% walk half speed, < 15% stand.
- Aim: mouse, hero always faces cursor. Pad right stick; at rest faces movement.
- Tag: LMB, one per press / right trigger. Skill 1, 2: Q, E / LB, RB.
- Interact: F / A or Cross. Hold to capture (Toggle: tap start, tap stop); tap to anchor, join or leave chain.
- Ping: MMB or G / D-pad up (wheel line via right stick). Banter: T / D-pad down (inert). Scoreboard: Tab / View or Touchpad (hold). Menu: Escape / Menu or Options.
- All rebindable. Prompts follow last-used device instantly; pad icons per Button icons.
- Tag assist (gamepad, default On): nearest taggable enemy within 2.4 m and 30 deg of aim; lunge turned toward it up to 15 deg; else straight.

## 10. Settings
- Apply instantly; Display mode/Resolution revert after 10 s unless confirmed. Slider steps 1 (0 to 100), 5% (percent), 0.1 (sensitivity). IBALIK SA DEFAULT per tab. Online-only rows greyed; finals rows hidden. Credits button. [default]; On/Off rows show default only.
- Gameplay: Danger border [On] (outlines always show). Skill casting [Quick cast]/Show aim then release. Tag assist [On]. Camera shake 0 to 100% [70%] (0, greyed under Reduce camera motion). Minimap size S/[M]/L, position [Top right]/Bottom right. Tag feed [On]. All chat [Off], greyed. Team colours [Fixed]/Relative (own yellow, enemy purple, local only).
- Controls: key and pad bindings per action. Mouse sensitivity 0.1 to 3.0 [1.0] (aim cursor speed). Stick dead zone 0 to 30% [15%]. Vibration [On]. Button icons Xbox/PlayStation/Generic [detected, else Generic].
- Video: Display mode Windowed/[Borderless]/Fullscreen. Resolution [monitor] (Borderless always monitor). Render scale 50 to 100% [100%]. VSync [On]. Frame cap 30/[60]/120/Unlimited. Quality preset Mababa (Shadows Off, Effects Low, Render 75%), Katamtaman (Low, Low, 100%), Mataas (High, High, 100%), Custom (auto on manual change) [first launch Mataas on discrete GPU, else Katamtaman]. Shadows Off/Low/High, Effects Low/High [follow preset]. Brightness 0 to 100 [50]. Interface size 80 to 130% [100%].
- Audio 0 to 100: Master [80], Music [60], Sound effects [80], Voices and banter [80], Announcer [80]. Output device [system default].
- Accessibility: Colour mode Default/Deuteranopia/Protanopia/Tritanopia/High contrast [from setup] (swaps outline, danger border, team colours; High contrast adds dark text backing). Subtitles [On] (all voice and announcer lines), size S/[M]/L, speaker names [On]. Sound cues on screen [Off] (icon toward footsteps of unseen enemies within 10 m, captures, coughs; none for hidden sounds). Reduce flashing [Off] (max 3 flashes/s, edge flashes steady glow, no confetti). Reduce camera motion [Off] (no shake or slow motion; zooms become cuts). Capture input [Hold]/Toggle.
- Menus fully keyboard and pad usable. UI text sans-serif ≥ 18 px at 1080p, contrast ≥ 4.5:1.
- Language/network/account: Interface language [Filipino with English labels]/English/Filipino. Show ping and packet loss [Off] (top left). Change name (3 to 16, same filter, outside rooms). Delete local data (confirm, wipe, restart at setup). Region, Who can invite you, Blocked players: greyed.

## 11. Bots
- Same rules and input frames as players; no skills in Tradisyonal.
- Bantay: within 8 m of own pole, outside barrier, tags nearby attackers. Atake: heads for enemy base when no Free enemy within 8 m of its path, captures. Pain: runs at defenders to pull them off base. Resbak: heads to chain tip of jail holding teammates. Kapit: jailed, joins chain; tip bot steers toward nearest free teammate.
- Every 1 s per team: if a teammate is jailed, free bot nearest enemy jail = Resbak; free bot nearest own base = Bantay; rest alternate Atake, Pain, Atake first. Jailed = Kapit.
- Retreat: free bot not capturing/rescuing with no skill ready backs from a Free enemy within 6 m unless its tag lands first.

|Difficulty|Reaction|Retreat rule|Skill use|
|---|---|---|---|
|Madali|0.6 s|Ignored 30%|20% of valid chances|
|Katamtaman|0.35 s|Ignored 10%|50%|
|Mahirap|0.2 s|Never ignored; Pain only with a teammate within 15 m of enemy base|90%|

- Takeover (disconnect/idle): instant; hands back on return. Keeps position, jail/chain state, CDs. Capture cancelled to 0. Chained stays; tip bot steers to nearest free teammate. Room difficulty. Name kept, bot icon in tracker.

## 12. Technical

### Engine and networking
- No SDFGI, VoxelGI, volumetric fog. Target 60 fps at 1920x1080, Medium, 10 heroes, slowest demo PC. Export Windows x86_64, .pck embedded.
- ENetMultiplayerPeer, UDP 7777, listen server, up to 9 remote players. vs Bots, tutorial: same host code on OfflineMultiplayerPeer; pause stops tick.
- Host simulates everything incl. every random roll (map, bases, draft auto-picks); clients only send input and draw. 60 ticks/s in _physics_process regardless of frame cap. Version mismatch refused with reason.
- Client: per tick input frame, unreliable ordered (move vector, aim, held buttons); presses (Tag, S1, S2, Interact tap, ping, wheel choice) reliable, applied next tick. Host uses newest frame, else last; bots make same frames. Lobby/draft actions (mat, Ready, hover, pick, settings): reliable requests, host validates, broadcasts.
- Host: per tick one snapshot to all, unreliable ordered. Per player: position, facing, state (free, winding up, stumbling, stunned, capturing, jailed, chained, protected, hidden), CDs, passive. Per match: capture progress, chain order per jail, skill objects, hazard state, timer, round phase, score.
- Reliable events with host tick: tag, failed tag, Sabay, guard break, perfect slide, rescue, capture start/cancel/success, lockdown, sudden death start, round end, hazard warning, ping. Reliable phase changes: load map, roulette results, draft state, countdown, results.
- Clients interpolate everyone 2 ticks (about 33 ms) behind newest snapshot, no prediction; local facing follows mouse instantly, position doesn't. Outlines from same can_tag. Full snapshot to all (hidden players, decoy identity, fakes); client hides what its team can't see.

### Tick order (host, every tick)
Results found in the same step happen at the same moment.
1. Inputs: apply the newest input frame and the queued presses of every player and bot.
2. Actions: a Tag press starts a 9-tick wind-up. Skill and Interact presses start or cancel skills, captures and chain joins.
3. Movement: move players and skill objects, then apply pushes, slows, terrain and hazards.
4. Base barriers: keep each team's players out of their own base ring.
5. Tags: for each tag whose wind-up ends this tick, run the hit test, then the perfect-slide check, then can_tag, all against the state after step 4. Store the results without applying them. If two enemies land valid tags on each other this tick, both stumble and nobody is jailed (Sabay).
6. Rescues: find every free player touching a chain tip, and every valid SAGIP! ranged rescue, against the state after step 4. A player tagged in step 5 still counts as free here.
7. Apply steps 5 and 6 together: tagged players go to jail, rescued chains go free and get Escape Protection.
8. Captures: cancel any capture whose attacker was tagged this tick, let go of Interact, or is more than 1 metre from the pole. Add 1 tick to the others. A capture that reaches 90 ticks succeeds.
9. Round end: check captures, then total jail lockdown (after step 7, so a same-tick rescue prevents it), then the timer. In sudden death, a tag applied in step 7 (a JM guard break counts) or a capture ends the round. If both teams meet an end condition on the same tick, the round is a draw.
10. Send this tick's snapshot and events.

### Sessions and discovery
- player_id: random UUID on first launch, saved; host keys slots by it. Disconnect: ENet report or 5 s silence, bot next tick.
- Idle (Custom Room only): no input change (key, button, mouse, stick past dead zone) while Free and round running: warning 30 s, bot 60 s; any input returns control.
- Rejoin until match end (Home banner while discovery lists the match, or LAN browser after restart): current phase + full snapshot, control next tick. New players lobby only. No host migration; host leaving or lost connection: host-left message, Home, no results saved.
- Discovery: host broadcasts 1/s on UDP 7778: room name, code, map, player count, PIN flag, game version, game port. Browser ping = probe round trip to discovery port. Direct IP: IPv4 on 7777. Host verifies PIN. Windows Firewall: allow on private networks.

### Save data
- user:// with use_custom_user_dir = RESBAK (%APPDATA%\RESBAK).
- settings.cfg (ConfigFile): sections gameplay, controls, video, audio, accessibility, language_network; one key per setting row; bindings per action; written on every change.
- profile.json: save_version, player_id, player_name, setup_done, tutorial_lessons_done, matches_played, last_hero, home_hero, last_map, totals (matches, wins, tags, rescues, captures, MVPs); written after setup, each lesson, each match, each rename.
- Write .tmp then rename. Unloadable: rename .bak, use defaults. Delete local data removes both. Each PC saves only its own player; host sends each client its stats. No encryption, no cloud.

### Project structure
- Autoloads: Net (peer, discovery, code, connect, disconnect, rejoin); Save; Session (room settings, slots, lineup, map, bases, score); Audio (buses Master, Music, Effects, Voices, Announcer; announcer queue).
- tuning.tres (Numbers values); HeroData .tres per hero (speed, reach, CDs, skill values).
- Scenes: boot, title, first_setup, home, play_menu, custom_room, settings, credits, kanto, roulette, draft, loading, match (incl. intro, countdown, between rounds, HUD), results.
- match: map, 10 heroes, HUD, host-only MatchHost (RoundFlow, TagSystem, BaseSystem, JailSystem, SkillSystem, HazardSystem, BotBrain per bot) running the tick order.
- Hero: shared hero.tscn (CharacterBody3D) + HeroData + script per skill and passive. Kanto: match sim without player tagging + dummies, chain, pole. Tutorial: match on offline host + lesson script. UI strings: one translation CSV (Filipino, English).

### Build order
Networking first, rules host-side from the start: 1 LAN host/join, discovery, 60-tick loop, two players on grey map; 2 can_tag, tagging, stumble, outlines; 3 capture, base barrier; 4 jail, chain, rescue, EP; 5 round flow (countdown, timer, sunset, sudden death, draws, scoring); 6 HUD (danger border, tracker, sun timer, tag feed, minimap, ping); 7 bots, takeover; 8 one hero's kit, then four more; 9 Barangay Court, then Plaza, Tambakan (Taguan, terrain, high ground); 10 save, Settings; 11 front end through results; 12 tutorial 1 to 5; 13 sound, music, voices, clean camera; 14 hazards if time allows.

## 13. Strings
Filipino = English; [x] = runtime value.
- Boot: "Made with Godot"; "A game about the Filipino street game Agawan Base."
- Pindutin para maglaro = Press any key; Aalis ka na? = Leaving?; Oo = Yes; Hindi = No; Wika = Language; Pangalan = Name; Kontrol = Controls; dice names e.g. Batang Ulan, Siga ng Kanto.
- LARO = Play; ENSAYO = Practice; BARKADA = Friends; GAWAIN = Challenges; LUMABAS = Quit; Malapit na = Coming soon.
- Turo ni Kuya Tanod (tutorial); Alam Mo Ba? = Did you know?
- Cards: Laban sa Bots = "You and 4 bots against 5 bots"; Custom Room = "Private room for friends, LAN and tournaments"; Tradisyonal = "No skills, one base each, the real playground rules". Laban sa Bots o Custom Room? = Against bots or Custom Room?
- Madali = Easy; Katamtaman = Normal; Mahirap = Hard. SIMULAN = Start; HANDA = Ready. Room default "[Player name]'s room"; duplicate "[Name] 2". Umalis ang host = The host left.
- Sa Barangay Court tayo! (map line, one per map); Purok Dilaw! / Purok Lila!; KABOOM!
- Lessons: Takbo = Run; Unahan = First tag; Taya! = Capture; Huli ka = You're caught; Resbak = Rescue. Unahan lang 'yan! = Whoever is first!
- Resbak! Hawakan ang dulo ng kadena. = Rescue! Touch the end of the chain. HULI! = Caught; NAKUHA! = Got it.
- TAKIPSILIM (banner); Takipsilim! Isang huli na lang! = Sunset! One more tag wins! Uwi na! Kakain na! = Come home, time to eat.
- Banners: NAKUHA ANG BASE! = Base captured; LOCKDOWN!; UWI NA! (sunset win); TAKIPSILIM! (sudden death win); TABLA! Ulit! = Draw, play again.
- Tag feed: [Tagger] HINULI si [Target]; [Name] RESBAK x[n] (n freed); [Name] NAKUHA ANG BASE!; [Name] SINIRA ang bantay ni JM; LOCKDOWN! (winner colour).
- Pindutin ang F para kumapit = Press F to hold on; Pindutin ang F para bumitaw = Press F to let go (key per binding).
- Smart pings: enemy base Atake dito! = Attack here; own base Depensa! = Defend; enemy Kalaban dito! = Enemy here; enemy jail with teammates Resbak tayo! = Let's rescue; ground/own jail Punta dito. = Go here.
- Wheel: Atake!; Depensa!; Resbak!; Ingat! = Careful; Ako bahala = I've got it; Aatake ako = I'm going in; Bantay ako = I'm guarding; Salamat! = Thanks.
- BUMALIK = Resume; UMALIS = Leave match; Nandiyan ka pa ba? = Are you still there?; Bumalik sa laro = Rejoin.
- PANALO! = Win; TALO! = Loss; Bida ng Talo = Star of the losing side; LARO ULIT = Play again; BUMALIK SA TAMBAYAN = Back to Home.
- Badges: Pader = Wall; Pasaway = Troublemaker; Kidlat = Lightning. Bot name: [Hero] (Bot).
- IBALIK SA DEFAULT = Reset to default; Mababa/Katamtaman/Mataas = Low/Medium/High.

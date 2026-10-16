# Game at a glance

## How to read this document
- Sections follow the player: boot, menus, match setup, rules, characters, maps, match screen and results. Progression, customization and settings come next. Production notes come last.
- Numbers such as speeds, timers and cooldowns are starting values. Store each one as a named constant in one place so it can be tuned without code changes. When playtesting changes a value, update this document.
- The "What ships when" table in "Build scope for the competition entry" decides whether a feature is in the 25 October build, the finals build or later. A feature this document does not scope follows that table.
- The section "Changes from the original concept" lists everything that changed from the first RESBAK! concept document.

## Summary
RESBAK! Agawan Base is a 5 versus 5 competitive team game based on Agawan Base, the Filipino street game of base stealing and tag. Two teams of five kids try to capture the other team's base or jail all five opponents. Tagged players are not eliminated. They go to jail, where they hold hands to form a human chain and wait for a teammate to rescue them.

## Key facts
| Item | Decision |
|---|---|
| Title | RESBAK! Agawan Base |
| Genre | Team objective tag game, round based |
| Competition | DOST LEVEL UP 3.0 Esports Game Dev Challenge |
| Theme | Philippine Games and Sports |
| Engine | Godot 4 |
| Platform | Windows PC, with keyboard and mouse or gamepad |
| Players | 5 versus 5. Bots fill empty slots. A Custom Room can turn bot filling off (see Creating a Custom Room). |
| Connection for the entry | Local network (LAN) and bots. Online play comes later. |
| Camera | Top-down three-quarter view that keeps your hero in the centre of the screen. The camera never rotates. Starting values: 55-degree downward pitch, 22 metres from the hero, 40-degree vertical field of view. Every player sees the map with its long axis left to right and Purok Dilaw's side on the left. |
| Match format | Best of 5 rounds: the first team to 3 points wins. A drawn round (Tabla) gives no point and is replayed, so it does not count toward the 5. A Custom Room can set points to win from 1 to 5. |
| Round length | 2-minute round timer (Custom Room: 1 to 3 minutes). If the round reaches sudden death, up to 30 more seconds. From the third draw in a match, sudden death has no time limit. |
| Match length | Design target, not enforced: 10 minutes on average from map roulette to results. There is no hard maximum, because sudden death has no time limit from the third draw. |
| Teams | Purok Dilaw (yellow) and Purok Lila (purple) |

## Premise
It is a hot summer afternoon in Barangay Masigla. Two neighbourhood groups, Purok Dilaw and Purok Lila, settle their rivalry with a game of Agawan Base before sunset. Kuya Tanod, the barangay watchman with a megaphone, is the referee, the announcer and the tutorial guide. The round timer is drawn as the sun setting. When a round ends after the timer ran out (a sunset win, a sudden death result or a draw), a mother's voice calls "Uwi na! Kakain na!" It does not play when a capture or a lockdown ends the round before the timer runs out.

## What the title means
Resbak is street slang for coming back for your people. Rescuing jailed teammates is the heart of the game. Every successful rescue plays the "RESBAK!" shout described in Feedback for key events.

## Design pillars
1. Sigla decides every chase. Sigla means energy, and it is the real Agawan Base rule: whoever touched their own base more recently can tag the other. Going home makes you dangerous again.
2. Nobody gets left behind. Being tagged is never elimination. Your team can always rescue you.
3. Readable at a glance. A new player or a spectator can tell who can tag whom without reading numbers.
4. Barangay, not battlefield. Kids at play with comic energy. No guns, no weapons, and nothing that hurts anyone.

## Game loops
1. The chase loop, target 10 seconds. Touch your base, then chase enemies you can tag. Go home to become dangerous again, or sneak a rescue or a capture while the defenders chase someone else.
2. The round loop. Countdown, then play until a base capture, a total jail lockdown, or the end of the round timer and any sudden death. With default settings this is up to 2 minutes 30 seconds after the 3-second countdown, except that sudden death has no limit from the third draw.
3. The match loop, target 10 minutes. Map roulette, character draft, loading, intro, then rounds until one team reaches the points to win, then results.
4. The session loop, finals build and later (see What ships when). Play matches to earn Tansan (bottle caps) and, later, experience. Spend Tansan on cosmetics in the Locker. Complete daily challenges for extra rewards. The competition entry has no session loop.

# Player journey at a glance

## From boot to results
1. Boot splash: team logo and Godot credit.
2. Title screen: press any key.
3. First-time setup: language, name, colour check and controls. Shown until it is finished once.
4. Home screen (Tambayan): the hub for everything.
5. Play menu: choose vs Bots, Tradisyonal or Custom Room.
6. Room lobby (Custom Room only): players run around the playable Kanto while teams fill up, then press Ready. vs Bots goes from its setup screen straight to step 7.
7. Map roulette: the map and both active bases are picked.
8. Character draft: snake pick order. From the finals build, the 15-second Preparation phase follows.
9. Loading screen: both lineups in their signature poses.
10. Intro cinematic: a sweep over the arena, then a circling team reveal for each side.
11. Countdown: 3 seconds frozen, then KABOOM.
12. Round: chase, tag, jail, chain, rescue and capture.
13. Between rounds: result, freeze frame and score.
14. Results screen: winner, MVP, badges and scoreboard.
15. Next: BUMALIK SA TAMBAYAN returns to Home. LARO ULIT starts another match with the same settings. In vs Bots it goes to step 7. In a Custom Room it returns every player to the room lobby with teams kept and every Ready tick cleared.

## Where each step is described
| Step | Section |
|---|---|
| Boot splash, title screen, first-time setup | Launching the game |
| Tutorial, opened from the Practice menu | Learning to play |
| Home screen | Home screen |
| Play menu and room lobby | Choosing a mode |
| Map roulette to countdown | Getting into a match |
| Round | Controls, Core rules, Characters, Maps, The match screen |
| Between rounds | The match screen |
| Results screen | After the match |

# Launching the game

## Boot splash
- Shows the team logo for 2 seconds, then "Made with Godot" for 1 second, then a short note for 1 second: "A game about the Filipino street game Agawan Base."
- Any key, mouse button or gamepad button skips the rest of the splash. The title screen appears once settings and the player profile have loaded.
- Settings and the player profile load in the background.

## Title screen
- A live 3D scene of the Barangay Court at golden hour, with kids playing in the background and a tricycle passing. If the kids or the tricycle are not ready by the 22 October feature freeze, the competition build shows the court without them.
- The RESBAK! logo drops in with a megaphone shout of "RESBAK!"
- Text in the centre: "Pindutin para maglaro" (Press any key).
- Bottom left: the version number. Bottom right: a Settings button and a Quit button. Quit opens the same "Aalis ka na?" confirmation as the Home screen.
- Any key, mouse click or gamepad button that does not select Settings or Quit goes to First-time setup on the first launch, and to the Home screen after that. Escape, or B or Circle on a gamepad, opens the Quit confirmation.

## First-time setup
Shown until the player finishes step 4 once. Quitting earlier shows it again on the next launch. Every step has a Skip button that keeps the default. Skipping step 2 gives a random name from the dice list. Escape, or B or Circle, goes back one step and does nothing on step 1.
1. Wika (Language): Filipino with English labels (default), English, or Filipino.
2. Pangalan (Name): enter a player name of 3 to 16 characters, counted after removing leading and trailing spaces. Allowed characters are letters (including Ñ and ñ), digits and spaces. A name that contains a word from the local blocklist file (Filipino and English, not case-sensitive) cannot be confirmed. A dice button picks a random name from a list of at least 20, such as "Batang Ulan" or "Siga ng Kanto".
3. Readability check: the screen shows one enemy with a cyan outline and one with an orange outline. The player cycles through Default, Deuteranopia, Protanopia, Tritanopia and High contrast, the two outlines update live, and the player confirms the easiest one to read. Default is selected first.
4. Kontrol: the game shows the control layout for the device that last sent input (keyboard and mouse, or gamepad), and the player confirms.
5. The game then goes to the Home screen. It never prompts the tutorial, which is in the Practice menu (Ensayo).

## Interface language
Buttons and headings are in Filipino with an English label underneath in a smaller font, for example LARO (Play). The smaller label is still at least 18 pixels at 1080p (see Accessibility). Players can switch to English only or Filipino only in Settings. All three options ship in the competition build.

## Navigation rules for every screen
- Every button can be reached with the mouse, the arrow keys, the gamepad D-pad and the left stick. Enter, or A or Cross on a gamepad, presses the selected button.
- Escape, or B or Circle on a gamepad, goes back one screen. On the Home screen it opens the Quit confirmation. From the map roulette until the results screen appears, it opens the match options overlay instead (see Options during a match).
- The main action on each screen is selected when the screen opens. In a confirmation dialog the safe choice, such as Hindi (No), is selected.
- Screen changes use a chalk-wipe transition that lasts 0.3 seconds.

# Learning to play

## Tutorial: Turo ni Kuya Tanod
The tutorial is in the Practice menu (Ensayo). The game never forces or prompts it. Target length: 3 minutes. It runs offline as a local host, using the same rules code as a match. Lessons always play in order from lesson 1, and progress is not saved. Each lesson shows its goals on screen and a checkmark as each goal is done. The next lesson starts 2 seconds after the last checkmark. Kuya Tanod guides each lesson with speech bubbles and short recorded voice lines. Full recorded narration comes with the finals build. Escape pauses the tutorial and opens a pause overlay with a resume option and an option to return to the Practice menu.
1. Takbo (Run): run to your own active base ring and step inside it. Heroes run whenever they move, so there is no sprint button. On a gamepad, a small tilt of the stick walks.
2. Huling hawak (Last touch): touch your base, then tag a bot that left its base earlier and glows cyan. Then stay away from your base while a bot touches its own base, turns orange, and tags you. Finally, duel a bot with a white outline: the first clean tag wins. Kuya Tanod says: "Bagong hawak sa base, ikaw ang taya!" (Fresh from your base, you're it!)
3. Taya! (Capture): capture the enemy base by holding Interact at its pole for 1.5 seconds. No enemy bot defends it.
4. Huli ka (You're caught): a bot tags you and you appear in the enemy jail with two bot prisoners. Press Interact at the jail marker to become the anchor. The two bots join behind you, and a bot teammate rescues the chain by running into its tip.
5. Resbak: run into the tip of a chain of three bot prisoners to rescue them. No enemy bot defends the jail.

Lessons 1 to 5 are in the competition build. The finals build adds lesson 6, Skills, where the player picks a hero and uses one skill, and lesson 7, Final test, a 3 versus 3 match against Normal bots, first to 1 point, with the default round timer. From the finals, finishing the tutorial also gives Tansan and the title "Bagong Kalaro" (New Player).

## Help after the tutorial
- During the draft, each skill shows a one-line tip.
- From the finals build, each hero has a "Paano laruin" (How to play) page with a looping clip of up to 20 seconds, opened from the draft screen and from the Locker. The competition build uses the draft's skill tips and 6-second clip instead.
- Onboarding hints (competition build): during a player's first 5 completed matches, counted in the local save, each hint shows the first time its event happens in a match. A hint shows for 4 seconds above the skill icons and does not pause play. The hint list so far: the first time a teammate is jailed, "Resbak! Hawakan ang dulo ng kadena." (Rescue! Touch the end of the chain.)
- Loading screens show tips (see Loading screen), and the Practice menu has the Alam Mo Ba? (Did you know?) pages.

# Home screen

## The Tambayan
The Home screen is the front of a sari-sari store at dusk. The player's bench hero sits on the bench in their equipped skin (the default skin in the competition build). The bench hero is saved locally and is JM "Botsog" on first launch. Once Barkada parties arrive (later), party members' heroes stand next to it.

## Layout
| Position | Element | What it does |
|---|---|---|
| Top left | Player card | Shows name, avatar and level bar. Opens Profile. |
| Top right | Tansan counter | Shows the player's bottle caps |
| Top right | Gawain bell | Opens Challenges. Shows a dot when a reward can be claimed. |
| Top right | Settings button | Opens Settings |
| Centre | Hero on the bench | Select it to open a row of the 5 hero portraits. Picking one changes the bench hero. |
| Right column | LARO (Play) | The largest button, selected by default. Opens the Play menu. |
| Right column | ENSAYO (Practice) | Opens the Practice menu |
| Right column | BARKADA (Friends) | Opens the party and friends panel |
| Right column | LOCKER | Opens Customization |
| Right column | GAWAIN (Challenges) | Opens Challenges |
| Bottom left | News tile | Tips, patch notes and season information |
| Bottom right | LUMABAS (Quit) | Asks "Aalis ka na?" (Leaving?) with Oo (Yes) and Hindi (No). Hindi is selected first. Oo closes the game. |

In the competition build, LOCKER, GAWAIN, BARKADA, the Gawain bell, the player card's Profile link, the Tansan counter and the News tile are shown greyed out with a "Malapit na" (Coming soon) tag, and selecting them does nothing. The player card shows only the player's name and the bench hero's portrait as the avatar. Every other menu entry that is not in the current build, such as Bakuran and the Classic and Ranked cards, is greyed out the same way. In the finals build, LOCKER, GAWAIN, the Gawain bell, the Profile link and the Tansan counter work. BARKADA, the News tile and the level bar stay greyed out or hidden until later.

## Practice menu (Ensayo)
- Tutorial: Turo ni Kuya Tanod.
- Bakuran (sandbox, finals build): play any hero alone on any map with training dummies. Options: no cooldowns, dummies that stand still or chase you, and hazards on or off.
- Alam Mo Ba? (Did you know?): short illustrated pages about Agawan Base and other Filipino street games, their rules and history. The competition build has 5 pages, all unlocked. More pages come later and unlock as you play.

## Profile
Ships with the finals build. Items that depend on levels or mastery (level, experience bar, frame, title and mastery level) appear only when those systems ship later.
- Player name, avatar, frame and title.
- Level and experience bar.
- Totals: matches, wins, tags, rescues, captures and MVPs.
- Most played heroes with their mastery level.
- Saludos received from other players.

## Challenges (Gawain)
Ships with the finals build.
- Three daily challenges, drawn from a challenge list in a data file, for example "Rescue 5 teammates." They reset at 00:00 local PC time.
- Three weekly challenges, drawn from the same file, for example "Win 5 matches." They reset on Monday at 00:00 local PC time.
- One free reroll of a daily challenge per day.
- Each challenge shows its progress and its Tansan reward. A Kunin (Claim) button appears when it is complete.

# Choosing a mode

## Play menu (Laro)
The Play menu shows one card per mode. Hovering over a card, or selecting it with keys or a gamepad, plays its 5-second clip on a loop and shows its one-line summary. Cards marked Later are greyed out with the "Malapit na" tag.

| Card | Summary | Available |
|---|---|---|
| Laban sa Bots (vs Bots) | You and 4 bots against 5 bots | Competition build |
| Custom Room | Private room for friends, LAN and tournaments | Competition build |
| Tradisyonal | No skills, one base each, the real playground rules | Competition build |
| Classic | Online 5 versus 5 with random teammates | Later |
| Ranked | Competitive online ladder | Later |

## All modes
| Mode | Players | Rules | When |
|---|---|---|---|
| vs Bots | You and 4 bots against 5 bots | Full rules, choose difficulty | Competition build |
| Custom Room | 2 to 10 players plus up to 2 spectators, bots fill empty slots | The host chooses every setting | Competition build |
| Tutorial | Solo | Scripted lessons | Competition build |
| Bakuran (sandbox) | Solo | Free practice with dummies | Finals build |
| Tradisyonal | 5 versus 5, with bots or in a Custom Room | No skills, one fixed base per side, no hazards | Competition build |
| Classic | 5 versus 5 online | Full rules, random map, no role selection | Later |
| Ranked | 5 versus 5 online | Full rules, role queue, seasons | Later |

## vs Bots setup
- Choose a map, or Roulette. Default: Roulette.
- Choose bot difficulty: Madali (Easy), Katamtaman (Normal) or Mahirap (Hard). Default: Katamtaman.
- Every other setting uses the Custom Room defaults: 3 points to win, 2-minute round timer, hazards on, skills on, base Roulette.
- Press SIMULAN (Start) to go to the map roulette, then the character draft.
- vs Bots runs offline as a local host with no other clients, using the same host code as a LAN match.
- During a match, Escape opens the options overlay and pauses the game until the overlay closes.

## Creating a Custom Room
| Setting | Options | Default |
|---|---|---|
| Room name | 3 to 24 characters, with the same character rules and blocklist as player names | "[Player name]'s room" |
| PIN | None, or 4 digits | None |
| Map | Any map, or Roulette | Roulette |
| Base selection | Roulette, Fixed (the host picks site 1, 2 or 3, mirrored for both teams) | Roulette |
| Points to win | 1 to 5 | 3 |
| Round timer | 1 to 3 minutes, in 30-second steps | 2 minutes |
| Hazards | On, Off | On |
| Skills | On, Off | On |
| Fill empty slots with bots | On, Off | On |
| Bot difficulty | Easy, Normal, Hard | Normal |
| Spectator slots (finals build) | 0 to 2 | 0 |
| Tournament mode (finals build) | On, Off | Off |

The two finals-build settings are hidden from the room settings in the competition build.
- Each map numbers its three base sites 1 to 3 in the order its map section lists them. Fixed uses the same site number on every map, so it also works with a Roulette map. The Tradisyonal preset uses site 1.
- With Fill empty slots with bots Off, teams can be smaller than 5 and uneven. Each team needs at least 1 player to start. Total jail lockdown then means every player on that team is in jail.
- The host can change settings in the room lobby. Any change clears every Ready tick.
- If Hazards is On but a map's hazard is not built, that map plays without it.

## Joining a Custom Room
- The LAN browser lists rooms on the local network with their name, map, player count and ping. It refreshes every 2 seconds and drops a room it has not heard from for 6 seconds.
- Players can also type the host's IP address or a 6-character room code. The code is shown in the room lobby and uses uppercase letters and digits, without 0, O, 1 and I. The code is matched against rooms found by LAN discovery, so it works only on the same network.
- Rooms with a PIN ask for it before joining.
- A room with 10 human players is full. A joining player takes a slot held by a bot. A room whose match has started cannot be joined, except by a player reconnecting to it.
- If a joining player's name matches one already in the room, the room shows it with a number suffix, such as "Batang Ulan 2".
- If the host leaves the room lobby, the room closes and every player returns to the Play menu with the message "Umalis ang host" (The host left).

## Room lobby
The room lobby is playable: players run around a small street corner called the Kanto while the room fills.
- Each player appears in the Kanto as the hero they played in their last match, or as their bench hero if they have not played one. Every player sees every other player in the Kanto.
- The Kanto has three practice dummies to tag, a practice chain of two dummy prisoners to rescue, and a base pole to practise capturing. A tagged dummy and a rescued chain come back after 3 seconds. A finished capture plays its effects and resets, with no score. Skills work with half their normal cooldown.
- Players cannot tag each other in the Kanto, and Sigla is off, so any player can tag any dummy. A tag that reaches a player instead of a dummy counts as a miss. Skills affect dummies only, never other players.
- The floor has a yellow mat for Purok Dilaw and a purple mat for Purok Lila. Standing on a mat for 1 second moves you to that team if it has a free slot. A slot held by a bot counts as free, and the bot is removed. Changing team clears your Ready tick. A player who joins is placed on the team with fewer human players, or Purok Dilaw on a tie.
- A room panel on the right of the screen always shows two columns of five slots, one per team, plus the spectator slots from the finals build. Each slot shows the player's name and a Ready tick, and plays a 0.3-second fill-in animation when someone joins. Slot order, top to bottom, is the order players joined that team, with the host first and bots last.
- Each player presses HANDA (Ready) on the panel, or holds Interact for 1 second on the ready sign in the Kanto. Doing either again removes the Ready tick.
- The host's controls are on the panel: shuffle teams, balance teams, remove a player, add bots, room settings and SIMULAN (Start).
- Shuffle teams moves humans to random teams, keeping the human count per team within 1. Balance teams moves the most recently joined humans off the larger team until the counts are within 1. There is no skill rating on LAN.
- Add bots puts a bot in the selected empty slot. Remove a player removes a bot, or sends a human back to the Play menu. A removed human can rejoin.
- SIMULAN unlocks when every human except the host is ready and each team has at least 1 player. Pressing it counts as the host's Ready. With Fill empty slots with bots On, every slot still empty then gets a bot.
- When the host starts, the screen wipes from the Kanto to the map roulette.
- The same Kanto is used while waiting for an online match later.

## Tradisyonal mode
Tradisyonal is the real playground game: Skills Off, Hazards Off and Base selection Fixed at site 1. Everything else, including Sigla, jail, the chain and rescues, works as normal.
- Skills Off turns off both active skills of every hero. Passives stay on, and heroes keep their own speed and tag reach.
- Tradisyonal is a one-click preset, not a separate game mode. Its Play menu card asks "Laban sa Bots o Custom Room?" (Against bots or Custom Room?) and opens that setup with the three settings above already set.
- In a Custom Room the host can still change those settings, and the room then plays with whatever is set.

# Getting into a match

## Map roulette
- A wheel of map cards spins for 4 seconds and lands on one map. Kuya Tanod announces it with that map's own line, for example "Sa Barangay Court tayo!"
- The overhead view of the map appears. When the announcement ends, each team's three base sites flicker like a roulette for 2 seconds, then the bases lock in. The character draft starts 1 second later. Both teams get the same site, mirrored, so neither side has an advantage. These active bases stay the same for the whole match.
- Map Roulette never picks the map of the previous match in the same Custom Room, or in the same vs Bots session since the game launched.
- A chosen map skips the map wheel, and Fixed base selection skips the base roulette. Each skipped part shows the chosen map or site for 2 seconds instead. In vs Bots the player makes the host's choices.

## Character draft: layout
- Your team's five slots on the left, the enemy's five slots on the right.
- The character grid in the centre.
- At the bottom, the hovered or picked character's skills, passive and a looping 6-second clip.
- Top right corner: the map with your active base marked.

## Character draft: pick order and rules
Pick order is a snake draft. With A as the first-pick team and B as the other, the 10 picks run A1, B1, B2, A2, A3, B3, B4, A4, A5, B5. Pick n of a team belongs to the player in slot n of that team on the room panel. In vs Bots the player is slot 1. A team with fewer than 5 players skips its missing picks.
- In vs Bots the player is always on Purok Dilaw, and Dilaw picks first. In a Custom Room, first pick alternates between matches, starting with Dilaw.
- Each pick lasts 12 seconds. The two picks of a two-pick turn run one after the other, so the turn lasts up to 24 seconds. A player locks in by confirming the hovered character, and the next pick starts at once. If time runs out, the hovered character is locked in. If nothing is hovered, or the hovered character is no longer available, a random available character is picked.
- A bot locks in a random available character 2 seconds into its pick.
- Before your turn, you can hover a character so your teammates see your plan.
- A team cannot pick the same character twice. A character the enemy picked is still available to you.
- With 5 characters, every team ends up with all five, so the draft decides who plays which character. Bans begin when the roster reaches 10 characters.
- If a player leaves during the draft, a bot takes the slot and the draft continues.

## Preparation phase (Ayusan)
The competition build skips this phase, because there are no skins, flares or banter sets to choose until the Locker arrives. From the finals build:
- Starts after the last pick and lasts 15 seconds.
- Players choose their skin, tag flare and banter set, and see both lineups.
- Buttons: Skin, Flare, Banter and HANDA NA (Ready). The phase ends early when everyone is ready.

## Loading screen
- Both lineups side by side. Each hero strikes a signature pose next to the player's name. Level and title are added when progression arrives.
- A progress bar under each player. The intro starts when every player has loaded. A player still loading after 30 seconds is treated as disconnected: a bot plays their hero until they finish loading.
- A tip that changes every 5 seconds, alternating between a gameplay tip and an Alam Mo Ba? fact about Filipino street games.

## Intro cinematic
- An 8-second cinematic in three shots, in this order.
- Arena, 2 seconds: the camera sweeps over the map, past both jails and both active bases glowing.
- Team reveals, 2.5 seconds per team, Purok Dilaw first: each team's five heroes stand shoulder to shoulder at their spawn. The camera circles around them at their height in slow motion while each hero strikes their pose, and Kuya Tanod calls out the team, for example "Purok Dilaw!"
- Face-off, 1 second: the camera rises above the middle of the map with both teams facing each other, then cuts down to the gameplay view.
- There is no countdown during the cinematic.
- It plays once per match, before the first round only. It cannot be skipped when more than one human is in the match. In vs Bots and in tutorial lesson 7, pressing Interact skips it, and a skip prompt with the Interact key shows in the bottom right corner.

## Countdown and KABOOM
- The camera cuts down to the gameplay view.
- A 3-second frozen countdown begins, showing 3, 2 and 1 for 1 second each. Players can turn to aim and can ping, but cannot move, tag, interact or use skills.
- At zero, "KABOOM!" appears with confetti and a drum hit, the round starts and the round timer starts running.

# Controls

## Keyboard and mouse
All keys can be changed in Settings.

| Action | Default key | Notes |
|---|---|---|
| Move | W, A, S, D | Always runs. There is no walk key. |
| Aim and face | Mouse | The hero always faces the cursor. Tags lunge toward it and skills aim at it. |
| Tag | Left mouse button | One tag per press. Holding does not repeat. |
| Skill 1 | Q | |
| Skill 2 | E | |
| Interact | F | Hold to capture, or with the Toggle capture setting tap to start and tap to stop. Tap to become the anchor, join or leave a chain. Rescues need no button. |
| Ping | Middle mouse button or G | Release within 0.25 seconds for a smart ping. Hold longer for the ping wheel, then release on a line to send it, or in the centre to cancel. Each player can send at most 3 pings in any 3 seconds. |
| Banter wheel | T, hold | Finals build. The key does nothing in the competition build. |
| Scoreboard | Tab, hold | Shows each player's name, hero, tags, rescues and captures, and whether they are free, jailed or chained. |
| Menu | Escape | |

## Gamepad
| Action | Default button |
|---|---|
| Move | Left stick. Tilted 50 percent or more: run. Tilted 15 to 50 percent: walk at half speed. Under 15 percent: stand still. |
| Aim | Right stick. With the stick at rest, the hero faces the way it moves. |
| Tag | Right trigger |
| Skill 1 | Left bumper |
| Skill 2 | Right bumper |
| Interact | A (Xbox) or Cross (PlayStation) |
| Ping | D-pad up, with the same tap and hold rules as the keyboard. Pick a wheel line with the right stick. |
| Banter wheel | D-pad down, hold. Finals build. |
| Scoreboard | View or Touchpad, hold |
| Menu | Menu or Options |

Every on-screen prompt shows the key or button for the device that last sent input, and switches as soon as the other device is used. Gamepad icons follow the Button icons setting.

Tag assist works on gamepads only and is on by default. When a tag starts, it finds the nearest enemy you can tag within 2.4 metres and within 30 degrees of your aim, and turns the lunge toward them by up to 15 degrees. With no such enemy, the lunge goes straight.

# Core rules

## Sigla: who can tag whom
Sigla means energy. It is the real Agawan Base rule: when two enemies meet, whoever touched their own base more recently has more Sigla and can tag the other. Touching your base refills your Sigla, and it fades the longer you stay away.
- Touching your base means your centre is inside your own active base ring. Running in counts. A tick on which you are pushed, by a skill or a hazard, does not count.
- Your touch time is the last tick you touched your base. While you stand in your ring it updates every tick.
- The moment you step out again, you are the newest player out, so you can tag every enemy who left their base before you.
- The longer you stay away from your base, the more enemies can tag you. Go home to become dangerous again.
- At KABOOM every player counts as leaving their base at the same moment, so nobody has the Sigla edge until someone touches their base.
- If two enemies' touch times are 0.3 seconds (18 ticks) or less apart, neither has the edge.
- Who can tag whom is checked on the tick a tag lands, at the end of the 0.15-second wind-up, not when Tag is pressed.
- Tapatan (duel): when neither player has the edge, either one can tag the other, and the first clean tag wins. A miss still causes the 0.5-second stumble, so swinging early is risky.
- Sabay (at the same time): the host checks tags 60 times a second. If two enemies tag each other in the same check, both stumble and nobody is jailed. Other tags landing on that tick apply normally. This is very rare.
- Freed prisoners count as having left their base at the start of the round. Once Escape Protection ends, any enemy who has touched base since the round started can tag them, and any enemy who has not meets them in a duel. This lasts until they touch their own base again.
- Sigla does not matter for rescues or captures. Any free player can rescue. Any free player can capture, except during the 4-second capture lockout after their own rescue.
- There is no Sigla meter and no number on screen. Players read Sigla from the outlines below.

## Reading Sigla on screen
This is the most important information in the game, so it uses shape and icon as well as colour.

| Situation | What you see | Meaning |
|---|---|---|
| You touched your base after that enemy did | Cyan outline and an open-hand icon on that enemy | You can tag them. Chase. |
| That enemy touched their base after you did | Orange outline and an exclamation mark icon on that enemy | They can tag you. Run. |
| Any enemy within 10 metres can tag you, including one in a duel with you | A thin orange border around your screen | Danger nearby. |
| Neither of you has the edge, for example right after KABOOM | White outline and a crossed-hands icon on that enemy | Duel: the first clean tag wins. |
| That enemy cannot be tagged by anyone (Tagged, Jailed, Chained or under Escape Protection) | Grey outline with no icon. Escape Protection adds a small shield icon. | Leave them. |

- When you touch your base, the ring flashes in your team colour, a short ding plays, and every outline around you updates at once.
- Outlines update the instant anyone touches a base, so a chase can flip in a second: a defender who steps on their base turns from cyan to orange.
- There is no fog of war. Every enemy on your screen is visible and outlined. The only things that hide a player are Taguan zones (hiding spots) and Nathan's powder cloud.

## Base rules
- No loitering (Bawal tumambay): a player can spend at most 3 seconds in total inside their own active base ring. The 3 seconds do not need to be continuous.
- When the limit is reached, the player is pushed outward from the pole until they are just outside the ring, and Kuya Tanod blows a whistle.
- The timer resets to zero once the player has been outside their own ring for 2 continuous seconds. Until then, their own ring blocks them like a wall.
- Spawn points sit outside every base ring, so the timer does not run during the countdown.

## Tagging
- Pressing Tag starts a 0.15-second wind-up. The lunge direction is your aim direction at the moment you press, after tag assist if it is on. You keep moving during the wind-up.
- On the tick the wind-up ends, the host looks for enemies, and Nene's decoys and fakes, whose body is within your reach (1.2 metres, Tutoy 1.0 metres, measured edge to edge between the two bodies) and within 45 degrees either side of the lunge direction. Who can tag whom is checked on that same tick.
- If at least one of them is an enemy you can tag, the nearest such enemy is tagged. An enemy you can tag is in the Free state (see Player states and timing), is not under Escape Protection, and either left their base before you did, is in a duel with you, or it is sudden death.
- A successful tag sends the target to your jail.
- Every other tag is a failed tag: nothing in range, only a decoy or fake, or only enemies you cannot tag. A failed tag makes you stumble for 0.5 seconds.
- There is no other tag cooldown. You can press Tag again on the tick after a tag resolves.
- A tag never scores a point by itself. It removes an enemy from play until they are rescued.
- Breaking JM's guard counts as a successful tag for sudden death, Impact points and badges.
- The host decides every tag, with no lag compensation on LAN. Online play later adds a 100-millisecond rewind in the tagger's favour.

## Bodies and blocking
- Every hero's body is a circle with a 0.4-metre radius.
- Free players collide with each other, so standing in someone's path to block them is allowed.
- Players in the Tagged, Jailed or Chained state, and players under Escape Protection, do not collide with other players.
- A push moves the target in a straight line over 0.2 seconds and stops at walls and jail barriers. The target cannot steer during a push.
- Pushes and slows from any source have no effect on chained prisoners. They do affect players under Escape Protection.
- Slows do not stack. Only the strongest active slow applies, whether it comes from a skill, terrain or a hazard.
- A skill can push an enemy away from their base, but it never changes who touched their base last.

## Bases
- Each team has 3 possible base sites on its side of the map.
- Once per match, right after the map roulette, a roulette picks one of the three sites. Each team's active base is that site on its own side, mirrored, and it stays put for the whole match. With Base selection set to Fixed, the host's chosen site is used instead.
- The active base is a solid pole with a 0.2-metre radius, inside a ring with a 3-metre radius, in the team's colour. The other two sites have no effect for that match.
- A player is inside a ring when their centre is 3 metres or less from the pole's centre. This test is used for touching your base, no loitering and JM's guard.
- There is no flag. You score by capturing the enemy's active base.

## Capturing a base
- An attacker starts a capture by holding Interact while the gap between their body and the enemy pole is 1 metre or less. The capture completes after 1.5 seconds of holding.
- While capturing, the attacker cannot move, tag or use skills. They can still be pushed.
- A shrinking chalk circle shows capture progress. Every player hears a rising megaphone tone and sees a flash at the edge of the screen.
- The capture is cancelled and progress resets to zero if the attacker is tagged, releases Interact, or is pushed so that the gap to the pole is more than 1 metre.
- With Capture input set to Toggle, press Interact once to start capturing and again to stop. The other cancel conditions still apply.
- A defender standing nearby does not pause or slow a capture.
- Several attackers can capture the same pole at once. Each has their own progress, and progress does not add up.
- A successful capture ends the round and gives the attacking team 1 point.

## Jail
- Each team's jail is on its own side of the map, behind its base sites. Players you tag go to your jail.
- A tagged player enters the Tagged state: they see a "HULI!" stamp and freeze in place for 0.8 seconds. Then they fade out and reappear at a random free spot inside the enemy jail, in the Jailed state.
- An energy barrier, drawn like a chalk fence, surrounds the jail. It blocks every free player, attackers and defenders alike, so nobody can hide inside. Prisoners cannot cross it, except chained prisoners. Prisoners leave only through a rescue or the round reset.
- Jailed players can move inside the jail at their normal speed, form a chain, ping and use the banter wheel. They cannot tag, capture or use skills.

## The human chain
- Each jail has a jail marker, a painted post on the side of the jail that faces the prisoners' home. The anchor's hand point is 1.5 metres outside the barrier, straight out from the marker.
- A prisoner within 1 metre of the marker presses Interact to become the anchor. There is one anchor at a time. The anchor cannot move.
- Any other prisoner within 1.5 metres of the anchor or of the tip who presses Interact joins the end of the chain. They are moved to the old tip's position and become the new tip.
- The last prisoner in the chain is the tip. Only the tip is steered, at its player's normal speed. The tip stays within 1.5 metres of the hand point for each link after the anchor. The host places the other links at even spacing on the line from the hand point to the tip.
- So the tip reaches at most 1.5 metres outside the barrier per chained prisoner: 6 metres with 4 prisoners. A chain has at most 4 prisoners, because 5 jailed players is a lockdown.
- Chained prisoners pass through the jail barrier but not through walls or solid map objects.
- Chained prisoners cannot be tagged, cannot tag, cannot capture and cannot use skills.
- Any prisoner can let go by pressing Interact again. That prisoner and every prisoner beyond them return to a random free spot inside the jail and must rejoin the chain. If the anchor lets go, the whole chain returns.
- A lone anchor is also the tip. Their rescue point is the hand point.

![Jail and chain diagram. The jail is a fenced box behind the base sites. The anchor stands at the jail marker on the side facing home and reaches 1.5 metres through the barrier. Three more prisoners link at up to 1.5 metres each, so the tip reaches at most 6 metres outside the jail. A free teammate runs into the tip to free the whole chain.](diagrams/chain.png)

## Rescuing
- A free teammate, including one under Escape Protection, rescues by touching the tip of the chain: their bodies touch (centres 0.8 metres apart or less). For a lone anchor, the rescuer's centre must be 0.4 metres or less from the hand point. No button is needed, and the rescue happens on that tick.
- A rescue frees the whole chain, from the tip back to the anchor. Prisoners who are not in the chain stay in jail.
- Freed players keep their positions. Any freed player still inside the jail is moved to the nearest point just outside the barrier.
- Rescues still happen in sudden death, but they do not win the round.

## Escape after a rescue
- Freed players get Escape Protection for 4 seconds, or 5 seconds if Inday made the rescue. They cannot be tagged and they pass through other players.
- Escape Protection ends early on the tick the freed player presses Tag, uses an offensive or movement skill (see Skill types under Characters), or starts a capture.
- Freed players cannot start a capture for 4 seconds after the rescue, also after an Inday rescue.
- Both timers start on the tick of the rescue.

## How a round ends
A round ends on the tick either of these happens, and gives exactly 1 point:
1. Base capture: a team captures the enemy's active base. That team scores.
2. Total jail lockdown: every player on a team is in the Tagged, Jailed or Chained state at the same moment. The other team scores.

If a rescue and the lockdown tag happen on the same tick, the rescue wins (see Same-tick order).

## Sunset tiebreak
The round timer is 2 minutes (Custom Room: 1 to 3 minutes), shown as the sun going down. It starts at KABOOM. If it reaches zero:
1. Uwi na: the team with fewer players in the Tagged, Jailed or Chained state on that tick wins the round.
2. If both teams have the same number, sudden death (Takipsilim) starts on the next tick and lasts 30 seconds. Play continues without a reset, and a capture in progress keeps its progress. Sigla is lifted: any free player can tag any free enemy who is not under Escape Protection, anywhere. The first successful tag or capture wins the round.
3. If no tag or capture happens in those 30 seconds, the round is a draw (Tabla). No point is given, and the round is replayed after a normal reset.
4. Once a match has had 2 draws, every later sudden death has no time limit, so every match has a winner.

A round won at sunset or in sudden death gives 1 point, like any other round.

Sudden death has its own look, so players know the rules just changed:
- The sky turns deep red, Kuya Tanod blows a long whistle and calls "Takipsilim! Kahit saan, pwede!" (Sunset! Anywhere goes!).
- Every enemy you can tag gets the cyan outline. The orange border shows while any enemy who can tag you is within 10 metres. A TAKIPSILIM banner stays under the sun timer.
- The mother's "Uwi na! Kakain na!" plays only when the round actually ends, not when sudden death starts.

## Winning the match
- The first team to 3 points wins the match (Custom Room: 1 to 5 points). Drawn rounds give no point and do not count toward the 5 rounds.
- Teams do not swap sides between rounds.

## Reset between rounds
- Everyone is freed from jail and every chain is cleared.
- All cooldowns reset, and JM's guard is restored.
- Every skill effect, slow, push, stun, stumble, Escape Protection, capture lockout, no-loitering timer, capture progress and passive bonus ends. Hazard schedules restart.
- Players return to their team's spawn points. Each spawn point holds up to 3 heroes: team slots 1 to 3 use the first and slots 4 and 5 use the second.
- Bases do not move. Teams keep the same active base for the whole match.

## Player states and timing
- The host runs the rules at 60 ticks per second. Every timer is counted in ticks: 1.5 seconds is 90 ticks.
- Distances between players are measured between body centres unless a rule says otherwise.
- Each player is always in exactly one of these states:

| State | Meaning |
|---|---|
| Free | On the field. Can move, tag, capture, rescue and use skills. Escape Protection is a timer on a Free player. |
| Tagged | The 0.8 seconds after being tagged. Frozen and cannot act. Cannot be tagged and does not collide. Counts as jailed. |
| Jailed | Inside the enemy jail and not in the chain. Counts as jailed. |
| Chained | The anchor, a link or the tip of the chain. Counts as jailed. |

- Stumble (failed tag) and stun (perfect slide, TAMARAW!!! wall hit): the player cannot move, tag, use skills or start a capture until it ends. They do not stack. If a new one arrives, the longer remaining time applies.
- When two players are more than 1 metre apart in height, they do not collide and cannot tag or rescue each other.

Same-tick order: the host resolves each tick in the fixed order listed under How the host resolves one tick, in Technical notes for Godot. That list is the only source for ordering.

On the tick the round ends, all play stops. Unfinished actions, such as a capture in progress at sunset, a tag wind-up or an active skill, are cancelled and give nothing.

## Numbers at a glance
| Value | Starting number |
|---|---|
| Host tick rate | 60 ticks per second |
| Running speed | 5.0 metres per second (JM 4.6, Tutoy 5.4). Heroes run whenever they move. There is no sprint and no stamina. |
| Walking speed | Half of running speed. Gamepad only, when the left stick is tilted between 15 and 50 percent. |
| Gamepad stick dead zone | 15 percent of full tilt |
| Hero body radius | 0.4 metres |
| Tag reach | 1.2 metres (Tutoy 1.0), edge to edge between bodies |
| Tag arc | 45 degrees either side of the lunge direction |
| Tag wind-up | 0.15 seconds |
| Tagged freeze | 0.8 seconds |
| Duel window | Base touches within 0.3 seconds of each other start a duel |
| Sabay | Two tags that land on the same host tick (1/60 second) |
| Danger border range | 10 metres |
| Failed tag stumble | 0.5 seconds |
| Base ring radius | 3 metres, measured to the player's centre |
| No-loitering limit | 3 seconds in total inside your own base ring, reset after 2 continuous seconds outside |
| Capture range | 1 metre gap between the attacker's body and the pole |
| Capture hold time | 1.5 seconds |
| Chain link distance | 1.5 metres, and the anchor reaches 1.5 metres through the barrier |
| Chain tip reach | 1.5 metres outside the barrier per chained prisoner, 6 metres at most |
| Rescue touch | Bodies touching, centres 0.8 metres apart or less |
| Escape Protection | 4 seconds, or 5 if rescued by Inday |
| Capture lockout after a rescue | 4 seconds, also after an Inday rescue |
| Round timer | 2 minutes (Custom Room: 1 to 3) |
| Sudden death | 30 seconds, with no limit after 2 draws in a match |
| Points to win | 3 (Custom Room: 1 to 5) |
| Footstep hearing range | 15 metres for running footsteps |

# Characters

## Roster rules
- There are five roles: Protection, Deception, Movement, Disruption and Rescue.
- Each character has a main role and a secondary role.
- Each character has two active skills and one passive trait.
- The launch roster has 5 characters, one per role.
- All characters share the same core rules: Sigla, tagging, running and Interact. They differ in speed, tag reach and skills.
- There is no sprint button and no stamina. Every hero runs at their own speed whenever they move. On a keyboard, moving always means running. On a gamepad, a small tilt of the left stick walks at half speed. Only skills, passives, terrain and hazards change speed.
- Current speed = base speed * (1 + the biggest active speed bonus) * (1 - the strongest active slow). Bonuses do not stack with each other, and slows do not stack with each other.
- HARUROT! and TAMARAW!!! set a fixed speed of 9 metres per second. Speed bonuses do not apply on top, but slows do.
- Skills cannot be used during the countdown, in the Tagged, Jailed or Chained state, while capturing, or while stumbling or stunned.
- A cooldown starts when the skill is activated.
- A skill aimed beyond its range is cast at its maximum range in the aimed direction.
- When a player is tagged, their ongoing skills end at once: TAMARAW!!!, HARUROT!, IYAK! see-through, IHIP! and SAGIP!. Objects they placed (the TALBOG! wall, the IYAK! decoy, the SUMBONG KITA! fake, powder clouds and powder patches) last their full time.

## Base stats
| Character | Role | Speed | Tag reach | Skill 1 cooldown | Skill 2 cooldown |
|---|---|---|---|---|---|
| JM "Botsog" | Protection | 4.6 m/s | 1.2 m | 12 s | 16 s |
| Nene | Deception | 5.0 m/s | 1.2 m | 14 s | 10 s |
| Tutoy | Movement | 5.4 m/s | 1.0 m | 8 s | 6 s |
| Nathan | Disruption | 5.0 m/s | 1.2 m | 10 s | 18 s |
| Inday | Rescue | 5.0 m/s | 1.2 m | 15 s | 12 s |

## Skill types
Some rules, such as Escape Protection, depend on the type of skill.

| Type | Skills |
|---|---|
| Offensive | TALBOG!, TAMARAW!!!, BUGA!, UBO! UBO! |
| Movement | HARUROT!, LUSOT!, IHIP! |
| Neither | IYAK!, SUMBONG KITA!, SAGIP! |

## JM "Botsog"
Role: Protection. Secondary role: Disruption.
Look: a big-hearted heavyweight in a tamaraw shirt with a towel on his shoulder. JM is his name and Botsog is his nickname.

Skill 1, TALBOG!
- JM jumps to a target point up to 6 metres away. He is airborne for 0.6 seconds, during which a landing marker warns enemies. While airborne he cannot steer, tag or be pushed, but he can still be tagged. If a wall or jail barrier blocks the straight path, he lands just before it.
- On impact, enemies whose centre is within 2.5 metres of the landing point are pushed 3 metres directly away from it.
- At impact, a crescent-shaped earth wall, 5 metres wide, rises 1.5 metres in front of the landing point in JM's aim direction, curving around him. It is solid for every player and lasts 4 seconds. Players can go around its open ends. Players it would overlap are moved to its nearer side.

Skill 2, TAMARAW!!!
- JM charges in his aim direction at 9 metres per second for up to 1.5 seconds, wrapped in a tamaraw-shaped aura. He turns at most 90 degrees per second. Pressing Skill 2 again ends the charge early.
- Each enemy he touches is pushed 2 metres sideways, away from his path, once per charge. Allies do not block him and are not affected.
- If he hits a wall or solid map object, the charge ends, enemies within 2.5 metres of him are slowed by 40 percent for 1 second, and JM is stunned for 0.8 seconds.
- JM cannot tag during the charge.

Passive, MAKAPAL!
- The first successful tag on JM breaks his guard instead of jailing him. The tagger does not stumble. The next successful tag jails him.
- After his guard breaks, JM cannot tag for 1.5 seconds.
- His guard returns after he spends 2 continuous seconds inside his own base ring. If his no-loitering limit is reached while his guard is broken, the push waits until his guard returns.
- A shield icon above JM shows everyone whether his guard is ready.
- A tag on JM while he is capturing jails him even if his guard is ready. His guard state is kept while he is in jail.

## Nene
Role: Deception. Secondary role: Rescue.
Look: pigtails, a pink dress and a handkerchief for fake tears.

Skill 1, IYAK!
- Nene leaves a crying decoy where she stands and turns see-through for 3 seconds. See-through means enemies see her at 25 percent opacity. Her outline and minimap marker stay.
- The decoy stands still and cries for 5 seconds. It always shows the same outline as Nene, so enemies cannot tell which one is real. It does not collide, and it shows on the enemy minimap as Nene.
- Tagging the decoy counts as a failed tag. The decoy stays.
- The real Nene can still be tagged. Her see-through effect ends early when she presses Tag, uses a skill, starts a capture or makes a rescue.

Skill 2, SUMBONG KITA!
- Nene places a fake alert at a point up to 12 metres away. For 3 seconds, enemies see a footstep sound icon there and hear running, as if an attacker were coming.
- The alert can only fake an attacker or a rescuer. It never fakes a score or a round announcement.
- If the point is within 8 metres of the jail holding Nene's teammates, enemies instead see a fake rescuer that looks like Nene. It runs from the point toward the chain tip, or the jail marker if there is no chain, at 5.0 metres per second for 3 seconds, then vanishes. It does not collide and cannot rescue. Tagging it counts as a failed tag.
- The fake rescuer casts no shadow, so observant players can spot it.

Passive, SALING-PUSA
- After 4 continuous seconds with no free enemy within 8 metres, Nene's footsteps go silent. Enemies cannot hear her or see her as an on-screen sound cue.
- The effect ends when a free enemy comes within 4 metres or Nene uses a skill. It can start again after another 4 seconds.

## Tutoy
Role: Movement. Secondary role: Rescue.
Look: a headband, a number 07 jersey and scraped knees. Tutoy is a Filipino nickname for a young boy, and pairs with Nene.

Skill 1, HARUROT!
- Tutoy runs at 9 metres per second for 1.2 seconds, with no turning limit.
- He leaves a wind trail that everyone can see. Each part of the trail lasts 2 seconds.
- He can still tag and be tagged during the burst.

Skill 2, LUSOT!
- Tutoy slides 4 metres over 0.4 seconds, in his movement direction, or his aim direction if he is not moving. If a low obstacle (a map object marked as vaultable) is in his path, he vaults over it as part of the slide.
- A normal slide stops early at players, walls and map edges. For 0.3 seconds after it ends he cannot tag.
- Perfect slide: a slide is perfect against an enemy if that enemy's tag would have hit Tutoy had he stayed where the slide started, and the slide starts on one of the last 6 ticks (0.1 seconds) of that tag's wind-up, including the tick the tag lands. The host counts ticks, so the window is the same at any frame rate.
- A slide started earlier in the wind-up is a normal slide.
- A perfect slide passes through that enemy, and their tag misses. That enemy is stunned for 0.6 seconds and cannot move, tag or use skills. The stun replaces the 0.5-second failed-tag stumble. If several enemy tags qualify, each of those enemies is stunned.
- A perfect slide flashes gold, plays a "LUSOT!" shout, and shows "PERFECT!" to both players and spectators.
- The stun is not a tag.
- A slide outside the window is a normal slide, and the enemy's tag is checked against Tutoy's new position as usual.
- Online play later uses the same 100-millisecond allowance as tags. If a tag and a perfect slide both fall inside it, the perfect slide wins.

Passive, DIRE-DIRETSO
- While Tutoy keeps moving without a sharp turn, his speed bonus grows evenly from 0 to 15 percent over 3 seconds, then stays at 15 percent.
- A sharp turn is a change of more than 45 degrees in movement direction within 0.5 seconds.
- The bonus resets to zero when he stops moving, turns sharply, presses Tag, starts a capture, or is pushed, slowed or stunned by an enemy skill.

## Nathan
Role: Disruption. Secondary role: Deception.
Look: a purple polo shirt, a sling bag and a sachet of powdered milk. The candy brand is Kimkim, invented for the game.

Skill 1, BUGA!
- Nathan inhales for 0.4 seconds and can keep moving. Enemies can see and hear the wind-up.
- He then blows a cone of milk powder, 5 metres long and 60 degrees wide, in his aim direction. Walls block it.
- Enemies caught are slowed by 30 percent for 1.5 seconds and leave a powder trail, visible to everyone, for 4 seconds. For those 4 seconds Nathan's team sees them everywhere: inside hiding spots, inside powder clouds and on the minimap.
- The cone does not tag and does not cancel a capture.

Skill 2, UBO! UBO!
- Nathan throws a powder packet up to 9 metres. It lands 0.5 seconds later, or at the first wall in its path, and bursts into a powder cloud with a 3.5-metre radius that lasts 5 seconds.
- Players outside the cloud cannot see anyone whose centre is inside it, on screen or on the minimap. Players inside see only within 2 metres of themselves. This applies to both teams, including Nathan.
- An enemy who stays inside for more than 1 continuous second coughs once. The cough shows them on Nathan's team's minimap and through the cloud for 2 seconds. They can still move, tag and use skills.
- Each enemy can cough only once per cloud.

Passive, MAY TIRA PA!
- After Nathan uses a skill, his next turn of more than 90 degrees in movement direction within 0.5 seconds drops a patch of leftover powder, 1 metre in radius, where he stands. Everyone can see it.
- The first enemy whose centre enters the patch makes a puff of powder and a loud footstep. This shows them on Nathan's team's minimap and through hiding spots for 2 seconds. The patch then disappears. It does not slow or tag.
- Only one patch can exist at a time. A new patch replaces the old one. A patch lasts until it is triggered or the round ends.

## Inday
Role: Rescue. Secondary role: Movement.
Look: a long braid, a white blouse, a red scarf and wide pants. The calm one.

Skill 1, IHIP!
- Inday stands still and blows wind in her aim direction for up to 4 seconds. This creates a lane 10 metres long and 3 metres wide, starting at Inday. The lane turns with her aim, and walls cut it short.
- Only free allies inside the lane get 25 percent extra speed. Enemies can cross it but get nothing.
- While blowing, Inday can aim but cannot move, tag or use another skill. She can still be tagged.
- Pressing Skill 1 again ends the skill. Being tagged, pushed or stunned also ends it. The lane disappears on the same tick.

Skill 2, SAGIP!
- For 4 seconds, Inday rescues a chain when her centre is 3 metres or less from the chain tip, or from the hand point of a lone anchor, instead of by touch. No button is needed.
- The straight line from Inday to the tip must be clear. Walls, solid map objects and the TALBOG! wall block it. Players and powder clouds do not.

Passive, TAKBO NA!
- After any rescue Inday makes, by touch or with SAGIP!, Inday and every teammate she freed get 20 percent extra speed for 2 seconds.
- This happens once per rescue, however many prisoners are freed. It does not stack with other speed bonuses such as IHIP!. The biggest bonus applies.
- Prisoners freed by Inday get 1 extra second of Escape Protection, for 5 seconds in total.

## Future characters
Later, after the finals, the roster grows to 10 characters, two per role. These are ideas only. Do not build them for the competition entry or the finals. Each new character is the champion of a different Filipino street game, so the roster also teaches laro ng lahi. When the roster reaches 10, each team bans one character before the draft.

| Role | Character | Street game | Idea |
|---|---|---|---|
| Protection | Bok | Sipa | Kicks a sipa that bounces off walls and knocks back the first enemy it hits |
| Deception | Ising | Taguan | Disguises as a map object, such as a bucket or a crate, while standing still |
| Movement | Pikoy | Piko | Three-hop dash over low obstacles that leaves chalk squares which speed up allies |
| Disruption | Lata | Tumbang Preso | Throws a slipper that briefly knocks over the target |
| Rescue | Biboy | Luksong Lubid | Throws a jump rope to the chain tip and pulls it 3 metres closer |

# Maps

## Rules for every map
- The playable area is 56 by 32 metres. Crossing its length takes 11.2 seconds at 5.0 metres per second.
- Both sides have the same layout, mirrored across the centre line that splits the 56-metre length. Everything that affects play is identical on both sides. Only decoration can differ.
- Each side has 3 base sites, 1 jail behind the bases and 2 spawn points. Spawn points sit outside every base ring.
- Each jail is 6 metres wide and 4 metres deep inside, with the jail marker at the middle of the side that faces the prisoners' home.
- Each map has a central clash zone, a lane with lots of cover, and a flank route.
- Each side has at least one high-ground spot. Standing on it zooms the camera out by 15 percent.
- Each map has one signature hazard. Other features that change movement, such as mud or speed strips, are terrain, not hazards. The Hazards setting turns off hazards only. Terrain always stays.
- The map is not split into halves for tagging. Each team's side is simply where its bases, jail and spawns are.

## Hiding spots (Taguan zones)
- Tarps, market stalls, laundry lines and trash piles create Taguan zones. Each zone is an area marked on the map.
- A player whose centre is inside a Taguan zone is hidden from enemies, on screen and on the minimap. They show again while any enemy is within 2.5 metres of them, and for 2 seconds after they press Tag or use a skill.
- Hidden players' footsteps can still be heard.
- Allies can always see each other.

## Barangay Court (the showcase map)
The open-air barangay basketball court.
- Centre: the basketball court itself, an open no-man's land. Barricades, tyre stacks and plastic chairs break up lines of sight.
- Cover lane: along the bleachers and the barangay stage, with tarps and banderitas.
- Flank route: the street alley along one edge, with parked tricycles.
- High ground: the stage on one side and a mirrored platform on the other.
- Base sites and jail: three sites per side, one near the court's free-throw line, one by the bleachers and one at the alley mouth. The jail sits at each end behind them, drawn as a chalk-and-hologram cage.
- Spawns: two per side, between the base sites and the jail, outside every base ring.
- Terrain: none.
- Hazard, Baha (flood): when 60 seconds of the round timer remain (at KABOOM if the timer is 1 minute), a yellow rainfall warning banner, styled like a weather bulletin, shows for 10 seconds. Then the whole alley flank route floods until the round ends, including sudden death. Water slows players by 35 percent and silences their footsteps. The banner does not use the name or logo of PAGASA or any real agency.

![Top-down layout of Barangay Court, 56 by 32 metres. Each side has three base sites, a jail at the far end and two spawns. The bleachers and stage form the cover lane along the top edge, the open court is the centre, and the alley with parked tricycles is the flank route along the bottom edge.](diagrams/court.png)

## Plaza
A Quiapo-style plaza with a church courtyard, church stairs, a pedestrian overpass, a covered bazaar and a market.
- Centre: the open square around a dry fountain, with benches and flower boxes as low cover that LUSOT! can vault.
- Cover lane: the covered bazaar along one long edge.
- Flank route: the market street along the other long edge, lined with fruit stalls.
- High ground: wide stairs on each side, a church stair on the Dilaw side and a mirrored town-hall stair on the Lila side. The pedestrian overpass crosses above the middle of the plaza and can be walked from both sides.
- Base sites and jail: three sites per side, at the fountain edge, under the bazaar arcade and beside the market stalls. The jail sits at each end behind them.
- Spawns: two per side, between the base sites and the jail.
- Terrain, speed strips: a player who crosses a pedestrian crossing while moving within 45 degrees of straight toward the enemy side gets 20 percent extra speed for 1.5 seconds. Crossing again restarts the 1.5 seconds.
- Hazard, market shutters: the bazaar shutters on both sides close every 30 seconds after KABOOM (at 0:30, 1:00, 1:30 and so on, including sudden death). Each closure lasts 10 seconds and cuts the main path to the jail. The shutters rattle for 2 seconds before each closure. Closed shutters are walls. Players under a closing shutter are pushed to its nearer side.

## Tambakan
A junkyard with garbage mounds, excavators, a trash maze and a dry waterway. Do not use the real place name Payatas anywhere in the game.
- Centre: a flat clearing around a rusted, wheel-less jeepney body that blocks the straight line between the bases.
- Cover lane: the trash maze along one long edge.
- Flank route: the dirt truck road along the other long edge.
- High ground: a garbage mound on each side, with a parked excavator on top.
- Base sites and jail: three sites per side, at the maze exit, beside the mound and at the truck road. The jail sits at each end behind them.
- Spawns: two per side, between the base sites and the jail.
- Terrain, mud: the dry waterway is a mud strip 4 metres wide that runs the full 56-metre length of the map, through the middle of each side. Mud slows players by 15 percent.
- Hazard, garbage truck (Trak ng Basura): twice per round, a truck drives the full length of the truck road (the flank route). It arrives at one third and two thirds of the round timer (40 and 80 seconds after KABOOM in a 2-minute round) and sounds its horn 3 seconds before. It takes 4 seconds to pass and alternates direction each time. It is a solid moving wall: anyone in its path is pushed to the nearer side of the road. It does not tag and does not run in sudden death.

# The match screen

## Screen layout (HUD)
| Position | Element | Details |
|---|---|---|
| Top centre | Score and sun timer | Team scores on each side of a sun that sinks toward a rooftop. Your team's score is on the left. Spectators see Dilaw on the left. The time left is shown as m:ss below the sun. In sudden death it counts down the 30 seconds and the TAKIPSILIM banner sits under it. In untimed sudden death (from the third draw) no number is shown. |
| Below the score | Point markers | Each team has one dot per point needed to win (the room's Points to win, 3 by default). A dot fills in that team's colour when the team scores. Drawn rounds add no dot. |
| Either side of the score | Prisoner tracker | Five portraits per team, your team on the left. Free is full colour, jailed is behind bars, and a linked-hands icon means the player is in a chain. A small bot icon marks a slot a bot controls, including a bot that took over a player. |
| Top right corner (Minimap position setting can move it to bottom right) | Minimap | Shows both active bases, both jails and all allies. Shows an enemy only while it is within 12 metres of an ally and not hidden in a Taguan zone or a powder cloud, or while Nathan's BUGA!, cough or powder patch reveals it to your team. |
| Left side | Tag feed | One line per tag (a JM guard break counts as a tag), rescue and capture, from both teams. For example "Nene HINULI si Nathan" (Nene tagged Nathan) and "Inday RESBAK x3", where x3 is the number of prisoners freed. A capture reads "[Name] NAKUHA ANG BASE!", a guard break "[Name] SINIRA ang bantay ni JM", and a lockdown "LOCKDOWN!" in the winning team's colour. Each line stays 5 seconds. At most 5 lines show. The Tag feed setting hides it. |
| Bottom centre | Skill 1 and Skill 2 | Icons with a cooldown sweep and the key label. They flash in your team colour when you touch your base. They are greyed out during the countdown. In jail they are replaced by the chain controls (see Jail screen). In Tradisyonal they are hidden. |
| Screen border | Danger warning | A thin orange border while any enemy within 10 metres can tag you. In sudden death it shows while any enemy is within 10 metres. The Danger border setting turns it off. |
| Beside the skills | Passive icon | Shows the passive's state. JM: guard ready or broken. Nene: footsteps silent or not. Tutoy: speed bonus as a fill from 0 to 15 percent. Nathan: powder patch ready to drop or not. Inday: TAKBO NA! speed boost with its 2-second timer. |
| Screen edges | Off-screen arrows | Point to your active base, to the enemy jail while any teammate is held there, and to any capture in progress by either team. An arrow shows only while its target is off screen. |

![HUD wireframe at 1920 by 1080. Top centre: the score with the sun timer and point dots, with each team's five prisoner portraits on either side. Top right: the minimap. Left: the tag feed. Bottom centre: Skill 1, Skill 2 and the passive icon. A thin orange border marks the screen edge while an enemy nearby can tag you.](diagrams/hud.png)

## Jail screen
When you are in jail, the skill icons at the bottom of the HUD are replaced by the chain controls:
- A prompt, shown only while pressing Interact would do something. Outside the chain it reads "Pindutin ang F para kumapit" (Press F to hold on). Inside the chain it reads "Pindutin ang F para bumitaw" (Press F to let go). The key shown matches the player's device and bindings.
- The chain length as linked prisoners out of prisoners in this jail, for example 2/3.
- The distance in whole metres from the chain tip to the nearest free teammate. With no chain, it is measured from the jail marker.

## Feedback for key events
| Event | What you see | What you hear |
|---|---|---|
| You touch your base | The ring flashes in your team colour and every enemy outline updates (see Reading Sigla on screen) | A short ding |
| An enemy who can tag you comes within 10 metres | The orange danger border appears. The enemy's outline is already orange. | A low warning tick, once each time the border turns on |
| An enemy you can tag comes within 10 metres | No change. Their outline is already cyan. | A light chime, once each time that enemy enters 10 metres |
| Successful tag | A "HULI!" stamp, and the target freezes for 0.8 seconds | A slap, the crowd's "Ooh!" and Kuya Tanod's "Huli!" |
| JM's guard breaks | The shield icon above JM cracks. JM does not freeze. | A crack sound |
| Failed tag | Your hero stumbles for 0.5 seconds | A whiff sound |
| Capture in progress | A shrinking chalk circle and a flash at everyone's screen edge | A rising megaphone tone everyone hears |
| Capture success | 0.5 seconds of slow motion, confetti and a "NAKUHA!" stamp at the pole, then the result banner (see Between rounds) | A victory jingle |
| Rescue | The chain breaks free and "RESBAK!" appears | Kuya Tanod, the rescuer and the freed teammates shout "RESBAK!" |
| Total jail lockdown | The jail gate slams and "LOCKDOWN!" appears | A gate clang and a drumroll |
| 30 seconds left | The sky reaches full orange | The music switches to a faster version of the loop |
| Sudden death starts | The sky turns deep red, every enemy turns cyan and the TAKIPSILIM banner appears under the sun timer | A long whistle and "Takipsilim! Kahit saan, pwede!" |
| Round ends by the timer (sunset win, sudden death win or draw) | The screen dims, then the result banner (see Between rounds) | A mother calls "Uwi na! Kakain na!" |

## Team communication
Pings are seen and heard only by your team. Jailed players can ping. Each player can send at most 3 pings in any 5 seconds. Extra presses are ignored. A tap is a press shorter than 0.25 seconds. A longer hold opens the ping wheel.

Smart ping (tap the ping key) pings the target under the cursor. With a gamepad it pings the first target along the aim direction within 20 metres, or the ground at that point. If targets overlap, the order is enemy, base, jail, ground. The ping shows a marker in the world and on the minimap for 4 seconds, with its line as text and a short voice bark.
- On the enemy base: "Atake dito!" (Attack here)
- On your own base: "Depensa!" (Defend)
- On a visible enemy: "Kalaban dito!" (Enemy here)
- On the enemy jail, where your teammates are held: "Resbak tayo!" (Let's rescue)
- On the ground, or on your own jail: "Punta dito." (Go here)

Ping wheel (hold the ping key): Atake!, Depensa!, Resbak!, Ingat! (Careful), Ako bahala (I've got it), Aatake ako (I'm going in), Bantay ako (I'm guarding) and Salamat! (Thanks). Point at a line with the mouse or right stick and release the key to send it. Releasing in the centre sends nothing. A wheel line shows above your hero and next to your portrait in the prisoner tracker for 4 seconds, with a voice bark. It places no world marker.

Chat:
- There is no voice chat in any build.
- The competition build and the finals build have no text chat.
- Text chat is planned for online play (Later): filtered team chat on by default, and all chat, which reaches both teams, off by default. Ping wheel lines always work, even with chat off.

## Options during a match
Escape opens an overlay. In vs Bots and the tutorial the match pauses behind it. In a Custom Room the match keeps running, your hero gets no input and the idle timer keeps counting.
- BUMALIK (Resume).
- Settings: Audio, Controls, Video and Accessibility can be changed. Gameplay and Language, network and account can only be viewed. A change to Capture input applies from the next capture.
- UMALIS (Leave match): asks "Aalis ka na?" (Leaving?) with Oo (Yes) and Hindi (No). In vs Bots and the tutorial, Oo ends the match with no result and returns to the menu it was started from. In a Custom Room, Oo counts as a disconnect (see Disconnects and idle players). If the host leaves, the match ends for everyone.

## Between rounds
When a round ends, gameplay stops. Players cannot move or act until the next countdown, but can hold the scoreboard. After a capture, its 0.5 seconds of slow motion plays first.
1. Result banner, 2 seconds, over the stopped scene, in the winning team's colour: "NAKUHA ANG BASE!" (Base captured), "LOCKDOWN!", "UWI NA!" (sunset win) or "TAKIPSILIM!" (sudden death win). A draw shows "TABLA! Ulit!" (Draw, play again) in white.
2. Freeze frame, 2 seconds: the camera zooms in on the round-ending moment in the stopped scene. That is the capturing player at the pole, the final lockdown tag, the deciding sudden death tag or capture, or, after a sunset win, the jail holding the losing team's prisoners. It is the live scene paused, not a replay recording. A draw skips this step.
3. Score update and the round's best player card, 3 seconds. The best player is the player on the winning team who earned the most Impact points in that round. Ties go to more rescues, then to the lower slot number. A draw skips the card.
4. The reset between rounds is applied, the camera cuts to gameplay, the 3-second frozen countdown runs, and KABOOM starts the next round.

Steps 1 to 3 take 7 seconds, or 5 seconds after a draw. After the round that wins the match, step 3 is followed by the Results screen instead of step 4.

## Disconnects and idle players
- Disconnect: the host treats a player as disconnected after 5 seconds with no packets. A bot then takes over the hero (see Taking over for players). The player can rejoin until the match ends. A returning player sees a "Bumalik sa laro" (Rejoin) banner on the Home screen. Rejoining hands the hero back at once, in its current state.
- Idle player: input is any key, button, mouse movement or stick movement past the dead zone. After 30 seconds without input the player sees "Nandiyan ka pa ba?" (Are you still there?). After 60 seconds a bot takes over. Any input hands control back at once. The idle timer counts only while the player is free and the round is running, so never in jail, in the countdown or between rounds. Idle takeover applies in Custom Rooms only.
- No surrender: there is no surrender option. Every match is played until one team reaches the points to win.
- Host leaves (LAN): the match ends for everyone with the message "Umalis ang host" (The host left), then everyone returns to Home. No results are shown or saved. A player who loses the connection to the host sees the same message.

# After the match

## Results screen
Six steps. Each player can skip a timed step with the confirm button. Skipping affects only that player's screen.

The competition build shows steps 1, 2 and 3, with the buttons LARO ULIT (Play again) and BUMALIK SA TAMBAYAN (Back to Home) on the step 3 screen. Saludo (step 4) and the Tansan and challenge progress in step 5 arrive with the finals build. Experience and hero mastery in step 5 come later. I-REPORT comes later, with online play.
1. Win or loss, 4 seconds: "PANALO!" (Win) or "TALO!" (Loss) with the final score. The winners do victory poses at their base. The losers sit on the curb with their chins in their hands. The scene is playful, never humiliating.
2. Awards, 6 seconds: one MVP card per team, then up to three badges.
3. Scoreboard with tabs: Impact, Tags, Rescues, Captures, Assists and Saves. It stays until the player presses a button.
4. Saludo, 15 seconds (finals build): each player can give one Saludo to one other human player in the match, on either team. Not to themselves and not to bots. The choices are Galing! (Skilled), Kalaro (Team player) and Mabait (Good sport).
5. Rewards, 5 seconds (finals build): Tansan and challenge progress. Experience and hero mastery are added later.
6. Buttons: LARO ULIT (Play again), BUMALIK SA TAMBAYAN (Back to Home) and I-REPORT (Report a player, Later). PANOORIN ANG REPLAY (Watch replay) comes later.

LARO ULIT in vs Bots starts a new match with the same settings, at the map roulette. In a Custom Room it returns that player to the room lobby with Ready cleared. BUMALIK SA TAMBAYAN leaves the room. If the host leaves the room, it closes for everyone.

## Impact score and MVP
| Action | Impact points |
|---|---|
| Base capture | 10 |
| Rescue, per prisoner freed | 3 |
| Tag, including breaking JM's guard | 2 |
| Saved: tagging an enemy who was holding a capture, or who was within 5 metres of the tip of a chain holding their teammates | 2 extra |
| Assist: your skill slowed, pushed or revealed an enemy in the 3 seconds before a teammate tagged that enemy, or before a teammate's rescue or capture while that enemy was within 10 metres of the teammate. At most 1 assist per teammate action. Body blocking does not count. | 1 |
| Clutch: a capture or rescue while you are your team's last free player | 5 extra |

Each team gets its own MVP: the player with the highest Impact score on that team. The winning MVP card is gold and shown first. The losing team's MVP card is silver and labelled "Bida ng Talo" (Star of the losing side). If two players on a team tie, the one with more rescues wins MVP, then the one with more captures, then the lower slot number. Bots can be MVP. Stats belong to the slot, including those earned by a bot that took over a player.

## Badges
| Badge | Given for |
|---|---|
| Best Resbak | Most prisoners freed |
| Pader (Wall) | Most tags within 10 metres of your own active base pole |
| Pasaway (Troublemaker) | Most capture attempts. Every capture started counts, whether it succeeds or not. |
| Kidlat (Lightning) | The tag with the longest chase. A chase is the unbroken time before the tag during which the target was within 10 metres of the tagger and the tagger could tag them. |
| Nemesis | Two enemy players whose tags on each other total 3 or more in the match, with each tagging the other at least once |

At most three badges are shown, picked in the table's order. A badge needs a count of at least 1 and goes to one player, or one pair for Nemesis. A tie goes to the player with more Impact points. If still tied, the badge is not given.

# Progression and rewards

## Account level
- Scope: Later. Not in the competition entry or the finals build.
- Every match gives experience. Wins, rescues and captures give more. Amounts are set when levels are built.
- Levels unlock titles, profile frames and Tansan. Level 10 unlocks Ranked when online play arrives.

## Hero mastery
- Scope: Later. Not in the competition entry or the finals build.
- Each hero has its own mastery experience.
- Mastery milestones unlock that hero's skins, banter lines and victory poses.
- Mastery badges are Bronze, Silver and Gold (Alamat).

## Tansan
- Tansan (bottle caps) is the only currency.
- Scope: finals build. The competition entry has no Tansan.
- Players earn it only by playing. From the finals build: 10 per match played, 10 more for a win, and each challenge's listed reward. Level-ups add Tansan once levels arrive (Later).
- There are no paid items.

# Locker and customization

## Locker screen
- Left: category tabs.
- Centre: the hero on a turning stand.
- Right: a grid of items. Locked items show what unlocks them.
- Buttons: GAMITIN (Equip), BILHIN (Buy with Tansan) and SILIPIN (Preview in action).

## What players can customize
| Category | Applies to | Examples |
|---|---|---|
| Skins | Each hero | Pambahay (house clothes), School Uniform, Fiesta, Tag-ulan (rain gear), Simbang Gabi |
| Tag flares | Account | Chalk marks left where you tag someone: a slipper print, a star, a "HULI!" stamp |
| Banter lines | Each hero | Extra voice lines for the banter wheel |
| Victory poses | Each hero | Used on the loading and results screens |
| Chain style | Account | How your hands glow when you link up in jail |
| Profile | Account | Avatar, frame and title, for example "Hari ng Resbak" |
| Tambayan | Account | Decorations for the sari-sari store on the Home screen |

## Scope
The competition build has no Locker. Every hero uses its default skin and no tag flare is drawn. The finals build Locker has two tabs only: Skins, with one extra skin per hero, and Tag flares, with three flares. From the finals build, every player also owns one default flare. Both are bought with Tansan. Prices are set with the finals build. Every other category in the table above comes later.

# Settings

## Rules for every settings tab
- Every change applies immediately. A Display mode or Resolution change reverts after 10 seconds unless the player confirms it.
- Sliders move in steps of 1 for 0 to 100 values, 5 percent for percent values, and 0.1 for mouse sensitivity.
- Each tab has an IBALIK SA DEFAULT (Reset to default) button.
- Settings are saved in the local save file in Godot's user:// folder, with the player name.

## Gameplay
| Setting | Options | Default |
|---|---|---|
| Danger border | On, Off. Off hides only the orange screen border. Enemy outlines always show. | On |
| Skill casting | Quick cast (the skill fires toward the aim on key press), Show aim then release (holding the key shows the aim indicator, releasing fires it) | Quick cast |
| Tag assist (gamepad) | On, Off | On |
| Camera shake | 0 to 100 percent. Forced to 0 percent and greyed out while Reduce camera motion is on. | 70 percent |
| Minimap size | Small, Medium, Large | Medium |
| Minimap position | Top right, Bottom right | Top right |
| Tag feed | On, Off | On |
| All chat (online play only) | On, Off | Off |
| Team colours | Fixed (Dilaw yellow, Lila purple), Relative (your team is always yellow and the enemy purple, on this PC only, with team names unchanged) | Fixed |

## Controls
| Setting | Options | Default |
|---|---|---|
| Key bindings | Change any action | See Controls |
| Gamepad bindings | Change any action | See Controls |
| Mouse sensitivity | 0.1 to 3.0. Scales the speed of the in-match aim cursor. | 1.0 |
| Stick dead zone | 0 to 30 percent | 10 percent |
| Vibration | On, Off | On |
| Button icons | Xbox, PlayStation, Generic | Detected from the connected gamepad. Generic if unknown. |

## Video
| Setting | Options | Default |
|---|---|---|
| Display mode | Windowed, Borderless, Fullscreen | Borderless |
| Resolution | Resolutions the monitor supports. Used in Windowed and Fullscreen. Borderless always uses the monitor resolution. | Monitor resolution |
| Render scale | 50 to 100 percent | 100 percent |
| VSync | On, Off | On |
| Frame rate cap | 30, 60, 120, Unlimited | 60 |
| Quality preset | Mababa (Low): Shadows Off, Effects Low, Render scale 75 percent. Katamtaman (Medium): Shadows Low, Effects Low, Render scale 100 percent. Mataas (High): Shadows High, Effects High, Render scale 100 percent. Custom: set automatically when the player changes Shadows, Effects or Render scale. | On first launch, Mataas on a discrete GPU, Katamtaman otherwise |
| Shadows | Off, Low, High | Follows preset |
| Effects | Low, High | Follows preset |
| Brightness | 0 to 100 | 50 (no change) |
| Interface size | 80 to 130 percent | 100 percent |

## Audio
| Setting | Options | Default |
|---|---|---|
| Master volume | 0 to 100 | 80 |
| Music | 0 to 100 | 60 |
| Sound effects | 0 to 100 | 80 |
| Voices and banter | 0 to 100 | 80 |
| Announcer (Kuya Tanod) | 0 to 100 | 80 |
| Enemy banter (finals build) | On, Off. Off mutes banter from the enemy team. | On |
| All banter (finals build) | On, Off. Off mutes every banter line and greys out Enemy banter. | On |
| Output device | System devices | System default |

## Accessibility
| Setting | Options | Default |
|---|---|---|
| Colour mode | Default, Deuteranopia, Protanopia, Tritanopia, High contrast | Chosen in first-time setup |
| Subtitles | On, Off | On |
| Subtitle size | Small, Medium, Large | Medium |
| Speaker names in subtitles | On, Off | On |
| Sound cues on screen | On, Off | Off |
| Reduce flashing | On, Off | Off |
| Reduce camera motion | On, Off | Off |
| Capture input | Hold, Toggle | Hold |

## Language, network and account
| Setting | Options | Default |
|---|---|---|
| Interface language | Filipino with English labels, English, Filipino | Filipino with English labels |
| Show ping and packet loss | On, Off. Shows both as small text in the top left corner during a match. | Off |
| Region (online play only) | Automatic, manual list | Automatic |
| Change player name | 3 to 16 characters, with the same word filter as first-time setup. Any time outside a room in the competition build. Once every 30 days when online accounts arrive (Later). | |
| Who can invite you (online play only) | Everyone, Friends only, Nobody | Everyone |
| Blocked players (online play only) | List with Unblock buttons | |
| Delete local data | Asks for confirmation, deletes the local save (name, settings, and unlocks once they exist), then restarts at first-time setup | |

Settings marked online play only are greyed out with the "Malapit na" tag until online play arrives. Settings marked finals build are hidden in the competition build. There is no voice language setting. All voices, including Kuya Tanod, are in Filipino or Taglish, and there are no Bisaya lines. A Credits button at the bottom of the Settings menu opens the Credits.

# Accessibility

## Principles
The final judging criteria ask for colours that are "accessible and inclusive for all types of users". Every feature below is in the competition entry.

## Features
- Tag outlines always use shape and icon as well as colour: an open hand or an exclamation mark.
- The team colours, yellow and purple, are a colour-blind-safe pair.
- Five colour modes: Default, Deuteranopia, Protanopia, Tritanopia and High contrast. Each mode replaces the outline colours (cyan, orange and white), the danger border colour and the two team colours with its own palette. High contrast also puts a dark backing behind interface text.
- Subtitles for every voice line and announcer call, with speaker names and three sizes.
- Sound cues on screen (optional): an icon at the sound's direction for footsteps of enemies within 10 metres who are not visible on screen, for captures in progress and for coughs. Sounds the game hides, such as Nene's silent footsteps or footsteps in Baha water, show no icon.
- Reduce flashing: nothing flashes more than 3 times per second, the KABOOM and capture screen-edge flashes become a steady glow, and no confetti is shown.
- Reduce camera motion: no camera shake, no slow motion, and camera zooms such as high ground and the freeze frame become instant cuts.
- Capture input: Hold or Toggle (see Capturing a base).
- Interface size from 80 to 130 percent.
- Every menu works with the keyboard alone and with the gamepad alone.
- Interface text uses a clear sans-serif font at 18 pixels or larger at 1080p and 100 percent Interface size, with a contrast ratio of at least 4.5 to 1 against its background.

# Friends and online play

## Status
Everything in this section is Later. It is not in the competition entry or the finals build. Values described as small, similar or about are placeholders, to be set before online play is built.

## Barkada (party and friends)
- A friends list with status: Online, Nasa laro (In a match) or Offline.
- Invite friends from the list or with a 6-character party code.
- The party leader picks the mode. Members press Handa (Ready).

## Classic
- Parties of 1 to 5 players.
- Players are matched by a hidden skill rating and by ping. Teams are balanced by average skill rating, and parties are matched against parties of a similar size where possible.
- After 90 seconds in the queue, players are asked "Laro muna kasama ang bots?" (Play with bots while you wait?).
- When a match is found, every player sees "MAY LARO NA!" (Match found!) with TARA! (Accept), HINDI MUNA (Decline) and a 10-second timer. If anyone declines, everyone who accepted goes back to the front of the queue.

## Ranked
Ranked has two queues, inspired by Splatoon 3's Anarchy Battles.
- Ranked Open: play solo, or with friends in a party of 2 or 5, one match at a time. A win gains points and a loss costs points.
- Ranked Series: solo only. A player pays a small entry cost in ranked points, then plays a run that ends at 5 wins or 3 losses. The more wins in the run, the bigger the reward. A 5-win run also gives a bonus.
- Parties of 3 or 4 are not allowed in Ranked, so solo players are never stacked against an uneven party.
- Role queue: before queuing, each player picks a main role and a backup role, or Kahit Ano (Fill). A Fill player gets a small bonus to ranked points when they win.
- Each team always has one player per role, and each player picks within their role in the draft.
- 5 placement matches, then a visible tier.
- Leaving a match, leaving during the draft and repeated idling give growing queue bans and ranked point losses.

## Ranked tiers
| Tier | Name | Meaning |
|---|---|---|
| Placement | Saling-pusa | Just tagging along |
| 1 | Batang Kalye | Street kid |
| 2 | Kalaro | Real player |
| 3 | Siga | Tough one |
| 4 | Bida | Star |
| 5 | Idolo | Idol |
| 6 | Alamat ng Barangay | Barangay legend, the top 100 players |

Tiers 1 to 5 each have three divisions. A season lasts about 8 weeks, and ranks partly reset at the start of each season.

# Bots

## Behaviour
Bots follow the same rules as players and read the same outline states. A bot is named after its hero with a "(Bot)" tag. In Tradisyonal, bots use no skills. Each bot uses one of five behaviours:
1. Bantay (Guard): stays within 8 metres of its own pole, outside the base ring, and tags attackers it can tag.
2. Atake (Attack): goes for the enemy base when no enemy that can tag it is within 8 metres of its path, then captures.
3. Pain (Bait): touches its base, then runs at defenders who left their base earlier, to pull them away from their base so a teammate can slip past.
4. Resbak (Rescue): goes for the chain tip of the jail holding its teammates.
5. Kapit (Chain): when jailed, joins the chain. A bot at the tip points it toward the nearest free teammate.

Every 1 second each team reassigns its free bots in this order. If any teammate is jailed, the free bot nearest the enemy jail becomes Resbak. The free bot nearest its own base becomes Bantay. The remaining free bots alternate Atake and Pain, starting with Atake. Jailed bots are always Kapit.

Any free bot that is not capturing or rescuing runs to touch its own base when an enemy that can tag it comes within 6 metres. Easy and Normal bots sometimes ignore this rule (see Difficulty).

## Difficulty
| Setting | Reaction time | Tag judgement | Skill use |
|---|---|---|---|
| Madali (Easy) | 0.6 seconds | Ignores the 6-metre retreat rule 30 percent of the time | Uses a skill on 20 percent of valid chances |
| Katamtaman (Normal) | 0.35 seconds | Ignores the 6-metre retreat rule 10 percent of the time | Uses a skill on 50 percent of valid chances |
| Mahirap (Hard) | 0.2 seconds | Never ignores the retreat rule, and uses Pain only when a teammate is within 15 metres of the enemy base | Uses a skill on 90 percent of valid chances |

## Taking over for players
Bots send the same inputs as players. A bot takes over a disconnected or idle player at once, with no pause, and hands control back the moment the player returns.
- The hero keeps its position, jail and chain state, cooldowns and last base touch time.
- A capture in progress is cancelled and its progress resets to zero, as if Interact were released.
- A chained prisoner stays in the chain. A bot at the tip steers it toward the nearest free teammate.
- The bot uses the room's Bot difficulty.
- The player's name stays on the slot, with a bot icon in the prisoner tracker.

# Spectating and esports

## Spectator view
Competition entry: only the clean camera. Pressing F10 hides the whole HUD on that PC, for recording the trailer and gameplay video. It works in every mode and does not affect other players.

Finals build: spectator slots and the caster tools below.
- A Custom Room can have up to 2 spectator slots.
- Spectators can use a free camera or follow any player. Number keys 1 to 5 jump to Dilaw's slots and 6 to 0 to Lila's slots.
- The caster overlay shows both teams' cooldowns, the prisoner tracker, capture progress, the seconds since each player last touched their base, and a line between any two opponents within 10 metres showing who can tag whom.
- An automatic director camera picks its shot in this order: a capture in progress, then a chain tip with a free teammate within 10 metres, then the closest pair of opponents where one can tag the other. Each shot lasts at least 3 seconds.
- A 20-second spectator delay is on whenever Tournament mode is on, and off otherwise. It stops spectators from helping players.

## Tournament mode
Finals build. A Custom Room setting. The host is the admin.
- Map veto replaces the map roulette. Dilaw bans a map, then Lila bans a map, and the remaining map is played. The player in each team's first slot makes the ban, with 20 seconds. If time runs out, a random map is banned. With more than 3 maps, the teams take turns banning until one map is left.
- Base selection uses the room's Base selection setting.
- Each team gets one 60-second tactical pause per match. Any player on the team calls it from the Escape overlay during steps 1 to 3 of Between rounds. It runs before the countdown. The host can pause at any time for technical problems, which freezes the round timer and every player, and unpauses with the same control.
- The host cannot change room settings once the match starts.

# Art and audio direction

## Art style
- Bright, stylised 3D with chunky kid proportions, matching the character lineup art.
- Warm golden afternoon light. It shifts gradually to orange between KABOOM and 30 seconds left, then stays orange. Sudden death turns the sky deep red.
- The interface looks like chalk on asphalt, like playground markings. Base rings, outlines and interface frames are chalk-drawn. Headings are hand-lettered. Menus use sari-sari store signage.

## Making the Barangay Court feel alive
Part of the Barangay Court art pass for the competition entry. None of these props collide with players, block sight lines or create Taguan zones. Tarps and laundry lines that create Taguan zones are separate gameplay objects.
- Spectating kids on the bleachers and the fence. They cheer at captures, rescues, lockdowns and perfect slides.
- A sari-sari store at the edge of the court with a radio playing.
- Banderitas strung across the court, moving in the wind.
- Laundry lines, potted plants and parked bicycles along the alley.
- A stray cat and dog wandering in the background.
- Chalk drawings and old patintero lines on the court floor.
- Background figures are mostly kids, with a few adults such as a tindera.

## Music
- An upbeat original OPM-style loop with kulintang and rondalla sounds.
- A chase layer fades in over 1 second while an enemy you can tag is within 10 metres of you, and fades out over 1 second after.
- At 30 seconds left the music switches to a faster version of the loop.
- Short jingles for captures and rescues.

## Voices and sound
- Every hero has Taglish voice lines for tagging, being tagged, rescuing, being freed, capturing, winning a round and losing a round. The competition entry has at least one line per event per hero. Banter lines arrive with the banter wheel in the finals build.
- All voice lines are in Filipino or Taglish. There are no Bisaya lines.
- Kuya Tanod announces through a megaphone effect.
- A mother's voice calls "Uwi na! Kakain na!" when a round ends by the timer: a sunset win, a sudden death win or a draw.
- Background sounds: tricycles, a sari-sari store radio, roosters, a distant basketball, and rain on roofs during the flood hazard.

# Sportsmanship and banter

## Banter wheel
Finals build. In the competition build the banter key does nothing.
- Players hold the banter key to open a wheel of their hero's voice lines, such as "Habol!", "Kulelat!" or "Bago paa ko!", and release on a line to play it.
- Each player can play at most 3 banter lines in any 10 seconds. Extra picks are ignored.
- A banter line plays from the hero with a subtitle. Every player in the match hears it unless the listener's Enemy banter or All banter setting mutes it.
- Every line must be playful teasing, never an insult. The competition rules forbid hateful or demeaning content.

## Tag flares
Finals build. A chalk mark left on the ground where you tag someone. It fades after 10 seconds. Players choose their flare in the Locker. The competition build draws no mark.

## Nemesis
Two enemy players become Nemesis when their tags on each other in one match total 3 or more, with each tagging the other at least once. The results screen shows it as the Nemesis badge (competition entry). From the finals build, each also sees a Nemesis icon above the other's head, and the first time they come within 10 metres of each other after that, a special sound plays for both.

## Saludo
Finals build. See step 4 of the Results screen. Each player's received Saludos are saved on their own PC and shown on their Profile.

## Safety tools
- There is no voice or text chat. Players can only send fixed ping lines, plus fixed banter lines from the finals build.
- If text chat arrives with online play (Later), all chat is off by default and team chat is filtered for offensive words.
- When online play arrives, report and block are one click away on the scoreboard and the results screen. On LAN the players are in the same room, so the competition build has neither.

# Technical notes for Godot

## Engine and rendering
- Godot 4, GDScript only. DEFAULT: use the newest stable Godot 4 release available on 16 October 2026 and do not change version before 27 November.
- Forward+ renderer. Do not use Forward+-only features (SDFGI, VoxelGI, volumetric fog), so switching to the Mobile renderer stays a one-setting change if a demo PC cannot hold the target.
- Target: 60 frames per second at 1920 by 1080, Medium preset, 10 heroes on screen, on the slowest PC the team will demo on.
- 1 Godot unit is 1 metre. Y is up.
- Export: Windows Desktop, x86_64, with the .pck embedded in the .exe.

## Networking for the competition build
- Transport: Godot's high-level multiplayer API over ENetMultiplayerPeer on UDP port 7777.
- Topology: a listen server. One player's PC hosts the match and also plays. Up to 9 remote players, plus 2 spectators from the finals build.
- vs Bots, the tutorial and Bakuran run the same host code on an OfflineMultiplayerPeer, so there is one code path. In these modes the pause menu stops the host tick.
- The host runs the whole simulation: movement, base touches, the tag rule, tags, captures, jail, chain, rescues, skills, hazards, bots, timers, score and every random roll (map, bases, draft auto-picks). Clients send input and draw what the host sends. They never decide an outcome.
- Tick: the host simulates 60 ticks per second in _physics_process, whatever the frame-rate cap. Every duration is stored as a tick count: seconds times 60, rounded.
- The host refuses a client whose game version differs from its own and shows the reason.

## What clients send
- Every tick, an input frame on an unreliable ordered channel: move vector, aim direction and held buttons (Interact).
- Button presses (Tag, Skill 1, Skill 2, Interact tap, ping, ping wheel choice) as reliable messages. The host applies them on its next tick.
- The host uses the newest input frame from each client. If none arrived for a tick, it reuses the last one.
- Bots produce the same input frames on the host.
- Lobby and draft actions (team mat, Ready, hover, pick, host settings) as reliable requests. The host checks them and broadcasts the result.

## What the host sends
- Every tick, one snapshot to all clients on an unreliable ordered channel. Per player: position, facing, state (free, winding up, stumbling, stunned, capturing, jailed, chained, protected, hidden), last base-touch tick, skill cooldowns and passive state. Per match: capture progress, chain order in each jail, active skill objects, hazard state, round timer, round phase and score.
- Events as reliable messages, each with its host tick: tag, failed tag, Sabay, guard break, perfect slide, rescue, capture start, cancel and success, lockdown, sudden death start, round end, hazard warning and ping. Clients play the effect and sound when they render that tick.
- Phase changes (load map, roulette results, draft state, countdown, results) as reliable messages.
- Clients draw every character, including their own, by interpolating snapshots 2 ticks (about 33 milliseconds) behind the newest one. There is no client prediction. The local player's facing follows the mouse at once. Their position does not.
- Clients pick outline colours from the snapshot's last base-touch ticks, using the same can_tag function as the host.
- Every client gets the same snapshot, including hidden players, which one is Nene's decoy, and fake alerts. Each client hides what its team should not see.

## The tag rule on the host
- The host stores last_touch, a tick number, for each player. On every tick a player's centre is inside their own active base ring and they are not being pushed, last_touch is set to that tick. A tick on which they are pushed, by a skill or a hazard, does not count.
- At KABOOM every player's last_touch is set to the KABOOM tick. A freed prisoner's last_touch is set back to the KABOOM tick.
- Whatever tag rule is chosen (Sigla, duel, Sabay) lives in one function, can_tag(tagger, target, tick). It also returns false for chained prisoners and players under Escape Protection, and true for any free enemy during sudden death. Nothing else in the code reads last_touch to decide a tag.
- Times in the rule are tick counts: the 0.3-second duel window is 18 ticks, the 0.15-second wind-up is 9 ticks.
- The host checks can_tag on the tick the tag lands, not the tick it was pressed.
- Tutoy's perfect slide: the host compares the tick LUSOT! was applied with the landing tick of each enemy tag aimed at him.

## How the host resolves one tick
The host runs these steps in this order every tick. Results found in the same step happen at the same moment.
1. Inputs: apply the newest input frame and the queued presses of every player and bot.
2. Actions: a Tag press starts a 9-tick wind-up. Skill and Interact presses start or cancel skills, captures and chain joins.
3. Movement: move players and skill objects, then apply pushes, slows, terrain and hazards.
4. Base touches: update last_touch as described above, and the no-loitering timers.
5. Tags: for each tag whose wind-up ends this tick, run the hit test, then the perfect-slide check, then can_tag, all against the state after step 4. Store the results without applying them. If two enemies land valid tags on each other this tick, both stumble and nobody is jailed (Sabay).
6. Rescues: find every free player touching a chain tip, and every valid SAGIP! ranged rescue, against the state after step 4. A player tagged in step 5 still counts as free here.
7. Apply steps 5 and 6 together: tagged players go to jail, rescued chains go free and get Escape Protection.
8. Captures: cancel any capture whose attacker was tagged this tick, let go of Interact, or is more than 1 metre from the pole. Add 1 tick to the others. A capture that reaches 90 ticks succeeds.
9. Round end: check captures, then total jail lockdown (after step 7, so a same-tick rescue prevents it), then the timer. In sudden death, a tag applied in step 7 (a JM guard break counts) or a capture ends the round. If both teams meet an end condition on the same tick, the round is a draw.
10. Send this tick's snapshot and events.

## Disconnects and rejoin
- Each install has a player_id, a random UUID made on first launch and kept in the save. The host keys every slot by player_id.
- The host treats a client as disconnected when ENet reports it, or after 5 seconds with no packets. A bot takes the slot on the next tick.
- Idle players: the host counts ticks with no input change. The warning shows at 30 seconds and a bot takes over at 60 seconds. Any input gives control back.
- Rejoin: if a client connects with a player_id that has a slot in the running match, the host sends the current phase and a full snapshot, and the player takes control back from the bot on the next tick. The Home screen Rejoin banner shows while the host's discovery broadcast still lists that match. After a restart, joining the room from the LAN browser rejoins the same way.
- New players can join only in the room lobby.
- If the host leaves, the match ends for everyone with "Umalis ang host". There is no host migration.

## Finding a room
- The host broadcasts a discovery packet once per second on UDP port 7778: room name, room code, map, player count, whether a PIN is needed, game version and game port.
- The LAN browser lists rooms from these packets. The ping column is the round trip of a probe sent to the host's discovery port.
- Room code: 6 characters from A to Z and 2 to 9, made by the host. The client finds the room by matching the code in discovery packets, so a code only works on the same LAN.
- Direct IP: the client connects to the typed IPv4 address on port 7777.
- PIN: the host checks it on join and refuses a wrong one.
- Windows Firewall asks to allow the game the first time a PC hosts. Allow it on private networks, and test this on the judging-day PCs.

## Online play later
- Dedicated Godot servers running headless.
- Client prediction for movement, and a 100-millisecond rewind for tags and perfect slides that favours the tagger. A tag and a perfect slide inside the same window go to the slide.
- Per-team snapshots that leave out what that team cannot see.
- Matchmaking, player accounts and saves on a server.

## Save data
- Location: user://. Turn on application/config/use_custom_user_dir with the name RESBAK, so on Windows the files are in %APPDATA%\RESBAK.
- settings.cfg, a Godot ConfigFile. One section per Settings tab (gameplay, controls, video, audio, accessibility, language_network), one key per row of the Settings tables. Key and gamepad bindings are stored per action.
- profile.json: save_version, player_id, player_name, setup_done, tutorial_lessons_done, matches_played (drives the first-5-matches hints), last_hero (shown in the Kanto), home_hero (shown on the bench), last_map (so roulette never repeats a map) and totals: matches, wins, tags, rescues, captures and MVPs.
- The finals build adds to profile.json: tansan, owned_items, equipped items per hero, tag flare, challenges with their dates and progress, saludos_received, title and tutorial_reward_claimed.
- Settings are written on every change. The profile is written after first-time setup, each tutorial lesson, each match and each name change.
- Each write goes to a .tmp file that is then renamed over the old file. A file that fails to load is renamed to .bak and defaults are used.
- Delete local data removes both files and returns to first-time setup.
- Each PC saves only its own player. After a match the host sends each client its own stats.
- No encryption and no cloud. Online accounts come later.

## Project structure
| Part | What it holds |
|---|---|
| Autoload Net | ENet peer, discovery, room code, connect, disconnect and rejoin |
| Autoload Save | Loading and writing settings.cfg and profile.json |
| Autoload Session | Room settings, team slots, lineup, map, bases and score, carried between scenes |
| Autoload Audio | Buses (Master, Music, Effects, Voices, Announcer) and the announcer queue |
| Tuning data | tuning.tres holds every value in Numbers at a glance. One HeroData .tres per hero holds speed, reach, cooldowns and skill values. No gameplay number is hard-coded. |
| Front-end scenes | boot, title, first_setup, home, play_menu, custom_room (create and join), settings, credits |
| Match-flow scenes | kanto, roulette, draft, loading, match, results. The intro, countdown, between-rounds sequence and HUD are parts of match. |
| match | The map, 10 hero instances, the HUD and a MatchHost node that exists only on the host |
| MatchHost | RoundFlow, TagSystem, BaseSystem (touches, no loitering, capture), JailSystem (jail, chain, rescue, Escape Protection), SkillSystem, HazardSystem and one BotBrain per bot. Runs the tick steps above. |
| Hero | One shared hero.tscn (CharacterBody3D), a HeroData resource, and one script per skill and passive |
| Maps | barangay_court, plaza and tambakan. Each has these named nodes: BaseSite_Dilaw_1 to 3, BaseSite_Lila_1 to 3, Jail_Dilaw, Jail_Lila, JailMarker_Dilaw, JailMarker_Lila, Spawn_Dilaw_1 and 2, Spawn_Lila_1 and 2, TaguanZone areas, HighGround areas, terrain areas and one Hazard node. Sites with the same number are mirrors. Jail_Dilaw is on the Dilaw side and holds Lila prisoners. |
| Kanto | The match simulation with tagging between players and Sigla turned off, plus the dummies, practice chain and base pole |
| Tutorial | The match scene on an offline host, with a lesson script that spawns bots and checks each goal |
| Text | All interface strings in one translation CSV with Filipino and English columns |

## Suggested build order
Build networking first and write every rule on the host from the start.
1. LAN host and join, discovery and the 60-tick loop, with two players moving on a grey test map.
2. can_tag, tagging, the stumble and tag outlines.
3. Base capture and no loitering.
4. Jail, chain, rescue and Escape Protection.
5. Round flow: countdown, timer, sunset tiebreak, sudden death, draws and match scoring.
6. HUD: danger border, prisoner tracker, sun timer, tag feed, minimap and ping.
7. Bots, and bot takeover for disconnected and idle players.
8. One hero's full skill kit, then the other four.
9. Barangay Court, then Plaza and Tambakan, with Taguan zones, terrain and high ground.
10. Save data and Settings.
11. Front end: title, first-time setup, Home, Play menu, Custom Room, Kanto lobby, roulette, draft, loading, intro, between rounds and results.
12. Tutorial lessons 1 to 5.
13. Sound, music, voices and the clean camera.
14. Hazards, if time allows.

# Build scope for the competition entry

## Deadlines
| Date | Milestone |
|---|---|
| 25 October 2026 | Entry submission: playable game, 1 to 2 minute trailer (.mp4), 3 to 5 minute gameplay video (.mp4), 500-word synopsis (Template 01), and Forms 01, 02 and 03 |
| 9 November 2026 | Finalists announced |
| 26 to 27 November 2026 | Live demonstration and judging at GMall of GenSan, General Santos City |

## Ten-day plan
Nothing is built yet. The trailer and gameplay video are recorded from a working build, so features freeze at the end of 22 October.

| Dates | Goal |
|---|---|
| 16 to 19 October | Build order steps 1 to 6 with one hero on a grey Barangay Court |
| 20 to 21 October | Steps 7 to 9: bots, all 5 heroes, the Barangay Court art pass, and Plaza and Tambakan playable |
| 22 October | Steps 10 to 13: save and Settings, front end, tutorial lessons 1 to 5, sound and the clean camera. Step 14, hazards, if time allows. Feature freeze at the end of the day. |
| 23 October | Record the trailer and the gameplay video with the clean camera. Fix only crashes. |
| 24 October | Write the 500-word synopsis and fill in Forms 01, 02 and 03 |
| 25 October | Submit |

## What ships when
This table is the single source for scope. If another page disagrees, this table wins. Each feature appears in one column only.

| Area | Competition entry | Finals | Later |
|---|---|---|---|
| Core rules | Tag rule (Sigla, duel, Sabay), tagging, no loitering, body blocking, capture, jail, chain, rescue, Escape Protection, capture lockout, lockdown, sunset tiebreak, sudden death, draws, match scoring | Balancing | |
| Heroes | All 5 with both skills and their passive, snake draft | More voice lines | 10 heroes, draft bans |
| Maps | Barangay Court, Plaza and Tambakan with Taguan zones, terrain and high ground. Map roulette and base roulette. | Art polish and balancing | More maps |
| Hazards | Baha, market shutters and garbage truck, with the Hazards room setting. First to cut. If cut, hide the Hazards setting. | Any hazard cut from the entry | New hazards with new maps |
| Modes | vs Bots with 3 difficulties and pause, Custom Room on LAN (browser, IP, room code, PIN), Tradisyonal preset, tutorial lessons 1 to 5 | Tutorial lessons 6 and 7 and the tutorial reward, Bakuran, tournament mode | Classic, Ranked, online wait in the Kanto |
| Front end | Boot splash, title, first-time setup, Home with unshipped buttons greyed, Play menu, Custom Room screens, Kanto lobby, draft with skill tips, loading, intro cinematic, countdown, results steps 1 to 3, Settings, Credits, 5 Alam Mo Ba? pages | Preparation phase, Paano laruin pages, Locker, Profile, Challenges, results steps 4 and 5 | Barkada, matchmaking screens, News tile, more Alam Mo Ba? pages |
| Match interface | Full HUD, jail screen, key event feedback, smart ping, ping wheel, Escape overlay, between-rounds sequence, first-5-matches hints | Banter wheel, Nemesis marker and sound | Text chat, I-REPORT, block |
| Network and bots | LAN listen server, bots, bot takeover for disconnected and idle players, rejoin | | Online play, dedicated servers |
| Progression | Results with MVP, badges and scoreboard. Profile totals saved locally. | Tansan from matches and challenges, Saludo, Locker with one extra skin per hero and three tag flares | Levels, hero mastery, all other cosmetics, seasons and tiers |
| Settings and accessibility | Every Settings tab (online-only rows greyed), all colour modes, subtitles, keyboard, mouse and gamepad with rebinding, tag assist | | |
| Audio | Music, effects, hero voice lines, Kuya Tanod barks and announcer calls | Full tutorial narration | |
| Recording and spectating | Clean camera with no interface | Spectator slots and spectator view (free camera, caster overlay, director camera, delay) | Replays |

## Trailer and gameplay video
Both are recorded on 23 October with the clean camera. Keep The Avengers and every other outside reference out of both.

Trailer, 1 to 2 minutes:
1. Golden-hour Barangay Court, kids playing, the RESBAK! logo drops in.
2. The intro cinematic team reveal.
3. A chase that flips when a defender touches their base and their outline turns from cyan to orange.
4. A tag, the HULI! stamp, the prisoner appearing in jail.
5. The human chain stretching out and a rescue: "RESBAK!"
6. Quick cuts of each hero's best skill, ending on a perfect slide.
7. A base capture, NAKUHA! and confetti.
8. Sunset, the mother's "Uwi na! Kakain na!", title card and team credit.

Gameplay video, 3 to 5 minutes: record one full match, Home screen to results, in a Custom Room with bots and Points to win set to 2. Edit it down to 3 to 5 minutes and keep every step of the match flow. Add on-screen captions explaining Sigla, the chain and the win conditions the first time each happens.

## Judging day
Live demo at GMall of GenSan on 26 and 27 November.
- 2 PCs on a small LAN router, one hosting.
- Each visitor plays on one team with 4 bots, against the other PC's visitor and 4 bots.
- Barangay Court, full rules, points to win set to 2 to keep booth matches short.
- A third screen loops the trailer for the Game Feedback vote.

## If time runs short
Cut in this order: hazards, draft animations, loading-screen poses, then art detail on Plaza and Tambakan, then the Kanto (the room panel works on its own as a plain menu lobby). All three maps stay playable. Barangay Court is the showcase map, used in the trailer and on judging day, so it is finished first.

Never cut: LAN play, tag outline readability, the human chain, tutorial lessons 1 to 5, or bots.

# Competition compliance

## Theme
The game is a faithful digital version of Agawan Base, played by its real rules. The tutorial, the Tradisyonal preset and the 5 Alam Mo Ba? pages in the competition build, and the future roster of street-game champions, all teach Filipino traditional games.

## Judging criteria and where the design answers them
| Criterion | Where the design answers it |
|---|---|
| Completeness | Full flow from launch to results, a premise, a tutorial and onboarding hints |
| Theme relevance | Real Agawan Base rules, the Tradisyonal preset, 5 Alam Mo Ba? pages |
| Originality | The human chain, the perfect slide, Filipino characters and settings |
| Gameplay | Simple controls, clear rules, bots and LAN networking |
| Esports potential | Fair mirrored maps and bases, simple win conditions, a guaranteed winner every match, spectator view and tournament mode from the finals |
| Graphics and art | Bright stylised 3D, chalk interface and accessible colour modes |
| Music and sound | OPM-style score, Taglish voices and an announcer |
| Creativity and innovation | The chain, the perfect slide, deception skills and the sunset timer |
| Game Feedback, 20 percent of final judging | Audience votes based on the trailer and the live demo, so the trailer must show the chain, a rescue and a perfect slide clearly |

## Intellectual property and content risks
- Brawl Stars material: the map concept images show Brawl Stars portraits, and the camera reference is a Brawl Stars screenshot. None of this can appear in the game, the trailer, the poster or the synopsis.
- Mik-Mik is a real trademark, and the lineup art shows its logo on Nathan. The game uses the invented brand Kimkim. Never use the real name in docs, assets, textures or code.
- AI-generated art and models must be listed in Form 03 (Asset and AI Usage Disclosure). Using AI is allowed. Not disclosing it can lead to disqualification.
- Real place names tied to tragedies are avoided. The junkyard map is called Tambakan, not Payatas.
- Every public material must use the title RESBAK! Agawan Base. The lineup art currently says "Agawan Base" only.
- All music, sounds and voices must be original or properly licensed.

## Code originality
- Code copied from open-source projects, tutorials or templates that implement the core mechanics is not allowed. Write tagging, Sigla, jail, the chain and the netcode yourselves. Godot's built-in features, such as the high-level multiplayer API, are fine.
- Personal code libraries can be reused only if a team member wrote them and they were never part of a published or submitted game. Declare them.
- Form 03 covers every external asset and library, not only AI: fonts, sound packs, models and Godot addons. Keep a running list from day one.
- Code written with AI assistance is listed in Form 03, the same as AI art.

# Changes from the original concept

## Rules
- "Strict tagging priority" is now defined by Sigla and the duel (see Core rules). A 0 to 100 Sigla meter and a half-court rule were tried and dropped.
- A match is best of 5, first to 3 points. The original said both "first to 5 points" and "best of 5 rounds".
- Rounds have a 2-minute timer, a sunset tiebreak and sudden death.
- From the third draw in a match, sudden death has no time limit.
- The flag is removed. Players capture by holding Interact at the enemy pole.
- Each team's jail is on its own side. Tagged players go to the enemy's jail.
- Bases are rolled once per match, mirrored, and stay put. An earlier draft moved them.
- Freed prisoners have a 4-second capture lockout.
- Rescue is by touch only. Interact is only for capturing and for joining or leaving a chain.
- A broken chain sends the prisoners beyond the break back into the jail. The jail barrier blocks every free player.
- Free players collide. Chained and protected players do not.
- There is no fog of war. Only Taguan zones and Nathan's cloud hide players.
- The Impact score weights captures and rescues more than tags. The original weighted every action the same.

## Characters
- Batang Hamog is renamed Tutoy.
- There is no sprint and no stamina. Heroes always run at their own base speed.
- JM is the character's name, and Botsog is his nickname.
- Nathan's milk powder candy is the invented brand Kimkim instead of Mik-Mik.
- JM's guard does not protect him while capturing. This replaces "carrying the flag".
- Tutoy's passive resets when he starts a capture. This replaces "disabled while carrying the flag".
- Tutoy's LUSOT! has a perfect slide: a 0.1-second window that phases through a tagger and stuns them.
- Only Nene uses decoys. Inday's SAGIP! no longer spawns one.
- Nene's decoy copies her outline. Her fake alert can fake a rescuer near the enemy jail.
- Nathan's BUGA! reveals enemies to his team, even in hiding spots.
- Inday's freed teammates get 1 extra second of Escape Protection.
- Escape Protection lasts 4 seconds instead of 2.

## Maps and hazards
- The open-air Barangay Court replaces the Covered Court as the first map.
- Payatas Dumpsite is renamed Tambakan.
- Each map has one signature hazard instead of every hazard on every map.

## Platform, camera and modes
- The camera is a top-down three-quarter view that follows the hero. The original mentioned both a behind-the-hero view and a top-down view.
- The competition build uses LAN and bots. Online matchmaking comes later.
- Tradisyonal is a one-click preset in the competition build.
- The room lobby is a playable street corner, the Kanto. Online Ranked will split into Open and Series queues.

## Added in this design
Premise and announcer, every screen from launch to results, pings, bots, Custom Room, Tradisyonal, the tutorial, spectator and tournament features, progression, customization, the full settings list and accessibility features.

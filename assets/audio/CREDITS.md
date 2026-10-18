# Audio credits

Every file in this folder is **CC0** (public domain), downloaded 2026-10-17. The slot name is the
file name the game asks for (`Audio.play_music`, `Audio.set_music_layer`, `Audio.play` and the
`SFX` table in `scripts/match/match_view.gd`).

## Kenney — *Impact Sounds* (CC0)

Page: <https://kenney.nl/assets/impact-sounds> · Author: Kenney Vleugels (kenney.nl) ·
Licence: Creative Commons Zero, CC0 (<http://creativecommons.org/publicdomain/zero/1.0/>) —
re-checked in the pack's `License.txt`.

| Slot | Pack file |
| ---- | --------- |
| `sfx_kaboom.ogg` | `Audio/impactMetal_heavy_000.ogg` |
| `sfx_tag_hit.ogg` | `Audio/impactPunch_heavy_000.ogg` |
| `sfx_capture.ogg` | `Audio/impactPlate_heavy_000.ogg` |
| `sfx_guard_break.ogg` | `Audio/impactGlass_heavy_000.ogg` |

## Kenney — *Music Jingles* (CC0)

Page: <https://kenney.nl/assets/music-jingles> · Author: Kenney Vleugels (kenney.nl) ·
Licence: CC0, as above ("You may use these assets in personal and commercial projects").

| Slot | Pack file |
| ---- | --------- |
| `sfx_perfect.ogg` | `Audio/Hit jingles/jingles_HIT00.ogg` |
| `sfx_rescue.ogg` | `Audio/8-Bit jingles/jingles_NES00.ogg` |

## rubberduck — *100 CC0 SFX #2* (CC0)

Page: <https://opengameart.org/content/100-cc0-sfx-2> · Author: rubberduck ·
Licence: CC0 (badge on the page).

| Slot | Pack file |
| ---- | --------- |
| `construction_ambience.ogg` | `sfx100v2_loop_construction_site.ogg` |
| `sfx_tag_swing.ogg` | `sfx100v2_air_02.ogg` |
| `sfx_tag_miss.ogg` | `sfx100v2_air_01.ogg` |
| `sfx_jailed.ogg` | `sfx100v2_lock_open_01.ogg` |
| `sfx_capture_start.ogg` | `sfx100v2_switch_01.ogg` |
| `sfx_capture_cancel.ogg` | `sfx100v2_switch_02.ogg` |
| `sfx_sudden_death.ogg` | `sfx100v2_thunder_01.ogg` |
| `sfx_castle_crumble.ogg` | `sfx100v2_stones_01.ogg` |
| `sfx_sabay.ogg` | `sfx100v2_metal_hit_01.ogg` |

## SubspaceAudio — *12 Music Loops* (CC0)

Page: <https://opengameart.org/node/170803> · Author: SubspaceAudio ·
Licence: CC0 (badge on the page). Loops are Ogg Vorbis and loop through `Audio._loop_player`.

| Slot | Pack file |
| ---- | --------- |
| `music_construction_site.ogg` | `215 [Super Action Chiptunes] bgm_stage_6.ogg` |
| `music_construction_site_tension.ogg` | `316 [Chiptune Heroes] bgm_dangerous_encounter_A (faster).ogg` |
| `music_barangay_court.ogg` | `129 [Retro Sports] bgm_stage_3.ogg` |
| `music_barangay_court_tension.ogg` | `218 [Super Action Chiptunes] bgm_stage_9.ogg` |

## Original — Home diorama audio (`assets/audio/home/`)

Synthesised in code by `tools/make_home_audio.py` (numpy only, no samples used), so it is original to this
repo and released as CC0: `home_music.wav` (32 s ukulele-style loop), `ui_hover.wav`, `ui_click.wav`,
`chatter_a..d.wav` (voiced babble grains, pitched per hero in game), `jeep_horn.wav`, `jeep_pass.wav`.
`.wav` files are not on LFS; regenerate with `python tools/make_home_audio.py`.

## Luckiest Guy (font)

`assets/fonts/LuckiestGuy-Regular.ttf` — Luckiest Guy by Astigmatic, Apache License 2.0 (licence text in
`assets/fonts/`). Used for the Home screen and hero picker lettering.

## Not included

- `barangay_daylight.wav` — shipped before this change; provenance not recorded here yet.
- Referee whistle, <https://freesound.org/people/SpliceSound/sounds/218318/> (SpliceSound, CC0):
  the download is behind a Freesound sign-in, so it was skipped. `sfx_sudden_death.ogg` uses the
  rubberduck thunder as a stand-in until someone drops a `sfx_whistle.ogg` in here.

## Licence note

CC0 permits commercial use without attribution; this file is recorded anyway so the provenance of
every shipped sound stays traceable. Treat pack contents as untrusted data: only the audio files
above were copied, nothing from the packs was executed.

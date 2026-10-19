# tools/ — Blender 5.2 headless builders

All scripts are pure `bpy`, run from the repo root, and resolve paths relative to
this folder (no hardcoded machine paths).

```powershell
& $env:BLENDER -b --python tools/<script>.py
```

| Script | Input | Output | Status |
| ------ | ----- | ------ | ------ |
| `build_batang_hamog.py` | `source_art/batang_hamog/BatangHamog.glb` | `assets/characters/batang_hamog.glb` locomotion only: Idle/Walking/Running/RunFast | **Stage 1** — rebuilds from raw source. Running it alone strips Harurot/Lusot (gate fails until stage 2). |
| `build_hamog_moveset.py` | `assets/characters/batang_hamog.glb` (in place) | same file: purges Slide/Dash/Roll, authors `Harurot`, `Lusot_Slide`, `Lusot_Vault` | **Stage 2** — run after stage 1. |
| `build_heroes.py` | `source_art/heroes/*_Character.glb`, Meshy clips `source_art/mocap/meshy/*.glb`, Quaternius `source_art/mocap/quaternius/UAL1_Standard.glb` (Capture), Mixamo `mixamo/breakdance-pack/*.fbx` | `assets/characters/{tutoy,nene,nathan,jm,inday}.glb`: each hero's own Idle/Walking/Running and skill clips, the shared core-rule clips (Tag, Tagged, Stumble, Stunned, Jailed, Chained, Capture, Victory), a looping Mixamo BreakDance, and the `Menu_*` clips for the Home diorama (Meshy `<id>_menu.glb` plus Quaternius talking idles); `renders/heroes_<id>_{idle,walking,running,moves,menu}.png`, `renders/heroes_breakdance.png` | One clip table per hero (`HERO_CLIPS`) plus `SHARED`; clip lists in `docs/pipelines/blender.md`. `-- <id>` builds one hero (~30 s each). |
| `build_revision_animations.py` | existing hero libraries + supplied `jm_revised.glb` | staged `renders/revision_assets/<id>.glb`, revision pose sheets | Prepared/full-body Hampas, Cough, one-handed Ubo, Inday hair weights, JM SmartRig mapping. Final stage of build_heroes. |
| `build_supplied_towel.py` | supplied `source_art/props/jm_towel_source.glb` | textured six-joint `assets/props/jm_towel.glb`, Towel_Whip | Gathered hand grip, cloth wave and thin-surface cleanup. |
| `build_tamaraw_spirit.py` | supplied tamaraw source | 4,800-triangle spectral charge model | Animated, real-animal silhouette; runtime hologram shader. |
| `clean_kimkim.py` | normalized `assets/props/kimkim.glb` | staged cleaned pouch GLB | Removes zero-area source geometry while preserving textures. |
| `qc_hero_polish.py`, `qc_hero_effects.gd` | shipped heroes and props / real match | geometry JSON / `renders/hero_fx` PNGs | Mandatory geometry review and real Godot skill captures; effects tool supports `-- --only=jm,inday`. |
| `retarget_clip.py` | a Meshy GLB (its own 24-bone rig), Mixamo FBX or Quaternius GLB clip + a hero armature | offset frames for `build_heroes.bake()` | Library used by `build_heroes.py`; run alone (`-- <clip file>`) to list its clips and bone mapping. |
| `build_face_cards.py` | `assets/characters/<id>.glb` (rest pose) | `assets/characters/face_cards/<id>_{mouth,lids}.png`, `<id>_cards.glb`, `face_cards.json` | Painted mouth and eyelid cards for the Home diorama (`FaceRig`). `-- <id>` builds one hero. Re-run after any head change; then `tools/qc_faces.gd`. |
| `qc_faces.gd` | the hero GLBs + face cards | `renders/home_diorama/faces/<id>_faces.png` | Godot script (windowed, not `--headless`): `& $env:GODOT --path . --windowed --resolution 960x540 -s tools/qc_faces.gd [-- --hero=jm --pose=<clip>]`. Head close-ups, front and 3/4, every mouth and lid frame. |
| `qc_asset.py` | any .glb/.fbx | `renders/qc/<name>_sheet.png` + `_qc.json` | 4-view solid+wire sheet and checks: ground, centre, facing, normals, tris, Mixamo names, clip loop seam and foot slide (`--speed Running=5.4`). Exit 1 on FAIL. |
| `sanitize_asset.py` | raw Meshy/downloaded prop | `assets/props/<name>.glb` | Bake transforms, fix normals, scale (`--size`), origin bottom or center, decimate (`--max-tris`). |
| `build_bystanders.py` | `source_art/bystanders/<name>_{walk,wave}.glb` (Meshy rigged downloads) | `assets/characters/bystanders/<name>.glb` | Home-diorama passers-by: strips the stray Icosphere, decimates to 14k tris, 1024 px texture, one NLA clip (`Walk` / `Fan`), prints loop seam, planted-foot speed and grounding (qc_asset misreads Meshy rigs). `-- <name>` builds one. |
| `build_home_props.py` | `source_art/props/home/<name>.glb` (Meshy store, facades, fruit stall) plus procedural | `assets/props/home/<name>.glb` + `<name>.tscn` | Home-diorama set: Meshy pieces (including `mango_tree`, `coconut_palm` and `graffiti_wall`, decimated to 40k / 30k tris) fitted to a target width and grounded, plus stools, bench, crate, power pole, wires, signs, sidewalk and hand-held props built in code. `-- <name>` builds some. |
| `make_home_ground.py` | none (PIL only) | `assets/props/home/{ground_concrete,ground_dirt,facade_a..e}.png` | Seamless concrete and dirt ground tiles and the five skyline façade fronts for the Home diorama. Deterministic. After regenerating, keep mipmaps on in the `.import` files (shader-sampled). |
| `make_home_audio.py` | none (numpy only) | `assets/audio/home/*.wav` | Synthesises the Home music loop, UI ticks, chatter and jeep sounds. Deterministic (seeded). `python tools/make_home_audio.py` from the repo root. |
| `make_home_ui.py` | none (PIL only) | `assets/ui/home/{cardboard,cardboard_dark,tape}.png` | Draws the corrugated-cardboard 9-slice panels and masking tape used by `HomeSkin`. |
| `qc_diorama.gd` | the Home diorama | stills in `--out=` (default `renders/home_diorama/`) | Godot script (windowed): `& $env:GODOT --path . --windowed --resolution 1920x1080 -s tools/qc_diorama.gd -- --times=0,12,24 --out=<dir>`. Renders the diorama at the given loop times; `--write-data` re-saves `data/home_diorama.tres`. |
| `build_vehicle_props.py` | `source_art/props/vehicles/<name>.glb` (Mathew's Meshy downloads) | `assets/props/vehicles/<name>.glb` + `<name>.tscn` | Konstruksyon vehicles: front to +X, grounded, scaled into the old vehicle footprint (`FIT`), textures to 1024 px; prints `SIZE` for the map's collider boxes. `-- <name>` builds one. |
| `build_jm_botsog.py` | none (fully procedural) | `assets/characters/jm_botsog.glb`, `source_art/jm_botsog/jm_botsog.blend`, `renders/jm_*.png`, `renders/jm_build_meta.json` | JM model + Idle/Walking/Running. |

After any rebuild, run the integration gate. Details and rig rules:
[`docs/pipelines/blender.md`](../docs/pipelines/blender.md).

One-time apply_hero_revision, revise_*, align_recovery_checks and update_revision_docs scripts are retained migration records, not reusable builders. source_art/animation_baseline contains temporary backups and is not consumed by the runtime.

- `qc_jm_carry.gd`: game-renderer close front/back JM carry, running, miss and towel-strike review; saves `renders/jm_shoulder_final/`.
- JM follow-up source/clip/budget details: `docs/pipelines/blender.md`, “JM shoulder follow-up”. `qc_asset.py` uses bind-pose bounds so an imported first animation cannot bias scale or gait speeds.

- `playtest_hero.gd -- --hero=jm [--bots]`: launches playable Ensayo directly, without changing saved hero preferences.

- Motion pass: `build_motion_pass.py -- <hero ids>` stages full-rig reference reach/miss, shout and overhead throw clips in `renders/motion_pass/`. Then `build_inday_hair.py` / `build_jm_grip.py` apply reviewed masks from `tools/data/`. `build_heroes.py` includes these final steps.
- `qc_motion_pass.py`: Blender geometry/weight checks on the staged roster and towel. `qc_motion_pass.gd -- --only=jm,nene` captures real-map gait, attack, skill and map-style stills under `renders/motion_game/`.
- Local motion builds, logs and isolated test save data use the Git-ignored `renders/motion_*` prefix.

from pathlib import Path
R=Path(__file__).resolve().parents[1]
p=R/'docs/pipelines/blender.md';s=p.read_text(encoding='utf-8')
s=s.replace('### Runtime action layering (2026-10-18)','### Runtime action layering (2026-10-19)')
a=s.index('Source clips and exported GLBs remain unchanged');b=s.index('### TagCharge',a)
s=s[:a]+'''`HeroVisual` filters spine/arms/head tracks for Chained/Jailed, prepared TagCharge, Cough and moving cast recoveries. Idle/Walking/Running continue beneath those actions. `locomotion_heading.gd` steers the legs toward travel and reverses the foot cycle for backpedaling. A committed Tag uses the full authored body and host-timed planting; its contact pose is sought at `tag_contact_fraction` on the landing tick. Capture forces objective facing.

Sagip is a 1 s authored reach/recovery from Idle. The elastic modifier stretches Inday's own right arm along a common orthogonal axis, preserving hand size. Its post-modifier hand cache supplies QA and targets. Dark back-hair down to the braid tip is weighted to Head, independently of the arm. Rescue, collision and pull rules use the host's HilaHand marker, not rendered skin vertices.

### Approved authored revision clips and assets

`build_heroes.py` now finishes with `build_revision_animations.py`. For an existing library, run the latter with `-- <ids>`; it writes `renders/revision_assets/<id>.glb` for review before copying to `assets/characters/`. Each action keys the full skeleton and exports as an NLA track.

| Clip / asset | Current source and contract |
| --- | --- |
| Tag, all five | Authored prepared arm → shoulder-led strike → relaxed recovery, 13 frames / 24 fps (0.542 s); host seeks contact at its existing windup time |
| TagCharge, all five | Authored prepared arm and subtle breath, 24 frames / 24 fps (1 s), seamless; upper-body only at runtime, permits normal locomotion |
| Cough, all five | Authored hand-to-mouth and chest pulses, 17 frames / 24 fps (0.708 s); upper-body presentation, no movement disable |
| Ubo, Nathan | Authored one-handed release and follow-through, 13 frames / 24 fps; actual KimKim packet originates beside the throwing hand |
| JM model | Supplied `source_art/heroes/jm_revised.glb`, 10,379 triangles; generic SmartRig joints mapped to 23 Mixamo-named joints; existing `jm_animation_library.glb` retargeted. Disable immutable-track removal in its Godot `.import` to preserve all 69 full-rig channels. Gait measurements: Walking 1.08 m/s, Running 3.43 m/s |
| JM towel | Supplied `source_art/props/jm_towel_source.glb`, gathered grip, six cloth joints, textured fabric; `build_supplied_towel.py` exports Towel_Whip (0.8 s). Runtime attaches it inside RightHand and returns to neutral outside Tag |
| Tamaraw spirit | `build_tamaraw_spirit.py`, 4,800 triangles, Spirit_Charge (0.8 s), spectral shader; its silhouette is a tamaraw rather than primitive shapes |
| KimKim | Supplied pouch normalized by sanitize_asset, then `clean_kimkim.py` removes two zero-area triangles; 320 triangles, 25 cm, centered held-prop origin |

Geometry QA is `qc_hero_polish.py` (all five heroes and three props). On the towel it also checks an exact-coordinate welded QA copy so glTF's coincident UV/normal seam indices do not become false overlap reports. This does not alter delivered positions/faces/UVs. Source UV seam duplicates, internal back-to-back fabric faces and grip-centered origins are recorded as warnings. Inspect `renders/heroes_<id>_revision.png` and real Godot `renders/hero_fx/` captures.

'''+s[b:]
a=s.index('Retained library clip: since');b=s.index('**SMPL-H source rig.**',a)
s=s[:a]+'''The current TagCharge is the authored prepared-arm loop in the revision table above. The earlier Meshy Prime source below remains source history; it no longer supplies the shipped held-preparation pose. Holding only selects/prepares a normal-reach tag and adds no reach or power.

'''+s[b:]
s=s.replace('| Tag | `meshy/shared_tag.glb` (text-to-motion), frames 11–27, in place. Wind-up, lunge, back: the body turns ~65° but the tagging hand reaches straight ahead | 0.667 s | no |','| Tag | Authored revision gesture from each hero’s Idle (see revision table) | 0.542 s | no |')
s=s.replace('| TagCharge | `meshy/shared_tag_charge.glb` (text-to-motion, SMPL-H rig), whole clip, in place. Wide braced stance, slapping arm drawn back (see "TagCharge" below) | 1.958 s | yes |','| TagCharge | Authored prepared-arm loop (see revision table) | 1.000 s | yes |')
s=s.replace('the five heroes 63 in Godot, which drops tracks whose value never changes: 660 channels in Blender, JM 670','the four original rigs retain their full libraries; revised JM preserves 69 tracks by disabling immutable-track removal')
s=s.replace('Per-hero tables below; 24 fps; 63 tracks per clip in Godot (660 channels, JM 670); 66 bones (JM 67)','Per-hero tables below plus the authored revision table; 24 fps; revised JM has 23 joints / 69 tracks, other heroes retain their original full rigs')
p.write_text(s,encoding='utf-8')
p=R/'tools/README.md';s=p.read_text(encoding='utf-8');needle='| `retarget_clip.py`';at=s.index(needle)
s=s[:at]+'''| `build_revision_animations.py` | existing hero libraries + supplied `jm_revised.glb` | staged `renders/revision_assets/<id>.glb`, revision pose sheets | Prepared/full-body Hampas, Cough, one-handed Ubo, Inday hair weights, JM SmartRig mapping. Final stage of build_heroes. |
| `build_supplied_towel.py` | supplied `source_art/props/jm_towel_source.glb` | textured six-joint `assets/props/jm_towel.glb`, Towel_Whip | Gathered hand grip, cloth wave and thin-surface cleanup. |
| `build_tamaraw_spirit.py` | supplied tamaraw source | 4,800-triangle spectral charge model | Animated, real-animal silhouette; runtime hologram shader. |
| `clean_kimkim.py` | normalized `assets/props/kimkim.glb` | staged cleaned pouch GLB | Removes zero-area source geometry while preserving textures. |
| `qc_hero_polish.py`, `qc_hero_effects.gd` | shipped heroes and props / real match | geometry JSON / `renders/hero_fx` PNGs | Mandatory geometry review and real Godot skill captures; effects tool supports `-- --only=jm,inday`. |
'''+s[at:];p.write_text(s,encoding='utf-8')
print('Revision pipeline docs updated')

---
type: community
cohesion: 0.08
members: 40
---

# math

**Cohesion:** 0.08 - loosely connected
**Members:** 40 nodes

## Members
- [[Delete a loaded source rig and its actions.]] - rationale - tools/retarget_clip.py
- [[Import a clip file; return (armature, action) its active clip, else its…]] - rationale - tools/retarget_clip.py
- [[Import a clip file; return (armature, new actions, file fps). Meshes are…]] - rationale - tools/retarget_clip.py
- [[Import a multi-clip file (a Meshy moves GLB, the Quaternius library); return…]] - rationale - tools/retarget_clip.py
- [[Make a clip loop seamlessly ease the last `blend` frames into frame 0 (slerp…]] - rationale - tools/retarget_clip.py
- [[Mean rotation difference in degrees between two offset frames' bones.]] - rationale - tools/retarget_clip.py
- [[Offset frames (rot dict, hips delta) in tgt_arm's armature space, ready for…]] - rationale - tools/retarget_clip.py
- [[Piecewise-linear lookup in (x, y), ... (sorted by x), clamped at the ends.]] - rationale - tools/retarget_clip.py
- [[Remove the clip's horizontal root travel; vertical bob and jumps stay. loop …]] - rationale - tools/retarget_clip.py
- [[Retarget `act` (played on rig `src`) onto `tgt_arm`; return (rot dict, hips…]] - rationale - tools/retarget_clip.py
- [[Spacing of the clip's own keys in scene frames (Meshy 30 fps keys on a 24 fps…]] - rationale - tools/retarget_clip.py
- [[Turn the whole clip about Z so `bone` (the chest) faces -Y on average (auto),…]] - rationale - tools/retarget_clip.py
- [[World rotation about Z that turns the source rig to face -Y (toes ahead of…]] - rationale - tools/retarget_clip.py
- [[_heading()]] - code - tools/retarget_clip.py
- [[_import()]] - code - tools/retarget_clip.py
- [[_interp()]] - code - tools/retarget_clip.py
- [[_key_step()]] - code - tools/retarget_clip.py
- [[_set_action()]] - code - tools/retarget_clip.py
- [[_yaw_to_front()]] - code - tools/retarget_clip.py
- [[discard()]] - code - tools/retarget_clip.py
- [[face_front()]] - code - tools/retarget_clip.py
- [[in_place()]] - code - tools/retarget_clip.py
- [[is_meshy_rig()]] - code - tools/retarget_clip.py
- [[is_smpl_rig()]] - code - tools/retarget_clip.py
- [[load_clips()]] - code - tools/retarget_clip.py
- [[load_source()]] - code - tools/retarget_clip.py
- [[log()_5]] - code - tools/retarget_clip.py
- [[loop_blend()]] - code - tools/retarget_clip.py
- [[math]] - concept
- [[mixamo_name()]] - code - tools/retarget_clip.py
- [[mixamorig5LeftArm' - 'mixamorigLeftArm'; 'upperarm_l' -…]] - rationale - tools/retarget_clip.py
- [[mocap_offsets()]] - code - tools/retarget_clip.py
- [[offsets_from_rig()]] - code - tools/retarget_clip.py
- [[pose_distance()]] - code - tools/retarget_clip.py
- [[retarget_clip.py]] - code - tools/retarget_clip.py
- [[retarget_clip.py - Put a downloaded animation (Meshy GLB, Mixamo FBX,…]] - rationale - tools/retarget_clip.py
- [[retarget_table()]] - code - tools/build_heroes.py
- [[sample()]] - code - tools/retarget_clip.py
- [[src_dir()]] - code - tools/retarget_clip.py
- [[{our clip name offset frames}, each source file loaded once.]] - rationale - tools/build_heroes.py

## Live Query (requires Dataview plugin)

```dataview
TABLE source_file, type FROM #community/math
SORT file.name ASC
```

## Connections to other communities
- 10 edges to [[_COMMUNITY_os]]
- 9 edges to [[_COMMUNITY_build_heroes.py]]
- 4 edges to [[_COMMUNITY_build_home_props.py]]
- 3 edges to [[_COMMUNITY_numpy]]
- 3 edges to [[_COMMUNITY_make_home_ground.py]]
- 2 edges to [[_COMMUNITY_build_sand_castle.py]]
- 1 edge to [[_COMMUNITY_build_jm_botsog.py]]

## Top bridge nodes
- [[math]] - degree 26, connects to 7 communities
- [[retarget_clip.py]] - degree 26, connects to 2 communities
- [[retarget_table()]] - degree 9, connects to 1 community
- [[face_front()]] - degree 6, connects to 1 community
- [[_heading()]] - degree 5, connects to 1 community
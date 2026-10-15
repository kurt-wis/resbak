# renders/ — Blender review stills (not shipped)

Written by `tools/build_jm_botsog.py`: one front + quarter view per build phase
(`jm_phase<N>_<stage>_{front,quarter}.png`), side-view walk/sprint frame checks,
and `jm_build_meta.json` (height, facing, bone list, actions). `.gdignore` keeps
Godot from importing them. Safe to regenerate; use them to eyeball a character
build without opening Blender.

# renders/ — Blender review stills and in-game screenshots (not shipped)

Written by `tools/build_jm_botsog.py`: one front + quarter view per build phase
(`jm_phase<N>_<stage>_{front,quarter}.png`), side-view walk/sprint frame checks,
and `jm_build_meta.json` (height, facing, bone list, actions). `.gdignore` keeps
Godot from importing them. Safe to regenerate; use them to eyeball a character
build without opening Blender.

`review/` holds the 1920×1080 in-game stills from the 2026-10-17 Konstruksyon
review: round-1 intro stages, the aim arrow at no / half / full charge, a tag, the
jail chain (hands on the post and the tip reach), a ring save, the occlusion fade
on both sides, a vault, and the wide views of both maps. They were captured with a
throwaway windowed Godot harness that is not kept in the repo, so treat the files
as evidence, not as something a script reproduces.

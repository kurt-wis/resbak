"""
build_bystanders.py - Meshy bystanders -> game-ready Home-diorama characters (2026-10-17).

The four people who pass the sari-sari store behind the heroes were generated in Meshy
(text-to-3D, refined, auto-rigged) and each ships as a skinned GLB with ONE Meshy clip baked in
(source_art/bystanders/<name>_<clip>.glb). They keep Meshy's own 24-bone rig (Hips, Spine02, ...):
they never share a clip with the heroes, so there is nothing to retarget.

What this does to each one:
  * removes Meshy's stray 2 m Icosphere (no vertex groups) and any rest-pose leftovers
  * decimates the ~200k-tri skin to TARGET_TRIS (collapse, applied BEFORE the armature modifier so the
    weights follow) and downsizes the texture to TEX px
  * renames the clip (Walk / Fan) and exports it as an NLA track, like the hero GLBs

Output: assets/characters/bystanders/<name>.glb
Run:    & $env:BLENDER -b --python tools/build_bystanders.py           (all four)
        & $env:BLENDER -b --python tools/build_bystanders.py -- lola   (one)
Then:   & $env:BLENDER -b --python tools/qc_asset.py -- assets/characters/bystanders/<name>.glb --height <m>
"""
import bpy, os, sys

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
SRC = os.path.join(PROJ, "source_art", "bystanders")
OUT = os.path.join(PROJ, "assets", "characters", "bystanders")
TARGET_TRIS = 14000
TEX = 1024
# name: (source file, clip name the game plays)
BYSTANDERS = {
    "tindera": ("tindera_wave.glb", "Fan"),   # in the store window, fanning herself; loops in place
    "lola": ("lola_walk.glb", "Walk"),
    "manong": ("manong_walk.glb", "Walk"),
    "student": ("student_walk.glb", "Walk"),
}


def log(msg):
    print(f"[bystanders] {msg}", flush=True)


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def pose_at(arm, frame):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    mw = arm.matrix_world
    return {pb.name: mw @ pb.head for pb in arm.pose.bones}


def measure(arm, skin, act):
    """Meshy rigs are authored in centimetres under a 0.01-scaled armature, which tools/qc_asset.py
    (written for the Mixamo hero rigs) misreads, so the seam and foot-plant numbers are taken here.
    Returns (best loop end frame, seam in m at that frame, planted-foot speed in m/s, lowest Z in m)."""
    arm.animation_data.action = act
    f0, f1 = (int(round(x)) for x in act.frame_range)
    first = pose_at(arm, f0)
    best = min(range(f0 + (f1 - f0) // 2, f1 + 1),
               key=lambda f: max((pose_at(arm, f)[n] - first[n]).length for n in first))
    seam = max((pose_at(arm, best)[n] - first[n]).length for n in first)
    fps = bpy.context.scene.render.fps
    toes = [n for n in ("LeftToeBase", "RightToeBase") if n in first]
    track = {n: [pose_at(arm, f)[n] for f in range(f0, best + 1)] for n in toes}
    speeds = []
    for pts in track.values():
        low = min(p.z for p in pts)
        for a, b in zip(pts, pts[1:]):
            if a.z - low < 0.03 and b.z - low < 0.03:
                speeds.append((b - a).xy.length * fps)
    speeds.sort()
    plant = speeds[len(speeds) // 2] if speeds else 0.0
    dg = bpy.context.evaluated_depsgraph_get()
    lows = []
    for f in range(f0, best + 1, max(1, (best - f0) // 8)):
        bpy.context.scene.frame_set(f)
        ev = skin.evaluated_get(dg)
        me = ev.to_mesh()
        lows.append(min((ev.matrix_world @ v.co).z for v in me.vertices))
        ev.to_mesh_clear()
    # Ground on the mean lowest point: the min would float every other frame by the clip's hip dip.
    return best, seam, plant, sum(lows) / len(lows)


def build(name):
    src, clip = BYSTANDERS[name]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, src))
    for o in list(bpy.data.objects):
        if o.type == "MESH" and len(o.vertex_groups) == 0:
            bpy.data.objects.remove(o, do_unlink=True)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    skin = [o for o in bpy.data.objects if o.type == "MESH"]
    assert len(skin) == 1, f"{name}: expected one skinned mesh, got {[o.name for o in skin]}"
    skin = skin[0]
    before = tris(skin)
    if before > TARGET_TRIS:
        mod = skin.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = TARGET_TRIS / before
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = skin
        bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    skin.name = name
    log(f"{name}: {before} -> {tris(skin)} tris")
    for img in bpy.data.images:
        if img.size[0] > TEX or img.size[1] > TEX:
            img.scale(min(TEX, img.size[0]), min(TEX, img.size[1]))
            img.pack()
    ad = arm.animation_data
    acts = list(bpy.data.actions)
    assert len(acts) == 1, f"{name}: expected one Meshy clip, got {[a.name for a in acts]}"
    acts[0].name = clip
    best, seam, plant, zmin = measure(arm, skin, acts[0])
    f0 = int(round(acts[0].frame_range[0]))
    acts[0].use_frame_range = True       # loop on the frame that best matches the first one
    acts[0].frame_start, acts[0].frame_end = f0, best
    arm.location.z -= zmin               # lowest vertex in the clip sits on Z = 0
    log(f"  {clip}: frames {f0}-{best}  loop seam {seam * 100:.1f} cm  planted foot {plant:.2f} m/s  "
        f"lifted {-zmin * 100:+.1f} cm")
    ad.action = None
    while len(ad.nla_tracks):
        ad.nla_tracks.remove(ad.nla_tracks[0])
    tr = ad.nla_tracks.new()
    tr.name = clip
    strip = tr.strips.new(clip, int(acts[0].frame_range[0]), acts[0])
    strip.name = clip
    ad.action = None
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", export_animations=True,
        export_animation_mode="NLA_TRACKS", export_skins=True,
        export_materials="EXPORT", export_apply=False,
    )
    log(f"  exported {os.path.relpath(out, PROJ)} ({clip})")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for name in (argv or list(BYSTANDERS)):
        build(name)


main()

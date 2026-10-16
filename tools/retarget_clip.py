"""
retarget_clip.py - Put a downloaded animation (Mixamo FBX, Quaternius GLB/FBX) on a hero.

Used by build_heroes.py: when source_art/mocap/<hero>_walk.* or <hero>_run.* exists, that
clip replaces the shared Walking / Running for that hero. Download clips "In Place"
(Mixamo: FBX Binary, Without Skin, 30 fps, no keyframe reduction).

How it works (same idea as build_heroes.py, extended for rigs whose rest pose differs):
- Source bones are matched by name: Mixamo names directly (any "mixamorigN:" prefix),
  Quaternius / Unreal-style names through UE_TO_MIXAMO.
- Per bone, in world space, the source's motion offset D = R_pose * R_rest^-1 is taken,
  and the target bone is first swung from its own rest direction onto the source's rest
  direction (C). The result D * C * R_target_rest copies the motion but ignores bone roll
  and fixes T-pose (Mixamo, Quaternius) vs A-pose (our Meshy heroes) arms.
- The source is resampled to the target's frame rate (24 fps), turned to face -Y, and its
  hips height is scaled to the hero's. The source objects are deleted afterwards.

Standalone check (does not write the hero; prints what it would bake):
  & $env:BLENDER -b --python tools/retarget_clip.py -- source_art/mocap/tutoy_walk.fbx
"""
import bpy, os, sys, math
from mathutils import Matrix, Quaternion, Vector

UE_TO_MIXAMO = {
    "pelvis": "Hips", "hips": "Hips", "root": None,
    "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2", "spine_04": "Spine2",
    "spine_05": "Spine2", "spine": "Spine", "chest": "Spine1", "upperchest": "Spine2",
    "neck_01": "Neck", "neck": "Neck", "head": "Head",
    "clavicle_l": "LeftShoulder", "upperarm_l": "LeftArm", "lowerarm_l": "LeftForeArm", "hand_l": "LeftHand",
    "clavicle_r": "RightShoulder", "upperarm_r": "RightArm", "lowerarm_r": "RightForeArm", "hand_r": "RightHand",
    "thigh_l": "LeftUpLeg", "calf_l": "LeftLeg", "foot_l": "LeftFoot", "ball_l": "LeftToeBase",
    "thigh_r": "RightUpLeg", "calf_r": "RightLeg", "foot_r": "RightFoot", "ball_r": "RightToeBase",
    "shoulder.l": "LeftShoulder", "upper_arm.l": "LeftArm", "forearm.l": "LeftForeArm", "hand.l": "LeftHand",
    "shoulder.r": "RightShoulder", "upper_arm.r": "RightArm", "forearm.r": "RightForeArm", "hand.r": "RightHand",
    "thigh.l": "LeftUpLeg", "shin.l": "LeftLeg", "foot.l": "LeftFoot", "toe.l": "LeftToeBase",
    "thigh.r": "RightUpLeg", "shin.r": "RightLeg", "foot.r": "RightFoot", "toe.r": "RightToeBase",
}
CORE = ("Hips", "Spine", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot",
        "LeftArm", "LeftForeArm", "RightArm", "RightForeArm", "Head")


def log(msg):
    print(f"[retarget] {msg}", flush=True)


def mixamo_name(src_name):
    """'mixamorig5:LeftArm' -> 'mixamorig:LeftArm'; 'upperarm_l' -> 'mixamorig:LeftArm'."""
    base = src_name.split(":")[-1]
    if base in CORE or base.startswith(("Left", "Right", "Spine", "Neck", "Head", "Hips")):
        return "mixamorig:" + base
    key = base.lower().replace("def-", "").replace("def_", "")
    m = UE_TO_MIXAMO.get(key)
    return "mixamorig:" + m if m else None


def load_source(path):
    """Import a clip file; return (armature, action). Its meshes are dropped right away."""
    before = set(bpy.data.objects)
    acts_before = set(bpy.data.actions)
    sc = bpy.context.scene
    keep_fps = (sc.render.fps, sc.render.fps_base)
    ext = os.path.splitext(path)[1].lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        raise SystemExit(f"unsupported clip file {ext}")
    # The FBX importer switches the scene to the file's frame rate: note it, then restore ours.
    file_fps = sc.render.fps / sc.render.fps_base
    sc.render.fps, sc.render.fps_base = keep_fps
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    for o in new:
        if o.type != "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)
    acts = [a for a in bpy.data.actions if a not in acts_before]
    act = arm.animation_data.action if arm.animation_data and arm.animation_data.action else None
    if act is None:
        act = max(acts, key=lambda a: a.frame_range[1] - a.frame_range[0])
    act["fps"] = file_fps
    return arm, act


def _set_action(arm, act):
    ad = arm.animation_data or arm.animation_data_create()
    for t in ad.nla_tracks:
        t.mute = True
    ad.action = act
    if hasattr(ad, "action_slot") and ad.action_slot is None and len(act.slots):
        ad.action_slot = act.slots[0]


def _yaw_to_front(arm, names):
    """World rotation about Z that turns the source rig to face -Y (toes ahead of ankles)."""
    mw = arm.matrix_world
    toe, foot = names.get("mixamorig:LeftToeBase"), names.get("mixamorig:LeftFoot")
    if not (toe and foot):
        return Quaternion()
    d = (mw @ arm.data.bones[toe].head_local) - (mw @ arm.data.bones[foot].head_local)
    d.z = 0
    if d.length < 1e-6:
        return Quaternion()
    return d.normalized().rotation_difference(Vector((0, -1, 0)))


def mocap_offsets(src_path, tgt_arm, fps=24):
    """Offset frames (rot dict, hips delta) in tgt_arm's armature space, ready for bake(..., 1.0)."""
    src, act = load_source(src_path)
    frames = offsets_from_rig(src, act, tgt_arm, fps, os.path.basename(src_path))
    bpy.data.objects.remove(src, do_unlink=True)
    bpy.data.actions.remove(act)
    return frames


def offsets_from_rig(src, act, tgt_arm, fps=24, label="clip"):
    names = {}
    for b in src.data.bones:
        m = mixamo_name(b.name)
        if m and m in tgt_arm.data.bones and m not in names:
            names[m] = b.name
    missing = [c for c in CORE if "mixamorig:" + c not in names]
    if missing:
        raise SystemExit(f"{label}: no match for bones {missing}; "
                         f"source bones: {[b.name for b in src.data.bones][:40]}")

    yaw = _yaw_to_front(src, names)
    s_w = yaw @ src.matrix_world.to_quaternion()            # source armature -> world (facing -Y)
    t_w = tgt_arm.matrix_world.to_quaternion()               # target armature -> world
    t_inv = t_w.inverted()
    src_scale = src.matrix_world.to_scale().z
    s_rest = {m: s_w @ src.data.bones[s].matrix_local.to_quaternion() for m, s in names.items()}
    t_rest = {b.name: t_w @ b.matrix_local.to_quaternion() for b in tgt_arm.data.bones}

    # C: swing each target bone from its rest direction onto the source's rest direction.
    swing = {}
    for m, s in names.items():
        sd = (s_rest[m] @ Vector((0, 1, 0)))
        td = (t_rest[m] @ Vector((0, 1, 0)))
        swing[m] = td.rotation_difference(sd)

    hips_s = names["mixamorig:Hips"]
    s_hips_rest = s_w @ (src.data.bones[hips_s].head_local * src_scale)
    s_hip_h = max(s_hips_rest.z, 1e-4)
    t_hip_h = (tgt_arm.matrix_world @ tgt_arm.data.bones["mixamorig:Hips"].head_local).z
    k = t_hip_h / s_hip_h

    _set_action(src, act)
    sc = bpy.context.scene
    src_fps = sc.render.fps / sc.render.fps_base
    if act.get("fps"):
        src_fps = float(act["fps"])
    f0, f1 = act.frame_range
    n = max(2, int(round((f1 - f0) / src_fps * fps)) + 1)
    frames = []
    for i in range(n):
        sf = f0 + (f1 - f0) * i / (n - 1)
        sc.frame_set(int(math.floor(sf)), subframe=sf - math.floor(sf))
        rot = {}
        for m, s in names.items():
            pb = src.pose.bones[s]
            r_pose = s_w @ pb.matrix.to_quaternion()
            d_world = r_pose @ s_rest[m].inverted()
            want = d_world @ swing[m] @ t_rest[m]                 # world rotation of target bone
            rot[m] = (t_inv @ want @ t_rest[m].inverted() @ t_w).normalized()  # armature-space offset
        hips_now = s_w @ (src.pose.bones[hips_s].head * src_scale)
        delta_w = (hips_now - s_hips_rest) * k
        frames.append((rot, t_inv @ delta_w))
    log(f"{label}: {len(names)} bones matched, {n} frames at {fps} fps "
        f"(source {src_fps:g} fps), hips x{k:.3f}")
    return frames


def loop_blend(frames, blend=6):
    """Make a clip loop seamlessly: ease the last `blend` frames into frame 0 (slerp per bone).
    Use on clips that don't loop by themselves (breakdance, emotes). The last frame equals frame 0."""
    if len(frames) <= blend + 1:
        return frames
    first_rot, first_hips = frames[0]
    out = list(frames[:-blend - 1])
    tail = frames[-blend - 1:]
    for i, (rot, hips) in enumerate(tail):
        t = i / blend
        t = t * t * (3 - 2 * t)  # smoothstep
        mixed = {n: q.slerp(first_rot.get(n, q), t) for n, q in rot.items()}
        out.append((mixed, hips.lerp(first_hips, t)))
    return out


def find_mocap(src_dir, hero_id, kind):
    """source_art/mocap/<hero>_<walk|run>.<fbx|glb|gltf>, or None."""
    for ext in (".fbx", ".glb", ".gltf"):
        p = os.path.join(src_dir, f"{hero_id}_{kind}{ext}")
        if os.path.exists(p):
            return p
    return None


if __name__ == "__main__" and "--" in sys.argv:
    PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = sys.argv[sys.argv.index("--") + 1]
    path = path if os.path.isabs(path) else os.path.join(PROJ, path)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    src, act = load_source(path)
    matched = {b.name: mixamo_name(b.name) for b in src.data.bones}
    log(f"{os.path.basename(path)}: action {act.name}, frames {tuple(act.frame_range)}, "
        f"{len(src.data.bones)} bones")
    for s, m in matched.items():
        print(f"  {s:28} -> {m or '-'}")
    missing = [c for c in CORE if "mixamorig:" + c not in matched.values()]
    log("all core bones matched" if not missing else f"MISSING core bones: {missing}")

"""
retarget_clip.py - Put a downloaded animation (Meshy GLB, Mixamo FBX, Quaternius GLB) on a hero.

Library for build_heroes.py, which lists every clip it bakes in its clip tables.

How it works:
- Source bones are matched by name: Mixamo names directly (any "mixamorigN:" prefix),
  Quaternius / Unreal-style names through UE_TO_MIXAMO, and Meshy's own 24-bone rig
  (Hips, Spine02, Spine01, Spine, neck, Head, ...) through MESHY_TO_MIXAMO. Meshy's spine
  runs Hips -> Spine02 -> Spine01 -> Spine -> neck, so its LOWEST spine bone is Spine02:
  the rig-aware mapping is used whenever a source has both Spine02 and Spine01.
- Per bone, in world space, the source's motion offset D = R_pose * R_rest^-1 is taken,
  and the target bone is first swung from its own rest direction onto the source's rest
  direction (C). The result D * C * R_target_rest copies the motion but ignores bone roll
  and fixes T-pose (Mixamo, Quaternius) vs A-pose (our Meshy heroes) arms.
- The source is resampled to the target's frame rate (24 fps), turned to face -Y, and its
  hips height (above its own floor, for skinned glTF sources) is scaled to the hero's.
- offsets_from_rig() can trim a clip (seconds), remap its time piecewise (warp) and close an
  open loop (a loop whose last key sits one key before its first: wrap). in_place() removes
  root travel; loop_blend() eases a cut segment back into its first frame.

Standalone check (does not write the hero; prints the bone mapping):
  & $env:BLENDER -b --python tools/retarget_clip.py -- source_art/mocap/meshy/tutoy_moves.glb
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
# Meshy auto-rig (24 bones). Its spine chain is Hips -> Spine02 -> Spine01 -> Spine -> neck.
MESHY_TO_MIXAMO = {"Spine02": "Spine", "Spine01": "Spine1", "Spine": "Spine2", "neck": "Neck"}
LOOP_SEAM_DEG = 3.0  # a loop whose first and last keys differ more than this is open: wrap it


def log(msg):
    print(f"[retarget] {msg}", flush=True)


def is_meshy_rig(bone_names):
    names = set(bone_names)
    return "Spine02" in names and "Spine01" in names


def mixamo_name(src_name, meshy=False):
    """'mixamorig5:LeftArm' -> 'mixamorig:LeftArm'; 'upperarm_l' -> 'mixamorig:LeftArm';
    with meshy=True, Meshy's 'Spine02' -> 'mixamorig:Spine' (its lowest spine bone)."""
    base = src_name.split(":")[-1]
    if meshy:
        if base in MESHY_TO_MIXAMO:
            return "mixamorig:" + MESHY_TO_MIXAMO[base]
        if base in ("head_end", "headfront"):
            return None  # the hero's HeadTop_End / headfront follow Head
    if base in CORE or base.startswith(("Left", "Right", "Spine", "Neck", "Head", "Hips")):
        return "mixamorig:" + base
    key = base.lower().replace("def-", "").replace("def_", "")
    m = UE_TO_MIXAMO.get(key)
    return "mixamorig:" + m if m else None


def _import(path):
    """Import a clip file; return (armature, new actions, file fps). Meshes are measured for
    the floor height (skinned glTF sources only) and dropped right away."""
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
    if ext in (".glb", ".gltf"):
        # Meshy's clip rigs stand with their soles ~10 cm under Z = 0: measure the floor from
        # the bind-pose mesh so the hips height (and so the bob/jump scale) is right.
        lows = []
        for o in new:
            if o.type == "MESH" and len(o.vertex_groups) and len(o.data.vertices):
                mw = o.matrix_world
                lows.append(min((mw @ v.co).z for v in o.data.vertices))
        if lows:
            arm["floor_z"] = min(lows)
    for o in new:
        if o.type != "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)
    acts = [a for a in bpy.data.actions if a not in acts_before]
    for a in acts:
        a["fps"] = file_fps
    return arm, acts, file_fps


def load_source(path):
    """Import a clip file; return (armature, action): its active clip, else its longest."""
    arm, acts, _ = _import(path)
    act = arm.animation_data.action if arm.animation_data and arm.animation_data.action else None
    if act is None:
        act = max(acts, key=lambda a: a.frame_range[1] - a.frame_range[0])
    return arm, act


def load_clips(path):
    """Import a multi-clip file (a Meshy moves GLB, the Quaternius library); return
    (armature, {clip name: action}). Names lose Blender's '.001' suffixes."""
    arm, acts, _ = _import(path)
    out = {}
    for a in acts:
        base = a.name
        if len(base) > 4 and base[-4] == "." and base[-3:].isdigit():
            base = base[:-4]
        out.setdefault(base, a)
    return arm, out


def discard(arm, acts):
    """Delete a loaded source rig and its actions."""
    bpy.data.objects.remove(arm, do_unlink=True)
    for a in acts:
        if a.name in bpy.data.actions:
            bpy.data.actions.remove(a)


def _key_step(act):
    """Spacing of the clip's own keys in scene frames (Meshy: 30 fps keys on a 24 fps scene)."""
    curves = list(getattr(act, "fcurves", []) or [])
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                curves += list(bag.fcurves)
    for c in curves:
        xs = sorted(k.co.x for k in c.keyframe_points)
        if len(xs) > 2:
            d = sorted(b - a for a, b in zip(xs, xs[1:]))
            return d[len(d) // 2]
    return 1.0


def pose_distance(a, b):
    """Mean rotation difference in degrees between two offset frames' bones."""
    names = [n for n in a[0] if n in b[0]]
    if not names:
        return 0.0
    return sum(math.degrees(a[0][n].rotation_difference(b[0][n]).angle) for n in names) / len(names)


def _set_action(arm, act):
    ad = arm.animation_data or arm.animation_data_create()
    for t in ad.nla_tracks:
        t.mute = True
    ad.action = act
    # Multi-clip files switch actions on one rig: make sure the slot belongs to this action.
    if hasattr(ad, "action_slot") and len(act.slots) and ad.action_slot not in list(act.slots):
        ad.action_slot = act.slots[0]


def _yaw_to_front(arm, names, meshy=False):
    """World rotation about Z that turns the source rig to face -Y (toes ahead of ankles).
    Meshy rigs splay their feet (~35 deg on one side), so both feet are averaged there."""
    mw = arm.matrix_world
    sides = ("Left", "Right") if meshy else ("Left",)
    d = Vector()
    for side in sides:
        toe, foot = names.get(f"mixamorig:{side}ToeBase"), names.get(f"mixamorig:{side}Foot")
        if not (toe and foot):
            return Quaternion()
        d += (mw @ arm.data.bones[toe].head_local) - (mw @ arm.data.bones[foot].head_local)
    d.z = 0
    if d.length < 1e-6:
        return Quaternion()
    return d.normalized().rotation_difference(Vector((0, -1, 0)))


def mocap_offsets(src_path, tgt_arm, fps=24, **kw):
    """Offset frames (rot dict, hips delta) in tgt_arm's armature space, ready for bake(..., 1.0)."""
    src, act = load_source(src_path)
    frames = offsets_from_rig(src, act, tgt_arm, fps, os.path.basename(src_path), **kw)
    bpy.data.objects.remove(src, do_unlink=True)
    bpy.data.actions.remove(act)
    return frames


def _interp(points, x):
    """Piecewise-linear lookup in [(x, y), ...] (sorted by x), clamped at the ends."""
    if x <= points[0][0]:
        return points[0][1]
    for (xa, ya), (xb, yb) in zip(points, points[1:]):
        if x <= xb:
            return ya + (yb - ya) * (x - xa) / max(xb - xa, 1e-9)
    return points[-1][1]


def offsets_from_rig(src, act, tgt_arm, fps=24, label="clip", trim=None, warp=None, loop=False):
    """Retarget `act` (played on rig `src`) onto `tgt_arm`; return [(rot dict, hips delta)].

    trim : (start_s, end_s) seconds into the source clip; None = the whole clip.
    warp : [(out_s, src_s), ...] piecewise-linear time map from the output clip to the source
           (overrides trim): e.g. squeeze a slow wind-up so a beat lands on a gameplay time.
    loop : the clip is a loop. A whole-clip loop whose last key differs from its first by more
           than LOOP_SEAM_DEG is open (its next key would be the first one): one key step is
           appended that blends back into the first frame, so the result closes exactly.
    """
    meshy = is_meshy_rig(b.name for b in src.data.bones)
    names = {}
    for b in src.data.bones:
        m = mixamo_name(b.name, meshy)
        if m and m in tgt_arm.data.bones and m not in names:
            names[m] = b.name
    missing = [c for c in CORE if "mixamorig:" + c not in names]
    if missing:
        raise SystemExit(f"{label}: no match for bones {missing}; "
                         f"source bones: {[b.name for b in src.data.bones][:40]}")

    yaw = _yaw_to_front(src, names, meshy)
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
    s_hip_h = max(s_hips_rest.z - float(src.get("floor_z", 0.0)), 1e-4)
    t_hip_h = (tgt_arm.matrix_world @ tgt_arm.data.bones["mixamorig:Hips"].head_local).z
    k = t_hip_h / s_hip_h

    _set_action(src, act)
    sc = bpy.context.scene
    src_fps = sc.render.fps / sc.render.fps_base
    if act.get("fps"):
        src_fps = float(act["fps"])
    f0, f1 = act.frame_range

    def sample(sf):
        sc.frame_set(int(math.floor(sf)), subframe=sf - math.floor(sf))
        rot = {}
        for m, s in names.items():
            pb = src.pose.bones[s]
            r_pose = s_w @ pb.matrix.to_quaternion()
            d_world = r_pose @ s_rest[m].inverted()
            want = d_world @ swing[m] @ t_rest[m]                 # world rotation of target bone
            rot[m] = (t_inv @ want @ t_rest[m].inverted() @ t_w).normalized()  # armature-space offset
        hips_now = s_w @ (src.pose.bones[hips_s].head * src_scale)
        return rot, t_inv @ ((hips_now - s_hips_rest) * k)

    wrap = 0.0
    if warp:
        pts = [(o, f0 + s * src_fps) for o, s in warp]
        dur = pts[-1][0]
    else:
        a, b = (f0, f1) if trim is None else (f0 + trim[0] * src_fps, min(f1, f0 + trim[1] * src_fps))
        if loop and trim is None:
            seam = pose_distance(sample(f0), sample(f1))
            if seam > LOOP_SEAM_DEG:
                wrap = _key_step(act)
                log(f"{label}: open loop (seam {seam:.1f} deg), closing over one key ({wrap:.2f} f)")
        pts = [(0.0, a), ((b + wrap - a) / src_fps, b + wrap)]
        dur = pts[-1][0]
    n = max(2, int(round(dur * fps)) + 1)
    first = last = None
    if wrap:
        first, last = sample(f0), sample(f1)
        travel = (last[1] - first[1]) * ((f1 - f0 + wrap) / max(f1 - f0, 1e-6))
    frames = []
    for i in range(n):
        sf = _interp(pts, dur * i / (n - 1))
        if wrap and sf > f1:
            u = min(1.0, (sf - f1) / wrap)
            rot = {m: q.slerp(first[0][m], u) for m, q in last[0].items()}
            frames.append((rot, last[1].lerp(first[1] + travel, u)))
        else:
            frames.append(sample(min(sf, f1)))
    log(f"{label}: {len(names)} bones matched{' (Meshy rig)' if meshy else ''}, {n} frames at {fps} fps "
        f"(source {src_fps:g} fps), hips x{k:.3f}")
    return frames


def _heading(q):
    f = q @ Vector((0, -1, 0))
    return math.atan2(f.x, -f.y)


def in_place(frames, loop):
    """Remove the clip's horizontal root travel; vertical bob and jumps stay.

    loop    : the last frame is brought onto the first (travel, height drift and net spin are
              removed linearly, so a closed cycle stays seamless), then the hips are centred.
    one-shot: travel along the clip's own direction is removed completely (the game moves the
              body), sideways drift linearly; small sideways sway stays.
    """
    n = len(frames)
    if n < 2:
        return frames
    out = []
    if loop:
        d = frames[-1][1] - frames[0][1]
        if Vector((d.x, d.y)).length > 0.05:
            log(f"  in place: removed {Vector((d.x, d.y)).length:.2f} m of travel per cycle, heading "
                f"{math.degrees(math.atan2(d.x, -d.y)):+.0f} deg (0 = straight ahead, -Y)")
        h0, h1 = frames[0][0]["mixamorig:Hips"], frames[-1][0]["mixamorig:Hips"]
        dyaw = (_heading(h1) - _heading(h0) + math.pi) % (2 * math.pi) - math.pi
        for i, (rot, hips) in enumerate(frames):
            t = i / (n - 1)
            turn = Quaternion((0, 0, 1), -dyaw * t)
            out.append(({k: (turn @ q).normalized() for k, q in rot.items()}, turn @ (hips - d * t)))
        mid = sum((Vector((h.x, h.y, 0)) for _, h in out), Vector()) / n
        return [(r, h - mid) for r, h in out]
    d = frames[-1][1] - frames[0][1]
    d.z = 0
    fwd = d.normalized() if d.length > 0.05 else Vector((0, -1, 0))
    log(f"  in place: removed {d.length:.2f} m of travel, heading "
        f"{math.degrees(math.atan2(fwd.x, -fwd.y)):+.0f} deg (0 = straight ahead, -Y)")
    side = Vector((-fwd.y, fwd.x, 0))
    s0, s1 = frames[0][1].dot(side), frames[-1][1].dot(side)
    f0 = frames[0][1].dot(fwd)
    for i, (rot, hips) in enumerate(frames):
        t = i / (n - 1)
        h = hips - fwd * (hips.dot(fwd) - f0) - side * ((s1 - s0) * t)
        out.append((rot, h))
    # Start on the rest spot so the clip blends from Idle without a hop.
    start = Vector((out[0][1].x, out[0][1].y, 0))
    return [(r, h - start) for r, h in out]


def face_front(frames, bone="mixamorig:Spine2", turn=0.0, auto=True):
    """Turn the whole clip about Z so `bone` (the chest) faces -Y on average (auto), then by
    `turn` more degrees (+ = toward +X, the hero's left). For clips that stand turned (Tutoy's
    Idle_5 has its chest ~42 deg off): without it the hero would stand sideways to the way the
    game points the model."""
    mean = 0.0
    if auto:
        heads = [_heading(rot[bone]) for rot, _ in frames]
        mean = math.atan2(sum(map(math.sin, heads)), sum(map(math.cos, heads)))
    turn = Quaternion((0, 0, 1), math.radians(turn) - mean)
    return [({k: (turn @ q).normalized() for k, q in rot.items()}, turn @ hips) for rot, hips in frames]


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


if __name__ == "__main__" and "--" in sys.argv:
    PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = sys.argv[sys.argv.index("--") + 1]
    path = path if os.path.isabs(path) else os.path.join(PROJ, path)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    src, clips = load_clips(path)
    meshy = is_meshy_rig(b.name for b in src.data.bones)
    matched = {b.name: mixamo_name(b.name, meshy) for b in src.data.bones}
    log(f"{os.path.basename(path)}: {len(src.data.bones)} bones{' (Meshy rig)' if meshy else ''}, "
        f"floor {float(src.get('floor_z', 0.0)):+.3f} m")
    for name, act in sorted(clips.items()):
        f0, f1 = act.frame_range
        print(f"  clip {name:28} {(f1 - f0) / float(act['fps']):6.2f} s")
    for s, m in matched.items():
        print(f"  {s:28} -> {m or '-'}")
    missing = [c for c in CORE if "mixamorig:" + c not in matched.values()]
    log("all core bones matched" if not missing else f"MISSING core bones: {missing}")

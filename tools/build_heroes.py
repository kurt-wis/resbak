"""
build_heroes.py - Idle / Walking / Running for the five Meshy-rigged heroes.

Input : source_art/heroes/<Name>_Character.glb (Meshy auto-rig, Mixamo bone names,
        A-pose, faces -Y, ONE clip each: Running, or Walking for JM).
Output: assets/characters/<id>.glb with NLA clips Idle, Walking, Running, BreakDance,
        renders/heroes_<id>_*.png stills, renders/heroes_breakdance.png dance sheet.

How the missing clips are made (no external animation library needed):
- Clips are retargeted between heroes in ARMATURE space: for every bone we take the
  source pose's rotation offset from its own rest pose (D = R_pose * R_rest^-1) and
  apply the same offset to the target's rest pose. This ignores bone roll, so it
  works even though each Meshy rig has slightly different rolls/proportions.
  Hips translation is scaled by the hip-height ratio.
- Walking comes from JM's native Walking; JM's Running comes from Tutoy's native
  Running. Heroes keep their own native clip.
- Idle is authored: legs/hips stay at rest (feet planted), upper body takes the
  average pose of the hero's Walking cycle (arms relaxed at the sides), then a
  2 s breathing/sway loop is layered on top.

Run:  & $env:BLENDER -b --python tools/build_heroes.py
"""
import bpy, os, math, sys
from mathutils import Matrix, Quaternion, Vector

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
SRC_DIR = os.path.join(PROJ, "source_art", "heroes")
OUT_DIR = os.path.join(PROJ, "assets", "characters")
RENDER_DIR = os.path.join(PROJ, "renders")

HEROES = {  # id -> source file
    "tutoy": "Tutoy_Character.glb",
    "nene": "Nene_Character.glb",
    "nathan": "Nathan_Character.glb",
    "jm": "JM_Character.glb",
    "inday": "Inday_Character.glb",
}
WALK_SOURCE = "jm"      # only hero shipped with a Walking clip
RUN_SOURCE = "tutoy"   # used for heroes without a native Running clip
IDLE_FRAMES = 48        # 2.0 s @ 24 fps
LOWER_BODY = ("Hips", "UpLeg", "Leg", "Foot", "Toe")


def log(msg):
    print(f"[build_heroes] {msg}", flush=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24


def import_hero(file_name):
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC_DIR, file_name))
    # Meshy leaves a stray 2 m Icosphere at the origin; it would wreck bounds-based scaling.
    for o in list(bpy.data.objects):
        if o.type == "MESH" and len(o.vertex_groups) == 0:
            log(f"  removing stray mesh {o.name}")
            bpy.data.objects.remove(o, do_unlink=True)
    return next(o for o in bpy.data.objects if o.type == "ARMATURE")


def rest_data(arm):
    return {b.name: b.matrix_local.copy() for b in arm.data.bones}


def sample_action(arm, action):
    """Per-frame armature-space pose matrices of every bone."""
    ad = arm.animation_data
    ad.action = action
    if hasattr(ad, "action_slot") and ad.action_slot is None and len(action.slots):
        ad.action_slot = action.slots[0]
    f0, f1 = (int(round(v)) for v in action.frame_range)
    frames = []
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        frames.append({pb.name: pb.matrix.copy() for pb in arm.pose.bones})
    return frames


def offsets_from_samples(frames, rest):
    """Convert sampled poses to (per-bone world rotation offset, hips head delta)."""
    out = []
    hips_rest = rest["mixamorig:Hips"].to_translation()
    for pose in frames:
        rot = {n: (m.to_quaternion() @ rest[n].to_quaternion().inverted()).normalized()
               for n, m in pose.items() if n in rest}
        out.append((rot, pose["mixamorig:Hips"].to_translation() - hips_rest))
    return out


def ordered_bones(arm):
    out = []
    def walk(b):
        out.append(b)
        for c in b.children:
            walk(c)
    for b in arm.data.bones:
        if b.parent is None:
            walk(b)
    return out


def bake(arm, name, offset_frames, hips_scale):
    """Write offset frames onto `arm` as a new action named `name`."""
    rest = rest_data(arm)
    bones = ordered_bones(arm)
    hips_rest = rest["mixamorig:Hips"].to_translation()
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    prev_q = {}
    for fi, (rot, hips_delta) in enumerate(offset_frames):
        pose_m = {}
        for b in bones:
            n = b.name
            # Bones missing from the source (headfront, JM's Bone_016) follow their parent rigidly.
            d = rot.get(n)
            if d is None:
                p = b.parent
                while p is not None and p.name not in rot:
                    p = p.parent
                d = rot[p.name] if p is not None else Quaternion()
            want_rot = d @ rest[n].to_quaternion()
            if b.parent is None:
                head = hips_rest + hips_delta * hips_scale
                pose_m[n] = Matrix.Translation(head) @ want_rot.to_matrix().to_4x4()
                basis = rest[n].inverted() @ pose_m[n]
            else:
                pm = pose_m[b.parent.name] @ rest[b.parent.name].inverted() @ rest[n]
                basis_q = pm.to_quaternion().inverted() @ want_rot
                basis = basis_q.to_matrix().to_4x4()
                pose_m[n] = pm @ basis
            loc, q, _ = basis.decompose()
            if n in prev_q:
                q.make_compatible(prev_q[n])
            prev_q[n] = q
            pb = arm.pose.bones[n]
            pb.rotation_mode = "QUATERNION"
            pb.location = loc if b.parent is None else Vector()
            pb.rotation_quaternion = q
            pb.keyframe_insert("location", frame=fi)
            pb.keyframe_insert("rotation_quaternion", frame=fi)
    log(f"  baked {name}: {len(offset_frames)} frames")
    return act


def quat_average(qs):
    ref = qs[0]
    w = x = y = z = 0.0
    for q in qs:
        s = -1.0 if q.dot(ref) < 0 else 1.0  # keep every sample in the same hemisphere
        w += s * q.w; x += s * q.x; y += s * q.y; z += s * q.z
    return Quaternion((w, x, y, z)).normalized()


def make_idle(walk_offsets, rest_names, children_of):
    """Legs at rest, upper body = averaged walk pose, plus a looping breath/sway."""
    base = {}
    for n in rest_names:
        if any(k in n for k in LOWER_BODY):
            base[n] = Quaternion()
        else:
            qs = [rot[n] for rot, _ in walk_offsets if n in rot]
            base[n] = quat_average(qs) if qs else Quaternion()

    def subtree(root):
        out, stack = [], [root]
        while stack:
            n = stack.pop()
            out.append(n)
            stack.extend(children_of.get(n, []))
        return out

    chest = subtree("mixamorig:Spine1")
    head = subtree("mixamorig:Head")
    larm = subtree("mixamorig:LeftArm")
    rarm = subtree("mixamorig:RightArm")
    frames = []
    for f in range(IDLE_FRAMES + 1):
        t = 2.0 * math.pi * f / IDLE_FRAMES
        breath = math.sin(t)
        rot = dict(base)
        # Axes are armature space: X = character's side, Y = back/front (faces -Y), Z = up.
        for names, q in (
            (chest, Quaternion((1, 0, 0), math.radians(1.6) * breath)),
            (head, Quaternion((0, 0, 1), math.radians(4.0) * math.sin(t + 0.6))),
            (larm, Quaternion((0, 1, 0), math.radians(-2.5) * (0.5 + 0.5 * breath))),
            (rarm, Quaternion((0, 1, 0), math.radians(2.5) * (0.5 + 0.5 * breath))),
        ):
            for n in names:
                if n in rot:
                    rot[n] = q @ rot[n]
        frames.append((rot, Vector((0.0, 0.0, 0.004 * breath))))
    return frames


# ---------------------------------------------------------------- BreakDance
# A 4 s loop for the character select: two bars of toprock (Indian step), drop to a
# squat, a two-turn spinning leg sweep on the hands, a one-arm freeze, pop back up.
# Poses are authored as limb DIRECTIONS in the hero's yaw frame (x = hero's left, -y = front,
# z = up), so the same choreography fits every rig regardless of its A-pose angle or
# bone rolls. Hips height is solved every frame so the lowest foot stays on the floor.
BD_FRAMES = 96  # 4.0 s @ 24 fps; frame 96 == frame 0


def _v(x, y, z):
    return Vector((x, y, z)).normalized()


def _m(v):  # mirror left <-> right
    return Vector((-v.x, v.y, v.z))


def _euler(p, y, r):  # degrees: pitch about X (top goes forward), yaw about Z, roll about Y
    return (Quaternion((0, 0, 1), math.radians(y)) @ Quaternion((1, 0, 0), math.radians(p))
            @ Quaternion((0, 1, 0), math.radians(r)))


GUARD_L, GUARD_LF = _v(0.55, -0.25, -0.8), _v(-0.25, -0.7, 0.65)  # fists up near the chest
STAND_LT, STAND_LS = _v(0.08, -0.05, -1), _v(0.06, 0.1, -1)
SQUAT_LT, SQUAT_LS = _v(0.35, -0.85, -0.38), _v(0.05, 0.35, -0.94)


def _pose(**kw):
    p = dict(hip=(5, 0, 0), off=(0.0, 0.0), hop=0.0, spine=(8, 0, 0), head=(-10, 0, 0),
             la=GUARD_L, lf=GUARD_LF, ra=_m(GUARD_L), rf=_m(GUARD_LF),
             lt=STAND_LT, ls=STAND_LS, rt=_m(STAND_LT), rs=_m(STAND_LS), lfoot=0.0, rfoot=0.0)
    p.update(kw)
    return p


def _mirror_pose(p):
    q = dict(p)
    q["hip"] = (p["hip"][0], -p["hip"][1], -p["hip"][2])
    q["spine"] = (p["spine"][0], -p["spine"][1], -p["spine"][2])
    q["head"] = (p["head"][0], -p["head"][1], -p["head"][2])
    q["off"] = (-p["off"][0], p["off"][1])
    for a, b in (("la", "ra"), ("lf", "rf"), ("lt", "rt"), ("ls", "rs")):
        q[a], q[b] = _m(p[b]), _m(p[a])
    q["lfoot"], q["rfoot"] = p["rfoot"], p["lfoot"]
    return q


BD_T0 = _pose()
BD_T1 = _pose(  # right foot steps across in front, arms swing open
    hip=(5, 25, -5), off=(0.03, -0.03), spine=(10, -20, 0), head=(-8, -10, 0),
    la=_v(0.95, 0.0, -0.25), lf=_v(0.9, -0.4, 0.15), ra=_v(-0.25, -0.85, -0.45), rf=_v(0.35, -0.85, 0.25),
    lt=_v(0.1, 0.05, -1), ls=_v(0.05, 0.2, -0.98), rt=_v(0.2, -0.45, -0.87), rs=_v(0.25, -0.1, -0.96))
BD_T2 = _pose(lt=_v(0.1, -0.25, -0.95), ls=_v(0.06, 0.2, -0.97),  # bounce
              rt=_m(_v(0.1, -0.25, -0.95)), rs=_m(_v(0.06, 0.2, -0.97)), spine=(12, 0, 0))
BD_T3 = _mirror_pose(BD_T1)
BD_DROP = _pose(
    hip=(35, 0, 0), spine=(25, 0, 0), head=(-40, 0, 0),
    la=_v(0.3, -0.6, -0.75), lf=_v(0.05, -0.2, -0.98), ra=_m(_v(0.3, -0.6, -0.75)), rf=_m(_v(0.05, -0.2, -0.98)),
    lt=SQUAT_LT, ls=SQUAT_LS, rt=_m(SQUAT_LT), rs=_m(SQUAT_LS))
BD_GRIND = _pose(  # squat on the left leg, right leg swept straight out, hands on the floor
    hip=(40, 0, 0), spine=(20, 0, 0), head=(-45, 0, 0),
    la=_v(0.25, -0.45, -0.85), lf=_v(0.05, -0.15, -0.99), ra=_m(_v(0.25, -0.45, -0.85)), rf=_m(_v(0.05, -0.15, -0.99)),
    lt=SQUAT_LT, ls=SQUAT_LS, rt=_v(-0.85, -0.35, -0.55), rs=_v(-0.85, -0.35, -0.55), rfoot=-30.0)
BD_FREEZE = _pose(  # one hand down, other arm punched to the sky
    hip=(25, 0, -15), spine=(5, 15, -10), head=(-30, 15, 0),
    la=_v(0.6, -0.1, -0.8), lf=_v(0.3, 0.0, -0.95), ra=_v(-0.6, -0.1, 0.8), rf=_v(-0.45, -0.15, 0.9),
    lt=SQUAT_LT, ls=SQUAT_LS, rt=_m(SQUAT_LT), rs=_m(SQUAT_LS))
BD_KEYS = [(0, BD_T0), (6, BD_T1), (12, BD_T2), (18, BD_T3), (24, BD_T0), (30, BD_T1), (36, BD_T2),
           (42, BD_T3), (48, BD_T0), (54, BD_DROP), (58, BD_GRIND), (84, BD_GRIND), (88, BD_FREEZE),
           (92, BD_FREEZE), (96, BD_T0)]
SPIN_START, SPIN_END = 58, 84  # two full turns during the sweep


def _smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def _blend(a, b, t):
    out = {}
    for k, va in a.items():
        vb = b[k]
        if isinstance(va, Vector):
            out[k] = va.lerp(vb, t).normalized()
        elif isinstance(va, tuple):
            out[k] = tuple(x + (y - x) * t for x, y in zip(va, vb))
        else:
            out[k] = va + (vb - va) * t
    return out


def _controls(f):
    for (fa, a), (fb, b) in zip(BD_KEYS, BD_KEYS[1:]):
        if fa <= f <= fb:
            p = _blend(a, b, _smooth((f - fa) / (fb - fa)))
            break
    if SPIN_START <= f <= SPIN_END:
        s = (f - SPIN_START) / (SPIN_END - SPIN_START)
        p["hip"] = (p["hip"][0], 720.0 * _smooth(s), p["hip"][2])
        # the swept leg also fans forward and back a little on each turn
        a = math.radians(205 + 25 * math.sin(4 * math.pi * s))
        sweep = _v(math.cos(a), math.sin(a), -0.55)
        p["rt"], p["rs"] = sweep, sweep
    return p


def make_breakdance(arm):
    rest = rest_data(arm)
    head = {n: m.to_translation() for n, m in rest.items()}

    def seg(a, b):
        return head["mixamorig:" + b] - head["mixamorig:" + a]

    def swing(a, b, want):
        return seg(a, b).normalized().rotation_difference(want)

    hips0 = head["mixamorig:Hips"]
    ankle_z = min(head["mixamorig:LeftFoot"].z, head["mixamorig:RightFoot"].z)
    frames = []
    for f in range(BD_FRAMES + 1):
        p = _controls(f)
        d_hips = _euler(*p["hip"])
        # Limbs aim in a yaw-only frame: pelvis/spine tilt must not drag the feet off the
        # floor or the hands away from it, but the spin still carries everything around.
        d_yaw = _euler(0, p["hip"][1], 0)
        sp = _euler(*(c / 3.0 for c in p["spine"]))
        d_sp = d_hips @ sp
        d_sp1 = d_sp @ sp
        d_sp2 = d_sp1 @ sp
        hd = _euler(*(c / 2.0 for c in p["head"]))
        rot = {"mixamorig:Hips": d_hips, "mixamorig:Spine": d_sp, "mixamorig:Spine1": d_sp1,
               "mixamorig:Spine2": d_sp2, "mixamorig:Neck": d_sp2 @ hd, "mixamorig:Head": d_sp2 @ hd @ hd}
        ankles = []
        for side, up, lo, foot in (("Left", p["lt"], p["ls"], p["lfoot"]), ("Right", p["rt"], p["rs"], p["rfoot"])):
            rot[f"mixamorig:{side}Arm"] = d_yaw @ swing(f"{side}Arm", f"{side}ForeArm", p["la" if side == "Left" else "ra"])
            rot[f"mixamorig:{side}ForeArm"] = d_yaw @ swing(f"{side}ForeArm", f"{side}Hand", p["lf" if side == "Left" else "rf"])
            d_up = d_yaw @ swing(f"{side}UpLeg", f"{side}Leg", up)
            d_lo = d_yaw @ swing(f"{side}Leg", f"{side}Foot", lo)
            rot[f"mixamorig:{side}UpLeg"] = d_up
            rot[f"mixamorig:{side}Leg"] = d_lo
            rot[f"mixamorig:{side}Foot"] = d_lo @ Quaternion((1, 0, 0), math.radians(foot))
            # Where this ankle lands relative to the hips (same FK the bake will do).
            ankles.append((d_hips @ seg("Hips", f"{side}UpLeg") + d_up @ seg(f"{side}UpLeg", f"{side}Leg")
                           + d_lo @ seg(f"{side}Leg", f"{side}Foot")).z)
        dz = ankle_z - (hips0.z + min(ankles)) + p["hop"]
        frames.append((rot, Vector((p["off"][0], p["off"][1], dz))))
    return frames


def render_dance_strip(arm, hero_id):
    """Six dance frames side by side from the character-select camera angle."""
    sc = bpy.context.scene
    arm.animation_data.action = bpy.data.actions["BreakDance"]
    paths = []
    for f in (6, 18, 54, 66, 76, 90):
        sc.frame_set(f)
        path = os.path.join(RENDER_DIR, f"_bd_{hero_id}_{f}.png")
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def render_sheet(arm, hero_id):
    """Quarter top-down review sheet: idle / walk / run, matching the game camera."""
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x, sc.render.resolution_y = 360, 480
    world = bpy.data.worlds.new("W"); sc.world = world
    world.color = (0.8, 0.78, 0.72)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.0; sun.rotation_euler = (math.radians(40), 0, math.radians(30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.4
    sc.collection.objects.link(cam); sc.camera = cam
    # Game camera sits above and in front (+Z Godot = -Y Blender), looking down ~56 deg.
    cam.location = (0, -5.5, 8.0)
    cam.rotation_euler = (math.radians(34), 0, 0)
    shots = []
    for clip, frame in (("Idle", 0), ("Walking", 6), ("Running", 4)):
        arm.animation_data.action = bpy.data.actions[clip]
        sc.frame_set(frame)
        path = os.path.join(RENDER_DIR, f"heroes_{hero_id}_{clip.lower()}.png")
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        shots.append(path)
    log(f"  renders: {', '.join(os.path.basename(s) for s in shots)}")


def export(arm, hero_id):
    ad = arm.animation_data
    while len(ad.nla_tracks):
        ad.nla_tracks.remove(ad.nla_tracks[0])
    for name in ("Idle", "Walking", "Running", "BreakDance"):
        act = bpy.data.actions[name]
        tr = ad.nla_tracks.new(); tr.name = name
        strip = tr.strips.new(name, int(act.frame_range[0]), act); strip.name = name
    ad.action = None
    out = os.path.join(OUT_DIR, f"{hero_id}.glb")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", export_animations=True,
        export_animation_mode="NLA_TRACKS", export_skins=True,
        export_materials="EXPORT", export_apply=False,
    )
    log(f"  exported {os.path.relpath(out, PROJ)}")


def native_clip(hero_id, clip):
    reset()
    arm = import_hero(HEROES[hero_id])
    act = next((a for a in bpy.data.actions if a.name.lower() == clip.lower()), None)
    if act is None:
        return None, None
    rest = rest_data(arm)
    offs = offsets_from_samples(sample_action(arm, act), rest)
    return offs, rest["mixamorig:Hips"].to_translation().z


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(RENDER_DIR, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(HEROES)
    walk_src, walk_hips = native_clip(WALK_SOURCE, "Walking")
    run_src, run_hips = native_clip(RUN_SOURCE, "Running")
    assert walk_src and run_src, "source clips missing"
    dance_strips = {}
    for hero_id in only:
        log(f"hero {hero_id}")
        reset()
        arm = import_hero(HEROES[hero_id])
        if arm.animation_data is None:
            arm.animation_data_create()
        rest = rest_data(arm)
        hips_z = rest["mixamorig:Hips"].to_translation().z
        clips = {}
        for a in list(bpy.data.actions):
            low = a.name.lower()
            if low in ("walking", "running"):
                # Re-bake native clips too, so every clip has identical tracks and a clean name.
                clips[low.capitalize()] = offsets_from_samples(sample_action(arm, a), rest)
            bpy.data.actions.remove(a)
        ad = arm.animation_data
        while len(ad.nla_tracks):
            ad.nla_tracks.remove(ad.nla_tracks[0])
        if "Walking" in clips:
            walk = clips["Walking"]
            bake(arm, "Walking", walk, 1.0)
        else:
            walk = walk_src
            bake(arm, "Walking", walk_src, hips_z / walk_hips)
        if "Running" in clips:
            bake(arm, "Running", clips["Running"], 1.0)
        else:
            bake(arm, "Running", run_src, hips_z / run_hips)
        children = {}
        for b in arm.data.bones:
            if b.parent:
                children.setdefault(b.parent.name, []).append(b.name)
        bake(arm, "Idle", make_idle(walk, list(rest), children), 1.0)
        bake(arm, "BreakDance", make_breakdance(arm), 1.0)
        render_sheet(arm, hero_id)
        dance_strips[hero_id] = render_dance_strip(arm, hero_id)
        export(arm, hero_id)
    _contact_sheet(dance_strips, os.path.join(RENDER_DIR, "heroes_breakdance.png"))
    log("done")


def _contact_sheet(strips, out):
    """Rows = heroes, columns = dance frames, packed into one PNG for review."""
    if not strips:
        return
    imgs = {k: [bpy.data.images.load(p) for p in v] for k, v in strips.items()}
    w, h = imgs[next(iter(imgs))][0].size
    cols, rows = max(len(v) for v in imgs.values()), len(imgs)
    sheet = bpy.data.images.new("bd_sheet", cols * w, rows * h, alpha=True)
    px = [0.0] * (cols * w * rows * h * 4)
    for r, (k, row) in enumerate(imgs.items()):
        for c, img in enumerate(row):
            src = list(img.pixels)
            y0 = (rows - 1 - r) * h  # Blender images start at the bottom row
            for y in range(h):
                a = (y * w) * 4
                b = ((y0 + y) * cols * w + c * w) * 4
                px[b:b + w * 4] = src[a:a + w * 4]
    sheet.pixels = px
    sheet.filepath_raw = out
    sheet.file_format = "PNG"
    sheet.save()
    for row in strips.values():
        for p in row:
            os.remove(p)
    log(f"  dance sheet: {os.path.relpath(out, PROJ)}")


main()

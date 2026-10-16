"""
build_heroes.py - Idle / Walking / Running for the five Meshy-rigged heroes.

Input : source_art/heroes/<Name>_Character.glb (Meshy auto-rig, Mixamo bone names,
        A-pose, faces -Y, ONE clip each: Running, or Walking for JM).
Output: assets/characters/<id>.glb with NLA clips Idle, Walking, Running,
        renders/heroes_<id>.png review sheet.

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
    "tutoy": "Dodong_Character.glb",  # file keeps its old name; the hero is Tutoy
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
    for name in ("Idle", "Walking", "Running"):
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
        render_sheet(arm, hero_id)
        export(arm, hero_id)
    log("done")


main()

"""
build_heroes.py - Idle / Walking / Running / BreakDance for the five Meshy-rigged heroes.

Input : source_art/heroes/<Name>_Character.glb (Meshy auto-rig, Mixamo bone names, A-pose, faces -Y)
        mixamo/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb (Quaternius, CC0)
        mixamo/breakdance-pack/*.fbx (Mixamo breakdance pack on X Bot)
Output: assets/characters/<id>.glb with NLA clips Idle, Walking, Running, BreakDance,
        renders/heroes_<id>_*.png stills, renders/heroes_breakdance.png dance sheet.

- Idle / Running are Quaternius Idle_Loop / Jog_Fwd_Loop and Walking is JM's Meshy walk, for
  everyone, retargeted by tools/retarget_clip.py (handles T-pose vs A-pose and bone roll, 24 fps).
  A per-hero file source_art/mocap/<id>_walk.* / <id>_run.* overrides the shared clip.
- BreakDance is each hero's own routine of Mixamo moves (BREAKDANCE below). Each move has its
  root drift (travel, height, spin) removed, moves are cross-faded, and the end eases into
  frame 0 so the loop is seamless. Character select plays it; gameplay never does.
- After changing clips, re-measure foot speeds with tools/qc_asset.py and update
  walk_clip_speed / run_clip_speed in scripts/runtime/hero_roster.gd.

Run:  & $env:BLENDER -b --python tools/build_heroes.py            (all heroes)
      & $env:BLENDER -b --python tools/build_heroes.py -- nene    (one hero)
"""
import bpy, os, math, sys
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import retarget_clip  # noqa: E402  (tools/retarget_clip.py)

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
SRC_DIR = os.path.join(PROJ, "source_art", "heroes")
OUT_DIR = os.path.join(PROJ, "assets", "characters")
RENDER_DIR = os.path.join(PROJ, "renders")
MOCAP_DIR = os.path.join(PROJ, "source_art", "mocap")  # optional <id>_walk / <id>_run clips
QUATERNIUS = os.path.join(PROJ, "mixamo", "Universal Animation Library[Standard]", "Unreal-Godot", "UAL1_Standard.glb")
MIXAMO_DIR = os.path.join(PROJ, "mixamo", "breakdance-pack")

HEROES = {  # id -> source file
    "tutoy": "Tutoy_Character.glb",
    "nene": "Nene_Character.glb",
    "nathan": "Nathan_Character.glb",
    "jm": "JM_Character.glb",
    "inday": "Inday_Character.glb",
}
LOCOMOTION = {"Idle": "Idle_Loop", "Running": "Jog_Fwd_Loop"}
# Quaternius' Walk_Loop is a slow stroll (feet push ~0.8 m/s); at the design's 2.5 m/s walk it
# would play ~3x. The brisker walk Meshy shipped with JM (~1.3 m/s) needs ~1.9x instead.
WALK_SOURCE = os.path.join(SRC_DIR, "JM_Character.glb")
# Each hero's own breakdance: Mixamo moves played in order, (file, repeats). Every move here
# starts and ends in the same pose, so the routine loops cleanly.
BREAKDANCE = {
    "tutoy": [("breakdance footwork 2.fbx", 1), ("flair (2).fbx", 2)],   # street kid: footwork into flares
    "nene": [("breakdance uprock var 1.fbx", 2)],                         # bouncy uprock
    "nathan": [("breakdance footwork 1.fbx", 1)],                         # six-step footwork
    "jm": [("breakdance freezes.fbx", 1)],                                # big-man power freezes
    "inday": [("brooklyn uprock.fbx", 1)],                                # Brooklyn uprock, dips to the floor
}
CROSSFADE = 8  # frames between moves and at the loop seam
PAD_RADIUS = 0.35  # m of floor travel allowed on the select-screen pad


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


def _blend_frame(a, b, t):
    ra, ha = a
    rb, hb = b
    return ({n: q.slerp(rb.get(n, q), t) for n, q in ra.items()}, ha.lerp(hb, t))


def _heading(q):
    f = q @ Vector((0, -1, 0))
    return math.atan2(f.x, -f.y)


def remove_drift(frames):
    """Cancel a move's net travel, height change and spin so its last frame lands on its first."""
    n = len(frames)
    if n < 2:
        return frames
    d = frames[-1][1] - frames[0][1]
    hips0, hips1 = frames[0][0]["mixamorig:Hips"], frames[-1][0]["mixamorig:Hips"]
    dyaw = (_heading(hips1) - _heading(hips0) + math.pi) % (2 * math.pi) - math.pi
    out = []
    for i, (rot, hips) in enumerate(frames):
        t = i / (n - 1)
        turn = Quaternion((0, 0, 1), -dyaw * t)
        out.append(({k: (turn @ q).normalized() for k, q in rot.items()}, turn @ (hips - d * t)))
    return out


def concat(a, b, fade=CROSSFADE):
    """a then b, with the last `fade` frames of a cross-faded into the first `fade` of b."""
    if not a:
        return list(b)
    fade = min(fade, len(a) - 1, len(b) - 1)
    out = list(a[:-fade])
    for i in range(fade):
        t = (i + 1) / (fade + 1)
        out.append(_blend_frame(a[len(a) - fade + i], b[i], t * t * (3 - 2 * t)))
    return out + list(b[fade:])


def _mesh_lows(arm, act, count):
    """Lowest skinned-mesh point (armature space Z) on each of the first `count` frames."""
    body = [o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm]
    arm.animation_data.action = act
    f0 = int(act.frame_range[0])
    lows = []
    for i in range(count):
        bpy.context.scene.frame_set(f0 + i)
        dg = bpy.context.evaluated_depsgraph_get()
        low = 1e9
        for o in body:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            low = min(low, min((ev.matrix_world @ v.co).z for v in me.vertices))
            ev.to_mesh_clear()
        lows.append(low)
    return lows


def bake_grounded(arm, name, frames):
    """Bake, then shift the whole clip so its lowest sole touches the floor: retargeted hips
    heights otherwise leave feet a few cm under or over it."""
    act = bake(arm, name, frames, 1.0)
    dz = -min(_mesh_lows(arm, act, len(frames)))
    if abs(dz) > 0.003:
        bpy.data.actions.remove(act)
        act = bake(arm, name, [(r, h + Vector((0, 0, dz))) for r, h in frames], 1.0)
        log(f"  grounded {name}: {dz * 100:+.1f} cm")
    return act


def bake_on_floor(arm, name, frames):
    """Bake, then lift any frame whose skinned mesh dips under the floor (a kid's big head and
    short arms reach the ground sooner than the adult rig the moves were captured on)."""
    act = bake(arm, name, frames, 1.0)
    raw = [max(0.0, -low) for low in _mesh_lows(arm, act, len(frames))]
    # Widen each lift (running max) then soften it (running mean) so the body eases up and
    # down instead of popping. Indices wrap: the clip loops.
    n, w = len(raw), 3
    wide = [max(raw[(i + k) % n] for k in range(-w, w + 1)) for i in range(n)]
    lifts = [sum(wide[(i + k) % n] for k in range(-w, w + 1)) / (2 * w + 1) for i in range(n)]
    if max(lifts) > 0.003:
        bpy.data.actions.remove(act)
        act = bake(arm, name, [(r, h + Vector((0, 0, d))) for (r, h), d in zip(frames, lifts)], 1.0)
        log(f"  kept {name} above the floor (max lift {max(lifts) * 100:.1f} cm)")
    return act


def quaternius_clips(arm, wanted):
    """{our clip name: offset frames} from the Quaternius library, loaded once per hero."""
    acts_before = set(bpy.data.actions)
    src, _ = retarget_clip.load_source(QUATERNIUS)
    new_acts = [a for a in bpy.data.actions if a not in acts_before]
    out = {}
    for ours, theirs in wanted.items():
        act = next(a for a in new_acts if a.name == theirs or a.name.startswith(theirs + "."))
        out[ours] = retarget_clip.offsets_from_rig(src, act, arm, label=theirs)
    bpy.data.objects.remove(src, do_unlink=True)
    for a in new_acts:
        bpy.data.actions.remove(a)
    return out


def breakdance(arm, hero_id):
    frames = []
    for file_name, repeats in BREAKDANCE[hero_id]:
        move = remove_drift(retarget_clip.mocap_offsets(os.path.join(MIXAMO_DIR, file_name), arm))
        for _ in range(repeats):
            frames = concat(frames, move)
    return retarget_clip.loop_blend(keep_on_pad(frames), blend=CROSSFADE)


def keep_on_pad(frames, radius=PAD_RADIUS):
    """Uprocks wander up to a metre; centre the routine and shrink its floor travel so the
    dancer stays on the select-screen pad (feet slide a little, which the camera hides)."""
    xy = [Vector((h.x, h.y)) for _, h in frames]
    mid = sum(xy, Vector((0, 0))) / len(xy)
    reach = max((v - mid).length for v in xy)
    k = min(1.0, radius / reach) if reach > 1e-6 else 1.0
    out = []
    for (rot, h), v in zip(frames, xy):
        d = (v - mid) * k
        out.append((rot, Vector((d.x, d.y, h.z))))
    return out


def render_dance_strip(arm, hero_id, count=6):
    """Evenly spaced BreakDance frames from the review camera, for the contact sheet."""
    sc = bpy.context.scene
    act = bpy.data.actions["BreakDance"]
    arm.animation_data.action = act
    f0, f1 = act.frame_range
    paths = []
    for i in range(count):
        f = int(f0 + (f1 - f0) * (i + 0.5) / count)
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
    # Clip sources (e.g. JM_Character.glb for the walk) can bring Meshy's stray Icosphere back.
    for o in list(bpy.data.objects):
        if o.type == "MESH" and len(o.vertex_groups) == 0:
            bpy.data.objects.remove(o, do_unlink=True)
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


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(RENDER_DIR, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(HEROES)
    dance_strips = {}
    for hero_id in only:
        log(f"hero {hero_id}")
        reset()
        arm = import_hero(HEROES[hero_id])
        if arm.animation_data is None:
            arm.animation_data_create()
        ad = arm.animation_data
        ad.action = None
        while len(ad.nla_tracks):
            ad.nla_tracks.remove(ad.nla_tracks[0])
        for a in list(bpy.data.actions):  # the one sample clip Meshy shipped
            bpy.data.actions.remove(a)
        clips = quaternius_clips(arm, LOCOMOTION)
        clips["Walking"] = retarget_clip.mocap_offsets(WALK_SOURCE, arm)
        for ours, kind in (("Walking", "walk"), ("Running", "run")):
            own = retarget_clip.find_mocap(MOCAP_DIR, hero_id, kind)
            if own:
                clips[ours] = retarget_clip.mocap_offsets(own, arm)
        for name in ("Idle", "Walking", "Running"):
            bake_grounded(arm, name, clips[name])
        bake_on_floor(arm, "BreakDance", breakdance(arm, hero_id))
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

"""
qc_asset.py - Look at a model before calling it done: a 4-view sheet plus hard numbers.

Blender scripts report "success" even when a mesh floats, faces backwards or a walk
cycle skates, so every model or animation change ends with this check.

Input : any .glb/.gltf/.fbx (repo-relative or absolute path).
Output: renders/qc/<name>_sheet.png  front / side / top / 3-4 view, solid + wireframe
        renders/qc/<name>_qc.json    the numbers below
        stdout                       one PASS/WARN/FAIL line per check

Checks
- size and ground: height, lowest point (should be Z = 0), XY centre (should be ~0)
- facing (rigged heroes): toes must point to -Y in Blender, which is +Z (Vector3.MODEL_FRONT) in Godot
- unapplied object scale / rotation, stray unskinned meshes in a rigged file
- normals: share of faces pointing away from the mesh centre (inside-out meshes score low)
- open edges / non-manifold edges, triangle count against --max-tris
- rig: Mixamo bone names; per clip: length, tracks, loop seam, hips root motion, and
  foot-plant speed in GAME metres per second (scaled the way HeroController scales the
  model, to --height metres). If the character moves faster than its planted foot, the
  feet skate; the clip's playback must be scaled or the blend point moved.

Run:  & $env:BLENDER -b --python tools/qc_asset.py -- assets/characters/nene.glb
      ... -- assets/characters/nene.glb --clip Running --frame 4   (sheet in that pose)
      ... -- assets/characters/tutoy.glb --speed Walking=2.7 --speed Running=5.4
      ... -- assets/props/kimkim.glb --max-tris 3000 --height 0     (floor props: keep real size)
      ... -- assets/props/kimkim.glb --height 0 --held                 (held/thrown props)
Exit code is 1 if any check FAILs.
"""
import bpy, bmesh, os, sys, math, json, argparse
from mathutils import Vector

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
OUT_DIR = os.path.join(PROJ, "renders", "qc")
GAME_HEIGHT = 1.8   # HeroController.model_height: heroes are scaled to this in Godot
PLANT_TOL = 0.03    # m (game scale): a foot this close to its lowest point counts as planted
TOE_BONES = ("mixamorig:LeftToeBase", "mixamorig:RightToeBase")
FOOT_BONES = ("mixamorig:LeftFoot", "mixamorig:RightFoot")


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(prog="qc_asset.py")
    p.add_argument("file")
    p.add_argument("--clip", default=None, help="pose the sheet on this clip")
    p.add_argument("--frame", type=int, default=0)
    p.add_argument("--max-tris", type=int, default=15000)
    p.add_argument("--height", type=float, default=GAME_HEIGHT,
                   help="game height the model is scaled to (0 = keep its real size)")
    p.add_argument("--speed", action="append", default=[], metavar="CLIP=M/S",
                   help="game speed a clip plays at, e.g. Running=5.4; skating over 10%% is flagged")
    p.add_argument("--held", action="store_true",
                   help="held or thrown prop: origin at its middle instead of on the floor")
    p.add_argument("--no-render", action="store_true")
    return p.parse_args(argv)


results = []


def check(name, status, detail):
    results.append({"check": name, "status": status, "detail": detail})
    print(f"[qc] {status:4} {name}: {detail}", flush=True)


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    before = set(bpy.data.objects)
    ext = os.path.splitext(path)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        raise SystemExit(f"unsupported file type {ext}")
    # The glTF importer parks bone display shapes (an "Icosphere") in glTF_not_exported;
    # they are not part of the file, so leave them out of every check.
    return [o for o in bpy.data.objects if o not in before
            and not any(c.name == "glTF_not_exported" for c in o.users_collection)]


def world_bounds(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        e = o.evaluated_get(dg)
        for c in e.bound_box:
            p = e.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
    return lo, hi


def mesh_checks(meshes, rigged, max_tris):
    tris = 0
    for m in meshes:
        bm = bmesh.new(); bm.from_mesh(m.data)
        bm.transform(m.matrix_world)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        tris += len(bm.faces)
        centre = sum((v.co for v in bm.verts), Vector()) / max(len(bm.verts), 1)
        out = sum(1 for f in bm.faces if f.normal.dot(f.calc_center_median() - centre) > 0)
        share = out / max(len(bm.faces), 1)
        check(f"normals {m.name}", "PASS" if share >= 0.6 else ("WARN" if share >= 0.4 else "FAIL"),
              f"{share:.0%} of faces point outward (inside-out meshes score under 40%)")
        open_e = sum(1 for e in bm.edges if e.is_boundary)
        nonman = sum(1 for e in bm.edges if not e.is_manifold and not e.is_boundary)
        # glTF splits vertices along UV seams, so open edges are expected on imports.
        check(f"topology {m.name}", "PASS" if nonman == 0 else "WARN",
              f"{nonman} non-manifold edges ({open_e} open edges, normal at UV seams)")
        bm.free()
        s, r = m.scale, m.rotation_euler
        if m.parent is None and (max(abs(x - 1) for x in s) > 1e-3 or max(abs(x) for x in r) > 1e-3):
            check(f"transforms {m.name}", "WARN", f"unapplied scale {tuple(round(x, 3) for x in s)} "
                  f"/ rotation {tuple(round(math.degrees(x), 1) for x in r)} deg")
        if rigged and len(m.vertex_groups) == 0:
            check(f"stray mesh {m.name}", "WARN", "unskinned mesh in a rigged file (a prop, or left over?)")
    check("triangles", "PASS" if tris <= max_tris else "WARN", f"{tris} (budget {max_tris})")
    return tris


def track_paths(act):
    """Unique animated channels (Blender 5 actions keep F-curves in layered channelbags)."""
    curves = list(getattr(act, "fcurves", []) or [])
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                curves += list(bag.fcurves)
    return {(c.data_path, c.array_index) for c in curves}


def clip_report(arm, act, scale):
    sc = bpy.context.scene
    ad = arm.animation_data
    ad.action = act
    for t in ad.nla_tracks:
        t.mute = True
    f0, f1 = (int(round(x)) for x in act.frame_range)
    fps = sc.render.fps / sc.render.fps_base
    bones = [b for b in TOE_BONES if b in arm.pose.bones] or [b for b in FOOT_BONES if b in arm.pose.bones]
    feet = {b: [] for b in bones}
    hips, poses = [], []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        mw = arm.matrix_world
        for b in bones:
            feet[b].append(mw @ arm.pose.bones[b].head)
        if "mixamorig:Hips" in arm.pose.bones:
            hips.append(mw @ arm.pose.bones["mixamorig:Hips"].head)
        poses.append([pb.matrix.copy() for pb in arm.pose.bones])
    speeds = []
    for pts in feet.values():
        zlow = min(p.z for p in pts)
        for a, b in zip(pts, pts[1:]):
            if (a.z - zlow) * scale < PLANT_TOL and (b.z - zlow) * scale < PLANT_TOL:
                d = b - a; d.z = 0
                speeds.append(d.length * scale * fps)
    speeds.sort()
    plant = speeds[len(speeds) // 2] if speeds else 0.0
    seam = max((poses[0][i].to_translation() - poses[-1][i].to_translation()).length
               for i in range(len(poses[0]))) * scale
    root = ((hips[-1] - hips[0]).length * scale) if hips else 0.0
    tracks = len(track_paths(act))
    return {"clip": act.name, "frames": [f0, f1], "seconds": round((f1 - f0) / fps, 3),
            "tracks": tracks, "foot_plant_speed_mps": round(plant, 2),
            "loop_seam_m": round(seam, 3), "hips_root_motion_m": round(root, 3)}


def set_wire(meshes, on, size):
    """Workbench renders ignore wireframe shading, so the wire pass swaps in a Wireframe modifier."""
    sh = bpy.context.scene.display.shading
    sh.light, sh.color_type = ("FLAT", "SINGLE") if on else ("STUDIO", "TEXTURE")
    sh.single_color = (0, 0, 0)
    for m in meshes:
        mod = m.modifiers.get("QC_Wire")
        if on and mod is None:
            mod = m.modifiers.new("QC_Wire", "WIREFRAME")
            mod.thickness = size * 0.0012
            mod.use_even_offset = False  # even offset spikes on Meshy's sliver triangles
        elif not on and mod is not None:
            m.modifiers.remove(mod)


def render_sheet(objs, name, lo, hi):
    """Four ortho views, solid shading with a wireframe pass multiplied on top."""
    meshes = [o for o in objs if o.type == "MESH"]
    import numpy as np
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.type = "SOLID"
    sc.display.shading.show_cavity = True
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.film_transparent = True
    size = max((hi - lo).length, 0.1)
    mid = (lo + hi) / 2
    cam = bpy.data.objects.new("QC_Cam", bpy.data.cameras.new("QC_Cam"))
    cam.data.type = "ORTHO"; cam.data.ortho_scale = size * 1.1
    cam.data.clip_end = size * 20
    sc.collection.objects.link(cam); sc.camera = cam
    views = {  # name -> (direction from centre to camera, rotation)
        "front": (Vector((0, -1, 0)), (math.radians(90), 0, 0)),
        "side": (Vector((1, 0, 0)), (math.radians(90), 0, math.radians(90))),
        "top": (Vector((0, 0, 1)), (0, 0, 0)),
        "quarter": (Vector((1, -1, 0.8)).normalized(), None),
    }
    tiles = []
    tmp = os.path.join(OUT_DIR, "_tile.png")
    for view, (d, rot) in views.items():
        cam.location = mid + d * size * 5
        if rot is None:
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        else:
            cam.rotation_euler = rot
        layers = []
        for wire in (False, True):
            set_wire(meshes, wire, size)
            sc.render.filepath = tmp
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(tmp, check_existing=False)
            px = np.array(img.pixels[:], dtype=np.float32).reshape(512, 512, 4)
            bpy.data.images.remove(img)
            layers.append(px)
        solid, wire = layers
        bg = np.array([0.86, 0.84, 0.80], dtype=np.float32)
        rgb = solid[..., :3] * solid[..., 3:4] + bg * (1 - solid[..., 3:4])
        rgb *= 1 - 0.45 * wire[..., 3:4]
        rgb[2:4, :, :] = rgb[:, 2:4, :] = 0.3  # ground line hint and tile edge
        tiles.append(rgb)
    os.remove(tmp)
    top = np.concatenate([tiles[2], tiles[3]], axis=1)      # image rows run bottom-up
    bottom = np.concatenate([tiles[0], tiles[1]], axis=1)
    sheet = np.concatenate([bottom, top], axis=0)
    out = bpy.data.images.new("qc_sheet", 1024, 1024)
    out.pixels = np.concatenate([sheet, np.ones((1024, 1024, 1), np.float32)], axis=2).ravel()
    path = os.path.join(OUT_DIR, f"{name}_sheet.png")
    out.filepath_raw = path; out.file_format = "PNG"; out.save()
    return path


def main():
    a = args()
    path = a.file if os.path.isabs(a.file) else os.path.join(PROJ, a.file)
    name = os.path.splitext(os.path.basename(path))[0]
    os.makedirs(OUT_DIR, exist_ok=True)
    objs = load(path)
    meshes = [o for o in objs if o.type == "MESH"]
    arm = next((o for o in objs if o.type == "ARMATURE"), None)
    rigged = arm is not None
    body = [m for m in meshes if not rigged or len(m.vertex_groups) > 0] or meshes

    # Importers may activate the first clip (often BreakDance) at frame zero.
    # Measure the bind mesh, as Godot does, rather than mistaking a crouch for its height.
    if arm:
        arm.data.pose_position = "REST"
        bpy.context.view_layer.update()
    lo, hi = world_bounds(body)
    if arm:
        arm.data.pose_position = "POSE"
        bpy.context.view_layer.update()
    h = hi.z - lo.z
    scale = a.height / h if a.height > 0 and h > 0 else 1.0
    report = {"file": os.path.relpath(path, PROJ), "real_height_m": round(h, 3),
              "game_scale": round(scale, 3), "dims_m": [round(x, 3) for x in hi - lo]}
    if a.held:
        cz = (lo.z + hi.z) / 2
        check("origin", "PASS" if abs(cz) <= 0.01 else "FAIL", f"Z centre = {cz:.3f} m (want 0 for a held prop)")
    else:
        check("ground", "PASS" if abs(lo.z) <= 0.01 else "FAIL", f"lowest point Z = {lo.z:.3f} m (want 0)")
    cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
    check("centred", "PASS" if max(abs(cx), abs(cy)) <= 0.05 * max(h, 0.1) else "WARN",
          f"XY centre ({cx:.3f}, {cy:.3f}) m")
    report["triangles"] = mesh_checks(meshes, rigged, a.max_tris)

    if rigged:
        names = [b.name for b in arm.data.bones]
        mix = sum(n.startswith("mixamorig:") for n in names)
        check("mixamo names", "PASS" if mix == len(names) else "WARN", f"{mix}/{len(names)} bones")
        toes = [arm.data.bones.get(b) for b in TOE_BONES]
        foot = [arm.data.bones.get(b) for b in FOOT_BONES]
        if all(toes) and all(foot):
            dy = sum(t.head_local.y - f.head_local.y for t, f in zip(toes, foot)) / 2
            check("facing", "PASS" if dy < 0 else "FAIL",
                  f"toes {'-Y' if dy < 0 else '+Y'} of ankles (want -Y = Godot +Z front)")
        want = {k.lower(): float(v) for k, v in (x.split("=") for x in a.speed)}
        report["clips"] = []
        for act in sorted(bpy.data.actions, key=lambda x: x.name):
            c = clip_report(arm, act, scale)
            report["clips"].append(c)
            check(f"clip {c['clip']}", "PASS" if c["loop_seam_m"] < 0.02 else "WARN",
                  f"{c['seconds']} s, {c['tracks']} channels, foot plant {c['foot_plant_speed_mps']} m/s, "
                  f"loop seam {c['loop_seam_m']} m, root motion {c['hips_root_motion_m']} m")
            game = want.get(c["clip"].lower())
            if game and c["foot_plant_speed_mps"] > 0:
                ratio = game / c["foot_plant_speed_mps"]
                c["skate_ratio"] = round(ratio, 2)
                check(f"foot slide {c['clip']}", "PASS" if abs(ratio - 1) <= 0.1 else "FAIL",
                      f"moves {game} m/s, feet push {c['foot_plant_speed_mps']} m/s: x{ratio:.2f} "
                      f"(play the clip at x{ratio:.2f} or put its blend point at {c['foot_plant_speed_mps']} m/s)")

    if not a.no_render:
        if rigged and a.clip:
            act = bpy.data.actions.get(a.clip)
            if act:
                arm.animation_data.action = act
        bpy.context.scene.frame_set(a.frame)
        lo2, hi2 = world_bounds(body)
        report["sheet"] = os.path.relpath(render_sheet(objs, name, lo2, hi2), PROJ)
        print(f"[qc] sheet {report['sheet']}  (bottom: front, side; top: top, 3/4)", flush=True)

    report["checks"] = results
    with open(os.path.join(OUT_DIR, f"{name}_qc.json"), "w") as f:
        json.dump(report, f, indent=1)
    fails = [r for r in results if r["status"] == "FAIL"]
    print(f"[qc] {name}: {len(fails)} FAIL, {sum(r['status'] == 'WARN' for r in results)} WARN", flush=True)
    sys.exit(1 if fails else 0)


main()

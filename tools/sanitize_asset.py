"""
sanitize_asset.py - Make a raw Meshy (or downloaded) PROP game-ready in one pass.

Rigged characters do not go through here; they use build_heroes.py.

Input : a raw .glb/.gltf/.fbx, usually in source_art/ or imported_models/
Output: assets/props/<name>.glb, then run qc_asset.py on it

Steps (bmesh and data-blocks only, no selection-dependent bpy.ops edits):
1. drop importer helpers and empty objects, join every mesh's world transform into its data
   (scale and rotation applied, Z-up kept: the glTF exporter turns it into Godot's Y-up)
2. recalculate normals to face outside
3. optional: scale so the longest side is --size metres (Meshy exports about 1 m by default)
4. move the origin: --origin bottom (floor props: base at Z = 0, centred on X/Y) or
   --origin center (held or thrown props, e.g. Nathan's Kimkim, which spins around its middle)
5. optional: decimate (collapse) down to --max-tris
6. export GLB with materials and textures

Run:  & $env:BLENDER -b --python tools/sanitize_asset.py -- source_art/heroes/KimKim_Asset.glb --name kimkim --size 0.25 --origin center
      & $env:BLENDER -b --python tools/qc_asset.py -- assets/props/kimkim.glb --height 0 --held
"""
import bpy, bmesh, os, sys, argparse
from mathutils import Matrix, Vector

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
OUT_DIR = os.path.join(PROJ, "assets", "props")


def log(msg):
    print(f"[sanitize] {msg}", flush=True)


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(prog="sanitize_asset.py")
    p.add_argument("file")
    p.add_argument("--name", default=None, help="output name (default: input file name, lower case)")
    p.add_argument("--size", type=float, default=0.0, help="longest side in metres (0 = keep)")
    p.add_argument("--origin", choices=("bottom", "center"), default="bottom")
    p.add_argument("--max-tris", type=int, default=0, help="decimate to this many triangles (0 = keep)")
    return p.parse_args(argv)


def main():
    a = args()
    src = a.file if os.path.isabs(a.file) else os.path.join(PROJ, a.file)
    name = a.name or os.path.splitext(os.path.basename(src))[0].lower()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ext = os.path.splitext(src)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=src)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=src)
    else:
        raise SystemExit(f"unsupported file type {ext}")
    if any(o.type == "ARMATURE" for o in bpy.data.objects):
        raise SystemExit("rigged file: characters go through tools/build_heroes.py, not this script")

    for o in list(bpy.data.objects):
        if any(c.name == "glTF_not_exported" for c in o.users_collection) or o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("no meshes found")

    # 1-2: bake transforms into the mesh data and fix normals.
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        bm = bmesh.new(); bm.from_mesh(o.data)
        bm.transform(mw)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(o.data); bm.free()
        o.matrix_world = Matrix.Identity(4)

    def bounds():
        pts = [v.co for o in meshes for v in o.data.vertices]
        return (Vector(map(min, *pts)), Vector(map(max, *pts)))

    # 3: scale.
    lo, hi = bounds()
    if a.size > 0:
        k = a.size / max(hi - lo)
        for o in meshes:
            o.data.transform(Matrix.Scale(k, 4))
        log(f"scaled x{k:.3f} (longest side {max(hi - lo):.3f} -> {a.size} m)")
        lo, hi = bounds()

    # 4: origin.
    c = (lo + hi) / 2
    pivot = Vector((c.x, c.y, lo.z if a.origin == "bottom" else c.z))
    for o in meshes:
        o.data.transform(Matrix.Translation(-pivot))
    log(f"origin at {a.origin} (moved by {tuple(round(x, 3) for x in -pivot)})")

    # 5: decimate through the evaluated mesh (no modifier_apply operator needed).
    if a.max_tris > 0:
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
        if tris > a.max_tris:
            ratio = a.max_tris / tris
            dg = bpy.context.evaluated_depsgraph_get()
            for o in meshes:
                mod = o.modifiers.new("Decimate", "DECIMATE"); mod.ratio = ratio
                dg.update()
                new = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
                o.modifiers.remove(mod)
                old, o.data = o.data, new
                bpy.data.meshes.remove(old)
            log(f"decimated {tris} -> ~{int(tris * ratio)} triangles")

    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_materials="EXPORT",
                              export_animations=False, export_yup=True)
    log(f"exported {os.path.relpath(out, PROJ)}; now run tools/qc_asset.py on it")


main()

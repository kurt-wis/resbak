"""
build_sand_castle.py - Procedural sand castle: the Konstruksyon base prop (2026-10-17).

Konstruksyon is a harbour building site, so each team's base is a sand castle on a pile of
site sand instead of the court's basketball stand. Presentation only: the base's solid pole
collider, ring and capture rules live in BaseSystem and do not change.

Output: assets/props/sand_castle.glb   (floor prop: base at Z = 0, centred on X/Y, ~2.3 m tall)
        assets/props/sand_castle.tscn  (instances the GLB; the game loads this)
Objects in the GLB:
  SandCastle  mound, keep, four corner turrets, crenellations, tall tower, flag pole
  Flag        a separate pennant (white, tinted per team by ArenaArt; waved and lowered in play)
Materials: sand, sand_dark, wood, flag. No textures; everything is flat colour, low poly.

Run:  & $env:BLENDER -b --python tools/build_sand_castle.py
Then: & $env:BLENDER -b --python tools/qc_asset.py -- assets/props/sand_castle.glb --height 0 --max-tris 3000
Rebuild is deterministic (fixed jitter seed). Godot picks the GLB up on the next --import.
"""
import bpy, bmesh, os, math, random

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
OUT_GLB = os.path.join(PROJ, "assets", "props", "sand_castle.glb")
OUT_TSCN = os.path.join(PROJ, "assets", "props", "sand_castle.tscn")
SEED = 7


def log(msg):
    print(f"[sand_castle] {msg}", flush=True)


def material(name, rgb, rough=0.95):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m


def srgb(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x ** 2.2 for x in c]  # sRGB -> linear for the Principled input


def wipe():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials):
        for b in list(block):
            block.remove(b)


def finish(obj, mat, rng, jitter=0.0):
    """Apply transforms, jitter the verts a little (hand-patted sand), flat-shade, assign."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if jitter > 0.0:
        for v in obj.data.vertices:
            v.co.x += rng.uniform(-jitter, jitter)
            v.co.y += rng.uniform(-jitter, jitter)
            v.co.z += rng.uniform(-jitter, jitter) * 0.5
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    bpy.ops.object.shade_flat()
    obj.select_set(False)
    return obj


def cyl(r, h, x, y, z0, mat, rng, verts=10, r_top=None, jitter=0.012):
    """Cylinder (or tapered cylinder) standing on z0."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r_top is None else r_top,
                                    depth=h, location=(x, y, z0 + h * 0.5))
    return finish(bpy.context.active_object, mat, rng, jitter)


def cone(r, h, x, y, z0, mat, rng, verts=10):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=0.0, depth=h, location=(x, y, z0 + h * 0.5))
    return finish(bpy.context.active_object, mat, rng, 0.006)


def box(sx, sy, sz, x, y, z0, mat, rng, rot=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, z0 + sz * 0.5), rotation=(0, 0, rot))
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    return finish(o, mat, rng, 0.004)


def build():
    wipe()
    rng = random.Random(SEED)
    sand = material("sand", srgb("e3c27d"))
    sand_dark = material("sand_dark", srgb("c29a57"))
    wood = material("wood", srgb("6b4a2b"))
    flag_m = material("flag", srgb("ffffff"), 0.7)
    parts = []

    # site-sand mound the castle sits on (wide, low, a darker damp skirt)
    parts.append(cyl(0.72, 0.16, 0, 0, 0.0, sand_dark, rng, verts=14, r_top=0.6, jitter=0.02))
    parts.append(cyl(0.58, 0.16, 0, 0, 0.14, sand, rng, verts=14, r_top=0.5, jitter=0.015))
    # keep: the squat main block, with a darker door
    parts.append(cyl(0.40, 0.62, 0, 0, 0.28, sand, rng, verts=12, r_top=0.37))
    parts.append(box(0.16, 0.08, 0.26, 0, -0.37, 0.30, sand_dark, rng))
    # crenellations around the keep's top edge
    ztop = 0.90
    for i in range(8):
        a = i * math.tau / 8
        parts.append(box(0.12, 0.09, 0.11, math.cos(a) * 0.35, math.sin(a) * 0.35, ztop, sand, rng, rot=a))
    # four corner turrets with cone roofs, set into the keep's skirt
    for i in range(4):
        a = math.radians(45 + i * 90)
        x, y = math.cos(a) * 0.5, math.sin(a) * 0.5
        parts.append(cyl(0.13, 0.78, x, y, 0.24, sand, rng, verts=9, r_top=0.115))
        parts.append(cone(0.17, 0.26, x, y, 1.02, sand_dark, rng, verts=9))
    # tall central tower
    parts.append(cyl(0.2, 0.55, 0, 0, 0.9, sand, rng, verts=10, r_top=0.17))
    parts.append(cone(0.26, 0.3, 0, 0, 1.45, sand_dark, rng, verts=10))
    # flag pole on top
    parts.append(cyl(0.022, 0.62, 0, 0, 1.7, wood, rng, verts=6, jitter=0.0))

    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    castle = bpy.context.active_object
    castle.name = "SandCastle"
    castle.data.name = "SandCastle"

    # pennant: a flat triangle-ish quad at the pole top, pointing +X (waves around the pole)
    me = bpy.data.meshes.new("Flag")
    z = 2.22
    bm = bmesh.new()
    kite = [bm.verts.new(v) for v in [(0.0, 0.0, z), (0.1, 0.0, z - 0.12), (0.0, 0.0, z - 0.24), (0.46, 0.0, z - 0.12)]]
    face = bm.faces.new([kite[0], kite[3], kite[2], kite[1]])
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])  # a thin closed slab, so it reads from both sides
    moved = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0.0, 0.012, 0.0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    flag = bpy.data.objects.new("Flag", me)
    bpy.context.collection.objects.link(flag)
    bpy.context.view_layer.objects.active = flag
    flag.select_set(True)
    me.materials.append(flag_m)
    bpy.ops.object.shade_flat()
    flag.select_set(False)

    # origin: castle base at Z = 0, centred on X/Y (already built that way); verify
    zs = [v.co.z for v in castle.data.vertices]
    log(f"castle z {min(zs):.3f}..{max(zs):.3f}, flag top {z:.2f}, tris {sum(len(p.vertices) - 2 for p in castle.data.polygons)}")
    return castle, flag


def export():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_materials="EXPORT",
                              export_apply=True, export_yup=True, export_animations=False)
    log(f"wrote {os.path.relpath(OUT_GLB, PROJ)}")
    with open(OUT_TSCN, "w", newline="\n") as f:
        f.write('[gd_scene load_steps=2 format=3]\n\n'
                '[ext_resource type="PackedScene" path="res://assets/props/sand_castle.glb" id="1_castle"]\n\n'
                '[node name="SandCastle" instance=ExtResource("1_castle")]\n')
    log(f"wrote {os.path.relpath(OUT_TSCN, PROJ)}")


if __name__ == "__main__":
    build()
    export()

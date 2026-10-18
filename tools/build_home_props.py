"""
build_home_props.py - the set dressing for the Home diorama (2026-10-17, Meshy import route 2026-10-18).

Two kinds of prop come out of this script, all into assets/props/home/:

  MESHY set pieces (source_art/props/home/<name>.glb, one textured mesh each, 10-190 MB):
      sari-sari store, crate stack, plastic stool, banana plant, house, utility pole, two tricycles -
      all generated from the crop script's reference crops (see tools/crop_home_reference.py) - plus
      the older stall / tree / graffiti pieces. Each is decimated to a tri budget, its textures cut
      to TEX px and packed, then scaled by its fit rule (see MESHY below), centred on X/Y and
      grounded. The front stays on +Z (Godot) as Meshy exports it. A few carry a cleanup for what
      their crop dragged in: see CLEAN below.

  PROCEDURAL props (no source files, no credits): the sign boards, sidewalk strip, wire spans, and
      the little things the bystanders hold - paper fan, payong, water gallon, backpack. Built from
      primitives with flat painted colours so the project toon shader reads them like the rest of
      the set. Overhead cables stay procedural: Meshy cannot make a thin sagging cable, and it reads
      the reference's own cables as flat strips baked into the pole's texture.

Every prop is written as <name>.glb plus a <name>.tscn that instances it (the diorama instances the
.tscn, so a rebuilt GLB never touches scene edits). Hand-held props are authored with their GRIP at the
origin: the diorama parents them to a BoneAttachment3D on the hand and the grip lands in the palm.

Run:    & $env:BLENDER -b --python tools/build_home_props.py                (everything)
        & $env:BLENDER -b --python tools/build_home_props.py -- store wire_span (some, in any mix)
Then:   & $env:BLENDER -b --python tools/qc_asset.py -- assets/props/home/<name>.glb --height 0 --max-tris 95000
"""
import bpy, os, sys, math
from mathutils import Vector, Matrix, Euler

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
SRC = os.path.join(PROJ, "source_art", "props", "home")
OUT = os.path.join(PROJ, "assets", "props", "home")

# ---- Meshy set pieces -----------------------------------------------------------------------------
# name: (node name, fit mode, target, tri budget, texture px)
#   fit "w"   -> the width along X becomes `target` metres  (most props: a crop sets the width)
#   fit "h"   -> the height along Z becomes `target` metres (the utility pole: width is not fixed)
#   fit "box" -> fits inside a (x, y, z) target box        (vehicles: keeps a long, low silhouette)
MESHY = {
    # generated from crops of the reference art (source_art/reference/home_crops/)
    "store": ("SariSariStore", "w", 5.20, 90000, 2048),
    "crate_stack": ("CrateStack", "w", 1.50, 24000, 1024),
    "plastic_stool": ("PlasticStool", "w", 0.40, 8000, 512),
    "banana_plant": ("BananaPlant", "w", 1.80, 30000, 1024),
    "house_left": ("HouseLeft", "w", 4.60, 45000, 2048),
    "power_pole": ("PowerPole", "h", 7.60, 22000, 1024),
    "tricycle_blue": ("TricycleBlue", "box", (2.50, 1.30, 1.75), 32000, 1024),
    "tricycle_right": ("TricycleRight", "box", (2.50, 1.30, 1.75), 32000, 1024),
    # older set pieces, still in the diorama
    "fruit_stall": ("FruitStall", "w", 2.6, 25000, 1024),
    "graffiti_wall": ("GraffitiWall", "w", 3.6, 30000, 1024),
    "mango_tree": ("MangoTree", "w", 6.0, 40000, 1024),
    "coconut_palm": ("CoconutPalm", "w", 4.5, 30000, 1024),
}

# ---- per-prop cleanup: fixes for what the source crop dragged in -----------------------------------
#   light_marks: erase print that is *lighter* than the panel under it, whatever its hue (the crate
#               stack's crop carries the soda script; that trade dress is not ours to ship). A pale
#               tint of the crate colour defeats any saturation test, so this one is local contrast.
#   pale_fill : repaint near-white, unsaturated texture pixels with the colour of the panel around
#               them (kept for props whose marks really are white)
#   cut_radius: drop geometry further than this many metres from the Z axis. Meshy reads the
#               reference's overhead cables as flat strips; the diorama draws its own wire spans, so
#               the pole keeps only the pole, its cross-arms and the transformer.
#   axis_xy   : centre on the prop's own vertical axis instead of on its bounding box (the pole
#               stands on the wire line, so the trunk - not the cross-arm - belongs at the origin)
#   desaturate: strip the colour out of the texture, keeping its shading. The monobloc stool is one
#               model in the reference and three colours in the diorama (red, blue, teal), so it
#               ships grey and HomeDiorama multiplies the data's tint into the albedo at build time.
CLEAN = {
    "crate_stack": {"light_marks": {"radius": 6, "delta": 0.05, "rounds": 60, "dilate": 2}},
    "power_pole": {"cut_radius": 1.05, "axis_xy": True},
    "plastic_stool": {"desaturate": 1.0, "value": 0.92},
}


def log(msg):
    print(f"[home_props] {msg}", flush=True)


def bounds(objs):
    # from the vertices: Object.bound_box is cached and goes stale after mesh.transform()
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def tris(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


def axis_of(objs):
    """The prop's own vertical axis, in world X/Y: the centre of its bottom slice.

    Meshy puts the origin wherever it likes and the crop's cables make the bounding box useless for
    finding a pole, so the trunk is measured from the bottom of the model."""
    verts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    zs = [v.z for v in verts]
    zmin, zmax = min(zs), max(zs)
    base = [v for v in verts if v.z <= zmin + 0.06 * max(zmax - zmin, 1e-6)]
    return Vector((sum(v.x for v in base) / len(base), sum(v.y for v in base) / len(base), 0.0))


def cut_radius(objs, r, axis):
    """Delete every face further than r m from `axis` (the pole's baked-in cable strips).

    `context="FACES"` keeps the verts the faces used, so loose verts are swept afterwards: they
    carry no geometry but they do carry bounds(), which would size and ground the prop on nothing."""
    import bmesh
    killed = 0
    swept = 0
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        kill = [f for f in bm.faces
                if max(math.hypot(v.co.x - axis.x, v.co.y - axis.y) for v in f.verts) > r]
        killed += len(kill)
        if kill:
            bmesh.ops.delete(bm, geom=kill, context="FACES")
            loose = [v for v in bm.verts if not v.link_faces]
            swept += len(loose)
            if loose:
                bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()
    log(f"cut_radius: axis ({axis.x:.2f}, {axis.y:.2f}), dropped {killed} faces beyond {r} m, "
        f"swept {swept} loose verts")


def _box_blur(plane, radius):
    """Separable moving average over a 2D float plane, edges clamped."""
    import numpy as np
    r = max(1, int(radius))
    n = 2 * r + 1
    p = np.pad(plane, ((r, r), (r, r)), mode="edge")
    c = np.cumsum(p, axis=0)
    c = np.concatenate([np.zeros((1, c.shape[1]), dtype=c.dtype), c], axis=0)
    rows = (c[n:] - c[:-n]) / n
    c2 = np.cumsum(rows, axis=1)
    c2 = np.concatenate([np.zeros((c2.shape[0], 1), dtype=c2.dtype), c2], axis=1)
    return (c2[:, n:] - c2[:, :-n]) / n


def light_marks(objs, radius=6, delta=0.05, rounds=48, dilate=2):
    """Erase print that is *lighter* than the panel it sits on, whatever its hue.

    A soda script is a pale tint of the crate colour, not white, so a saturation test misses it: on
    red plastic the letters are light red. What they always are is brighter than the panel around
    them, so the mask is local contrast against a box blur. The pixels are then replaced by the
    colour of the panel, which is what the surrounding area already is."""
    import numpy as np
    done = set()
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if not m or not m.node_tree:
                continue
            for n in m.node_tree.nodes:
                img = getattr(n, "image", None)
                if n.type != "TEX_IMAGE" or not img or img.name in done:
                    continue
                done.add(img.name)
                w, h = img.size
                if w < 2 or h < 2:
                    continue
                buf = np.empty(w * h * 4, dtype=np.float32)
                img.pixels.foreach_get(buf)
                px = buf.reshape(h, w, 4)
                rgb = px[:, :, :3]
                value = rgb.mean(axis=2)
                todo = (value - _box_blur(value, radius)) > delta
                for _ in range(max(0, dilate)):
                    grown = todo.copy()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        grown |= np.roll(np.roll(todo, dy, 0), dx, 1)
                    todo = grown
                n_marked = int(todo.sum())
                if not n_marked:
                    continue
                fill = rgb.copy()
                for _ in range(rounds):
                    if not todo.any():
                        break
                    known = ~todo
                    acc = np.zeros_like(rgb)
                    cnt = np.zeros((h, w), dtype=np.float32)
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        k = np.roll(np.roll(known, dy, 0), dx, 1).astype(np.float32)
                        acc += np.roll(np.roll(fill, dy, 0), dx, 1) * k[:, :, None]
                        cnt += k
                    edge = todo & (cnt > 0)
                    if not edge.any():
                        break
                    fill[edge] = acc[edge] / cnt[edge][:, None]
                    todo &= ~edge
                px[:, :, :3] = fill
                img.pixels.foreach_set(buf)
                img.pack()
                log(f"light_marks: {img.name} {w}x{h}, {n_marked} marked pixels "
                    f"({100.0 * n_marked / (w * h):.2f}%), radius {radius}, delta {delta}")


def desaturate(objs, amount=1.0, value=1.0):
    """Remove colour from every texture slot, keeping the shading, and lift the result to `value`.

    Greyscale here is a plain channel mean, not a luma weight: the stool's blue plastic has a low
    luma, so a luma conversion would bake a dark tint into the model and the red/teal data tints
    would come out muddy."""
    import numpy as np
    done = set()
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if not m or not m.node_tree:
                continue
            for n in m.node_tree.nodes:
                img = getattr(n, "image", None)
                if n.type != "TEX_IMAGE" or not img or img.name in done:
                    continue
                done.add(img.name)
                w, h = img.size
                if w < 2 or h < 2:
                    continue
                buf = np.empty(w * h * 4, dtype=np.float32)
                img.pixels.foreach_get(buf)
                px = buf.reshape(h, w, 4)
                rgb = px[:, :, :3]
                grey = rgb.mean(axis=2)
                grey = grey * (float(value) / max(1e-4, float(grey.mean())))
                px[:, :, :3] = rgb + (grey[:, :, None] - rgb) * float(amount)
                img.pixels.foreach_set(buf)
                img.pack()
                log(f"desaturate: {img.name} {w}x{h} -> grey {float(px[:, :, :3].mean()):.3f}")
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if not m or not m.node_tree:
                continue
            for n in m.node_tree.nodes:
                if n.type != "BSDF_PRINCIPLED":
                    continue
                sock = n.inputs["Base Color"]
                if not sock.links:  # a linked texture already carries the grey
                    sock.default_value = (value, value, value, 1.0)


def pale_fill(objs, sat=0.10, val=0.40, rounds=10, dilate=0):
    """Repaint near-white, unsaturated pixels with the colour of the panel around them.

    Blender holds image pixels linearly, so a white pixel sits near 1.0 on every channel and a
    saturated panel keeps a wide channel spread. `dilate` grows the mask outwards first: a glyph is
    pale only in its core, and its anti-aliased rim would otherwise survive as a white ghost of the
    word. Filling costs the thin highlights as well, which is what we want on the crates: no trade
    dress, just weathered plastic."""
    import numpy as np
    done = set()
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if not m or not m.node_tree:
                continue
            for n in m.node_tree.nodes:
                img = getattr(n, "image", None)
                if n.type != "TEX_IMAGE" or not img or img.name in done:
                    continue
                done.add(img.name)
                w, h = img.size
                if w < 2 or h < 2:
                    continue
                buf = np.empty(w * h * 4, dtype=np.float32)
                img.pixels.foreach_get(buf)
                px = buf.reshape(h, w, 4)
                rgb = px[:, :, :3]
                mx, mn = rgb.max(axis=2), rgb.min(axis=2)
                todo = (mx > val) & ((mx - mn) < sat)
                for _ in range(max(0, dilate)):
                    grown = todo.copy()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        grown |= np.roll(np.roll(todo, dy, 0), dx, 1)
                    todo = grown
                n_pale = int(todo.sum())
                if not n_pale:
                    continue
                fill = rgb.copy()
                for _ in range(rounds):
                    if not todo.any():
                        break
                    known = ~todo
                    acc = np.zeros_like(rgb)
                    cnt = np.zeros((h, w), dtype=np.float32)
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        k = np.roll(np.roll(known, dy, 0), dx, 1).astype(np.float32)
                        acc += np.roll(np.roll(fill, dy, 0), dx, 1) * k[:, :, None]
                        cnt += k
                    edge = todo & (cnt > 0)
                    if not edge.any():
                        break
                    fill[edge] = acc[edge] / cnt[edge][:, None]
                    todo &= ~edge
                px[:, :, :3] = fill
                img.pixels.foreach_set(buf)
                img.pack()
                log(f"pale_fill: {img.name} {w}x{h}, {n_pale} pale pixels ({100.0 * n_pale / (w * h):.1f}%), dilate {dilate}")


def write_tscn(name, node):
    with open(os.path.join(OUT, name + ".tscn"), "w", newline="\n") as f:
        f.write('[gd_scene load_steps=2 format=3]\n\n')
        f.write(f'[ext_resource type="PackedScene" path="res://assets/props/home/{name}.glb" id="1_{name}"]\n\n')
        f.write(f'[node name="{node}" instance=ExtResource("1_{name}")]\n')


def export(name, node, objs):
    os.makedirs(OUT, exist_ok=True)
    glb = os.path.join(OUT, name + ".glb")
    lo, hi = bounds(objs)       # before the export: the operator can leave the data stale afterwards
    sz = hi - lo
    n_tris = tris(objs)
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_materials="EXPORT",
                              export_image_format="AUTO", export_yup=True, export_apply=True)
    write_tscn(name, node)
    log(f"{name}: {sz.x:.2f} x {sz.y:.2f} x {sz.z:.2f} m (W x D x H)  {n_tris} tris  -> {os.path.relpath(glb, PROJ)}")


def build_meshy(name):
    node, fit, target, budget, tex = MESHY[name]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + ".glb"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in meshes:            # flatten the import hierarchy into world-space meshes
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    before = tris(meshes)
    for o in meshes:
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
    if before > budget:
        for o in meshes:
            mod = o.modifiers.new("Decimate", "DECIMATE")
            mod.ratio = budget / before
            mod.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=mod.name)
    lo, hi = bounds(meshes)
    size = hi - lo
    if fit == "w":
        s = target / size.x
    elif fit == "h":
        s = target / size.z
    else:                       # "box": the longest axis decides, so the silhouette keeps its shape
        s = min(target[0] / size.x, target[1] / size.y, target[2] / size.z)
    clean = CLEAN.get(name) or {}
    for o in meshes:
        o.data.transform(Matrix.Scale(s, 4))
        o.data.update()
    axis = axis_of(meshes) if clean.get("axis_xy") else None
    if clean.get("cut_radius"):
        cut_radius(meshes, clean["cut_radius"], axis if axis is not None else axis_of(meshes))
    lo, hi = bounds(meshes)                 # after the scale and any cut, never before
    if axis is None:
        axis = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, 0.0))
    shift = Vector((-axis.x, -axis.y, -lo.z))
    for o in meshes:
        o.data.transform(Matrix.Translation(shift))
        o.data.update()
        o.name = node if len(meshes) == 1 else f"{node}_{o.name}"
    marks = clean.get("light_marks")
    if marks:
        light_marks(meshes, **marks)
    if clean.get("pale_fill"):
        pale_fill(meshes, sat=float(clean.get("sat", 0.10)), val=float(clean.get("val", 0.40)),
                  rounds=int(clean.get("rounds", 16)), dilate=int(clean.get("dilate", 0)))
    if clean.get("desaturate"):
        desaturate(meshes, amount=float(clean["desaturate"]), value=float(clean.get("value", 1.0)))
    for img in bpy.data.images:
        if img.size[0] > tex or img.size[1] > tex:
            img.scale(min(tex, img.size[0]), min(tex, img.size[1]))
            img.pack()
    log(f"{name}: {before} -> {tris(meshes)} tris, scale {s:.3f}")
    export(name, node, meshes)


# ---- procedural props -----------------------------------------------------------------------------
# Conventions: Blender -Y is the front (it becomes Godot +Z), Z is up. Set pieces are grounded and
# centred on X/Y. Hand-held props have their GRIP at the origin and their long axis on +Z.
_mats = {}


def mat(name, rgb, rough=0.85, alpha=1.0):
    key = (name, rgb, rough, alpha)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Alpha"].default_value = alpha
    if alpha < 1.0:
        try:
            m.surface_render_method = "BLENDED"
        except (AttributeError, TypeError):
            pass
    _mats[key] = m
    return m


def hexc(h):
    """'#RRGGBB' in sRGB -> linear floats for Blender's colour sockets."""
    c = [int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


def prim(kind, name, loc, size, material, rot=(0, 0, 0), smooth=False, seg=16):
    """One primitive baked into world space. kind: cube | cyl | cone | sphere. size = (x, y, z) full extents
    (a cyl/cone/sphere's x and y are DIAMETERS, z the height). A cone's radius1 is the base, radius2 the tip."""
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=0.5, depth=1)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=0.5, radius2=0.0, depth=1)
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(6, seg // 2), radius=0.5)
    o = bpy.context.active_object
    o.name = name
    o.data.transform(Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1.0)))
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def fin(name, node, objs, ground=True, centre=True):
    """Centre on X/Y and ground on Z = 0 (each optional: a prop whose origin is its grip or anchor keeps
    the origin where it was authored), then export."""
    lo, hi = bounds(objs)
    shift = Vector((-(lo.x + hi.x) * 0.5 if centre else 0.0, -(lo.y + hi.y) * 0.5 if centre else 0.0,
                    -lo.z if ground else 0.0))
    for o in objs:
        o.data.transform(Matrix.Translation(shift))
    export(name, node, objs)


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


WOOD = hexc("#8A5A33")
WOOD_DK = hexc("#5E3B22")
METAL = hexc("#5B5F66")
PLASTIC_RED = hexc("#D23A2E")




def build_wire_span(span=8.0, sag=0.45):
    """Three sagging cables hung between two pole tops `span` m apart along X, starting at X = 0."""
    fresh()
    black = mat("Wire", hexc("#1B1B1D"), 0.6)
    objs = []
    z = 6.72      # top of the upper crossarm's insulators (power_pole)
    for off in (-0.72, 0.0, 0.72):
        # a parabola sampled as thin box segments
        n = 24
        pts = [Vector((i / n * span, 0.0, -4 * sag * (i / n) * (1 - i / n))) for i in range(n + 1)]
        for a, b in zip(pts, pts[1:]):
            mid = (a + b) * 0.5
            ln = (b - a).length
            ang = math.atan2(b.z - a.z, b.x - a.x)
            objs.append(prim("cube", "Cable", (mid.x, off, mid.z + z), (ln, 0.025, 0.025), black, rot=(0, -ang, 0)))
    fin("wire_span", "WireSpan", objs, ground=False, centre=False)


def _text_mesh(body, size, material, extrude=0.012):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    o = bpy.data.objects.new("Letters", cu)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.data.materials.append(material)
    return o


def build_sign(name, node, text, w, h, board_hex, text_hex, size, rim_hex):
    """Painted sign board with raised letters on its -Y (front) face. Hangs with its bottom edge at Z = 0."""
    fresh()
    board = mat("SignBoard", hexc(board_hex), 0.8)
    rim = mat("SignRim", hexc(rim_hex), 0.8)
    ink = mat("SignInk", hexc(text_hex), 0.6)
    t = 0.05
    objs = [prim("cube", "Board", (0, 0, h / 2), (w, t, h), board)]
    for sz, z in (((w, t * 1.4, 0.04), 0.02), ((w, t * 1.4, 0.04), h - 0.02)):
        objs.append(prim("cube", "Rim", (0, 0, z), sz, rim))
    for sx in (-w / 2 + 0.02, w / 2 - 0.02):
        objs.append(prim("cube", "Rim", (sx, 0, h / 2), (0.04, t * 1.4, h), rim))
    letters = _text_mesh(text, size, ink)
    xs = [v.co.x for v in letters.data.vertices]
    ys = [v.co.y for v in letters.data.vertices]
    fit = min(1.0, (w - 0.3) / (max(xs) - min(xs)), (h - 0.2) / (max(ys) - min(ys)))  # clear of the rim
    letters.data.transform(Matrix.Diagonal((fit, fit, 1.0, 1.0)))
    letters.data.transform(Matrix.Translation((0, -t / 2 - 0.006, h / 2)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    objs.append(letters)
    fin(name, node, objs, ground=False)


def build_store_base():
    """The stall's lower half: a plank counter and its dark under-panel, 5.9 x 1.7 x 1.15 m.

    The store model was generated from a crop cut off at the counter line (the reference's own seated
    cast covers everything below it), so the stall has to stand on this: it fills the band between the
    model's bottom edge and the ground, which is where the reference draws the counter, the price
    lists and the ICE board. Painted flat, like the rest of the procedural props."""
    fresh()
    plank = mat("CounterPlank", hexc("#B08148"), 0.9)
    panel = mat("CounterPanel", hexc("#4A3524"), 0.95)
    trim = mat("CounterTrim", hexc("#7A5A32"), 0.9)
    w, d, h = 5.9, 1.7, 1.15
    objs = [
        prim("cube", "Panel", (0, 0, (h - 0.08) * 0.5), (w, d, h - 0.08), panel),
        prim("cube", "Top", (0, 0, h - 0.04), (w + 0.12, d + 0.12, 0.08), plank),
        prim("cube", "Rail", (0, -d * 0.5 - 0.03, h - 0.22), (w, 0.07, 0.16), trim),   # edge band on the front
        prim("cube", "Skirt", (0, -d * 0.5 - 0.02, 0.12), (w, 0.05, 0.24), trim),
    ]
    for i in range(6):                                                              # front battens
        x = (i - 2.5) * (w / 6.0)
        objs.append(prim("cube", f"Batten{i}", (x, -d * 0.5 - 0.01, h * 0.5), (0.09, 0.05, h - 0.16), trim))
    fin("store_base", "StoreBase", objs)


def build_sidewalk(length=16.0, depth=2.4):
    """Concrete sidewalk with 2 m tiles and a raised curb on the +Y edge (the road side, behind). Top at 0.14 m."""
    fresh()
    a, b = mat("TileA", hexc("#B9B2A4"), 0.95), mat("TileB", hexc("#A9A294"), 0.95)
    curb = mat("Curb", hexc("#C9C2B2"), 0.9)
    objs = []
    n = int(length / 2.0)
    for i in range(n):
        x = (i - (n - 1) / 2) * 2.0
        objs.append(prim("cube", f"Tile{i}", (x, 0, 0.07), (1.97, depth, 0.14), a if i % 2 == 0 else b))
    objs.append(prim("cube", "Curb", (0, depth / 2 + 0.1, 0.1), (length, 0.22, 0.2), curb))
    fin("sidewalk", "Sidewalk", objs)


# --- hand-held / worn props (grip at the origin, long axis +Z) -------------------------------------


def build_paper_fan():
    """Pamaypay: a round woven fan on a short handle. Grip at the handle, the disc faces -Y."""
    fresh()
    straw, rim, handle = mat("Buri", hexc("#E3C27A"), 0.9), mat("FanRim", hexc("#B8442E"), 0.8), mat("FanHandle", WOOD, 0.9)
    objs = [prim("cyl", "Handle", (0, 0, 0.05), (0.016, 0.016, 0.16), handle, seg=8, smooth=True),
            prim("cyl", "Disc", (0, 0, 0.21), (0.26, 0.012, 0.26), straw, rot=(math.pi / 2, 0, 0), seg=28, smooth=True),
            prim("cyl", "Rim", (0, 0.0, 0.21), (0.27, 0.014, 0.27), rim, rot=(math.pi / 2, 0, 0), seg=28)]
    fin("paper_fan", "PaperFan", objs, ground=False)


def build_payong():
    """Umbrella (payong), canopy open overhead. The grip is the origin; the shaft rises about 1 m to the
    canopy, so a hand at chest height puts the canopy above the head."""
    fresh()
    cloth, shaft, tip = mat("PayongCloth", hexc("#B22A4E"), 0.8), mat("PayongShaft", hexc("#2B2B2D"), 0.4), mat("PayongTip", hexc("#C8C8C8"), 0.3)
    objs = [prim("cyl", "Shaft", (0, 0, 0.45), (0.018, 0.018, 1.0), shaft, seg=8, smooth=True),
            prim("sphere", "Canopy", (0, 0, 0.95), (1.1, 1.1, 0.5), cloth, seg=20, smooth=True),
            prim("sphere", "Under", (0, 0, 0.94), (1.04, 1.04, 0.42), mat("PayongUnder", hexc("#7A1A36"), 0.9), seg=20, smooth=True),
            prim("cyl", "Tip", (0, 0, 1.19), (0.02, 0.02, 0.07), tip, seg=8)]
    # the spheres are full ellipsoids: flatten everything below the rim plane (z = 0.95) so each is a dome
    for o in objs[1:3]:
        for v in o.data.vertices:
            if v.co.z < 0.95:
                v.co.z = 0.95 - (0.95 - v.co.z) * 0.15
    fin("payong", "Payong", objs, ground=False)


def build_water_gallon():
    """Blue 5-gallon refill bottle. Grip at the neck ring, the body hangs below it along -Z."""
    fresh()
    water = mat("GallonPlastic", hexc("#6FB6E8"), 0.2, alpha=0.7)
    cap = mat("GallonCap", hexc("#2F6FB8"), 0.5)
    objs = [prim("cyl", "Body", (0, 0, -0.27), (0.27, 0.27, 0.36), water, seg=18, smooth=True),
            prim("cone", "Shoulder", (0, 0, -0.07), (0.27, 0.27, 0.1), water, seg=18, smooth=True),
            prim("cyl", "Neck", (0, 0, -0.01), (0.1, 0.1, 0.06), water, seg=14, smooth=True),
            prim("cyl", "Cap", (0, 0, 0.03), (0.1, 0.1, 0.03), cap, seg=14),
            prim("cyl", "Water", (0, 0, -0.3), (0.245, 0.245, 0.28), mat("GallonWater", hexc("#4F9FD8"), 0.3), seg=18, smooth=True)]
    fin("water_gallon", "WaterGallon", objs, ground=False)


def build_backpack():
    """School backpack. Origin on the back panel's outer face, so it sits against the wearer's back; the
    straps are on the -Y (front) side, the bag body behind it on +Y."""
    fresh()
    body, pocket, strap = mat("PackBody", hexc("#2A56A5"), 0.7), mat("PackPocket", hexc("#E08A1E"), 0.7), mat("PackStrap", hexc("#1B2F5C"), 0.8)
    objs = [prim("cube", "Body", (0, 0.09, 0.0), (0.3, 0.17, 0.38), body, smooth=False),
            prim("cube", "Pocket", (0, 0.19, -0.07), (0.24, 0.05, 0.16), pocket),
            prim("cube", "Top", (0, 0.09, 0.2), (0.28, 0.15, 0.03), strap)]
    for sx in (-0.09, 0.09):
        objs.append(prim("cube", "Strap", (sx, -0.005, 0.02), (0.045, 0.015, 0.34), strap))
    fin("backpack", "Backpack", objs, ground=False, centre=False)


PROCEDURAL = {
    "wire_span": build_wire_span,
    "sign_sari_sari": lambda: build_sign("sign_sari_sari", "SignSariSari", "SARI-SARI STORE", 2.6, 0.7,
                                         "#E8C13A", "#B4252A", 0.34, "#7A2A1C"),
    "sign_tindahan": lambda: build_sign("sign_tindahan", "SignTindahan", "Tindahan ni Aling Charing", 1.9, 0.5,
                                        "#F2EAD3", "#2A5CA8", 0.17, "#2A5CA8"),
    "sidewalk": build_sidewalk,
    "store_base": build_store_base,
    "paper_fan": build_paper_fan,
    "payong": build_payong,
    "water_gallon": build_water_gallon,
    "backpack": build_backpack,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv or (list(MESHY) + list(PROCEDURAL))
    for n in names:
        if n in MESHY:
            build_meshy(n)
        elif n in PROCEDURAL:
            PROCEDURAL[n]()
        else:
            raise SystemExit(f"unknown prop {n!r}; have {list(MESHY) + list(PROCEDURAL)}")


main()

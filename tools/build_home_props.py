"""
build_home_props.py - the set dressing for the Home diorama (2026-10-17).

Two kinds of prop come out of this script, all into assets/props/home/:

  MESHY set pieces (source_art/props/home/<name>.glb, one textured ~1 m mesh each, 40-50 MB):
      store, facade_teal, facade_pink, fruit_stall, mango_tree, coconut_palm
      Decimated to a tri budget, the 2K base colour kept (or halved), scaled so the WIDTH matches
      FIT, centred on X/Y and grounded. The front stays on +Z (Godot) like Meshy exports it.

  PROCEDURAL props (no source files, no credits): bench, stool, bottle_crate, power_pole,
      sign boards, sidewalk strip, and the little things people hold - soda bottle, palamig bag,
      paper fan, payong, water gallon, backpack. Built from primitives with flat painted
      colours so the project toon shader reads them like the rest of the set.

Every prop is written as <name>.glb plus a <name>.tscn that instances it (the diorama instances the
.tscn, so a rebuilt GLB never touches scene edits). Hand-held props are authored with their GRIP at the
origin: the diorama parents them to a BoneAttachment3D on the hand and the grip lands in the palm.

Run:    & $env:BLENDER -b --python tools/build_home_props.py                (everything)
        & $env:BLENDER -b --python tools/build_home_props.py -- store bench (some)
Then:   & $env:BLENDER -b --python tools/qc_asset.py -- assets/props/home/<name>.glb --height 0 --max-tris 40000
"""
import bpy, os, sys, math
from mathutils import Vector, Matrix, Euler

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
SRC = os.path.join(PROJ, "source_art", "props", "home")
OUT = os.path.join(PROJ, "assets", "props", "home")

# ---- Meshy set pieces -----------------------------------------------------------------------------
# name: (node name, target width in m along X, tri budget, texture px)
MESHY = {
    "store": ("SariSariStore", 5.2, 60000, 2048),
    "facade_teal": ("FacadeTeal", 5.0, 30000, 1024),
    "facade_pink": ("FacadePink", 6.0, 30000, 1024),
    "fruit_stall": ("FruitStall", 2.6, 25000, 1024),
    "mango_tree": ("MangoTree", 6.0, 40000, 1024),
    "coconut_palm": ("CoconutPalm", 4.5, 30000, 1024),
    "graffiti_wall": ("GraffitiWall", 3.6, 30000, 1024),
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


def write_tscn(name, node):
    with open(os.path.join(OUT, name + ".tscn"), "w", newline="\n") as f:
        f.write('[gd_scene load_steps=2 format=3]\n\n')
        f.write(f'[ext_resource type="PackedScene" path="res://assets/props/home/{name}.glb" id="1_{name}"]\n\n')
        f.write(f'[node name="{node}" instance=ExtResource("1_{name}")]\n')


def export(name, node, objs):
    os.makedirs(OUT, exist_ok=True)
    glb = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_materials="EXPORT",
                              export_image_format="AUTO", export_yup=True, export_apply=True)
    write_tscn(name, node)
    lo, hi = bounds(objs)
    sz = hi - lo
    log(f"{name}: {sz.x:.2f} x {sz.y:.2f} x {sz.z:.2f} m (W x D x H)  {tris(objs)} tris  -> {os.path.relpath(glb, PROJ)}")


def build_meshy(name):
    node, width, budget, tex = MESHY[name]
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
    s = width / (hi.x - lo.x)
    shift = Vector((-(lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5, -lo.z))
    for o in meshes:
        o.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(shift))
        o.data.update()
        o.name = node if len(meshes) == 1 else f"{node}_{o.name}"
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


def build_stool(name, height):
    """Low plastic monobloc-style stool, the kind every sari-sari store has. height = seat top (m)."""
    fresh()
    seat = mat("StoolPlastic", hexc("#2E6FB5"), 0.5)
    r = 0.17
    objs = [prim("cyl", "Seat", (0, 0, height - 0.02), (r * 2, r * 2, 0.04), seat, seg=24, smooth=True)]
    for i in range(4):
        a = math.radians(45 + 90 * i)
        objs.append(prim("cyl", f"Leg{i}", (math.cos(a) * 0.115, math.sin(a) * 0.115, (height - 0.04) / 2),
                         (0.045, 0.045, height - 0.04), seat, seg=10, smooth=True))
    fin(name, "Stool", objs)


def build_bench():
    """Plank bench with a back rest, 1.7 m long, seat top 0.45 m. Sitters face -Y (Godot +Z)."""
    fresh()
    w, d = mat("BenchWood", WOOD, 0.9), mat("BenchDark", WOOD_DK, 0.9)
    objs = []
    for i in range(3):   # seat planks
        objs.append(prim("cube", f"Seat{i}", (0, -0.12 + i * 0.12, 0.43), (1.7, 0.11, 0.04), w))
    for i in range(3):   # back rest planks
        objs.append(prim("cube", f"Back{i}", (0, 0.2, 0.62 + i * 0.12), (1.7, 0.035, 0.1), w))
    for sx in (-0.75, 0.75):
        objs.append(prim("cube", f"Leg{sx}", (sx, 0.0, 0.205), (0.07, 0.4, 0.41), d))
        objs.append(prim("cube", f"BackPost{sx}", (sx, 0.2, 0.6), (0.07, 0.07, 0.4), d))
    fin("bench", "Bench", objs)


def build_bottle_crate():
    """Red plastic bottle crate with a dozen brown glass bottles; works as a side table (0.34 m tall)."""
    fresh()
    red, glass, cap = mat("Crate", PLASTIC_RED, 0.6), mat("BottleGlass", hexc("#6A3A1C"), 0.25), mat("Cap", hexc("#C8C8C8"), 0.4)
    objs = [prim("cube", "Floor", (0, 0, 0.015), (0.42, 0.32, 0.03), red)]
    for sx, sy, w, d in ((0, -0.155, 0.42, 0.02), (0, 0.155, 0.42, 0.02), (-0.2, 0, 0.02, 0.32), (0.2, 0, 0.02, 0.32)):
        objs.append(prim("cube", "Wall", (sx, sy, 0.13), (w, d, 0.2), red))
    for ix in range(4):
        for iy in range(3):
            x, y = -0.15 + ix * 0.1, -0.1 + iy * 0.1
            objs.append(prim("cyl", "Bottle", (x, y, 0.2), (0.058, 0.058, 0.24), glass, seg=10, smooth=True))
            objs.append(prim("cyl", "Cap", (x, y, 0.325), (0.04, 0.04, 0.012), cap, seg=10))
    fin("bottle_crate", "BottleCrate", objs)


def build_power_pole():
    """Wooden utility pole, 7 m, two crossarms with insulators. The wires are a separate prop (wire_span)."""
    fresh()
    w, d, g = mat("PoleWood", hexc("#6B4A2E"), 0.95), mat("Crossarm", WOOD_DK, 0.9), mat("Insulator", hexc("#8FB8B0"), 0.3)
    objs = [prim("cyl", "Pole", (0, 0, 3.5), (0.24, 0.24, 7.0), w, seg=12, smooth=True)]
    for z, ln in ((6.6, 1.8), (5.9, 1.4)):
        objs.append(prim("cube", "Arm", (0, 0, z), (0.1, ln, 0.1), d))     # across the road: wires run along X
        for sy in (-ln * 0.4, 0.0, ln * 0.4):
            objs.append(prim("cyl", "Insulator", (0, sy, z + 0.12), (0.07, 0.07, 0.14), g, seg=8, smooth=True))
    objs.append(prim("cyl", "Transformer", (0.28, 0, 5.1), (0.42, 0.42, 0.7), mat("Transformer", METAL, 0.5), seg=14, smooth=True))
    fin("power_pole", "PowerPole", objs)


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
def build_soda_bottle():
    fresh()
    glass, label, cap = mat("SodaGlass", hexc("#2E7A3F"), 0.2), mat("SodaLabel", hexc("#E8D26B"), 0.6), mat("SodaCap", hexc("#C8C8C8"), 0.4)
    objs = [prim("cyl", "Body", (0, 0, 0.0), (0.056, 0.056, 0.13), glass, seg=14, smooth=True),
            prim("cone", "Shoulder", (0, 0, 0.088), (0.056, 0.056, 0.05), glass, seg=14, smooth=True),
            prim("cyl", "Neck", (0, 0, 0.12), (0.024, 0.024, 0.05), glass, seg=12, smooth=True),
            prim("cyl", "Cap", (0, 0, 0.148), (0.03, 0.03, 0.01), cap, seg=12),
            prim("cyl", "Label", (0, 0, 0.0), (0.0585, 0.0585, 0.05), label, seg=14, smooth=True)]
    fin("soda_bottle", "SodaBottle", objs, ground=False)   # grip = the bottle's belly, at the origin


def build_palamig_bag():
    fresh()
    bag = mat("PalamigBag", hexc("#EFEFEF"), 0.3, alpha=0.45)
    juice = mat("Palamig", hexc("#F08A24"), 0.4)
    straw = mat("Straw", hexc("#D93A3A"), 0.5)
    objs = [prim("cone", "Juice", (0, 0, -0.02), (0.1, 0.1, 0.16), juice, seg=14, smooth=True, rot=(math.pi, 0, 0)),
            prim("cone", "Bag", (0, 0, 0.0), (0.115, 0.115, 0.2), bag, seg=14, smooth=True, rot=(math.pi, 0, 0)),
            prim("cyl", "Knot", (0, 0, 0.115), (0.025, 0.025, 0.03), bag, seg=8, smooth=True),
            prim("cyl", "Straw", (0.012, 0, 0.1), (0.01, 0.01, 0.24), straw, seg=6, rot=(0, math.radians(8), 0))]
    fin("palamig_bag", "PalamigBag", objs, ground=False)


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
    "stool_18": lambda: build_stool("stool_18", 0.18),
    "stool_19": lambda: build_stool("stool_19", 0.19),
    "stool_24": lambda: build_stool("stool_24", 0.24),
    "bench": build_bench,
    "bottle_crate": build_bottle_crate,
    "power_pole": build_power_pole,
    "wire_span": build_wire_span,
    "sign_sari_sari": lambda: build_sign("sign_sari_sari", "SignSariSari", "SARI-SARI STORE", 2.6, 0.7,
                                         "#E8C13A", "#B4252A", 0.34, "#7A2A1C"),
    "sign_tindahan": lambda: build_sign("sign_tindahan", "SignTindahan", "Tindahan ni Aling Charing", 1.9, 0.5,
                                        "#F2EAD3", "#2A5CA8", 0.17, "#2A5CA8"),
    "sidewalk": build_sidewalk,
    "soda_bottle": build_soda_bottle,
    "palamig_bag": build_palamig_bag,
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

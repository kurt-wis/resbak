"""
build_face_cards.py - procedural face cards for the Home diorama (talking mouths and blinking lids).

The hero meshes have no face rig and their mouths are painted shut. Instead of rigging, each hero
gets three thin cards laid on the head: a mouth card and two eyelid cards. The cards are curved
meshes (a grid ray-cast onto the head surface, lifted 1.5 mm, with the head's own smoothed
normals), so the toon lighting on a card matches the face under it and no flat-quad edge shows.
A shader (shaders/face_flipbook.gdshader) picks the frame of an atlas.

Input : assets/characters/<hero>.glb (rest pose), per-hero feature positions in the FEATURES table
        (pixel positions read off the rest-pose head close-up, 0.30 m across 720 px, see below)
Output: assets/characters/face_cards/<hero>_mouth.png   3x2 atlas: closed, small-open, wide-open, O, smile, laugh
        assets/characters/face_cards/<hero>_lids.png    3x1 atlas: open, half, closed
        assets/characters/face_cards/<hero>_cards.glb   meshes Mouth, Eye_R, Eye_L in the hero's model space
        assets/characters/face_cards/face_cards.json    sizes, centres, sampled skin tints (for tests and QC)

Frame 0 of both atlases is fully transparent, so the painted face shows at rest. The other frames
paint a feathered skin-coloured patch (tint sampled from that hero's own texture around the
feature) and then the shape on top, which hides the painted mouth or eye.

Run:  & $env:BLENDER -b --python tools/build_face_cards.py            (all five heroes)
      & $env:BLENDER -b --python tools/build_face_cards.py -- nene    (one hero)
Then judge the result in Godot (the Home diorama's face QC sheets), not here.
"""
import bpy, os, sys, json, math
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHAR_DIR = os.path.join(PROJ, "assets", "characters")
OUT_DIR = os.path.join(CHAR_DIR, "face_cards")

# Rest-pose head close-ups (front, orthographic, 0.30 m across 720 px) were used to read the feature
# positions: px/py are pixels from the top-left of that image, ref is the world (x, z) of its centre.
PX_M = 0.30 / 720.0
# mouth = (px, py, width px); eyes = (px, py, width px, height px, tilt deg) for the viewer's left then right.
FEATURES = {
    "tutoy":  {"ref": (0.0, 1.29), "mouth": (365, 543, 310),
               "eyes": [(158, 340, 205, 135, -8), (556, 338, 200, 130, 8)]},
    "nene":   {"ref": (0.0, 1.28), "mouth": (357, 507, 325),
               "eyes": [(115, 250, 250, 190, -8), (610, 255, 250, 185, 8)]},
    "nathan": {"ref": (0.0, 1.34), "mouth": (362, 555, 385),
               "eyes": [(145, 310, 225, 165, -8), (577, 312, 230, 160, 8)]},
    "jm":     {"ref": (0.0, 1.42), "mouth": (360, 487, 260),
               "eyes": [(155, 292, 205, 140, -10), (560, 292, 205, 140, 10)]},
    "inday":  {"ref": (0.0, 1.41), "mouth": (360, 460, 250),
               "eyes": [(190, 240, 185, 130, -8), (535, 240, 190, 130, 8)]},
}

MOUTH_CARD_W = 1.5   # card width = this x the painted mouth width
MOUTH_ASPECT = 0.55  # card height / width
EYE_W, EYE_H = 1.2, 1.3   # card size = this x the painted eye size
SURFACE_LIFT = 0.0015     # m along the surface normal
MOUTH_CELL = (320, 176)   # atlas cell px, 3 x 2
LID_CELL_W = 256          # lid atlas cell width px, 3 x 1 (height follows the card aspect)
GRID_MOUTH = (22, 10)
GRID_EYE = (16, 12)

OUTLINE = np.array([0.20, 0.09, 0.08])
INNER = np.array([0.40, 0.10, 0.14])
TONGUE = np.array([0.86, 0.38, 0.46])
TEETH = np.array([0.97, 0.95, 0.90])
LASH = np.array([0.13, 0.07, 0.06])


# ---------------------------------------------------------------------------------------------
# Blender helpers
# ---------------------------------------------------------------------------------------------
class Skin:
    """The hero's skinned meshes in rest pose: ray-cast a point on the face, get position, smoothed
    normal and the texture colour there."""

    def __init__(self, hero):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(CHAR_DIR, f"{hero}.glb"))
        self.arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        self.arm.data.pose_position = "REST"
        self.arm.animation_data_clear()
        bpy.context.scene.frame_set(0)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        self.meshes = []
        for o in bpy.data.objects:
            if o.type != "MESH" or o.find_armature() is None:   # skip the importer's bone-shape Icosphere
                continue
            bvh = BVHTree.FromObject(o, dg)
            self.meshes.append((o, bvh, o.matrix_world.copy(), o.matrix_world.inverted()))
        self.images = {}
        head = self.arm.data.bones["mixamorig:Head"]
        self.head = (self.arm.matrix_world @ head.head_local, self.arm.matrix_world @ head.tail_local)

    def _tri_poly(self, obj):
        key = ("tp", obj.name)
        if key not in self.images:
            n = len(obj.data.loop_triangles)
            arr = np.empty(n, dtype=np.int32)
            obj.data.loop_triangle_polygons.foreach_get("value", arr)
            self.images[key] = arr
        return self.images[key]

    def _image(self, obj, poly):
        if not obj.data.materials:
            return None
        mat = obj.data.materials[min(poly.material_index, len(obj.data.materials) - 1)]
        if mat is None or not mat.use_nodes:
            return None
        node = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None)
        if node is None:
            return None
        img = node.image
        if img.name not in self.images:
            img.colorspace_settings.name = "Non-Color"   # raw sRGB values, what the PNG and the shader see
            w, h = img.size
            arr = np.empty(w * h * 4, dtype=np.float32)
            img.pixels.foreach_get(arr)
            self.images[img.name] = arr.reshape(h, w, 4)
        return self.images[img.name]

    def cast(self, x, z):
        """Nearest front-facing surface under (x, z) from -Y. Returns (pos, normal, rgb) or None."""
        best = None
        for obj, bvh, mw, mwi in self.meshes:
            o = mwi @ Vector((x, -1.5, z))
            d = (mwi.to_3x3() @ Vector((0, 1, 0))).normalized()
            hit = bvh.ray_cast(o, d)
            if hit[0] is None:
                continue
            world = mw @ hit[0]
            if best is None or world.y < best[0].y:
                best = (world, obj, hit[0], hit[2])
        if best is None:
            return None
        world, obj, local, idx = best
        me = obj.data
        tp = self._tri_poly(obj)
        poly = me.polygons[idx] if idx < len(me.polygons) else None
        tris = list(np.nonzero(tp == idx)[0]) if poly is not None else []
        if not tris:   # index was a triangle index
            tris = [idx]
            poly = me.polygons[int(tp[idx])]
        bw, bt = -9.0, None
        for t in tris:
            tri = me.loop_triangles[t]
            vs = [me.vertices[v].co for v in tri.vertices]
            w = poly_3d_calc(vs, local)
            if min(w) > bw:
                bw, bt = min(w), (tri, w)
        tri, w = bt
        uvl = me.uv_layers.active.data
        uv = sum((Vector(uvl[l].uv) * w[i] for i, l in enumerate(tri.loops)), Vector((0, 0)))
        nrm = sum((Vector(me.corner_normals[l].vector) * w[i] for i, l in enumerate(tri.loops)),
                  Vector((0, 0, 0)))
        nrm = (obj.matrix_world.to_3x3() @ nrm).normalized()
        img = self._image(obj, poly)
        rgb = None
        if img is not None:
            h, wd = img.shape[:2]
            px = int(np.clip(uv.x % 1.0 * (wd - 1), 0, wd - 1))
            py = int(np.clip(uv.y % 1.0 * (h - 1), 0, h - 1))
            rgb = img[py, px, :3].copy()
        return world, nrm, rgb


def feature_xz(hero, px, py):
    rx, rz = FEATURES[hero]["ref"]
    return rx + (px - 360) * PX_M, rz - (py - 360) * PX_M


def sample_skin(skin, cx, cz, ra, rb, lower_only=False):
    """Median skin colour on a ring just outside an ellipse (ra, rb) around (cx, cz); dark outlines,
    whites and teeth are rejected."""
    pts = []
    for k in range(36):
        a = 2 * math.pi * k / 36
        if lower_only and math.sin(a) > 0.35:
            continue
        hit = skin.cast(cx + math.cos(a) * ra, cz + math.sin(a) * rb)
        if hit is None or hit[2] is None:
            continue
        c = hit[2]
        luma = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
        if 0.28 < luma < 0.88 and (c.max() - c.min()) > 0.06:
            pts.append(c)
    if len(pts) < 6:
        raise RuntimeError(f"skin sample failed around {cx:.3f},{cz:.3f} ({len(pts)} points)")
    return np.median(np.array(pts), axis=0)


def project_grid(skin, cx, cz, w, h, tilt_deg, nu, nv, lift=SURFACE_LIFT):
    """A (nu+1) x (nv+1) grid of w x h metres centred on (cx, cz), rotated tilt_deg in the face
    plane, laid onto the surface. Returns positions, normals, uvs and quad faces."""
    t = math.radians(tilt_deg)
    ct, st = math.cos(t), math.sin(t)
    pos, nrm, uvs = [], [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            u, v = i / nu, j / nv
            a, b = (u - 0.5) * w, (v - 0.5) * h
            hit = None
            for s in (1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2):
                # corners past the jaw line miss the head: slide them inward (their alpha is 0 anyway)
                x, z = cx + (a * ct - b * st) * s, cz + (a * st + b * ct) * s
                hit = skin.cast(x, z)
                if hit is not None:
                    break
            if hit is None:
                raise RuntimeError(f"ray missed the head at {x:.3f},{z:.3f}")
            p, n, _ = hit
            pos.append(p + n * lift)
            nrm.append(n)
            uvs.append((u, v))
    faces = []
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            faces.append((a, a + 1, a + nu + 2, a + nu + 1))
    ys = [p.y for p in pos]
    if max(ys) - min(ys) > 0.14:   # the heads are big and round: 0.08-0.12 m across a mouth card is normal
        print(f"  WARN card depth spread {max(ys) - min(ys):.3f} m (hair in the ray's way?)")
    return pos, nrm, uvs, faces


# ---------------------------------------------------------------------------------------------
# Drawing (numpy, signed distances, 1 px antialias)
# ---------------------------------------------------------------------------------------------
def cell_grid(wpx, hpx, wu, hu):
    xs = (np.arange(wpx) + 0.5) / wpx * wu - wu / 2
    ys = hu / 2 - (np.arange(hpx) + 0.5) / hpx * hu
    X, Y = np.meshgrid(xs, ys)
    return X, Y, wu / wpx


def cov(d, px):
    return np.clip(0.5 - d / px, 0.0, 1.0)


def ell_k(X, Y, cx, cy, a, b):
    return np.sqrt(((X - cx) / a) ** 2 + ((Y - cy) / b) ** 2)


def ell_d(X, Y, cx, cy, a, b):
    return (ell_k(X, Y, cx, cy, a, b) - 1.0) * min(a, b)


def feather(k, f):
    m = np.clip((1.0 - k) / f, 0.0, 1.0)
    return m * m * (3 - 2 * m)


def arc_d(X, Y, fn, x0, x1, th):
    e = 1e-3
    s = (fn(X + e) - fn(X - e)) / (2 * e)
    xe = np.clip(X, x0, x1)
    inside = (X >= x0) & (X <= x1)
    d_in = np.abs(Y - fn(X)) / np.sqrt(1 + s * s)
    d_out = np.hypot(X - xe, Y - fn(xe))
    return np.where(inside, d_in, d_out) - th / 2


def over(dst, rgb, a):
    a = a[..., None] if a.ndim == 2 else a
    da = dst[..., 3:4]
    oa = a + da * (1 - a)
    orgb = (np.asarray(rgb) * a + dst[..., :3] * da * (1 - a)) / np.maximum(oa, 1e-5)
    dst[..., :3] = orgb
    dst[..., 3:4] = oa


def blank(wpx, hpx, skin):
    out = np.zeros((hpx, wpx, 4), dtype=np.float32)
    out[..., :3] = skin
    return out


def mouth_frame(i, skin):
    wpx, hpx = MOUTH_CELL
    X, Y, px = cell_grid(wpx, hpx, 1.0, MOUTH_ASPECT)
    out = blank(wpx, hpx, skin)
    if i == 0:
        return out
    patch = feather(ell_k(X, Y, 0, 0, 0.47, 0.26), 0.2)
    over(out, skin, patch)
    th = 0.026
    if i == 1:    # small open
        o = cov(ell_d(X, Y, 0, 0, 0.15 + th, 0.075 + th), px)
        n = cov(ell_d(X, Y, 0, 0, 0.15, 0.075), px)
        over(out, OUTLINE, o)
        over(out, INNER, n)
    elif i == 2:  # wide open
        o = cov(ell_d(X, Y, 0, 0, 0.20 + th, 0.13 + th), px)
        n = cov(ell_d(X, Y, 0, 0, 0.20, 0.13), px)
        over(out, OUTLINE, o)
        over(out, INNER, n)
        tongue = cov(ell_d(X, Y, 0, -0.085, 0.13, 0.055), px) * n
        over(out, TONGUE, tongue)
    elif i == 3:  # O
        o = cov(ell_d(X, Y, 0, 0, 0.085 + th, 0.115 + th), px)
        n = cov(ell_d(X, Y, 0, 0, 0.085, 0.115), px)
        over(out, OUTLINE, o)
        over(out, INNER, n)
        over(out, TONGUE, cov(ell_d(X, Y, 0, -0.055, 0.05, 0.03), px) * n)
    elif i == 4:  # smile: a U shaped lip line with little corner ticks
        fn = lambda x: -0.07 + 0.10 * (x / 0.27) ** 2
        over(out, OUTLINE, cov(arc_d(X, Y, fn, -0.27, 0.27, 0.03), px))
    elif i == 5:  # laugh: a D, flat top, teeth strip, tongue
        a, b, cy = 0.30, 0.19, 0.04
        below = np.clip(0.5 - (Y - cy) / px, 0, 1)
        inner = cov(ell_d(X, Y, 0, cy, a, b), px) * below
        outer = np.clip(cov(ell_d(X, Y, 0, cy, a + th, b + th), px) *
                        np.clip(0.5 - (Y - cy - th) / px, 0, 1), 0, 1)
        over(out, OUTLINE, outer)
        over(out, INNER, inner)
        over(out, TONGUE, cov(ell_d(X, Y, 0, -0.115, 0.14, 0.06), px) * inner)
        teeth = np.clip(0.5 - (cy - 0.055 - Y) / px * -1, 0, 1)  # y above cy-0.055
        teeth = np.clip(0.5 + (Y - (cy - 0.055)) / px, 0, 1) * inner
        over(out, TEETH, teeth)
    return out


def lid_frame(i, skin, asp):
    wpx = LID_CELL_W
    hpx = max(8, int(round(wpx * asp)))
    X, Y, px = cell_grid(wpx, hpx, 1.0, asp)
    Y = Y / asp   # isotropic design space: x in +-0.5, y in +-0.5
    out = blank(wpx, hpx, skin)
    if i == 0:
        return out, hpx
    mask = feather(ell_k(X, Y, 0, 0, 0.47, 0.46), 0.18)
    th = 0.05
    if i == 1:   # half closed
        fn = lambda x: 0.08 - 0.16 * (1 - (x / 0.45) ** 2)
        above = np.clip(0.5 + (Y - fn(X)) / px, 0, 1)
        over(out, skin, mask * above)
        line = cov(arc_d(X, Y, fn, -0.43, 0.43, th), px) * mask
        over(out, LASH, line)
    else:        # closed
        over(out, skin, mask)
        fn = lambda x: 0.02 - 0.16 * (1 - (x / 0.42) ** 2)
        over(out, LASH, cov(arc_d(X, Y, fn, -0.40, 0.40, th), px))
    return out, hpx


def save_png(path, arr):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "STRAIGHT"
    img.pixels = np.flipud(arr).ravel().tolist()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def atlas(frames, cols):
    rows = (len(frames) + cols - 1) // cols
    h, w = frames[0].shape[:2]
    out = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    for k, f in enumerate(frames):
        r, c = divmod(k, cols)
        out[r * h:(r + 1) * h, c * w:(c + 1) * w] = f
    return out


def export_cards(hero, cards):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, (pos, nrm, uvs, faces) in cards.items():
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p) for p in pos], [], faces)
        uv = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for l in poly.loop_indices:
                uv.data[l].uv = uvs[me.loops[l].vertex_index]
        me.normals_split_custom_set_from_vertices([tuple(n) for n in nrm])
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
    path = os.path.join(OUT_DIR, f"{hero}_cards.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True,
                              export_materials="NONE", export_apply=False)


def build(hero):
    f = FEATURES[hero]
    skin = Skin(hero)
    info = {"head_bone": {"head": list(skin.head[0]), "tail": list(skin.head[1])}, "cards": {}}
    cards = {}
    # --- mouth
    mx, my, mw_px = f["mouth"]
    cx, cz = feature_xz(hero, mx, my)
    mw = mw_px * PX_M
    W = mw * MOUTH_CARD_W
    H = W * MOUTH_ASPECT
    tint_m = sample_skin(skin, cx, cz, W * 0.47 * 1.15, H * 0.5 * 1.1)
    # Transparent feather margins overlap on the replacement JM's round cheeks.
    # Separate the mouth layer so their geometry cannot fight at oblique angles.
    mouth_lift = SURFACE_LIFT + (.003 if hero == 'jm' else 0)
    cards["Mouth"] = project_grid(skin, cx, cz, W, H, 0.0, *GRID_MOUTH, lift=mouth_lift)
    info["cards"]["Mouth"] = {"centre": [cx, cz], "size": [W, H], "tint": [float(x) for x in tint_m]}
    mouth_atlas = atlas([mouth_frame(i, tint_m) for i in range(6)], 3)
    # --- eyes (viewer's left first = the hero's right eye)
    lid_frames = {0: [], 1: [], 2: []}
    lid_atlas = None
    asps = []
    for name, (ex, ey, ew_px, eh_px, tilt) in zip(("Eye_R", "Eye_L"), f["eyes"]):
        cx, cz = feature_xz(hero, ex, ey)
        ew, eh = ew_px * PX_M, eh_px * PX_M
        W, H = ew * EYE_W, eh * EYE_H
        tint = sample_skin(skin, cx, cz, ew * 0.60, eh * 0.62, lower_only=True)
        cards[name] = project_grid(skin, cx, cz, W, H, tilt, *GRID_EYE)
        info["cards"][name] = {"centre": [cx, cz], "size": [W, H], "tilt": tilt,
                               "tint": [float(x) for x in tint]}
        asps.append((H / W, tint))
    # both lids share one atlas: average aspect and tint
    asp = sum(a for a, _ in asps) / 2
    tint_e = (asps[0][1] + asps[1][1]) / 2
    frames = []
    hpx = 0
    for i in range(3):
        fr, hpx = lid_frame(i, tint_e, asp)
        frames.append(fr)
    lid_atlas = atlas(frames, 3)
    info["lid_aspect"] = asp
    save_png(os.path.join(OUT_DIR, f"{hero}_mouth.png"), mouth_atlas)
    save_png(os.path.join(OUT_DIR, f"{hero}_lids.png"), lid_atlas)
    export_cards(hero, cards)
    print(f"FACE {hero}: mouth tint {np.round(tint_m, 3)}, lid tint {np.round(tint_e, 3)}, lid aspect {asp:.3f}",
          flush=True)
    return info


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    heroes = argv or list(FEATURES)
    os.makedirs(OUT_DIR, exist_ok=True)
    json_path = os.path.join(OUT_DIR, "face_cards.json")
    data = {}
    if os.path.exists(json_path):
        with open(json_path) as fh:
            data = json.load(fh)
    for h in heroes:
        data[h] = build(h)
    with open(json_path, "w") as fh:
        json.dump(data, fh, indent=1)


main()

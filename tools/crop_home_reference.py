"""
crop_home_reference.py - per-prop crops of the Home reference image (2026-10-18).

The Home diorama is rebuilt from the concept art in source_art/reference/home_target.webp. Meshy's
image-to-3D wants ONE object per image, roughly centred, on a plain background, so this script cuts
the reference into one crop per prop and pads each to a square on white (2 % margin) before Meshy
sees it. The crops are sources, not game art: they live under source_art/ (Godot-ignored) and are
never imported by the engine.

Boxes are pixels of the 1376 x 768 reference; they are scaled if the file is a different size, so a
re-export at higher resolution keeps the same framing.

`MASKS` patches out what must NOT reach Meshy as geometry: in the reference the three seated kids
sit in front of the stall and the crate stack overlaps its right corner, so those areas are filled
by blending between the box's own edges (see `blend_box`). Without that, the store model comes back
with three children welded to its counter. The fill is a smooth smear on purpose - it reads to the
generator as plain wall or shadow, and the diorama's own cast sits in front of that area anyway.

Run:  python tools/crop_home_reference.py              (all crops)
      python tools/crop_home_reference.py -- store    (some)
Out:  source_art/reference/home_crops/<name>.png
"""
import os
import sys

from PIL import Image, ImageFilter

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
REF = os.path.join(PROJ, "source_art", "reference", "home_target.webp")
OUT = os.path.join(PROJ, "source_art", "reference", "home_crops")
REF_SIZE = (1376, 768)  # the boxes below are written against this
MARGIN = 0.02           # white border added around the padded square
FEATHER = 4             # px of soft edge where a patch meets the untouched picture

# name: (x0, y0, x1, y1) in reference pixels, all read off the 1376 x 768 file. Keep every crop on
# the prop alone: no neighbours, no UI. Two caveats, both from the UI covering the left third of the
# reference: the reference's own left-hand house sits behind the PLAY card, so `house_left` is the
# wooden jalousie house beside the store instead - that is the one placed behind the left menu; and
# the vehicles parked at the left kerb are 74 % covered by the TUTORIAL / locked-tile / BACK TO TITLE
# stickers, which is why no tricycle crop is taken from there.
CROPS = {
    # The stall above the seated cast: roof tyres, sign board, awning, snack strips, grille window,
    # the ICE FOR SALE sign, the price-list papers. The box stops at y 402, the top of the three
    # heads, so only a strip of hair is masked - the kids' bodies below it are never cropped in.
    "store": (528, 32, 1150, 402),
    # The four parked vehicles at the right edge, seen small and side-on from the road. Reference
    # only: at 30 px per vehicle it is far too small to generate from (see the caveat below).
    "parked_vehicles": (1250, 375, 1376, 545),
    # Red + blue Coca-style plastic crate stack at the store's right corner. The box stops at x 1152,
    # left of Tutoy's arm, and at y 578, above the plank and gravel at its foot.
    "crate_stack": (1030, 336, 1168, 580),
    # The monobloc stool the cast sits on: the red one under Nene is mostly hidden by her dress, so
    # this one (the unoccupied blue stool beside her) is the model. Red is an albedo tint in Godot.
    "stool_red": (574, 516, 638, 596),
    "stool_blue": (692, 490, 740, 562),
    # Banana plant right of the store, in front of the wooden house. The box starts below the
    # PROFILE tile's ghost, which the UI leaves on the leaves above y 248.
    "banana": (1150, 244, 1270, 336),
    # Wooden house with slatted jalousie windows and a corrugated tin roof (see the caveat above).
    # Stops at x 1132, before the banana leaves that cross it.
    "house_left": (1036, 126, 1132, 306),
    # Utility pole with cross-arm, insulators and a transformer. Stops at x 618 and y 196 so the
    # store's sign, roof tyre and brick at its foot stay out.
    "pole": (534, 0, 618, 196),
}

# name: [(mode, x0, y0, x1, y1), ...] in reference pixels. "h" blends between the columns just
# outside the box (use it where the surroundings continue sideways: a figure in front of a wall);
# "v" blends between the rows just outside it (use it for a band that must keep the column textures).
MASKS = {
    "store": [
        # Only the figures in front of the stall reach into the crop, and only their heads: it stops
        # at y 402. Each box is as narrow as its figure, so the sideways blend runs across the counter
        # just outside it - a smooth shadow, not a smear over half the stall.
        ("h", 526, 286, 584, 402),     # Inday, standing at the left edge of the frame
        ("h", 586, 352, 664, 402),     # Nene's hair and the pink bows
        ("h", 762, 348, 886, 402),     # Nathan, with the towel over his shoulder
        ("h", 900, 352, 1010, 402),    # JM
        ("h", 1016, 352, 1150, 402),   # the crate stack over the store's right corner
        ("h", 1062, 300, 1150, 352),   # ... and above it, right of the ICE sign
        ("h", 1128, 220, 1150, 300),   # the banana plant's leaves at the right edge
    ],
    "crate_stack": [
        ("h", 1030, 336, 1088, 428),   # the store's window frame behind the stack's top left
        ("h", 1086, 334, 1162, 370),   # the crates carry a Coca-style script: blend the legible
        ("h", 1078, 384, 1152, 414),   # ... marks out (crate faces are flat, so it is invisible)
        ("h", 1038, 546, 1106, 578),   # ... - the plan is crates with no soda branding
        ("h", 1140, 396, 1168, 512),   # Tutoy's arm in front of the stack's right column
    ],
    "banana": [
        ("h", 1150, 244, 1206, 292),   # the house's roof beam crossing the leaves at the top left
    ],
}


def crop_box(name, size):
    """The reference crop box scaled from REF_SIZE to the file's real size."""
    x0, y0, x1, y1 = CROPS[name]
    sx, sy = size[0] / REF_SIZE[0], size[1] / REF_SIZE[1]
    box = (round(x0 * sx), round(y0 * sy), round(x1 * sx), round(y1 * sy))
    return box


def blend_box(im, box, mode="h"):
    """Fill `box` by blending between the picture just outside its two opposite edges.

    The box is a thing we do not want in the model (a person, a sticker band). Blending sideways
    from the columns outside it continues a wall behind a figure; blending downwards from the rows
    outside it continues the column of texture through a horizontal band. Either way the result is a
    smooth guess, which the generator reads as plain surface instead of as a second subject.
    """
    x0, y0, x1, y1 = box
    w, h = im.size
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(w, x1), min(h, y1)
    if x1 <= x0 or y1 <= y0:
        return
    filled = im.copy()
    src, dst = im.load(), filled.load()
    if mode == "v":
        ty, by = max(0, y0 - 2), min(h - 1, y1 + 1)
        span = max(1, y1 - 1 - y0)
        for x in range(x0, x1):
            a, b = src[x, ty], src[x, by]
            for y in range(y0, y1):
                t = (y - y0) / span
                dst[x, y] = (round(a[0] + (b[0] - a[0]) * t),
                             round(a[1] + (b[1] - a[1]) * t),
                             round(a[2] + (b[2] - a[2]) * t))
    else:
        lx, rx = max(0, x0 - 2), min(w - 1, x1 + 1)
        span = max(1, x1 - 1 - x0)
        for y in range(y0, y1):
            a, b = src[lx, y], src[rx, y]
            for x in range(x0, x1):
                t = (x - x0) / span
                dst[x, y] = (round(a[0] + (b[0] - a[0]) * t),
                             round(a[1] + (b[1] - a[1]) * t),
                             round(a[2] + (b[2] - a[2]) * t))
    soft = Image.new("L", im.size, 0)
    soft.paste(255, (x0, y0, x1, y1))
    soft = soft.filter(ImageFilter.GaussianBlur(FEATHER))
    im.paste(filled, (0, 0), soft)


def patch(im, box, masks):
    """Apply the mask boxes (reference px, converted to crop-local px) to a crop in place."""
    (cx0, cy0, _cx1, _cy1) = box
    for mode, x0, y0, x1, y1 in masks:
        blend_box(im, (x0 - cx0, y0 - cy0, x1 - cx0, y1 - cy0), mode)


def pad_square(im, fill=(255, 255, 255)):
    """Centre the crop on a white square with a margin, so Meshy sees the prop whole and upright."""
    w, h = im.size
    side = max(w, h)
    side = int(round(side * (1.0 + 2.0 * MARGIN)))
    canvas = Image.new("RGB", (side, side), fill)
    canvas.paste(im, ((side - w) // 2, (side - h) // 2))
    return canvas


def main():
    argv = sys.argv[1:]
    if argv and argv[0] == "--":
        argv = argv[1:]
    names = argv or list(CROPS)
    if not os.path.exists(REF):
        raise SystemExit(f"missing {os.path.relpath(REF, PROJ)} - the Home reference is not on disk")
    ref = Image.open(REF).convert("RGB")
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        if name not in CROPS:
            raise SystemExit(f"unknown crop {name!r}; have {list(CROPS)}")
        box = crop_box(name, ref.size)
        im = ref.crop(box)
        masks = MASKS.get(name, [])
        if masks:
            patch(im, box, masks)
        im = pad_square(im)
        path = os.path.join(OUT, name + ".png")
        im.save(path)
        extra = f"  ({len(masks)} patched area{'' if len(masks) == 1 else 's'})" if masks else ""
        print(f"[home_crops] {name:16s} ref{box} -> {im.size[0]}x{im.size[1]}  {os.path.relpath(path, PROJ)}{extra}")


main()

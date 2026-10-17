"""Home diorama ground and backdrop textures (PIL + numpy only, deterministic).

Writes into assets/props/home/:
  ground_concrete.png   2048 px seamless tile (8 m): slab joints, cracks, stains, grit, bottle caps,
                        leaves and a chalk piko (hopscotch)
  ground_dirt.png       1024 px seamless tile (4 m): packed earth, pebbles, tyre ruts
  facade_a..e.png       512 px building fronts for the far street (stucco, windows, grilles, stains)

Run from the repo root:  python tools/make_home_ground.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join("assets", "props", "home")


def periodic_noise(size, cells, rng, octaves=4):
    """Seamless value noise in 0..1 (cosine interpolation on a wrapping lattice)."""
    out = np.zeros((size, size), dtype=np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = cells * (2 ** o)
        grid = rng.random((n, n)).astype(np.float32)
        xs = np.linspace(0, n, size, endpoint=False)
        i0 = np.floor(xs).astype(int) % n
        i1 = (i0 + 1) % n
        f = xs - np.floor(xs)
        f = (1 - np.cos(f * math.pi)) * 0.5
        row = grid[:, i0] * (1 - f)[None, :] + grid[:, i1] * f[None, :]
        col = row[i0, :] * (1 - f)[:, None] + row[i1, :] * f[:, None]
        out += col * amp
        total += amp
        amp *= 0.5
    return out / total


def wrap_draw(size, fn):
    """Calls fn(dx, dy) for the 3x3 neighbours so shapes crossing an edge wrap."""
    for dx in (-size, 0, size):
        for dy in (-size, 0, size):
            fn(dx, dy)


def shade(arr, rgb):
    return (np.array(rgb, dtype=np.float32)[None, None, :] * arr[:, :, None])


def ground_concrete():
    size = 2048
    rng = np.random.default_rng(7)
    r = random.Random(7)
    base = (184, 168, 146)
    low = periodic_noise(size, 3, rng, 5)
    mid = periodic_noise(size, 12, rng, 3)
    fine = rng.random((size, size)).astype(np.float32)
    lum = 0.80 + 0.30 * low + 0.12 * (mid - 0.5) + 0.07 * (fine - 0.5)
    img = shade(lum, base)
    # slab-to-slab tone difference (2 x 2 slabs of 4 m)
    for sx in range(2):
        for sy in range(2):
            t = 1.0 + (r.random() - 0.5) * 0.14
            img[sy * 1024:(sy + 1) * 1024, sx * 1024:(sx + 1) * 1024] *= t
    # warm/cool drift so it is not one colour
    drift = periodic_noise(size, 2, rng, 2)
    img[:, :, 0] *= 0.96 + 0.08 * drift
    img[:, :, 2] *= 1.06 - 0.12 * drift
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im, "RGBA")

    # expansion joints, with a soft lighter lip on one side
    for p in (0, 1024):
        d.rectangle([p - 5, 0, p + 5, size], fill=(58, 50, 42, 235))
        d.rectangle([p + 6, 0, p + 9, size], fill=(232, 218, 196, 70))
        d.rectangle([0, p - 5, size, p + 5], fill=(58, 50, 42, 235))
        d.rectangle([0, p + 6, size, p + 9], fill=(232, 218, 196, 70))
    # broken joint edges
    for _ in range(90):
        p = r.choice((0, 1024))
        a = r.randrange(size)
        w = r.randrange(6, 30)
        wrap_draw(size, lambda dx, dy, p=p, a=a, w=w: (
            d.rectangle([p - 9 + dx, a + dy, p + 9 + dx, a + w + dy], fill=(70, 60, 50, 180)),
            d.rectangle([a + dx, p - 9 + dy, a + w + dx, p + 9 + dy], fill=(70, 60, 50, 180))))

    # stains: damp, oil, soot
    for _ in range(46):
        x, y = r.randrange(size), r.randrange(size)
        rad = r.randrange(40, 190)
        col = r.choice([(70, 60, 50, 38), (40, 36, 34, 46), (120, 100, 78, 34), (90, 100, 80, 26)])
        wrap_draw(size, lambda dx, dy, x=x, y=y, rad=rad, col=col: d.ellipse(
            [x - rad + dx, y - rad * 0.7 + dy, x + rad + dx, y + rad * 0.7 + dy], fill=col))
    # hairline cracks (random walks that branch), wrapped
    def crack(x, y, ang, length, width):
        for i in range(length):
            ang += (r.random() - 0.5) * 0.55
            nx, ny = x + math.cos(ang) * 7, y + math.sin(ang) * 7
            wrap_draw(size, lambda dx, dy: d.line([x + dx, y + dy, nx + dx, ny + dy],
                                                  fill=(44, 38, 32, 210), width=width))
            if r.random() < 0.035 and width > 1:
                crack(nx, ny, ang + (r.random() - 0.5) * 1.6, length // 3, 1)
            x, y = nx, ny
    for _ in range(16):
        crack(r.randrange(size), r.randrange(size), r.random() * 6.28, r.randrange(30, 110), 2)
    # chalk piko (hopscotch) on slab (1,1): squares 1..10 up the court
    ox, oy = 1260, 1180
    cw = 118
    cells = [(0, 0), (0, 1), (-0.5, 2), (0.5, 2), (0, 3), (0, 4), (-0.5, 5), (0.5, 5), (0, 6), (0, 7)]
    for i, (cx, cy) in enumerate(cells):
        x0 = ox + cx * cw
        y0 = oy + 620 - (cy + 1) * cw
        d.rectangle([x0, y0, x0 + cw, y0 + cw], outline=(245, 240, 225, 150), width=7)
        d.text((x0 + cw * 0.36, y0 + cw * 0.28), str(i + 1), fill=(245, 240, 225, 130))
    d.ellipse([ox - 60, oy + 700, ox + 80, oy + 800], outline=(245, 240, 225, 120), width=6)
    # chalk scribbles
    for _ in range(10):
        x, y = r.randrange(size), r.randrange(size)
        pts = [(x + r.randrange(-90, 90), y + r.randrange(-90, 90)) for _ in range(5)]
        d.line(pts, fill=(235, 232, 220, 70), width=4)
    # tyre / slipper scuffs
    for _ in range(14):
        x, y = r.randrange(size), r.randrange(size)
        ang = r.random() * 6.28
        l = r.randrange(120, 360)
        wrap_draw(size, lambda dx, dy: d.line([x + dx, y + dy, x + math.cos(ang) * l + dx, y + math.sin(ang) * l + dy],
                                              fill=(40, 36, 32, 30), width=r.randrange(8, 20)))
    # bottle caps (tansan), leaves, litter
    caps = [(216, 60, 50), (240, 190, 50), (60, 120, 200), (110, 170, 80), (230, 110, 40)]
    for _ in range(34):
        x, y = r.randrange(size), r.randrange(size)
        col = r.choice(caps)
        rad = 11
        wrap_draw(size, lambda dx, dy: (
            d.ellipse([x - rad + dx, y - rad + dy, x + rad + dx, y + rad + dy], fill=col + (255,), outline=(60, 50, 40, 255), width=2),
            d.ellipse([x - 5 + dx, y - 5 + dy, x + 5 + dx, y + 5 + dy], outline=(255, 255, 255, 110), width=1)))
    for _ in range(80):
        x, y = r.randrange(size), r.randrange(size)
        col = r.choice([(96, 112, 52), (130, 120, 56), (150, 100, 52), (88, 96, 50)])
        w, h = r.randrange(14, 30), r.randrange(6, 12)
        wrap_draw(size, lambda dx, dy: d.ellipse([x + dx, y + dy, x + w + dx, y + h + dy], fill=col + (235,)))
    for _ in range(16):
        x, y = r.randrange(size), r.randrange(size)
        col = r.choice([(222, 214, 196), (200, 70, 60), (70, 120, 170), (226, 190, 70)])
        w = r.randrange(16, 34)
        wrap_draw(size, lambda dx, dy: d.polygon([(x + dx, y + dy), (x + w + dx, y + 6 + dy), (x + w - 6 + dx, y + w + dy), (x - 4 + dx, y + w - 8 + dy)], fill=col + (230,)))
    # grit
    arr = np.asarray(im).astype(np.float32)
    grit = (rng.random((size, size)) > 0.985).astype(np.float32)
    arr += grit[:, :, None] * rng.choice([-34, 30], size=(size, size))[:, :, None]
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(OUT, "ground_concrete.png"))


def ground_dirt():
    size = 1024
    rng = np.random.default_rng(11)
    r = random.Random(11)
    low = periodic_noise(size, 4, rng, 5)
    fine = rng.random((size, size)).astype(np.float32)
    lum = 0.78 + 0.34 * low + 0.10 * (fine - 0.5)
    img = shade(lum, (150, 118, 84))
    drift = periodic_noise(size, 3, rng, 2)
    img[:, :, 1] *= 0.94 + 0.10 * drift
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im, "RGBA")
    for lane in (300, 700):  # tyre ruts
        for i in range(0, size, 6):
            off = math.sin(i / 90.0) * 10
            d.ellipse([lane + off - 22, i - 6, lane + off + 22, i + 6], fill=(60, 44, 30, 40))
    for _ in range(900):
        x, y = r.randrange(size), r.randrange(size)
        rad = r.randrange(2, 7)
        c = r.choice([(110, 100, 90), (180, 160, 130), (90, 76, 64), (200, 188, 160)])
        wrap_draw(size, lambda dx, dy: d.ellipse([x - rad + dx, y - rad + dy, x + rad + dx, y + rad + dy], fill=c + (230,)))
    for _ in range(60):
        x, y = r.randrange(size), r.randrange(size)
        wrap_draw(size, lambda dx, dy: d.line([x + dx, y + dy, x + r.randrange(-8, 8) + dx, y - r.randrange(14, 30) + dy],
                                              fill=(92, 112, 52, 220), width=3))
    im = im.filter(ImageFilter.GaussianBlur(0.5))
    im.save(os.path.join(OUT, "ground_dirt.png"))


FACADES = {
    "a": dict(wall=(176, 168, 148), trim=(96, 124, 118), seed=1, floors=3, door="shutter"),
    "b": dict(wall=(214, 170, 120), trim=(122, 70, 52), seed=2, floors=2, door="door"),
    "c": dict(wall=(198, 150, 150), trim=(92, 104, 120), seed=3, floors=3, door="shutter"),
    "d": dict(wall=(206, 200, 184), trim=(148, 80, 60), seed=4, floors=2, door="door"),
    "e": dict(wall=(150, 168, 150), trim=(214, 196, 150), seed=5, floors=3, door="door"),
}


def facade(name, cfg):
    W = H = 512
    rng = np.random.default_rng(cfg["seed"] * 31)
    r = random.Random(cfg["seed"])
    noise = periodic_noise(W, 5, rng, 4)
    fine = rng.random((H, W)).astype(np.float32)
    lum = 0.88 + 0.22 * noise + 0.06 * (fine - 0.5)
    img = shade(lum, cfg["wall"])
    # damp / soot toward the base
    yy = np.linspace(0, 1, H)[:, None]
    img *= (1.0 - 0.30 * np.clip((yy - 0.62) / 0.38, 0, 1) ** 1.3)[:, :, None]
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im, "RGBA")
    trim = cfg["trim"]
    # parapet + cornice
    d.rectangle([0, 0, W, 26], fill=trim + (255,))
    d.rectangle([0, 26, W, 32], fill=(40, 34, 30, 120))
    # horizontal floor bands
    floors = cfg["floors"]
    fh = (H - 70) // floors
    for f in range(floors):
        y0 = 44 + f * fh
        bottom = f == floors - 1
        cols = 3
        cw = W // cols
        for c in range(cols):
            x0 = c * cw + cw // 2 - 46
            wy = y0 + 14
            wh = fh - 52 if not bottom else fh - 34
            if bottom and c == 1:
                # ground floor: door or roll-up shutter
                if cfg["door"] == "shutter":
                    d.rectangle([x0 - 8, wy - 4, x0 + 108, wy + wh + 2], fill=(116, 118, 116, 255))
                    for ry in range(wy, wy + wh, 7):
                        d.line([x0 - 8, ry, x0 + 108, ry], fill=(80, 82, 80, 200), width=2)
                else:
                    d.rectangle([x0 + 6, wy - 2, x0 + 90, wy + wh + 2], fill=trim + (255,))
                    d.rectangle([x0 + 16, wy + 8, x0 + 80, wy + wh + 2], fill=(60, 44, 34, 255))
                    d.ellipse([x0 + 68, wy + wh // 2, x0 + 76, wy + wh // 2 + 8], fill=(226, 190, 80, 255))
                continue
            wide = 92
            d.rectangle([x0 - 7, wy - 7, x0 + wide + 7, wy + wh + 7], fill=trim + (255,))
            lit = r.random() < 0.3
            glass = (236, 170, 90, 255) if lit else (52, 66, 82, 255)
            d.rectangle([x0, wy, x0 + wide, wy + wh], fill=glass)
            # reflection streak
            d.polygon([(x0 + 10, wy), (x0 + 34, wy), (x0 + 12, wy + wh), (x0, wy + wh)], fill=(255, 255, 255, 34))
            d.line([x0 + wide // 2, wy, x0 + wide // 2, wy + wh], fill=trim + (255,), width=4)
            if r.random() < 0.55:  # grille bars
                for gx in range(x0 + 12, x0 + wide, 16):
                    d.line([gx, wy, gx, wy + wh], fill=(30, 26, 24, 230), width=3)
            elif r.random() < 0.5:  # louvres
                for ly in range(wy + 4, wy + wh, 9):
                    d.line([x0, ly, x0 + wide, ly], fill=(70, 76, 70, 200), width=3)
            if r.random() < 0.25 and not bottom:  # AC unit
                d.rectangle([x0 + 14, wy + wh + 8, x0 + 78, wy + wh + 30], fill=(214, 212, 204, 255), outline=(90, 88, 84, 255))
            # sill + water stains
            d.rectangle([x0 - 10, wy + wh + 7, x0 + wide + 10, wy + wh + 13], fill=(226, 218, 200, 230))
            for k in range(r.randrange(2, 5)):
                sx = x0 + r.randrange(0, wide)
                d.line([sx, wy + wh + 14, sx + r.randrange(-3, 3), wy + wh + r.randrange(40, 90)], fill=(60, 50, 40, 46), width=r.randrange(4, 9))
    # peeling patches exposing block / brick
    for _ in range(9):
        x, y = r.randrange(20, W - 80), r.randrange(60, H - 60)
        w, h = r.randrange(24, 70), r.randrange(18, 50)
        d.rectangle([x, y, x + w, y + h], fill=(150, 124, 106, 150))
        for by in range(y, y + h, 10):
            d.line([x, by, x + w, by], fill=(100, 84, 72, 160), width=1)
    # painted ad band on the base
    if cfg["seed"] % 2 == 1:
        d.rectangle([20, H - 54, 190, H - 22], fill=(220, 80, 60, 235))
        d.rectangle([28, H - 46, 182, H - 30], outline=(250, 240, 210, 235), width=3)
    im = im.filter(ImageFilter.GaussianBlur(0.5))
    im.save(os.path.join(OUT, "facade_%s.png" % name))


def main():
    os.makedirs(OUT, exist_ok=True)
    ground_concrete()
    ground_dirt()
    for k, cfg in FACADES.items():
        facade(k, cfg)
    print("wrote ground_concrete, ground_dirt and %d facades to %s" % (len(FACADES), OUT))


if __name__ == "__main__":
    main()

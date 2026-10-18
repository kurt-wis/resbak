"""Draws the Home screen's cardboard skins into assets/ui/home/ (numpy + PIL only, no network).

    python tools/make_home_ui.py

cardboard.png        256x256, 9-slice (margin 30): corrugated brown card with a worn, slightly
                     wobbly cut edge and rounded corners (player card, picker pad)
cardboard_dark.png   the same card in a darker, greyer board (hover / pressed buttons)
tape.png             128x44 masking tape strip, semi-transparent, for the card corners
Generated here so the art is original to the repo (see assets/audio/CREDITS.md for the rule).
"""
import os

import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join("assets", "ui", "home")
RNG = np.random.default_rng(1025)


def value_noise(w, h, cell, rng):
    gw, gh = w // cell + 3, h // cell + 3
    g = rng.random((gh, gw))
    big = np.array(Image.fromarray((g * 255).astype(np.uint8)).resize((gw * cell, gh * cell), Image.BICUBIC)) / 255.0
    return big[:h, :w]


def cardboard(size, base, dark):
    h = w = size
    n1 = value_noise(w, h, 48, RNG)
    n2 = value_noise(w, h, 12, RNG)
    n3 = value_noise(w, h, 3, RNG)
    y = np.arange(h)[:, None] * np.ones((1, w))
    corr = 0.5 + 0.5 * np.sin(y * 2 * np.pi / 7.0)          # corrugation ribs
    fibre = value_noise(w, h, 2, RNG)
    v = 0.62 + 0.20 * n1 + 0.10 * n2 + 0.06 * n3 + 0.07 * corr - 0.05 * fibre
    col = np.zeros((h, w, 3))
    for c in range(3):
        col[..., c] = base[c] * v
    # edge wear: lighter, fibrous rim and a darker inner shadow
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy]).astype(float)
    wob = value_noise(w, h, 9, RNG) * 5.0
    rim = np.clip((edge - wob) / 10.0, 0, 1)
    col *= (0.78 + 0.22 * rim)[..., None]
    for c in range(3):
        col[..., c] = col[..., c] * (1 - (1 - rim) * 0.0) + (1 - rim) * dark[c] * 0.18
    # rounded-corner alpha with a wobbly cut line
    r = 22.0
    cx = np.clip(xx, r, w - 1 - r)
    cy = np.clip(yy, r, h - 1 - r)
    d = np.hypot(xx - cx, yy - cy)
    a = np.clip((r - d + 1.5 - wob * 0.18) * 1.2, 0, 1)
    img = np.dstack([np.clip(col, 0, 255), a * 255]).astype(np.uint8)
    return Image.fromarray(img, "RGBA").filter(ImageFilter.GaussianBlur(0.4))


def tape():
    w, h = 128, 44
    n = value_noise(w, h, 6, RNG)
    base = np.array([226, 214, 170], dtype=float)
    col = base[None, None, :] * (0.9 + 0.1 * n[..., None])
    a = np.full((h, w), 168.0)
    # torn zig-zag ends
    for y in range(h):
        k = int(5 * abs(((y * 7) % 11) - 5) / 5)
        a[y, :k + 2] = 0
        a[y, w - k - 2:] = 0
    img = np.dstack([col, a]).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    cardboard(256, (186, 140, 92), (60, 40, 24)).save(os.path.join(OUT, "cardboard.png"))
    cardboard(256, (150, 118, 84), (40, 30, 20)).save(os.path.join(OUT, "cardboard_dark.png"))
    tape().save(os.path.join(OUT, "tape.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()

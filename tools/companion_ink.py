#!/usr/bin/env python3
"""Cleans a companion picture into black ink on clear (design log 0144),
the form companion_pop.gdshader colors.

    python3 tools/companion_ink.py assets/companion/blush/frame_*.png
    python3 tools/companion_ink.py --paper 0.9 assets/companion/sleeping/*.png

Pictures exported with a background (a gray vignette, a dark wash, a
color) read as ink everywhere to the shader. This looks at each picture as
it would show over white, takes away the local background tone (a wide
blur), and keeps only what's darker than its surroundings: the lines,
hatching and marks. --paper L (0..1) first turns everything lighter than
L to blank paper, for a light background with a pattern in it (a baked-in
transparency checkerboard). Each original is kept in an originals/ folder beside
it (Godot ignores that folder), and running again starts from that copy.

Needs Pillow and numpy.
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageFilter

BACKGROUND_BLUR = 10  # px; wider than a line, narrower than a face
LOW, HIGH = 0.03, 0.10  # darkness above the background: clear .. full ink


def clean(path, paper=None):
    folder, name = os.path.split(path)
    keep = os.path.join(folder, "originals")
    os.makedirs(keep, exist_ok=True)
    gdignore = os.path.join(keep, ".gdignore")
    if not os.path.exists(gdignore):
        open(gdignore, "w").close()
    original = os.path.join(keep, name)
    if not os.path.exists(original):
        shutil.copy2(path, original)

    rgba = np.asarray(Image.open(original).convert("RGBA")).astype(np.float32) / 255.0
    alpha = rgba[..., 3:4]
    over_white = rgba[..., :3] * alpha + (1.0 - alpha)
    light = over_white.mean(axis=2)
    if paper:
        light = np.clip(light / paper, 0.0, 1.0)
    dark = 1.0 - light

    dark_img = Image.fromarray((dark * 255).astype(np.uint8))
    background = np.asarray(dark_img.filter(ImageFilter.GaussianBlur(BACKGROUND_BLUR)),
                            dtype=np.float32) / 255.0
    ink = np.clip((dark - background - LOW) / (HIGH - LOW), 0.0, 1.0)

    out = np.zeros(rgba.shape, dtype=np.uint8)
    out[..., 3] = (ink * 255).astype(np.uint8)
    Image.fromarray(out).save(path)
    print("%s: %.1f%% ink" % (path, 100.0 * (ink > 0.5).mean()))


if __name__ == "__main__":
    args = sys.argv[1:]
    paper = None
    if len(args) >= 2 and args[0] == "--paper":
        paper = float(args[1])
        args = args[2:]
    if not args or any(a.startswith("--") for a in args):
        sys.exit(__doc__)
    for p in args:
        clean(p, paper)

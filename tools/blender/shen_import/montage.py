"""Tile rendered frames into one image, for judging motion side by side.

    Blender -b --factory-startup --python tools/blender/shen_import/montage.py -- OUT.png COLS frame.png ...
"""
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out, cols, files = args[0], int(args[1]), args[2:]
tiles = []
for path in files:
    im = bpy.data.images.load(path)
    w, h = im.size
    a = np.empty(w * h * 4, np.float32)
    im.pixels.foreach_get(a)
    tiles.append(a.reshape(h, w, 4))
h, w = tiles[0].shape[:2]
rows = int(np.ceil(len(tiles) / cols))
sheet = np.zeros((rows * h, cols * w, 4), np.float32)
sheet[..., 3] = 1
for i, t in enumerate(tiles):
    r, c = i // cols, i % cols
    sheet[(rows - 1 - r) * h:(rows - r) * h, c * w:(c + 1) * w] = t
im = bpy.data.images.new("m", cols * w, rows * h, alpha=True)
im.pixels.foreach_set(sheet.ravel())
im.filepath_raw = out
im.file_format = "PNG"
im.save()

# Blender -b --python sheet.py -- OUT.png STEP DIR:f1,f2,... [DIR:...] : contact sheet, one row per DIR (frames by number), downsampled by STEP; 4px gap
import sys, os, bpy, numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
out, k = a[0], int(a[1])
rows = []
for spec in a[2:]:
    d, fr = spec.rsplit(":", 1)
    row = []
    for f in fr.split(","):
        im = bpy.data.images.load(os.path.join(d, "f_%05d.png" % int(f)))
        w, h = im.size
        px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::k, ::k]
        row.append(px); bpy.data.images.remove(im)
    gap = np.ones((row[0].shape[0], 4, 4), np.float32)
    rows.append(np.concatenate(sum([[r, gap] for r in row], [])[:-1], axis=1))
W = max(r.shape[1] for r in rows)
rows = [np.pad(r, ((0, 0), (0, W - r.shape[1]), (0, 0)), constant_values=1) for r in rows]
hgap = np.ones((6, W, 4), np.float32)
sheet = np.concatenate(sum([[r, hgap] for r in rows[::-1]], [])[:-1], axis=0)  # bpy pixels are bottom-up: first row ends on top
H, W = sheet.shape[:2]
img = bpy.data.images.new("sheet", W, H, alpha=True)
img.pixels = sheet.ravel()
img.filepath_raw = out; img.file_format = "PNG"; img.save()
print("SHEET", out, W, H)

"""The guandao haft's real centreline and radius, measured on the prop mesh, for the animation solver's grips.

    Blender -b --factory-startup --python tools/blender/shen_import/haft_axis.py -- PHASE

The rig's haft line runs from the BUTT landmark to the SOCKET landmark, and the sculpted haft is neither on it nor quite straight: its centre
wanders 0.04-0.15 rig units off that line. A fist turned about the landmark line swings into the wood. This slices the haft every 0.05 along
the landmark line, fits a circle to each slice's vertices, keeps the clean round slices (plain wood, not the ornaments), and fits the centre's
offset as a quadratic in s (distance along the line from the right-hand grip landmark).
Writes work/shen_import/haft_pN.json: "knots" [s, x, y] (the smoothed slice centres: centre(s) = GRIP + HAFT * s + e1 * x + e2 * y, interpolated,
held at the ends), the quadratic fit "c1", "c2" for reference, "radius", all in rig space at the sculpt's pose.
"""
import json
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
phase = int(sys.argv[sys.argv.index("--") + 1])

CI = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))).inverted()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Props.glb" % phase))
V = []
for o in bpy.data.objects:
    if o.type == "MESH" and "Weapon" in o.name:
        M = CI @ o.matrix_world
        V += [tuple(M @ v.co) for v in o.data.vertices]
V = np.array(V)
spec = json.loads(os.environ["HAFT_SPEC"])     # {"grip": [...], "haft": [...], "smin": x, "socket_s": y} from the solver's Rig (shen_lib)
g, h = np.array(spec["grip"]), np.array(spec["haft"])
e1 = np.cross(h, (0.0, 1.0, 0.0))
e1 /= np.linalg.norm(e1)
e2 = np.cross(h, e1)
s = (V - g) @ h
rows = []
for a in np.arange(spec["smin"] + 0.05, spec["socket_s"], 0.05):
    m = (s > a) & (s < a + 0.05)
    if m.sum() < 30:
        continue
    q = (V[m] - g) - np.outer(s[m], h)
    x, y = q @ e1, q @ e2
    A = np.column_stack([2 * x, 2 * y, np.ones_like(x)])
    cx, cy, k = np.linalg.lstsq(A, x * x + y * y, rcond=None)[0]
    R = float(np.sqrt(k + cx * cx + cy * cy))
    sd = float(np.std(np.hypot(x - cx, y - cy)))
    rows.append((a + 0.025, cx, cy, R, sd))
rows = np.array(rows)
clean = rows[(rows[:, 4] < 0.015) & (rows[:, 3] > 0.07) & (rows[:, 3] < 0.1)]
radius = float(np.median(clean[:, 3]))
c1 = np.polyfit(clean[:, 0], clean[:, 1], 2)[::-1]
c2 = np.polyfit(clean[:, 0], clean[:, 2], 2)[::-1]
fit = np.column_stack([np.polyval(c1[::-1], clean[:, 0]), np.polyval(c2[::-1], clean[:, 0])])
res = np.hypot(*(fit - clean[:, 1:3]).T)
k = np.array([1, 2, 3, 2, 1], float) / 9.0     # the centre itself, lightly smoothed along the clean slices: the haft's own gentle S-bend, which the quadratic misses by up to 0.045
sm = [np.convolve(np.pad(clean[:, j], 2, mode="edge"), k, mode="valid") for j in (1, 2)]
out = {"knots": [[round(float(a), 4), round(float(x), 4), round(float(y), 4)] for a, x, y in zip(clean[:, 0], *sm)], "e1": e1.tolist(), "e2": e2.tolist(), "c1": c1.tolist(), "c2": c2.tolist(), "radius": radius, "s_range": [float(clean[0, 0]), float(clean[-1, 0])],
       "slices": len(rows), "clean": len(clean), "fit_residual_max": float(res.max())}
json.dump(out, open(os.path.join(ROOT, "work/shen_import/haft_p%d.json" % phase), "w"), indent=1)
print("HAFT", phase, json.dumps(out))

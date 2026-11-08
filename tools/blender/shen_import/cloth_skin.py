"""Samples of Grandmaster Shen's garment surface with the skin weights the game really draws them with, for ClothSim's skin constraint.

    Blender -b --factory-startup --python tools/blender/shen_import/cloth_skin.py -- PHASE

Writes work/shen_import/clothskin_pN.json: {"spacing", "samples": [{"g": garment, "v": rest position (rig space), "w": [[bone, weight], ...]}]}.
The cloth lattice's particles can all clear his body while the robe drawn between them does not: a garment vertex is a weighted blend of up
to four bones, often of two lattices (the outer coat and the under-skirt) that wrap a limb from different sides, and the blend of points
outside a leg can lie inside it (measured 2026-11-07, phase 2 idle: every bone alone put a robe vertex 0.25-1.0 outside his right shin,
their blend put it 0.28 inside). skin_rig.py --cloth-only turns these samples into constraints; the weights are the frozen ones in the
game GLB (assets/build/grandmaster_shen/Shen_P<n>_Game.glb), read here, never changed.
One vertex per SPACING cell of each garment, the one nearest the cell's centre; only vertices the cloth lattice moves (cloth weight over
MIN_CLOTH).
(2026-11-07) And one per FINE cell where the garment rests within NEAR of his legs or hips (the parts' distance fields, body_sdf.py): between samples
0.2 apart the drawn robe still dipped into him where it lies on the trousers (phase 1 idle, his left inner thigh: the nearest sample, 0.08
away, held its clearance while the vertex between went 0.06 into the leg).
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
SPACING = float(os.environ.get("SHEN_SKIN_SPACING", 0.2))     # (2026-11-07) what the committed samples use: 0.25 and 0.3 left the robe visibly in his thigh
MIN_CLOTH = 0.3
FINE = float(os.environ.get("SHEN_SKIN_FINE", 0.07))
NEAR = float(os.environ.get("SHEN_SKIN_NEAR", 0.05))
# where the lattice's own sway meets him: the legs and hips (the mantle, beads, beard and hair rest on his chest, shoulders and head by design)
NEAR_PARTS = tuple(os.environ.get("SHEN_SKIN_NEAR_PARTS", "LowerTorso,RightUpperLeg,RightLowerLeg,LeftUpperLeg,LeftLowerLeg").split(","))
CLOTH = ("RobeBack", "RobeRight", "RobeLeft", "RobeInner", "RobeFront", "RightMantle", "LeftMantle", "LeftSleeve", "RightSleeve", "RibbonRight", "RibbonLeft", "HairBack", "Beard", "Beads")
CI = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))).inverted()   # Blender (z up) to rig space (y up)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Game.glb" % phase))
info = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen%d/pieces.json" % phase)))
sdf = np.load(os.path.join(ROOT, "work/shen_import/sdf_p%d.npz" % phase))


def gap(P):
    """Each rest point's distance outside the nearest of NEAR_PARTS (negative inside), trilinear in the parts' fields; off a grid counts as far."""
    out = np.full(len(P), 9.0)
    for part in NEAR_PARTS:
        grid, lo, st = sdf[part + "_grid"], sdf[part + "_origin"], float(sdf[part + "_step"])
        q = (P - lo) / st
        n = np.array(grid.shape) - 1
        i0 = np.clip(np.floor(q).astype(int), 0, n - 1)
        f = np.clip(q - i0, 0.0, 1.0)
        v = np.zeros(len(P))
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    v += (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2]) * grid[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
        v[np.any((q < 0) | (q > n), axis=1)] = 9.0
        out = np.minimum(out, v)
    return out


samples = []
for g in CLOTH:
    pts, wts = [], []
    for ob in sorted((o for o in bpy.data.objects if o.type == "MESH" and info.get(o.name.split(".")[0], {}).get("group") == g), key=lambda o: o.name):
        M = CI @ ob.matrix_world
        names = {vg.index: vg.name for vg in ob.vertex_groups}
        for v in ob.data.vertices:
            w = sorted(((names[e.group], e.weight) for e in v.groups if e.weight > 1e-3), key=lambda x: -x[1])[:4]
            tot = sum(x[1] for x in w)
            if tot <= 0 or sum(x[1] for x in w if x[0].startswith("Cl_")) / tot < MIN_CLOTH:
                continue
            pts.append(tuple(M @ v.co))
            wts.append([[b, round(x / tot, 4)] for b, x in w])
    if not pts:
        continue
    P = np.array(pts)
    cell = np.floor(P / SPACING).astype(int)
    centre = (cell + 0.5) * SPACING
    d = np.linalg.norm(P - centre, axis=1)
    best = {}
    for i, key in enumerate(map(tuple, cell)):
        if key not in best or d[i] < d[best[key]]:
            best[key] = i
    for i in sorted(best.values()):
        samples.append({"g": g, "v": [round(float(x), 4) for x in P[i]], "w": wts[i]})
    near = np.nonzero(gap(P) < NEAR)[0]
    fine = {}
    if FINE > 0 and len(near):
        taken = P[sorted(best.values())]
        fc = np.floor(P[near] / FINE).astype(int)
        fd = np.linalg.norm(P[near] - (fc + 0.5) * FINE, axis=1)
        for k, key in enumerate(map(tuple, fc)):
            if key not in fine or fd[k] < fd[fine[key]]:
                fine[key] = k
        fine = {key: k for key, k in fine.items() if np.linalg.norm(taken - P[near[k]], axis=1).min() > FINE * 0.5}
        for k in sorted(fine.values()):
            i = near[k]
            samples.append({"g": g, "v": [round(float(x), 4) for x in P[i]], "w": wts[i], "fine": 1})
    print("SKIN", g, len(pts), "vertices ->", len(best), "samples +", len(fine), "near the body", flush=True)
json.dump({"spacing": SPACING, "fine": FINE, "near": NEAR, "samples": samples}, open(os.environ.get("SHEN_SKIN_OUT") or os.path.join(ROOT, "work/shen_import/clothskin_p%d.json" % phase), "w"))
print("CLOTHSKIN", phase, len(samples))

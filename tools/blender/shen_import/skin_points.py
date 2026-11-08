"""Grandmaster Shen's body surface with its real skin weights, for the animation solver's weapon clearance.

    Blender -b --factory-startup --python tools/blender/shen_import/skin_points.py -- PHASE

The solver used to carry each part's surface samples rigidly on that part's bone. The real skin blends near every joint: the wrist crease and
the heel of the palm (sculpted on the arm mesh) follow the hand, the top of the shoulder follows the chest. A rigid sample is not where that skin
is, so an arm could look clear to the solver and still sit in the haft on screen.
This writes work/shen_import/surface_pN.npz (not skin_pN.npz, which holds skin_rig.py's source weights): `<part>_rigid` (below), and every vertex of the body and hand meshes (thinned evenly), in rig space at rest, grouped by the body
part whose bone it follows most (`<part>_P`), with its four largest weights (`<part>_W`) and their bones (`<part>_B`, indices into `bones`, solver
part names). A cloth bone's weight goes to the body bone it hangs from.
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
PARTS = ("Head", "UpperTorso", "LowerTorso", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
         "RightUpperLeg", "RightLowerLeg", "LeftUpperLeg", "LeftLowerLeg")
KEEP = {"Head": 600, "UpperTorso": 1500, "LowerTorso": 1500, "RightUpperArm": 500, "RightLowerArm": 600, "RightHand": 500,
        "LeftUpperArm": 500, "LeftLowerArm": 600, "LeftHand": 500, "RightUpperLeg": 500, "RightLowerLeg": 400, "LeftUpperLeg": 500, "LeftLowerLeg": 400}
CI = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))).inverted()   # Blender (z up) to rig space (y up)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Game.glb" % phase))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
info = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen%d/pieces.json" % phase)))


def body_bone(name):
    """The solver part a bone moves with: Sk_<part> itself, a cloth bone its nearest Sk_ ancestor."""
    b = arm.data.bones.get(name)
    while b is not None:
        if b.name.startswith("Sk_") and b.name[3:] in PARTS:
            return b.name[3:]
        b = b.parent
    return None


pts, wts, bns = [], [], []
for ob in bpy.data.objects:
    base = ob.name.split(".")[0]
    if ob.type != "MESH" or base not in info or info[base].get("group") not in PARTS:
        continue
    M = CI @ ob.matrix_world
    names = {g.index: body_bone(g.name) for g in ob.vertex_groups}
    for v in ob.data.vertices:
        acc = {}
        for e in v.groups:
            p = names.get(e.group)
            if p is not None and e.weight > 0:
                acc[p] = acc.get(p, 0.0) + e.weight
        if not acc:
            acc = {info[base]["group"]: 1.0}
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
        s = sum(w for _, w in top)
        pts.append(tuple(M @ v.co))
        wts.append([w / s for _, w in top] + [0.0] * (4 - len(top)))
        bns.append([PARTS.index(p) for p, _ in top] + [PARTS.index(top[0][0])] * (4 - len(top)))
P, W, B = np.array(pts), np.array(wts), np.array(bns)
out = {"bones": np.array(PARTS)}
for i, part in enumerate(PARTS):
    m = np.nonzero(B[:, 0] == i)[0]
    m = m[:: max(1, len(m) // KEEP[part])]
    out[part + "_P"], out[part + "_W"], out[part + "_B"] = P[m].astype(np.float32), W[m].astype(np.float32), B[m].astype(np.int8)
    print("SKIN", part, len(m), "blended %.0f%%" % (100 * float(np.mean(W[m, 0] < 0.98)) if len(m) else 0), flush=True)
# Where each part's solid (body_sdf.py) may count: voxels whose nearest surface of that part's own mesh is skinned to its own bone over RIGID,
# exactly as tools/blender/shen_import/mesh_clash.py judges it. A solid is carried rigidly by its bone; near a joint it is not where the blended skin
# is, and the skinned samples above (the other direction of the test) cover those zones instead.
from mathutils import Vector  # noqa: E402
from mathutils.kdtree import KDTree  # noqa: E402
RIGID = 0.8
sdf = np.load(os.path.join(ROOT, "work/shen_import/sdf_p%d.npz" % phase))
for part in PARTS:
    if part + "_grid" not in sdf.files:
        continue
    vp, vw = [], []
    for ob in bpy.data.objects:
        base = ob.name.split(".")[0]
        if ob.type != "MESH" or base not in info or info[base].get("group") != part:
            continue
        M = CI @ ob.matrix_world
        vg = ob.vertex_groups.get("Sk_" + part)
        for v in ob.data.vertices:
            vp.append(M @ v.co)
            vw.append(next((e.weight for e in v.groups if vg is not None and e.group == vg.index), 0.0))
    kd = KDTree(len(vp))
    for i, q in enumerate(vp):
        kd.insert(q, i)
    kd.balance()
    grid, lo, st = sdf[part + "_grid"], sdf[part + "_origin"], float(sdf[part + "_step"])
    rigid = np.ones(grid.shape, bool)
    for idx in np.argwhere(grid < 0.3):
        rigid[tuple(idx)] = vw[kd.find(Vector(lo + st * idx))[1]] > RIGID
    out[part + "_rigid"] = rigid
    print("RIGID", part, "%.0f%% of the near voxels" % (100 * float(rigid[grid < 0.3].mean())), flush=True)
np.savez_compressed(os.path.join(ROOT, "work/shen_import/surface_p%d.npz" % phase), **out)
print("SKINDONE", phase)

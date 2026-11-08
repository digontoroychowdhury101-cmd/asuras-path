"""Signed distance fields of Grandmaster Shen's body parts, measured from the real GLB at rest, for the animation solver's weapon clearance.

    Blender -b --factory-startup --python tools/blender/shen_import/body_sdf.py -- PHASE

Writes work/shen_import/sdf_pN.npz: for each part, `<part>_grid` (distance in rig units, negative inside, clamped to +-0.5), `<part>_origin` and `<part>_step`.
SDF_PARTS=Weapon writes the glaive's (from the props file, rest pose) to sdf_pN_Weapon.npz, its grid laid along the weapon's own axes (`Weapon_axes`, rows)
at 0.025: a grid point p maps to rig space as centre + axes.T @ (origin + step * index).
The distance is to that part's own surface; inside or outside is its generalized winding number (over 0.5 inside), which holds up where the
sculpt is open (hems, cuffs, the cuts between parts), unlike ray parity or flooding the outside in.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
phase = int(sys.argv[sys.argv.index("--") + 1])
ALL_PARTS = ("Head", "UpperTorso", "LowerTorso", "RightUpperArm", "RightLowerArm", "LeftUpperArm", "LeftLowerArm", "RightUpperLeg", "RightLowerLeg", "LeftUpperLeg", "LeftLowerLeg")
PARTS = tuple(os.environ["SDF_PARTS"].split(",")) if os.environ.get("SDF_PARTS") else ALL_PARTS     # SDF_PARTS: a subset, written to sdf_pN_<first part>.npz
STEP, PAD, CLAMP = 0.04, 0.3, 0.5
CI = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))).inverted()   # Blender (z up) to rig space (y up)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Game.glb" % phase))
import json  # noqa: E402
info = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen%d/pieces.json" % phase)))
if PARTS == ("Weapon",):
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Props.glb" % phase))
dg = bpy.context.evaluated_depsgraph_get()
geo = {}
for ob in bpy.data.objects:
    base = ob.name.split(".")[0]
    if ob.type != "MESH" or base not in info:
        continue
    g = info[base].get("group")
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    M = CI @ ob.matrix_world
    v, t = geo.setdefault(g, ([], []))
    o = len(v)
    v += [M @ x.co for x in me.vertices]
    t += [tuple(o + i for i in p.vertices) for p in me.polygons]
    ev.to_mesh_clear()


def winding(V, T, P, chunk=4000000):
    """Generalized winding number of the triangle soup (V, T) at points P: about 1 inside, 0 outside, and it degrades gracefully where the sculpt is open."""
    A, B, C = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    out = np.zeros(len(P))
    step = max(1, chunk // len(T))
    for s0 in range(0, len(P), step):
        p = P[s0:s0 + step, None, :]
        a, b, c = A[None] - p, B[None] - p, C[None] - p
        la, lb, lc = (np.linalg.norm(x, axis=2) for x in (a, b, c))
        det = np.einsum("ijk,ijk->ij", a, np.cross(b, c))
        den = la * lb * lc + np.einsum("ijk,ijk->ij", a, b) * lc + np.einsum("ijk,ijk->ij", b, c) * la + np.einsum("ijk,ijk->ij", c, a) * lb
        out[s0:s0 + step] = np.arctan2(det, den).sum(1) / (2 * np.pi)
    return np.abs(out)


out = {}
if PARTS == ("Weapon",):
    v, t = geo["Weapon"]
    P = np.array([tuple(x) for x in v])
    c = P.mean(0)
    axes = np.linalg.svd(P - c, full_matrices=False)[2]     # long, wide, thin
    Q = (P - c) @ axes.T
    bvh = BVHTree.FromPolygons([Vector(q) for q in Q], t, epsilon=0.0)
    step, pad = 0.025, 0.2
    lo = Q.min(0) - pad
    dims = np.ceil((Q.max(0) + pad - lo) / step).astype(int) + 1
    grid = np.full(dims, 0.3, np.float32)
    near, dist = [], []
    for i in range(dims[0]):
        for j in range(dims[1]):
            for k in range(dims[2]):
                hit = bvh.find_nearest(Vector(lo + step * np.array((i, j, k))), 0.3)
                if hit[0] is not None:
                    near.append((i, j, k))
                    dist.append(hit[3])
    near = np.array(near)
    wn = winding(Q, np.array(t), lo + step * near)
    grid[near[:, 0], near[:, 1], near[:, 2]] = np.where(wn > 0.5, -1.0, 1.0) * np.array(dist)
    np.savez_compressed(os.path.join(ROOT, "work/shen_import/sdf_p%d_Weapon.npz" % phase), Weapon_grid=grid, Weapon_origin=lo, Weapon_step=np.array(step), Weapon_axes=axes, Weapon_centre=c)
    print("SDF Weapon", dims.tolist(), "inside voxels", int((grid < 0).sum()))
    print("SDFDONE", phase)
    sys.exit(0)
for part in PARTS:
    v, t = geo[part]
    bvh = BVHTree.FromPolygons(v, t, epsilon=0.0)
    P = np.array([tuple(x) for x in v])
    lo, hi = P.min(0) - PAD, P.max(0) + PAD
    dims = np.ceil((hi - lo) / STEP).astype(int) + 1
    grid = np.full(dims, CLAMP, np.float32)
    near, dist = [], []
    for i in range(dims[0]):
        for j in range(dims[1]):
            for k in range(dims[2]):
                hit = bvh.find_nearest(Vector(lo + STEP * np.array((i, j, k))), CLAMP)
                if hit[0] is not None:
                    near.append((i, j, k))
                    dist.append(hit[3])
    near = np.array(near)
    wn = winding(P, np.array(t), lo + STEP * near)
    grid[near[:, 0], near[:, 1], near[:, 2]] = np.where(wn > 0.5, -1.0, 1.0) * np.array(dist)
    out[part + "_grid"] = grid
    out[part + "_origin"] = lo
    out[part + "_step"] = np.array(STEP)
    print("SDF", part, dims.tolist(), "inside voxels", int((grid < 0).sum()), flush=True)
np.savez_compressed(os.path.join(ROOT, "work/shen_import/sdf_p%d%s.npz" % (phase, "_" + PARTS[0] if PARTS != ALL_PARTS else "")), **out)
print("SDFDONE", phase)

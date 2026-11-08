"""Which body volumes each garment sample (cloth_skin.py) ever comes near, over every baked clip: ClothSim tests a sample only against those.

    python3 tools/blender/shen_import/cloth_skin_reach.py PHASE SUFFIX [MARGIN]

Reads work/opening_cast_bake/shen_shots/c<PHASE>_<clip><SUFFIX>.json (cloth_bake.py, one per clip of work/opening_cast_bake/shen), skins every
sample with its real weights, and finds, per sample and per body volume it avoids (as ClothSim: all but the glaive and the arm it hangs from), the least room it ever had (its distance from the volume
less its clearance, as ClothSim reckons both). Writes work/shen_import/clothskin_reach_p<PHASE>.json: per sample, per volume (collider index) the least
room it ever had; skin_rig.py keeps the volumes that came within its REACH_MARGIN. MARGIN here only sets the printed count. Bake the clips with the surface pass off (an earlier ClothSim), whose cloth
runs nearer the body, so the set is generous; a volume a sample never came near costs nothing at runtime.
"""
import glob
import json
import os
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../.."))
phase, suffix = int(sys.argv[1]), sys.argv[2]
MARGIN = float(sys.argv[3]) if len(sys.argv) > 3 else 0.35
SKIN_MARGIN = 0.02     # as ClothSim
IO = os.environ.get("SHEN_SKIN_DIR", os.path.join(ROOT, "work/shen_import"))     # (2026-11-07) another folder of clothskin/cloth files, for trials
samples = json.load(open(os.path.join(IO, "clothskin_p%d.json" % phase)))["samples"]
cloth = json.load(open(os.path.join(IO, "cloth_p%d.json" % phase)))
cols, parts, bones = cloth["colliders"], cloth["particles"], cloth["bones"]
kind = {s["name"]: s["kind"] for s in cloth["sheets"]}
# the particles that carry a sample in ClothSim (skin_rig.py drops pins, orbs and fingers from the weights)
sheet_of_bone = {bones[p["bone"]]["name"]: p for p in parts if "bone" in p and not p["pin"] and "orb" not in p and "finger" not in p}
V = np.array([s["v"] for s in samples])
N = len(samples)


def seg(c, X):
    a, b = np.array(c["a"]), np.array(c["b"])
    d = b - a
    u = np.clip((X - a) @ d / max(d @ d, 1e-9), 0, 1)
    return np.linalg.norm(X - a - np.outer(u, d), axis=1), u


# each sample's volumes and clearances, exactly as ClothSim.new works them out
pairs = []        # (sample, collider, clearance value, firm)
for k, s in enumerate(samples):
    avoid, hung = set(), set()
    for name, _ in s["w"]:
        p = sheet_of_bone.get(name)
        if p is None:
            continue
        for side in ("Left", "Right"):
            if p["anchor"].startswith(side) and p["anchor"][len(side):] in ("UpperArm", "LowerArm", "Hand"):
                hung |= {side + "UpperArm", side + "LowerArm", side + "Hand"}
    for ci in range(len(cols)):    # every body volume, as ClothSim
        c = cols[ci]
        if c["limb"] == "Glaive" or c["limb"] in hung:
            continue
        d, u = seg(c, V[k:k + 1])
        d, u = float(d[0]), float(u[0])
        if d < 0.05:
            continue
        r = c["r"] + (c["rb"] - c["r"]) * u
        pairs.append((k, ci, min(SKIN_MARGIN, (d - r) * 0.985) if d >= r else d * 0.985 - r, True))
P = np.array([p[0] for p in pairs])
C = np.array([p[1] for p in pairs])
H = np.array([p[2] for p in pairs])
F = np.array([p[3] for p in pairs])
room = np.full(len(pairs), np.inf)
bone_names = sorted({b for s in samples for b, _ in s["w"]})
bi = {b: i for i, b in enumerate(bone_names)}
Wm = np.zeros((N, 4))
Bm = np.zeros((N, 4), int)
for k, s in enumerate(samples):
    for j, (b, w) in enumerate(s["w"]):
        Wm[k, j], Bm[k, j] = w, bi[b]
shots = sorted(glob.glob(os.path.join(ROOT, "work/opening_cast_bake/shen_shots/c%d_*%s.json" % (phase, suffix))))
for path in shots:
    frames = json.load(open(path))["frames"]
    for fr in frames:
        R = np.tile(np.eye(3), (len(bone_names), 1, 1))
        T = np.zeros((len(bone_names), 3))
        for b, i in bi.items():
            v = fr["bones"].get(b)
            if v is not None:
                R[i], T[i] = np.array(v[:9]).reshape(3, 3), v[9:12]
        X = np.zeros((N, 3))
        for j in range(4):
            X += Wm[:, j, None] * (np.einsum("nij,nj->ni", R[Bm[:, j]], V) + T[Bm[:, j]])
        for ci in np.unique(C):
            m = C == ci
            v = fr["bones"]["Sk_" + cols[ci]["limb"]]
            Rl, tl = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
            Q = (X[P[m]] - tl) @ Rl
            d, u = seg(cols[ci], Q)
            r = cols[ci]["r"] + (cols[ci]["rb"] - cols[ci]["r"]) * u
            need = np.where(F[m], r + H[m], H[m])
            room[m] = np.minimum(room[m], d - need)
keep = room < MARGIN
reach = [[] for _ in range(N)]
for k, ci, rm in zip(P, C, room):
    reach[k].append([int(ci), round(float(rm), 3)])
json.dump({"suffix": suffix, "shots": len(shots), "reach": reach}, open(os.path.join(IO, "clothskin_reach_p%d.json" % phase), "w"))
print("P%d: %d shots; %d sample-volume pairs, %d within %.2f; samples with any %d of %d" % (phase, len(shots), len(pairs), int(keep.sum()), MARGIN, sum(1 for r in reach if r), N))

"""Every lattice quad of every sheet vs the firm capsules of one limb, per frame: worst corner clearance and worst bilinear-surface clearance.
usage: quadscan.py SHOT PARTICLES.npy LIMB lo hi [cdir]"""
import json, sys, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
shot, pd, limb, lo, hi = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
cdir = sys.argv[6] if len(sys.argv) > 6 else ROOT + "/work/shen_import"
data = json.load(open(ROOT + "/work/opening_cast_bake/shen_shots/%s.json" % shot)); phase = data["phase"]
cloth = json.load(open(cdir + "/cloth_p%d.json" % phase))
PP = np.load(pd); P = cloth["particles"]
caps = [c for c in cloth["colliders"] if c["limb"] == limb]
idx = {(p["sheet"], p["r"], p["c"]): i for i, p in enumerate(P)}
quads = []
for (sh, r, c), i in idx.items():
    q = [idx.get((sh, r, c + 1)), idx.get((sh, r + 1, c)), idx.get((sh, r + 1, c + 1))]
    if None not in q: quads.append((sh, r, c, [i] + q))
def clear(Q, c):
    a, b = np.array(c["a"]), np.array(c["b"]); d = b - a
    u = np.clip((Q - a) @ d / (d @ d), 0, 1)
    return np.linalg.norm(Q - a - np.outer(u, d), axis=-1) - (c["r"] + (c.get("rb", c["r"]) - c["r"]) * u)
s = np.linspace(0, 1, 9)
W = np.array([[(1 - x) * (1 - y), x * (1 - y), (1 - x) * y, x * y] for y in s for x in s])  # corners order: (r,c),(r,c+1),(r+1,c),(r+1,c+1)
print("caps", [(c.get("firm"), round(c["r"], 3)) for c in caps])
for f in range(lo, hi + 1):
    v = data["frames"][f]["bones"]["Sk_" + limb]; R, t = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
    X = (PP[f] - t) @ R
    rows = []
    for sh, r, c, q in quads:
        Q = X[q]; S2 = W @ Q
        cc = min(clear(Q, k).min() for k in caps); cs = min(clear(S2, k).min() for k in caps)
        if cs < -0.04: rows.append((cs, cc, sh, r, c))
    rows.sort()
    print("f%3d %s" % (f, "  ".join("%s r%d c%d surf %+.3f corn %+.3f" % (sh, r, c, cs, cc) for cs, cc, sh, r, c in rows[:4])))

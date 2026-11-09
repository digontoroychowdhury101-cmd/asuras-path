"""Per frame: how a lattice quad sits against a firm leg capsule -- each corner's clearance (distance to the axis minus radius) and the bilinear
surface's worst point between them (no Blender: shot bones + dumped particles)."""
import json, sys, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
shot, pd, solid = sys.argv[1], sys.argv[2], sys.argv[3]
quad = [int(x) for x in sys.argv[4].split(",")]   # p00,p01,p10,p11 (row r col c, row r col c+1, row r+1 col c, row r+1 col c+1)
lo, hi = int(sys.argv[5]), int(sys.argv[6])
cdir = sys.argv[7] if len(sys.argv) > 7 else ROOT + "/work/shen_import"
data = json.load(open(ROOT + "/work/opening_cast_bake/shen_shots/%s.json" % shot)); phase = data["phase"]
cloth = json.load(open(cdir + "/cloth_p%d.json" % phase))
PP = np.load(pd)
caps = [c for c in cloth["colliders"] if c["limb"] == solid]
def clear(Q, c):
    a, b = np.array(c["a"]), np.array(c["b"]); d = b - a
    u = np.clip((Q - a) @ d / (d @ d), 0, 1)
    return np.linalg.norm(Q - a - np.outer(u, d), axis=1) - (c["r"] + (c.get("rb", c["r"]) - c["r"]) * u)
s = np.linspace(0, 1, 21)
for f in range(lo, hi + 1):
    v = data["frames"][f]["bones"]["Sk_" + solid]; R, t = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
    P = (PP[f][quad] - t) @ R
    A, B, Cc, D = P
    S2 = np.array([(1 - x) * (1 - y) * A + x * (1 - y) * B + (1 - x) * y * Cc + x * y * D for x in s for y in s])
    for c in caps:
        cc = clear(P, c); cs = clear(S2, c)
        k = int(cs.argmin())
        print("f%3d corners %s  surface worst %+.3f at (%.2f,%.2f)  corner gap %.2f %.2f" % (f, " ".join("%+.2f" % x for x in cc), cs.min(), s[k // 21], s[k % 21], np.linalg.norm(A - B), np.linalg.norm(Cc - D)))

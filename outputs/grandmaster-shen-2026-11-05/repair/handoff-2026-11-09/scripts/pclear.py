"""One particle per frame: its clearance from every firm/soft volume it avoids (distance to the capsule axis minus what it needs) and where it is."""
import json, sys, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
shot, pd, pi, lo, hi = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
cdir = sys.argv[6] if len(sys.argv) > 6 else ROOT + "/work/shen_import"
data = json.load(open(ROOT + "/work/opening_cast_bake/shen_shots/%s.json" % shot)); phase = data["phase"]
cloth = json.load(open(cdir + "/cloth_p%d.json" % phase))
PP = np.load(pd); P = cloth["particles"]; C = cloth["colliders"]
hits = P[pi]["hit"]
print("particle", pi, P[pi]["sheet"], P[pi]["r"], P[pi]["c"])
print("hits:", ", ".join("%d %s%s %.2f" % (h[0], C[h[0]]["limb"], "*" if h[2] else "", h[1]) for h in hits))
for f in range(lo, hi + 1):
    row = []
    for h in hits:
        c = C[h[0]]; b = data["frames"][f]["bones"].get("Sk_" + c["limb"])
        if b is None: row.append("  ?  "); continue
        R, t = np.array(b[:9]).reshape(3, 3), np.array(b[9:12])
        Q = (PP[f][pi] - t) @ R
        a, bb = np.array(c["a"]), np.array(c["b"]); d = bb - a
        u = float(np.clip((Q - a) @ d / (d @ d), 0, 1)); dist = float(np.linalg.norm(Q - a - u * d))
        rr = c["r"] + (c.get("rb", c["r"]) - c["r"]) * u
        need = rr + h[1] if h[2] else h[1]
        row.append("%+.2f" % (dist - need))
    print("f%3d %s  pos %s" % (f, " ".join(row), np.round(PP[f][pi], 2)))

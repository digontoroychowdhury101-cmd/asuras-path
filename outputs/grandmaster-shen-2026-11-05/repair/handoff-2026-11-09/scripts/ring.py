"""Where a sheet's particles sit around a limb capsule: radial clearance and angle about the limb axis, at rest and at shot frames."""
import json, sys, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
shot, frames, limb, sheets, cdir = sys.argv[1], [int(x) for x in sys.argv[2].split(",")], sys.argv[3], sys.argv[4].split(","), sys.argv[5]
data = json.load(open(ROOT + "/work/opening_cast_bake/shen_shots/%s.json" % shot))
cloth = json.load(open(cdir + "/cloth_p%d.json" % data["phase"]))
bones = cloth["bones"]
cap = [c for c in cloth["colliders"] if c.get("limb") == limb]
c = max(cap, key=lambda c: c["r"])
a, b = np.array(c["a"]), np.array(c["b"]); ax = (b - a) / np.linalg.norm(b - a)
e1 = np.cross(ax, [0, 0, -1.0]); e1 /= np.linalg.norm(e1); e2 = np.cross(ax, e1)
print("capsule", limb, "r", c["r"], c.get("rb"), "len", round(float(np.linalg.norm(b - a)), 3))
def where(P):
    q = P - a; u = np.clip(q @ ax / np.linalg.norm(b - a), 0, 1); foot = a + np.outer(u, b - a); d = P - foot
    r = np.linalg.norm(d, axis=1) - (c["r"] + (c.get("rb", c["r"]) - c["r"]) * u)
    ang = np.degrees(np.arctan2(d @ e2, d @ e1))
    return u, r, ang
import os
KEEP = {(k.split(":")[0], int(k.split(":")[1])) for k in os.environ.get("KEEP", "").split(",") if k}
sel = [(i, p) for i, p in enumerate(cloth["particles"]) if p["sheet"] in sheets and "bone" in p]
for f in [None] + frames:
    if f is None:
        P = np.array([p["at"] for _, p in sel]); tag = "rest"
    else:
        fr = data["frames"][f]
        Rl, tl = np.array(fr["bones"]["Sk_" + limb][:9]).reshape(3, 3), np.array(fr["bones"]["Sk_" + limb][9:12])
        W = np.array([np.array(fr["bones"][bones[p["bone"]]["name"]][:9]).reshape(3, 3) @ np.array(p["at"]) + np.array(fr["bones"][bones[p["bone"]]["name"]][9:12]) for _, p in sel])
        P = (W - tl) @ Rl; tag = "frame %d" % f      # into the limb's rest frame
    u, r, ang = where(P)
    print("--", tag)
    for (i, p), uu, rr, aa in zip(sel, u, r, ang):
        if (p["sheet"], p["c"]) in KEEP or not KEEP and rr < 0.45 and 0 < uu < 1:
            print("  %-6s r%d c%d  along %.2f  clear %+.3f  angle %+5.0f" % (p["sheet"], p["r"], p["c"], uu, rr, aa))

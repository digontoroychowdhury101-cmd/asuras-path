import sys, json, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
S = (__import__("os").environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair")
def ang(R): return np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1)))
def load(p):
    d = json.load(open(p)); return [{k: np.array(v).reshape(4, 4) for k, v in f["parts"].items()} for f in d["frames"]]
name, lo, hi = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
src = sys.argv[4] if len(sys.argv) > 4 else ROOT + "/work/opening_cast_bake/shen"
for tag, path in (("before", S + "/bake_snap/GrandmasterShen_%s.json" % name), ("after", src + "/GrandmasterShen_%s.json" % name)):
    W = load(path)
    print("==", tag)
    for i in range(max(lo, 1), min(hi, len(W) - 1) + 1):
        a, b = W[i - 1], W[i]
        out = []
        for h in ("RightHand", "LeftHand"):
            ra = a["Glaive"][:3, :3].T @ a[h][:3, :3]; rb = b["Glaive"][:3, :3].T @ b[h][:3, :3]
            d = ra.T @ rb
            # axis of relative change
            w = np.array([d[2,1]-d[1,2], d[0,2]-d[2,0], d[1,0]-d[0,1]]); 
            out.append("%s rel %5.1f axis %s dist %.2f" % (h[:1], ang(d), np.round(w / (np.linalg.norm(w) + 1e-9), 2), np.linalg.norm(b[h][:3,3]-b["Glaive"][:3,3])))
        print("f%3d " % i + " | ".join(out))

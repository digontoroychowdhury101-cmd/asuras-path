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
        sp = {p: ang(a[p][:3, :3].T @ b[p][:3, :3]) for p in ("RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand", "Glaive")}
        wr = ang(b["RightLowerArm"][:3, :3].T @ b["RightHand"][:3, :3]); wl = ang(b["LeftLowerArm"][:3, :3].T @ b["LeftHand"][:3, :3])
        print("f%3d " % i + " ".join("%s %5.1f" % (k[:6] + k[-4:], v) for k, v in sp.items()) + " | wR %5.1f wL %5.1f" % (wr, wl))

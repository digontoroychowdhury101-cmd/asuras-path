import sys, os, json, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
S = (__import__("os").environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair")
PARTS = ("RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand", "UpperTorso", "Glaive")
def ang(R): return np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1)))
def detail(path):
    d = json.load(open(path)); F = d["frames"]
    W = [{k: np.array(v).reshape(4, 4) for k, v in f["parts"].items()} for f in F]
    out = []
    for p in PARTS:
        R = [w[p][:3, :3] for w in W]
        v = np.array([ang(R[i].T @ R[i + 1]) for i in range(len(R) - 1)])
        a = np.abs(np.diff(v)) if len(v) > 1 else np.zeros(1)
        out.append((a.max(), p, int(a.argmax()) + 1, v.max(), int(v.argmax())))
    out.sort(reverse=True)
    wr = [ang(w["RightLowerArm"][:3, :3].T @ w["RightHand"][:3, :3]) for w in W]
    wl = [ang(w["LeftLowerArm"][:3, :3].T @ w["LeftHand"][:3, :3]) for w in W]
    return out[:2], (max(wr), int(np.argmax(wr))), (max(wl), int(np.argmax(wl))), len(F), d.get("loop"), d.get("fps", None)
for n in sys.argv[1:]:
    name = "GrandmasterShen_%s.json" % n
    A = detail(S + "/bake_snap/" + name); B = detail(ROOT + "/work/opening_cast_bake/shen/" + name)
    print("== %s (%d frames, loop %s)" % (n, B[3], B[4]))
    for tag, X in (("before", A), ("after ", B)):
        print("  %s accel %s | wristR %.0f@%d wristL %.0f@%d" % (tag, "; ".join("%s %.1f@f%d (speed %.1f@f%d)" % (p, a, fa, v, fv) for a, p, fa, v, fv in X[0]), X[1][0], X[1][1], X[2][0], X[2][1]))

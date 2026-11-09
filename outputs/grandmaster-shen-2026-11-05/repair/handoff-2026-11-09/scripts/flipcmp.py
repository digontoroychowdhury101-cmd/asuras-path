"""Per clip: the worst one-frame hand flip (min of world turn and turn on the haft), peak part acceleration, wrist bends; snap (old export) vs dc (dense-cloud export) vs now."""
import json, sys, numpy as np, os
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
S = (__import__("os").environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair")
def ang(R): return np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1)))
PARTS = ("RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand")
def stats(path):
    F = json.load(open(path))["frames"]
    W = [{k: np.array(v).reshape(4, 4)[:3, :3] for k, v in fr["parts"].items()} for fr in F]
    flip = (0, "", 0)
    for h in ("RightHand", "LeftHand"):
        for i in range(1, len(W)):
            m = min(ang(W[i-1][h].T @ W[i][h]), ang((W[i-1]["Glaive"].T @ W[i-1][h]).T @ (W[i]["Glaive"].T @ W[i][h])))
            if m > flip[0]: flip = (m, h[0], i)
    acc = (0, "", 0)
    for p in PARTS:
        v = np.array([ang(W[i].get(p).T @ W[i + 1][p]) for i in range(len(W) - 1)])
        a = np.abs(np.diff(v))
        if len(a) and a.max() > acc[0]: acc = (a.max(), p, int(a.argmax()) + 1)
    wr = max(ang(w["RightLowerArm"].T @ w["RightHand"]) for w in W); wl = max(ang(w["LeftLowerArm"].T @ w["LeftHand"]) for w in W)
    return "flip %5.1f %s@f%-3d accel %5.1f %-13s@f%-3d wristR %3.0f wristL %3.0f" % (flip[0], flip[1], flip[2], acc[0], acc[1], acc[2], wr, wl)
for n in sys.argv[1:]:
    f = "GrandmasterShen_%s.json" % n
    print("== " + n)
    for tag, d in (("snap", S + "/bake_snap"), ("dc", S + "/bake_dc"), ("now", ROOT + "/work/opening_cast_bake/shen")):
        print("  %-4s %s" % (tag, stats(os.path.join(d, f))))

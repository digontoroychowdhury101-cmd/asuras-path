"""Every exported clip, before (frozen bake) vs after (the dense-cloud export): peak angular speed and acceleration over the arm, torso and glaive
parts (deg/frame), wrist bend, loop seam, frame count; and the per-clip grip/arm checks the export recorded in its own json, when present."""
import sys, os, json, glob, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
S = (__import__("os").environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair")
PARTS = ("RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand", "UpperTorso", "Glaive")
def ang(R): return np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1)))
def stats(path):
    d = json.load(open(path)); F = d["frames"]
    W = [{k: np.array(v).reshape(4, 4) for k, v in f["parts"].items()} for f in F]
    sp, ac, worst = 0, 0, ""
    for p in PARTS:
        R = [w[p][:3, :3] for w in W]
        v = np.array([ang(R[i].T @ R[i + 1]) for i in range(len(R) - 1)])
        a = np.abs(np.diff(v)) if len(v) > 1 else np.zeros(1)
        if v.max() > sp: sp, worst = v.max(), p
        ac = max(ac, a.max())
    wr = max(ang(w["RightLowerArm"][:3, :3].T @ w["RightHand"][:3, :3]) for w in W)
    wl = max(ang(w["LeftLowerArm"][:3, :3].T @ w["LeftHand"][:3, :3]) for w in W)
    seam = max(ang(W[0][p][:3, :3].T @ W[-1][p][:3, :3]) for p in PARTS)
    return dict(speed=sp, part=worst, accel=ac, wr=wr, wl=wl, seam=seam, n=len(F), loop=d.get("loop"), length=d.get("length"))
rows = []
for b in sorted(glob.glob(ROOT + "/work/opening_cast_bake/shen/GrandmasterShen_P*.json")):
    name = os.path.basename(b); a = S + "/bake_snap/" + name
    if not os.path.exists(a): print("no before for", name); continue
    A, B = stats(a), stats(b)
    rows.append((name[16:-5], A, B))
print("%-26s %-34s | %-34s" % ("clip", "before: speed accel wristR/L seam", "after: speed accel wristR/L seam"))
flag = []
for n, A, B in rows:
    print("%-26s %6.2f %6.2f %5.0f/%-4.0f %5.2f | %6.2f %6.2f %5.0f/%-4.0f %5.2f %s" % (n, A["speed"], A["accel"], A["wr"], A["wl"], A["seam"], B["speed"], B["accel"], B["wr"], B["wl"], B["seam"],
          ("frames %d->%d" % (A["n"], B["n"])) if A["n"] != B["n"] else ""))
    if B["accel"] > A["accel"] * 1.25 + 0.5 or B["speed"] > A["speed"] * 1.25 + 0.5 or B["wr"] > A["wr"] + 5 or B["wl"] > A["wl"] + 5 or B["seam"] > A["seam"] + 0.5:
        flag.append(n)
print("worse after (speed/accel +25%%, wrist +5 deg, seam +0.5 deg):", flag)

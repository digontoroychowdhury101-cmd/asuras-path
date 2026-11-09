"""keyed-only sequential solve of one clip with arc centres patched: ARC_PATCH="t0:cx,cy,cz;..." CLIP FR Q"""
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D: sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
P = {}
for part in filter(None, os.environ.get("ARC_PATCH", "").split(";")):
    t, c = part.split(":"); P[round(float(t), 3)] = tuple(float(x) for x in c.split(","))
_arc = SC.arc
def arc(t0, *a, **k):
    if round(t0, 3) in P: k["centre"] = P[round(t0, 3)]
    return _arc(t0, *a, **k)
SC.arc = arc
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + os.environ["CLIP"]); times = clip.frames()
clip._side = {}
a, b = [int(x) for x in os.environ.get("FR", "0:999").split(":")]
rows = []
for i in range(a, min(b, len(times))):
    k = clip.controls(times[i]); c = dict(k); local, world, diag = clip.solve(c)
    tor = L.arm_torso_world(clip.rig, world)
    dv = np.asarray(c["rp"]) - np.asarray(k["rp"])
    rows.append((i, dv, tor["Right"], tor["Left"]))
jumps = [float(np.linalg.norm(rows[j][1] - 0.5 * (rows[j-1][1] + rows[j+1][1]))) for j in range(1, len(rows) - 1)]
print(os.environ.get("ARC_PATCH", "base"), "| max R %.2f L %.2f | worst corr-pop %.2f @f%d" % (max(r[2] for r in rows), max(r[3] for r in rows), max(jumps), rows[1 + int(np.argmax(jumps))][0]))
if os.environ.get("V"):
    for i, dv, r, l in rows: print("f%d corr %s R %.2f L %.2f" % (i, np.round(dv, 2), r, l))

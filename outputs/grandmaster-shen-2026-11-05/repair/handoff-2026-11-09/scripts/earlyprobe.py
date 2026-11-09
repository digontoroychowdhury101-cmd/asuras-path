import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; F = [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
times = clip.frames(); ctrl = [clip.controls(t) for t in times]
L.organic(clip, times, ctrl); L.spine_reach(clip, ctrl)
def ev(c):
    clip._side = {}; t2 = dict(c); _l, w, d = clip.solve(t2); clip._side = None
    sh = float(np.linalg.norm(np.asarray(t2["rp"]) - np.asarray(c["rp"])))
    return float(L.elbow_torso(rg, t2, "Right").min()), sh, d.get("arm_reach", 0)
for i in F:
    c = ctrl[i]
    clip._side = {}; _l, w, d = clip.solve(dict(c)); clip._side = None
    Rc = w["UpperTorso"][:3, :3]; at = (w["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
    print("f%d base best %.2f shift %.2f reach %.2f haft-chest %s" % ((i,) + ev(c) + (np.round(np.asarray(c["haft"]) @ Rc, 2),)))
    for dvec in L.ARM_TORSO_DIRS + [L.unit(np.array(v)) for v in ((1, 0, -1), (1, 0.5, -1), (1, -0.5, -1), (1, 0, 0), (0.5, 0, -1))]:
        print("  %s " % np.round(dvec, 2) + "  ".join("%.1f:%.2f/s%.2f" % ((m,) + ev(dict(c, rp=tuple(np.asarray(c["rp"]) + Rc @ dvec * m)))[:2]) for m in (0.2, 0.4, 0.6, 0.8, 1.0)))

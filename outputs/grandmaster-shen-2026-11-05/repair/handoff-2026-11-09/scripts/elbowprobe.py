import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; frames = [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
ctrl = pickle.load(open("%s/pretorso_%s.pkl" % (os.path.dirname(os.path.abspath(__file__)), name), "rb"))
def eb(c):
    clip._side = {}; t2 = dict(c); clip.solve(t2); clip._side = None
    return {sd: L.elbow_torso(rg, t2, sd) for sd in ("Right", "Left")}
for i in frames:
    c = ctrl[i]
    clip._side = {}; _l, world, diag = clip.solve(dict(c)); clip._side = None
    Rc = world["UpperTorso"][:3, :3]
    e = eb(c)
    print("f%d actual %s best-elbow R %.2f L %.2f  R turns %s" % (i, {k: round(v, 2) for k, v in L.arm_torso(clip, c).items()}, e["Right"].min(), e["Left"].min(), np.round(e["Right"], 2)))
    for dvec in L.ARM_TORSO_DIRS:
        row = []
        for m in (0.3, 0.6, 0.9):
            t2 = dict(c); t2["rp"] = tuple(np.asarray(c["rp"]) + Rc @ dvec * m)
            e = eb(t2); g = L.held_clash(clip, t2, wrists=False)
            row.append("%.1f:%.2f g%.3f" % (m, e["Right"].min(), g))
        print("  dir %s  %s" % (np.round(dvec, 2), "  ".join(row)))

import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; frames = [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
ctrl = pickle.load(open("' + (__import__('os').environ.get('SHEN_SCRATCH') or ROOT + '/work/shen_repair') + '/pretorso_%s.pkl" % name, "rb"))
for i in frames:
    c = ctrl[i]
    clip._side = {}; _l, world, diag = clip.solve(dict(c)); clip._side = None
    Rc = world["UpperTorso"][:3, :3]
    d0 = L.arm_torso(clip, c); g0 = L.held_clash(clip, c)
    print("f%d base torso %.3f/%.3f guard %.3f lhw %.2f ltw %.2f" % (i, d0["Right"], d0["Left"], g0, c["lhw"], c["ltw"]))
    for dvec in L.ARM_TORSO_DIRS:
        row = []
        for m in (0.2, 0.4, 0.6, 0.8):
            t2 = dict(c); t2["rp"] = tuple(np.asarray(c["rp"]) + Rc @ dvec * m)
            d = L.arm_torso(clip, t2); g = L.held_clash(clip, t2)
            row.append("%.1f:%.2f/%.2f g%.3f" % (m, d["Right"], d["Left"], g))
        print("  dir %s  %s" % (np.round(dvec, 2), "  ".join(row)))

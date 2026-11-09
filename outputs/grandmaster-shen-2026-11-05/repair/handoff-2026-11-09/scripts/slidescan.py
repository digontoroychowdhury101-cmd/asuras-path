import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; frames = [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
ctrl = pickle.load(open("' + (__import__('os').environ.get('SHEN_SCRATCH') or ROOT + '/work/shen_repair') + '/bake_%s.pkl" % name, "rb"))
for i in frames:
    row = []
    for k in (-0.3, -0.15, 0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9):
        c = dict(ctrl[i]); c["rsl"] = float(c["rsl"]) + k; c["rp"] = tuple(np.asarray(c["rp"], float) + L.unit(c["haft"]) * k)
        d = L.arm_torso(clip, c)
        clip._side = {}; _, world, _ = clip.solve(dict(c)); clip._side = None
        fist = (world["RightHand"] @ np.append(clip.rig.GRIP0, 1))[:3]; Wt = world["UpperTorso"]
        q = (fist - (Wt @ np.append(clip.rig.JOINT["UpperTorso"], 1))[:3]) @ Wt[:3, :3]
        G = world["Glaive"]
        row.append("%+.2f:%.2f/%.2f fz%.2f gl%s" % (k, d["Right"], d["Left"], q[2], np.round(G[:3, 3], 2)))
    print("f%d rsl %.2f lsl %.2f lhw %.2f |" % (i, ctrl[i]["rsl"], ctrl[i]["lsl"], ctrl[i]["lhw"]), " ".join(row))

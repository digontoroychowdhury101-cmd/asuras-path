import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; frames = [int(x) for x in sys.argv[2].split(",")]; key = sys.argv[3] if len(sys.argv) > 3 else "rp"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
ctrl = pickle.load(open("' + (__import__('os').environ.get('SHEN_SCRATCH') or ROOT + '/work/shen_repair') + '/bake_%s.pkl" % name, "rb"))
for i in frames:
    c0 = ctrl[i]; clip._side = {}; Rc = clip.solve(dict(c0))[1]["UpperTorso"][:3, :3]; clip._side = None
    d0 = L.arm_torso(clip, c0)
    best = []
    for m in (0.2, 0.4, 0.6, 0.8, 1.0):
        for dv in L.ARM_TORSO_DIRS:
            c = dict(c0); c[key] = tuple(np.asarray(c0[key], float) + Rc @ dv * m)
            d = L.arm_torso(clip, c)
            best.append((max(d.values()) if key == "rp" else d["Left"], m, tuple(np.round(dv, 1)), round(d["Right"], 2), round(d["Left"], 2)))
    best.sort()
    print("f%d now R %.2f L %.2f | best %s" % (i, d0["Right"], d0["Left"], best[:3]))

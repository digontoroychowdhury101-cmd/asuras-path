import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
for name in sys.argv[1:]:
    clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
    out = clip.bake()
    fl, kn = [], []
    for o in out:
        world = o[2]
        P = world["LowerTorso"][:3, :3]; T = world["LeftUpperLeg"][:3, :3]
        d = (P.T @ T) @ np.array([0, -1.0, 0])
        fl.append(np.degrees(np.arctan2(-d[2], -d[1])))
    print(name, "L flex max %.0f" % max(fl), " ".join("%.0f" % x for x in fl[::6]))

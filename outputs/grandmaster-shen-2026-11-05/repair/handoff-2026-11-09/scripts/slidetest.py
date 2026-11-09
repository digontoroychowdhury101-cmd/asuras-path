import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
S = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, S + "/" + os.environ["DEV"]); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, frs, pk = sys.argv[1], [int(x) for x in sys.argv[2].split(",")], sys.argv[3]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
out = pickle.load(open(pk, "rb"))
for i in frs:
    t, local, world, diag, c = out[i]
    for d in (0.0, 0.1, 0.2, 0.3, 0.4):
        c2 = dict(c); c2["rsl"] = float(c["rsl"]) + d; clip._side = {}
        tor = L.arm_torso(clip, c2)
        print("f%d rsl %.2f (+%.1f) R %.3f L %.3f clash %.3f" % (i, c2["rsl"], d, tor["Right"], tor["Left"], L.held_clash(clip, c2)))

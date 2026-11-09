import sys, os, pickle, copy, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
S = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, S + "/" + os.environ["DEV"]); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, pk = sys.argv[1], sys.argv[2]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
d = pickle.load(open(pk, "rb")); ctrl = d["ctrl"]; clip._side = d["side"]
r0 = [float(c["rsl"]) for c in ctrl]
L.slide_fist(clip, ctrl)
r1 = [float(c["rsl"]) for c in ctrl]
for i in range(len(ctrl)):
    if abs(r1[i] - r0[i]) > 1e-4 or i in (19, 20, 21, 22):
        tor = L.arm_torso(clip, ctrl[i])
        print("f%d slide %.2f R %.3f L %.3f clash %.3f" % (i, r0[i] - r1[i], tor["Right"], tor["Left"], L.held_clash(clip, ctrl[i])))

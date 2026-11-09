# gripdiag.py CLIP [pkl]: per frame lhw, left_grip short, lead gap, left off haft (as validate), arm depth L; repo code unless SHEN_DEV
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
if os.environ.get("SHEN_DEV"): sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/" + os.environ["SHEN_DEV"])
S = os.path.dirname(os.path.abspath(__file__)); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
ctrl = pickle.load(open(sys.argv[2] if len(sys.argv) > 2 else "%s/final_%s.pkl" % (S, name), "rb")); clip._side = {}
for i, c0 in enumerate(ctrl):
    c = dict(c0); _l, w, d = clip.solve(c)
    if c["lhw"] < 0.5: continue
    g = d.get("left_grip", 0.0); gap = c.get("_lgap", 0.0)
    if g > 0.05 or gap > 0.05:
        a = L.arm_torso_world(rg, w)
        print("f%d lhw %.2f ltw %.2f left_grip %.3f lgap %.3f L-in-torso %.3f" % (i, c["lhw"], c["ltw"], g, gap, a["Left"]))

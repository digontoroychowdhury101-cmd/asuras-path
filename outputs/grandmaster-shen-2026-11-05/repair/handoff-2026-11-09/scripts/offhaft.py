# offhaft.py CLIP : validate's left_off_haft per frame (lhw >= 0.99), from final_<clip>.pkl; SHEN_DEV=dev for the dev copy
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
if os.environ.get("SHEN_DEV"): sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/" + os.environ["SHEN_DEV"])
S = os.path.dirname(os.path.abspath(__file__)); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
ctrl = pickle.load(open("%s/final_%s.pkl" % (S, name), "rb")); clip._side = {}
for i, c0 in enumerate(ctrl):
    c = dict(c0); _l, world, d = clip.solve(c)
    if c["lhw"] >= 0.99 and c["lhw"] >= c["ltw"]:
        palm = (world["LeftHand"] @ np.append(rg.PALM0, 1))[:3]; ax = L.unit(c["haft"])
        dd = palm - (rg.lead_point(c["rp"], c["haft"], c["face"], float(c.get("_lsl", c["lsl"])), float(c["rsl"])) - ax * float(c.get("_lsl", c["lsl"])))
        off = float(np.linalg.norm(dd - ax * np.dot(dd, ax)))
        if off > 0.08: print("f%d off %.3f lhw %.2f ltw %.2f lgrip %.3f lgap %.3f" % (i, off, c["lhw"], c["ltw"], d.get("left_grip", 0), c.get("_lgap", 0)))

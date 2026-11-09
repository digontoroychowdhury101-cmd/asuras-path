# kprobe.py CLIP F1,F2 : keyed solve of frames (DEV honoured); prints controls' body keys and R/L
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D: sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, frs = sys.argv[1], [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
for f in frs:
    t = clip.frames()[f]; k = clip.controls(t); clip._side = {}
    w = clip.solve(dict(k))[1]; tor = L.arm_torso_world(clip.rig, w)
    print("f%d t%.3f R %.3f L %.3f rp %s lsl %.2f" % (f, t, tor["Right"], tor["Left"], np.round(k["rp"], 2), float(k.get("lsl", 0))))
    if f == frs[0]: print(sorted(k.keys()))

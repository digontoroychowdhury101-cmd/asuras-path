import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
name = sys.argv[1]; frames = [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
ctrl = pickle.load(open("%s/final_%s.pkl" % (S, name), "rb")); clip._side = None
for i in frames:
    c = ctrl[i]
    row = []
    for dy in range(-45, 46, 15):
        for dp in (-15, 0, 15):
            t2 = dict(c); ch = tuple(c["chest"]); t2["chest"] = (ch[0] + dp, ch[1] + dy, ch[2])
            d = L.arm_torso(clip, t2); g = L.held_clash(clip, t2)
            row.append("y%+d p%+d %.2f/%.2f g%.2f" % (dy, dp, d["Right"], d["Left"], g))
    print("f%d chest %s pelR %s" % (i, np.round(c["chest"], 0), np.round(c["pelR"], 0)))
    for k in range(0, len(row), 3): print("   ", " | ".join(row[k:k + 3]))

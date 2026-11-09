import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; F = [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
times = clip.frames(); ctrl = [clip.controls(t) for t in times]
L.organic(clip, times, ctrl); L.spine_reach(clip, ctrl)
floor = float(rg.WCLOUD_S.min()) + L.BUTT_HOLD
print("floor", round(floor, 2))
for i in F:
    row = []
    for k in (0.0, 0.1, 0.2, 0.3, 0.4):
        c = dict(ctrl[i]); c["rsl"] = max(floor, float(c["rsl"]) - k)
        clip._side = {}; t2 = dict(c); _l, w, d = clip.solve(t2); clip._side = None
        sh = float(np.linalg.norm(np.asarray(t2["rp"]) - np.asarray(c["rp"])))
        a = L.arm_torso_world(rg, w)
        row.append("k%.1f shift %.2f arms %.2f/%.2f" % (k, sh, a["Right"], a["Left"]))
    print("f%d " % i + " | ".join(row))

"""ctprobe.py CLIP PKL frame: clear_torso's candidate moves at one frame of a baked control pickle: depth after, guard, both arms"""
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, pkl, fr = sys.argv[1], sys.argv[2], int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
ctrl = pickle.load(open(pkl, "rb")); clip._side = {}
c = dict(ctrl[fr])
R = clip.solve(dict(c))[1]["UpperTorso"][:3, :3]
d0 = L.arm_torso(clip, c); g0 = L.held_clash(clip, c)
print("f%d base torso %s guard %.3f rsl %.2f lsl %.2f" % (fr, {k: round(v, 3) for k, v in d0.items()}, g0, c["rsl"], c["lsl"]))
dirs = {"fwd": (0, 0, -1), "up": (0, 1, 0), "down": (0, -1, 0), "right": (1, 0, 0), "left": (-1, 0, 0), "fwd_up": (0, 0.7, -1), "fwd_right": (0.7, 0, -1), "right_up": (1, 0.7, 0), "fwd_left": (-0.7, 0, -1)}
for nm, dv in dirs.items():
    row = []
    for m in (0.2, 0.4, 0.6, 0.8):
        t2 = dict(c); t2["rp"] = tuple(np.asarray(c["rp"], float) + R @ L.unit(np.array(dv, float)) * m)
        d = L.arm_torso(clip, t2); g = L.held_clash(clip, t2)
        row.append("%.1f:R%.2f/L%.2f g%.2f" % (m, d["Right"], d["Left"], g))
    print("%-9s %s" % (nm, "  ".join(row)))

# movetest.py CLIP F : from the final ctrl at frame F, move rp along chest-frame dirs; print arm depth R/L, held_clash guard, left grip diag, shoulder glide
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
if os.environ.get("SHEN_DEV"): sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/dev")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
name = sys.argv[1]; i = int(sys.argv[2])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
ctrl = pickle.load(open(os.environ.get("PKL") or "%s/final_%s.pkl" % (S, name), "rb")); clip._side = {}
c0 = dict(ctrl[i]); _l, world, diag = clip.solve(dict(c0)); R = world["UpperTorso"][:3, :3]
print("ARM_TORSO_DIRS", np.round(L.ARM_TORSO_DIRS, 2).tolist())
def ev(c):
    t = dict(c); _l, w, d = clip.solve(t)
    a = L.arm_torso_world(clip.rig, w)
    return a["Right"], a["Left"], L.held_clash(clip, c), d.get("left_grip", 0), d.get("arm_reach", 0), t.get("_lgap", 0)
print("base R %.3f L %.3f guard %.3f lgrip %.3f areach %.3f lgap %.3f" % ev(c0))
for name_, dv in (("fwd", (0, 0, -1)), ("fwd-down", (0, -0.6, -0.8)), ("right", (1, 0, 0)), ("left", (-1, 0, 0)), ("down", (0, -1, 0)), ("up", (0, 1, 0)), ("fwd-right", (0.7, 0, -0.7)), ("fwd-left", (-0.7, 0, -0.7)), ("back", (0, 0, 1)), ("back-right", (0.7, 0, 0.7)), ("right-back", (1, 0, 0.3)), ("back-left", (-0.7, 0, 0.7)), ("back-down", (0, -0.5, 0.85)), ("radial", None)):
    row = []
    for m in (0.2, 0.4, 0.6, 0.8):
        if dv is None:
            ct = (world["UpperTorso"] @ np.append(clip.rig.JOINT["UpperTorso"], 1))[:3]
            q = R.T @ (np.asarray(c0["rp"], float) - ct); q[1] = 0; dv = q / np.linalg.norm(q)
        c = dict(c0); c["rp"] = tuple(np.asarray(c0["rp"], float) + R @ np.array(dv, float) * m)
        row.append("%.1f: %.2f/%.2f g%.2f" % ((m,) + ev(c)[:3]))
    print("%-9s" % name_, " | ".join(row))

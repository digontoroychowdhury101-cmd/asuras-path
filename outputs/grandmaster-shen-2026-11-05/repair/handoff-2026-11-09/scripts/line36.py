import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, math, numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, pk, f = sys.argv[1], sys.argv[2], int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
out = pickle.load(open(pk, "rb")); ctrl = [dict(o[4]) for o in out]
sides, worlds, depth, mids, entry = L._polish_sweep(clip, ctrl)
def m(c):
    clip._side = dict(sides[f]); local, world, diag = clip.solve(dict(c)); t = L.arm_torso_world(rg, world, dense=True)
    return t["Right"], L.held_clash(clip, c), diag.get("arm_reach", 0), L.ZR.angle_of(local["RightHand"][:3, :3])
c0 = ctrl[f]
for t in np.arange(0, 0.205, 0.02):
    c = dict(c0); c["rp"] = tuple(np.asarray(c0["rp"], float) + (0, 0, -t)); print("dz %.2f R %.3f clash %.3f reach %.3f wrist %.0f" % ((t,) + m(c)))

# sens36.py CLIP PKL F : one frame's dense right/left torso depth and limits under single control changes (elbow swing, fist moves, haft tilt)
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, math, numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, pk, f = sys.argv[1], sys.argv[2], int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
out = pickle.load(open(pk, "rb")); ctrl = [dict(o[4]) for o in out]
sides, worlds, depth, mids, entry = L._polish_sweep(clip, ctrl)
w = worlds[f]
sh = (w["RightUpperArm"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]; wr = (w["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
sw = L.unit(wr - sh)
def m(c):
    clip._side = dict(sides[f]); local, world, diag = clip.solve(dict(c)); t = L.arm_torso_world(rg, world, dense=True)
    el = (world["RightLowerArm"] @ np.append(rg.JOINT["RightLowerArm"], 1))[:3]
    return "R %.3f L %.3f clash %.3f reach %.3f grip %.3f wrist %.0f elbow %s" % (t["Right"], t["Left"], L.held_clash(clip, c), diag.get("arm_reach", 0), diag.get("left_grip", 0),
            L.ZR.angle_of(local["RightHand"][:3, :3]), np.round(el - sh, 2))
c0 = ctrl[f]; print("base", m(c0), "rpole", np.round(c0["rpole"], 2), "rp", np.round(c0["rp"], 2), "haft", np.round(c0["haft"], 2))
for a in (-90, -60, -30, 30, 60, 90):
    c = dict(c0); c["rpole"] = tuple(L.rodrigues(sw * math.radians(a)) @ np.asarray(c0["rpole"], float)); print("swing %4d" % a, m(c))
for d in ((0.2, 0, 0), (-0.2, 0, 0), (0, 0.2, 0), (0, -0.2, 0), (0, 0, 0.2), (0, 0, -0.2)):
    c = dict(c0); c["rp"] = tuple(np.asarray(c0["rp"], float) + d); print("rp", d, m(c))

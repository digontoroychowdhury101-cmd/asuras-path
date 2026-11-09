import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; i = int(sys.argv[2])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
c = pickle.load(open(sys.argv[3], "rb"))[i]
clip._side = {}; _l, world, diag = clip.solve(dict(c)); clip._side = None
ut = world["UpperTorso"]; Rc = ut[:3, :3]; at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
for m in (0.0, 0.3, 0.6, 0.9):
    t2 = dict(c); t2["rp"] = tuple(np.asarray(c["rp"]) + Rc @ np.array([0, 0, -1.0]) * m)
    clip._side = {}; _l, w2, d2 = clip.solve(t2); clip._side = None
    fist = (w2["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
    el = (w2["RightLowerArm"] @ np.append(rg.JOINT["RightLowerArm"], 1))[:3]
    print("push %.1f keyed %s solved fist %s elbow %s torso %s arm_reach %.3f" % (m, np.round((np.asarray(t2["rp"]) - at) @ Rc, 2), np.round((fist - at) @ Rc, 2), np.round((el - at) @ Rc, 2), {k: round(v, 3) for k, v in L.arm_torso_world(rg, w2).items()}, d2.get("arm_reach", 0)))
print("rpole", c.get("rpole"), "relb", c.get("relb"), "rhand?", "rhand" in c)

import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
clip = next(c for c in SC.library() if c.name.endswith(os.environ.get("CLIP", "P2_Idle")))
t = float(os.environ.get("T", "0"))
poses = [tuple(tuple(float(x) for x in p.split(",")) for p in arg.split("/")) for arg in sys.argv[1:]]
for lua, lfa, lha in poses:
    c = dict(clip.controls(t)); c.update(lhw=0.0, ltw=0.0, lua=lua, lfa=lfa, lha=lha)
    local, world, diag = clip.solve(c)
    tor = L.arm_torso_world(clip.rig, world)
    root = world.get("HumanoidRootPart", np.eye(4))
    J = clip.rig.JOINT
    hand = (world["LeftHand"] @ np.append(J["LeftHand"], 1))[:3]; ch = (world["UpperTorso"] @ np.append(J["LeftUpperArm"], 1))[:3]
    Rc = world["UpperTorso"][:3, :3]
    rel = Rc.T @ (hand - ch)
    print("lua %s lfa %s lha %s | hand from L shoulder, chest frame (x right, y up, z back) %s | torso R %.2f L %.2f" % (lua, lfa, lha, np.round(rel, 2), tor["Right"], tor["Left"]))

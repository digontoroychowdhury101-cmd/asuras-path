import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; frames = [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
ctrl = pickle.load(open(sys.argv[3], "rb"))
for i in frames:
    clip._side = {}; _l, world, diag = clip.solve(dict(ctrl[i])); clip._side = None
    pose = L.pose_of(rg, world)
    ut = world["UpperTorso"]; at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
    for side in ("Right", "Left"):
        for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
            W = world[part]
            B = L.body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
            for t in ("UpperTorso", "LowerTorso"):
                keep = L._torso_free(rg, part, t)
                Wt = world[t]
                d = L.part_depth(rg, t, Wt[:3, :3], (Wt @ np.append(rg.JOINT[t], 1))[:3], B[keep])
                if d.max() > 0.1:
                    k = int(np.argmax(d)); p = (B[keep][k] - at) @ ut[:3, :3]
                    bind = rg.SKIN[part][0][keep][k]
                    print("f%d %s in %s %.3f at chest %s (%d pts >0.14; bind pt %s)" % (i, part, t, d.max(), np.round(p, 2), int((d > 0.14).sum()), np.round(bind, 2)))

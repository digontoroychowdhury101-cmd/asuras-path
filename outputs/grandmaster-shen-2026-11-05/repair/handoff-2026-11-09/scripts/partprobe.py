# partprobe.py CLIP F1,F2 [PKL] : per arm part x torso part depth, keyed (or from a saved bake PKL); DEV honoured
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D: sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, frs = sys.argv[1], [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
out = pickle.load(open(sys.argv[3], "rb")) if len(sys.argv) > 3 else None
for f in frs:
    if out: world = out[f][2]; c = out[f][4]
    else:
        c = clip.controls(clip.frames()[f]); clip._side = {}; world = clip.solve(dict(c))[1]
    pose = L.pose_of(rg, world); row = []
    for side in ("Right", "Left"):
        for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
            W = world[part]; B = L.body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
            for t in ("UpperTorso", "LowerTorso"):
                keep = L._torso_free(rg, part, t)
                if keep.any():
                    Wt = world[t]; d = float(L.part_depth(rg, t, Wt[:3, :3], (Wt @ np.append(rg.JOINT[t], 1))[:3], B[keep]).max())
                    if d > 0.02: row.append("%s>%s %.2f" % (part.replace(side, side[0]), t[:5], d))
    ut = world["UpperTorso"]; fwd = ut[:3, :3] @ np.array([0, 0, -1.0])
    print("f%d chest fwd %s relb %s | %s" % (f, np.round(fwd, 2), np.round(np.asarray(c.get("relb", (0, 0, 0)), float), 2), ", ".join(row)))

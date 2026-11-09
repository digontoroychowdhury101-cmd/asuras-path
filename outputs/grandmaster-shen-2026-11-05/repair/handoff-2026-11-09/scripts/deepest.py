# deepest.py CLIP PKL F[,F] : for each frame, the deepest dense right/left arm samples inside a torso solid: part, torso, depth, the sample's bind point, its distance from the shoulder joint
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, pk = sys.argv[1], sys.argv[2]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
out = pickle.load(open(pk, "rb"))
for f in [int(v) for v in sys.argv[3].split(",")]:
    world = out[f][2]; pose = L.pose_of(rg, world)
    for side in ("Right", "Left"):
        hits = []
        for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
            W = world[part]; P, mix = rg.SKIN_FULL[part]; B = np.zeros_like(P)
            for bone, wt in mix:
                (Rb, ab), jb = (pose[bone], rg.JOINT[bone]) if bone in pose else ((W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3]), rg.JOINT[part])
                B += wt[:, None] * ((P - jb) @ Rb.T + ab)
            for t in ("UpperTorso", "LowerTorso"):
                keep = L._torso_free(rg, part, t, True); Wt = world[t]
                d = L.part_depth(rg, t, Wt[:3, :3], (Wt @ np.append(rg.JOINT[t], 1))[:3], B)
                d = np.where(keep, d, -9)
                for k in np.argsort(-d)[:3]:
                    if d[k] > 0.12:
                        bones = [(bn, round(float(wt[k]), 2)) for bn, wt in mix if wt[k] > 0.05]
                        hits.append((round(float(d[k]), 3), part, t, tuple(np.round(P[k], 2)), round(float(np.linalg.norm(P[k] - rg.JOINT[side + "UpperArm"])), 2), bones,
                                     "thinned" if any(np.allclose(P[k], q) for q in rg.SKIN[part][0]) else "dense-only"))
        hits.sort(reverse=True)
        for h in hits[:4]:
            print(f, side, h)

import sys, os, numpy as np, pickle
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; frames = [int(x) for x in sys.argv[2].split(",")]; push = [float(x) for x in sys.argv[3].split(",")] if len(sys.argv) > 3 else [0, 0, 0]
dchest = [float(x) for x in sys.argv[4].split(",")] if len(sys.argv) > 4 else [0, 0, 0]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
pk = S = "' + (__import__('os').environ.get('SHEN_SCRATCH') or ROOT + '/work/shen_repair') + '/bake_%s.pkl" % name
if os.path.exists(pk): out = pickle.load(open(pk, "rb"))
else:
    out = clip.bake(); pickle.dump([o[4] for o in out], open(pk, "wb")); out = [o[4] for o in out]
rg = clip.rig
for i in frames:
    c = dict(out[i]); clip._side = {}; _, world0, _ = clip.solve(dict(c))
    Rc = world0["UpperTorso"][:3, :3]
    c["rp"] = tuple(np.asarray(c["rp"], float) + Rc @ np.array(push))
    c["chest"] = tuple(np.asarray(c["chest"], float) + np.array(dchest))
    _, world, _ = clip.solve(c); clip._side = None
    pose = L.pose_of(rg, world)
    Wt = world["UpperTorso"]; at = (Wt @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
    print("f%d push %s chest %s rp moved %.2f" % (i, push, dchest, float(np.linalg.norm(np.asarray(c["rp"]) - np.asarray(out[i]["rp"], float)))))
    for side in ("Right", "Left"):
        for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
            W = world[part]
            B = L.body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
            for t in ("UpperTorso", "LowerTorso")[:1 if os.environ.get("UT") else 2]:
                keep = L._torso_free(rg, part, t)
                Wq = world[t]; atq = (Wq @ np.append(rg.JOINT[t], 1))[:3]
                d = L.part_depth(rg, t, Wq[:3, :3], atq, B[keep])
                if d.max() > 0.05:
                    k = int(np.argmax(d)); q = (B[keep][k] - at) @ Wt[:3, :3] + rg.JOINT["UpperTorso"]
                    rest = rg.SKIN[part][0][keep][k]
                    print("   %-14s in %-10s %.3f  n>.05 %3d  at chest-rest %s  (its rest point %s, %.2f from its joint)" % (part, t, d.max(), int((d > 0.05).sum()), np.round(q, 2), np.round(rest, 2), float(np.linalg.norm(rest - rg.JOINT[part]))))

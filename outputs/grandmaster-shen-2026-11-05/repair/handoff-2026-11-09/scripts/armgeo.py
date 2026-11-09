import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
name = sys.argv[1]; frames = [int(x) for x in sys.argv[2].split(",")]; side = sys.argv[3] if len(sys.argv) > 3 else "Left"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
ctrl = pickle.load(open(os.environ.get("PKL") or "%s/final_%s.pkl" % (S, name), "rb")); clip._side = None
print("PROTRACT", L.PROTRACT, "U", np.linalg.norm(rg.LARM_U), "L", np.linalg.norm(rg.LARM_L))
for i in frames:
    c = dict(ctrl[i]); _l, world, diag = clip.solve(c); pose = L.pose_of(rg, world)
    ut = world["UpperTorso"]; at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]; R = ut[:3, :3]
    cf = lambda p: np.round((p - at) @ R, 2)
    jw = lambda part: (world[part] @ np.append(rg.JOINT[part], 1))[:3]
    sh, el, wr = jw(side + "UpperArm"), jw(side + "LowerArm"), jw(side + "Hand")
    print("f%d shoulder %s (rest %s) elbow %s wrist %s |sh-el| %.2f |el-wr| %.2f |sh-wr| %.2f chest yaw/pitch keyed %s" % (i, cf(sh), cf((ut @ np.append(rg.JOINT[side + "UpperArm"], 1))[:3]), cf(el), cf(wr), np.linalg.norm(el - sh), np.linalg.norm(wr - el), np.linalg.norm(wr - sh), np.round(c["chest"], 0)))
    for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
        W = world[part]; B = L.body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
        for t in ("UpperTorso", "LowerTorso"):
            keep = L._torso_free(rg, part, t)
            Wt = world[t]; dd = L.part_depth(rg, t, Wt[:3, :3], (Wt @ np.append(rg.JOINT[t], 1))[:3], B[keep])
            if dd.max() > 0.1:
                k = int(np.argmax(dd)); bind = rg.SKIN[part][0][keep][k]
                j0 = rg.JOINT[part]
                print("   %s in %s %.3f at %s; bind pt rel joint %s; %d pts>0.14 of %d; weights %s" % (part, t, dd.max(), cf(B[keep][k]), np.round(bind - j0, 2), int((dd > 0.14).sum()), len(dd), [(b, round(float(w[np.nonzero(keep)[0][k]]), 2)) for b, w in rg.SKIN[part][1]] if isinstance(rg.SKIN[part][1], list) else "?"))

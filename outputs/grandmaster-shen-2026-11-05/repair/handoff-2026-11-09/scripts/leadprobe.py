"""Bake a clip, keep its final controls, and for each frame with an arm in his torso: the lead hand's grip numbers and which part is in."""
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
pk = "%s/final_%s.pkl" % (S, name)
if os.path.exists(pk) and "--rebake" not in sys.argv:
    ctrl = pickle.load(open(pk, "rb"))
else:
    out = clip.bake(); ctrl = [dict(o[4]) for o in out]; pickle.dump(ctrl, open(pk, "wb"))
clip._side = None
for i, c0 in enumerate(ctrl):
    c = dict(c0); _l, world, diag = clip.solve(c)
    d = L.arm_torso_world(rg, world)
    if max(d.values()) <= L.ARM_TORSO_REST: continue
    pose = L.pose_of(rg, world)
    ut = world["UpperTorso"]; at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]; R = ut[:3, :3]
    def cf(p): return np.round((p - at) @ R, 2)
    SLw = (ut @ np.append(rg.JOINT["LeftUpperArm"], 1))[:3]; SRw = (ut @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
    on = rg.lead_point(c["rp"], c["haft"], c["face"], float(c.get("_lsl", c["lsl"])), float(c["rsl"]))
    el = (world["LeftLowerArm"] @ np.append(rg.JOINT["LeftLowerArm"], 1))[:3]
    er = (world["RightLowerArm"] @ np.append(rg.JOINT["RightLowerArm"], 1))[:3]
    print("f%d R/L %.2f/%.2f lhw %.2f ltw %.2f lsl %.2f->%.2f rsl %.2f | fist %s relb %s | lead %s lelb %s |lead-SL| %.2f haft %s" % (
        i, d["Right"], d["Left"], c["lhw"], c["ltw"], float(c0["lsl"]), float(c.get("_lsl", c["lsl"])), float(c["rsl"]), cf(c["rp"]), cf(er), cf(on), cf(el),
        float(np.linalg.norm(on - SLw)), np.round(np.asarray(c["haft"]) @ R, 2)))
    for side in ("Right", "Left"):
        for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
            W = world[part]
            B = L.body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
            for t in ("UpperTorso", "LowerTorso"):
                keep = L._torso_free(rg, part, t)
                if not keep.any(): continue
                Wt = world[t]
                dd = L.part_depth(rg, t, Wt[:3, :3], (Wt @ np.append(rg.JOINT[t], 1))[:3], B[keep])
                if dd.max() > L.ARM_TORSO_REST:
                    k = int(np.argmax(dd))
                    print("     %s in %s %.3f at chest %s" % (part, t, dd.max(), cf(B[keep][k])))

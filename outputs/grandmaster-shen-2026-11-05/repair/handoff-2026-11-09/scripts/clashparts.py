import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
ctrl = pickle.load(open(sys.argv[2], "rb"))
for i, c in enumerate(ctrl):
    clip._side = {}
    _l, world, diag = clip.solve(dict(c)); clip._side = None
    G = world["Glaive"]; place = (G[:3, :3], G[:3, 3] + G[:3, :3] @ rg.WGRIP); P = (rg.WDENSE @ G[:3, :3].T) + place[1]
    chest = (world["UpperTorso"][:3, :3], (world["UpperTorso"] @ np.append(rg.JOINT["UpperTorso"], 1))[:3])
    row = {}
    for side in ("Right", "Left"):
        j = [(world[k] @ np.append(rg.JOINT[k], 1))[:3] for k in (side + "UpperArm", side + "LowerArm", side + "Hand")]
        row["clash" + side[0]] = L.arm_clash(rg, side, j[0], j[1], j[2], P, world[side + "UpperArm"][:3, :3], world[side + "LowerArm"][:3, :3], place, world[side + "Hand"][:3, :3], chest)
    pose = L.pose_of(rg, world)
    for part in L.BODY_SOLIDS + L.LEG_SOLIDS:
        W = world[part]; B = L.body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
        v = float(L.weapon_depth(rg, place[0], place[1], B).max()) - (L.BODY_IN_WEAPON - L.CLASH_GRAZE)
        if v > 0.005: row["body_" + part] = v
    for part in ("RightUpperArm", "RightLowerArm", "LeftUpperArm", "LeftLowerArm"):
        W = world[part]; B = L.body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
        v = float(L.weapon_depth_rest(rg, (B - G[:3, 3]) @ G[:3, :3]).max())
        if v > 0.005: row["skin_" + part] = v
    print("f%-2d" % i, " ".join("%s=%.3f" % (k, v) for k, v in row.items() if v > 0.005))

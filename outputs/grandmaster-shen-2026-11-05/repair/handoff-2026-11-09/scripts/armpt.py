import sys, os, json, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
phase, name, f = int(sys.argv[1]), sys.argv[2], int(sys.argv[3])
clip = [c for c in SC.build(phase) if c.name.endswith("_" + name)][0]; rg = clip.rig
print("elbow", rg.JOINT["RightLowerArm"], "wrist", rg.JOINT["RightHand"])
data = json.load(open(ROOT + "/work/opening_cast_bake/shen/GrandmasterShen_P%d_%s.json" % (phase, name)))
world = {k: np.array(v).reshape(4, 4) for k, v in data["frames"][f]["parts"].items()}
G = world["Glaive"]; place = (G[:3, :3], G[:3, 3] + G[:3, :3] @ rg.WGRIP)
V = np.load(S + "/wverts_p%d.npy" % phase) if (S := os.environ["S"]) else None
P = V @ G[:3, :3].T + G[:3, 3]
part = "RightLowerArm"; A = (world[part] @ np.append(rg.JOINT[part], 1))[:3]; R = world[part][:3, :3]
d = L.part_depth(rg, part, R, A, P); hit = d > 0.03
Q = (P[hit] - A) @ R + rg.JOINT[part]
e, wj = rg.JOINT["RightLowerArm"], rg.JOINT["RightHand"]
u = (Q - e) @ (wj - e) / ((wj - e) @ (wj - e))
print("hit verts along forearm (0 elbow, 1 wrist): %.2f..%.2f" % (u.min(), u.max()))
# the right hand on the haft: station of the wrist and palm along the haft
W = (world["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
sw = ((W - place[1]) @ place[0] + rg.WGRIP - rg.GRIP0) @ rg.HAFT0
print("wrist at haft station %.2f; hit verts at %.2f..%.2f" % (sw, ((V[hit] - rg.GRIP0) @ rg.HAFT0).min(), ((V[hit] - rg.GRIP0) @ rg.HAFT0).max()))
# forearm surface points in the weapon (the pipeline's other test)
pose = L.pose_of(rg, world)
B = L.body_points(rg, part, R, A, pose)
wd = L.weapon_depth(rg, place[0], place[1], B)
print("forearm surface points %d, deepest in weapon %.3f; nearest to the clash %.3f" % (len(B), wd.max(), np.min(np.linalg.norm(B[:, None] - P[hit][None], axis=2))))
H = L.body_points(rg, "RightHand", world["RightHand"][:3, :3], W, pose)
print("hand points deepest in weapon %.3f (HAND_GRIP %.3f)" % (L.weapon_depth(rg, place[0], place[1], H).max(), L.HAND_GRIP))
ctrl = data["frames"][f]

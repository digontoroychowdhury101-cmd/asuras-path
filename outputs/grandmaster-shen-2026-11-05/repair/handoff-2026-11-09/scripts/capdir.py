import sys, os, json, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
S = os.environ["S"]
clip = [c for c in SC.build(2) if c.name.endswith("_Idle")][0]; rg = clip.rig
data = json.load(open(S + "/before_arm/GrandmasterShen_P2_Idle.json"))
f = 66
world = {k: np.array(v).reshape(4, 4) for k, v in data["frames"][f]["parts"].items()}
G = world["Glaive"]; V = np.load(S + "/wverts_p2.npy"); P = V @ G[:3, :3].T + G[:3, 3]
part = "RightLowerArm"; A = (world[part] @ np.append(rg.JOINT[part], 1))[:3]; W = (world["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
d = L.part_depth(rg, part, world[part][:3, :3], A, P); hit = P[d > 0.03]
c = hit.mean(0); ax = (W - A) / np.linalg.norm(W - A); u = (c - A) @ ax
foot = A + ax * u; out = c - foot
print("elbow", A.round(3), "wrist", W.round(3), "cap-in-arm centre", c.round(3), "u", round(u / np.linalg.norm(W - A), 2), "outward", (out / np.linalg.norm(out)).round(3), "dist", round(float(np.linalg.norm(out)), 3))
print("root yaw", data["frames"][f].get("root"))

import sys, json, numpy as np
sys.path.insert(0, ".")
import shen_clips as SC, shen_lib as L
BODY = ["Head","UpperTorso","LowerTorso","RightUpperArm","RightLowerArm","RightHand","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperLeg","RightLowerLeg","RightFoot","LeftUpperLeg","LeftLowerLeg","LeftFoot"]
phase = int(sys.argv[1]); t = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0
over = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
clip = [c for c in SC.library() if c.name == f"GrandmasterShen_P{phase}_Death"][0]
c = clip.controls(t)
for k, v in over.items(): c[k] = np.array(v, float) if isinstance(v, list) else v
local, world, diag = clip.solve(c)
rg = clip.rig
print(" | ".join("%s %+.2f" % (k.replace("Right","R").replace("Left","L").replace("Upper","U").replace("Lower","Lo"), float(L.place(rg, world, k)[:, 1].min()) - L.GROUND) for k in BODY))
Wp = L.place(rg, world, "Weapon")[::3]
near = {}
for k in BODY:
    B = L.place(rg, world, k)[::3]
    d = np.sqrt(((Wp[:, None, :] - B[None, :, :]) ** 2).sum(-1)).min()
    near[k] = round(float(d), 2)
print("weapon y %+.2f..%+.2f" % (Wp[:, 1].min() - L.GROUND, Wp[:, 1].max() - L.GROUND), "closest body:", sorted(near.items(), key=lambda x: x[1])[:4], {k: round(v, 2) for k, v in diag.items() if v > 0.01})
for side in ("Right", "Left"):
    S = (world["UpperTorso"] @ np.append(rg.JOINT[side + "UpperArm"], 1))[:3]
    H = (world[side + "Hand"] @ np.append(rg.JOINT[side + "Hand"], 1))[:3]
    print(side, "shoulder", np.round(S, 2), "wrist", np.round(H, 2))
hd = L.place(rg, world, "Head"); print("head centre", np.round(hd.mean(0), 2), "pelvis", np.round(L.place(rg, world, "LowerTorso").mean(0), 2))

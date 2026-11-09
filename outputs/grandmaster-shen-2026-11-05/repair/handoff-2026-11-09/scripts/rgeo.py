import sys, math
sys.path.insert(0, "tools/animation/opening_cast")
import numpy as np, shen_clips as SC, shen_lib as L, rig as ZR
for clip in SC.library():
    if not any(n in clip.name for n in sys.argv[1:]): continue
    rg = clip.rig
    print(clip.name)
    for t, local, world, diag, c in clip.bake():
        a = ZR.angle_of(local["RightHand"][:3, :3])
        if a < 100: continue
        S = (world["RightUpperArm"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
        E = (world["RightLowerArm"] @ np.append(rg.JOINT["RightLowerArm"], 1))[:3]
        W = (world["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
        h = L.unit(c["haft"])
        f = L.unit(W - E)
        print("  t %.3f ang %5.1f |S-W| %.2f elbowang %5.1f forearm.haft %5.1f rp-S %s haft %s lhw %.2f" % (t, a, np.linalg.norm(W - S), math.degrees(math.acos(np.clip(L.unit(S-E)@L.unit(W-E),-1,1))), math.degrees(math.acos(np.clip(f @ h, -1, 1))), np.round(np.asarray(c["rp"]) - S, 2), np.round(h, 2), c["lhw"]))

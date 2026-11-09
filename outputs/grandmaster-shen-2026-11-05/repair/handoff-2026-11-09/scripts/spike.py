import sys, math
sys.path.insert(0, "tools/animation/opening_cast")
import numpy as np, shen_clips as SC, shen_lib as L, rig as ZR
clip = [c for c in SC.library() if c.name.endswith(sys.argv[1])][0]
rg = clip.rig
lo, hi = float(sys.argv[2]), float(sys.argv[3])
for t, local, world, diag, c in clip.bake():
    if not lo <= t <= hi: continue
    S = (world["RightUpperArm"] @ np.append(rg.JOINT["RightUpperArm"], 1))[:3]
    E = (world["RightLowerArm"] @ np.append(rg.JOINT["RightLowerArm"], 1))[:3]
    W = (world["RightHand"] @ np.append(rg.JOINT["RightHand"], 1))[:3]
    print("t %.3f ang %5.1f rp %s haft %s elbow %s pole %s roll %.1f hand %s" % (t, ZR.angle_of(local["RightHand"][:3, :3]), np.round(c["rp"], 2), np.round(L.unit(c["haft"]), 2), np.round(E - S, 2), np.round(c.get("rpole", c["relb"]), 2), c.get("rpole_roll", 0), np.round(ZR.quat(c["rhand"]), 2)))

import sys, os, time, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_P2_Guandao_L3")
rg = clip.rig
c = clip.controls(clip.frames()[6]); clip._side = {}
_, world, _ = clip.solve(dict(c))
pose = {p: (world[p][:3, :3], (world[p] @ np.append(rg.JOINT[p], 1))[:3]) for p in ("RightUpperArm", "RightLowerArm", "RightHand", "UpperTorso", "LowerTorso")}
for st in (3, 6, 9):
    t0 = time.time()
    for _ in range(50): d = L.arm_torso_pose(rg, "Right", pose, stride=st)
    print("stride", st, "ms", round((time.time() - t0) / 50 * 1000, 2), "depth", round(d, 3), "world", round(L.arm_torso_world(rg, world)["Right"], 3))
print({p: len(rg.SKIN[p][0]) for p in ("RightUpperArm", "RightLowerArm", "RightHand")})

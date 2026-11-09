import sys, os
sys.path.insert(0, "tools/animation/opening_cast")
import numpy as np, shen_clips as SC, shen_lib as L, rig as ZR
clip = [c for c in SC.library() if c.name.endswith(sys.argv[1])][0]
for t, local, world, diag, c in clip.bake():
    a = ZR.angle_of(local["LeftHand"][:3, :3])
    if a > float(os.environ.get("AMIN", 100)) or diag.get("left_grip", 0) > 0.2:
        print("t %.3f L %5.1f R %5.1f lhw %.2f ltw %.2f grip %.2f gap %.2f lsl %.2f" % (t, a, ZR.angle_of(local["RightHand"][:3, :3]), c["lhw"], c["ltw"], diag.get("left_grip", 0), c.get("_lgap", 0), c.get("_lsl", 0)))

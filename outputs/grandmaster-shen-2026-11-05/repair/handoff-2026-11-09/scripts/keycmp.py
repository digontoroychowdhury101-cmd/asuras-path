import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
nm = sys.argv[1]
lib = {c.name: c for c in SC.library()}
cl = [lib["GrandmasterShen_P%d_%s" % (p, nm)] for p in (1, 2)]
for i, t in enumerate(cl[0].frames()):
    row = []
    for clip in cl:
        rg = clip.rig
        c = clip.controls(t)
        clip._side = {}; _l, world, diag = clip.solve(c); clip._side = None
        d = L.arm_torso_world(rg, world)
        ut = world["UpperTorso"]; at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
        fist = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
        q = (fist - at) @ ut[:3, :3]; qk = (np.asarray(c["rp"]) - at) @ ut[:3, :3]
        h = np.asarray(c["haft"]) @ ut[:3, :3]
        row.append("R%.2f L%.2f key%s got%s h%s lhw%.1f ltw%.1f" % (d["Right"], d["Left"], np.round(qk, 2), np.round(q, 2), np.round(h, 1), c["lhw"], c["ltw"]))
    print("f%-2d P1 %s\n    P2 %s" % (i, row[0], row[1]))

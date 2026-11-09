import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
want = sys.argv[1:]
for clip in SC.library():
    nm = clip.name.replace("GrandmasterShen_", "")
    if want and nm not in want: continue
    rg = clip.rig; rows = []
    mr = ml = 0.0
    for i, t in enumerate(clip.frames()):
        c = clip.controls(t)
        clip._side = {}; _l, world, _d = clip.solve(c); clip._side = None
        d = L.arm_torso_world(rg, world)
        ut = world["UpperTorso"]; at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
        q = (np.asarray(c["rp"]) - at) @ ut[:3, :3]
        mr, ml = max(mr, d["Right"]), max(ml, d["Left"])
        if max(d.values()) > 0.18: rows.append("f%d %.2f/%.2f fist%s" % (i, d["Right"], d["Left"], np.round(q, 2)))
    print("%-26s keyed max R %.2f L %.2f | %s" % (nm, mr, ml, " ; ".join(rows[:8])), flush=True)

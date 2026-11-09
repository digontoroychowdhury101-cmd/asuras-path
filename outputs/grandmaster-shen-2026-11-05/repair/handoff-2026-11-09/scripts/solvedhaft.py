import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig
cs = pickle.load(open("' + (__import__('os').environ.get('SHEN_SCRATCH') or ROOT + '/work/shen_repair') + '/bake_%s.pkl" % name, "rb"))
for i, c in enumerate(cs):
    local, world, diag = clip.solve(dict(c))
    ut = world["UpperTorso"]; at = (ut @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
    h = np.asarray(c["haft"]) @ ut[:3, :3]
    print("f%-2d haft chest %s rsl %.2f lsl %.2f rp-chest %s" % (i, np.round(h, 2), c["rsl"], c["lsl"], np.round((np.asarray(c["rp"]) - at) @ ut[:3, :3], 2)))

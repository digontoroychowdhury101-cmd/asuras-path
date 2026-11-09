import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
S = os.path.dirname(os.path.abspath(__file__)); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, rng = sys.argv[1], sys.argv[2]; pk = sys.argv[3] if len(sys.argv) > 3 else S + "/baked_dp6/" + name + ".pkl"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
out = pickle.load(open(pk, "rb"))
a, b = [int(x) for x in rng.split(":")]
for i in range(a, b):
    t, local, world, diag, c = out[i]; k = clip.controls(t)
    tor = L.arm_torso_world(clip.rig, world)
    print("f%d t%.2f rpK %s hK %s | rpF %s hF %s rsl %.2f/%.2f lhw %.2f ltw %.2f | R %.2f L %.2f" % (i, t, np.round(k["rp"], 2), np.round(L.unit(k["haft"]), 2), np.round(c["rp"], 2), np.round(L.unit(c["haft"]), 2), k["rsl"], c["rsl"], c["lhw"], c["ltw"], tor["Right"], tor["Left"]))

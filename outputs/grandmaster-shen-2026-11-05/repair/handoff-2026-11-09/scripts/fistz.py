import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
times = clip.frames(); keyed = [clip.controls(t) for t in times]
out = clip.bake(); rg = clip.rig
pickle.dump([o[4] for o in out], open("' + (__import__('os').environ.get('SHEN_SCRATCH') or ROOT + '/work/shen_repair') + '/bake_%s.pkl" % name, "wb"))
for i, o in enumerate(out):
    world, c = o[2], o[4]
    Wt = world["UpperTorso"]; at = (Wt @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
    fist = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]; q = (fist - at) @ Wt[:3, :3]
    palm = (world["LeftHand"] @ np.append(rg.PALM0, 1))[:3]; ql = (palm - at) @ Wt[:3, :3]
    d = L.arm_torso_world(rg, world)
    print("f%-2d chest key %4.0f now %4.0f | pel key %4.0f now %4.0f | fist chest %s lead %s | torso R %.2f L %.2f | lhw %.2f" % (i, keyed[i]["chest"][1], c["chest"][1], keyed[i]["pelR"][1], c["pelR"][1], np.round(q, 2), np.round(ql, 2), d["Right"], d["Left"], c["lhw"]))

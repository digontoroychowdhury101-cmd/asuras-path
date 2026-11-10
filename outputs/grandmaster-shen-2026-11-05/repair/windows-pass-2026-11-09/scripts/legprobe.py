# legprobe.py BAKED.pkl CLIP F0 F1 : (Windows pass 2026-11-10) where the weapon sits in his legs on a saved bake (the out list: t, local, world,
# diag, controls), frame by frame F0..F1: the deepest weapon point in each leg solid (as the validator's weapon_in_legs measures it, every sample),
# its place along the haft from the right fist's grip (s, rig units: negative = the butt behind the fist, between 0 and the lead hand = the wood
# between the hands), the lead hand's s, and which way out of the leg is shortest (the leg solid's local axes in his frame). Diagnostics only.
import os, sys, pickle
import numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L

out = pickle.load(open(sys.argv[1], "rb"))
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + sys.argv[2])
rg = clip.rig
f0, f1 = int(sys.argv[3]), int(sys.argv[4])
for i in range(max(0, f0), min(len(out) - 1, f1) + 1):
    t, local, world, diag, c = out[i]
    P = L.place(rg, world, "Weapon")
    fist = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
    palm = (world["LeftHand"] @ np.append(rg.PALM0, 1))[:3]
    ax = L.unit(np.asarray(c["haft"], float))
    s_all = (P - fist) @ ax
    rows = []
    for part in L.LEG_SOLIDS:
        Rw = world[part][:3, :3]
        at = (world[part] @ np.append(rg.JOINT[part], 1))[:3]
        d = L.part_depth(rg, part, Rw, at, P)
        k = int(np.argmax(d))
        if d[k] > 0.01:
            inside = d > 0.01
            rows.append("%s %.3f (%d pts, s %.2f..%.2f, deepest s %.2f at (%+.2f %+.2f %+.2f) joint (%+.2f %+.2f %+.2f))" % (
                part, d[k], int(inside.sum()), s_all[inside].min(), s_all[inside].max(), s_all[k], *P[k], *at))
    print("f%-3d t %.3f lead s %.2f fist (%+.2f %+.2f %+.2f) haft (%+.2f %+.2f %+.2f) rsl %.2f | %s" % (
        i, t, float((palm - fist) @ ax), *fist, *ax, float(c.get("rsl", 0.0)), "; ".join(rows) or "clear"), flush=True)

import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
S = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, S + "/" + os.environ["DEV"]); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, pk = sys.argv[1], sys.argv[2]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
d = pickle.load(open(pk, "rb")); ctrl = d["ctrl"]; clip._side = d["side"]
n = len(ctrl); floor = float(clip.rig.WCLOUD_S.min()) + L.BUTT_HOLD
need = np.zeros(n)
for i, c in enumerate(ctrl):
    if float(c.get("wfree", 0.0)) > 0.01: continue
    v0 = L.held_clash(clip, c)
    if v0 <= L.CLASH_GRAZE: continue
    best = (v0, 0.0)
    for k in L.FIST_SLIDE:
        if float(c["rsl"]) - k < floor: break
        t2 = dict(c); t2["rsl"] = float(c["rsl"]) - k; v = L.held_clash(clip, t2)
        if v < best[0] - 1e-4: best = (v, k)
        if v <= L.CLASH_GRAZE: break
    need[i] = best[1]
want = np.array([float((need * np.exp(-0.5 * ((np.arange(n) - i) / 2.5) ** 2)).max()) for i in range(n)])
for i, c in enumerate(ctrl):
    if want[i] < 1e-4: continue
    t0 = L.arm_torso(clip, c); v0 = L.held_clash(clip, c)
    t2 = dict(c); t2["rsl"] = max(floor, float(c["rsl"]) - want[i]); t1 = L.arm_torso(clip, t2); v1 = L.held_clash(clip, t2)
    print("f%d need %.2f want %.2f lhw %.2f | before R %.3f L %.3f clash %.3f | slid R %.3f L %.3f clash %.3f" % (i, need[i], want[i], float(c.get("lhw", 0)), t0["Right"], t0["Left"], v0, t1["Right"], t1["Left"], v1))

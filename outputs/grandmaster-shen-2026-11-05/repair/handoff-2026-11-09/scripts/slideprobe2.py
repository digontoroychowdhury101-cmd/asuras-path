"""slideprobe2.py CLIP PKL frames: the right fist slid along the haft by d with the weapon held still (rsl+d, rp to the new spot); lead hand kept (lsl-d) or carried (lsl)"""
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, pkl = sys.argv[1], sys.argv[2]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
ctrl = pickle.load(open(pkl, "rb")); clip._side = {}
rg = clip.rig
for fr in [int(x) for x in sys.argv[3].split(",")]:
    c = dict(ctrl[fr])
    d0 = L.arm_torso(clip, c)
    print("f%d base R%.2f/L%.2f rsl %.2f lsl %.2f lhw %.2f ltw %.2f" % (fr, d0["Right"], d0["Left"], c["rsl"], c["lsl"], c["lhw"], c["ltw"]))
    o = rg.weapon_origin(c["rp"], c["haft"], c["face"], c["rsl"])
    for mode in ("keep", "carry"):
        row = []
        for d in (-0.4, -0.2, 0.2, 0.4, 0.6, 0.8):
            t2 = dict(c); t2["rsl"] = float(c["rsl"]) + d; t2["rp"] = tuple(rg.fist_point(o, c["haft"], c["face"], t2["rsl"]))
            if mode == "keep": t2["lsl"] = float(c["lsl"]) - d
            dd = L.arm_torso(clip, t2); g = L.held_clash(clip, t2)
            row.append("%+.1f:R%.2f/L%.2f g%.2f" % (d, dd["Right"], dd["Left"], g))
        print("  %-5s %s" % (mode, "  ".join(row)))

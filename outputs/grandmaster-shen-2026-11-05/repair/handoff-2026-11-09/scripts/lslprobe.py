# lslprobe.py CLIP FRAMES LSL... : keyed solve of frames with the lead hand's slide (lsl) set; solved fist move and arm-in-torso
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, frs, lsls = sys.argv[1], [int(x) for x in sys.argv[2].split(",")], [float(x) for x in sys.argv[3:]]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
for fr in frs:
    t = clip.frames()[fr]; k = clip.controls(t)
    row = []
    for s in lsls:
        c = dict(k); c["lsl"] = s; clip._side = {}
        w = clip.solve(c)[1]; tor = L.arm_torso_world(clip.rig, w)
        row.append("lsl %.2f: rp moved %.2f R %.2f L %.2f lhw %.2f" % (s, np.linalg.norm(np.asarray(c["rp"]) - np.asarray(k["rp"])), tor["Right"], tor["Left"], c["lhw"]))
    print("f%d keyed lsl %.2f | " % (fr, k["lsl"]) + " | ".join(row))

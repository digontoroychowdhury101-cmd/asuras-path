import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
for name in sys.argv[1:]:
    clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
    out = clip.bake()
    row = []
    for i, o in enumerate(out):
        c = o[4]
        row.append("%d:%.2f/%.2f/%.3f" % (i, c["lhw"], c["ltw"], L.smoothed_arm_clash(clip, dict(c), "Left")))
    print(name, " ".join(row))

# keyroll.py [OVERLAY] : (Windows pass 2026-11-11) every Shen clip's keyed glaive (Clip.controls: haft, and the edge as the face made square to
# it) frame by frame: frames where the keyed edge rolls more than 45 deg about the haft in one frame (the last frame's edge carried onto this
# haft by the least rotation first), or the keyed haft swings more than 60. These are the keys' own turns, before the solver; glaiveturn.py
# measures the exported glaive. OVERLAY: a dir under SHEN_SCRATCH (work/shen_repair) holding shen_clips.py / shen_lib.py to read instead.
import math, os, sys
import numpy as np

ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
S = os.environ.get("SHEN_SCRATCH") or os.path.join(ROOT, "work", "shen_repair")
sys.path.insert(0, os.path.join(ROOT, "tools/animation/general_zhao"))
sys.path.insert(0, os.path.join(ROOT, "tools/animation/opening_cast"))
if len(sys.argv) > 1:
    sys.path.insert(0, os.path.join(S, sys.argv[1]))
import shen_clips as R
import shen_lib as L

count = 0
for c in R.library():
    prev, hits = None, []
    for i, t in enumerate(c.frames()):
        x = c.controls(t)
        if x.get("haft") is None or x.get("face") is None:
            prev = None
            continue
        h = L.unit(x["haft"])
        e = L.orth(L.unit(x["face"]), h)
        if prev is not None:
            ph, pe = prev
            swing = math.degrees(math.acos(max(-1.0, min(1.0, float(ph @ h)))))
            pe = L.short_arc(ph, h) @ pe
            roll = math.degrees(math.atan2(float(np.cross(pe, e) @ h), float(pe @ e)))
            if abs(roll) > 45 or swing > 60:
                hits.append("f%d swing %.0f roll %+.0f" % (i, swing, roll))
        prev = (h, e)
    count += len(hits)
    if hits:
        print("%-30s %s" % (c.name[len("GrandmasterShen_"):], "; ".join(hits)))
print("frames:", count)

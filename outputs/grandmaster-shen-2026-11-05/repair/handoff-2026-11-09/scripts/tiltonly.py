import sys, os, time, pickle, math, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
times = clip.frames(); ctrl = pickle.load(open(sys.argv[2], "rb"))
before = [tuple(c["haft"]) for c in ctrl]
t0 = time.time(); L.tilt_haft(clip, ctrl, times); dt = time.time() - t0
a = [L.held_clash(clip, c) for c in ctrl]
print("tilt %.0fs" % dt)
print("after tilt: ", " ".join("%d:%.3f" % (i, v) for i, v in enumerate(a)))
print("tilt deg:   ", " ".join("%d:%.0f" % (i, math.degrees(math.acos(min(1, float(np.dot(L.unit(before[i]), L.unit(c["haft"]))))))) for i, c in enumerate(ctrl)))
print("haft step:  ", " ".join("%.0f" % math.degrees(math.acos(min(1, float(np.dot(L.unit(ctrl[i]["haft"]), L.unit(ctrl[i-1]["haft"])))))) for i in range(1, len(ctrl))))
print("keyed step: ", " ".join("%.0f" % math.degrees(math.acos(min(1, float(np.dot(L.unit(before[i]), L.unit(before[i-1])))))) for i in range(1, len(ctrl))))

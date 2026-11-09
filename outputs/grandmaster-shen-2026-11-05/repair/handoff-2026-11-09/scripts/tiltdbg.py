import sys, os, time, pickle, numpy as np, math
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
times = clip.frames(); ctrl = [clip.controls(t) for t in times]
L.organic(clip, times, ctrl); L.spine_reach(clip, ctrl)
if clip.floor_body: L.rest_on_floor(clip, ctrl)
L.settle(clip, ctrl); L.swivel(clip, ctrl)
for _ in range(3):
    if not L.wrist_yield(clip, ctrl, passes=1): break
    L.settle(clip, ctrl); L.swivel(clip, ctrl)
L.clear_free_arm(clip, ctrl); L.clear_torso(clip, ctrl, times); L.slide_fist(clip, ctrl)
pickle.dump(ctrl, open(sys.argv[2], "wb"))
t0 = time.time(); b = [L.held_clash(clip, c) for c in ctrl]; dt = (time.time() - t0) / len(ctrl)
print("held_clash %.3fs/call" % dt)
print("before tilt:", " ".join("%d:%.3f" % (i, v) for i, v in enumerate(b) if v > 0.005))
before = [tuple(c["haft"]) for c in ctrl]
L.tilt_haft(clip, ctrl, times)
a = [L.held_clash(clip, c) for c in ctrl]
print("after tilt: ", " ".join("%d:%.3f" % (i, v) for i, v in enumerate(a) if v > 0.005))
print("tilt deg:   ", " ".join("%d:%.0f" % (i, math.degrees(math.acos(min(1, float(np.dot(L.unit(before[i]), L.unit(c["haft"]))))))) for i, c in enumerate(ctrl)))

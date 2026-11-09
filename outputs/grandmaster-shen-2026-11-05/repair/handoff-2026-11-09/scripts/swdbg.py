"""Instrumented swivel: per arm, the raw path's hand turn per frame, the costs, and the frames the repair pass reverted."""
import sys, os, inspect, textwrap, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, lo, hi = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
src = inspect.getsource(L.swivel)
src = src.replace("        Q = smooth_hold(Q, clip.loop)\n",
 "        DBG(hand_side, 'raw', Q, path, costs, live, E)\n        Q = smooth_hold(Q, clip.loop)\n        DBG(hand_side, 'smooth', Q, None, None, live, E)\n")
src = src.replace("            fixed += 1\n", "            fixed += 1\n            print('   repair', hand_side, i, round(smoothed_arm_clash(clip, ctrl[i], hand_side), 3))\n")
src = src.replace("        if fixed:\n", "        DBG(hand_side, 'final', np.array([ZR.quat(c[hkey]) for c in ctrl]), None, None, live, E)\n        if fixed:\n")
def DBG(side, tag, Q, path, costs, live, E):
    v = [float(np.degrees(2 * np.arccos(min(1.0, abs(float(Q[i - 1] @ Q[i])))))) for i in range(1, len(Q))]
    s = " ".join("%3.0f" % v[i - 1] for i in range(max(lo, 1), min(hi, len(Q) - 1) + 1))
    print("  %-5s %-6s turn %s" % (side, tag, s))
    if path is not None:
        print("  %-5s path   %s" % (side, " ".join("%d/%d" % path[i] if i in path else "-" for i in range(lo, hi + 1))))
        print("  %-5s cost   %s" % (side, " ".join("%.0f" % costs[i][path[i]] if i in path else "-" for i in range(lo, hi + 1))))
        print("  %-5s best   %s" % (side, " ".join("%.0f" % costs[i].min() if i in path else "-" for i in range(lo, hi + 1))))
L.DBG = DBG
exec(compile(src, "swivel_dbg", "exec"), L.__dict__)
times = clip.frames(); ctrl = [clip.controls(t) for t in times]
L.organic(clip, times, ctrl); L.spine_reach(clip, ctrl)
if clip.floor_body: L.rest_on_floor(clip, ctrl)
L.settle(clip, ctrl)
print("frames %d..%d" % (lo, hi))
L.swivel(clip, ctrl)
for k in range(3):
    if not L.wrist_yield(clip, ctrl, passes=1): break
    print("-- swivel again"); L.settle(clip, ctrl); L.swivel(clip, ctrl)

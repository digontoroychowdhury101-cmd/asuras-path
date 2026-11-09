import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; F = int(sys.argv[2]) if len(sys.argv) > 2 else 8
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig
def show(tag, ctrl):
    row = []
    for i in range(F):
        c = dict(ctrl[i]); local, world, diag = clip.solve(c)
        ut = world["UpperTorso"]
        h = np.asarray(ctrl[i]["haft"]) @ ut[:3, :3]
        row.append("%+.2f,%+.2f" % (h[0], h[1]))
    print("%-14s %s" % (tag, " ".join(row)), flush=True)
times = clip.frames(); ctrl = [clip.controls(t) for t in times]
show("keyed", ctrl)
L.organic(clip, times, ctrl); show("organic", ctrl)
L.spine_reach(clip, ctrl); show("spine_reach", ctrl)
L.settle(clip, ctrl); show("settle", ctrl)
L.swivel(clip, ctrl); show("swivel", ctrl)
for k in range(3):
    if not L.wrist_yield(clip, ctrl, passes=1): break
    show("wrist_yield%d" % k, ctrl)
    L.settle(clip, ctrl); show("settle%d" % k, ctrl)
    L.swivel(clip, ctrl); show("swivel%d" % k, ctrl)
L.clear_free_arm(clip, ctrl); show("free_arm", ctrl)
L.clear_torso(clip, ctrl, times); show("torso", ctrl)
L.slide_fist(clip, ctrl); show("slide", ctrl)
L.tilt_haft(clip, ctrl, times); show("tilt", ctrl)

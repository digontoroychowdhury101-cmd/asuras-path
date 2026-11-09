# swivtest.py CLIP : the bake's first stages (organic, spine_reach, settle, swivel) and each frame's arm-in-torso after them; DEV honoured
import sys, os, time, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D: sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
t0 = time.time()
times = clip.frames(); ctrl = [clip.controls(t) for t in times]
L.organic(clip, times, ctrl); L.spine_reach(clip, ctrl)
if clip.floor_body: L.rest_on_floor(clip, ctrl)
L.settle(clip, ctrl)
pre = [L.arm_torso(clip, c) for c in ctrl]
L.swivel(clip, ctrl)
post = [L.arm_torso(clip, c) for c in ctrl]
bad = [(i, pre[i]["Right"], pre[i]["Left"], post[i]["Right"], post[i]["Left"]) for i in range(len(ctrl)) if max(post[i].values()) > 0.17 or max(pre[i].values()) > 0.17]
print("%s %.0fs  max pre R %.3f L %.3f | post R %.3f L %.3f" % (name, time.time() - t0, max(p["Right"] for p in pre), max(p["Left"] for p in pre), max(p["Right"] for p in post), max(p["Left"] for p in post)))
print("  " + " ".join("f%d:%.2f/%.2f>%.2f/%.2f" % b for b in bad))

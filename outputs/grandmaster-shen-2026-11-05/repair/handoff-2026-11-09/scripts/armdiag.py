"""Bake one Shen clip as export does and report, per frame, the pipeline's own held_clash and per-arm clash (both weapon clouds)."""
import sys, os, time, json, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast")
os.environ.setdefault("SHEN_DEBUG_FREE", "1")
import shen_clips as SC, shen_lib as L
phase, name = int(sys.argv[1]), sys.argv[2]
t0 = time.time()
clip = [c for c in SC.build(phase) if c.name.endswith("_" + name) or c.name == name][0]
print("clip", clip.name, clip.length)
out = clip.bake()
print("baked %.0fs" % (time.time() - t0))
rg = clip.rig
full = None
rows = []
for k, (t, local, world, diag, c) in enumerate(out):
    hc = L.held_clash(clip, c)
    rows.append((t, hc, L.smoothed_arm_clash(clip, c, "Right"), L.smoothed_arm_clash(clip, c, "Left")))
json.dump(rows, open(sys.argv[3], "w"))
for r in rows[::6]: print("t %.2f held %.3f right %.3f left %.3f" % r)
print("max held %.3f at t %.2f" % max((r[1], r[0]) for r in rows))

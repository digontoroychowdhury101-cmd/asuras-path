import sys
import numpy as np
sys.path.insert(0, "' + (__import__('os').environ.get('SHEN_SCRATCH') or ROOT + '/work/shen_repair') + '/old/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
mode = sys.argv[2]
if "noyield" in mode: L.wrist_yield = lambda clip, ctrl, *a, **k: False
if "settle2" in mode:
    orig = L.settle
    L.settle = lambda clip, ctrl, sigma=2.0, passes=2: orig(clip, ctrl, sigma, 2)
if "nofloor" in mode: L.rest_on_floor = lambda *a, **k: None
clip = [c for c in SC.library() if c.name.endswith(sys.argv[1])][0]
b = clip.bake()
P = np.array([L.wrist_parts(clip.rig, x[1]["LeftHand"][:3, :3], "Left") for x in b])
over = np.mean([L.wrist_excess(clip.rig, x[1]["LeftHand"][:3, :3], "Left") > 1.0 for x in b])
print(sys.argv[1], mode, "L max |tw fl dv|", np.abs(P).max(0).round(0), "over %.0f%%" % (over * 100), flush=True)

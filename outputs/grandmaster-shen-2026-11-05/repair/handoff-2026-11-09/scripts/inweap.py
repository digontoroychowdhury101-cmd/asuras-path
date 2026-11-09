import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; parts = sys.argv[2].split(",")
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
out = clip.bake(); rg = clip.rig
row = []
for i, o in enumerate(out):
    c = dict(o[4]); local, world, diag = clip.solve(c)
    G = world["Glaive"]; pose = L.pose_of(rg, world)
    v = []
    for part in parts:
        W = world[part]
        B = L.body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
        v.append(max(0.0, float(L.weapon_depth_rest(rg, (B - G[:3, 3]) @ G[:3, :3]).max()) - (L.HAND_GRIP if "Hand" in part else 0.0)))
    if max(v) > 0.015: row.append("f%d %.2f/%.2f %s" % (i, c["lhw"], c["ltw"], "/".join("%.3f" % x for x in v)))
print(name, parts, " | ".join(row))

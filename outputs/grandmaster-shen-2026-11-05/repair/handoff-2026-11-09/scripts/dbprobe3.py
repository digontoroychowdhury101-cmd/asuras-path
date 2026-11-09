# dbprobe.py CLIP FRAME : keyed solve of one frame with the fist (rp) moved over a grid; arm-in-torso R/L and grip clash for each
import sys, os, numpy as np, itertools
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D: sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, fr = sys.argv[1], int(sys.argv[2])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
t = clip.frames()[fr]; k = clip.controls(t)
res = []
for dx, dy, dz in itertools.product(tuple(float(x) for x in os.environ.get("GX", "-0.2,0,0.2,0.4").split(",")), tuple(float(x) for x in os.environ.get("GY", "-0.2,0,0.2").split(",")), tuple(float(x) for x in os.environ.get("GZ", "-0.6,-0.4,-0.2,0,0.2").split(","))):
    c = dict(k); c["rp"] = tuple(np.asarray(k["rp"], float) + (dx, dy, dz))
    clip._side = {}
    local, world, diag = clip.solve(dict(c))[:3] if len(clip.solve(dict(c))) >= 3 else (None,) * 3
    w = clip.solve(dict(c))[1]
    tor = L.arm_torso_world(clip.rig, w)
    g = L.held_clash(clip, c)
    res.append((max(tor.values()), dx, dy, dz, tor["Right"], tor["Left"], g))
res.sort(key=lambda r: (round(r[0], 2), abs(r[1]) + abs(r[2]) + abs(r[3])))
print("keyed rp", np.round(k["rp"], 2), "chest", k.get("chest"))
for r in res[:12]: print("d=(%.1f,%.1f,%.1f) R %.2f L %.2f clash %.3f" % r[1:])
base = ([r for r in res if r[1:4] == (0, 0, 0)] or [None])[0]; base and print("base R %.2f L %.2f clash %.3f" % base[4:])

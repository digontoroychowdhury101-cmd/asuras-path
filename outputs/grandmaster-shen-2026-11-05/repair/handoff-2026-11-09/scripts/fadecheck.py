# fadecheck.py BAKEDDIR [CLIP ...] : every clip's boundaries as the shots and the game play them: Idle fading into it over 0.2 s (smoothstep) and it
# fading back into Idle; each arm's depth in his torso on every skin sample (arm_torso_world dense, as validate) on each fade frame, with the old
# world-place blend (cloth_bake.lerp_pose) and the Animator's joint blend (cloth_bake.fade_pose). Clip frames themselves: validate's own number.
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, glob, numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L, cloth_bake as CB
D = sys.argv[1]
names = sys.argv[2:] or sorted(os.path.basename(p)[:-4] for p in glob.glob(D + "/P*.pkl"))
rigs = {}
def worlds(name):
    return [o[2] for o in pickle.load(open("%s/%s.pkl" % (D, name), "rb"))]
FADE, FPS = 0.2, 30
def depth(rg, w):
    t = L.arm_torso_world(rg, w, dense=True); return max(t["Right"], t["Left"])
for name in names:
    if name.endswith("_Idle"): continue
    ph = int(name[1]); rg = rigs.setdefault(ph, L.Rig(ph))
    idle = worlds("P%d_Idle" % ph); W = worlds(name)
    last_idle = idle[min(len(idle) - 1, int(round(0.6 * FPS)) - 1)]
    res = {}
    for how, fn in (("place", lambda a, b, u: CB.lerp_pose(a, b, u)), ("joint", lambda a, b, u: CB.fade_pose(a, b, u, ph))):
        fin = max(depth(rg, fn(last_idle, W[min(i, len(W) - 1)], (i / FPS / FADE) ** 2 * (3 - 2 * i / FPS / FADE))) for i in range(1, int(FADE * FPS)))
        fout = max(depth(rg, fn(W[-1], idle[min(i, len(idle) - 1)], (i / FPS / FADE) ** 2 * (3 - 2 * i / FPS / FADE))) for i in range(1, int(FADE * FPS)))
        res[how] = (fin, fout)
    print("%-24s in place %.3f joint %.3f | out place %.3f joint %.3f%s" % (name, res["place"][0], res["joint"][0], res["place"][1], res["joint"][1],
          "  <-- joint fade past 0.18" if max(res["joint"]) > 0.18 else ""), flush=True)

# fadeprobe.py BAKEDDIR CLIP [CLIP ...] : (Windows pass 2026-11-09) the Idle boundaries fadecheck2.py measures, step by step: for the game's fade
# in (Idle from 0.6 s into the clip's start, linear 0.15 s joint blend at 60 fps) and fade out (the clip's last frame held into Idle from its start),
# the deeper arm (dense, both arms printed) at each step, with both ends' own depths at that time, so a boundary that only inherits a deep end
# reads apart from one the blend itself folds.
import os, sys, pickle
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L

D = sys.argv[1]
rigs = {}


def W(name):
    return [o[2] for o in pickle.load(open("%s/%s.pkl" % (D, name), "rb"))]


def dep(rg, w):
    t = L.arm_torso_world(rg, w, dense=True)
    return t["Right"], t["Left"]


def at(rg, frames, f):
    i = min(int(f), len(frames) - 1)
    return L.joint_mix(rg, frames[i], frames[min(i + 1, len(frames) - 1)], f - int(f))


def steps(rg, A, B, sec):
    n = int(round(sec * 60))
    for i in range(1, n):
        s = i / n
        f = i / 60.0 * 30
        wa, wb = at(rg, A, f), at(rg, B, f)
        yield i, s, dep(rg, wa), dep(rg, wb), dep(rg, L.joint_mix(rg, wa, wb, s))


for name in sys.argv[2:]:
    ph = int(name[1])
    rg = rigs.setdefault(ph, L.Rig(ph))
    idle, X = W("P%d_Idle" % ph), W(name)
    k = int(round(0.6 * 30)) - 1
    for lab, A, B in (("in", idle[k:] + idle[:k], X), ("out", X[-1:] * 12, idle)):
        print("%s fade %s" % (name, lab))
        for i, s, da, db, dm in steps(rg, A, B, 0.15):
            print("  step %d u %.2f  from R %.3f L %.3f | to R %.3f L %.3f | blend R %.3f L %.3f%s" % (i, s, da[0], da[1], db[0], db[1], dm[0], dm[1], "  <--" if max(dm) > 0.18 else ""), flush=True)

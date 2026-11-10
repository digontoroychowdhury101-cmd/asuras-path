# loopout.py BAKEDDIR CLIP [SEC] : (Windows pass 2026-11-09) fadecheck3.py's gait loop-out in detail: the looping gait stopped on each of its
# frames f fades to Idle over SEC (default 0.2 s, BossAnimations' stopGait) while Idle plays on; for each f the deepest arm in his torso during
# the fade (dense, both arms), which arm, at which blend weight, against which Idle frame (the worst of every Idle frame, as Idle's time at the
# stop is unrelated to the gait's), and how deep the gait's own frame and that Idle frame sit.
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L
D, name = sys.argv[1], sys.argv[2]
SEC = float(sys.argv[3]) if len(sys.argv) > 3 else 0.2
ph = int(name[1])
rg = L.Rig(ph)
W = lambda nm: [o[2] for o in pickle.load(open("%s/%s.pkl" % (D, nm), "rb"))]
X, idle = W(name), W("P%d_Idle" % ph)
nx, ni = max(len(X) - 1, 1), max(len(idle) - 1, 1)


def at(frames, n, f):
    i = int(f)
    return L.joint_mix(rg, frames[i % n], frames[(i + 1) % n], f - i)


def dep(w):
    t = L.arm_torso_world(rg, w, dense=True)
    return max((t["Right"], "Right"), (t["Left"], "Left"))


steps = int(round(SEC * 60))
rows = []
for f in range(nx):
    best = (0.0, "", 0.0, 0)
    for g in range(0, ni, 3):
        for s in range(1, steps):
            d, arm = dep(L.joint_mix(rg, at(X, nx, f + s / 2.0), at(idle, ni, g + s / 2.0), s / steps))
            if d > best[0]:
                best = (d, arm, s / steps, g)
    own, idl = dep(X[f])[0], dep(idle[best[3]])[0]
    rows.append((best[0], f))
    print("f%-3d worst %.3f %-5s at weight %.2f vs Idle f%-3d | gait frame %.3f idle frame %.3f" % (f, best[0], best[1], best[2], best[3], own, idl), flush=True)
print("WORST %s loop out %.3f at f%d" % (name, *max(rows)))

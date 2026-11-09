# fadecheck2.py BAKEDDIR [CLIP ...] : each clip's boundaries with Idle, as the game plays them (BossAnimations: a linear 0.15 s fade, joint blend,
# shen_lib.joint_mix) and as the review shots do (0.2 s smoothstep): deepest arm in his torso on every skin sample over each fade, in and out
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, glob
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L
D = sys.argv[1]
names = sys.argv[2:] or sorted(os.path.basename(p)[:-4] for p in glob.glob(D + "/P*.pkl"))
rigs = {}
def W(name, d=D):
    p = "%s/%s.pkl" % (d, name)
    return [o[2] for o in pickle.load(open(p, "rb"))]
def dep(rg, w):
    t = L.arm_torso_world(rg, w, dense=True); return max(t["Right"], t["Left"])
def fade(rg, a_frames, b_frames, sec, smooth):
    n = int(round(sec * 60))     # the game draws at 60
    worst = (0.0, 0)
    for i in range(1, n):
        s = i / n; u = s * s * (3 - 2 * s) if smooth else s
        t = i / 60.0; f = t * 30
        ia = min(int(f), len(a_frames) - 1); ib = min(int(f), len(b_frames) - 1)
        wa = L.joint_mix(rg, a_frames[ia], a_frames[min(ia + 1, len(a_frames) - 1)], f - int(f))
        wb = L.joint_mix(rg, b_frames[ib], b_frames[min(ib + 1, len(b_frames) - 1)], f - int(f))
        d = dep(rg, L.joint_mix(rg, wa, wb, u))
        if d > worst[0]: worst = (d, i)
    return worst
for name in names:
    if name.endswith("_Idle"): continue
    ph = int(name[1]); rg = rigs.setdefault(ph, L.Rig(ph))
    idle = W("P%d_Idle" % ph); X = W(name)
    k = int(round(0.6 * 30)) - 1
    gin = fade(rg, idle[k:] + idle[:k], X, 0.15, False); gout = fade(rg, X[-1:] * 12, idle, 0.15, False)
    sin = fade(rg, idle[k:] + idle[:k], X, 0.2, True)
    flag = "  <-- past 0.18" if max(gin[0], gout[0], sin[0]) > 0.18 else ""
    print("%-24s game in %.3f out %.3f | shot in %.3f%s" % (name, gin[0], gout[0], sin[0], flag), flush=True)

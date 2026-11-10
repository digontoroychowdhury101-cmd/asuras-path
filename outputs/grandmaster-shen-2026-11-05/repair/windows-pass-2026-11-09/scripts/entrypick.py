# entrypick.py BAKEDDIR CLIP SIDE [N] : (Windows pass 2026-11-09) the fade in from Idle (fadecheck2.py: Idle 0.6 s in, linear 0.15 s joint fade at
# 60 fps) with one arm (SIDE) held in one swivel state through the clip's first frames (those the fade reaches, as guard_entry pins them): for
# swivel's N cheapest states at frame 0, the summed swivel cost over those frames, the deepest frame and the deepest fade pose (both arms, dense).
import os, sys, pickle, inspect, textwrap, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L

bdir, name, SIDE = sys.argv[1], sys.argv[2], sys.argv[3]
N = int(sys.argv[4]) if len(sys.argv) > 4 else 30
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig
out = pickle.load(open("%s/%s.pkl" % (bdir, name), "rb"))
idle = [o[2] for o in pickle.load(open("%s/P%s_Idle.pkl" % (bdir, name[1]), "rb"))]
k0 = int(round(0.6 * 30)) - 1
idle_in = idle[k0:] + idle[:k0]
tt = clip.frames()
F = [i for i in range(len(out)) if tt[i] < L.ENTRY_FADE - 1e-9] + [int(L.ENTRY_FADE * 30) + 1]     # the frames the fade samples (f 0..4.5)
F = sorted(set(min(i, len(out) - 1) for i in F))
src = textwrap.dedent(inspect.getsource(L.swivel))
a = "        # (2026-11-07) the lead hand is a loose ring on the haft"
src = src.replace(a, "        if hand_side == SIDE:\n            TAB.update(costs=costs, hands=hands, poles=poles, twists=twists)\n            return\n" + a, 1)
TAB = {}
ns = dict(L.__dict__)
ns.update(TAB=TAB, SIDE=SIDE)
exec(compile(src, "swivel_cost_probe", "exec"), ns)
G16, E = len(L.GRIP_TURNS), len(L.ELBOW_TURNS)
hk, pk = ("rhand", "rpole") if SIDE == "Right" else ("lhand", "lpole")
loop = clip.loop
clip.loop = False
ns["swivel"](clip, [dict(out[i][4]) for i in F])
clip.loop = loop
T = dict(TAB)


def at(frames, f):
    i = min(int(f), len(frames) - 1)
    return L.joint_mix(rg, frames[i], frames[min(i + 1, len(frames) - 1)], f - int(f))


def dep(w):
    t = L.arm_torso_world(rg, w, dense=True)
    return max(t["Right"], t["Left"])


X = [o[2] for o in out]
base_in = max(dep(L.joint_mix(rg, at(idle_in, i / 2.0), at(X, i / 2.0), i / 9.0)) for i in range(1, 9))
print("%s frames %s as baked: fade in %.3f, frames %s" % (name, F, base_in, " ".join("%.3f" % dep(X[i]) for i in F)))
C0 = T["costs"][0]
# STATES="slant,turn,elbow;..." (environment): try these states instead of the N cheapest
want = [tuple(float(v) for v in s.split(",")) for s in os.environ.get("STATES", "").split(";") if s.strip()]
flats = [(L.GRIP_SLANTS.index(s) * G16 + int(round(t / 22.5)) % G16) * E + int(round(el / (360.0 / E))) % E for s, t, el in want] if want else np.argsort(C0, axis=None)[:N]
for flat in flats:
    g, e = divmod(int(flat), E)
    W = list(X)
    clip._side = {}
    try:
        for j, i in enumerate(F):
            c = dict(out[i][4])
            c[hk], c[pk], c[hk + "_slant"], c[pk + "_roll"] = T["hands"][j][g], T["poles"][j][g, e], L.GRIP_SLANTS[g // G16], float(T["twists"][j][g, e])
            W[i] = clip.solve(c)[1]
    finally:
        clip._side = None
    cost = sum(float(T["costs"][j][g, e]) for j in range(len(F)))
    fin = max(dep(L.joint_mix(rg, at(idle_in, i / 2.0), at(W, i / 2.0), i / 9.0)) for i in range(1, 9))
    deep = max(dep(W[i]) for i in F)
    print("slant %+.0f turn %5.1f elbow %5.1f cost %7.1f | frames to %.3f | fade in %.3f%s" % (L.GRIP_SLANTS[g // G16], np.degrees(L.GRIP_TURNS[g % G16]), L.ELBOW_TURNS[e], cost, deep, fin,
                                                                                        "  ok" if max(fin, deep) <= 0.17 else ""), flush=True)

# endpick.py BAKEDDIR CLIP FRAME SIDE [N] : (Windows pass 2026-11-09) for one end frame of a baked clip (0 or -1), swivel's N cheapest grip/elbow
# states for one arm (SIDE), each solved as the export solves that frame, with the frame's own depth (dense, both arms) and the deepest pose of the
# game's 0.15 s joint fade with Idle through it (fade in from Idle 0.6 s in, fade out to Idle's start, the end frame held as fadecheck2 holds it):
# which state an end could hold so its fades with Idle stay clear, and what it costs swivel.
import os, sys, pickle, inspect, textwrap, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L

bdir, name, F, SIDE = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
N = int(sys.argv[5]) if len(sys.argv) > 5 else 30
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
rg = clip.rig
out = pickle.load(open("%s/%s.pkl" % (bdir, name), "rb"))
idle = [o[2] for o in pickle.load(open("%s/P%s_Idle.pkl" % (bdir, name[1]), "rb"))]
k0 = int(round(0.6 * 30)) - 1
idle_in = idle[k0:] + idle[:k0]
src = textwrap.dedent(inspect.getsource(L.swivel))
a = "        # (2026-11-07) the lead hand is a loose ring on the haft"
src = src.replace(a, "        if hand_side == SIDE:\n            TAB.update(costs=costs, hands=hands, poles=poles, twists=twists)\n            return\n" + a, 1)
TAB = {}
ns = dict(L.__dict__)
ns.update(TAB=TAB, SIDE=SIDE)
exec(compile(src, "swivel_cost_probe", "exec"), ns)
G16, E = len(L.GRIP_TURNS), len(L.ELBOW_TURNS)
hk, pk = ("rhand", "rpole") if SIDE == "Right" else ("lhand", "lpole")
F = F % len(out)
c0 = dict(out[F][4])
loop = clip.loop
clip.loop = False
ns["swivel"](clip, [dict(c0)])
clip.loop = loop
C, Hs, Ps, Ts = TAB["costs"][0], TAB["hands"][0], TAB["poles"][0], TAB["twists"][0]


def at(frames, f):
    i = min(int(f), len(frames) - 1)
    return L.joint_mix(rg, frames[i], frames[min(i + 1, len(frames) - 1)], f - int(f))


def dep(w):
    t = L.arm_torso_world(rg, w, dense=True)
    return max(t["Right"], t["Left"])


X = [o[2] for o in out]
for flat in np.argsort(C, axis=None)[:N]:
    g, e = divmod(int(flat), E)
    c = dict(c0)
    c[hk], c[pk], c[hk + "_slant"], c[pk + "_roll"] = Hs[g], Ps[g, e], L.GRIP_SLANTS[g // G16], float(Ts[g, e])
    clip._side = {}
    _l, w, _d = clip.solve(c)
    clip._side = None
    ends = list(X)
    ends[F] = w
    if loop:
        ends[0] = ends[-1] = w
    fin = max(dep(L.joint_mix(rg, at(idle_in, i / 2.0), at(ends, i / 2.0), i / 9.0)) for i in range(1, 9))
    fout = max(dep(L.joint_mix(rg, ends[-1], at(idle, i / 2.0), i / 9.0)) for i in range(1, 9))
    print("slant %+.0f turn %5.1f elbow %5.1f cost %6.1f | frame %.3f | fade in %.3f out %.3f%s" % (L.GRIP_SLANTS[g // G16], np.degrees(L.GRIP_TURNS[g % G16]), L.ELBOW_TURNS[e], C[g, e], dep(w), fin, fout,
                                                                                          "  ok" if max(fin, fout, dep(w)) <= 0.17 else ""), flush=True)

# swcost.py BAKEDDIR CLIP F[,F...] [SIDE] : (Windows pass 2026-11-09) swivel's own cost table for one arm (default Right) on single baked frames,
# as swivel weighs a frame alone (no path): its cheapest grip/elbow states (slant, grip turn, elbow turn, the forearm twist, cost), and which of them
# the bake kept (nearest state to the frame's baked hand and pole), so a clip end that holds the guard unlike Idle can be told from Idle's own choice.
import os, sys, pickle, inspect, textwrap, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L

bdir, name = sys.argv[1], sys.argv[2]
frames = [int(v) for v in sys.argv[3].split(",")]
SIDE = sys.argv[4] if len(sys.argv) > 4 else "Right"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
out = pickle.load(open("%s/%s.pkl" % (bdir, name), "rb"))
src = textwrap.dedent(inspect.getsource(L.swivel))
a = "        # (2026-11-07) the lead hand is a loose ring on the haft"
assert a in src
src = src.replace(a, "        if hand_side == SIDE:\n            TAB.update(costs=costs, hands=hands, poles=poles, twists=twists)\n            return\n" + a, 1)
TAB = {}
ns = dict(L.__dict__)
ns.update(TAB=TAB, SIDE=SIDE)
exec(compile(src, "swivel_cost_probe", "exec"), ns)
G16, E = len(L.GRIP_TURNS), len(L.ELBOW_TURNS)
hk, pk = ("rhand", "rpole") if SIDE == "Right" else ("lhand", "lpole")
clip.loop = False
for f in frames:
    f = f % len(out)
    c = dict(out[f][4])
    TAB.clear()
    ns["swivel"](clip, [dict(c)])
    C = TAB["costs"][0]
    Hs, Ps, Ts = TAB["hands"][0], TAB["poles"][0], TAB["twists"][0]
    # the state the bake kept: nearest grip rotation, then nearest pole
    gk = min(range(len(Hs)), key=lambda g: L.ZR.angle_of(Hs[g].T @ np.asarray(c[hk], float)))
    ek = int(np.argmax(Ps[gk] @ L.unit(np.asarray(c[pk], float))))
    order = np.argsort(C, axis=None)
    rank = int(np.where(order == gk * E + ek)[0][0])
    print("%s f%d baked: slant %+.0f turn %5.1f elbow %5.1f twist %6.1f cost %.1f (rank %d of %d; baked slant %.1f roll %.1f)"
          % (name, f, L.GRIP_SLANTS[gk // G16], np.degrees(L.GRIP_TURNS[gk % G16]), L.ELBOW_TURNS[ek], Ts[gk, ek], C[gk, ek], rank, C.size,
             float(c.get(hk + "_slant", 0)), float(c.get(pk + "_roll", 0))))
    for flat in order[:6]:
        g, e = divmod(int(flat), E)
        print("    slant %+.0f turn %5.1f elbow %5.1f twist %6.1f cost %.1f" % (L.GRIP_SLANTS[g // G16], np.degrees(L.GRIP_TURNS[g % G16]), L.ELBOW_TURNS[e], Ts[g, e], C[g, e]), flush=True)

# swtor.py CLIP CALL F0 F1 [SIDE] : (Windows pass 2026-11-09) at the CALL-th swivel of CLIP, for one arm (SIDE, default Right) on frames F0..F1:
# what swivel's own cost table holds per frame: the cheapest state alone and its cost, the state the walk chose and its cost, and the torso terms
# (tor: the arm per elbow turn with the untilted grip's wrist; htor: the hand per grip) at the keyed elbow, the cheapest and the chosen. Shows
# whether a clip's dear frames are dear for every choice (the hand or arm in him whatever the elbow) or only along the chosen path. SET as
# swpath.py. Writes nothing.
import sys, os, inspect, textwrap, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
os.environ["SHEN_JOINT_POLISH"] = "0"
import shen_clips as SC, shen_lib as L
name, CALL, F0, F1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
SIDE = sys.argv[5] if len(sys.argv) > 5 else "Right"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
for kv in filter(None, os.environ.get("SET", "").split(";")):
    k, v = kv.split("=", 1)
    setattr(clip, k.strip(), eval(v))
src = textwrap.dedent(inspect.getsource(L.swivel))
a = "            costs[i], quats[i], hands[i], poles[i], twists[i] = C, Qi, Hi, Pi, Ti\n"
b = "        path = walk()\n"
assert a in src and b in src
src = src.replace(a, a + "            TLOG.append((hand_side, i, tor.copy(), htor.copy()))\n", 1)
src = src.replace(b, b + "        PLOG.append((hand_side, dict(path), {i: costs[i] for i in live}))\n", 1)
TLOG, PLOG = [], []
ns = dict(L.__dict__)
ns["TLOG"], ns["PLOG"] = TLOG, PLOG
exec(compile(src, "swivel_tor_probe", "exec"), ns)
probe, real, calls = ns["swivel"], L.swivel, [0]


class Stop(Exception):
    pass


def st(g, e):
    G16 = len(L.GRIP_TURNS)
    return "(%+.0f,%5.1f,%6.2f)" % (L.GRIP_SLANTS[g // G16], (g % G16) * 360.0 / G16, L.ELBOW_TURNS[e])


def sw(c_, ctrl, *a, **k):
    calls[0] += 1
    if calls[0] < CALL:
        return real(c_, ctrl, *a, **k)
    probe(c_, ctrl, *a, **k)
    tor = {i: (t, h) for s, i, t, h in TLOG if s == SIDE}
    for s, path, costs in PLOG:
        if s != SIDE:
            continue
        for i in range(F0, F1 + 1):
            if i not in costs:
                print("f%-3d off" % i)
                continue
            C = costs[i]
            g0, e0 = np.unravel_index(int(C.argmin()), C.shape)
            gk = int(C[:, 0].argmin())
            g1, e1 = path[i]
            t, h = tor[i]
            print("f%-3d cheapest %s %6.1f (tor %.2f htor %.2f) | keyed elbow best %s %6.1f (tor %.2f htor %.2f) | chosen %s %6.1f (tor %.2f htor %.2f) | tor min %.2f at %.0f"
                  % (i, st(g0, e0), C[g0, e0], t[e0], h[g0], st(gk, 0), C[gk, 0], t[0], h[gk], st(g1, e1), C[g1, e1], t[e1], h[g1], t.min(), L.ELBOW_TURNS[int(t.argmin())]), flush=True)
    raise Stop


L.swivel = sw
try:
    clip.bake()
except Stop:
    pass

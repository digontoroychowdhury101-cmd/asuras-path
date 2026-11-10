# swparts.py CLIP CALL F0 F1 [SIDE] : (Windows pass 2026-11-09) swtor.py's frames split into swivel's cost terms. At the CALL-th swivel of CLIP,
# for one arm (SIDE, default Right) on frames F0..F1: the cheapest state and the walk's chosen state with each term of their cost (arm in the
# weapon: clash; wrist bend; wrist_cost past its limits; elbow in his ribs: inside; reach shortfall: x; torso), and the least clash and least
# wrist_cost any state on that frame has, so a frame dear for every choice shows what makes it so. SET as swpath.py. Writes nothing.
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
lines = src.split("\n")
k = next(j for j, ln in enumerate(lines) if ln.lstrip().startswith("C[g, e] = CLASH_COST"))
ind = lines[k][:len(lines[k]) - len(lines[k].lstrip())]
lines.insert(k + 1, ind + "XL.setdefault((hand_side, i), {})[(g, e)] = (clash, bend, wrist_cost(wp), inside, scratch['x'], torso_cost(max(tor[e], htor[g])), float(C[g, e]))")
src = "\n".join(lines)
b = "        path = walk()\n"
assert b in src
src = src.replace(b, b + "        PLOG.append((hand_side, dict(path)))\n", 1)
XL, PLOG = {}, []
ns = dict(L.__dict__)
ns["XL"], ns["PLOG"] = XL, PLOG
exec(compile(src, "swivel_parts_probe", "exec"), ns)
probe, real, calls = ns["swivel"], L.swivel, [0]


class Stop(Exception):
    pass


def st(g, e):
    G16 = len(L.GRIP_TURNS)
    return "(%+.0f,%5.1f,%6.2f)" % (L.GRIP_SLANTS[g // G16], (g % G16) * 360.0 / G16, L.ELBOW_TURNS[e])


def terms(t):
    return "clash %.3f bend %5.1f wrist %6.1f inside %.2f x %.2f torso %6.1f = %7.1f" % t


def sw(c_, ctrl, *a, **k):
    calls[0] += 1
    if calls[0] < CALL:
        return real(c_, ctrl, *a, **k)
    probe(c_, ctrl, *a, **k)
    for s, path in PLOG:
        if s != SIDE:
            continue
        for i in range(F0, F1 + 1):
            tab = XL.get((SIDE, i))
            if not tab:
                print("f%-3d off" % i)
                continue
            cheap = min(tab, key=lambda q: tab[q][6])
            print("f%-3d cheapest %s %s" % (i, st(*cheap), terms(tab[cheap])))
            if i in path:
                print("     chosen   %s %s" % (st(*path[i]), terms(tab[path[i]])))
            mc = min(tab, key=lambda q: tab[q][0])
            mw = min(tab, key=lambda q: tab[q][2])
            print("     least clash %s %s" % (st(*mc), terms(tab[mc])))
            print("     least wrist %s %s" % (st(*mw), terms(tab[mw])), flush=True)
    raise Stop


L.swivel = sw
try:
    clip.bake()
except Stop:
    pass

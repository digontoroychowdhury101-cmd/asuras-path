# swpath.py CLIP CALL [SIDE] : (Windows pass 2026-11-09) bake CLIP up to its CALL-th swivel and print the path that swivel's walk chose for one arm
# (SIDE, default Left), per frame: live or not, (grip, elbow) state as (slant, turn, elbow turn), its cost, and the pins applied. SET="attr=value;..."
# (environment) sets Clip opt-ins first (e.g. SET="hold_end={'Left': (-20.0, 270.0, 0.0)}"). Writes nothing.
import sys, os, inspect, textwrap, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D:
    sys.path.insert(0, (os.environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair") + "/" + D)
os.chdir(ROOT)
os.environ["SHEN_JOINT_POLISH"] = "0"
import shen_clips as SC, shen_lib as L
name, CALL = sys.argv[1], int(sys.argv[2])
SIDE = sys.argv[3] if len(sys.argv) > 3 else "Left"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
for kv in filter(None, os.environ.get("SET", "").split(";")):
    k, v = kv.split("=", 1)
    setattr(clip, k.strip(), eval(v))
print("hold_start", clip.hold_start, "hold_end", clip.hold_end, "hold_entry", clip.hold_entry)
src = textwrap.dedent(inspect.getsource(L.swivel))
a = "        path = walk()\n"
assert a in src
src = src.replace(a, a + "        LOG.append((hand_side, n, list(live), dict(path), {i: costs[i] for i in live}, dict(pinned)))\n", 1)
LOG = []
ns = dict(L.__dict__)
ns["LOG"] = LOG
exec(compile(src, "swivel_path_probe", "exec"), ns)
probe = ns["swivel"]
real = L.swivel
calls = [0]


class Stop(Exception):
    pass


def sw(c_, ctrl, *a, **k):
    calls[0] += 1
    if calls[0] < CALL:
        return real(c_, ctrl, *a, **k)
    probe(c_, ctrl, *a, **k)
    G16, E = len(L.GRIP_TURNS), len(L.ELBOW_TURNS)
    for side, n, live, path, costs, pinned in LOG:
        if side != SIDE:
            continue
        print(side, "frames", n, "live", live[0] if live else None, "..", live[-1] if live else None, "(%d)" % len(live), "pinned", pinned)
        for i in range(n):
            if i not in path:
                print("f%-3d off" % i)
                continue
            g, e = path[i]
            print("f%-3d slant %+.0f turn %5.1f elbow %6.2f cost %7.1f" % (i, L.GRIP_SLANTS[g // G16], (g % G16) * 360.0 / G16, L.ELBOW_TURNS[e], float(costs[i][g, e])))
    raise Stop


L.swivel = sw
try:
    clip.bake()
except Stop:
    pass

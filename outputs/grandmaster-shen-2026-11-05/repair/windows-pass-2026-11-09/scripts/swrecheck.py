# swrecheck.py CLIP CALL F0 F1 [SIDE] : (Windows pass 2026-11-09) bake CLIP up to its CALL-th swivel and run that swivel with its two post-passes
# exposed for one arm (SIDE, default Left): where the smoothing was undone toward the path's own choice (clash or torso), and where the torso
# recheck swapped a frame's choice (and half of its neighbours') for another of its cheapest states: frame, depth before/after, the path's
# state and twist, the swapped-in state and twist. Then each frame's wrist angle and pole after the call. Writes nothing.
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
SIDE = sys.argv[5] if len(sys.argv) > 5 else "Left"
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
for kv in filter(None, os.environ.get("SET", "").split(";")):     # SET="run_recheck=True;...": Clip opt-ins to try
    k, v = kv.split("=", 1)
    setattr(clip, k.strip(), eval(v))
src =textwrap.dedent(inspect.getsource(L.swivel))
a1 = "            fixed += 1\n"
a2 = "            _, g, e = pick\n"
assert a1 in src and a2 in src
src = src.replace(a1, a1 + "            LOG.append(('unsmooth', hand_side, i))\n", 1)
src = src.replace(a2, a2 + "            LOG.append(('recheck', hand_side, i, round(d, 3), round(pick[0], 3), path.get(i), round(float(twists[i][path[i]]), 1) if i in path else None, (g, e), round(float(twists[i][g, e]), 1)))\n", 1)
LOG = []
ns = dict(L.__dict__)
ns["LOG"] = LOG
exec(compile(src, "swivel_recheck_probe", "exec"), ns)
probe_swivel = ns["swivel"]
real = L.swivel
calls = [0]


class Stop(Exception):
    pass


def sw(c_, ctrl, *a, **k):
    calls[0] += 1
    if calls[0] < CALL:
        return real(c_, ctrl, *a, **k)
    probe_swivel(c_, ctrl, *a, **k)
    for row in LOG:
        if row[1] == SIDE and F0 - 3 <= row[2] <= F1 + 3:
            print(row)
    keep = clip._side
    clip._side = {}
    try:
        for f in range(F0, F1 + 1):
            loc = clip.solve(dict(ctrl[f]))[0]
            pk = "lpole" if SIDE == "Left" else "rpole"
            print("f%d wrist %.0f pole %s roll %.1f" % (f, L.ZR.angle_of(loc[SIDE + "Hand"][:3, :3]), np.round(ctrl[f].get(pk, ctrl[f].get("lelb")), 2).tolist(), float(ctrl[f].get(pk + "_roll", 0.0))))
    finally:
        clip._side = keep
    raise Stop


L.swivel = sw
try:
    clip.bake()
except Stop:
    pass

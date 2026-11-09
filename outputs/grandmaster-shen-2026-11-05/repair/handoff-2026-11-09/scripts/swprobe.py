# swprobe.py CLIP CALL F0 F1 : bake CLIP up to its CALL-th swivel; run that swivel with its left-arm state table exposed: on F0..F1 the chosen
# (grip, elbow) state's own cost against the cheapest state's, the lead wrist parts of each, and the step walls the chosen path pays
import sys, os, inspect, textwrap, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
os.environ["SHEN_JOINT_POLISH"] = "0"
import shen_clips as SC, shen_lib as L
name, CALL, F0, F1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
src = textwrap.dedent(inspect.getsource(L.swivel))
src = src.replace("        path = walk()\n", "        path = walk()\n        PROBE[hand_side] = dict(costs=costs, quats=quats, poles=poles, twists=twists, rels=rels, path=dict(path), live=list(live), E=E, step_cost=step_cost, grip_step=grip_step, elbow_step=elbow_step, roll_step=roll_step, turn_cost=turn_cost)\n", 1)
PROBE = {}
ns = dict(L.__dict__); ns["PROBE"] = PROBE
exec(compile(src, "swivel_probe", "exec"), ns)
probe_swivel = ns["swivel"]
real = L.swivel; calls = [0]
class Stop(Exception): pass
def sw(c_, ctrl, *a, **k):
    calls[0] += 1
    if calls[0] < CALL:
        return real(c_, ctrl, *a, **k)
    r = probe_swivel(c_, ctrl, *a, **k)
    P = PROBE["Left"]; E = P["E"]; path = P["path"]
    for i in range(F0, F1 + 1):
        if i not in path: print(i, "not live"); continue
        C = P["costs"][i]; g, e = path[i]; gb, eb = np.unravel_index(int(C.argmin()), C.shape)
        print("f%d chosen g%d e%d cost %.0f twist %.0f | cheapest g%d e%d cost %.0f twist %.0f" % (i, g, e, C[g, e], P["twists"][i][g, e], gb, eb, C[gb, eb], P["twists"][i][gb, eb]))
        if i - 1 in path:
            gp, ep = path[i - 1]
            qa, qb = P["quats"][i - 1][gp], P["quats"][i][g]
            Tg = np.degrees(2 * np.arccos(min(1.0, abs(float(qa @ qb)))))
            Te = np.degrees(np.arccos(np.clip(P["poles"][i - 1][gp, ep] @ P["poles"][i][g, e], -1, 1)))
            Tr = abs(P["twists"][i - 1][gp, ep] - P["twists"][i][g, e])
            print("    step from f%d: grip turn %.0f (wall %.0f) elbow %.0f (wall %.0f) roll %.0f (wall %.0f)" % (i - 1, Tg, P["grip_step"], Te, P["elbow_step"], Tr, P["roll_step"]))
    raise Stop
L.swivel = sw
try: clip.bake()
except Stop: pass

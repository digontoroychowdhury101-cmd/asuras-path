import sys, math, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_lib as L, shen_clips as SC
from shen_lib import *
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name.endswith(name))
baked = clip.bake()
rg = clip.rig
for idx, (t, local, world, diag, c) in enumerate(baked):
    ex = L.wrist_excess(rg, local["LeftHand"][:3, :3], "Left")
    if "_lgrip" not in c: continue
    S_, grip, axis, core = c["_lgrip"]
    best = (9e9, None)
    clash_best = 9.0
    P, _ = L.weapon_cloud(rg, c)
    for g in range(len(GRIP_TURNS) * len(GRIP_SLANTS)):
        slant = GRIP_SLANTS[g // len(GRIP_TURNS)]
        Rh = rodrigues(axis * GRIP_TURNS[g % len(GRIP_TURNS)]) @ short_arc(slanted(rg, rg.LAX0, "Left", slant), axis)
        wrist = grip - Rh @ (rg.PALM0 - rg.JOINT["LeftHand"])
        d = unit(wrist - S_); keyed = orth(unit(c["lpole"]), d); side = np.cross(d, keyed)
        for a in ELBOW_TURNS:
            ar = math.radians(a); pole = keyed * math.cos(ar) + side * math.sin(ar); sc = {"x": 0.0}
            ru, rl, reached = two_bone(S_, wrist, rg.LARM_U, rg.LARM_L, rg.LELBOW0, pole, "x", sc)
            if sc["x"] > 0.02: continue
            elbow = S_ + ru @ rg.LARM_U; f = unit(reached - elbow)
            A = Rh @ rl.T; phi = float(np.clip(twist_about(A, f), -ROLL_LIMIT, ROLL_LIMIT))
            rr = rodrigues(f * math.radians(phi)) @ rl
            e = L.wrist_excess(rg, rr.T @ Rh, "Left")
            cl = L.arm_clash(rg, "Left", S_, elbow, reached, P, ru, rr)
            if e < best[0]: best = (e, (g, a, cl))
            if e < 1: clash_best = min(clash_best, cl)
    if ex > 1 or idx % 4 == 0:
        print("   lhw %.2f ltw %.2f" % (c["lhw"], c["ltw"]), end=" ")
        print("t %.2f chosen excess %5.1f | best reachable excess %5.1f (clash there %.3f) | least clash among in-range %.3f | rsl %.2f lsl %.2f" % (t, ex, best[0], best[1][2] if best[1] else -1, clash_best, c["rsl"], c.get("_lsl", c["lsl"])))

"""For a clip's frames: each held arm's torso depth as solved, and the least over every elbow turn with the chosen grip (can the swivel clear it?)."""
import sys, os, math, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; frames = [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
out = clip.bake(); rg = clip.rig
free = {}
def torso_depth(side, ru, S, rl, elbow, Rh, wrist, chest, pelvis):
    pose = {side + "UpperArm": (ru, S), side + "LowerArm": (rl, elbow), side + "Hand": (Rh, wrist), "UpperTorso": chest, "LowerTorso": pelvis}
    best = {}
    for part, R, A in ((side + "UpperArm", ru, S), (side + "LowerArm", rl, elbow), (side + "Hand", Rh, wrist)):
        B = L.body_points(rg, part, R, A, pose)
        for t, (Rt, At) in (("UpperTorso", chest), ("LowerTorso", pelvis)):
            k = (part, t)
            if k not in free: free[k] = L.sdf_depth(rg, t, rg.SKIN[part][0]) < -0.05
            d = L.part_depth(rg, t, Rt, At, B[free[k]])
            best[part] = max(best.get(part, 0.0), float(d.max()) if len(d) else 0.0)
    return best
for i in frames:
    c = dict(out[i][4]); clip._side = {}; local, world, diag = clip.solve(c); clip._side = None
    pel = (world["LowerTorso"][:3, :3], (world["LowerTorso"] @ np.append(rg.JOINT["LowerTorso"], 1))[:3])
    chest = c["_chest"]
    for side in ("Right", "Left"):
        ru, rl, Rh = world[side + "UpperArm"][:3, :3], world[side + "LowerArm"][:3, :3], world[side + "Hand"][:3, :3]
        S, el, wr = [(world[k] @ np.append(rg.JOINT[k], 1))[:3] for k in (side + "UpperArm", side + "LowerArm", side + "Hand")]
        now = torso_depth(side, ru, S, rl, el, Rh, wr, chest, pel)
        line = "f%d %s now %s" % (i, side, {k[len(side):]: round(v, 3) for k, v in now.items()})
        gkey = "_rgrip" if side == "Right" else "_lgrip"
        if gkey in c:
            S2, grip, axis, core = c[gkey]
            u0, l0, pole0 = (rg.ARM_U, rg.ARM_L, rg.ELBOW0) if side == "Right" else (rg.LARM_U, rg.LARM_L, rg.LELBOW0)
            d = L.unit(wr - S2); base = L.orth(L.unit(c["relb" if side == "Right" else "lelb"]), d); sd = np.cross(d, base)
            res = []
            for a in L.ELBOW_TURNS:
                ar = math.radians(a); pole = base * math.cos(ar) + sd * math.sin(ar)
                ru2, rl2, reached = L.two_bone(S2, wr, u0, l0, pole0, pole, "x", {})
                el2 = S2 + ru2 @ u0
                f = L.unit(reached - el2); phi = float(np.clip(L.twist_about(Rh @ rl2.T, f), -L.ROLL_LIMIT, L.ROLL_LIMIT)); rr = L.rodrigues(f * math.radians(phi)) @ rl2
                dd = torso_depth(side, ru2, S2, rr, el2, Rh, wr, chest, pel)
                res.append((round(max(dd.values()), 3), int(a)))
            line += " | elbow turns " + " ".join("%d:%.2f" % (a, v) for v, a in res)
        print(line)

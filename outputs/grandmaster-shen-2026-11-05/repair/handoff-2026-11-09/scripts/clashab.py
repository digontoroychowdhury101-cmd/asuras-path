import sys, time, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
cost = float(sys.argv[1]); names = sys.argv[2:]
L.CLASH_COST = cost
for clip in SC.library():
    if names and not any(clip.name.endswith(n) for n in names):
        continue
    t0 = time.time(); baked = clip.bake(); w, probs = L.validate(clip, baked)
    rg = clip.rig
    share = {"arms": 0, "torso": 0}
    for t, local, world, diag, c in baked:
        P = L.place(rg, world, "Weapon")[::6]
        a = 0.0
        for side in ("Right", "Left"):
            j = [(world[k] @ np.append(rg.JOINT[k], 1))[:3] for k in (side + "UpperArm", side + "LowerArm", side + "Hand")]
            a = max(a, L.arm_clash(rg, side, j[0], j[1], j[2], P, world[side + "UpperArm"][:3, :3], world[side + "LowerArm"][:3, :3]))
        tr = max(float(L.part_depth(rg, p, world[p][:3, :3], (world[p] @ np.append(rg.JOINT[p], 1))[:3], P).max()) for p in L.BODY_SOLIDS)
        share["arms"] += a > 0.03; share["torso"] += tr > 0.03
    n = len(baked)
    print("%-34s arms R %.3f L %.3f %3.0f%% | torso %.3f %3.0f%% legs %.3f | wrist over L/R %s | %s %.0fs" % (clip.name, w.get("weapon_in_arm_right", 0), w.get("weapon_in_arm_left", 0), 100 * share["arms"] / n,
          w.get("weapon_in_torso", 0), 100 * share["torso"] / n, w.get("weapon_in_legs", 0),
          "%.0f/%.0f%%" % tuple(100 * np.mean([L.wrist_excess(rg, b[1][s + "Hand"][:3, :3], s) > 1 for b in baked]) for s in ("Left", "Right")), probs, time.time() - t0), flush=True)

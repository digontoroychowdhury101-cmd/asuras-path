import sys, time, numpy as np, os
os.environ["SHEN_DEBUG_FREE"] = "1"
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = [c for c in SC.library() if c.name.endswith(name)][0]
t0 = time.time(); baked = clip.bake(); rg = clip.rig
w, probs = L.validate(clip, baked)
print(name, {k: round(v, 3) for k, v in w.items() if "weapon" in k}, probs, "%.0fs" % (time.time() - t0))
for s in ("Right", "Left"):
    ex = [L.wrist_excess(rg, b[1][s + "Hand"][:3, :3], s) for b in baked]
    print(s, "wrist past range: share %.0f%% max %.1f deg" % (100 * np.mean(np.array(ex) > 1), max(ex)))
worst = (0, None)
for t, local, world, diag, c in baked:
    G = world["Glaive"]; pose = L.pose_of(rg, world)
    for part in L.BODY_SOLIDS:
        W = world[part]; B = L.body_points(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], pose)
        d = L.weapon_depth_rest(rg, (B - G[:3, 3]) @ G[:3, :3]); i = int(np.argmax(d))
        if d[i] > worst[0]:
            P, mix = rg.SKIN[part]
            worst = (float(d[i]), (round(t, 2), part, [(b, round(float(wv[i]), 2)) for b, wv in mix if wv[i] > 0.01], round(float(((B[i] - G[:3, 3]) @ G[:3, :3] - rg.WGRIP) @ rg.HAFT0), 2)))
print("deepest torso skin in weapon", round(worst[0], 3), worst[1])
print("tilt", getattr(clip, "_haft_tilted", None), "slide", getattr(clip, "_fist_slid", None), "free", getattr(clip, "_free_arm_cleared", None))
print("tilt", getattr(clip, "_haft_tilted", None), "slide", getattr(clip, "_fist_slid", None), "free", getattr(clip, "_free_arm_cleared", None))
for t, local, world, diag, c in baked:
    a = float(L.ZR.angle_of(local["RightHand"][:3, :3]))
    if a > 115: print("t %.2f right wrist %.0f rsl %.2f" % (t, a, c["rsl"]))

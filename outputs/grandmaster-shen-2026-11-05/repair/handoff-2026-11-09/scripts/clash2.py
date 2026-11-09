import sys, time, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
names = sys.argv[1:]
for clip in SC.library():
    if names and not any(clip.name.endswith(n) for n in names):
        continue
    t0 = time.time(); baked = clip.bake(); w, probs = L.validate(clip, baked)
    keys = ["weapon_in_arm_right", "weapon_in_arm_left", "in_weapon_arm_right", "in_weapon_arm_left", "in_weapon_hands", "weapon_in_torso", "in_weapon_torso", "weapon_in_legs", "in_weapon_legs"]
    rg = clip.rig
    wr = "%.0f/%.0f%%" % tuple(100 * np.mean([L.wrist_excess(rg, b[1][s + "Hand"][:3, :3], s) > 1 for b in baked]) for s in ("Left", "Right"))
    print("%-30s %s | wrist L/R %s | %s %.0fs" % (clip.name, " ".join("%s %.3f" % (k.replace("weapon", "w").replace("_arm", ""), w.get(k, 0)) for k in keys), wr, probs, time.time() - t0), flush=True)

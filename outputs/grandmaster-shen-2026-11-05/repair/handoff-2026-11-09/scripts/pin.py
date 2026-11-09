import sys, os, numpy as np, time
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
clip = [c for c in SC.library() if c.name.endswith(sys.argv[1])][0]
t0 = time.time(); baked = clip.bake(); w, probs = L.validate(clip, baked)
keys = ["weapon_in_arm_right", "weapon_in_arm_left", "in_weapon_arm_right", "in_weapon_arm_left", "in_weapon_hands", "weapon_in_legs", "in_weapon_legs", "in_weapon_torso"]
ex = max(L.wrist_excess(clip.rig, b[1]["RightHand"][:3, :3], "Right") for b in baked)
print(os.environ.get("SHEN_PIN"), " ".join("%s %.3f" % (k.replace("weapon", "w"), w.get(k, 0)) for k in keys), "wristR max %.0f" % ex, probs, getattr(clip, "_haft_tilted", None), "%.0fs" % (time.time() - t0), flush=True)

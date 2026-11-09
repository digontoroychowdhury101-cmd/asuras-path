import sys, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_lib as L, shen_clips as SC
for clip in SC.library():
    if not clip.name.endswith(sys.argv[2]): continue
    clip.slide_floor = float(sys.argv[1]) if float(sys.argv[1]) > 0 else clip.slide_floor
    b = clip.bake(); w, probs = L.validate(clip, b)
    ex = [L.wrist_excess(clip.rig, x[1]["LeftHand"][:3, :3], "Left") for x in b]
    exr = [L.wrist_excess(clip.rig, x[1]["RightHand"][:3, :3], "Right") for x in b]
    print(sys.argv[1], clip.name, "L over %.0f%% max %.0f | R over %.0f%%" % (100 * np.mean(np.array(ex) > 1), max(ex), 100 * np.mean(np.array(exr) > 1)), "lsl", " ".join("%.2f" % x[4].get("_lsl", 0) for x in b[8:24]), probs, w.get("strike"), flush=True)

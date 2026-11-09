import sys, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_lib as L, shen_clips as SC
if sys.argv[1] == "nosmooth":
    L.smooth_hold = lambda Q, loop: Q
for clip in SC.library():
    if not clip.name.endswith(sys.argv[2]): continue
    b = clip.bake()
    ex = [L.wrist_excess(clip.rig, x[1]["LeftHand"][:3, :3], "Left") for x in b]
    print(sys.argv[1], clip.name, "L over %.0f%% max %.0f" % (100 * np.mean(np.array(ex) > 1), max(ex)), " ".join("%.0f" % e for e in ex))

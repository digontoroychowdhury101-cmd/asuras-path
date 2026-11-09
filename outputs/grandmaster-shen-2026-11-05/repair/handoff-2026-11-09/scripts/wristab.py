import sys, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_lib as L, shen_clips as SC
mode = sys.argv[1]
if mode == "noclear":
    L.CLEAR_MARGIN = 99.0
for clip in SC.library():
    if not clip.name.endswith(sys.argv[2]): continue
    b = clip.bake()
    print(mode, clip.name, "L over %.0f%%" % (100 * np.mean([L.wrist_excess(clip.rig, x[1]["LeftHand"][:3, :3], "Left") > 1 for x in b])), "max parts", np.abs([L.wrist_parts(clip.rig, x[1]["LeftHand"][:3, :3], "Left") for x in b]).max(0).round(0))

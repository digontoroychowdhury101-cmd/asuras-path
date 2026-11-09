import sys, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_lib as L, shen_clips as SC
L.STEP_LIMITS_ACTION = (float(sys.argv[1]), float(sys.argv[2])); L.LEAD_TURN_COST = float(sys.argv[3])
for clip in SC.library():
    if not clip.name.endswith(sys.argv[4]): continue
    b = clip.bake()
    out = []
    for s in ("Left", "Right"):
        ex = [L.wrist_excess(clip.rig, x[1][s + "Hand"][:3, :3], s) for x in b]
        out.append("%s over %.0f%% max %.0f" % (s[0], 100 * np.mean(np.array(ex) > 1), max(ex)))
    print(sys.argv[1:4], clip.name, *out, flush=True)

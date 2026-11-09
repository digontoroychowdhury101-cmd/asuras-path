import sys, json, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
from pathlib import Path
D = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("' + ROOT + '/work/opening_cast_bake/shen")
inside = 0; rows = []
for clip in SC.library():
    f = D / (clip.name + ".json")
    if not f.exists(): continue
    fr = json.load(open(f))["frames"]; out = []
    for s in ("Left", "Right"):
        ex = []
        for x in fr:
            A = np.array(x["parts"][s + "LowerArm"]).reshape(4, 4)[:3, :3]; H = np.array(x["parts"][s + "Hand"]).reshape(4, 4)[:3, :3]
            ex.append(L.wrist_excess(clip.rig, A.T @ H, s))
        ex = np.array(ex); out.append((float(np.mean(ex > 1)), float(ex.max())))
    rows.append((clip.name.replace("GrandmasterShen_", ""), out)); inside += all(o[0] == 0 for o in out)
for n, o in rows:
    if any(x[0] > 0 for x in o): print("%-26s L %3.0f%% max %4.1f | R %3.0f%% max %4.1f" % (n, 100 * o[0][0], o[0][1], 100 * o[1][0], o[1][1]))
print("clips fully inside range: %d of %d; mean left share %.0f%%, right %.0f%%" % (inside, len(rows), 100 * np.mean([o[0][0] for _, o in rows]), 100 * np.mean([o[1][0] for _, o in rows])))

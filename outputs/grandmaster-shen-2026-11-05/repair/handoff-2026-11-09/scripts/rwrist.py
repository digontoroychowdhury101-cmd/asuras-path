import sys
sys.path.insert(0, "tools/animation/opening_cast")
import numpy as np, shen_clips as SC, shen_lib as L, rig as ZR
for clip in SC.library():
    if not any(n in clip.name for n in sys.argv[1:]): continue
    b = clip.bake()
    rows = []
    for t, local, world, diag, c in b:
        a = ZR.angle_of(local["RightHand"][:3, :3])
        p = L.wrist_parts(clip.rig, local["RightHand"][:3, :3], "Right")
        rows.append((t, a, p, c.get("rhand_slant", 0), c.get("rlk", 0)))
    print(clip.name)
    for t, a, p, s, lk in rows:
        if a > float(__import__("os").environ.get("AMIN", 90)): print("  t %.3f ang %5.1f tw %5.1f fl %5.1f dv %5.1f slant %5.1f rlk %.2f" % (t, a, *p, s, lk))

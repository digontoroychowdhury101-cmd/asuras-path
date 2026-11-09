import json, sys, numpy as np
ROOT="' + ROOT + '"
def ang(R): return float(np.degrees(np.arccos(np.clip((np.trace(R)-1)/2,-1,1))))
for n in sys.argv[1:]:
    F=json.load(open(ROOT+"/work/opening_cast_bake/shen/GrandmasterShen_%s.json"%n))["frames"]
    out = {}
    for side in ("Left", "Right"):
        v=[]
        for fr in F:
            P=np.array(fr["parts"]["LowerTorso"]).reshape(4,4)[:3,:3]; T=np.array(fr["parts"][side+"UpperLeg"]).reshape(4,4)[:3,:3]
            R = P.T @ T
            # flex: how far the thigh's long axis (rest -y) has swung forward/up in the pelvis frame
            d = R @ np.array([0, -1.0, 0])
            flex = np.degrees(np.arctan2(-d[2], -d[1]))   # forward (-z) vs down (-y)
            v.append(flex)
        out[side] = v
    print(n, "L max %.0f R max %.0f" % (max(out["Left"]), max(out["Right"])), "| L", " ".join("%.0f" % x for x in out["Left"][::4]))

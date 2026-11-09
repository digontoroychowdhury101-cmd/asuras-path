import json, sys, numpy as np
ROOT="' + ROOT + '"
def ang(R): return np.degrees(np.arccos(np.clip((np.trace(R)-1)/2,-1,1)))
for n in sys.argv[1:]:
    F=json.load(open(ROOT+"/work/opening_cast_bake/shen/GrandmasterShen_%s.json"%n))["frames"]
    W=[{k:np.array(v).reshape(4,4)[:3,:3] for k,v in fr["parts"].items()} for fr in F]
    for p in ("LeftUpperArm","LeftLowerArm","LeftHand"):
        v=[ang(W[i][p].T@W[i+1][p]) for i in range(len(W)-1)]
        print(n,p[:9]," ".join("%3.0f"%x for x in v))
    print(n, "wristL", " ".join("%3.0f" % ang(w["LeftLowerArm"].T @ w["LeftHand"]) for w in W))

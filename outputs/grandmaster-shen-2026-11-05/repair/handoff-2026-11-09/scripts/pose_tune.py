import sys, json, numpy as np
sys.path.insert(0, "."); import shen_clips as SC, shen_lib as L
BODY=["Head","UpperTorso","LowerTorso","RightUpperArm","RightLowerArm","RightHand","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperLeg","RightLowerLeg","RightFoot","LeftUpperLeg","LeftLowerLeg","LeftFoot"]
phase=int(sys.argv[1]); over=json.loads(sys.argv[2]) if len(sys.argv)>2 else {}
clip=[c for c in SC.library() if c.name==f"GrandmasterShen_P{phase}_Death"][0]
c=clip.controls(3.0)
for k,v in over.items(): c[k]=tuple(v) if isinstance(v,list) else v
local,world,diag=clip.solve(c)
rg=clip.rig
out=[]
for k in BODY:
    out.append("%s %+.2f" % (k.replace("Right","R").replace("Left","L").replace("Upper","U").replace("Lower","Lo"), float(L.place(rg,world,k)[:,1].min())-L.GROUND))
print(" | ".join(out))
print("weapon low %+.2f" % (float(L.place(rg,world,"Weapon")[:,1].min())-L.GROUND), {k:round(v,2) for k,v in diag.items() if v>0.01})
for side in ("Right","Left"):
    S=(world["UpperTorso"]@np.append(rg.JOINT[side+"UpperArm"],1))[:3]
    print(side,"shoulder",np.round(S,2),"arm len",round(float(np.linalg.norm(rg.ARM_U)+np.linalg.norm(rg.ARM_L)),2))
print("rp final",np.round(c["rp"],2),"haft",np.round(c["haft"],2))

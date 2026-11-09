import sys, numpy as np
sys.path.insert(0, "."); import shen_clips as SC, shen_lib as L
BODY=["Head","UpperTorso","LowerTorso","RightUpperArm","RightLowerArm","RightHand","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperLeg","RightLowerLeg","RightFoot","LeftUpperLeg","LeftLowerLeg","LeftFoot"]
for clip in SC.library():
    if not clip.name.endswith("_Death"): continue
    b=clip.bake(); rg=clip.rig
    stats, problems = L.validate(clip, b)
    print(clip.name, "problems:", problems)
    for t,local,world,diag,c in b[::6]:
        lows={k: float(L.place(rg,world,k)[:,1].min()) for k in BODY}
        lo=min(lows.values()); who=min(lows,key=lows.get)
        w=float(L.place(rg,world,"Weapon")[:,1].min())
        print("  t %.2f body low %+.2f (%s) weapon low %+.2f head %+.2f" % (t, lo-L.GROUND, who, w-L.GROUND, lows["Head"]-L.GROUND))

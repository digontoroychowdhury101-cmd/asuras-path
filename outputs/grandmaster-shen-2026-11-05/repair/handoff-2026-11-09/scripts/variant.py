import sys, shen_clips as SC, shen_lib as L, numpy as np
mode=sys.argv[1]
if mode=="nomem":
    orig_bake=L.Clip.bake
    L.Clip._side=property(lambda self: None, lambda self,v: None)
names=sys.argv[2:]
for cl in SC.library():
    if not any(cl.name.endswith(n) for n in names): continue
    b=cl.bake(); rg=cl.rig; st,pr=SC.validate(cl,b)
    f=np.array([(w["RightHand"]@np.append(rg.GRIP0,1))[:3] for _,_,w,_,_ in b]); v=np.linalg.norm(np.diff(f,axis=0),axis=1)*30
    print(mode, cl.name[16:], "fist max %.1f"%v.max(), pr)

import sys, shen_clips as SC, shen_lib as L, numpy as np
for nm in sys.argv[1:]:
    cl=[c for c in SC.library() if c.name.endswith(nm)][0]; b=cl.bake(); rg=cl.rig
    f=np.array([(w["RightHand"]@np.append(rg.GRIP0,1))[:3] for _,_,w,_,_ in b])
    tip=[]
    for _,_,w,_,c in b:
        wp=L.place(rg,w,"Weapon"); fist=(w["RightHand"]@np.append(rg.GRIP0,1))[:3]; tip.append(wp[int(np.argmax((wp-fist)@L.unit(c["haft"])))])
    tip=np.array(tip)
    v=np.linalg.norm(np.diff(f,axis=0),axis=1)*30; vt=np.linalg.norm(np.diff(tip,axis=0),axis=1)*30
    o=np.argsort(-v)[:4]
    print(nm, "fist speed max", [(round(float(v[i]),1),round(b[i][0],2)) for i in o], "tip speed max %.1f"%vt.max())

import sys; sys.path.insert(0,'../../qa')
import shen_clips as SC, shen_lib as L, numpy as np, shen_grip_report as G
names=sys.argv[1:]
for cl in SC.library():
    if not any(cl.name.endswith(n) for n in names): continue
    b=cl.bake(); st,pr=SC.validate(cl,b); rows=G.measure(cl,b); rg=cl.rig
    f=np.array([(w["RightHand"]@np.append(rg.GRIP0,1))[:3] for _,_,w,_,_ in b]); v=np.linalg.norm(np.diff(f,axis=0),axis=1)*30
    cs=[round(min(r["sep"] for r in rows if ct-1e-4<=r["t"]<=ct+0.07),2) for ct in cl.contacts]
    seps=[r["sep"] for r in rows if r["sep"]==r["sep"]]
    pro=max(np.linalg.norm(l["LeftUpperArm"][:3,3]) for _,l,_,_,_ in b)
    print("%-26s contact sep %s min sep %.2f fist max %.0f pro %.2f reach %s wr %.0f wl %.0f %s"%(cl.name[16:],cs,min(seps),v.max(),pro,st.get("strike",{}).get("game_radius_during_active"),st.get("wrist_right",0),st.get("wrist_left",0),pr))

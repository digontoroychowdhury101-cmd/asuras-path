import sys, numpy as np
sys.path.insert(0, "' + ROOT + '/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
name, side = sys.argv[1], sys.argv[2]
clip=[c for c in SC.library() if c.name.endswith(name)][0]
baked=clip.bake(); rg=clip.rig; J=rg.JOINT
for t, local, world, diag, c in baked:
    G=world["Glaive"]; place=(G[:3,:3], G[:3,3]+G[:3,:3]@rg.WGRIP); P=rg.WCLOUD@G[:3,:3].T+place[1]
    out=[]
    for part in (side+"UpperArm", side+"LowerArm", side+"Hand"):
        W=world[part]; A=(W@np.append(J[part],1))[:3]
        Bw=L.body_points(rg,part,W[:3,:3],A)
        d1=L.weapon_depth(rg,*place,Bw); i=int(np.argmax(d1))
        s_=float(((Bw[i]-place[1])@place[0]+rg.WGRIP-rg.WGRIP)@rg.HAFT0)
        d2=float(L.part_depth(rg,part,W[:3,:3],A,P).max()) if part in rg.SDF else 0
        out.append("%s in %.3f out %.3f s%.2f"%(part.replace(side,"")[:5], d1[i], d2, s_))
    print("t %.2f "%t, " | ".join(out), "lhw %.2f ltw %.2f rsl %.2f lsl %.2f"%(c["lhw"],c["ltw"],c["rsl"],c.get("_lsl",c["lsl"])))

import json, numpy as np, sys
ROOT="' + ROOT + '"
shot=sys.argv[1]; frames=[int(x) for x in sys.argv[2].split(",")]
sh=json.load(open(ROOT+"/work/opening_cast_bake/shen_shots/%s.json"%shot)); ph=sh["phase"]
c=json.load(open(ROOT+"/work/shen_import/cloth_p%d.json"%ph))
col=c["colliders"]
def seg(p,a,b):
    a,b=np.array(a),np.array(b); ab=b-a; t=np.clip((p-a)@ab/max(ab@ab,1e-9),0,1); return np.linalg.norm(p-(a+t*ab))
sdf=np.load(ROOT+"/work/shen_import/sdf_p%d.npz"%ph)
g,lo,st=sdf["UpperTorso_grid"],sdf["UpperTorso_origin"],float(sdf["UpperTorso_step"])
def depth(Q):
    q=(Q-lo)/st; i=np.clip(np.round(q).astype(int),0,np.array(g.shape)-1); return -g[tuple(i.T)]
for f in frames:
    fr=sh["frames"][f]; v=fr["bones"]["Sk_UpperTorso"]; R=np.array(v[:9]).reshape(3,3); t=np.array(v[9:12])
    for i,p in enumerate(c["particles"]):
        if p["sheet"]!="Beard" or p.get("pin"): continue
        b=fr["bones"]["Cl_Beard_%d_%d"%(p["c"],p["r"])]; Rb=np.array(b[:9]).reshape(3,3); tb=np.array(b[9:12])
        P=Rb@np.array(p["at"])+tb
        Q=(P-t)@R
        h={k:cl for k,cl,_ in p["hit"]}
        print("f%d p%d c%d r%d Q %s d5 %.3f (need %.3f) d17 %.3f (need %.3f) sdf %.3f" % (f,i,p["c"],p["r"],np.round(Q,2), seg(Q,col[5]["a"],col[5]["b"]),h[5], seg(Q,col[17]["a"],col[17]["b"]),h[17], depth(Q[None])[0]))

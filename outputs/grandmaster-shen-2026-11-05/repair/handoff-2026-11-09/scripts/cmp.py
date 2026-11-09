import re,sys,glob,os
tags=sys.argv[1:]
def parse(f):
    if not os.path.exists(f): return None
    t=open(f).read()
    m=re.search(r"problems:(.*)",t)
    if not m: return None
    d={k:float(v) for k,v in re.findall(r"(\w+)=([\d.]+)",t.split("| strike")[0].split("\n")[-1] if False else t)}
    return d, m.group(1).strip()
names=sorted({os.path.basename(f)[len("tt"+tags[1])+1:-4] for f in glob.glob(f"tt{tags[1]}_*.log")})
for n in names:
    row=[]
    for tg in tags:
        r=parse(f"tt{tg}_{n}.log")
        if r is None: row.append("   (run)   "); continue
        d,p=r
        row.append("%.3f/%.3f w%3.0f %s"%(d.get("torso_right",0),d.get("torso_left",0),d.get("wrist_right",0),"OK" if p in ("[]","") else "F"))
    print("%-22s"%n," | ".join(row))

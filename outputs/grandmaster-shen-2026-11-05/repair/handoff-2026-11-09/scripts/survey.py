import json,sys
m=json.load(open("' + ROOT + '/assets/animations/opening_cast/shen/manifest.json"))["clips"]
keys=["weapon_in_arm_right","weapon_in_arm_left","in_weapon_arm_right","in_weapon_arm_left","in_weapon_hands","weapon_in_torso","in_weapon_torso","weapon_in_legs"]
worst={k:(0,"") for k in keys}; over=0
for n,e in m.items():
    v=e["validation"]; row=[v.get(k,0) or 0 for k in keys]
    for k,x in zip(keys,row):
        if x>worst[k][0]: worst[k]=(x,n)
    if max(row)>0.03: over+=1; print("%-36s %s"%(n.replace("GrandmasterShen_",""), " ".join("%.3f"%x for x in row)))
print("clips with any metric >0.03:",over,"of",len(m))
for k,(x,n) in worst.items(): print(k,round(x,3),n)
print("problems:",[n for n,e in m.items() if e["problems"]])

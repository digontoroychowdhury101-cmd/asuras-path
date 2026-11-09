import json, sys
S=(__import__("os").environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair")
ROOT="' + ROOT + '"
a=json.load(open(S+"/rbx_dc/manifest.json")); b=json.load(open(ROOT+"/assets/animations/opening_cast/shen/manifest.json")); a=a.get("clips",a); b=b.get("clips",b)
names = sys.argv[1:] or sorted(b)
keys=("left_grip","left_off_haft","right_off_haft","wrist_right","wrist_left","weapon_in_arm_right","weapon_in_arm_left","in_weapon_arm_right","in_weapon_arm_left","in_weapon_hands","in_weapon_torso","weapon_in_torso","weapon_in_legs","arm_reach","planted_slide")
for n in names:
    n = n if n.startswith("Grand") else "GrandmasterShen_"+n
    va, vb = a[n]["validation"], b[n]["validation"]
    diffs = ["%s %.3g->%.3g" % (k, va.get(k,0), vb.get(k,0)) for k in keys if abs(va.get(k,0)-vb.get(k,0)) > (2 if "wrist" in k else 0.005)]
    print(n[16:], " | ".join(diffs), "| problems:", b[n].get("problems"))

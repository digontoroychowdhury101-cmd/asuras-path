import json, sys
import numpy as np
sys.path.insert(0, "tools/qa")
import shen_cloth_report as R
shot = sys.argv[1]
data = json.loads((R.ROOT / "work/opening_cast_bake/shen_shots" / (shot + ".json")).read_text())
cloth = json.loads((R.ROOT / f"work/shen_import/cloth_p{data['phase']}.json").read_text())
P = cloth["particles"]; kind = {s["name"]: s["kind"] for s in cloth["sheets"]}
free = [i for i, p in enumerate(P) if "bone" in p and not p.get("finger") and not p.get("orb")]
bone_name = {i: cloth["bones"][P[i]["bone"]]["name"] for i in free}
links = [(a, b) for a, b, *_ in cloth["links"] if (a in bone_name or b in bone_name) and P[a]["sheet"] == P[b]["sheet"] and abs(P[a]["r"] - P[b]["r"]) <= 1]
rest = np.array([p["at"] for p in P], float)
vols = R.volumes(cloth)
# classify: particle / link both free / link with pinned end ; and whether volume is in the sheet's hit list
hits = cloth["hits"]; cols = cloth["colliders"]
def inhits(p, limb):
    ids = hits.get(kind[p["sheet"]], [])
    return any(cols[c]["limb"] == limb[3:] for c in ids)
def lt(a, b):
    pa, pb = P[a], P[b]; dr, dc = abs(pa["r"]-pb["r"]), abs(pa["c"]-pb["c"])
    t = "edge" if pa["sheet"] == pb["sheet"] and ((dc == 0 and dr == 1) or (dr == 0 and dc >= 1)) else "diag" if dr == 1 and dc == 1 else "other"
    return ("free-" if (a in bone_name and b in bone_name) else "pin-") + t
cls = ["particle"] * len(free) + [lt(a, b) for a, b in links]
owners = [P[i] for i in free] + [P[a] for a, b in links]
tags = [kind[p["sheet"]] for p in owners]
carried = lambda p: {"Sk_" + p["anchor"], "Sk_" + p.get("anchor2", p["anchor"])}
rest_pts = np.vstack([rest[free], (rest[[a for a, b in links]] + rest[[b for a, b in links]]) / 2])
start_out = np.stack([(R.seg_dist(rest_pts, a, b) > r + 0.02) & np.array([limb not in carried(p) for p in owners]) for _, limb, a, b, r in vols], 1)
cnt = {}
for fr in data["frames"]:
    B = fr["bones"]; world = rest.copy()
    for i, nm in bone_name.items():
        M = R.m34(B[nm]); world[i] = M[:3, :3] @ rest[i] + M[:3, 3]
    for i, p in enumerate(P):
        if i not in bone_name:
            M = R.m34(B["Sk_" + p["anchor"]]) if ("Sk_" + p["anchor"]) in B else np.eye(4); world[i] = M[:3, :3] @ rest[i] + M[:3, 3]
    pts = np.vstack([world[free], (world[[a for a, b in links]] + world[[b for a, b in links]]) / 2])
    for vi, (group, limb, a, b, r) in enumerate(vols):
        if group == "weapon": continue
        M = R.m34(B[limb]); A, Bp = M[:3, :3] @ a + M[:3, 3], M[:3, :3] @ b + M[:3, 3]
        depth = r - R.seg_dist(pts, A, Bp)
        for k in np.nonzero((depth > 0.03) & start_out[:, vi])[0]:
            key = (tags[k], group, cls[k], "hit" if inhits(owners[k], limb) else "nohit")
            c = cnt.setdefault(key, [0, 0.0]); c[0] += 1; c[1] = max(c[1], float(depth[k]))
for k, v in sorted(cnt.items(), key=lambda kv: -kv[1][0])[:25]:
    print(k, v[0], round(v[1], 3))

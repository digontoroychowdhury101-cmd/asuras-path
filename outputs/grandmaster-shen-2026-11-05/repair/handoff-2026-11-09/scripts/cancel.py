"""Offline: at one exported frame, which garment samples are inside a volume they avoid, and do the pushes they ask of shared particles cancel?"""
import json, sys, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
shot, f, cdir = sys.argv[1], int(sys.argv[2]), sys.argv[3]
fr = json.load(open(ROOT + "/work/opening_cast_bake/shen_shots/%s.json" % shot))
phase = fr["phase"]; fr = fr["frames"][f]
cloth = json.load(open(cdir + "/cloth_p%d.json" % phase))
sm = json.load(open(cdir + "/clothskin_p%d.json" % phase))["samples"]
rc = json.load(open(cdir + "/clothskin_reach_p%d.json" % phase))["reach"]
cols, parts, bones = cloth["colliders"], cloth["particles"], cloth["bones"]
kind = {s["name"]: s["kind"] for s in cloth["sheets"]}
carrier = {bones[p["bone"]]["name"]: (i, p) for i, p in enumerate(parts) if "bone" in p and not p["pin"] and "orb" not in p and "finger" not in p}
B = {k: (np.array(v[:9]).reshape(3, 3), np.array(v[9:12])) for k, v in fr["bones"].items()}
def seg(c, X):
    a, b = np.array(c["a"]), np.array(c["b"]); d = b - a
    u = float(np.clip((X - a) @ d / (d @ d), 0, 1)); q = X - a - u * d
    return q, u
acc = {}
viol = 0
for k, s in enumerate(sm):
    w = s["w"]
    if not all(n in carrier or n.startswith("Sk_") for n, _ in w) or not any(n in carrier for n, _ in w): continue
    v = np.array(s["v"])
    S = sum(x * (B[n][0] @ v + B[n][1]) for n, x in w)
    cw = [(carrier[n][0], x) for n, x in w if n in carrier]
    w2 = sum(x * x for _, x in cw); inv = min(1 / w2, 2.5 / max(x for _, x in cw))
    for ci, room in rc[k]:
        if room >= 0.35: continue
        c = cols[ci]
        q0, u0 = seg(c, v); d0 = np.linalg.norm(q0); r0 = c["r"] + (c.get("rb", c["r"]) - c["r"]) * u0
        hr, firm = (min(0.02, (d0 - r0) * 0.985), True) if d0 >= r0 else (d0 * 0.985 - r0, True)
        Rl, tl = B["Sk_" + c["limb"]]
        Q = Rl.T @ (S - tl)
        q, u = seg(c, Q); d = np.linalg.norm(q)
        need = hr + (c["r"] + (c.get("rb", c["r"]) - c["r"]) * u if firm else 0)
        if d < need:
            viol += 1
            m = Rl @ (q / d * (need - d))
            for i, x in cw:
                acc.setdefault(i, []).append((m * x * inv, k, c["limb"], need - d))
print("violating sample-volume pairs", viol, "deepest %.3f" % max([x[3] for L in acc.values() for x in L] or [0]))
rows = []
for i, L in acc.items():
    vs = np.array([a for a, *_ in L]); mean = vs.mean(0); tot = np.linalg.norm(vs, axis=1).mean()
    rows.append((np.linalg.norm(mean) / tot, i, len(L), tot, np.linalg.norm(mean), max(x[3] for x in L)))
rows.sort()
for r in rows[:15]:
    p = parts[r[1]]
    print("%-7s r%d c%d  pushes %2d  mean|push| %.3f  |mean push| %.3f  kept %.0f%%  deepest miss %.3f" % (p["sheet"], p["r"], p["c"], r[2], r[3], r[4], r[0] * 100, r[5]))
print("all particles: median kept %.0f%%" % (np.median([r[0] for r in rows]) * 100))

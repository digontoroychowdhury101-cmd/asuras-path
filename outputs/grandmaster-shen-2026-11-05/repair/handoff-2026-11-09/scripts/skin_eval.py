import sys, glob, os, json, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import skinlib as L
ROOT = L.ROOT
ph = int(sys.argv[1]); step = int(sys.argv[2]) if len(sys.argv) > 2 else 2
sm = L.load_samples(ph); sdf = L.load_sdf(ph)
cloth = json.load(open(ROOT + "/work/shen_import/cloth_p%d.json" % ph))
cols = cloth["colliders"]
body = [i for i, c in enumerate(cols) if c["limb"] != "Glaive" and c["limb"] in sdf]
V = np.array([s["v"] for s in sm]); N = len(sm)
rest_d = {i: L.capdist(V, cols[i]) for i in body}
rest_sd = {p: -L.depth(sdf[p], V) for p in sdf}
shots = sorted(os.path.basename(f)[:-5] for f in glob.glob(ROOT + "/work/opening_cast_bake/shen_shots/c%d_*.json" % ph) if os.path.basename(f).count("_") >= 1 and "." not in os.path.basename(f)[:-5])
shots = [s for s in shots if not any(s.endswith(x) for x in ("_b0", "_old", "_new"))]
minmargin = np.full(N, 9.0)       # min over frames of (capsule dist - capsule-rule clearance)
caught = missed = falsep = 0
real_in = np.zeros(N, int)
per_shot = {}
for name in shots:
    sh = L.shot(name); fr = sh["frames"][::step]
    P = L.skin(sm, fr)
    worst = 0.0
    for f in range(len(fr)):
        inside_real = np.zeros(N); viol = np.zeros(N, bool)
        for part in sdf:
            Q = L.to_rest(P[f], fr[f], part)
            d = L.depth(sdf[part], Q)
            inside_real = np.maximum(inside_real, d)
        for i in body:
            c = cols[i]
            Q = L.to_rest(P[f], fr[f], c["limb"])
            dist, u, r = L.capdist(Q, c)
            dp0 = rest_d[i][0]
            clear = np.minimum(r, dp0 * 0.985)
            minmargin = np.minimum(minmargin, dist - clear)
            viol |= dist < clear
        ri = inside_real > 0.03
        real_in += ri
        caught += (ri & viol).sum(); missed += (ri & ~viol).sum(); falsep += ((inside_real < -0.05) & viol).sum()
        worst = max(worst, inside_real.max())
    per_shot[name] = round(float(worst), 3)
print("P%d shots %d samples %d" % (ph, len(shots), N))
print("real-inside sample-frames: caught by capsule rule %d, missed %d; capsule-rule pushes where real clear >0.05: %d" % (caught, missed, falsep))
for th in (0.0, 0.05, 0.1, 0.2):
    print("  samples ever within %.2f of their capsule clearance: %d" % (th, (minmargin < th).sum()))
print("  samples ever really inside: %d" % (real_in > 0).sum())
np.savez(os.path.join(os.path.dirname(__file__), "skin_eval_p%d.npz" % ph), minmargin=minmargin, real_in=real_in)
print("worst real depth per shot:", sorted(per_shot.items(), key=lambda kv: -kv[1])[:12])

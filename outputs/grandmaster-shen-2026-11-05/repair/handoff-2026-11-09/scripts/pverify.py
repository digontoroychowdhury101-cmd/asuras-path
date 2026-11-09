"""Verify: are the cloth particles that drive the penetrating robe vertices themselves clear of the body (real surface and capsule)?"""
import sys, json, os
S = os.environ["S"]
sys.argv = [sys.argv[0], "--", S + "/_none.json", "1"]
sys.path.insert(0, "' + ROOT + '/tools/blender/shen_import")
import mesh_clash as M
import numpy as np, bpy
shot, cl_g, solid = os.environ["SHOT"], os.environ["CL"], os.environ["SOLID"]
frames = [int(x) for x in os.environ["FR"].split(",")]
data = json.load(open(os.path.join(M.ROOT, "work/opening_cast_bake/shen_shots", shot + ".json")))
phase = data["phase"]
PP = np.load(os.environ["PD"])
arm, props, groups = M.load(phase)
sdf = M.load_sdf(phase)
rest = {b.name: b.bone.matrix_local.copy() for b in arm.pose.bones}
maps = M.rigid_maps(groups, [solid])
cloth = json.load(open(os.path.join(M.ROOT, "work/shen_import/cloth_p%d.json" % phase)))
parts = cloth["particles"]
bone_to_pi = {cloth["bones"][p["bone"]]["name"]: i for i, p in enumerate(parts) if "bone" in p}
caps = [(i, c) for i, c in enumerate(cloth["colliders"]) if c["limb"] == solid]
objs = groups[cl_g]
# per-vertex weights (all vertices, same order as M.verts with keep=inf)
W = []
for ob in objs:
    names = {g.index: g.name for g in ob.vertex_groups}
    for v in ob.data.vertices:
        W.append({names[e.group]: e.weight for e in v.groups if e.weight > 0.01})
def capdist(Q, c):
    a, b = np.array(c["a"]), np.array(c["b"]); d = b - a
    u = np.clip((Q - a) @ d / (d @ d), 0, 1)
    return np.linalg.norm(Q - a - np.outer(u, d), axis=1), u
base = None
for f in frames:
    fr = data["frames"][f]
    M.pose(arm, props, fr, rest)
    dg = bpy.context.evaluated_depsgraph_get()
    P = M.verts(objs, dg, 10 ** 9)
    v = fr["bones"]["Sk_" + solid]; R, t = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
    Q = (P - t) @ R
    d = M.depth(sdf[solid], Q)
    ok = d > M.MARGIN
    idx = np.nonzero(ok)[0]
    idx = idx[M.rigid(maps, solid, Q[idx])]
    if base is None:
        base = set(idx.tolist()); print("BASELINE frame", f, "inside", len(base)); continue
    idx = np.array([i for i in idx if i not in base], int)
    print("\nFRAME %d: %d %s vertices inside %s past margin (deepest %.3f)" % (f, len(idx), cl_g, solid, d[idx].max() if len(idx) else 0))
    if not len(idx):
        continue
    # the bones (particles) carrying them
    acc = {}
    for i in idx:
        for bn, w in W[i].items():
            if bn in bone_to_pi:
                a = acc.setdefault(bn, [0.0, 0, 0.0]); a[0] += w; a[1] += 1; a[2] = max(a[2], d[i])
    Pq = (PP[f] - t) @ R   # particles in the leg's rest space
    dp = M.depth(sdf[solid], Pq)
    print("  driving particles (weight-summed over inside verts):")
    for bn, (ws, n, dm) in sorted(acc.items(), key=lambda kv: -kv[1][0])[:10]:
        pi = bone_to_pi[bn]; p = parts[pi]
        hits = {h[0]: h for h in p.get("hit", [])}
        cs = []
        for ci, c in caps:
            dist, u = capdist(Pq[pi:pi + 1], c)
            rr = c["r"] + (c.get("rb", c["r"]) - c["r"]) * u[0]
            h = hits.get(ci)
            need = (rr + h[1]) if h and h[2] else (h[1] if h else None)
            cs.append("cap%d dist %.3f need %s" % (ci, dist[0], "%.3f" % need if need is not None else "-"))
        print("   %-12s p%-3d %s r%d c%d  wsum %.2f n %3d  vert depth max %.3f | particle real-surface depth %+.3f | %s" % (bn, pi, p["sheet"], p["r"], p["c"], ws, n, dm, dp[pi], "; ".join(cs)))
    # how far the inside vertices are from their bones' particles, and where the vertex would be if carried only by translation
    deepest = idx[np.argsort(-d[idx])[:5]]
    for i in deepest:
        ws = {bn: w for bn, w in W[i].items() if bn in bone_to_pi}
        sk = {bn: w for bn, w in W[i].items() if bn.startswith("Sk_")}
        print("   vert %5d depth %.3f  cloth bones %s  body bones %s" % (i, d[i], {k: round(w, 2) for k, w in sorted(ws.items(), key=lambda kv: -kv[1])[:4]}, {k: round(w, 2) for k, w in sk.items()}))

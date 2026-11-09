"""Each penetrating vertex as the blend of where each of its bones alone would put it."""
import sys, json, os
S = os.environ["S"]
sys.argv = [sys.argv[0], "--", S + "/_none.json", "1"]
sys.path.insert(0, "' + ROOT + '/tools/blender/shen_import")
import mesh_clash as M
import numpy as np, bpy
shot, cl_g, solid, f = os.environ["SHOT"], os.environ["CL"], os.environ["SOLID"], int(os.environ["FR"])
data = json.load(open(os.path.join(M.ROOT, "work/opening_cast_bake/shen_shots", shot + ".json")))
phase = data["phase"]
arm, props, groups = M.load(phase)
sdf = M.load_sdf(phase)
rest = {b.name: b.bone.matrix_local.copy() for b in arm.pose.bones}
cloth = json.load(open(os.path.join(M.ROOT, "work/shen_import/cloth_p%d.json" % phase)))
parts = cloth["particles"]
bone_to_pi = {cloth["bones"][p["bone"]]["name"]: i for i, p in enumerate(parts) if "bone" in p}
objs = groups[cl_g]
V0, W = [], []
for ob in objs:
    names = {g.index: g.name for g in ob.vertex_groups}
    Mw = M.CI @ ob.matrix_world
    for v in ob.data.vertices:
        V0.append(np.array(Mw @ v.co)); W.append({names[e.group]: e.weight for e in v.groups if e.weight > 0.0})
V0 = np.array(V0)
fr = data["frames"][f]
M.pose(arm, props, fr, rest)
dg = bpy.context.evaluated_depsgraph_get()
P = M.verts(objs, dg, 10 ** 9)
v = fr["bones"]["Sk_" + solid]; R, t = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
d = M.depth(sdf[solid], (P - t) @ R)
B = {k: (np.array(x[:9]).reshape(3, 3), np.array(x[9:12])) for k, x in fr["bones"].items()}
for i in np.argsort(-d)[:int(os.environ.get("N", "4"))]:
    ws = W[i]; tot = sum(ws.values())
    print("\nvert %d depth %.3f  rest pos %s  skinned %s" % (i, d[i], np.round(V0[i], 3), np.round(P[i], 3)))
    blend = np.zeros(3)
    for bn, w in sorted(ws.items(), key=lambda kv: -kv[1]):
        Rb, tb = B[bn]
        c = Rb @ V0[i] + tb
        blend += w / tot * c
        dc = M.depth(sdf[solid], ((c - t) @ R)[None])[0]
        pi = bone_to_pi.get(bn)
        extra = ""
        if pi is not None:
            at = np.array(parts[pi]["at"]); p = Rb @ at + tb
            ang = np.degrees(np.arccos(np.clip((np.trace(Rb) - 1) / 2, -1, 1)))
            extra = "particle %s r%d c%d  rest offset |v-at| %.3f  bone turn %.0f deg  particle moved %.3f  translation-only depth %+.3f" % (parts[pi]["sheet"], parts[pi]["r"], parts[pi]["c"], np.linalg.norm(V0[i] - at), ang, np.linalg.norm(p - at),
                M.depth(sdf[solid], (((V0[i] - at) + p - t) @ R)[None])[0])
        print("   %-14s w %.2f  alone-> depth %+.3f  %s" % (bn, w / tot, dc, extra))
    print("   blend check %s depth %+.3f" % (np.round(blend, 3), M.depth(sdf[solid], ((blend - t) @ R)[None])[0]))

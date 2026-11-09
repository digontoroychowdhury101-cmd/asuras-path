import sys, json, os
sys.argv = [sys.argv[0], "--", os.environ["S"] + "/_none.json", "1"]
sys.path.insert(0, "' + ROOT + '/tools/blender/shen_import")
import mesh_clash as M
import numpy as np, bpy
shot, cl, solid, frames = os.environ["SHOT"], os.environ["CL"], os.environ["SOLID"], [int(x) for x in os.environ["FR"].split(",")]
data = json.load(open(os.path.join(M.ROOT, "work/opening_cast_bake/shen_shots", shot + ".json")))
arm, props, groups = M.load(data["phase"])
sdf = M.load_sdf(data["phase"])
rest = {b.name: b.bone.matrix_local.copy() for b in arm.pose.bones}
maps = M.rigid_maps(groups, [solid])
cloth = json.load(open(os.path.join(M.ROOT, "work/shen_import/cloth_p%d.json" % data["phase"])))
cols = [(i, c) for i, c in enumerate(cloth["colliders"]) if c.get("limb") == solid]
J0 = np.array(arm.data.bones["Sk_" + solid].head_local) @ M.CIn.T
J1 = np.array(arm.data.bones["Sk_" + solid].tail_local) @ M.CIn.T
print("colliders on", solid, [(i, c["r"], c.get("rb"), c.get("firm"), c["a"], c["b"]) for i, c in cols])
print("hits for kind:", {k: v for k, v in cloth["hits"].items()})
for f in frames:
    fr = data["frames"][f]
    M.pose(arm, props, fr, rest)
    dg = bpy.context.evaluated_depsgraph_get()
    P = M.verts(groups[cl], dg, 10 ** 9)
    v = fr["bones"]["Sk_" + solid]; R, t = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
    Q = (P - t) @ R
    d = M.depth(sdf[solid], Q)
    deep = np.nonzero(d > 0.03)[0]
    deep = deep[M.rigid(maps, solid, Q[deep])]
    ax = J1 - J0; u = (Q[deep] - J0) @ ax / (ax @ ax)
    r = np.linalg.norm((Q[deep] - J0) - np.outer(u, ax), axis=1)
    print("FRAME", f, "inside", len(deep), "of", len(P))
    for b in np.arange(-0.2, 1.4, 0.1):
        m = (u >= b) & (u < b + 0.1)
        if m.any():
            print("   u %.1f n %4d  depth max %.3f  radial from bone axis %.3f..%.3f" % (b, m.sum(), d[deep][m].max(), r[m].min(), r[m].max()))
    obs = groups[cl]; allv = []
    for ob in obs:
        names = {g.index: g.name for g in ob.vertex_groups}
        for v in ob.data.vertices:
            sk = sum(e.weight for e in v.groups if names[e.group].startswith("Sk_")); tot = sum(e.weight for e in v.groups)
            allv.append(sk / tot if tot else 0)
    allv = np.array(allv); bw = allv[deep]
    print("   body-bone weight share of the inside vertices: mean %.2f, min %.2f, max %.2f (all robe vertices mean %.2f)" % (bw.mean(), bw.min(), bw.max(), allv.mean()))

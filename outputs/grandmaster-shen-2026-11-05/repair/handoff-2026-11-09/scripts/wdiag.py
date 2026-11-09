"""Where is the glaive inside the forearm: deepest weapon vertices at given frames, in weapon rest space and forearm rest space."""
import sys, json, os
S = os.environ["S"]
sys.argv = [sys.argv[0], "--", S + "/_none.json", "1"]
sys.path.insert(0, "' + ROOT + '/tools/blender/shen_import")
import mesh_clash as M
import numpy as np, bpy
shot, solid = os.environ["SHOT"], os.environ["SOLID"]
data = json.load(open(os.path.join(M.ROOT, "work/opening_cast_bake/shen_shots", shot + ".json")))
phase = data["phase"]
arm, props, groups = M.load(phase)
sdf = M.load_sdf(phase)
rest = {b.name: b.bone.matrix_local.copy() for b in arm.pose.bones}
maps = M.rigid_maps(groups, [solid])
W0 = M.verts(groups["Weapon"], bpy.context.evaluated_depsgraph_get(), 10 ** 9)   # bind: weapon rest positions (props at identity in load)
for f in [int(x) for x in os.environ["FR"].split(",")]:
    fr = data["frames"][f]
    M.pose(arm, props, fr, rest)
    dg = bpy.context.evaluated_depsgraph_get()
    P = M.verts(groups["Weapon"], dg, 10 ** 9)
    v = fr["bones"]["Sk_" + solid]; R, t = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
    Q = (P - t) @ R
    d = M.depth(sdf[solid], Q)
    ok = M.rigid(maps, solid, Q[d > 0.03]) if (d > 0.03).any() else np.zeros(0, bool)
    idx = np.nonzero(d > 0.03)[0][ok]
    print("frame %d: %d weapon verts > 0.03 in %s, deepest %.3f" % (f, len(idx), solid, d[idx].max() if len(idx) else 0))
    if len(idx):
        k = idx[np.argmax(d[idx])]
        print("   deepest at weapon rest %s, forearm rest %s" % (np.round(W0[k], 3), np.round(Q[k], 3)))
        print("   weapon rest extent of the clash: x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f" % tuple(np.ravel([[W0[idx, a].min(), W0[idx, a].max()] for a in range(3)])))

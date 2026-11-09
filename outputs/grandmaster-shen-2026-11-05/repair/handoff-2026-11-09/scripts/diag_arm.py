import sys, json, os
sys.argv = [sys.argv[0], "--", "' + (__import__('os').environ.get('SHEN_SCRATCH') or ROOT + '/work/shen_repair') + '/_none.json", "1"]   # mesh_clash parses these at import; no shots
sys.path.insert(0, "' + ROOT + '/tools/blender/shen_import")
import mesh_clash as M
import numpy as np, bpy
shot, part, frames = os.environ["SHOT"], os.environ["PART"], [int(x) for x in os.environ["FR"].split(",")]
data = json.load(open(os.path.join(M.ROOT, "work/opening_cast_bake/shen_shots", shot + ".json")))
arm, props, groups = M.load(data["phase"])
sdf = M.load_sdf(data["phase"])
rest = {b.name: b.bone.matrix_local.copy() for b in arm.pose.bones}
side = "Left" if part.startswith("Left") else "Right"
for f in frames:
    fr = data["frames"][f]
    M.pose(arm, props, fr, rest)
    dg = bpy.context.evaluated_depsgraph_get()
    for ob in groups[part]:
        ev = ob.evaluated_get(dg); me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3); me.vertices.foreach_get("co", co); ev.to_mesh_clear()
        W = np.array(ob.matrix_world); P = (co.reshape(-1, 3) @ W[:3, :3].T + W[:3, 3]) @ M.CIn.T
        G = np.array(fr["props"]["Glaive"]).reshape(4, 4)
        Q = (P - G[:3, 3]) @ G[:3, :3]
        d = M.depth(sdf["Weapon"], Q)
        idx = np.nonzero(d > 0.03)[0]
        vg = {g.index: g.name for g in ob.vertex_groups}
        # forearm axis: distance of each vertex from the wrist (hand bone head) in rest
        hb = arm.data.bones["Sk_" + side + "Hand"].head_local; eb = arm.data.bones["Sk_" + side + "LowerArm"].head_local
        print("FRAME", f, ob.name, "verts", len(P), "inside", len(idx), "deepest %.3f" % (d.max()))
        if len(idx) == 0: continue
        hist = {}
        for i in idx:
            v = ob.data.vertices[int(i)]
            ws = sorted(((e.weight, vg[e.group]) for e in v.groups), reverse=True)[:2]
            rv = np.array(v.co)  # rest local
            u = float(np.dot(rv - np.array(eb), np.array(hb - eb)) / (hb - eb).length_squared)
            key = (round(u, 1), ws[0][1].replace("Sk_", "") + ("/" + ws[1][1].replace("Sk_", "") + "%.1f" % ws[1][0] if len(ws) > 1 else ""))
            h = hist.setdefault(key, [0, 0.0]); h[0] += 1; h[1] = max(h[1], float(d[i]))
        for k, v in sorted(hist.items()):
            print("  along-forearm %.1f  %-36s n %3d deep %.3f" % (k[0], k[1], v[0], v[1]))
        sl = (Q[idx] - 0) ; print("  weapon-local long-axis range of hits: %.2f..%.2f" % ((sl - sdf["Weapon"][4]) @ sdf["Weapon"][3][0]).min() if False else "")

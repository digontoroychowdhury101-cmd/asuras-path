"""Blender: for SHOT frames, the deepest vertices of garment GROUP inside body SOLID (mesh_clash's own test), with each vertex's top bones.
Blender -b --factory-startup --python cdeep.py -- SHOT GROUP SOLID f1,f2,..."""
import sys, os
argv = sys.argv[sys.argv.index("--") + 1:]
shot, grp, solid, fl = argv[0], argv[1], argv[2], [int(x) for x in argv[3].split(",")]
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
src = open(ROOT + "/tools/blender/shen_import/mesh_clash.py").read()
src = src[:src.index("report = json.load(open(out_path))")]
sys.argv = ["x", "--", "/dev/null", "1"]
g = {"__file__": ROOT + "/tools/blender/shen_import/mesh_clash.py", "__name__": "mc"}
exec(compile(src, "mesh_clash", "exec"), g)
np, json = g["np"], g["json"]
data = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen_shots", shot + ".json")))
phase = data["phase"]
arm, props, groups = g["load"](phase)
sdf = g["load_sdf"](phase)
rest = {b.name: b.bone.matrix_local.copy() for b in arm.pose.bones}
maps = g["rigid_maps"](groups, [solid])
obs = groups[grp]
# per vertex: object, index, top 3 bones
meta = []
for ob in obs:
    names = {vg.index: vg.name for vg in ob.vertex_groups}
    for v in ob.data.vertices:
        top = sorted(((e.weight, names[e.group]) for e in v.groups), reverse=True)[:3]
        meta.append((ob.name, v.index, top))
def frame_pts(fr):
    g["pose"](arm, props, fr, rest)
    dg = g["bpy"].context.evaluated_depsgraph_get()
    return g["verts"](obs, dg, 10 ** 9)
names = set(data["frames"][0]["bones"])
bind = {"bones": {k: [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0] for k in names}, "props": {"Glaive": [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]}}
P0 = frame_pts(bind)
d0 = g["depth"](sdf[solid], P0)
base = d0 > g["MARGIN"]
for f in fl:
    fr = data["frames"][f]
    P = frame_pts(fr)
    v = fr["bones"]["Sk_" + solid]; R, t = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
    Q = (P - t) @ R
    d = g["depth"](sdf[solid], Q)
    deep = d > g["MARGIN"]
    if deep.any():
        d[np.nonzero(deep)[0][~g["rigid"](maps, solid, Q[deep])]] = 0.0
    d[base] = 0.0
    order = np.argsort(-d)
    n = int((d > g["MARGIN"]).sum())
    print("FRAME", f, "count", n, "of", len(d))
    tally = {}
    for k in order[:n]:
        for w, b in meta[k][2][:1]:
            tally[b] = tally.get(b, 0) + 1
    print("  top bone of clashing verts:", sorted(tally.items(), key=lambda x: -x[1])[:10])
    for k in order[:8]:
        print("  %.3f %s v%d rest %s solid-rest %s bones %s" % (d[k], meta[k][0], meta[k][1], np.round(P0[k], 2), np.round(Q[k], 2), [(b, round(w, 2)) for w, b in meta[k][2]]))

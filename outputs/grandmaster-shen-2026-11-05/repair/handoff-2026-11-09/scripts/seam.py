"""Measure skin cohesion at the arm seams on the real skinned GLB through a baked shot.
Blender -b --factory-startup --python seam.py -- SHOT [step]
For each vertex pair that touches in rest pose (< EPS) but is driven mainly by different arm bones, report the separation after posing."""
import json, math, os, sys
import bpy, bmesh
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
args = sys.argv[sys.argv.index("--") + 1:]
shot = args[0]
step = int(args[1]) if len(args) > 1 else 4
data = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen_shots", shot + ".json")))
phase = data["phase"]
bpy.ops.wm.read_factory_settings(use_empty=True)
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CI = C.inverted()
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Game.glb" % phase))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
CHAIN = {"Sk_LeftUpperArm", "Sk_LeftLowerArm", "Sk_LeftHand", "Sk_RightUpperArm", "Sk_RightLowerArm", "Sk_RightHand", "Sk_UpperTorso"}
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
# rest-pose world positions + dominant bone per vertex
pts = []  # (obj index, vi, co, bone)
for oi, o in enumerate(meshes):
    names = {g.index: g.name for g in o.vertex_groups}
    mw = o.matrix_world
    for v in o.data.vertices:
        if not v.groups:
            continue
        g = max(v.groups, key=lambda g: g.weight)
        b = names.get(g.group)
        if b in CHAIN:
            pts.append((oi, v.index, mw @ v.co, b, g.weight))
kd = KDTree(len(pts))
for i, p in enumerate(pts):
    kd.insert(p[2], i)
kd.balance()
EPS = 0.03
pairs = {}
for i, p in enumerate(pts):
    for co, j, d in kd.find_range(p[2], EPS):
        if j <= i:
            continue
        q = pts[j]
        if q[3] == p[3]:
            continue
        key = tuple(sorted((p[3], q[3])))
        if "Sk_UpperTorso" in key and not any("UpperArm" in k for k in key):
            continue
        pairs.setdefault(key, []).append((i, j))
for k, v in pairs.items():
    objs = sorted({meshes[pts[i][0]].name for i, j in v} | {meshes[pts[j][0]].name for i, j in v})
    print("SEAM", k, len(v), objs[:6])
# rest geometry summary: seam centroid vs bone heads
for k, v in pairs.items():
    c = sum((pts[i][2] for i, j in v), Vector()) / len(v)
    print("CENTROID", k, tuple(round(x, 3) for x in c))
for b in arm.data.bones:
    if b.name in CHAIN:
        print("HEAD", b.name, tuple(round(x, 3) for x in arm.matrix_world @ b.head_local))
pose_bones = arm.pose.bones
rest = {b.name: b.bone.matrix_local.copy() for b in pose_bones}


def mat34(v):
    return Matrix(((v[0], v[1], v[2], v[9]), (v[3], v[4], v[5], v[10]), (v[6], v[7], v[8], v[11]), (0, 0, 0, 1)))


frames = data["frames"]
worst = {}
need = {}
for k, v in pairs.items():
    for i, j in v:
        for x in (i, j):
            need.setdefault(pts[x][0], set()).add(pts[x][1])
out = []
for f in range(0, len(frames), step):
    fr = frames[f]
    for name, v in fr["bones"].items():
        pb = pose_bones.get(name)
        if pb is not None:
            pb.matrix = (C @ mat34(v) @ CI) @ rest[name]
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    pos = {}
    for oi, vis in need.items():
        o = meshes[oi]
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = o.matrix_world
        for vi in vis:
            pos[(oi, vi)] = mw @ me.vertices[vi].co
        ev.to_mesh_clear()
    row = [f]
    for k, v in pairs.items():
        gaps = sorted(((pos[(pts[i][0], pts[i][1])] - pos[(pts[j][0], pts[j][1])]).length - (pts[i][2] - pts[j][2]).length) for i, j in v)
        g95 = gaps[int(len(gaps) * 0.95)] if gaps else 0
        gm = gaps[-1] if gaps else 0
        w = worst.setdefault(k, [0, 0, -1])
        if gm > w[0]:
            w[0], w[2] = gm, f
        w[1] = max(w[1], g95)
        row.append("%s=%.3f/%.3f" % ("".join(x[3:7] for x in k), g95, gm))
    out.append(row)
    print("F", *row)
for k, w in worst.items():
    print("WORST", k, "max %.3f  p95 %.3f  at frame %d" % tuple(w))

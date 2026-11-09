"""Mesh clash check for baked Grandmaster Shen shots (cloth_bake.py) on the real skinned GLB: where one surface passes into another.

    Blender -b --factory-startup --python tools/blender/shen_import/mesh_clash.py -- OUT.json [step] SHOT [SHOT ...]

Every frame is posed exactly as review.py poses it (the file's own bones and weights, the game's cloth), and every vertex of the skinned body,
the hands, the garments and the glaive is taken from the evaluated meshes. Inside is measured against the solids of the body parts and the
glaive: signed distance fields of the real meshes (tools/blender/shen_import/body_sdf.py; winding-number signs, so the sculpt's open hems and
cuts do not fool it), each carried by its own bone. Pairs:
  weapon in <part>    glaive vertices inside a body part
  <group> in weapon   body, hand or garment vertices inside the glaive (hands at a larger margin: they hold it)
  <garment> in <part> garment vertices inside a body part
A point counts past MARGIN deep, and inside a body part only where that part's surface nearby is skinned to its own bone (weight over RIGID):
each solid is carried rigidly by its bone, which near a joint (the shoulder, the hip) is not where the blended skin really is. Points already that deep at the shot's first frame (the sculpt's own overlaps, a garment resting on him) are
not counted. Writes, per shot and pair, the share of frames with a clash, the deepest (rig units, 1 = 1.3 studs) and the frame.
"""
import json
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

HERE = os.path.dirname(os.path.abspath(__file__))
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
args = sys.argv[sys.argv.index("--") + 1:]
out_path = args[0]
step = int(args[1])
shots = args[2:]
MARGIN, HAND_MARGIN = 0.03, 0.05
RIGID = 0.8
BODY = ("Head", "UpperTorso", "LowerTorso", "RightUpperArm", "RightLowerArm", "LeftUpperArm", "LeftLowerArm", "RightUpperLeg", "RightLowerLeg", "LeftUpperLeg", "LeftLowerLeg")
HANDS = ("RightHand", "LeftHand")
CLOTH = ("RobeBack", "RobeRight", "RobeLeft", "RobeInner", "RobeFront", "RightMantle", "LeftMantle", "LeftSleeve", "RibbonRight", "RibbonLeft", "HairBack", "Beard", "Beads")
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CI = C.inverted()
CIn = np.array(CI)[:3, :3]


def mat34(v):
    return Matrix(((v[0], v[1], v[2], v[9]), (v[3], v[4], v[5], v[10]), (v[6], v[7], v[8], v[11]), (0, 0, 0, 1)))


def load_sdf(phase):
    """Every solid's (grid, origin, step, axes, centre): the body parts' fields in rig space, the glaive's along its own axes."""
    out = {}
    for f in ("sdf_p%d.npz", "sdf_p%d_Weapon.npz"):
        if not os.path.exists(os.path.join(ROOT, "work/shen_import", f % phase)):
            print("no", f % phase, flush=True)
            continue
        d = np.load(os.path.join(ROOT, "work/shen_import", f % phase))
        opt = lambda k: d[k] if k in d.files else None
        for k in d.files:
            if k.endswith("_grid"):
                n = k[:-5]
                out[n] = (d[k], d[n + "_origin"], float(d[n + "_step"]), opt(n + "_axes"), opt(n + "_centre"))
    return out


def depth(sdf, P):
    """Depth inside (positive) of rest-space points, trilinear in the distance field; points off the grid are outside."""
    grid, lo, st, axes, centre = sdf
    if axes is not None:
        P = (P - centre) @ axes.T
    q = (P - lo) / st
    n = np.array(grid.shape) - 1
    i0 = np.clip(np.floor(q).astype(int), 0, n - 1)
    f = np.clip(q - i0, 0.0, 1.0)
    v = np.zeros(len(P))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                v += w * grid[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
    v[np.any((q < 0) | (q > n), axis=1)] = 1.0
    return -v


def load(phase):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Game.glb" % phase))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Props.glb" % phase))
    info = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen%d/pieces.json" % phase)))
    props, groups = [], {}
    for ob in bpy.data.objects:
        base = ob.name.split(".")[0]
        if ob.type != "MESH" or base not in info:
            continue
        groups.setdefault(info[base].get("group"), []).append(ob)
        if ob not in before:
            props.append((ob, info[base].get("bone"), ob.matrix_world.copy()))
    return arm, props, groups


def pose(arm, props, fr, rest):
    arm.matrix_world = Matrix.Identity(4)   # root space: travel and heading do not change what touches what
    for name, v in fr["bones"].items():
        pb = arm.pose.bones.get(name)
        if pb is not None:
            pb.matrix = (C @ mat34(v) @ CI) @ rest[name]
    for ob, bone, base in props:
        M = fr["props"].get(bone) if bone else None
        if M:
            ob.matrix_world = (C @ Matrix([M[0:4], M[4:8], M[8:12], M[12:16]]) @ CI) @ base
    bpy.context.view_layer.update()


def verts(objs, dg, keep):
    """A group's evaluated (skinned) vertices in rig space, thinned to about `keep`."""
    out = []
    for ob in objs:
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        M = np.array(ob.matrix_world)
        co = co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]
        out.append(co @ CIn.T)
    P = np.vstack(out)
    k = max(1, len(P) // keep)
    ID = [(ob, i) for ob in objs for i in range(len(ob.data.vertices))]
    return P[::k], ID[::k]


def rigid_maps(groups, parts):
    """Per body part, a KD-tree over its rest vertices (rig space) and each one's weight to the part's own bone."""
    out = {}
    for g in parts:
        pts, w = [], []
        for ob in groups[g]:
            vg = ob.vertex_groups.get("Sk_" + g)
            M = CI @ ob.matrix_world
            for v in ob.data.vertices:
                pts.append(M @ v.co)
                w.append(next((e.weight for e in v.groups if vg is not None and e.group == vg.index), 0.0))
        kd = KDTree(len(pts))
        for i, q in enumerate(pts):
            kd.insert(q, i)
        kd.balance()
        out[g] = (kd, np.array(w))
    return out


def rigid(maps, part, Q):
    """Whether each rest-space point lies where the part's own surface is rigid on its bone."""
    if part not in maps:
        return np.ones(len(Q), bool)
    kd, w = maps[part]
    return np.array([w[kd.find(Vector(q))[1]] > RIGID for q in Q], bool)


def shot_report(name):
    data = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen_shots", name + ".json")))
    phase = data["phase"]
    arm, props, groups = load(phase)
    sdf = load_sdf(phase)
    rest = {b.name: b.bone.matrix_local.copy() for b in arm.pose.bones}
    body = [g for g in BODY if g in groups and g in sdf]
    maps = rigid_maps(groups, body)
    cloth = [g for g in CLOTH if g in groups]
    pairs, baseline = {}, {}
    frames = data["frames"]
    idx = list(range(0, len(frames), step))
    for f in idx:
        fr = frames[f]
        pose(arm, props, fr, rest)
        dg = bpy.context.evaluated_depsgraph_get()
        vv = {g: verts(groups[g], dg, 2500 if g == "Weapon" else 1500) for g in body + cloth + list(HANDS) + ["Weapon"]}
        pts = {g: v[0] for g, v in vv.items()}
        ids = {g: v[1] for g, v in vv.items()}
        # each solid's map from posed rig space back to its rest space: p_rest = R^T (p - t)
        to_rest = {}
        for g in body:
            v = fr["bones"]["Sk_" + g]
            to_rest[g] = (np.array(v[:9]).reshape(3, 3), np.array(v[9:12]))
        G = np.array(fr["props"]["Glaive"]).reshape(4, 4)
        to_rest["Weapon"] = (G[:3, :3], G[:3, 3])
        tests = [("weapon in " + g, "Weapon", g, MARGIN) for g in body]
        tests += [(g + " in weapon", g, "Weapon", MARGIN) for g in body + cloth]
        tests += [(h + " in weapon", h, "Weapon", HAND_MARGIN) for h in HANDS]
        tests += [(c + " in " + g, c, g, MARGIN) for c in cloth for g in body]
        for key, src, solid, margin in tests:
            if solid not in sdf:
                continue
            R, t = to_rest[solid]
            Q = (pts[src] - t) @ R
            d = depth(sdf[solid], Q)
            deep = d > margin
            if deep.any():
                d[np.nonzero(deep)[0][~rigid(maps, solid, Q[deep])]] = 0.0
            if f == idx[0]:
                baseline[key] = d > margin
                continue
            dd = np.where(baseline[key], 0.0, d)
            worst = float(np.max(dd))
            if True:
                for j in np.nonzero(dd > margin)[0]:
                    ob, vi = ids[src][j]
                    D = DIAG.setdefault(key, {})
                    k2 = (ob.name, vi)
                    if dd[j] > D.get(k2, (0,))[0]:
                        D[k2] = (float(dd[j]), f)
            if worst > margin:
                s = pairs.setdefault(key, [0, 0.0, 0])
                s[0] += 1
                if worst > s[1]:
                    s[1], s[2] = worst, f
    n = len(idx) - 1
    res = {k: {"share": round(v[0] / max(n, 1), 3), "deepest": round(v[1], 3), "frame": v[2]} for k, v in pairs.items()}
    print("CLASH", name, n, json.dumps(dict(sorted(res.items(), key=lambda kv: -kv[1]["share"]))), flush=True)
    return {"frames": n, "pairs": res}


DIAG = {}
def body_frac(ob, vi):
    v = ob.data.vertices[vi]
    names = {g.index: g.name for g in ob.vertex_groups}
    tot = sum(e.weight for e in v.groups) or 1
    sk = sum(e.weight for e in v.groups if names.get(e.group, "").startswith("Sk_"))
    top = sorted(((e.weight, names.get(e.group)) for e in v.groups), reverse=True)[:3]
    return sk / tot, top
def dump():
    out = {}
    for key, D in DIAG.items():
        rows = []
        for (on, vi), (dep, f) in sorted(D.items(), key=lambda kv: -kv[1][0])[:400]:
            ob = bpy.data.objects[on]
            bf, top = body_frac(ob, vi)
            co = CI @ ob.matrix_world @ ob.data.vertices[vi].co
            rows.append([on, vi, round(dep, 3), f, round(bf, 2), [list(co)], [[round(w, 2), n] for w, n in top]])
        out[key] = rows
    json.dump(out, open(out_path.replace(".json", "_diag.json"), "w"))
report = json.load(open(out_path)) if os.path.exists(out_path) else {}
for s in shots:
    report[s] = shot_report(s)
    json.dump(report, open(out_path, "w"), indent=1)
    dump()

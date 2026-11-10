# xray_why.py : (Windows pass 2026-11-11) Why review.py's arm x-ray and the validator disagree on an arm in his upper torso.
#   blender -b --factory-startup --python xray_why.py -- OUT.json SHOT [SHOT ...]
# Poses each shot exactly as review.py does (the GLB's own bones and weights) and applies review.py's x-ray test (SHEN_REVIEW_CLASH=UpperTorso,
# CLASH_FROM = both arms and hands: evaluated arm-mesh vertices past 0.03 inside sdf_p<phase>.npz's UpperTorso, nearest torso surface rigid on its
# bone, not already lit in the bind pose). Every lit vertex is then sorted by what the validator (shen_lib.arm_torso_world, dense) would make of it:
#   arm      follows an arm or hand bone most and sat at least 0.05 clear of the torso solid at rest: a sample the validator counts
#   near     follows an arm or hand bone most but sat within 0.05 of the torso solid at rest: the validator leaves it out (_torso_free)
#   torso    follows UpperTorso (or another non-arm bone) most: the validator files it under the torso's samples, not the arm's
# Writes per shot and class the deepest depth, its frame, how many frames have one, and at the deepest frame the vertex's mesh, bones and rest gap.
# Blender evidence only: no rendering, nothing written beside OUT.json.
import json
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix
from mathutils.kdtree import KDTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
args = sys.argv[sys.argv.index("--") + 1:]
out_path, shots = args[0], args[1:]
ARMS = ("LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand")
ARM_BONES = {"Sk_" + a for a in ARMS}
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CI = C.inverted()
CIn = np.array(Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0))))


def mat34(v):
    return Matrix(((v[0], v[1], v[2], v[9]), (v[3], v[4], v[5], v[10]), (v[6], v[7], v[8], v[11]), (0, 0, 0, 1)))


results = {}
loaded = None
for shot in shots:
    data = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen_shots", shot + ".json")))
    phase = data["phase"]
    if loaded != phase:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Game.glb" % phase))
        arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        info = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen%d/pieces.json" % phase)))
        group = lambda o: info.get(o.name.split(".")[0], {}).get("group")
        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
        sdf = np.load(os.path.join(ROOT, "work/shen_import/sdf_p%d.npz" % phase))
        s_grid, s_lo, s_st = sdf["UpperTorso_grid"], sdf["UpperTorso_origin"], float(sdf["UpperTorso_step"])
        pts, wts = [], []
        for ob in (o for o in meshes if group(o) == "UpperTorso"):
            vg = ob.vertex_groups.get("Sk_UpperTorso")
            M = np.array(ob.matrix_world)
            for v in ob.data.vertices:
                pts.append(CIn @ (M[:3, :3] @ np.array(v.co) + M[:3, 3]))
                wts.append(next((e.weight for e in v.groups if vg is not None and e.group == vg.index), 0.0))
        kd = KDTree(len(pts))
        for i, q in enumerate(pts):
            kd.insert(q, i)
        kd.balance()
        wts = np.array(wts)
        gobs = [o for o in meshes if group(o) in ARMS]
        meta = {}
        for ob in gobs:
            n = len(ob.data.vertices)
            co = np.empty(n * 3)
            ob.data.vertices.foreach_get("co", co)
            M = np.array(ob.matrix_world)
            rest = (co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]) @ CIn.T
            names = {g.index: g.name for g in ob.vertex_groups}
            dom, domw, torw = [], np.zeros(n), np.zeros(n)
            for i, v in enumerate(ob.data.vertices):
                gs = sorted(((e.weight, names.get(e.group, "?")) for e in v.groups), reverse=True)
                dom.append(gs[0][1] if gs else "?")
                domw[i] = gs[0][0] if gs else 0.0
                torw[i] = sum(w for w, b in gs if b == "Sk_UpperTorso")
            meta[ob.name] = {"rest": rest, "dom": dom, "domw": domw, "torw": torw}
        pose_bones = arm.pose.bones
        rest_m = {b.name: b.bone.matrix_local.copy() for b in pose_bones}
        loaded = phase

    def depth(Q):
        q = (Q - s_lo) / s_st
        hi = np.array(s_grid.shape) - 1
        i0 = np.clip(np.floor(q).astype(int), 0, hi - 1)
        f = np.clip(q - i0, 0.0, 1.0)
        d = np.zeros(len(Q))
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    wgt = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                    d += wgt * s_grid[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
        d[np.any((q < 0) | (q > hi), axis=1)] = 1.0
        return -d

    def lit(d, Q):
        hit = d > 0.03
        for i in np.nonzero(hit)[0]:
            if wts[kd.find(Q[i])[1]] <= 0.8:
                hit[i] = False
        return hit

    for ob in gobs:     # bind-pose depth (signed: + inside) and review.py's bind-pose exclusion, in the torso's rest space = rig space at rest
        m = meta[ob.name]
        m["rest_d"] = depth(m["rest"])
        m["base"] = lit(m["rest_d"], m["rest"])
    best = {k: {"deepest": 0.0, "frame": None, "frames": 0, "at": None} for k in ("arm", "near", "torso")}
    per_frame = []
    span = [int(s) for s in os.environ.get("XRAYWHY_FRAMES", "0:100000").split(":")]     # optional first:last (inclusive) shot frames
    for f, fr in enumerate(data["frames"]):
        if not span[0] <= f <= span[1]:
            per_frame.append({"frame": f, "arm": 0.0, "near": 0.0, "torso": 0.0})
            continue
        x, y, z, yaw = fr["root"]
        arm.matrix_world = Matrix.Translation((0, 0, y)) @ Matrix.Rotation(yaw, 4, "Z")
        for name, v in fr["bones"].items():
            pb = pose_bones.get(name)
            if pb is not None:
                pb.matrix = (C @ mat34(v) @ CI) @ rest_m[name]
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        v = fr["bones"]["Sk_UpperTorso"]
        R, t = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
        got = {k: (0.0, None) for k in best}
        for ob in gobs:
            ev = ob.evaluated_get(dg)
            me = ev.to_mesh()
            co = np.empty(len(me.vertices) * 3)
            me.vertices.foreach_get("co", co)
            ev.to_mesh_clear()
            M = np.array(arm.matrix_world.inverted() @ ob.matrix_world)
            P = (co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]) @ CIn.T
            Q = (P - t) @ R
            d = depth(Q)
            m = meta[ob.name]
            hit = lit(d, Q) & ~m["base"]
            for i in np.nonzero(hit)[0]:
                k = "torso" if m["dom"][i] not in ARM_BONES else ("arm" if m["rest_d"][i] < -0.05 else "near")
                if d[i] > got[k][0]:
                    got[k] = (float(d[i]), {"mesh": group(ob), "vertex": int(i), "bone": m["dom"][i], "bone_w": round(float(m["domw"][i]), 3),
                                            "torso_w": round(float(m["torw"][i]), 3), "rest_depth": round(float(m["rest_d"][i]), 3)})
        row = {"frame": f}
        for k, (dk, at) in got.items():
            row[k] = round(dk, 3)
            if dk > 0:
                best[k]["frames"] += 1
                if dk > best[k]["deepest"]:
                    best[k].update(deepest=round(dk, 3), frame=f, at=at)
        per_frame.append(row)
    results[shot] = {"frames": len(data["frames"]), "classes": best, "per_frame": per_frame}
    print("XRAYWHY %s %s" % (shot, " ".join("%s %.3f f%s (%d fr)" % (k, b["deepest"], b["frame"], b["frames"]) for k, b in best.items())), flush=True)
json.dump(results, open(out_path, "w"), indent=1)
print("XRAYWHY done", out_path)

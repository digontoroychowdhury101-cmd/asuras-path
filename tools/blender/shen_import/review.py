"""Render a baked shot (cloth_bake.py) on the real skinned GLB: every vertex moves through the file's own bones and weights. Blender evidence only: no VFX, no sound, no Studio.

    Blender -b --factory-startup --python tools/blender/shen_import/review.py -- SHOT OUTDIR [camera] [first:last:step] [WxH]
camera: combat (the player's camera, a little to his right), side, back, front, quarter. Writes OUTDIR/f_<n>.png
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
args = sys.argv[sys.argv.index("--") + 1:]
shot, out = args[0], args[1]
camera = args[2] if len(args) > 2 else "combat"
span = [int(x) if x else None for x in args[3].split(":")] if len(args) > 3 else [None, None, 1]
size = [int(x) for x in args[4].split("x")] if len(args) > 4 else (854, 480)
os.makedirs(out, exist_ok=True)
data = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen_shots", shot + ".json")))
phase = data["phase"]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
try:
    sc.render.engine = "BLENDER_EEVEE"
except TypeError:
    sc.render.engine = "BLENDER_EEVEE_NEXT"
try:
    sc.eevee.taa_render_samples = 6
except AttributeError:
    pass
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CI = C.inverted()
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Game.glb" % phase))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in bpy.data.objects:
    if o.type == "MESH" and o.data.materials:
        for m in o.data.materials:
            m.use_backface_culling = False
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Props.glb" % phase))
info = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen%d/pieces.json" % phase)))
props = []
for ob in set(bpy.data.objects) - before:
    base = ob.name.split(".")[0]
    if ob.type == "MESH" and base in info:
        props.append((ob, info[base]["bone"], ob.matrix_world.copy()))
# (2026-11-07) SHEN_REVIEW_CLASH=<part> (e.g. RightLowerArm): that part is drawn see-through and every weapon vertex inside it is lit magenta, by the same
# test as mesh_clash.py (its distance field, past MARGIN 0.03, where the part's surface is rigid on its own bone), so a before/after shows what the numbers count
CLASH = os.environ.get("SHEN_REVIEW_CLASH")
if CLASH:
    import numpy as np
    from mathutils.kdtree import KDTree
    CIn = np.array(Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))) # Blender (z up) to rig space (y up)
    sdf = np.load(os.path.join(ROOT, "work/shen_import/sdf_p%d.npz" % phase))
    s_grid, s_lo, s_st = sdf[CLASH + "_grid"], sdf[CLASH + "_origin"], float(sdf[CLASH + "_step"])
    part_obs = [o for o in before if o.type == "MESH" and info.get(o.name.split(".")[0], {}).get("group") == CLASH]
    pts, wts = [], []
    for ob in part_obs:
        vg = ob.vertex_groups.get("Sk_" + CLASH)
        M = np.array(ob.matrix_world)
        for v in ob.data.vertices:
            pts.append(CIn @ (M[:3, :3] @ np.array(v.co) + M[:3, 3]))
            wts.append(next((e.weight for e in v.groups if vg is not None and e.group == vg.index), 0.0))
    kd = KDTree(len(pts))
    for i, q in enumerate(pts):
        kd.insert(q, i)
    kd.balance()
    wts = np.array(wts)
    xm = bpy.data.materials.new("xray")
    xm.use_nodes = True
    bs = next(n for n in xm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (0.5, 0.12, 0.1, 1)
    bs.inputs["Alpha"].default_value = 0.3
    try:
        xm.surface_render_method = "BLENDED"
    except (AttributeError, TypeError):
        xm.blend_method = "BLEND"
    xm.use_backface_culling = False
    for ob in part_obs:
        for slot in ob.material_slots:
            slot.material = xm
    wobs = [ob for ob, bone, base in props if info.get(ob.name.split(".")[0], {}).get("group") == "Weapon"]
    # (2026-11-08) SHEN_REVIEW_CLASH_FROM=<garment group>[,<group>...] (e.g. RobeFront,RobeLeft): light those garments' skinned vertices inside the part
    # instead of the weapon's
    CLASH_FROM = os.environ.get("SHEN_REVIEW_CLASH_FROM")
    gobs = [o for o in before if o.type == "MESH" and info.get(o.name.split(".")[0], {}).get("group") in CLASH_FROM.split(",")] if CLASH_FROM else []
    gbase = {}     # per garment object: its vertices already inside the part in the bind pose (filled on the first frame)
    wrest = {}
    for ob in (gobs or wobs):     # only what is lit gets the colour (a fresh attribute is not black)
        M = np.array(ob.matrix_world)
        co = np.empty(len(ob.data.vertices) * 3)
        ob.data.vertices.foreach_get("co", co)
        wrest[ob.name] = (co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]) @ CIn.T     # rig-space rest positions (the props file stands at rest)
        attr = ob.data.color_attributes.new("clash", "FLOAT_COLOR", "POINT")
        for m in {s.material for s in ob.material_slots if s.material}:
            if m.get("_clash"):
                continue
            m["_clash"] = 1
            nt = m.node_tree
            outn = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
            src = outn.inputs["Surface"].links[0].from_socket
            at = nt.nodes.new("ShaderNodeAttribute")
            at.attribute_name = "clash"
            em = nt.nodes.new("ShaderNodeEmission")
            em.inputs["Color"].default_value = (1.0, 0.0, 0.85, 1)
            em.inputs["Strength"].default_value = 4.0
            mx = nt.nodes.new("ShaderNodeMixShader")
            nt.links.new(at.outputs["Fac"], mx.inputs["Fac"])
            nt.links.new(src, mx.inputs[1])
            nt.links.new(em.outputs["Emission"], mx.inputs[2])
            nt.links.new(mx.outputs["Shader"], outn.inputs["Surface"])


def part_depth(Q):
    """How deep each point (in the CLASH part's rest space) lies inside it, and whether it counts: mesh_clash.py's test (past 0.03, where the
    part's own surface is rigid on its bone)."""
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
    d = -d
    hit = d > 0.03
    for i in np.nonzero(hit)[0]:
        if wts[kd.find(Q[i])[1]] <= 0.8:
            hit[i] = False
    return d, hit


def light_clash(fr):
    """Mark this frame's weapon (or CLASH_FROM garment) vertices inside the CLASH part; returns how many and the deepest."""
    v = fr["bones"]["Sk_" + CLASH]
    R, t = np.array(v[:9]).reshape(3, 3), np.array(v[9:12])
    G = np.array(fr["props"]["Glaive"]).reshape(4, 4)
    n, deepest = 0, 0.0
    if CLASH_FROM:
        dg = bpy.context.evaluated_depsgraph_get()
    for ob in (gobs if CLASH_FROM else wobs):
        if CLASH_FROM:
            ev = ob.evaluated_get(dg)
            me = ev.to_mesh()
            co = np.empty(len(me.vertices) * 3)
            me.vertices.foreach_get("co", co)
            ev.to_mesh_clear()
            M = np.array(arm.matrix_world.inverted() @ ob.matrix_world)     # root space, as the frame's bones are (he travels and turns in the render)
            P = (co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]) @ CIn.T
        else:
            P = wrest[ob.name] @ G[:3, :3].T + G[:3, 3]
        d, hit = part_depth((P - t) @ R)
        if CLASH_FROM:
            if ob.name not in gbase:
                gbase[ob.name] = part_depth(wrest[ob.name])[1]   # the bind pose: every bone at rest, so rig space is the part's rest space
            hit &= ~gbase[ob.name]     # inside already in the bind pose (the sculpt's own overlap): mesh_clash.py does not count it either
        col = np.zeros((len(P), 4))
        col[hit] = 1.0
        ob.data.color_attributes["clash"].data.foreach_set("color", col.ravel())
        ob.data.update()
        n += int(hit.sum())
        deepest = max(deepest, float(d[hit].max()) if hit.any() else 0.0)
    return n, deepest


w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.43, 0.46, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.7
sc.world = w
for name, rot, energy in (("key", (55, 0, 35), 3.0), ("fill", (70, 0, -60), 1.2), ("rim", (120, 0, 170), 1.5)):
    li = bpy.data.lights.new(name, "SUN")
    li.energy = energy
    ob = bpy.data.objects.new(name, li)
    ob.rotation_euler = tuple(math.radians(a) for a in rot)
    sc.collection.objects.link(ob)
# a tiled floor that scrolls with his travel, so sliding feet show
bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, -3.1924))
floor = bpy.context.active_object
mat = bpy.data.materials.new("floor")
mat.use_nodes = True
nt = mat.node_tree
ck = nt.nodes.new("ShaderNodeTexChecker")
ck.inputs["Scale"].default_value = 1.0
ck.inputs["Color1"].default_value = (0.24, 0.24, 0.26, 1)
ck.inputs["Color2"].default_value = (0.3, 0.3, 0.32, 1)
tc = nt.nodes.new("ShaderNodeTexCoord")
mp = nt.nodes.new("ShaderNodeMapping")
nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
mp.inputs["Scale"].default_value = (0.5, 0.5, 0.5)
nt.links.new(mp.outputs["Vector"], ck.inputs["Vector"])
nt.links.new(ck.outputs["Color"], nt.nodes["Principled BSDF"].inputs[0])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
floor.data.materials.append(mat)
sc.render.resolution_x, sc.render.resolution_y = size
sc.render.image_settings.file_format = "PNG"
cam = bpy.data.cameras.new("c")
cam.lens = 62
cam.sensor_fit, cam.sensor_height = "VERTICAL", 36   # the same framing of him at any aspect ratio
cam.clip_start = 0.02   # (2026-11-07) close-ups of the hands: the default near plane cut the haft off in front of the lens
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
SPOTS = {"head": (3.2, 7.5, 3.2), "face": (1.1, 3.2, 0.75), "combat": (9.0, 11.5, 1.6), "side": (10.5, 0, -0.2), "lside": (-10.5, 0, -0.2), "front": (0, 10.5, 0.0), "back": (0, -10.5, 0.0), "quarter": (7.5, 7.5, 0.4), "backq": (-7.0, -8.0, 0.8), "low": (7, 8, -2.0), "lhand": (-1.6, 2.6, 0.9), "lhandside": (-3.0, 0.4, 0.3), "lhandlow": (-1.2, 2.0, -1.6), "lhandtop": (-0.5, 0.7, 2.4), "lhandfront": (0.2, 3.0, 0.1), "rhand": (2.2, 2.2, 0.9),
         # (2026-11-07) close-ups that ride a joint and turn with him (the offset is in his own frame): the knees for the robe, the forearm for the haft
         "rknee": (2.2, 2.6, 0.4), "rkneeside": (3.4, 0.2, 0.3), "rkneeback": (1.6, -3.0, 0.4), "lknee": (-2.2, 2.6, 0.4), "lkneeside": (-3.4, 0.2, 0.3),
         "rarm": (2.0, 2.4, 0.6), "rarmside": (3.2, 0.0, 0.4), "rarmtop": (0.8, 0.8, 3.0),
         "rthigh": (2.4, 3.0, 0.2), "rthighside": (3.8, 0.0, 0.1), "lthigh": (-2.4, 3.0, 0.2),
         # (2026-11-07) the inside of the right forearm, two-thirds of the way to the wrist, where the haft behind the fist runs along it
         "rforelow": (1.0, 1.8, -1.3), "rforeclose": (0.55, 1.05, -0.75), "rforeback": (1.3, -0.3, -0.9), "rforeout": (1.6, 0.7, -0.15),
         # (2026-11-09) the beard on his chest, riding the neck so a kneel or a bow keeps it in frame
         "chestside": (2.6, 0.5, -0.5), "chestfront": (0.7, 2.7, -0.4)}
RIDE = {"chest": "Sk_Head", "rknee": "Sk_RightLowerLeg", "lknee": "Sk_LeftLowerLeg", "rarm": "Sk_RightLowerArm", "rthigh": "Sk_RightUpperLeg", "lthigh": "Sk_LeftUpperLeg"}
# phase 2 floats, so the camera rises with him; SHEN_REVIEW_GROUNDED=1 frames him on the floor instead (his deaths)
floats = phase == 2 and os.environ.get("SHEN_REVIEW_GROUNDED") != "1"
BASE = Vector(SPOTS[camera]) + Vector((0, 0, 1.55 if floats else 0))
co.location = BASE
co.rotation_euler = (Vector((0.75 if camera == "face" else 0, 0, (2.45 if camera == "face" else 3.4) if phase == 2 and camera in ("head", "face") else 1.9 if camera in ("head", "face") else (0.9 if floats else -0.45))) - BASE).to_track_quat("-Z", "Y").to_euler()
frames = data["frames"]
first, last, step = span[0] or 0, span[1] if span[1] is not None else len(frames) - 1, span[2] or 1
pose_bones = arm.pose.bones
rest = {b.name: b.bone.matrix_local.copy() for b in pose_bones}


def mat34(v):
    return Matrix(((v[0], v[1], v[2], v[9]), (v[3], v[4], v[5], v[10]), (v[6], v[7], v[8], v[11]), (0, 0, 0, 1)))


for f in range(first, last + 1, step):
    fr = frames[f]
    x, y, z, yaw = fr["root"]
    Ry = Matrix.Rotation(yaw, 4, "Z")  # his yaw about up: in the rig +yaw turns toward -X, the same turn as Blender's +Z seen from above after the axis swap
    arm.matrix_world = Matrix.Translation((0, 0, y)) @ Ry
    co.location = BASE + Vector((0, 0, y * 0.9))   # he stays in frame through a leap, and the floor falling away shows the height
    # the floor slides under him
    floor.location = (-(x % 2.0), z % 2.0, -3.1924)
    for name, v in fr["bones"].items():
        pb = pose_bones.get(name)
        if pb is None:
            continue
        pb.matrix = (C @ mat34(v) @ CI) @ rest[name]
    for ob, bone, base in props:
        M = fr["props"].get(bone)
        if M:
            ob.matrix_world = Matrix.Translation((0, 0, y)) @ Ry @ (C @ Matrix([M[0:4], M[4:8], M[8:12], M[12:16]]) @ CI) @ base
    bpy.context.view_layer.update()
    if camera.startswith(("lhand", "rhand")):   # a close look at the wrist seam: the camera rides beside the hand
        hb = pose_bones.get("Sk_LeftHand" if camera.startswith("lhand") else "Sk_RightHand")
        at = arm.matrix_world @ hb.head
        co.location = at + Vector(SPOTS[camera])
        co.rotation_euler = (at - co.location).to_track_quat("-Z", "Y").to_euler()
    ride = next((b for k, b in RIDE.items() if camera.startswith(k)), None)
    if camera.startswith("rfore"):
        a, b = arm.matrix_world @ pose_bones["Sk_RightLowerArm"].head, arm.matrix_world @ pose_bones["Sk_RightHand"].head
        at = a.lerp(b, 0.65)
        co.location = at + Ry.to_3x3() @ Vector(SPOTS[camera])
        co.rotation_euler = (at - co.location).to_track_quat("-Z", "Y").to_euler()
    elif ride:
        at = arm.matrix_world @ pose_bones[ride].head
        co.location = at + Ry.to_3x3() @ Vector(SPOTS[camera])
        co.rotation_euler = (at - co.location).to_track_quat("-Z", "Y").to_euler()
    if CLASH:
        n, deepest = light_clash(fr)
        print("CLASH frame %d: %d %s vertices in %s, deepest %.3f" % (f, n, CLASH_FROM or "weapon", CLASH, deepest), flush=True)
    sc.render.filepath = os.path.join(out, "f_%05d.png" % f)
    bpy.ops.render.render(write_still=True)
print("REVIEW", first, last, step)

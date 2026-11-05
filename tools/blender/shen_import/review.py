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
floor.data.materials.append(mat)
sc.render.resolution_x, sc.render.resolution_y = size
sc.render.image_settings.file_format = "PNG"
cam = bpy.data.cameras.new("c")
cam.lens = 62
cam.sensor_fit, cam.sensor_height = "VERTICAL", 36   # the same framing of him at any aspect ratio
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
SPOTS = {"combat": (9.0, 11.5, 1.6), "side": (10.5, 0, -0.2), "lside": (-10.5, 0, -0.2), "front": (0, 10.5, 0.0), "back": (0, -10.5, 0.0), "quarter": (7.5, 7.5, 0.4), "backq": (-7.0, -8.0, 0.8), "low": (7, 8, -2.0)}
BASE = Vector(SPOTS[camera])
co.location = BASE
co.rotation_euler = (Vector((0, 0, -0.45)) - BASE).to_track_quat("-Z", "Y").to_euler()
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
    sc.render.filepath = os.path.join(out, "f_%05d.png" % f)
    bpy.ops.render.render(write_still=True)
print("REVIEW", first, last, step)

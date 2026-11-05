"""Pose the real game pieces by their real bones in Blender: the rigid-joint stress test before anything goes near Studio. Nothing is saved.

    GLB=assets/build/grandmaster_shen/Shen_P1_Game.glb Blender -b --factory-startup --python tools/blender/shen_import/pose_test.py -- PHASE OUTDIR
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path.insert(0, HERE)
args = sys.argv[sys.argv.index("--") + 1:]
phase, out = int(args[0]), args[1]
os.makedirs(out, exist_ok=True)
import importlib.util  # noqa: E402
sys.modules.setdefault("numpy", __import__("numpy"))
import rigdef as RD  # noqa: E402
JOINT, HELPER = RD.JOINT[phase], RD.HELPER[phase]
info = json.load(open(os.path.join(ROOT, f"work/opening_cast_bake/shen{phase}/pieces.json")))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, f"assets/build/grandmaster_shen/Shen_P{phase}_Game.glb"))
sc = bpy.context.scene
try:
    sc.render.engine = "BLENDER_EEVEE"
except TypeError:
    sc.render.engine = "BLENDER_EEVEE_NEXT"
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
sc.world = w
for name, rot, energy in (("key", (55, 0, 35), 3.0), ("fill", (70, 0, -60), 1.2), ("rim", (120, 0, 170), 1.5)):
    li = bpy.data.lights.new(name, "SUN")
    li.energy = energy
    ob = bpy.data.objects.new(name, li)
    ob.rotation_euler = tuple(math.radians(a) for a in rot)
    sc.collection.objects.link(ob)
sc.render.resolution_x, sc.render.resolution_y = 800, 900
cam = bpy.data.cameras.new("c")
cam.type = "ORTHO"
cam.ortho_scale = 8.5
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
PARENT = {k: v[0] for k, v in JOINT.items()}
AT = {k: Vector(v[1]) for k, v in JOINT.items()}
for k, v in HELPER.items():
    PARENT[k], AT[k] = v[0], Vector(v[1])
ORDER = list(JOINT) + list(HELPER)


def rig_matrix(e):
    """Rig axes rotation (deg x, y, z as ry @ rx @ rz) as a 4x4 in rig space."""
    return Matrix.Rotation(math.radians(e[1]), 4, "Y") @ Matrix.Rotation(math.radians(e[0]), 4, "X") @ Matrix.Rotation(math.radians(e[2]), 4, "Z")


TO_B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # rig (x,y,z) -> Blender (x,-z,y)
objects = {o.name.split(".")[0]: o for o in sc.objects if o.type == "MESH"}
for o in objects.values():
    o.rotation_mode = "QUATERNION"
BASE = {n: o.matrix_world.copy() for n, o in objects.items()}


def pose(tag, local, views=((0, "f"), (135, "q"))):
    world = {"HumanoidRootPart": Matrix.Identity(4)}
    for b in ORDER:
        j = Matrix.Translation(AT[b])
        world[b] = world[PARENT[b]] @ j @ rig_matrix(local.get(b, (0, 0, 0))) @ j.inverted()
    for n, o in objects.items():
        W = world[info[n]["bone"]]
        o.matrix_world = TO_B @ W @ TO_B.inverted() @ BASE[n]
    bpy.context.view_layer.update()
    for az, lab in views:
        a = math.radians(az)
        d = Vector((math.sin(a), math.cos(a), 0.12)).normalized()
        co.location = Vector((0, 0, -0.1)) + d * 14
        co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(os.path.abspath(out), f"pose{phase}_{tag}_{lab}.png")
        bpy.ops.render.render(write_still=True)


pose("rest", {}, ((0, "f"),))
# the strongest poses the clips will ask for. Rig axes: +x pitches a hanging limb toward his front.
pose("raise", {"RightUpperArm": (120, 0, 15), "RightLowerArm": (160, 0, 15), "RightHand": (160, 0, 15), "LeftUpperArm": (70, 0, -25), "LeftLowerArm": (110, 0, -25), "LeftHand": (110, 0, -25),
               "UpperTorso": (8, 20, 0), "Head": (0, 15, 0), "RightMantle": (45, 0, 8), "LeftMantle": (30, 0, -10)})
pose("lunge", {"LowerTorso": (12, 25, 0), "UpperTorso": (20, 30, 0), "RightUpperLeg": (62, 25, 0), "RightLowerLeg": (10, 25, 0), "RightFoot": (0, 25, 0), "LeftUpperLeg": (-28, 25, 0), "LeftLowerLeg": (-50, 25, 0), "LeftFoot": (-10, 25, 0),
               "RobeFront": (30, 25, 0), "RobeRight": (28, 25, 0), "RobeLeft": (5, 25, 0), "RobeBack": (-15, 25, 0), "RobeInner": (25, 25, 0)})
print("POSE DONE")

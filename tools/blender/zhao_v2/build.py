"""Build General Zhao v2 (master + game geometry) into a fresh .blend.

    Blender -b --factory-startup -P tools/blender/zhao_v2/build.py

Writes assets/source/bosses/general_zhao/v2_design/GeneralZhao_v2.blend. Baking, export and the
manifest are separate steps (bake.py), so geometry can be iterated quickly.
"""
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
for m in ("lib", "mats", "body", "weapon"):
    sys.modules.pop(m, None)
import body  # noqa: E402
import mats  # noqa: E402
import weapon  # noqa: E402

ROOT = HERE.parents[2]
OUT = ROOT / "assets/source/bosses/general_zhao/v2_design"
BLEND = OUT / "GeneralZhao_v2.blend"

# R15 limb centres at scale 1 in Roblox coordinates (x, y, z), measured in Studio (v1 manifest)
PIVOT = {
    "Head": (0, 1.586, 0), "UpperTorso": (0, 0.2, 0), "LowerTorso": (0, -0.8, 0),
    "LeftUpperArm": (-1.5, 0.369, 0), "LeftLowerArm": (-1.5, -0.224, 0), "LeftHand": (-1.5, -0.85, 0),
    "RightUpperArm": (1.5, 0.369, 0), "RightLowerArm": (1.5, -0.224, 0), "RightHand": (1.5, -0.85, 0),
    "LeftUpperLeg": (-0.5, -1.421, 0), "LeftLowerLeg": (-0.5, -2.201, 0), "LeftFoot": (-0.5, -2.85, 0),
    "RightUpperLeg": (0.5, -1.421, 0), "RightLowerLeg": (0.5, -2.201, 0), "RightFoot": (0.5, -2.85, 0),
}


def blender_pivot(bone):
    x, y, z = PIVOT[bone]
    return Vector((x, -z, y))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_collection(name, parent=None):
    c = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(c)
    return c


def finish_pieces(pieces, coll, materials, suffix):
    obs = []
    for pc in pieces:
        pc.name = pc.name + suffix
        ob = pc.finish(coll, materials)
        if suffix == "_Master":  # smooth the master's forms; the bake reads the evaluated surface
            m = ob.modifiers.new("Subdiv", "SUBSURF")
            m.levels = m.render_levels = 1
            m.boundary_smooth = "PRESERVE_CORNERS"
        piv = blender_pivot(pc.bone)
        ob.data.transform(__import__("mathutils").Matrix.Translation(-piv))
        ob.location = piv
        obs.append(ob)
    return obs


def main():
    t0 = time.time()
    reset()
    materials = mats.make_all()
    master = make_collection("ZhaoV2_Master")
    game = make_collection("ZhaoV2_Game")
    gm = make_collection("ZhaoV2_Guandao_Master", master)
    gg = make_collection("ZhaoV2_Guandao_Game", game)
    finish_pieces(body.build(True), master, materials, "_Master")
    finish_pieces(weapon.build(True), gm, materials, "_Master")
    finish_pieces(body.build(False), game, materials, "")
    finish_pieces(weapon.build(False), gg, materials, "")
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
    for c in (master, game):
        tris = 0
        for ob in c.all_objects:
            n = sum(len(p.vertices) - 2 for p in ob.data.polygons)
            tris += n
            print(f"  {ob.name:34s} {n:7d}")
        print(c.name, "triangles", tris)
    print("built in %.1fs" % (time.time() - t0))


main()

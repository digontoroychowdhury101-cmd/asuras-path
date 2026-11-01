"""Blender review scene for baked Jian clips: the R15 template parts as boxes plus the welded jian, keyed from
work/jian_anim_bake/<clip>.json, one Blender action per clip on its own scene so clips can be scrubbed side by side.

Run inside Blender (MCP execute or `blender -P tools/animation/jian/preview_blender.py -- CLIP ...`). It only creates
or replaces scenes named JianAnim_<clip>; nothing else in the open file is touched.
Roblox root space (+X right, +Y up, -Z forward) maps to Blender (x, -z, y), so the fighter faces Blender +Y.
"""
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

HERE = Path(__file__).resolve().parent if "__file__" in globals() else Path(bpy.path.abspath("//"))
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent / "general_zhao"))
import rig  # noqa: E402

LIFT = -rig.GROUND
SKIN, CLOTH, STEEL, GOLD = (0.62, 0.48, 0.38, 1), (0.16, 0.17, 0.2, 1), (0.82, 0.85, 0.9, 1), (0.69, 0.55, 0.25, 1)


def to_blender(m):
    M = Matrix([m[0:4], m[4:8], m[8:12], m[12:16]])
    C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    out = C @ M @ C.inverted()
    out.translation.z += LIFT
    return out


def material(name, rgba):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    return mat


def box(scene, name, size, mat, parent=None, offset=(0, 0, 0)):
    mesh = bpy.data.meshes.new(name)
    sx, sy, sz = size[0] / 2, size[2] / 2, size[1] / 2  # Roblox (x, y, z) extents -> Blender (x, z, y)
    verts = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
        obj.location = (offset[0], -offset[2], offset[1])
    return obj


def build(clip):
    data = json.loads((ROOT / "work/jian_anim_bake" / (clip + ".json")).read_text())
    name = "JianAnim_" + clip
    old = bpy.data.scenes.get(name)
    if old:
        for obj in list(old.collection.all_objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new(name)
    scene.render.fps = 60
    scene.frame_start, scene.frame_end = 0, len(data["frames"]) - 1
    mats = {"skin": material("JianSkin", SKIN), "cloth": material("JianCloth", CLOTH), "steel": material("JianSteel", STEEL),
            "gold": material("JianGold", GOLD), "ground": material("JianGround", (0.3, 0.32, 0.3, 1))}
    parts = {}
    for part, size in rig.SIZES.items():
        if part == "HumanoidRootPart":
            continue
        kind = "skin" if part in ("Head",) or "Hand" in part or "LowerArm" in part else "cloth"
        parts[part] = box(scene, name + "_" + part, size, mats[kind])
    b = data["blade"]
    hand = parts["RightHand"]
    length = b["pommel"] - b["tip"]
    box(scene, name + "_JianBlade", (0.12, 0.28, length - 0.85), mats["steel"], hand, (0, b["y"], (b["tip"] + b["guard"]) / 2))
    box(scene, name + "_JianGuard", (0.9, 0.16, 0.2), mats["gold"], hand, (0, b["y"], b["guard"]))
    box(scene, name + "_JianGrip", (0.2, 0.22, 0.8), mats["cloth"], hand, (0, b["y"], (b["guard"] + b["pommel"]) / 2))
    ground = box(scene, name + "_Ground", (24, 0.02, 24), mats["ground"])
    ground.location = (0, -4, 0)
    target = box(scene, name + "_Target8", (2, 5, 1), mats["cloth"])  # an opponent's body at 8 studs (melee reach)
    target.location = (0, 8.5, 2.5)
    for i, frame in enumerate(data["frames"]):
        for part, obj in parts.items():
            obj.matrix_world = to_blender(frame["parts"][part])
            obj.keyframe_insert("location", frame=i)
            obj.rotation_mode = "QUATERNION"
            obj.keyframe_insert("rotation_quaternion", frame=i)
    scene.frame_set(0)
    return scene


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for clip in argv:
        build(clip)

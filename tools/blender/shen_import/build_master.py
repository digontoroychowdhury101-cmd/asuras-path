"""The editable Grandmaster Shen handoff: untouched sources, the skinned working rig, final export chunks, packed textures and one labelled Action per baked clip.

    Blender -b --factory-startup --python tools/blender/shen_import/build_master.py
Writes assets/source/bosses/grandmaster_shen/GrandmasterShen_Master.blend. Sources are read, never edited; the game chunks and their skeleton come from build_game.py's GLBs, so every vertex group here is the weight the game
ships. Actions come from tools/animation/opening_cast/export.py's bake (limb bones only; cloth bones are live in the game). ClothReview_* Actions hold a whole shot from cloth_bake.py, garments included, to scrub the simulation.
"""
import json
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
import rigdef as R  # noqa: E402

SRC = os.path.join(ROOT, "assets/source/bosses/grandmaster_shen")
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # rig (x, y, z) -> Blender (x, -z, y)
CI = C.inverted()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30


def collection(name, parent=None):
    col = bpy.data.collections.new(name)
    (parent or scene.collection).children.link(col)
    return col


def import_into(path, col):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for ob in new:
        for owner in list(ob.users_collection):
            owner.objects.unlink(ob)
        col.objects.link(ob)
    return new


report = {}
for phase in (1, 2):
    sources = collection("Source_P%d" % phase)
    for ob in import_into(os.path.join(SRC, "Grandmaster-Shen-Phase-%d-PBR.glb" % phase), sources):
        ob.hide_viewport, ob.hide_render = True, True
        ob.name = "Source_P%d_%s" % (phase, ob.name)
    export = collection("Export_P%d" % phase)
    pieces_new = import_into(os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Game.glb" % phase), export)
    props_new = import_into(os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Props.glb" % phase), export)
    info = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen%d/pieces.json" % phase)))
    fx = info.pop("__fx", {})
    # the rig is the file's own skeleton: every mesh already deforms through it
    rig = next(o for o in pieces_new if o.type == "ARMATURE")
    rig.name = "Rig_P%d" % phase
    arm = rig.data
    arm.name = rig.name
    rig_col = collection("Rig_P%d" % phase)
    for owner in list(rig.users_collection):
        owner.objects.unlink(rig)
    rig_col.objects.link(rig)
    for ob in pieces_new:   # the glTF importer's bone display shape, not a game chunk
        if ob.name.startswith("Icosphere"):
            for owner in list(ob.users_collection):
                owner.objects.unlink(ob)
            ob.use_fake_user = True
    bound = 0
    for ob in pieces_new:
        base = ob.name.split(".")[0]
        if ob.type == "MESH" and base in info:
            ob["AsuraSkinned"], ob["AsuraRole"] = True, str(info[base]["role"] or "")
            bound += 1
    # the rigid props ride their limb's bone (phase 2's beads get bones of their own, on their orbit)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    if R.HELPER[phase]:
        bpy.ops.object.mode_set(mode="EDIT")
        for bone, (parent, at) in R.HELPER[phase].items():
            b = arm.edit_bones.new(bone)
            p = C @ Vector(at)
            b.head, b.tail = p, p + Vector((0, 0, 0.18))
            b.parent = arm.edit_bones["Root"]
        bpy.ops.object.mode_set(mode="OBJECT")
    for ob in props_new:
        base = ob.name.split(".")[0]
        if ob.type == "MESH" and base in info:
            bone = info[base]["bone"]
            bone = bone if bone in arm.bones else "Sk_" + bone
            keep = ob.matrix_world.copy()
            ob.parent, ob.parent_type, ob.parent_bone = rig, "BONE", bone
            ob.matrix_world = keep
            ob["AsuraBone"], ob["AsuraRole"] = bone, str(info[base]["role"] or "")
            bound += 1
    # named effect points the game reads (bind_skin.py)
    for name, spec in fx.items():
        empty = bpy.data.objects.new("Fx_P%d_%s" % (phase, name), None)
        empty.empty_display_size = 0.12
        empty.matrix_world = Matrix.Translation(C @ Vector(spec["at"]))
        empty["AsuraFxLimb"] = spec.get("limb", "")
        rig_col.objects.link(empty)
    bake = os.path.join(ROOT, "work/opening_cast_bake/shen")
    rest = {b.name: b.matrix_local.copy() for b in arm.bones}
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    rig.animation_data_create()

    def key_pose(pose, f):
        """pose: bone -> (rotation rows and position as a 3x4 list) in rig space; a flat skeleton, so each bone's basis is its delta alone."""
        for name, v in pose.items():
            pb = rig.pose.bones.get(name)
            if pb is None:
                continue
            A = (C @ v @ CI) @ rest[name]
            pb.matrix_basis = rest[name].inverted() @ A
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)

    made = 0
    for fn in sorted(os.listdir(bake)):
        if not fn.endswith(".json") or "_P%d_" % phase not in fn:
            continue
        clip = json.load(open(os.path.join(bake, fn)))
        action = bpy.data.actions.new(clip["name"])
        action.use_fake_user = True
        action["contacts"] = list(clip["contacts"])
        action["length"] = clip["length"]
        rig.animation_data.action = action
        for frame in clip["frames"]:
            pose = {}
            for name, M in frame["parts"].items():
                bone = "Sk_" + name if "Sk_" + name in arm.bones else name
                if bone in arm.bones:
                    pose[bone] = Matrix([M[0:4], M[4:8], M[8:12], M[12:16]])
            key_pose(pose, 1 + frame["t"] * 30)
        made += 1
    shots = os.path.join(ROOT, "work/opening_cast_bake/shen_shots")
    for fn in sorted(os.listdir(shots)) if os.path.isdir(shots) else []:
        shot = json.load(open(os.path.join(shots, fn)))
        if shot["phase"] != phase:
            continue
        action = bpy.data.actions.new("ClothReview_" + fn[:-5])
        action.use_fake_user = True
        rig.animation_data.action = action
        for f, frame in enumerate(shot["frames"]):
            key_pose({k: Matrix(((v[0], v[1], v[2], v[9]), (v[3], v[4], v[5], v[10]), (v[6], v[7], v[8], v[11]), (0, 0, 0, 1))) for k, v in frame["bones"].items()}, 1 + f)
        made += 1
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    report[phase] = {"chunks_bound": bound, "actions": made, "bones": len(arm.bones)}
bpy.ops.file.pack_all()
text = bpy.data.texts.new("Build_Info")
text.write(json.dumps({"blender": bpy.app.version_string, "exporter": "io_scene_gltf2 %s" % str(bpy.context.preferences.addons.keys()), "report": report,
                       "rebuild": ["python3 tools/blender/shen_import/skin_rig.py", "python3 tools/blender/shen_import/build_game.py", "python3 tools/blender/shen_import/write_cloth_data.py", "cd tools/animation/opening_cast && python3 shen_fx_points.py && python3 export.py shen && python3 cloth_bake.py",
                                   "Blender -b --factory-startup --python tools/blender/shen_import/build_master.py"],
                       "notes": "Source_P* collections are the supplied GLBs, unedited. Export_P* are the skinned chunks in Shen_P*_Game.glb and the rigid props in Shen_P*_Props.glb. Actions are named as their game slots; custom properties carry contacts and length."}, indent=1))
out = os.path.join(SRC, "GrandmasterShen_Master.blend")
bpy.ops.wm.save_as_mainfile(filepath=out, compress=True)
print("MASTER", out, report, "actions", len(bpy.data.actions))

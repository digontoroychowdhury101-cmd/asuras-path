"""Exports General Zhao v2's game pieces for the 3D Importer, unchanged: same meshes and UVs as review, with the 2048 bakes.

    Blender -b assets/source/bosses/general_zhao/v2_design/GeneralZhao_v2.blend -P tools/blender/zhao_v2/export_skin.py

Writes assets/build/opening_cast/zhao/AsuraBoss_GeneralZhao.glb and work/opening_cast_bake/zhao/pieces.json (bones, roles and
root-space bounds for bind_skin.py and check_skin.py). The bone and role of each piece are the ones build.py stored on it.
"""
import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(bpy.data.filepath).resolve().parents[5]
MASTER = ROOT / "assets/source/bosses/general_zhao/v2_design/textures/master"
SIZE = {"ZhaoBodyV2": 2048, "ZhaoWeaponV2": 1024}


def use_masters(material):
    for node in material.node_tree.nodes:
        if node.type != "TEX_IMAGE" or not node.image:
            continue
        channel = next((c for c in ("Color", "Rough", "Metal", "Normal") if c in node.image.name), None)
        if channel:
            space = node.image.colorspace_settings.name
            node.image = bpy.data.images.load(str(MASTER / f"{material.name}_{channel}_{SIZE[material.name]}.png"), check_existing=True)
            node.image.colorspace_settings.name = space


def main():
    objs = [o for o in bpy.data.collections["ZhaoV2_Game"].all_objects if o.type == "MESH"]
    for material in {s.material for o in objs for s in o.material_slots if s.material}:
        use_masters(material)
    pieces = {}
    for o in objs:
        corners = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = [min(c[i] for c in corners) for i in range(3)]
        hi = [max(c[i] for c in corners) for i in range(3)]
        low, high = (lo[0], lo[2], -hi[1]), (hi[0], hi[2], -lo[1])  # Blender Z is Roblox +Y, Blender +Y is Roblox -Z
        o.data.calc_loop_triangles()
        pieces[o.name] = {"bone": o["AsuraBone"], "role": o.get("AsuraRole"), "centre": [(a + b) / 2 for a, b in zip(low, high)],
                          "size": [b - a for a, b in zip(low, high)], "tris": len(o.data.loop_triangles)}
    out = ROOT / "assets/build/opening_cast/zhao"
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=str(out / "AsuraBoss_GeneralZhao.glb"), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_materials="EXPORT")
    dst = ROOT / "work/opening_cast_bake/zhao"
    dst.mkdir(parents=True, exist_ok=True)
    (dst / "pieces.json").write_text(json.dumps(pieces, indent=1))
    print("EXPORTED", len(pieces), "pieces", sum(p["tris"] for p in pieces.values()), "tris")


main()

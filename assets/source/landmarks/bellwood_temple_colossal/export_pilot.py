"""Bake a representative Bellwood roof and a masonry stair section as an offline importer pilot."""
import json
import os
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "tools/blender/vesperhold"))
import vesp_bake as bake
import vesperhold_gargoyles as pack

OUT = Path(os.environ.get("VESP_PILOT_OUT", ROOT / "work/sol-bellwood-v15/pilot"))
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 4
for obj in scene.objects:
    obj.hide_render = True

piece = "Bellwood_ColossalTemplePilot"
sources = {
    "Stair": ("Masonry", (0, 198, 22), (39, 25, 6)),
    "Eaves": ("Tile", (102, -48, 175), (19, 15, 12)),
}
export = []
man = {}
for role, (from_role, center, half) in sources.items():
    original = bpy.data.objects[f"Bellwood_Colossal_{from_role}"]
    source_material = original.data.materials[0]
    name = f"{piece}__{role}"
    topo = bmesh.new()
    topo.from_mesh(original.data)
    outside = [face for face in topo.faces if any(abs(v-center[i]) > half[i]
               for i, v in enumerate(face.calc_center_median()))]
    bmesh.ops.delete(topo, geom=outside, context="FACES")
    remaining = list(topo.faces)
    assert remaining, role
    mesh = bpy.data.meshes.new(name)
    topo.to_mesh(mesh)
    topo.free()
    mesh.materials.clear()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.hide_render = False
    mat = source_material.copy()
    mesh.materials.append(mat)
    bake.unwrap(obj)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    output = next(node for node in mat.node_tree.nodes if node.type == "OUTPUT_MATERIAL")
    links = mat.node_tree.links
    emit = mat.node_tree.nodes.new("ShaderNodeEmission")
    target = mat.node_tree.nodes.new("ShaderNodeTexImage")
    mat.node_tree.nodes.active = target
    maps = {}
    for key, color, socket in (("Color", True, "Base Color"), ("Roughness", False, "Roughness"),
                               ("Metal", False, "Metallic"), ("Normal", False, None)):
        image = bake._new_img(f"{name}_{key}", 2048)
        target.image = image
        if socket:
            src = shader.inputs[socket]
            if emit.inputs[0].is_linked:
                links.remove(emit.inputs[0].links[0])
            if src.is_linked:
                links.new(src.links[0].from_socket, emit.inputs[0])
            elif socket == "Base Color":
                emit.inputs[0].default_value = src.default_value
            else:
                value = src.default_value
                emit.inputs[0].default_value = (value, value, value, 1)
            links.new(emit.outputs[0], output.inputs["Surface"])
        else:
            links.new(shader.outputs[0], output.inputs["Surface"])
        scene.render.bake.margin = 10
        scene.render.bake.margin_type = "EXTEND"
        bake._only([obj], obj)
        bpy.ops.object.bake(type="EMIT" if socket else "NORMAL", use_selected_to_active=False)
        path = OUT / f"{name}_{key}.png"
        bake.save_png(path, bake._pix(image)[..., :3], color)
        target.image = None
        bpy.data.images.remove(image)
        maps[key] = path
    obj.data.materials.clear()
    obj.data.materials.append(bake.low_material(name, maps))
    sections = bake.split_cap(obj)
    export.extend(sections)
    man.update({sub.name: bake.tris(sub) for sub in sections})
    print(name, len(remaining), {o.name: man[o.name] for o in sections}, flush=True)

glb = OUT / f"{piece}.glb"
pack.export_glb(export, glb)
(OUT / "manifest.json").write_text(json.dumps({"kit": "Bellwood pilot", "pieces": {
    piece: {"file": glb.name, "sub_meshes": man}
}}, indent=2) + "\n")

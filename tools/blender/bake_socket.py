"""UV-bake a material input (including vertex-color modulation) without baking scene lighting."""
import bpy
import bmesh
import numpy as np


def bake_socket(material, socket, size):
    tree = material.node_tree
    output = next(n for n in tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output)
    original = [(link.from_socket, link.to_socket) for link in output.inputs['Surface'].links]
    image = bpy.data.images.new('SocketBake', size, size, alpha=True, float_buffer=True)
    target = tree.nodes.new('ShaderNodeTexImage'); target.image = image
    emission = tree.nodes.new('ShaderNodeEmission')
    if socket.is_linked:
        tree.links.new(socket.links[0].from_socket, emission.inputs['Color'])
    else:
        value = socket.default_value
        emission.inputs['Color'].default_value = (value, value, value, 1) if isinstance(value, (float,int)) else value
    tree.links.new(emission.outputs[0], output.inputs['Surface'])
    tree.nodes.active = target
    copies = []
    try:
        for obj in list(bpy.context.scene.objects):
            if obj.type != 'MESH' or material not in list(obj.data.materials): continue
            clone = obj.copy(); clone.data = obj.data.copy()
            bpy.context.collection.objects.link(clone); copies.append(clone)
            slots = [i for i, mat in enumerate(clone.data.materials) if mat == material]
            bm = bmesh.new(); bm.from_mesh(clone.data)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index not in slots], context='FACES')
            bm.to_mesh(clone.data); bm.free()
            clone.data.materials.clear(); clone.data.materials.append(material)
            for face in clone.data.polygons: face.material_index = 0
        bpy.ops.object.select_all(action='DESELECT')
        for obj in copies: obj.select_set(True)
        bpy.context.view_layer.objects.active = copies[0]
        scene = bpy.context.scene
        scene.render.engine = 'CYCLES'; scene.cycles.device = 'CPU'; scene.cycles.samples = 1
        scene.render.bake.margin = 8; scene.render.bake.use_selected_to_active = False
        bpy.ops.object.bake(type='EMIT')
        pixels = np.empty(size*size*4, dtype=np.float32); image.pixels.foreach_get(pixels)
        return pixels.reshape(-1,4)
    finally:
        for obj in copies:
            mesh = obj.data; bpy.data.objects.remove(obj,do_unlink=True); bpy.data.meshes.remove(mesh)
        tree.nodes.remove(target); tree.nodes.remove(emission)
        for a,b in original: tree.links.new(a,b)
        bpy.data.images.remove(image)

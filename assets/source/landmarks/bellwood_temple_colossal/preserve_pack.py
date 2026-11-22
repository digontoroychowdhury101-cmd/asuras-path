"""Bake and split the approved temple meshes without lowering their triangle count.

Run on the packed Blender study. Keep every material and piece in Blender
world coordinates. Render-only scenery and the scale figure are excluded.
"""
from collections import defaultdict
import json
import os
from pathlib import Path
import sys

import bpy
import numpy as np

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "tools/blender/vesperhold"))
import vesp_bake as bake
from vesperhold_figures import bbox

OUT = Path(os.environ.get("VESP_PACK", ROOT / "work/sol-bellwood-v20/preserved"))
MAPS = OUT / "maps"
NAME = "Bellwood_ColossalTemple"
LIMIT = 17480
ATLAS_TARGET = 87500
PREFIX = "Bellwood_Colossal_"
STAGING = {"TravelerCloth", "Straw", "Crag", "Pine"}


def array_of(collection, attribute, width, dtype):
    result = np.empty(len(collection) * width, dtype=dtype)
    collection.foreach_get(attribute, result)
    return result.reshape(-1, width) if width > 1 else result


class Geometry:
    def __init__(self, source):
        mesh = source.data
        self.points = array_of(mesh.vertices, "co", 3, np.float32)
        self.index = array_of(mesh.loops, "vertex_index", 1, np.int32)
        self.start = array_of(mesh.polygons, "loop_start", 1, np.int32)
        self.length = array_of(mesh.polygons, "loop_total", 1, np.int32)
        self.centres = array_of(mesh.polygons, "center", 3, np.float32)
        self.smooth = array_of(mesh.polygons, "use_smooth", 1, np.bool_)
        mesh.calc_loop_triangles()
        self.tri_faces = array_of(mesh.loop_triangles, "polygon_index", 1, np.int32)
        self.tri_loops = array_of(mesh.loop_triangles, "loops", 3, np.int32)
        self.normals = array_of(mesh.corner_normals, "vector", 3, np.float32)
        self.uv = {layer.name: array_of(layer.uv, "vector", 2, np.float32)
                   for layer in mesh.uv_layers}
        self.attrs = {attribute.name: array_of(attribute.data, "value", 1, np.float32)
                      for attribute in mesh.attributes
                      if attribute.domain == "POINT" and attribute.data_type == "FLOAT"}

    def select(self, role):
        selected = np.arange(len(self.length), dtype=np.int32)
        if role == "DarkStone":
            # The scale figure's leather parts share this material with the architecture.
            keep = np.any(np.abs(self.centres - (8, 247.6, 5)) > (1.8, 1.8, 3), axis=1)
            selected = selected[keep]
        return selected

    def sections(self, role, selected):
        bins = defaultdict(list)
        for f in selected:
            x, y, z = self.centres[f]
            label = ("Roots" if z < 405 else "Crown") if role == "Bark" else role
            floor = int(np.floor(max(0, z) / 160))
            lane = int(np.floor((x + 480) / 210))
            reach = 1 if y > 15 else 0
            bins[label, floor * 16 + lane * 2 + reach].append(f)
        for (label, sector), faces in sorted(bins.items()):
            yield label, sector, list(self.partition(np.asarray(faces), ATLAS_TARGET))

    def partition(self, members, limit):
        if not len(members):
            return
        triangles = np.cumsum(self.length[members] - 2, dtype=np.int64)
        start = 0
        while start < len(members):
            before = triangles[start - 1] if start else 0
            stop = int(np.searchsorted(triangles, before + limit, side="right"))
            if stop <= start:
                raise ValueError(f"A single source face exceeds {limit} triangles")
            yield members[start:stop]
            start = stop

    def build(self, name, members, triangulate=False):
        sizes = self.length[members].astype(np.int32)
        source_triangles = int(sizes.sum()) - 2 * len(sizes)
        local_starts = np.cumsum(sizes, dtype=np.int32) - sizes
        local_loops = np.arange(int(sizes.sum()), dtype=np.int32)
        source_loops = local_loops + np.repeat(self.start[members] - local_starts, sizes)
        smooth = self.smooth[members]
        if triangulate:
            selected = np.isin(self.tri_faces, members)
            source_loops = self.tri_loops[selected].ravel()
            sizes = np.full(len(source_loops)//3, 3, dtype=np.int32)
            local_starts = np.arange(0, len(source_loops), 3, dtype=np.int32)
            smooth = self.smooth[self.tri_faces[selected]]
            assert len(sizes) == source_triangles
        verts, remap = np.unique(self.index[source_loops], return_inverse=True)
        mesh = bpy.data.meshes.new(name)
        face_vertices = [remap[start:start+size].tolist() for start, size in zip(local_starts, sizes)]
        mesh.from_pydata(self.points[verts].tolist(), [], face_vertices)
        mesh.polygons.foreach_set("use_smooth", smooth)
        mesh.update()
        assert sum(len(face.vertices) - 2 for face in mesh.polygons) == source_triangles, name
        if len(mesh.corner_normals) == len(source_loops):
            mesh.normals_split_custom_set(self.normals[source_loops])
        for layer_name, values in self.uv.items():
            layer = mesh.uv_layers.new(name=layer_name)
            layer.uv.foreach_set("vector", values[source_loops].ravel())
        for name_at, values in self.attrs.items():
            attribute = mesh.attributes.new(name_at, "FLOAT", "POINT")
            attribute.data.foreach_set("value", values[verts])
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj, source_triangles


def bake_atlas(obj, material, maps_directory):
    source = material.copy()
    obj.data.materials.clear()
    obj.data.materials.append(source)
    # Bark's original UVMap feeds the willow grain while the second sheet is baked.
    old_uv = obj.data.uv_layers.active.name if obj.data.uv_layers.active else None
    uv = obj.data.uv_layers.new(name="Atlas", do_init=False)
    obj.data.uv_layers.active = uv
    uv.active_render = True
    bake.unwrap(obj, margin=.008)
    nodes, links = source.node_tree.nodes, source.node_tree.links
    shader = nodes.get("Principled BSDF")
    output = next(node for node in nodes if node.type == "OUTPUT_MATERIAL")
    emission = nodes.new("ShaderNodeEmission")
    target = nodes.new("ShaderNodeTexImage")
    nodes.active = target
    for key, color, channel in (("Color",True,"Base Color"), ("Roughness",False,"Roughness"),
                                 ("Metal",False,"Metallic"), ("Normal",False,None)):
        image = bake._new_img(f"{obj.name}_{key}", 2048)
        target.image = image
        if channel:
            socket = shader.inputs[channel]
            if emission.inputs[0].is_linked:
                links.remove(emission.inputs[0].links[0])
            if socket.is_linked:
                links.new(socket.links[0].from_socket, emission.inputs[0])
            elif channel == "Base Color":
                emission.inputs[0].default_value = socket.default_value
            else:
                v = socket.default_value
                emission.inputs[0].default_value = (v,v,v,1)
            links.new(emission.outputs[0], output.inputs["Surface"])
        else:
            links.new(shader.outputs[0], output.inputs["Surface"])
        bake._only([obj], obj)
        scene = bpy.context.scene
        scene.render.bake.margin = 12
        scene.render.bake.margin_type = "EXTEND"
        bpy.ops.object.bake(type="EMIT" if channel else "NORMAL", use_selected_to_active=False, uv_layer="Atlas")
        path = maps_directory / f"{obj.name}_{key}.png"
        bake.save_png(path, bake._pix(image)[..., :3], color)
        target.image = None
        bpy.data.images.remove(image)
    obj.data.materials.clear()
    obj.data.materials.append(bpy.data.materials.new(obj.name))
    bpy.data.materials.remove(source)
    if old_uv:
        obj.data.uv_layers.remove(obj.data.uv_layers[old_uv])



def twig_geometry(scene):
    source = scene.objects.get("Bellwood_Crown_Fringe")
    if not source:
        return None
    nodes = source.modifiers[0].node_group.nodes
    tree = source.modifiers[0].node_group
    output = next(n for n in nodes if n.type == "GROUP_OUTPUT")
    instance = output.inputs[0].links[0].from_socket
    realize = nodes.new("GeometryNodeRealizeInstances")
    tree.links.new(instance, realize.inputs["Geometry"])
    tree.links.new(realize.outputs["Geometry"], output.inputs[0])
    deps = bpy.context.evaluated_depsgraph_get()
    cooked = bpy.data.meshes.new_from_object(source.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
    new_object = bpy.data.objects.new(PREFIX + "CrownShoots", cooked)
    bpy.context.scene.collection.objects.link(new_object)
    if not cooked.materials:
        cooked.materials.append(bpy.data.objects[PREFIX + "BarkTwigs"].data.materials[0])
    return new_object


def main():
    MAPS.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 2
    if not os.environ.get("VESP_PILOT"):
        twig_geometry(scene)
    objects = {obj.name.removeprefix(PREFIX): obj for obj in scene.objects
               if obj.type == "MESH" and obj.name.startswith(PREFIX)}
    for obj in scene.objects:
        obj.hide_render = True
    requested = set(os.environ.get("VESP_PACK_ROLES", "").split(",")) - {""}
    pieces = {}
    pilot = os.environ.get("VESP_PILOT") == "1"
    for role, source in objects.items():
        if role in STAGING or (requested and role not in requested):
            continue
        data = Geometry(source)
        material = source.data.materials[0]
        selected = data.select(role)
        seen = 0
        results = {}
        for label, sector, regions in data.sections(role, selected):
            for number, members in enumerate(regions, 1):
                name = f"{NAME}__{label}{sector:02d}_{number:02d}"
                group, total = data.build(name, members)
                bake_atlas(group, material, MAPS)
                atlas_geometry = Geometry(group)
                atlas_faces = np.arange(len(atlas_geometry.length))
                material = group.data.materials[0]
                loaded_material = source.data.materials[0]
                count = {}
                for suffix, indices in enumerate(atlas_geometry.partition(atlas_faces, LIMIT), 1):
                    sub, triangles = atlas_geometry.build(f"{name}_Part{suffix:02d}", indices, triangulate=True)
                    sub.data.materials.append(material)
                    count[sub.name] = triangles
                del atlas_geometry
                atlas_mesh = group.data
                bpy.data.objects.remove(group, do_unlink=True)
                bpy.data.meshes.remove(atlas_mesh)
                material = loaded_material
                assert sum(count.values()) == total and max(count.values()) <= 18000
                results.update(count)
                seen += total
                print("Preserved", name, len(count), total, flush=True)
                if pilot:
                    break
            if pilot:
                break
        assert pilot or seen == sum(data.length[selected] - 2)
        pieces.update(results)
        del data
        high_mesh = source.data
        bpy.data.objects.remove(source, do_unlink=True)
        if high_mesh.users == 0:
            bpy.data.meshes.remove(high_mesh)
        if pilot:
            break
    objects = [bpy.data.objects[name] for name in pieces]
    assert objects
    bake._only(objects, objects[0])
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{NAME}.glb"), export_format="GLB",
                              use_selection=True, export_apply=False, export_tangents=True,
                              export_image_format="NONE")
    lo, hi = bbox(objects)
    entry = {"file": f"{NAME}.glb", "sub_meshes": pieces, "bbox_min": list(map(float, lo)),
             "bbox_max": list(map(float, hi)), "map_size": 2048, "no_decimation": True}
    (OUT / "manifest.json").write_text(json.dumps({"kit":"Bellwood temple", "pieces":{NAME:entry}},indent=2)+"\n")


if __name__ == "__main__":
    main()

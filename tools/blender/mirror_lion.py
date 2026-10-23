"""Mirror twin of the guardian lion, so the gate's pair is truly symmetrical (headless Blender).

Usage:
  Blender -b --python-exit-code 1 -P tools/blender/mirror_lion.py -- assets/models/Asuraguardianlion.glb <out.glb>

The TRELLIS lion faces -X in Blender (Roblox -X after import), so its left-right axis is Y: the twin is
mirrored across it, faces are reversed so normals stay outward, and UVs and PBR maps are kept as they
are. Same size and base footprint as the original; import as AsuraGuardianLionMirror.
"""
import sys

import bmesh
import bpy
from mathutils import Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = ARGS[0], ARGS[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    me = o.data
    me.transform(o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
    me.transform(Matrix.Scale(-1, 4, (0, 1, 0)))
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    if me.has_custom_normals:  # mirrored custom normals would point the old way
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    me.update()
    o.name = me.name = "AsuraGuardianLionMirror"
for o in [o for o in bpy.data.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True)
print("MIRROR_OK", OUT, sum(len(o.data.polygons) for o in meshes), "faces", flush=True)

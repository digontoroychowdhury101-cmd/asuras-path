import bpy, sys, numpy as np
from mathutils import Matrix
ph, out = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="assets/build/grandmaster_shen/Shen_P%s_Props.glb" % ph)
CI = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))).inverted()
V = []
for o in bpy.data.objects:
    if o.type == "MESH" and "Weapon" in o.name:
        M = CI @ o.matrix_world
        V += [tuple(M @ v.co) for v in o.data.vertices]
np.save(out, np.array(V))
print("DUMP", len(V))

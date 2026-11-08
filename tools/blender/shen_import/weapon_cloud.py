"""The glaive's real surface as a dense point cloud, for the clip pipeline's arm-in-weapon checks (shen_lib held_clash, the grip chooser, validate).

    Blender -b --factory-startup --python tools/blender/shen_import/weapon_cloud.py -- PHASE

Writes work/shen_import/wcloud_pN.npz: {"points": rest positions (rig space, as the props file stands), "spacing"}.
One vertex per SPACING cell of the props file's weapon mesh, the one nearest the cell's centre.
(2026-11-07) The pipeline used to look with 250 of the 1500 validator samples (samples_pN.npz, Weapon[::6]). Over the butt cap, where the haft flares
from 0.08 to 0.24 across, that left 3 points in 0.2 of length: phase 2 Idle held the cap 0.109 inside his right forearm (the mesh check,
mesh_clash.py, on all 46k vertices) while the pipeline read 0.006, so no arm repair pass ran. At 0.04 a missed vertex is within 0.035 of a kept one.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
phase = int(sys.argv[sys.argv.index("--") + 1])
SPACING = 0.04
CI = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))).inverted()   # Blender (z up) to rig space (y up)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Props.glb" % phase))
V = []
for ob in sorted((o for o in bpy.data.objects if o.type == "MESH" and "Weapon" in o.name), key=lambda o: o.name):
    M = CI @ ob.matrix_world
    V += [tuple(M @ v.co) for v in ob.data.vertices]
P = np.array(V)
cell = np.floor(P / SPACING).astype(int)
d = np.linalg.norm(P - (cell + 0.5) * SPACING, axis=1)
best = {}
for i, key in enumerate(map(tuple, cell)):
    if key not in best or d[i] < d[best[key]]:
        best[key] = i
keep = P[sorted(best.values())]
np.savez_compressed(os.path.join(ROOT, "work/shen_import/wcloud_p%d.npz" % phase), points=keep, spacing=np.array(SPACING))
print("WCLOUD", phase, len(P), "vertices ->", len(keep), "points")

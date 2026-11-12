"""xray_dump.py (Blender, 2026-11-13): the arm and UpperTorso meshes of Shen_P<phase>_Game.glb as review.py's x-ray sees them, for
tools/animation/opening_cast/shen_seam.py (XRay).    blender -b --factory-startup --python tools/blender/shen_import/xray_dump.py -- PHASE
Writes work/shen_import/xray_p<phase>.npz. Per arm vertex: rig-space rest position (review.py's CIn), its arm group (0-5: LeftUpperArm,
LeftLowerArm, LeftHand, RightUpperArm, RightLowerArm, RightHand), its weights over the Sk_ bones (raw; shen_seam normalises them, as the
armature deforms). Per UpperTorso vertex: its rest position and its Sk_UpperTorso weight."""
import json, os, sys
import bpy
import numpy as np
from mathutils import Matrix
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
args = sys.argv[sys.argv.index("--") + 1:]
phase = int(args[0])
out = os.path.join(ROOT, "work/shen_import/xray_p%d.npz" % phase)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/build/grandmaster_shen/Shen_P%d_Game.glb" % phase))
info = json.load(open(os.path.join(ROOT, "work/opening_cast_bake/shen%d/pieces.json" % phase)))
CIn = np.array(Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0))))
ARMS = ("LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand")
bones = sorted({g.name for o in bpy.data.objects if o.type == "MESH" for g in o.vertex_groups if g.name.startswith("Sk_")})
bi = {b: i for i, b in enumerate(bones)}
P, G, Wt, TP, TW = [], [], [], [], []
for ob in bpy.data.objects:
    if ob.type != "MESH":
        continue
    grp = info.get(ob.name.split(".")[0], {}).get("group")
    if grp not in ARMS and grp != "UpperTorso":
        continue
    M = np.array(ob.matrix_world)
    names = {g.index: g.name for g in ob.vertex_groups}
    vg = ob.vertex_groups.get("Sk_UpperTorso")
    for v in ob.data.vertices:
        p = CIn @ (M[:3, :3] @ np.array(v.co) + M[:3, 3])
        if grp == "UpperTorso":
            TP.append(p)
            TW.append(next((e.weight for e in v.groups if vg is not None and e.group == vg.index), 0.0))
            continue
        w = np.zeros(len(bones))
        for e in v.groups:
            n = names.get(e.group)
            if n in bi:
                w[bi[n]] += e.weight
        P.append(p); G.append(ARMS.index(grp)); Wt.append(w)
np.savez_compressed(out, P=np.array(P), G=np.array(G), W=np.array(Wt), bones=np.array(bones), TP=np.array(TP), TW=np.array(TW))
print("XDUMP", len(P), "arm verts", len(TP), "torso verts", len(bones), "bones")

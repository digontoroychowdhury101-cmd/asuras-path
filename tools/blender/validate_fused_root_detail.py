"""Validate an actual exported GLB against permission-checked uploaded geometry.

Blender -b --factory-startup -P tools/blender/validate_fused_root_detail.py -- MODEL.glb RECOVERY REPORT.json
Checks evaluated triangles, 18K cap, one material/UV set, original scale/alignment and vertex positions.
This is an offline export check; Studio loading, rendering and performance remain separate gates.
"""
import gzip
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

model, recovery, report_path = map(Path, sys.argv[sys.argv.index("--")+1:])
assert bpy.app.background and not bpy.data.filepath, "use a separate factory-startup process"
assert not report_path.exists(), "existing export evidence is never overwritten"
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(model.resolve()))
basis = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
deps = bpy.context.evaluated_depsgraph_get()
report = {"kind":"actual GLB round-trip check; offline, not Studio visual acceptance", "model":str(model), "parts":[]}
for obj in (o for o in bpy.context.scene.objects if o.type=="MESH"):
    data = json.loads(gzip.decompress((recovery / (obj.name+".json.gz")).read_bytes()))
    frame = data["frame"]
    transform = Matrix(((frame[3],frame[4],frame[5],frame[0]),(frame[6],frame[7],frame[8],frame[1]),
                        (frame[9],frame[10],frame[11],frame[2]),(0,0,0,1)))
    scale = Matrix.Diagonal([data["size"][i]/data["meshSize"][i] for i in range(3)]+[1])
    tree = KDTree(len(data["vertices"]))
    for i,point in enumerate(data["vertices"]):
        tree.insert((basis @ transform @ scale) @ Vector(point),i)
    tree.balance()
    evaluated = obj.evaluated_get(deps).to_mesh()
    try:
        evaluated.calc_loop_triangles()
        count = len(evaluated.loop_triangles)
        error = max(tree.find(obj.matrix_world @ v.co)[2] for v in evaluated.vertices)
        assert count==len(data["faces"]) and count<=18000
        assert len(evaluated.uv_layers)==1 and len(evaluated.materials)==1
        assert error<1e-4,(obj.name,error)
        report["parts"].append({"name":obj.name,"evaluatedTriangles":count,
                                "maxVertexPositionDelta":error,"uvSets":1,"materials":1})
    finally:
        obj.evaluated_get(deps).to_mesh_clear()
assert report["parts"], "GLB contained no meshes"
report["totalTriangles"]=sum(p["evaluatedTriangles"] for p in report["parts"])
report_path.parent.mkdir(parents=True,exist_ok=True)
report_path.write_text(json.dumps(report,indent=2)+"\n")
print("VALIDATED",report["totalTriangles"],"triangles in",len(report["parts"]),"parts")

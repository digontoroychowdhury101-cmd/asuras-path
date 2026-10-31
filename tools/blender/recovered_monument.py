"""Build a separate inspection copy from permission-checked Studio mesh exports.

Blender --background --factory-startup --python tools/blender/recovered_monument.py -- INPUT OUTPUT
No decimation, remeshing, UV packing, uploaded-asset replacement or original-master edits.
The JSON recovery remains authoritative for corner UVs/normals and Roblox transforms.
"""
import gzip
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


def build(source, destination):
    assert bpy.app.background, "use a separate headless process; keep the user's editor untouched"
    source, destination = Path(source), Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    output = destination / "RecoveredMonument.blend"
    if output.exists():
        raise FileExistsError("choose a new destination; inspection copies are never overwritten")
    manifest = json.loads((source / "manifest.json").read_text())
    assert manifest["complete"], "source recovery is incomplete"
    collection = bpy.data.collections.new("RecoveredMonument")
    # Roblox X/Y/Z -> Blender X/-Z/Y: rotation only, preserving triangle winding.
    basis = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    created = [collection]
    report = {"kind": "derived uploaded-geometry inspection; not running-game proof",
              "source": str(source), "parts": [], "uvConvention": "Blender (u, 1-v); raw Roblox UVs retained in JSON"}
    try:
        for row in manifest["parts"]:
            packed = (source / row["file"]).read_bytes()
            assert hashlib.sha256(packed).hexdigest() == row["sha256"]
            data = json.loads(gzip.decompress(packed))
            mesh = bpy.data.meshes.new(data["name"])
            obj = bpy.data.objects.new(data["name"], mesh)
            created.extend([obj, mesh])
            collection.objects.link(obj)
            mesh.from_pydata([tuple(basis.to_3x3() @ Vector(v)) for v in data["vertices"]],
                             [], [f[:3] for f in data["faces"]])
            uv = mesh.uv_layers.new(name="UVMap")
            uv.data.foreach_set("uv", [x for f in data["faces"] for i in f[6:9]
                                       for x in (data["uvs"][i][0], 1-data["uvs"][i][1])])
            mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
            normals = [tuple(basis.to_3x3() @ Vector(data["normals"][i])) for f in data["faces"] for i in f[3:6]]
            mesh.normals_split_custom_set(normals)
            mesh.update()
            f = data["frame"]
            transform = Matrix(((f[3], f[4], f[5], f[0]), (f[6], f[7], f[8], f[1]),
                                (f[9], f[10], f[11], f[2]), (0, 0, 0, 1)))
            scale = Matrix.Diagonal([data["size"][i] / data["meshSize"][i] for i in range(3)] + [1])
            obj.matrix_world = basis @ transform @ scale @ basis.transposed()
            obj["UploadedMesh"] = data["mesh"]
            obj["PbrMaps"] = json.dumps(data["maps"], sort_keys=True)
            obj["SourceRecoverySHA256"] = row["sha256"]
            obj["OriginalDoubleSided"] = data["doubleSided"]
            material = bpy.data.materials.new(data["name"] + "_InspectionClay")
            created.append(material)
            material.use_nodes = True
            shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            shader.inputs["Base Color"].default_value = ((.24, .012, .025, 1) if "Leaves" in data["name"] else (.22, .16, .12, 1))
            shader.inputs["Roughness"].default_value = .7
            mesh.materials.append(material)
            # Surface-area-weighted density at the production 150/100 scale, for a 1024 map.
            densities = []
            for face in data["faces"]:
                a, b, c = [Vector(data["vertices"][i]) for i in face[:3]]
                area = (b - a).cross(c - a).length * .5 * 1.5 ** 2
                u, v, w = [Vector(data["uvs"][i]) for i in face[6:9]]
                uvarea = abs((v.x-u.x)*(w.y-u.y)-(v.y-u.y)*(w.x-u.x)) * .5
                if area > 1e-9:
                    densities.append((1024 * math.sqrt(uvarea / area), area))
            densities.sort()
            total = sum(a for _, a in densities)
            def percentile(q):
                accumulated = 0
                for density, area in densities:
                    accumulated += area
                    if accumulated >= total*q:
                        return density
                return densities[-1][0]
            stats = {"name": data["name"], "vertices": len(mesh.vertices), "triangles": len(mesh.polygons),
                     "density1024PixelsPerProductionStud": {str(q): percentile(q) for q in (.1,.5,.9)}}
            report["parts"].append(stats)
        # Blender 5.2.2 crashes copying an inactive Scene in libraries.write. A collection
        # library carries the same objects/materials without copying scene/view-layer state.
        bpy.data.libraries.write(str(output.resolve()), {collection}, fake_user=True)
        (destination / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"file": str(output), "parts": report["parts"]}))
    finally:
        # Remove only this function's temporary datablocks so the factory process can continue.
        bpy.data.batch_remove(created)
    return report


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    build(*args)

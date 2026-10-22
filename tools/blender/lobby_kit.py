"""Builds the Shrine of the Ascendant modular kit: textures, meshes, GLB, manifest, .blend, previews.

/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/lobby_kit.py [-- --batch nature]
Outputs assets/build/lobby_kit/: AsuraLobbyKit.glb (one single-material object per Roblox MeshPart,
named <Piece>__<Material>), textures/, manifest.json (Roblox-space part offsets from each piece
pivot, sizes and triangle counts), AsuraLobbyKit.blend (editable source) and preview renders.
Budgets follow assets/PHASE5.md: <= 19,500 triangles per MeshPart, <= 2,400 for repeated pieces.
Does not touch the imported Veiled Ascetic/tree sources.
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lobby_textures as TX  # noqa: E402
import lobby_kit_nature as NATURE  # noqa: E402
from lobby_kit_pieces import PIECES, Piece  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "build" / "lobby_kit"
# Pieces instanced dozens of times share the stricter repeated-stone cap.
# batch -> (pieces, texture sets, GLB/blend stem, manifest)
BATCHES = {"main": (PIECES, TX.SETS, "AsuraLobbyKit", "manifest.json"),
           "nature": (NATURE.PIECES, TX.NATURE, "AsuraLobbyNature", "manifest_nature.json")}
REPEATED = {"Cloud_A", "Cloud_B", "Cloud_C", "Shrub_Crimson", "Banner_Cloth", "Column_Lacquer", "Column_Base", "Bracket_Set", "Beam_Architrave", "Rail_Bay", "Rail_BayStair",
            "Rail_Post", "Lantern_Stone", "Lantern_Hanging", "Pool_Rim", "Pool_Corner", "Roof_Gallery",
            "Roof_GalleryEnd", "Rock_Outcrop"}
CAP, REPEATED_CAP = 19500, 2400
ORGANIC = ("Cloud_", "Tree_", "Shrub_", "Banner_")


def roblox(v):
    """Blender Z-up -> Roblox as Studio's 3D Importer places it (World Forward Front, Up Top):
    (x, y, z) -> (-x, z, y), verified against the uploaded parts. Blender -Y becomes Roblox -Z."""
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


def make_materials(images):
    mats = {}
    for name, maps in images.items():
        mat = bpy.data.materials.new(f"Kit_{name}")
        mat.use_nodes = True
        tree = mat.node_tree
        tree.nodes.clear()
        out = tree.nodes.new("ShaderNodeOutputMaterial")
        bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
        tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        for label, image in maps.items():
            tex = tree.nodes.new("ShaderNodeTexImage")
            tex.image = image
            if label == "Normal":
                nm = tree.nodes.new("ShaderNodeNormalMap")
                tree.links.new(tex.outputs["Color"], nm.inputs["Color"])
                tree.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
            else:
                socket = {"Color": "Base Color", "Roughness": "Roughness", "Metalness": "Metallic"}[label]
                tree.links.new(tex.outputs["Color"], bsdf.inputs[socket])
        mats[name] = mat
    return mats


def triangles(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def build(batch="main"):
    pieces, sets, stem, manifest_name = BATCHES[batch]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    (OUT / "textures").mkdir(parents=True, exist_ok=True)
    mats = make_materials(TX.save(str(OUT / "textures"), sets=sets))
    kit = bpy.data.collections.new(stem)
    bpy.context.scene.collection.children.link(kit)
    manifest = {"units": "studs", "axes": "Roblox (x, y up, z) as imported; Blender -Y (piece front) is Roblox -Z",
                "studsPerTile": TX.STUDS, "pieces": {}}
    problems = []
    cursor, row_depth, row_y = 0.0, 0.0, 0.0
    for name, fn in pieces:
        pc = Piece(name)
        fn(pc)
        lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        parts, objects = {}, []
        for material, mesh in pc.meshes.items():
            bm = mesh.finish()
            me = bpy.data.meshes.new(mesh.name)
            bm.to_mesh(me)
            bm.free()
            me.shade_smooth()
            if not name.startswith(ORGANIC):  # clouds and foliage stay fully smooth
                me.set_sharp_from_angle(angle=math.radians(38))
            me.validate(clean_customdata=False)
            ob = bpy.data.objects.new(mesh.name, me)
            ob.data.materials.append(mats[material])
            kit.objects.link(ob)
            objects.append(ob)
            pts = [v.co for v in me.vertices]
            a = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
            b = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
            lo = Vector((min(lo.x, a.x), min(lo.y, a.y), min(lo.z, a.z)))
            hi = Vector((max(hi.x, b.x), max(hi.y, b.y), max(hi.z, b.z)))
            tris = triangles(me)
            cap = REPEATED_CAP if name in REPEATED else CAP
            if tris > cap:
                problems.append(f"{mesh.name}: {tris} triangles > {cap}")
            if not me.uv_layers:
                problems.append(f"{mesh.name}: no UVs")
            size = b - a
            parts[mesh.name] = {"material": material, "center": roblox((a + b) * 0.5),
                                "size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)], "triangles": tris}
        span = hi - lo
        if cursor + span.x > 260:
            cursor, row_y, row_depth = 0.0, row_y + row_depth + 12, 0.0
        origin = Vector((cursor - lo.x, row_y - lo.y, 0))
        for ob in objects:
            ob.data.transform(Matrix.Translation(origin))
        cursor += span.x + 10
        row_depth = max(row_depth, span.y)
        manifest["pieces"][name] = {"layoutOrigin": roblox(origin), "bounds": [roblox(lo), roblox(hi)],
                                    "size": [round(span.x, 3), round(span.z, 3), round(span.y, 3)], "parts": parts}
    manifest["totals"] = {"pieces": len(manifest["pieces"]),
                          "meshParts": sum(len(p["parts"]) for p in manifest["pieces"].values()),
                          "triangles": sum(q["triangles"] for p in manifest["pieces"].values() for q in p["parts"].values())}
    manifest["problems"] = problems
    (OUT / manifest_name).write_text(json.dumps(manifest, indent=1) + "\n")
    for ob in kit.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{stem}.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_animations=False, export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{stem}.blend"))
    print("KIT", json.dumps(manifest["totals"]), "problems:", problems)
    return manifest


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build(argv[1] if len(argv) > 1 and argv[0] == "--batch" else "main")

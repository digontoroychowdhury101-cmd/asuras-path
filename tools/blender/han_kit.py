"""Builds AsuraHanKit: 0 A.D. Han architecture (CC BY-SA 3.0, Wildfire Games) and MIT nature props
(HungryProton/scatter, TokisanGames/Terrain3D) as one Roblox-ready GLB, manifest and contact sheet.

    blender -b --factory-startup -P tools/blender/han_kit.py

Sources are the hash-pinned files from assets/GITHUB_MODELS.json (fetch_github_assets.py). COLLADA is
read by tools/assets/dae_to_obj.py (Blender 5 has no COLLADA importer). Textures become Roblox PBR maps
of at most 1024 px: 0 A.D. specular -> roughness, its player-colour alpha mask baked as crimson lacquer.
Each piece sits on its own origin (base centre) in a row; output: assets/build/han_kit/.
"""
from pathlib import Path
import json
import math
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/assets"))
import dae_to_obj  # noqa: E402

SRC = ROOT / "assets/github"
OUT = ROOT / "assets/build/han_kit"
LACQUER = (0.55, 0.12, 0.1)

# Piece -> (source, texture set). Han meshes share one atlas.
PIECES = {
    "HanPagoda": ("0ad/han_pagoda.dae", "HanStruct"), "HanTemple": ("0ad/han_temple.dae", "HanStruct"),
    "HanShrine": ("0ad/han_shrine.dae", "HanStruct"), "HanGreatTower": ("0ad/han_great_tower.dae", "HanStruct"),
    "HanDefenseTower": ("0ad/han_defense_tower.dae", "HanStruct"), "HanWallGate": ("0ad/han_wall_gate.dae", "HanStruct"),
    "HanWallTower": ("0ad/han_wall_tower.dae", "HanStruct"), "HanWallLong": ("0ad/han_wall_long.dae", "HanStruct"),
    "HanBixiePedestal": ("0ad/han_bixie_pedestal.dae", "HanStruct"), "HanHouse": ("0ad/han_house_a.dae", "HanStruct"),
    "HanBixie": ("0ad/han_bixie.dae", "HanBixie"), "HanLantern": ("0ad/han_temple_lantern.dae", "HanLantern"),
    "HanCauldron": ("0ad/han_temple_cauldron.dae", "HanCauldron"),
    "Pine": ("scatter/pine_tree.glb", None), "BoulderLarge": ("scatter/large_rock.glb", "ScatterRock"),
    "BoulderSmall": ("scatter/small_rock.glb", "ScatterRock"), "CragA": ("terrain3d/RockA.glb", "Crag"),
    "CragB": ("terrain3d/RockB.glb", "Crag"), "CragC": ("terrain3d/RockC.glb", "Crag"),
}


def image(path: Path, name: str):
    img = bpy.data.images.load(str(path))
    img.name = name
    return img


def pixels(img):
    return list(img.pixels[:])


def write(name: str, w: int, h: int, data, alpha=False):
    """Scale to at most 1024 px on the long side and save as PNG in OUT/textures."""
    img = bpy.data.images.new(name, w, h, alpha=alpha)
    img.pixels[:] = data
    scale = min(1.0, 1024 / max(w, h))
    if scale < 1:
        img.scale(int(w * scale), int(h * scale))
    img.filepath_raw = str(OUT / "textures" / f"{name}.png")
    img.file_format = "PNG"
    img.save()
    return img


def texture_sets():
    """Texture set -> {Color, Normal, Roughness, Metalness} Blender images."""
    sets = {}

    def oad(name, color, norm=None, spec=None, metal_from_spec=False):
        c = image(SRC / f"0ad/{color}.png", f"{name}_src")
        w, h = c.size
        px = pixels(c)
        col = []
        for i in range(0, len(px), 4):
            r, g, b, a = px[i:i + 4]
            # 0 A.D. alpha < 1 marks player colour; bake it as lacquer red.
            col += [r * a + r * LACQUER[0] * 2 * (1 - a), g * a + g * LACQUER[1] * 2 * (1 - a), b * a + b * LACQUER[2] * 2 * (1 - a), 1]
        out = {"Color": write(f"{name}_Color", w, h, col)}
        if norm:
            n = image(SRC / f"0ad/{norm}.png", f"{name}_nsrc")
            npx = pixels(n)
            out["Normal"] = write(f"{name}_Normal", *n.size, [v if (k % 4) != 3 else 1 for k, v in enumerate(npx)])
        if spec:
            s = image(SRC / f"0ad/{spec}.png", f"{name}_ssrc")
            spx = pixels(s)
            rough, metal = [], []
            for i in range(0, len(spx), 4):
                lum = (spx[i] + spx[i + 1] + spx[i + 2]) / 3
                rv = max(0.25, min(1.0, 1 - lum * 0.85))
                mv = min(1.0, lum * 1.4) if metal_from_spec else 0.0
                rough += [rv, rv, rv, 1]
                metal += [mv, mv, mv, 1]
            out["Roughness"] = write(f"{name}_Roughness", *s.size, rough)
            out["Metalness"] = write(f"{name}_Metalness", *s.size, metal)
        return out

    sets["HanStruct"] = oad("HanStruct", "han_struct_02", "han_struct_02_norm", "han_struct_02_spec")
    sets["HanBixie"] = oad("HanBixie", "han_bixie_gold", "han_bixie_norm", "han_bixie_gold_spec", metal_from_spec=True)
    sets["HanLantern"] = oad("HanLantern", "han_temple_lantern")
    sets["HanCauldron"] = oad("HanCauldron", "han_temple_cauldron")
    # scatter's textures are greyscale; Godot tints them in m_rock / m_trunk / m_pine_leaves (.tres).
    def tinted(name, path, tint, alpha=False):
        src = image(SRC / path, f"{name}_src")
        px = pixels(src)
        out = []
        for i in range(0, len(px), 4):
            out += [px[i] * tint[0], px[i + 1] * tint[1], px[i + 2] * tint[2], px[i + 3] if alpha else 1]
        return {"Color": write(f"{name}_Color", *src.size, out, alpha=alpha)}

    sets["ScatterRock"] = tinted("ScatterRock", "scatter/t_rock.jpg", (0.44, 0.41, 0.39))
    sets["PineBark"] = tinted("PineBark", "scatter/t_tree_bark.png", (0.47, 0.38, 0.31))
    sets["PineNeedles"] = tinted("PineNeedles", "scatter/t_pine_branch.png", (0.2, 0.3, 0.15), alpha=True)  # gradient mid-tone
    sets["Crag"] = {k: image(SRC / f"terrain_ready/AsuraCliff_{k}.png", f"Crag_{k}") for k in ("Color", "Normal", "Roughness")}
    # Every set gets all four maps so the importer gives each MeshPart a full SurfaceAppearance.
    flat = {"Normal": (0.5, 0.5, 1.0), "Roughness": (0.85, 0.85, 0.85), "Metalness": (0.0, 0.0, 0.0)}
    for name, maps in sets.items():
        for key, value in flat.items():
            if key not in maps:
                maps[key] = write(f"{name}_{key}", 4, 4, [*value, 1.0] * 16)
    return sets


def material(name: str, maps: dict, alpha=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    for key, img in maps.items():
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        if key == "Color":
            tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
            if alpha:
                tree.links.new(node.outputs["Alpha"], bsdf.inputs["Alpha"])
        elif key == "Normal":
            img.colorspace_settings.name = "Non-Color"
            nm = tree.nodes.new("ShaderNodeNormalMap")
            tree.links.new(node.outputs["Color"], nm.inputs["Color"])
            tree.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            img.colorspace_settings.name = "Non-Color"
            tree.links.new(node.outputs["Color"], bsdf.inputs["Roughness" if key == "Roughness" else "Metallic"])
    if alpha:
        mat.blend_method = "CLIP" if hasattr(mat, "blend_method") else mat.blend_method
    return mat


def load(source: str):
    before = set(bpy.data.objects)
    path = SRC / source
    if path.suffix == ".dae":
        obj = OUT / "obj" / (path.stem + ".obj")
        obj.parent.mkdir(parents=True, exist_ok=True)
        dae_to_obj.convert(path, obj)
        bpy.ops.wm.obj_import(filepath=str(obj), forward_axis="NEGATIVE_Z", up_axis="Y")
    else:
        bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before and o.type == "MESH"]


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    (OUT / "textures").mkdir(parents=True, exist_ok=True)
    sets = texture_sets()
    mats = {k: material(k, v, alpha=(k == "PineNeedles")) for k, v in sets.items()}
    manifest = {"units": "source units (1 = 1 stud as imported)", "pieces": {}}
    cursor = 0.0
    for name, (source, tex) in PIECES.items():
        objs = load(source)
        for o in objs:
            bpy.context.view_layer.update()
            o.data.transform(o.matrix_world)
            o.matrix_world = Matrix.Identity(4)
            if tex:
                o.data.materials.clear()
                o.data.materials.append(mats[tex])
            else:  # pine: the glTF has no materials; its objects are named Leaves and Trunk
                o.data.materials.clear()
                o.data.materials.append(mats["PineNeedles" if "leaves" in o.name.lower() else "PineBark"])
        pts = [v.co for o in objs for v in o.data.vertices]  # bound_box is stale after data.transform
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        size = hi - lo
        shift = Vector((cursor - (lo.x + hi.x) / 2 + size.x / 2, -(lo.y + hi.y) / 2, -lo.z))
        tris = 0
        for o in objs:
            o.data.transform(Matrix.Translation(shift))
            o.name = f"{name}__{o.data.materials[0].name if o.data.materials else 'Mat'}"
            o.data.name = o.name  # Studio's importer names MeshParts after the mesh data
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
        cursor += size.x + 8
        manifest["pieces"][name] = {"source": source, "texture": tex or "PineBark+PineNeedles", "triangles": tris,
                                    "size": [round(size.x, 3), round(size.z, 3), round(size.y, 3)], "parts": [o.name for o in objs]}
        print("PIECE", name, tris, [round(v, 1) for v in size])
    manifest["totals"] = {"pieces": len(manifest["pieces"]), "triangles": sum(p["triangles"] for p in manifest["pieces"].values())}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
    for o in bpy.data.objects:
        o.select_set(o.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=str(OUT / "AsuraHanKit.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_animations=False, export_yup=True)
    preview()
    print("KIT", json.dumps(manifest["totals"]))


def preview():
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH") if e in engines)
    sc.render.resolution_x, sc.render.resolution_y = 1800, 700
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    sc.world = world
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value, bg.inputs[1].default_value = (0.5, 0.55, 0.62, 1), 1.0
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy, sun.rotation_euler = 3.5, (math.radians(55), 0, math.radians(35))
    sc.collection.objects.link(sun)
    pts = [v.co for o in sc.objects if o.type == "MESH" for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type, cam.data.ortho_scale = "ORTHO", (hi.x - lo.x) * 1.05
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = centre + Vector((0, -(hi.x - lo.x), (hi.z - lo.z) * 0.9))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(OUT / "contact_sheet.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()

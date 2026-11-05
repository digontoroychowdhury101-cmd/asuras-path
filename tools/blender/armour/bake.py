"""Unwrap, bake and export one armour set (after build.py).

    Blender -b assets/source/armour/<set>/<set>.blend -P tools/blender/armour/bake.py -- <set>

Bakes the master's PBR (colour, roughness, metalness, geometry normals) onto the game pieces' atlases, one 2048 atlas per body
region so the chest does not share texels with the boots. Writes textures/, export/<set>_Game.glb and, for bind_skin.py,
work/opening_cast_bake/<set>/pieces.json. Every value in manifest.json is measured from the game meshes.
"""
import json
import math
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SET = sys.argv[sys.argv.index("--") + 1]
OUT = ROOT / "assets/source/armour" / SET
SIZE = 2048
CHANNELS = ("Color", "Rough", "Metal", "Normal")
GROUPS = {"Cuirass": ("UpperTorso",), "Skirt": ("LowerTorso", "LeftUpperLeg", "RightUpperLeg"),
          "Arms": ("LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand"),
          "Legs": ("LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot")}


def select(objs, active=None):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def unwrap(objs):
    for o in objs:
        me = o.data
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])
        me.uv_layers.new(name="UVMap")
    select(objs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=0.003, scale=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def emission_mode(mats, key):
    for m in mats:
        nt = m.node_tree
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        em = nt.nodes.get("BAKE_EMIT") or nt.nodes.new("ShaderNodeEmission")
        em.name = "BAKE_EMIT"
        for l in list(out.inputs["Surface"].links):
            nt.links.remove(l)
        if key is None:
            nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
            continue
        for l in list(em.inputs["Color"].links):
            nt.links.remove(l)
        nt.links.new(nt.nodes["OUT_" + key].outputs[0], em.inputs["Color"])
        nt.links.new(em.outputs[0], out.inputs["Surface"])


def target_material(name, images):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    nodes = {}
    for ch in CHANNELS:
        n = nt.nodes.new("ShaderNodeTexImage")
        n.name = n.label = ch
        n.image = images[ch]
        nodes[ch] = n
    nt.links.new(nodes["Color"].outputs[0], bsdf.inputs["Base Color"])
    nt.links.new(nodes["Rough"].outputs[0], bsdf.inputs["Roughness"])
    nt.links.new(nodes["Metal"].outputs[0], bsdf.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nodes["Normal"].outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    return m, nodes


def bake(group, objs):
    prefix = f"{SET}_{group}"
    images = {}
    for ch in CHANNELS:
        img = bpy.data.images.new(f"{prefix}_{ch}", SIZE, SIZE, alpha=False, float_buffer=(ch == "Normal"))
        img.colorspace_settings.name = "sRGB" if ch == "Color" else "Non-Color"
        img.generated_color = (0.5, 0.5, 1.0, 1.0) if ch == "Normal" else (0, 0, 0, 1)
        images[ch] = img
    mat, nodes = target_material(prefix, images)
    masters = [bpy.data.objects[o.name + "_Master"] for o in objs]
    src = {m for mo in masters for m in mo.data.materials}
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
    sc = bpy.context.scene
    bk = sc.render.bake
    bk.use_selected_to_active, bk.use_cage, bk.cage_extrusion, bk.max_ray_distance, bk.margin, bk.use_clear = True, False, 0.07, 0.18, 8, False
    for ch in CHANNELS:
        for n in mat.node_tree.nodes:
            n.select = False
        mat.node_tree.nodes.active = nodes[ch]
        nodes[ch].select = True
        emission_mode(src, None if ch == "Normal" else {"Color": "COLOR", "Rough": "ROUGH", "Metal": "METAL"}[ch])
        sc.cycles.samples = {"Normal": 4, "Color": 24}.get(ch, 2)
        for o, mo in zip(objs, masters):
            select([mo, o], active=o)
            t0 = time.time()
            res = bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT") if ch == "Normal" else bpy.ops.object.bake(type="EMIT")
            assert res == {"FINISHED"}, (ch, o.name, res)
            print(f"  baked {ch:6s} {o.name:24s} {time.time() - t0:5.1f}s", flush=True)
    emission_mode(src, None)
    files = {}
    for ch, img in images.items():
        p = OUT / "textures" / f"{prefix}_{ch}_{SIZE}.png"
        p.parent.mkdir(parents=True, exist_ok=True)
        img.filepath_raw, img.file_format = str(p), "PNG"
        img.save()
        files[ch] = str(p.relative_to(ROOT))
    return files


def bounds(o):
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def main():
    t0 = time.time()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception as e:  # noqa: BLE001
        print("GPU unavailable:", e)
    for o in list(bpy.data.objects):  # review stand-ins never belong in a bake
        if o.type != "MESH" or not ("Master" in [c.name for c in o.users_collection] or "Game" in [c.name for c in o.users_collection]):
            bpy.data.objects.remove(o)
    game = {o["AsuraBone"]: o for o in bpy.data.collections["Game"].all_objects}
    tex = {}
    for group, limbs in GROUPS.items():
        objs = [game[l] for l in limbs if l in game]
        unwrap(objs)
        tex[group] = bake(group, objs)
    objs = list(game.values())
    (OUT / "export").mkdir(exist_ok=True)
    glb = OUT / "export" / f"{SET}_Game.glb"
    select(objs)
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_yup=True, export_apply=True, export_extras=True, export_materials="EXPORT")
    pieces, stats = {}, {}
    for o in objs:
        lo, hi = bounds(o)
        c, s = (lo + hi) / 2, hi - lo
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        pieces[o.name] = {"bone": o["AsuraBone"], "role": None, "centre": [c.x, c.z, -c.y], "size": [s.x, s.z, s.y], "tris": tris}
        stats[o.name] = tris
    dst = ROOT / "work/opening_cast_bake" / SET / "pieces.json"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(json.dumps(pieces, indent=1))
    master = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.collections["Master"].all_objects)
    manifest = {"set": SET, "provenance": "Project-authored: constructed forms in tools/blender/armour, procedural PBR baked from the master",
                "units": "studs, scale 1, default R15 rest pose", "axes": "Blender Z = Roblox +Y, Blender +Y = Roblox -Z",
                "texture_size": SIZE, "atlases": tex, "game_triangles": sum(stats.values()), "max_piece_triangles": max(stats.values()),
                "master_triangles": master, "pieces": stats, "glb": str(glb.relative_to(ROOT))}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1))
    bpy.ops.wm.save_mainfile(compress=True)
    print(json.dumps({k: manifest[k] for k in ("game_triangles", "max_piece_triangles", "master_triangles")}))
    print("baked in %.0fs" % (time.time() - t0), flush=True)


main()

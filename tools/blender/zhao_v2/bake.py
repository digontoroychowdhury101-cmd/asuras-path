"""Unwrap, bake, export and measure General Zhao v2 (run after build.py).

    Blender -b assets/source/bosses/general_zhao/v2_design/GeneralZhao_v2.blend -P tools/blender/zhao_v2/bake.py

Bakes the master's procedural materials (colour with AO cavity and pointiness wear, roughness, metalness)
and its geometry normals onto the game meshes' shared atlases: body 2048 -> 1024, weapon 1024 -> 512.
Exports the game template (GLB + FBX) and the guandao alone (GLB), and writes manifest.json with values
measured from the exported meshes, not assumed.
"""
import json
import math
import time
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/source/bosses/general_zhao/v2_design"
REL = lambda p: str(Path(p).relative_to(ROOT))
HAND_CENTRE = Vector((1.5, 0.0, -0.85))   # Roblox RightHand centre (1.5, -0.85, 0) in Blender axes
TIP_TARGET, TIP_TOL = 9.2, 0.5
LIMBS = ["Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
         "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]
SETS = {"body": ("ZhaoBodyV2", 2048, 1024), "weapon": ("ZhaoWeaponV2", 1024, 512)}
CHANNELS = ("Color", "Rough", "Metal", "Normal")


def game_objects():
    return [o for o in bpy.data.collections["ZhaoV2_Game"].all_objects if o.type == "MESH"]


def is_weapon(o):
    return o.get("AsuraRole") == "Weapon"


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def select(objs, active=None):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def unwrap(objs, boost):
    for o in objs:
        me = o.data
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])
        me.uv_layers.new(name="UVMap")
    select(objs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in objs:  # spend texels where the eye goes: the face and the crest
        k = boost.get(o.name, 1.0)
        if k != 1.0:
            uv = o.data.uv_layers["UVMap"].data
            for d in uv:
                d.uv = d.uv * k
    select(objs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.004, scale=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def emission_mode(mats, key):
    """Route OUT_<key> of each master material into an Emission shader for baking (key None restores)."""
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
        r = nt.nodes["OUT_" + key]
        for l in list(em.inputs["Color"].links):
            nt.links.remove(l)
        nt.links.new(r.outputs[0], em.inputs["Color"])
        em.inputs["Strength"].default_value = 1.0
        nt.links.new(em.outputs[0], out.inputs["Surface"])


def target_material(name, images):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (600, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (300, 0)
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    nodes = {}
    for i, ch in enumerate(CHANNELS):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.name = n.label = ch
        n.image = images[ch]
        n.location = (-400, 300 - i * 280)
        nodes[ch] = n
    nt.links.new(nodes["Color"].outputs[0], bsdf.inputs["Base Color"])
    nt.links.new(nodes["Rough"].outputs[0], bsdf.inputs["Roughness"])
    nt.links.new(nodes["Metal"].outputs[0], bsdf.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.location = (0, -600)
    nt.links.new(nodes["Normal"].outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    return m, nodes


def bake_set(kind, objs):
    prefix, size, game_size = SETS[kind]
    images = {}
    for ch in CHANNELS:
        img = bpy.data.images.new(f"{prefix}_{ch}", size, size, alpha=False, float_buffer=(ch == "Normal"))
        img.colorspace_settings.name = "sRGB" if ch == "Color" else "Non-Color"
        img.generated_color = (0.5, 0.5, 1.0, 1.0) if ch == "Normal" else (0, 0, 0, 1)
        images[ch] = img
    mat, nodes = target_material(prefix, images)
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
    masters = [bpy.data.objects[o.name + "_Master"] for o in objs]
    src_mats = {m for mo in masters for m in mo.data.materials}
    sc = bpy.context.scene
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.use_cage = False
    bk.cage_extrusion = 0.06
    bk.max_ray_distance = 0.16
    bk.margin = 6
    bk.use_clear = False
    for ch in CHANNELS:
        for n in mat.node_tree.nodes:
            n.select = False
        mat.node_tree.nodes.active = nodes[ch]
        nodes[ch].select = True
        if ch == "Normal":
            emission_mode(src_mats, None)
            sc.cycles.samples = 4
        else:
            emission_mode(src_mats, {"Color": "COLOR", "Rough": "ROUGH", "Metal": "METAL"}[ch])
            sc.cycles.samples = 16 if ch == "Color" else 2
        for o, mo in zip(objs, masters):
            select([mo, o], active=o)
            t0 = time.time()
            if ch == "Normal":
                res = bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
            else:
                res = bpy.ops.object.bake(type="EMIT")
            if res != {"FINISHED"}:
                raise RuntimeError(f"bake {ch} {o.name}: {res}")
            print(f"  baked {ch:6s} {o.name:22s} {time.time() - t0:5.1f}s", flush=True)
    emission_mode(src_mats, None)
    files = {}
    for ch, img in images.items():
        mp = OUT / "textures/master" / f"{prefix}_{ch}_{size}.png"
        gp = OUT / "textures/game" / f"{prefix}_{ch}_{game_size}.png"
        mp.parent.mkdir(parents=True, exist_ok=True)
        gp.parent.mkdir(parents=True, exist_ok=True)
        img.filepath_raw = str(mp)
        img.file_format = "PNG"
        img.save()
        g = img.copy()
        g.scale(game_size, game_size)
        g.filepath_raw = str(gp)
        g.file_format = "PNG"
        g.save()
        # the game material reads the game-size maps
        img.filepath = str(mp)
        g.filepath = str(gp)
        g.name = f"{prefix}_{ch}_{game_size}"
        nodes[ch].image = g
        files[ch] = {"master": REL(mp), "game": REL(gp), "master_size": [size, size], "game_size": [game_size, game_size]}
    return files


def roblox_size(o):
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    d = hi - lo
    return [round(d.x, 3), round(d.z, 3), round(d.y, 3)], lo, hi


def measure_tip(weapons):
    far_vertex = 0.0
    extent = 0.0
    corner = 0.0
    for o in weapons:
        pts = [o.matrix_world @ v.co for v in o.data.vertices]
        for p in pts:
            far_vertex = max(far_vertex, (p - HAND_CENTRE).length)
            extent = max(extent, p.y - HAND_CENTRE.y)
        # BossTemplateCheck measures the 8 corners of each weapon MeshPart's box about its pivot-centred bounds
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        for i in range(8):
            c = Vector((hi.x if i & 1 else lo.x, hi.y if i & 2 else lo.y, hi.z if i & 4 else lo.z))
            corner = max(corner, (c - HAND_CENTRE).length)
    return round(far_vertex, 3), round(extent, 3), round(corner, 3)


def export(objs, path, fmt):
    select(objs)
    if fmt == "GLB":
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                                  export_apply=True, export_extras=True, export_materials="EXPORT")
    else:
        bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, axis_forward="-Z", axis_up="Y",
                                 apply_unit_scale=True, path_mode="COPY", embed_textures=True, use_custom_props=True,
                                 mesh_smooth_type="FACE")


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
        print("GPU unavailable, using CPU:", e)
    objs = game_objects()
    body = [o for o in objs if not is_weapon(o)]
    weap = [o for o in objs if is_weapon(o)]
    unwrap(body, {"Zhao_Head": 1.8})
    unwrap(weap, {})
    tex = {"body": bake_set("body", body), "weapon": bake_set("weapon", weap)}
    exp = OUT / "export"
    exp.mkdir(exist_ok=True)
    glb, fbx, gglb = exp / "GeneralZhao_v2_Game.glb", exp / "GeneralZhao_v2_Game.fbx", exp / "Zhao_Guandao_v2.glb"
    export(objs, glb, "GLB")
    export(objs, fbx, "FBX")
    export(weap, gglb, "GLB")
    levels = {}
    for level, coll in (("master", "ZhaoV2_Master"), ("game", "ZhaoV2_Game")):
        obs = [o for o in bpy.data.collections[coll].all_objects if o.type == "MESH"]
        d = {}
        allpts_lo, allpts_hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        for o in obs:
            size, lo, hi = roblox_size(o)
            allpts_lo = Vector(map(min, allpts_lo, lo))
            allpts_hi = Vector(map(max, allpts_hi, hi))
            p = o.location
            d[o.name] = {"bone": o["AsuraBone"], "role": o.get("AsuraRole"), "triangles": tris(o), "vertices": len(o.data.vertices),
                         "pivot_roblox": [round(p.x, 3), round(p.z, 3), round(-p.y, 3)], "size_roblox": size}
        t = [v["triangles"] for v in d.values()]
        wt = [v["triangles"] for v in d.values() if v["role"] == "Weapon"]
        covered = sorted({v["bone"] for v in d.values()})
        levels[level] = {"mesh_count": len(d), "total_triangles": sum(t), "body_triangles": sum(t) - sum(wt),
                         "weapon_triangles": sum(wt), "max_piece_triangles": max(t),
                         "limbs_covered": len(set(covered) & set(LIMBS)), "limbs_missing": sorted(set(LIMBS) - set(covered)),
                         "bounds_roblox_y": [round(allpts_lo.z, 3), round(allpts_hi.z, 3)], "objects": d}
    gw = [o for o in bpy.data.collections["ZhaoV2_Game"].all_objects if is_weapon(o)]
    far, ext, corner = measure_tip(gw)
    head_top = max((o.matrix_world @ v.co).z for o in body if o.name == "Zhao_Head" for v in o.data.vertices)
    manifest = {
        "provenance": "Original project-authored v2 rebuild: constructed forms in tools/blender/zhao_v2 (no TRELLIS, no Rodin); "
                      "procedural PBR baked from the master onto game atlases",
        "units": "studs, scale 1, default R15 rest pose (arms down)",
        "axes": "Blender Z = Roblox +Y; Blender +Y = Roblox -Z (forward); GLB exported Y-up",
        "limb_centres": "R15 centres measured in Studio (same table as v1)",
        "limits": {"triangles_target": 22000, "piece_limit": 10000, "body_texture": 1024, "weapon_texture": 512,
                   "tip_target": TIP_TARGET, "tip_tolerance": TIP_TOL},
        "measured": {
            "game_total_triangles": levels["game"]["total_triangles"],
            "game_max_piece_triangles": levels["game"]["max_piece_triangles"],
            "game_limbs_covered": levels["game"]["limbs_covered"],
            "tip_farthest_vertex_from_hand_centre": far,
            "tip_extent_along_hand_minus_z": ext,
            "tip_bounding_corner_from_hand_centre": corner,
            "tip_within_tolerance": abs(corner - TIP_TARGET) <= TIP_TOL and abs(far - TIP_TARGET) <= TIP_TOL,
            "head_top_without_plumes_y": round(head_top, 3),
            "sole_y": levels["game"]["bounds_roblox_y"][0],
            "plume_top_y": levels["game"]["bounds_roblox_y"][1],
        },
        "levels": levels,
        "textures": tex,
        "exports": {"game_glb": REL(glb), "game_fbx": REL(fbx), "guandao_glb": REL(gglb)},
        "blend": REL(bpy.data.filepath),
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
    bpy.ops.wm.save_mainfile(compress=True)
    print(json.dumps(manifest["measured"], indent=2))
    print("bake+export in %.0fs" % (time.time() - t0))


main()

"""Unwrap, bake, export and measure one opening-cast character (run after build.py).

    blender -b assets/source/opening_cast/monk/Monk_v1.blend -P tools/blender/opening_cast/bake.py -- monk

Bakes the master's procedural materials (colour with cavity and wear, roughness, metalness) and its geometry
normals onto the game pieces' shared atlases: body 2048 -> 1024 (weapon 1024 -> 512 when the character carries
one). Exports the game pieces as one GLB (Studio 3D Importer input, Y-up, transforms applied about each limb
centre) plus an FBX (-Z forward, Y up), and writes a manifest measured from the exported meshes.
"""
import json
import math
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from build import CHARS, PIVOT, paths  # noqa: E402

ROOT = HERE.parents[2]
REL = lambda p: Path(p).relative_to(ROOT).as_posix()
CHANNELS = ("Color", "Rough", "Metal", "Normal")
PIECE_CAP = 18000  # triangles per MeshPart (the importer's 20k limit, with headroom)


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def select(objs, active=None):
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def unwrap(objs, boost):
    for o in objs:
        while o.data.uv_layers:
            o.data.uv_layers.remove(o.data.uv_layers[0])
        o.data.uv_layers.new(name="UVMap")
    select(objs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in objs:  # spend texels where the eye goes
        k = boost.get(o.name, 1.0)
        if k != 1.0:
            for d in o.data.uv_layers["UVMap"].data:
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
        for l in list(em.inputs["Color"].links):
            nt.links.remove(l)
        nt.links.new(nt.nodes["OUT_" + key].outputs[0], em.inputs["Color"])
        em.inputs["Strength"].default_value = 1.0
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
    nt.links.new(nodes["Normal"].outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    return m, nodes


def bake_set(out_dir, prefix, size, game_size, objs):
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
    bk.use_selected_to_active, bk.use_cage, bk.cage_extrusion, bk.max_ray_distance = True, False, 0.06, 0.16
    bk.margin, bk.use_clear = 6, False
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
            res = bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT") if ch == "Normal" else bpy.ops.object.bake(type="EMIT")
            if res != {"FINISHED"}:
                raise RuntimeError(f"bake {ch} {o.name}: {res}")
            print(f"  baked {ch:6s} {o.name:24s} {time.time() - t0:5.1f}s", flush=True)
    emission_mode(src_mats, None)
    files = {}
    for ch, img in images.items():
        mp = out_dir / "textures/master" / f"{prefix}_{ch}_{size}.png"
        gp = out_dir / "textures/game" / f"{prefix}_{ch}_{game_size}.png"
        for p in (mp, gp):
            p.parent.mkdir(parents=True, exist_ok=True)
        img.filepath_raw, img.file_format = str(mp), "PNG"
        img.save()
        g = img.copy()
        g.scale(game_size, game_size)
        g.filepath_raw, g.file_format = str(gp), "PNG"
        g.save()
        img.filepath, g.filepath = str(mp), str(gp)
        g.name = f"{prefix}_{ch}_{game_size}"
        nodes[ch].image = g
        files[ch] = {"master": REL(mp), "game": REL(gp), "master_size": size, "game_size": game_size}
    return files


def roblox_bounds(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def export(objs, path, fmt):
    select(objs)
    path.parent.mkdir(parents=True, exist_ok=True)
    if fmt == "GLB":
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                                  export_apply=True, export_extras=True, export_materials="EXPORT")
    else:
        bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, axis_forward="-Z", axis_up="Y",
                                 apply_unit_scale=True, path_mode="COPY", embed_textures=True, use_custom_props=True,
                                 mesh_smooth_type="FACE")


def gpu(sc):
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA", "HIP", "METAL"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            devs = [d for d in prefs.devices if d.type == kind]
            if devs:
                for d in prefs.devices:
                    d.use = d.type == kind
                sc.cycles.device = "GPU"
                return kind
        except TypeError:
            continue
    return "CPU"


def main(key):
    _, name, defid, ver = CHARS[key]
    out_dir, _ = paths(key)
    t0 = time.time()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    device = gpu(sc)
    print("bake device:", device)
    objs = [o for o in bpy.data.collections[f"{name}_Game"].all_objects if o.type == "MESH"]
    body = [o for o in objs if o.get("AsuraRole") != "Weapon"]
    weap = [o for o in objs if o.get("AsuraRole") == "Weapon"]
    unwrap(body, {f"{name}_Head": 1.8})
    tex = {"body": bake_set(out_dir, f"{name}Body", 2048, 1024, body)}
    if weap:
        unwrap(weap, {})
        tex["weapon"] = bake_set(out_dir, f"{name}Weapon", 1024, 512, weap)
    build_dir = ROOT / "assets/build/opening_cast" / key
    glb, fbx = build_dir / f"{name}_v{ver}_Game.glb", build_dir / f"{name}_v{ver}_Game.fbx"
    export(objs, glb, "GLB")
    export(objs, fbx, "FBX")
    pieces = {}
    for o in objs:
        lo, hi = roblox_bounds([o])
        p = o.location
        pieces[o.name] = {"bone": o["AsuraBone"], "role": o.get("AsuraRole"), "triangles": tris(o), "vertices": len(o.data.vertices),
                          "pivot_roblox": [round(p.x, 3), round(p.z, 3), round(-p.y, 3)],
                          "size_roblox": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)]}
    lo, hi = roblox_bounds(objs)
    master_tris = sum(tris(o) for o in bpy.data.collections[f"{name}_Master"].all_objects)
    covered = {v["bone"] for v in pieces.values()}
    manifest = {
        "character": defid, "version": ver,
        "provenance": "Original project-authored constructed forms (tools/blender/opening_cast); procedural PBR baked from the "
                      "subdivided master onto one game atlas",
        "units": "studs, scale 1, default R15 rest pose (arms down); each piece's origin is its R15 limb centre",
        "axes": "Blender Z = Roblox +Y; Blender +Y = Roblox -Z (forward); GLB exported Y-up",
        "limits": {"piece_triangle_cap": PIECE_CAP, "body_texture": 1024, "weapon_texture": 512},
        "measured": {"game_total_triangles": sum(v["triangles"] for v in pieces.values()),
                     "game_max_piece_triangles": max(v["triangles"] for v in pieces.values()),
                     "master_triangles_before_subdivision": master_tris,
                     "limbs_covered": len(covered & set(PIVOT)), "limbs_missing": sorted(set(PIVOT) - covered),
                     "sole_y": round(lo.z, 3), "top_y": round(hi.z, 3), "width_x": round(hi.x - lo.x, 3)},
        "pieces": pieces, "textures": tex, "exports": {"game_glb": REL(glb), "game_fbx": REL(fbx)}, "bake_device": device,
    }
    over = [k for k, v in pieces.items() if v["triangles"] > PIECE_CAP]
    if over:
        raise RuntimeError(f"pieces over the {PIECE_CAP} triangle cap: {over}")
    man = ROOT / "assets/opening_cast" / f"{key}.json"
    man.parent.mkdir(parents=True, exist_ok=True)
    man.write_text(json.dumps(manifest, indent=2) + "\n")
    bpy.ops.wm.save_mainfile(compress=True)
    print(json.dumps(manifest["measured"], indent=2))
    print("bake+export in %.0fs" % (time.time() - t0))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "monk")

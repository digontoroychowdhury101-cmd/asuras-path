"""Bakes the Veiled Ascetic into Roblox-ready MeshParts with 1024 PBR maps (headless Blender).

Usage:
  Blender -b <dressed.blend> --python-exit-code 1 -P tools/blender/bake_titan.py -- <tex_dir> <out_dir>

<tex_dir> holds the CC0 sources (assets/source/tex). Writes <out_dir>/veiled_titan.glb with
  Titan_Figure  body, hood-mantle, bodice, crown, halo      (stone, baked)
  Titan_Robe    robe pooled over her legs + fallen swords   (stone, baked)
  Titan_Roots   pale roots coiling around her               (pale bark, tiled)
  Titan_Canopy  dead tree trunk and branches                (pale bark, tiled)
  Titan_Leaves  crimson leaf cards                          (alpha leaf atlas)
and <out_dir>/leaves/crimson_leaf.png + leaf_scatter.png for the particle/decal textures.
Feed the GLB to process_asset.py afterwards for the triangle-cap check and map export.
"""
import math
import random
import sys
from pathlib import Path

import bpy
import numpy as np

TEX, OUT = Path("assets/source/tex"), Path("assets/build/veiled_titan")


def configure(tex, out):
    """Sets the texture source and output folders (also used by ingest_sculpt.py)."""
    global TEX, OUT
    TEX, OUT = Path(tex), Path(out)
    for d in (OUT, OUT / "maps", OUT / "leaves"):
        d.mkdir(parents=True, exist_ok=True)


SIZE = 1024
CAP = 19000
rnd = random.Random(5)

GROUPS = {
    "Titan_Figure": ["TitanBody", "TitanHead", "TitanBodice", "TitanMantle", "TitanCrown", "TitanHalo"],
    "Titan_Robe": ["TitanRobe", "TitanSwords"],
}
WOOD = {"Titan_Roots": "TitanRoots", "Titan_Canopy": "TitanCanopy"}


def select(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def join_copies(names, new_name):
    copies = []
    for n in names:
        src = bpy.data.objects[n]
        c = src.copy()
        c.data = src.data.copy()
        bpy.context.scene.collection.objects.link(c)
        copies.append(c)
    select(copies)
    if len(copies) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = new_name
    obj.data.materials.clear()
    return obj


def tris(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def decimate(o, cap):
    n = tris(o)
    if n <= cap:
        return
    m = o.modifiers.new("Dec", "DECIMATE")
    m.ratio = cap / n * 0.97
    select([o])
    bpy.ops.object.modifier_apply(modifier=m.name)


def load(name):
    return bpy.data.images.load(str(TEX / name), check_existing=True)


def new_image(name, alpha=False, non_color=False):
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=alpha)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def save(img, path):
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()


# ----------------------------------------------------------------------------- stone bake
def stone_source_material():
    """Weathered dark granite: box-projected rock scan, cavity grime, rain streaks, moss on top faces."""
    mat = bpy.data.materials.new("StoneSource")
    mat.use_nodes = True
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    coord = N.new("ShaderNodeTexCoord")
    mapping = N.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (7, 7, 7)
    L.new(coord.outputs["Object"], mapping.inputs["Vector"])

    def box(img_name, non_color=False):
        t = N.new("ShaderNodeTexImage")
        t.image = load(img_name)
        if non_color:
            t.image.colorspace_settings.name = "Non-Color"
        t.projection = "BOX"
        t.projection_blend = 0.3
        L.new(mapping.outputs["Vector"], t.inputs["Vector"])
        return t
    rock = box("rock_face_03_Diffuse.png")
    rough = box("rock_face_03_Rough.png", True)
    geo = N.new("ShaderNodeNewGeometry")
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.samples = 12
    ao.inputs["Distance"].default_value = 0.04

    def math_node(op, a, b=None, clamp=True):
        m = N.new("ShaderNodeMath")
        m.operation = op
        m.use_clamp = clamp
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                m.inputs[i].default_value = v
            else:
                L.new(v, m.inputs[i])
        return m.outputs[0]

    def mix(fac, a, b):
        m = N.new("ShaderNodeMix")
        m.data_type = "RGBA"
        L.new(fac, m.inputs["Factor"]) if not isinstance(fac, float) else None
        if isinstance(fac, float):
            m.inputs["Factor"].default_value = fac
        for sock, v in ((6, a), (7, b)):
            if isinstance(v, tuple):
                m.inputs[sock].default_value = (*v, 1)
            else:
                L.new(v, m.inputs[sock])
        return m.outputs[2]

    # dark, cool granite from the rock scan
    hsv = N.new("ShaderNodeHueSaturation")
    hsv.inputs["Saturation"].default_value = 0.18
    hsv.inputs["Value"].default_value = 0.95
    L.new(rock.outputs["Color"], hsv.inputs["Color"])
    granite = mix(0.42, hsv.outputs["Color"], (0.06, 0.065, 0.075))
    # streaks running down the statue
    streak = N.new("ShaderNodeTexNoise")
    streak.inputs["Scale"].default_value = 9.0
    smap = N.new("ShaderNodeMapping")
    smap.inputs["Scale"].default_value = (6, 6, 0.6)
    L.new(coord.outputs["Object"], smap.inputs["Vector"])
    L.new(smap.outputs["Vector"], streak.inputs["Vector"])
    streak_f = math_node("MULTIPLY_ADD", streak.outputs["Fac"], 0.5)
    N[streak_f.node.name].inputs[2].default_value = 0.62
    granite = mix(1.0, granite, granite)  # passthrough keeps node graph simple
    shade = N.new("ShaderNodeMix")
    shade.data_type = "RGBA"
    shade.blend_type = "MULTIPLY"
    shade.inputs["Factor"].default_value = 1.0
    L.new(granite, shade.inputs[6])
    L.new(streak_f, shade.inputs[7])
    # cavity grime from AO
    cav = N.new("ShaderNodeMix")
    cav.data_type = "RGBA"
    cav.blend_type = "MULTIPLY"
    cav.inputs["Factor"].default_value = 0.85
    L.new(shade.outputs[2], cav.inputs[6])
    L.new(ao.outputs["AO"], cav.inputs[7])
    # moss on upward faces, broken up by noise
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Normal"], sep.inputs["Vector"])
    up = math_node("SMOOTH_MIN", sep.outputs["Z"], 1.0)
    up_mask = N.new("ShaderNodeMapRange")
    up_mask.inputs["From Min"].default_value = 0.45
    up_mask.inputs["From Max"].default_value = 0.85
    L.new(sep.outputs["Z"], up_mask.inputs["Value"])
    mn = N.new("ShaderNodeTexNoise")
    mn.inputs["Scale"].default_value = 14.0
    mn.inputs["Detail"].default_value = 6.0
    L.new(coord.outputs["Object"], mn.inputs["Vector"])
    nm = N.new("ShaderNodeMapRange")
    nm.inputs["From Min"].default_value = 0.48
    nm.inputs["From Max"].default_value = 0.62
    L.new(mn.outputs["Fac"], nm.inputs["Value"])
    moss_f = math_node("MULTIPLY", up_mask.outputs["Result"], nm.outputs["Result"])
    moss_f = math_node("MULTIPLY", moss_f, 0.8)
    moss_col = mix(0.5, (0.07, 0.09, 0.035), rock.outputs["Color"])
    moss_col2 = N.new("ShaderNodeMix")
    moss_col2.data_type = "RGBA"
    moss_col2.blend_type = "MULTIPLY"
    moss_col2.inputs["Factor"].default_value = 1.0
    L.new(moss_col, moss_col2.inputs[6])
    moss_col2.inputs[7].default_value = (0.55, 0.6, 0.4, 1)
    final = N.new("ShaderNodeMix")
    final.data_type = "RGBA"
    L.new(moss_f, final.inputs["Factor"])
    L.new(cav.outputs[2], final.inputs[6])
    L.new(moss_col2.outputs[2], final.inputs[7])
    # roughness: rock roughness lifted, moss fully rough
    r1 = math_node("MULTIPLY_ADD", rough.outputs["Color"], 0.35)
    N[r1.node.name].inputs[2].default_value = 0.6
    r2 = math_node("MAXIMUM", r1, moss_f)
    # bump from the rock scan for the normal bake
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.002
    L.new(rough.outputs["Color"], bump.inputs["Height"])
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    L.new(final.outputs[2], bsdf.inputs["Base Color"])
    L.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    emit = N.new("ShaderNodeEmission")
    mat["color_sock"] = final.name
    mat["rough_sock"] = r2.node.name
    return mat, out, bsdf, emit, final.outputs[2], r2


def bake_stone(group, names, stone):
    mat, out, bsdf, emit, color_out, rough_out = stone
    nt = mat.node_tree
    hi = join_copies(names, group + "_hi")
    hi.data.materials.append(mat)
    lo = join_copies(names, group)
    decimate(lo, CAP)
    select([lo])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    final = bpy.data.materials.new(group + "_Stone")
    final.use_nodes = True
    fn = final.node_tree
    p = fn.nodes["Principled BSDF"]
    lo.data.materials.append(final)
    imgs = {}
    for key, nc in (("Color", False), ("Normal", True), ("Roughness", True)):
        img = new_image(f"{group}_{key}", non_color=nc)
        node = fn.nodes.new("ShaderNodeTexImage")
        node.image = img
        imgs[key] = (img, node)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 12
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = 0.02
    bk.max_ray_distance = 0.06
    bk.margin = 6
    select([hi, lo], active=lo)
    for key, socket, kind in (("Color", color_out, "EMIT"), ("Roughness", rough_out, "EMIT"), ("Normal", None, "NORMAL")):
        for link in list(nt.links):
            if link.to_node == out:
                nt.links.remove(link)
        if kind == "EMIT":
            nt.links.new(socket, emit.inputs["Color"])
            nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
        else:
            nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        img, node = imgs[key]
        fn.nodes.active = node
        bpy.ops.object.bake(type=kind)
        save(img, OUT / "maps" / f"{group}_{key}.png")
        print(f"BAKED {group} {key}", flush=True)
    links = fn.links
    links.new(imgs["Color"][1].outputs["Color"], p.inputs["Base Color"])
    links.new(imgs["Roughness"][1].outputs["Color"], p.inputs["Roughness"])
    nmap = fn.nodes.new("ShaderNodeNormalMap")
    links.new(imgs["Normal"][1].outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], p.inputs["Normal"])
    p.inputs["Metallic"].default_value = 0.0
    bpy.data.objects.remove(hi)
    return lo


# ----------------------------------------------------------------------------- textures
def pixels(img):
    a = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def to_image(name, arr, non_color=False):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(arr.astype(np.float32).ravel())
    return img


def pale_bark():
    """Alabaster bark: the platanus scan desaturated and lifted, crevices kept dark."""
    maps = {}
    for key, src, nc in (("Color", "bark_platanus_Diffuse.png", False), ("Normal", "bark_platanus_nor_gl.png", True),
                         ("Roughness", "bark_platanus_Rough.png", True)):
        img = load(src)
        if nc:
            img.colorspace_settings.name = "Non-Color"
        img.scale(SIZE, SIZE)
        a = pixels(img)
        if key == "Color":
            lum = (a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11)
            lum = lum / max(lum.mean(), 1e-3)
            tone = np.clip(0.2 + 0.62 * lum ** 0.7, 0, 1)
            tint = np.array([0.86, 0.83, 0.76])
            a[..., :3] = np.clip(tone[..., None] * tint, 0, 1)
        out = to_image(f"PaleBark_{key}", a, nc)
        save(out, OUT / "maps" / f"PaleBark_{key}.png")
        maps[key] = out
    return maps


def crimson_leaves():
    col = pixels(load("LeafSet024/LeafSet024_1K-PNG_Color.png"))
    op = pixels(load("LeafSet024/LeafSet024_1K-PNG_Opacity.png"))
    lum = col[..., 0] * 0.3 + col[..., 1] * 0.59 + col[..., 2] * 0.11
    vein = np.clip(lum / max(lum[op[..., 0] > 0.5].mean(), 1e-3), 0, 2)
    out = np.zeros_like(col)
    hue = np.array([0.4, 0.018, 0.03])
    out[..., :3] = np.clip(hue * (0.35 + 0.75 * vein[..., None]), 0, 1)
    out[..., 1] += 0.03 * (1 - vein)  # faint brown in the veins
    out[..., 3] = op[..., 0]
    atlas = to_image("CrimsonLeafAtlas", out)
    save(atlas, OUT / "maps" / "CrimsonLeafAtlas_Color.png")
    # single leaf for the ParticleEmitter (top-left cell of the 3x3 atlas, square)
    h, w = out.shape[:2]
    cell = out[h - h // 3:, : w // 3]
    save(to_image("crimson_leaf", cell), OUT / "leaves" / "crimson_leaf.png")
    # decal of fallen leaves: random rotated leaves composited (nearest-neighbour rotate)
    S = 1024
    canvas = np.zeros((S, S, 4), dtype=np.float32)
    cells = [out[(r * h) // 3:((r + 1) * h) // 3, (c * w) // 3:((c + 1) * w) // 3] for r in range(3) for c in range(3)]
    yy, xx = np.mgrid[0:S, 0:S]
    for _ in range(46):
        leaf = cells[rnd.randrange(9)]
        lh, lw = leaf.shape[:2]
        scale = rnd.uniform(0.32, 0.55)
        ang = rnd.uniform(0, 2 * math.pi)
        cx, cy = rnd.uniform(90, S - 90), rnd.uniform(90, S - 90)
        rad = int(max(lh, lw) * scale * 0.75)
        y0, y1, x0, x1 = int(max(cy - rad, 0)), int(min(cy + rad, S)), int(max(cx - rad, 0)), int(min(cx + rad, S))
        dx, dy = xx[y0:y1, x0:x1] - cx, yy[y0:y1, x0:x1] - cy
        u = (math.cos(ang) * dx + math.sin(ang) * dy) / scale + lw / 2
        v = (-math.sin(ang) * dx + math.cos(ang) * dy) / scale + lh / 2
        ok = (u >= 0) & (u < lw) & (v >= 0) & (v < lh)
        src = np.zeros((y1 - y0, x1 - x0, 4), dtype=np.float32)
        src[ok] = leaf[v[ok].astype(int), u[ok].astype(int)]
        src[..., :3] *= rnd.uniform(0.55, 1.05)
        al = src[..., 3:4]
        dst = canvas[y0:y1, x0:x1]
        dst[..., :3] = src[..., :3] * al + dst[..., :3] * (1 - al)
        dst[..., 3:4] = al + dst[..., 3:4] * (1 - al)
    save(to_image("leaf_scatter", canvas), OUT / "leaves" / "leaf_scatter.png")
    return atlas


def textured_material(name, color, normal=None, rough=None, alpha=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    c = nt.nodes.new("ShaderNodeTexImage")
    c.image = color
    nt.links.new(c.outputs["Color"], p.inputs["Base Color"])
    if alpha:
        # rounding the alpha makes the glTF exporter write alphaMode MASK (clean cut-outs)
        rnd_node = nt.nodes.new("ShaderNodeMath")
        rnd_node.operation = "ROUND"
        nt.links.new(c.outputs["Alpha"], rnd_node.inputs[0])
        nt.links.new(rnd_node.outputs[0], p.inputs["Alpha"])
        p.inputs["Roughness"].default_value = 0.65
    if normal:
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = normal
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    if rough:
        r = nt.nodes.new("ShaderNodeTexImage")
        r.image = rough
        nt.links.new(r.outputs["Color"], p.inputs["Roughness"])
    p.inputs["Metallic"].default_value = 0.0
    return m


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    configure(args[0], args[1])
    stone = stone_source_material()
    parts = [bake_stone(g, names, stone) for g, names in GROUPS.items()]
    bark = pale_bark()
    wood = textured_material("PaleRootWood", bark["Color"], bark["Normal"], bark["Roughness"])
    for part, src in WOOD.items():
        o = join_copies([src], part)
        decimate(o, CAP)
        o.data.materials.append(wood)
        parts.append(o)
    leaf = join_copies(["TitanLeaves"], "Titan_Leaves")
    leaf.data.materials.append(textured_material("CrimsonLeaves", crimson_leaves(), alpha=True))
    parts.append(leaf)
    for o in parts:
        print("PART", o.name, tris(o), [round(d, 3) for d in o.dimensions], flush=True)
    select(parts)
    glb = OUT / "veiled_titan.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True)
    print("BAKE_TITAN_OK", glb, round(glb.stat().st_size / 1e6, 2), "MB")


if __name__ == "__main__":
    main()

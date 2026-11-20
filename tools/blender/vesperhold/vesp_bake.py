"""Cycles high -> low bake helper for Vesperhold organic pieces (statues, gargoyles, trees). Owner: mac-51. Interface is stable.

Usage (inside Blender, objects already built, all with identity transforms and the same origin = foot centre):

    import vesp_bake as VB
    stone = VB.hi_material("Hi_Stone", VB.stone_source("Vesp_Weathered", maps_dir), tile=5.0)      # tiled CC0 / procedural base
    iron  = VB.hi_material("Hi_Iron",  VB.stone_source("Vesp_Verdigris", maps_dir), tile=1.5, metal=0.9)
    hi_robe.data.materials.append(stone)            # any number of high objects; per-face material slots are fine
    VB.unwrap(lo_robe)                              # Smart UV + average scale + pack, no overlaps (skip if the low has UVs)
    out = VB.bake("Hooded_Statue_A", {"Robe": (lo_robe, [hi_robe, hi_rope]), "Hood": (lo_hood, [hi_hood])},
                  maps_dir, size=2048, look=VB.Look(frost=0.35))
    # out["Robe"] = {"material": "Vesp_Hooded_Statue_A__Robe", "maps": {"Color": path, "Normal": .., "Roughness": .., "Metal": ..},
    #               "size": 2048}
    subs = VB.split_cap(lo_robe, cap=17500)          # AFTER the bake: Robe, Robe_2 ... share the baked material; never decimates

What it does:
  1. AO pre-pass: Cycles AO baked to a POINT colour attribute on every high (lows hidden, so cross-part occlusion such as hood
     over face is real). Multiplied by an optional float POINT attribute "void" (1 = paint black: hood cavity, sleeve inside)
     into the float attribute "occl".
  2. Per role, selected-to-active EMIT bakes of the high materials onto the low's UVs: ALB (base albedo, box-projected tiled
     map), D1 (occl, Cycles pointiness, vertical streak noise), D2 (metal, world normal z, base roughness) + tangent NORMAL
     (OpenGL +Y, as Roblox wants).
  3. numpy "look" composes ColorMap (sRGB pixel values: dark stone, lighter worn edges, darker grime, frost dust on up-facing
     surfaces), RoughnessMap (cavities rougher, rain streaks glossier), MetalnessMap (always written; black unless a high
     material has metal > 0). Files: <maps_dir>/Vesp_<piece>__<role>_{Color,Normal,Roughness,Metal}.png (vesp_embed naming).
  4. The low gets material Vesp_<piece>__<role> (Principled, all four maps linked; Metal always linked: mac-28 lesson).
Rays: cage_extrusion / max_ray_distance default 0.12 / 0.35 studs (per role via rays={role: (cage, ray)}); keep the cage
below the gap to any other high of the same role, and give each role only its own highs so a neighbour cannot steal rays. Env: VESP_BAKE_SIZE overrides size (e.g. 1024 for look iterations), VESP_BAKE_SAMPLES (AO, default 48).
"""
import math
import os
from pathlib import Path

import bpy
import numpy as np

KINDS = ("Color", "Normal", "Roughness", "Metal")


# ============================================================================================ setup
def cycles(samples=4):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for dev_type in ("METAL", "OPTIX", "CUDA", "HIP", "ONEAPI"):
            try:
                prefs.compute_device_type = dev_type
                prefs.get_devices()
                if any(d.type == dev_type for d in prefs.devices):
                    for d in prefs.devices:
                        d.use = True
                    sc.cycles.device = "GPU"
                    break
            except TypeError:
                continue
    except Exception:
        sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    if sc.world is None:
        sc.world = bpy.data.worlds.new("VB_World")
    return sc


def stone_source(name, maps_dir):
    """Resolve actual image paths for the high-poly shader. The bake applies its own stone grade."""
    import vesp_polyhaven
    if name in vesp_polyhaven.SRC and os.environ.get("VESP_PROCEDURAL") != "1":
        asset = vesp_polyhaven.SRC[name][0]
        folder = vesp_polyhaven.PH / asset
        color = folder / f"{asset}_Diffuse_2k.jpg"
        rough = folder / f"{asset}_Rough_2k.jpg"
        if color.is_file() and rough.is_file():
            return {"Color": color, "Roughness": rough, "source": f"Poly Haven {asset} 2K"}
    d = Path(maps_dir)
    r = d / f"{name}_Roughness.png"
    return {"Color": d / f"{name}_Color.png", "Roughness": r if r.exists() else None, "source": f"procedural {name} (vesp_common)"}


def _img(path, data):
    im = bpy.data.images.load(str(path), check_existing=True)
    if data:
        im.colorspace_settings.name = "Non-Color"
    return im


def hi_material(name, src, tile=5.0, tint=(1.0, 1.0, 1.0), metal=0.0, rough=0.78, streak=1.0):
    """High-poly bake material. src from stone_source(). tile = studs per texture repeat (box projection, object coords)."""
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    N, L = nt.nodes.new, nt.links.new
    out = N("ShaderNodeOutputMaterial")
    em = N("ShaderNodeEmission")
    em.name = "VB_EMIT"
    L(em.outputs[0], out.inputs["Surface"])
    tc = N("ShaderNodeTexCoord")
    mp = N("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0 / tile,) * 3
    L(tc.outputs["Object"], mp.inputs["Vector"])
    ci = N("ShaderNodeTexImage")
    ci.image = _img(src["Color"], False)
    ci.projection, ci.projection_blend = "BOX", 0.35
    L(mp.outputs[0], ci.inputs["Vector"])
    mix = N("ShaderNodeMix")
    mix.data_type, mix.blend_type = "RGBA", "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    L(ci.outputs["Color"], mix.inputs[6])
    mix.inputs[7].default_value = (*tint, 1.0)
    mix.name = "VB_ALB"
    if src.get("Roughness"):
        ri = N("ShaderNodeTexImage")
        ri.image = _img(src["Roughness"], True)
        ri.projection, ri.projection_blend = "BOX", 0.35
        L(mp.outputs[0], ri.inputs["Vector"])
        rsock = ri.outputs["Color"]
    else:
        rv = N("ShaderNodeValue")
        rv.outputs[0].default_value = rough
        rsock = rv.outputs[0]
    # D1 = (occl, pointiness, streak)
    occ = N("ShaderNodeAttribute")
    occ.attribute_name = "occl"
    geo = N("ShaderNodeNewGeometry")
    nz = N("ShaderNodeTexNoise")  # vertical rain/soot streaks: stretched along z
    nz.inputs["Scale"].default_value = 1.0
    nz.inputs["Detail"].default_value = 4.0
    smp = N("ShaderNodeMapping")
    smp.inputs["Scale"].default_value = (2.2, 2.2, 0.12)
    L(tc.outputs["Object"], smp.inputs["Vector"])
    L(smp.outputs[0], nz.inputs["Vector"])
    smul = N("ShaderNodeMath")
    smul.operation = "MULTIPLY"
    smul.inputs[1].default_value = streak
    L(nz.outputs["Fac"], smul.inputs[0])
    d1 = N("ShaderNodeCombineColor")
    d1.name = "VB_D1"
    L(occ.outputs["Fac"], d1.inputs[0])
    L(geo.outputs["Pointiness"], d1.inputs[1])
    L(smul.outputs[0], d1.inputs[2])
    # D2 = (metal, normal z remapped 0..1, base roughness)
    sep = N("ShaderNodeSeparateXYZ")
    L(geo.outputs["Normal"], sep.inputs[0])
    nzm = N("ShaderNodeMapRange")
    nzm.inputs["From Min"].default_value, nzm.inputs["From Max"].default_value = -1.0, 1.0
    L(sep.outputs["Z"], nzm.inputs["Value"])
    mv = N("ShaderNodeValue")
    mv.outputs[0].default_value = metal
    d2 = N("ShaderNodeCombineColor")
    d2.name = "VB_D2"
    L(mv.outputs[0], d2.inputs[0])
    L(nzm.outputs["Result"], d2.inputs[1])
    L(rsock, d2.inputs[2])
    # D3 = (lichen blotches, moss blotches, fine crust) in object space: seamless across UV islands. Baked only when a Look
    # asks for lichen or moss (win-66), so older callers bake exactly as before.
    d3 = N("ShaderNodeCombineColor")
    d3.name = "VB_D3"
    for ch, (scale, detail, rough_) in enumerate(((0.9, 6.0, 0.62), (0.45, 4.0, 0.55), (7.0, 3.0, 0.6))):
        bn = N("ShaderNodeTexNoise")
        bn.inputs["Scale"].default_value = scale
        bn.inputs["Detail"].default_value = detail
        bn.inputs["Roughness"].default_value = rough_
        L(tc.outputs["Object"], bn.inputs["Vector"])
        L(bn.outputs["Fac"], d3.inputs[ch])
    L(mix.outputs[2], em.inputs["Color"])
    mat["vb_metal"] = metal
    return mat


def _set_pass(mats, which):
    for m in mats:
        nt = m.node_tree
        em = nt.nodes["VB_EMIT"]
        src = nt.nodes[{"ALB": "VB_ALB", "D1": "VB_D1", "D2": "VB_D2", "D3": "VB_D3"}[which]]
        nt.links.new(src.outputs[2] if which == "ALB" else src.outputs[0], em.inputs["Color"])


# ============================================================================================ UV / split
def _only(objs, active):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def unwrap(obj, angle=62.0, margin=0.004, keep_existing=False):
    """Smart UV (or keep the existing UVs), average island scale, pack without overlap into 0-1."""
    _only([obj], obj)
    if not obj.data.uv_layers:
        obj.data.uv_layers.new(name="UVMap")
        keep_existing = False
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    if not keep_existing:
        bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=0.0, correct_aspect=True,
                                 scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    try:
        bpy.ops.uv.pack_islands(rotate=True, margin=margin, shape_method="CONCAVE")
    except TypeError:
        bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")


def tris(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def split_cap(obj, cap=17500):
    """Split (never decimate) into <cap-tri chunks along the longest axis: obj, obj_2, ... sharing material + UVs."""
    if tris(obj) < cap:
        return [obj]
    base = obj.name
    me = obj.data
    n = len(me.polygons)
    cen = np.zeros(n * 3, np.float32)
    me.polygons.foreach_get("center", cen)
    cen = cen.reshape(-1, 3)
    ext = cen.max(0) - cen.min(0)
    ax = int(np.argmax(ext))
    tri_per = np.zeros(n, np.int32)
    me.polygons.foreach_get("loop_total", tri_per)
    tri_per -= 2
    k = int(math.ceil(tri_per.sum() / cap))
    order = np.argsort(cen[:, ax], kind="stable")
    csum = np.cumsum(tri_per[order])
    label = np.zeros(n, np.int32)
    label[order] = np.minimum((csum * k) // (csum[-1] + 1), k - 1)
    import bmesh
    out = []
    for i in range(k):
        o = obj if i == 0 else obj.copy()
        if i:
            o.data = obj.data.copy()
            o.name = o.data.name = f"{base}_{i + 1}"
            for c in obj.users_collection:
                c.objects.link(o)
        out.append(o)
    for i, o in enumerate(out[::-1]):  # the original last, so its labels stay valid while copying
        i = k - 1 - i
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f, lab in zip(bm.faces, label) if lab != i], context="FACES")
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()
    for o in out:
        assert tris(o) < 18000, (o.name, tris(o))
    return out


# ============================================================================================ look (numpy compose)
class Look:
    """Tunable compose. Values are sRGB pixel values (what Roblox reads). Defaults: weathered black stone."""

    def __init__(self, base=0.135, grime=0.30, edge=0.95, edge_lo=0.50, edge_hi=0.62, frost=0.0, frost_col=(0.62, 0.65, 0.70),
                 streak_dark=0.18, rough_base=0.80, wet_gloss=0.30, occl_pow=1.25, seed=7, sat=1.0,
                 streak_lo=0.55, streak_hi=0.75, wash=0.0, frost_nz=(0.55, 0.9), frost_break=(0.46, 0.58),
                 growth=0.0, stone_tint=(1.0, 1.0, 1.0), lichen=0.0, moss=0.0, cavity=0.0,
                 lichen_col=(0.66, 0.67, 0.58), moss_col=(0.17, 0.21, 0.12)):
        # win-61 optional knobs (defaults = previous behaviour): streak_lo/hi = noise band that becomes a soot streak;
        # wash = lighten the rain-washed stone between streaks; frost_nz = up-facing range; frost_break = patch softness.
        # win-66 (default 0 = off): lichen = pale crusty patches on exposed stone, moss = green-grey growth in folds,
        # cavity = black grime packed into concave texels (Cycles pointiness).
        self.__dict__.update(locals())
        del self.__dict__["self"]


def _srgb(lin):
    lin = np.clip(lin, 0, 1)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def _smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def _blur(a, r):
    if r <= 0:
        return a
    k = np.exp(-0.5 * (np.arange(-2 * r, 2 * r + 1) / r) ** 2)
    k /= k.sum()
    for ax in (0, 1):
        a = np.apply_along_axis(lambda v: np.convolve(np.pad(v, 2 * r, mode="edge"), k, "valid"), ax, a)
    return a


def compose(alb_lin, d1, d2, look, cov, d3=None):
    L = look
    occl, point, streak = d1[..., 0], d1[..., 1], d1[..., 2]
    metal, nz, rbase = d2[..., 0], d2[..., 1] * 2 - 1, d2[..., 2]
    alb = _srgb(alb_lin)
    lum = alb.mean(-1, keepdims=True)
    tone = 1.0 + L.sat * (alb / np.maximum(lum, 1e-4) - 1.0)  # sat < 1 drops the source photo's hue (brown rock -> grey stone)
    p = point[cov] if cov.any() else point.ravel()
    lo, hi = np.percentile(p, 50), np.percentile(p, 99.0)
    wear = _smooth((point - lo) / max(hi - lo, 1e-4), L.edge_lo, L.edge_hi + 0.3)
    ao = np.clip(occl, 0, 1) ** L.occl_pow
    rel = lum / max(float(np.median(lum[cov])) if cov.any() else 0.2, 1e-3)  # keep the tiled map's variation, re-centred
    v = L.base * np.clip(rel, 0.75, 1.3)
    v = v * (1.0 - L.grime + L.grime * ao[..., None]) * (1.0 + L.edge * wear[..., None])
    sk = _smooth(streak, L.streak_lo, L.streak_hi)
    v = v * (1.0 - L.streak_dark * sk[..., None])
    if L.wash:
        v = v * (1.0 + L.wash * (1 - _smooth(streak, L.streak_lo - 0.2, L.streak_lo))[..., None] * ao[..., None])
    col = np.clip(v * tone * np.asarray(L.stone_tint, np.float32), 0, 1) * (1 - metal[..., None]) + alb * metal[..., None]
    if L.growth:
        nonmetal = 1 - metal
        moss = (1 - _smooth(occl, 0.20, 0.73)) * _smooth(streak, 0.46, 0.61) * _smooth(nz, -0.12, 0.72)
        lichen = _smooth(rel[..., 0], 1.05, 1.26) * _smooth(occl, 0.22, 0.65) * (1 - sk)
        col *= 1 - (moss * L.growth * nonmetal)[..., None] * np.array([0.35, 0.12, 0.48], np.float32)
        col += (lichen * L.growth * nonmetal)[..., None] * np.array([0.11, 0.12, 0.09], np.float32)
    if L.frost > 0:
        # breakup from the object-space streak noise (seamless across UV islands), denser on flatter tops
        fm = _smooth(nz, *L.frost_nz) * _smooth(streak + 0.25 * (nz - 0.8), *L.frost_break) * L.frost * (0.4 + 0.6 * ao)
        col = col * (1 - fm[..., None]) + np.array(L.frost_col, np.float32) * fm[..., None]
    crust_r = np.zeros_like(occl)
    if d3 is not None:
        nonmetal = (1 - metal)[..., None]
        crust = d3[..., 2]
        # moss: in folds and under overhangs (mid occlusion, not the black voids), facing up or sideways
        mm = (1 - _smooth(occl, 0.30, 0.78)) * _smooth(occl, 0.04, 0.14) * _smooth(d3[..., 1], 0.40, 0.56) * _smooth(nz, -0.45, 0.25)
        mm = np.clip(mm * L.moss * (0.75 + 0.5 * crust), 0, 1)[..., None] * nonmetal
        col = col * (1 - mm) + np.asarray(L.moss_col, np.float32) * (0.7 + 0.6 * crust[..., None]) * mm
        # lichen: pale crusty rosettes on exposed stone, broken up by the fine crust noise
        lm = _smooth(d3[..., 0], 0.56, 0.63) * _smooth(occl, 0.30, 0.65) * _smooth(crust, 0.30, 0.55)
        lm = np.clip(lm * L.lichen, 0, 1)[..., None] * nonmetal
        col = col * (1 - lm) + np.asarray(L.lichen_col, np.float32) * (0.8 + 0.4 * crust[..., None]) * lm
        crust_r = 0.12 * lm[..., 0]
    if L.cavity:
        pm, plo = np.percentile(p, 50), np.percentile(p, 4)
        span = pm - plo
        # A flat bake (such as the Wraith's blade) can have identical pointiness percentiles.
        if span > 0:
            cav = _smooth(pm - point, 0.15 * span, span) * (1 - metal)
            col = col * (1 - L.cavity * cav)[..., None]
    void = occl < 0.04
    col[void] = np.minimum(col[void], 0.02)
    rough = np.clip(L.rough_base + 0.12 * (rbase - 0.5) + 0.12 * (1 - ao) - L.wet_gloss * _smooth(streak, L.streak_lo - 0.05, L.streak_hi + 0.05)
                    - 0.08 * wear + crust_r, 0.25, 1.0)
    rough = rough * (1 - metal) + np.clip(0.35 + 0.3 * rbase, 0.2, 0.8) * metal
    return col.astype(np.float32), rough.astype(np.float32), metal.astype(np.float32)


# ============================================================================================ image I/O
def _new_img(name, size, data=True):
    if name in bpy.data.images:
        bpy.data.images.remove(bpy.data.images[name])
    im = bpy.data.images.new(name, size, size, alpha=False, float_buffer=True, is_data=data)
    return im


def _pix(im):
    a = np.zeros(im.size[0] * im.size[1] * 4, np.float32)
    im.pixels.foreach_get(a)
    return a.reshape(im.size[1], im.size[0], 4)


def save_png(path, arr, color):
    """arr (H, W) or (H, W, 3); color=True -> values are sRGB pixel values."""
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, 2)
    h, w = arr.shape[:2]
    im = bpy.data.images.new("vb_save", w, h, alpha=False, is_data=not color)
    im.pixels.foreach_set(np.concatenate([np.clip(arr, 0, 1), np.ones((h, w, 1), np.float32)], 2).astype(np.float32).ravel())
    im.filepath_raw = str(path)
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def low_material(name, paths):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(p.outputs[0], out.inputs["Surface"])
    for k, sock in (("Color", "Base Color"), ("Roughness", "Roughness"), ("Metal", "Metallic"), ("Normal", None)):
        if k not in paths:
            continue
        im = bpy.data.images.load(str(paths[k]), check_existing=False)
        im.name = Path(paths[k]).stem
        if k != "Color":
            im.colorspace_settings.name = "Non-Color"
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = im
        if sock:
            nt.links.new(n.outputs["Color"], p.inputs[sock])
        else:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(n.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    mat.use_backface_culling = False
    return mat


# ============================================================================================ bake
def _ao_prepass(highs, samples, distance):
    sc = bpy.context.scene
    sc.cycles.samples = samples
    sc.world.light_settings.distance = distance
    hidden = [o for o in sc.objects if o.type == "MESH" and o not in highs and not o.hide_render]
    for o in hidden:
        o.hide_render = True
    for h in highs:
        me = h.data
        if "vb_ao" in me.color_attributes:
            me.color_attributes.remove(me.color_attributes["vb_ao"])
        ca = me.color_attributes.new("vb_ao", "FLOAT_COLOR", "POINT")
        me.color_attributes.active_color = ca
    _only(highs, highs[0])
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS", use_selected_to_active=False)
    for h in highs:
        me = h.data
        n = len(me.vertices)
        c = np.zeros(n * 4, np.float32)
        me.color_attributes["vb_ao"].data.foreach_get("color", c)
        ao = c.reshape(-1, 4)[:, 0]
        if "void" in me.attributes:
            v = np.zeros(n, np.float32)
            me.attributes["void"].data.foreach_get("value", v)
            ao = ao * (1 - np.clip(v, 0, 1))
        if "occl" in me.attributes:
            me.attributes.remove(me.attributes["occl"])
        me.attributes.new("occl", "FLOAT", "POINT").data.foreach_set("value", ao.astype(np.float32))
        me.color_attributes.remove(me.color_attributes["vb_ao"])
    for o in hidden:
        o.hide_render = False


def bake(piece, roles, maps_dir, size=2048, look=None, cage=0.12, ray=0.35, ao_distance=0.9, ao_samples=None, log=print, rays=None):
    """roles: {role: (low_obj, [high_objs])}. rays: optional {role: (cage, ray)} overrides. look: Look or {role: Look}.
    Returns {role: {"material", "maps", "size", "metal_max"}}. See module docstring."""
    import time
    size = int(os.environ.get("VESP_BAKE_SIZE", size))
    ao_samples = int(os.environ.get("VESP_BAKE_SAMPLES", ao_samples or 48))
    looks = look if isinstance(look, dict) else {}
    look = look if isinstance(look, Look) else looks.get("*", Look())
    maps_dir = Path(maps_dir)
    maps_dir.mkdir(parents=True, exist_ok=True)
    sc = cycles(4)
    highs = sorted({h for _, hs in roles.values() for h in hs}, key=lambda o: o.name)
    t = time.time()
    _ao_prepass(highs, ao_samples, ao_distance)
    log(f"bake {piece}: AO prepass {len(highs)} highs {time.time() - t:.1f}s")
    sc.cycles.samples = 4
    rb = sc.render.bake
    rb.use_selected_to_active, rb.cage_extrusion, rb.max_ray_distance = True, cage, ray
    rb.margin, rb.use_clear = 16, True
    try:
        rb.margin_type = "EXTEND"
    except Exception:
        pass
    rb.normal_space, rb.normal_r, rb.normal_g, rb.normal_b = "TANGENT", "POS_X", "POS_Y", "POS_Z"
    result = {}
    for role, (low, hs) in roles.items():
        t = time.time()
        mname = f"Vesp_{piece}__{role}"
        rb.cage_extrusion, rb.max_ray_distance = (rays or {}).get(role, (cage, ray))
        mats = {m for h in hs for m in h.data.materials if m}
        tmp = bpy.data.materials.new("vb_tmp")
        try:
            tmp.use_nodes = True
        except Exception:
            pass
        low.data.materials.clear()
        low.data.materials.append(tmp)
        tn = tmp.node_tree.nodes.new("ShaderNodeTexImage")
        tmp.node_tree.nodes.active = tn
        bufs = {}
        lk = looks.get(role, look)
        passes = ("ALB", "D1", "D2", "NORMAL") + (("D3",) if lk.lichen or lk.moss else ())
        for pas in passes:
            im = _new_img(f"vb_{pas}", size)
            tn.image = im
            if pas != "NORMAL":
                _set_pass(mats, pas)
            _only(list(hs) + [low], low)
            bpy.ops.object.bake(type="EMIT" if pas != "NORMAL" else "NORMAL", use_selected_to_active=True)
            bufs[pas] = _pix(im)
            bpy.data.images.remove(im)
        _set_pass(mats, "ALB")
        cov = bufs["NORMAL"][..., 2] > 0.0  # baked texels (margin included)
        col, rough, metal = compose(bufs["ALB"][..., :3], bufs["D1"][..., :3], bufs["D2"][..., :3], lk, cov,
                                    bufs["D3"][..., :3] if "D3" in bufs else None)
        paths = {k: maps_dir / f"{mname}_{k}.png" for k in KINDS}
        save_png(paths["Color"], col, True)
        save_png(paths["Normal"], bufs["NORMAL"][..., :3], False)
        save_png(paths["Roughness"], rough, False)
        save_png(paths["Metal"], metal, False)
        low.data.materials.clear()
        low.data.materials.append(low_material(mname, paths))
        bpy.data.materials.remove(tmp)
        result[role] = {"material": mname, "maps": {k: str(p) for k, p in paths.items()}, "size": size,
                        "metal_max": round(float(metal.max()), 2)}
        log(f"bake {piece}__{role}: {size}px {time.time() - t:.1f}s")
    return result

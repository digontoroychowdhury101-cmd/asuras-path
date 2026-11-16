"""Bellwood far-tree LOD variants (lane M8): low-triangle distant versions of the 6 Bellwood tree forms.

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Supersedes: nothing (no earlier far/LOD tree script exists; slice_kit.py only mentions Leaves_Mass as a distance LOD in its manifest text).
Linked from LEDGER.md (lane M8 row, added by the lead). Why new: existing packs (slice, bellwood_veg) must stay untouched, so the variants,
their upload pack and the comparison renders live in their own tree.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/bellwood_far.py
  env FAR_ONLY=Canopy_Tree_A,... builds a subset; FAR_NORENDER=1 skips the 60/150/300 stud comparison renders.

Read-only on the near GLBs. For each form: import the near GLB, merge-and-decimate the bark, k-means the leaf vertices into ellipsoid lumps
(conifer: stacked cones), affine-fit the result to the near bbox, bake a 256x128 colour atlas from the near colour maps, export
<Piece>_Far.glb (sub-meshes <Piece>_Far__Bark / __Leaves|__Needles), write the upload pack, render near (left) vs far (right) at 60, 150, 300 studs.
"""
import json
import os
import shutil
import struct
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "assets/source/overworld"
OUT = SRC / "bellwood_far"
UP = SRC / "upload/bellwood_far"
CAP = ROOT / "outputs/claude-open-world-2026-11-14/captures/kit/bellwood_far"
NOTE = ROOT / "outputs/claude-open-world-2026-11-14/workers/25a-tree-far.md"
REGISTRY = "assets/BELLWOOD_FAR_KIT_UPLOADED.json"
HEADER = ("Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its "
          "complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.")
ONLY = {s for s in os.environ.get("FAR_ONLY", "").split(",") if s}
NORENDER = bool(os.environ.get("FAR_NORENDER"))
TRI_CAP = 18000
TEX_W, TEX_H, HALF = 256, 128, 128
LEAF_LIFT = {"Bell_Conifer": 1.5}  # albedo lift per leaf map so the far colour matches the lit near render (default 1.5)
DISTANCES = (60, 150, 300)

# switch distance (studs, camera to tree) per form: filled in after viewing the renders (see workers/25a-tree-far.md)
RECOMMEND = {"Canopy_Tree_A": 160, "Canopy_Tree_B": 200, "Canopy_Tree_C": 160, "Canopy_Tree_D": 160, "Conifer_Tall": 220, "Old_Gnarled_Tree": 150}

SLICE, VEG = SRC / "slice", SRC / "upload/bellwood_veg"
FORMS = {
    "Canopy_Tree_A": dict(glb=SLICE / "Canopy_Tree_A.glb", maps=SLICE / "maps", leaf="Bell_Leaf", kind="broad"),
    "Canopy_Tree_B": dict(glb=SLICE / "Canopy_Tree_B.glb", maps=SLICE / "maps", leaf="Bell_Leaf", kind="broad"),
    "Canopy_Tree_C": dict(glb=VEG / "Canopy_Tree_C.glb", maps=VEG / "maps", leaf="Bell_Leaf", kind="broad"),
    "Canopy_Tree_D": dict(glb=VEG / "Canopy_Tree_D.glb", maps=VEG / "maps", leaf="Bell_Leaf", kind="broad"),
    "Conifer_Tall": dict(glb=VEG / "Conifer_Tall.glb", maps=VEG / "maps", leaf="Bell_Conifer", kind="conifer"),
    "Old_Gnarled_Tree": dict(glb=VEG / "Old_Gnarled_Tree.glb", maps=VEG / "maps", leaf="Bell_Leaf", kind="broad"),
}


# ------------------------------------------------------------------ stdlib GLB inspection (same logic as make_upload_pack.py)
def inspect_glb(path):
    data = Path(path).read_bytes()
    n, _ = struct.unpack_from("<I4s", data, 12)
    g = json.loads(data[20:20 + n])
    subs, lo, hi = {}, [1e9] * 3, [-1e9] * 3
    for node in g["nodes"]:
        if "mesh" not in node:
            continue
        t, s = node.get("translation", [0, 0, 0]), node.get("scale", [1, 1, 1])
        tris = 0
        for prim in g["meshes"][node["mesh"]]["primitives"]:
            tris += g["accessors"][prim["indices"]]["count"] // 3
            a = g["accessors"][prim["attributes"]["POSITION"]]
            for i in range(3):
                lo[i] = min(lo[i], a["min"][i] * s[i] + t[i])
                hi[i] = max(hi[i], a["max"][i] * s[i] + t[i])
            mat = g["materials"][prim["material"]]["name"]
        subs[node.get("name") or g["meshes"][node["mesh"]]["name"]] = {"tris": tris, "material": mat}
    return subs, lo, hi


# ------------------------------------------------------------------ geometry
def world_verts(o):
    me = o.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    m = np.array(o.matrix_world)
    return co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]


def decimate(o, target):
    """Weld the (UV-split) near bark, collapse-decimate to ~target tris, return world verts + tri indices."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-3)
    tmp = bpy.data.meshes.new("tmp_bark")
    bm.to_mesh(tmp)
    bm.free()
    t = bpy.data.objects.new("tmp_bark", tmp)
    bpy.context.scene.collection.objects.link(t)
    md = t.modifiers.new("d", "DECIMATE")
    md.decimate_type, md.use_collapse_triangulate = "COLLAPSE", True
    ratio = min(1.0, target / max(1, sum(len(p.vertices) - 2 for p in tmp.polygons)))
    for _ in range(4):
        md.ratio = ratio
        ev = t.evaluated_get(bpy.context.evaluated_depsgraph_get())
        m2 = ev.to_mesh()
        got = len(m2.polygons)
        if abs(got - target) <= target * 0.12:
            break
        ratio = min(1.0, ratio * target / max(got, 1))
        ev.to_mesh_clear()
    V = np.empty(len(m2.vertices) * 3)
    m2.vertices.foreach_get("co", V)
    F = np.array([list(p.vertices) for p in m2.polygons], dtype=int)
    ev.to_mesh_clear()
    bpy.data.objects.remove(t)
    bpy.data.meshes.remove(tmp)
    return V.reshape(-1, 3), F


def unit_ico():
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    V = np.array([v.co[:] for v in bm.verts])
    idx = {v: i for i, v in enumerate(bm.verts)}
    F = np.array([[idx[v] for v in f.verts] for f in bm.faces])
    bm.free()
    return V, F


def kmeans(P, k, seed):
    rng = np.random.default_rng(seed)
    C = [P[rng.integers(len(P))]]
    for _ in range(k - 1):
        d = np.min(((P[:, None, :] - np.array(C)[None]) ** 2).sum(2), axis=1)
        C.append(P[rng.choice(len(P), p=d / d.sum())])
    C = np.array(C)
    for _ in range(30):
        lab = ((P[:, None, :] - C[None]) ** 2).sum(2).argmin(1)
        for i in range(k):
            if (lab == i).any():
                C[i] = P[lab == i].mean(0)
    return lab


def lumps(P, k, seed):
    """One jittered 80-tri ellipsoid per k-means cluster of the leaf vertices."""
    ico, ifaces = unit_ico()
    rng = np.random.default_rng(seed + 1)
    lab = kmeans(P * np.array([1, 1, 1.8]), k, seed)  # weight height so clusters stack into tiers
    Vs, Fs = [], []
    for i in range(k):
        Q = P[lab == i]
        if len(Q) < 4:
            continue
        lo, hi = np.percentile(Q, 2, axis=0), np.percentile(Q, 98, axis=0)
        r = np.maximum((hi - lo) / 2 * 1.25, 2.0)
        v = ico * (1 + rng.uniform(-0.07, 0.07, (len(ico), 1))) * r + (lo + hi) / 2
        Fs.append(ifaces + sum(len(x) for x in Vs))
        Vs.append(v)
    return np.vstack(Vs), np.vstack(Fs)


def cones(P, ntier, nsides):
    """Stacked cones: radius per height band from the 97th percentile radial extent of the needle vertices."""
    zlo, zhi = P[:, 2].min(), P[:, 2].max()
    edges = np.linspace(zlo, zhi, ntier + 1)
    dz = edges[1] - edges[0]
    Vs, Fs, n = [], [], 0
    ang = np.linspace(0, 2 * np.pi, nsides, endpoint=False)
    for i in range(ntier):
        band = P[(P[:, 2] >= edges[i] - dz * 0.5) & (P[:, 2] <= edges[i + 1] + dz * 0.5)]
        if len(band) < 4:
            continue
        c = band[:, :2].mean(0)
        r = max(np.percentile(np.hypot(*(band[:, :2] - c).T), 97) * 1.05, 1.5)
        z0, z1 = edges[i], min(edges[i + 1] + dz * 0.9, zhi)
        ring = np.stack([c[0] + r * np.cos(ang), c[1] + r * np.sin(ang), np.full(nsides, z0)], 1)
        v = np.vstack([ring, [[c[0], c[1], z1]], [[c[0], c[1], z0]]])
        apex, base = n + nsides, n + nsides + 1
        f = [[n + j, n + (j + 1) % nsides, apex] for j in range(nsides)] + [[n + (j + 1) % nsides, n + j, base] for j in range(nsides)]
        Vs.append(v)
        Fs.append(np.array(f))
        n += len(v)
    return np.vstack(Vs), np.vstack(Fs)


def make_obj(name, V, F, uv, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata(V.tolist(), [], F.tolist())
    me.validate()
    me.update()
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    vi = np.empty(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", vi)
    layer = me.uv_layers.new(name="UVMap")
    layer.data.foreach_set("uv", uv[vi].ravel())
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


# ------------------------------------------------------------------ texture
def load_rgba(path):
    img = bpy.data.images.load(str(path))
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    a = a.reshape(h, w, 4)
    if h % HALF == 0 and w % HALF == 0:
        a = a.reshape(HALF, h // HALF, HALF, w // HALF, 4).mean((1, 3))  # box downscale
    else:
        ys, xs = np.linspace(0, h - 1, HALF).astype(int), np.linspace(0, w - 1, HALF).astype(int)
        a = a[ys][:, xs]
    return a


def bake_atlas(name, maps, leaf):
    """256x128, rows bottom-first: left half bark, right half leaf/needle, each darkened toward the bottom (cheap baked AO)."""
    atlas = np.ones((TEX_H, TEX_W, 4), dtype=np.float32)
    grad = np.linspace(0.80, 1.15, TEX_H)[:, None, None]
    for half, mapname in ((0, "Bell_Bark"), (1, leaf)):
        t = load_rgba(maps / f"{mapname}_Color.png")
        if half:  # far lumps lose the near leaf cards' translucency / back light: soften the pattern and lift it (matched against the renders)
            t[..., :3] = 0.5 * t[..., :3] + 0.5 * t[..., :3].mean((0, 1))
        t[..., :3] = np.clip(t[..., :3] * grad * (LEAF_LIFT.get(leaf, 1.5) if half else 1.0), 0, 1)
        t[..., 3] = 1
        atlas[:, half * HALF:(half + 1) * HALF] = t
    img = bpy.data.images.new(name, TEX_W, TEX_H, alpha=False)
    img.pixels.foreach_set(atlas.ravel())
    path = OUT / "maps" / f"{name}_Color.png"
    img.filepath_raw, img.file_format = str(path), "PNG"
    img.save()
    shutil.copy2(path, UP / "maps" / path.name)
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.95
    return mat, atlas.mean((0, 1))[:3].tolist()


# ------------------------------------------------------------------ one form
def import_near(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before]


def build(form, cfg):
    near_objs = import_near(cfg["glb"])
    meshes = [o for o in near_objs if o.type == "MESH"]
    bark_o = next(o for o in meshes if o.name.split(".")[0].endswith("__Bark"))
    leaf_os = [o for o in meshes if o is not bark_o]
    near_sub = {o.name.split(".")[0]: len(o.data.loop_triangles) for o in meshes}
    near_tris = sum(near_sub.values())
    nlo = np.min([world_verts(o).min(0) for o in meshes], axis=0)
    nhi = np.max([world_verts(o).max(0) for o in meshes], axis=0)
    L = np.vstack([world_verts(o) for o in leaf_os])

    budget = min(1500, round(0.12 * near_tris))
    bark_target = min(300, round(budget * 0.2))
    bV, bF = decimate(bark_o, bark_target)
    seed = sum(map(ord, form))
    if cfg["kind"] == "conifer":
        lV, lF = cones(L, 24, 16)
    else:
        lV, lF = lumps(L, max(8, (budget - bark_target) // 80), seed)

    # affine-fit the whole far mesh to the near bbox (same silhouette extremes, same pivot)
    allV = np.vstack([bV, lV])
    flo, fhi = allV.min(0), allV.max(0)
    fit = lambda v: nlo + (v - flo) * (nhi - nlo) / (fhi - flo)
    bV, lV = fit(bV), fit(lV)

    # UVs into the atlas: bark = left half, leaves = right half, v = height (the baked gradient), u from x
    piece = form + "_Far"
    leaf_sub = "Needles" if cfg["kind"] == "conifer" else "Leaves"

    def uv(V, half, lo, hi):
        u = (V[:, 0] - lo[0]) / max(hi[0] - lo[0], 1e-6)
        v = (V[:, 2] - lo[2]) / max(hi[2] - lo[2], 1e-6)
        return np.stack([(half + 0.04 + 0.92 * u) * 0.5, 0.02 + 0.96 * v], 1)

    mat, mean_rgb = bake_atlas(f"Bell_Far_{form}", cfg["maps"], cfg["leaf"])
    llo, lhi = lV.min(0), lV.max(0)
    blo, bhi = bV.min(0), bV.max(0)
    far = [make_obj(f"{piece}__Bark", bV, bF, uv(bV, 0, blo, bhi), mat), make_obj(f"{piece}__{leaf_sub}", lV, lF, uv(lV, 1, llo, lhi), mat)]

    bpy.ops.object.select_all(action="DESELECT")
    for o in far:
        o.select_set(True)
    bpy.context.view_layer.objects.active = far[0]
    glb = OUT / f"{piece}.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=False)
    shutil.copy2(glb, UP / glb.name)

    subs, lo, hi = inspect_glb(glb)
    nsubs, nlo_g, nhi_g = inspect_glb(cfg["glb"])
    for k, v in subs.items():
        assert v["tris"] < TRI_CAP, (k, v["tris"])
    size = [round(hi[i] - lo[i], 2) for i in range(3)]
    nsize = [round(nhi_g[i] - nlo_g[i], 2) for i in range(3)]
    ftris = sum(v["tris"] for v in subs.values())
    rec = {
        "name": piece, "file": glb.name,
        "near_piece": form, "near_tris": sum(v["tris"] for v in nsubs.values()), "tri_ratio_pct": round(100 * ftris / sum(v["tris"] for v in nsubs.values()), 1),
        "sub_meshes": {k: v["tris"] for k, v in subs.items()},
        "sub_mesh_materials": {k: v["material"] for k, v in subs.items()},
        "tris_total": ftris,
        "size_studs_xyz_roblox": size, "near_size_studs_xyz_roblox": nsize,
        "bbox_max_delta_studs": round(max(max(abs(lo[i] - nlo_g[i]), abs(hi[i] - nhi_g[i])) for i in range(3)), 3),
        "file_size_bytes": glb.stat().st_size,
        "texture_px": [TEX_W, TEX_H],
        "pivot": "base centre at origin (Y up); " + json.dumps({"min_y": round(lo[1], 3), "centre_x": round((lo[0] + hi[0]) / 2, 3), "centre_z": round((lo[2] + hi[2]) / 2, 3)}),
        "studio_target": f"ServerStorage/BellwoodFarKit/{piece}", "registry_file": REGISTRY,
        "switch_distance_studs": RECOMMEND.get(form),
    }
    with open(NOTE, "a", encoding="utf-8") as f:
        f.write(f"- [export] {piece}: far {ftris} tris ({rec['tri_ratio_pct']}% of near {rec['near_tris']}); sub-meshes {rec['sub_meshes']}; "
                f"size {size} vs near {nsize}; max bbox edge delta {rec['bbox_max_delta_studs']} studs; GLB {rec['file_size_bytes'] // 1024} KB; atlas {TEX_W}x{TEX_H}\n")
    print("FAR_PIECE", piece, ftris, rec["bbox_max_delta_studs"], flush=True)
    return rec, near_objs, far


# ------------------------------------------------------------------ renders
def setup_render():
    sc = bpy.context.scene
    ids = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT") if e in ids)
    sc.render.resolution_x, sc.render.resolution_y = 1280, 720
    try:
        sc.eevee.taa_render_samples = 16
    except Exception:
        pass
    w = bpy.data.worlds.new("w")
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.55, 0.64, 0.72, 1)
    bg.inputs["Strength"].default_value = 0.9
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 2.4
    sun.rotation_euler = (0.9, 0.15, 2.2)
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.clip_start, cam.data.clip_end = 0.5, 6000
    cam.data.sensor_fit = "VERTICAL"
    cam.data.lens = 24 / (2 * np.tan(np.radians(35)))  # Roblox default 70 degree vertical FOV
    sc.collection.objects.link(cam)
    sc.camera = cam
    gm = bpy.data.materials.new("Ground")
    try:
        gm.use_nodes = True
    except Exception:
        pass
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.10, 0.15, 0.06, 1)
    me = bpy.data.meshes.new("Ground")
    me.from_pydata([(-3000, -3000, 0), (3000, -3000, 0), (3000, 3000, 0), (-3000, 3000, 0)], [], [(0, 1, 2, 3)])
    me.materials.append(gm)
    g = bpy.data.objects.new("Ground", me)
    sc.collection.objects.link(g)
    return sc, cam


def render_pair(sc, cam, form, rec, near_objs, far_objs):
    h = rec["near_size_studs_xyz_roblox"][1]
    half = max(rec["near_size_studs_xyz_roblox"][0], rec["near_size_studs_xyz_roblox"][2]) / 2 + 6
    roots = [o for o in near_objs if o.parent is None]
    for o in roots:
        o.location.x -= half
    for o in far_objs:
        o.location.x += half
    tgt = Vector((0, 0, h * 0.42))
    for d in DISTANCES:
        eye = Vector((0, -d, 6.0))
        cam.location = eye
        cam.rotation_euler = (tgt - eye).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = str(CAP / f"{form}_{d}.png")
        bpy.ops.render.render(write_still=True)
    for o in roots:
        o.location.x += half
    for o in far_objs:
        o.location.x -= half


def write_pack(recs):
    mats = {}
    for r in recs.values():
        for m in set(r["sub_mesh_materials"].values()):
            mats[m] = {"ColorMap": {"file": f"maps/{m}_Color.png", "size_px": [TEX_W, TEX_H]}}
    for r in recs.values():
        r["maps_per_material"] = {m: mats[m] for m in sorted(set(r["sub_mesh_materials"].values()))}
    (UP / "upload_manifest.json").write_text(json.dumps({
        "_header": HEADER + " | supersedes: nothing | linked from LEDGER.md (lane M8) | new because the near packs stay untouched; generated by tools/blender/overworld/bellwood_far.py",
        "format": "GLB (glTF 2.0, textures embedded; same maps also loose in maps/)",
        "units": "1 stud = 1 unit, Y up after import",
        "tri_cap_per_sub_mesh": TRI_CAP,
        "registry_file": REGISTRY,
        "registry_shape": {"pieces": {"<Piece>": {"<Piece>__<Sub>": {"MeshId": "rbxassetid://...", "ColorMap": ""}}}},
        "no_ids_yet": True,
        "studio_import_notes": [
            "3D Importer, Scale 1, one MeshPart per sub-mesh (Piece_Far__Sub), pivot at base centre (Y up), identical to the near piece",
            "One SurfaceAppearance per material from maps/ (ColorMap only: no Normal / Roughness, Roughness stays at default), 256x128 atlas, left half bark, right half leaf",
            "Solid lumps / cones, no alpha cards: no DoubleSided needed. Same bbox and pivot as the near piece, so swap by CFrame of the near model",
            "Use beyond the per-piece switch_distance_studs; drop the near Leaves_Detail / Needles_Detail and Leaves_Mass / Needles_Mass sub-meshes at the swap",
        ],
        "pieces": recs,
        "materials": mats,
    }, indent=2) + "\n")
    names = ", ".join(recs)
    (UP / "UPLOAD.md").write_text(f"""# Bellwood far trees: by-hand Studio 3D Importer steps

{HEADER}

Supersedes: nothing (first far/LOD tree pack). Linked from LEDGER.md (lane M8 row). New because the near packs (`../slice`, `../bellwood_veg`) are not modified.
Regenerate: `blender -b -P tools/blender/overworld/bellwood_far.py` (FAR_NORENDER=1 skips renders). Per-piece tris, size, bbox delta, switch distance: `upload_manifest.json`.

{len(recs)} GLBs: {names}. Each is the low-triangle distant variant of the near tree with the same name (without `_Far`), same bbox, same base-centre pivot.

1. Open `places/AsurasPath.rbxlx` in Studio. Asset Manager > Bulk Import (or Avatar > Import 3D). Creator: Me.
2. Import settings: Scale 1, Import As Model (one MeshPart per sub-mesh named `<Piece>_Far__Bark` and `<Piece>_Far__Leaves` or `__Needles`), Upload To Roblox on. No Auto-fix, no mesh simplification.
3. Each MeshPart needs a SurfaceAppearance with ColorMap only from `maps/Bell_Far_<Piece>_Color.png` (256x128). Leave StudsPerTile default. If the importer did not create it, upload the PNG as an Image and set it by hand.
4. Parent each Model to `ServerStorage/BellwoodFarKit/<Piece>_Far`. Swap with the near model at the per-piece `switch_distance_studs` (CFrame of the near model, no scale change).
5. Record IDs in `{REGISTRY}` (new file, shape in `upload_manifest.json`; copy `assets/SANCTUARY_VISTA_UPLOADED.json`). IDs come from the MeshPart/SurfaceAppearance properties in Studio; never guess.
""", encoding="utf-8")


def main():
    for d in (OUT / "maps", UP / "maps", CAP):
        d.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc, cam = setup_render()
    recs, kept = {}, []
    for i, (form, cfg) in enumerate([(f, c) for f, c in FORMS.items() if not ONLY or f in ONLY]):
        rec, near, far = build(form, cfg)
        recs[rec["name"]] = rec
        if not NORENDER:
            render_pair(sc, cam, form, rec, near, far)
            with open(NOTE, "a", encoding="utf-8") as f:
                f.write(f"- [render] {form}: {', '.join(f'{form}_{d}.png' for d in DISTANCES)} (near left, far right; Roblox 70 deg FOV, eye 6 studs)\n")
        for o in near:
            bpy.data.objects.remove(o)
        for o in far:
            o.location.x = i * 90
            o.hide_render = True  # parked for the saved .blend only; must not show up in later forms' renders
            o.location.y = 0
        kept += far
    write_pack(recs)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "bellwood_far.blend"), compress=True)
    print("FAR_OK", len(recs), flush=True)


main()

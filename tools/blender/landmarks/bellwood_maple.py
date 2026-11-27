"""Bellwood landmark kit: red maple leaves floating on the Sunken Temple lake (concept bellwood_3 foreground: crimson
leaves drifting among the lily pads, a few turning rust, some waterlogged and half sunk).

  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_maple.py -- [out_dir]
  default out_dir: assets/source/landmarks/bellwood_maple      env: MAPLE_PIECES=Drift,Raft  MAPLE_NORENDER=1

All procedural, built on the lotus kit's helpers (bellwood_lotus.py): one 2048 atlas painted with numpy, no third-party sources.
  Leaf  quadrants: fresh crimson | turning rust-orange | waterlogged maroon | pale underside (shared by every leaf)
Each leaf is a seven-lobed Acer palmatum blade: a polar sheet from the petiole junction, lobe tips and sinuses on exact
samples, with real thickness (two-sided, no alpha), a cup and a one-sided curl, and a short petiole.
Units studs, Z up. Pivot: the water surface at the piece centre (z = 0). Fresh leaves float 0.02-0.05 up; waterlogged
leaves lie flat at the surface or tip one edge under it.
"""
import json
import math
import os
import random
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bellwood_lotus as L  # noqa: E402  (MB, sheet, atlas helpers, relax, renders; its main() is guarded)

ROOT = HERE.parents[2]
BUILDER = "tools/blender/landmarks/bellwood_maple.py (win-105, procedural palmate cards + numpy-painted 2048 atlas)"
TAU, Q = L.TAU, L.Q
MAT = {"Leaf": "Vesp_Bellwood_Maple__Leaf"}
TRI_CAP = L.TRI_CAP
FRESH, TURNING, WET, UNDER = (0, 0), (1, 0), (0, 1), (1, 1)
SLOTS = 8                       # 7 lobes + the petiole sinus at the back (slot 4)
SPS = 6                         # samples per slot: tip, sinus and the flanks land on exact samples
LOBE = (1.0, 0.92, 0.78, 0.55, 0.10, 0.55, 0.78, 0.92)
UVS = 0.47                      # blade radius 1 -> 0.47 of the quadrant half-width
log = L.log


# ============================================================================================ texture
def leaf_quadrant(seed, kind):
    lu, lv = L.qgrid()
    x, y = lu * 2 - 1, lv * 2 - 1
    r, a = np.hypot(x, y), np.arctan2(y, x)
    f1, f2, f3 = L.field(Q, 1.6, seed), L.field(Q, 1.0, seed + 1), L.field(Q, 0.5, seed + 2)
    warp = 0.03 * f1
    prim = L.veins(r, a, SLOTS, 0.010 * (0.4 + 0.6 * r), warp) * L.sst(0.01, 0.06, r)
    sec = L.veins(r, a + TAU / 64, 32, 0.006, warp * 1.5) * L.sst(0.25, 0.4, r)
    vs = np.clip(prim + 0.45 * sec, 0, 1)
    pet = np.exp(-(y / 0.022) ** 2) * (x < 0)  # petiole band running back from the junction
    if kind == "fresh":
        col = L.mix(np.zeros(r.shape + (3,)) + (0.44, 0.05, 0.04), (0.66, 0.09, 0.05), L.sst(0.05, 0.9, r))
        col *= (1 + 0.07 * f2)[..., None]
        col = L.mix(col, (0.36, 0.04, 0.04), 0.35 * L.sst(0.6, 1.6, f1))     # deeper blotches
        col = L.mix(col, (0.78, 0.26, 0.12), 0.55 * vs)
        col = L.mix(col, (0.32, 0.08, 0.05), 0.5 * L.sst(0.82, 0.95, r))     # dry tips
        rough = 0.55 + 0.05 * f2
    elif kind == "turning":
        col = L.mix(np.zeros(r.shape + (3,)) + (0.80, 0.44, 0.08), (0.64, 0.12, 0.05), L.sst(0.15, 0.85, r + 0.2 * f1))
        col = L.mix(col, (0.74, 0.62, 0.18), 0.45 * L.sst(1.0, 1.9, f2) * L.sst(0.5, 0.0, r))  # yellow near the base
        col = L.mix(col, (0.86, 0.55, 0.20), 0.45 * vs)
        col = L.mix(col, (0.34, 0.12, 0.05), 0.55 * L.sst(0.8, 0.95, r))
        col = L.mix(col, (0.30, 0.10, 0.05), 0.6 * L.sst(2.1, 2.8, f3))      # rot spots
        rough = 0.6 + 0.06 * f2
    elif kind == "wet":
        col = L.mix(np.zeros(r.shape + (3,)) + (0.30, 0.08, 0.05), (0.22, 0.06, 0.04), L.sst(0.2, 0.9, r))
        col = L.mix(col, (0.13, 0.04, 0.03), 0.6 * L.sst(0.4, 1.5, f1))
        col = L.mix(col, (0.44, 0.20, 0.10), 0.35 * L.sst(1.6, 2.4, f2))     # leached patches
        col = L.mix(col, (0.38, 0.12, 0.07), 0.35 * vs)
        rough = 0.26 + 0.06 * f2                                              # wet sheen
    else:  # underside
        col = L.mix(np.zeros(r.shape + (3,)) + (0.62, 0.30, 0.22), (0.55, 0.22, 0.16), L.sst(0.2, 0.9, r))
        col *= (1 + 0.05 * f2)[..., None]
        col = L.mix(col, (0.76, 0.46, 0.33), 0.6 * vs)
        rough = 0.72 + 0.05 * f2
    col = L.mix(col, (0.30, 0.10, 0.06), 0.8 * pet * L.sst(0.02, 0.08, r))
    h = (0.5 - 0.16 * vs if kind != "under" else 0.5 + 0.22 * vs) + 0.03 * f3
    return np.clip(col, 0, 1), h, np.clip(rough, 0, 1)


def make_materials(maps):
    maps.mkdir(parents=True, exist_ok=True)
    col, nrm, rough = L.atlas({FRESH: leaf_quadrant(91, "fresh"), TURNING: leaf_quadrant(101, "turning"),
                               WET: leaf_quadrant(111, "wet"), UNDER: leaf_quadrant(121, "under")}, 3.0)
    mname = MAT["Leaf"]
    f = {s: maps / f"{mname}_{s}.png" for s in ("Color", "Normal", "Roughness", "Metal")}
    ims = {"Color": L.save_png(f["Color"], mname + "_Color", col, False),
           "Normal": L.save_png(f["Normal"], mname + "_Normal", nrm, True),
           "Roughness": L.save_png(f["Roughness"], mname + "_Roughness", rough, True),
           "Metal": L.save_png(f["Metal"], mname + "_Metal", np.zeros((L.N, L.N)), True)}
    m = bpy.data.materials.new(mname)
    try:
        m.use_nodes = True
    except (AttributeError, TypeError):
        pass
    m.use_backface_culling = True
    nt = m.node_tree
    p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for slot, sock in (("Color", "Base Color"), ("Roughness", "Roughness"), ("Metal", "Metallic")):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = ims[slot]
        nt.links.new(t.outputs["Color"], p.inputs[sock])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = ims["Normal"]
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(t.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    log(f"maps {mname} {L.N}x{L.N}")
    return {"Leaf": m}, {"Leaf": {s: Path(v).relative_to(maps.parent).as_posix() for s, v in f.items()}}


# ============================================================================================ geometry
def blade_r(k, u, lob, depth):
    """Radius at slot k, offset u in [-0.5, 0.5]: pointed lobe between two sinuses (deep, as in Acer palmatum)."""
    kn = (k + (1 if u >= 0 else -1)) % SLOTS
    s = depth * min(lob[k], lob[kn])
    w = 1 - abs(2 * u)
    return s + (lob[k] - s) * w ** 0.72  # broad lanceolate lobes, tapering to a point


def maple_leaf(P, c, S, yaw, rng, look, z0, cup, curl, sink=0.0):
    """One leaf at c (x, y), front-lobe length S. look picks the top quadrant; the underside is shared."""
    lob = [v * rng.uniform(0.9, 1.08) for v in LOBE]
    depth = rng.uniform(0.42, 0.52)
    ns = SLOTS * SPS
    cd = rng.uniform(0, TAU)
    cdir = Vector((math.cos(cd), math.sin(cd), 0))
    tilt = Matrix.Rotation(sink, 4, Vector((-math.sin(cd), math.cos(cd), 0)))  # waterlogged: one edge dips
    rot = Matrix.Rotation(yaw, 4, "Z")
    base = Vector((c[0], c[1], 0))

    def place(x, y, z):
        q = Vector((x, y, z))
        q.z += cup * (q.x * q.x + q.y * q.y) / (S * S) * S + curl * max(0.0, q.dot(cdir) / S) ** 2 * S
        return base + (rot @ (tilt @ q)) + Vector((0, 0, z0))

    def fn(t, phi):
        j = int(round(phi * ns))
        k, u = j // SPS % SLOTS, (j % SPS) / SPS
        if u > 0.5:  # past the sinus: the far flank of the next lobe
            k, u = (k + 1) % SLOTS, u - 1
        a = phi * TAU
        r = blade_r(k, u, lob, depth) * t
        x, y = r * math.cos(a), r * math.sin(a)
        return place(x * S, y * S, 0.0), 0.5 + UVS * x, 0.5 + UVS * y

    L.sheet(P, ns, (0.0, 0.5, 1.0), fn, look, UNDER, True, 0.008 * S / 0.7)  # a leaf is paper thin; a thick rim streaks
    # petiole: a thin two-sided strip running back from the junction, bending up off the water
    pl, pw = S * rng.uniform(0.32, 0.42), 0.016 * S
    pts = [(-pl * i / 3, 0.0, 0.04 * S * (i / 3) ** 2) for i in range(4)]
    for (x0, y0, z0_), (x1, y1, z1) in zip(pts, pts[1:]):
        pos = [place(x0, -pw, z0_), place(x1, -pw, z1), place(x1, pw, z1), place(x0, pw, z0_)]
        u0, u1 = L.quv(look, 0.5 + UVS * x0 / S, 0.5), L.quv(look, 0.5 + UVS * x1 / S, 0.5)
        top = [P.v(q) for q in pos]
        P.f(top, [u0, u1, u1, u0])
        dn = Vector((0, 0, 0.008 * S))
        bot = [P.v(q - dn) for q in pos]  # underside, its own vertices so the strip has thickness
        P.f([bot[3], bot[2], bot[1], bot[0]], [u0, u1, u1, u0])


def build_piece(spec, seed):
    rng = random.Random(seed)
    n, (ax, ay), smin, smax = spec["n"], spec["spread"], spec["size"][0], spec["size"][1]
    looks = spec["looks"]
    items = []
    for _ in range(n):
        while True:  # elliptical scatter, denser along a slow drift line
            x, y = rng.uniform(-1, 1), rng.uniform(-1, 1)
            if x * x + y * y <= 1 and rng.random() < 0.35 + 0.65 * math.exp(-((y - 0.4 * x * x + 0.2) / 0.45) ** 2):
                break
        S = rng.uniform(smin, smax)
        items.append((x * ax, y * ay, 0.82 * S, S))
    P = L.MB()
    for x, y, _, S in L.relax(items, gap=0.03):
        look = rng.choices((FRESH, TURNING, WET), looks)[0]
        if look == WET:
            maple_leaf(P, (x, y), S, rng.uniform(0, TAU), rng, look, rng.uniform(0.0, 0.012), 0.0, rng.uniform(0, 0.06),
                       sink=rng.uniform(0.0, 0.09))
        else:
            maple_leaf(P, (x, y), S, rng.uniform(0, TAU), rng, look, rng.uniform(0.02, 0.05), rng.uniform(0.04, 0.1),
                       rng.uniform(0.0, 0.28))
    return P


PIECES = {
    "Drift": ("Bellwood_MapleDrift", 401, {"n": 32, "spread": (7.0, 4.6), "size": (0.55, 0.85), "looks": (0.45, 0.3, 0.25)}),
    "Raft": ("Bellwood_MapleRaft", 402, {"n": 24, "spread": (3.2, 2.2), "size": (0.5, 0.8), "looks": (0.35, 0.25, 0.4)}),
}


# ============================================================================================ main
def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_maple").resolve()
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    keys = [k for k in os.environ.get("MAPLE_PIECES", ",".join(PIECES)).split(",") if k]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats, mapfiles = make_materials(out / "maps")
    built, entries = {}, {}
    for key in keys:
        name, seed, spec = PIECES[key]
        o = build_piece(spec, seed).build(f"{name}__Leaf", mats["Leaf"])
        subs = {o.name: L.tris(o)}
        assert all(v < TRI_CAP for v in subs.values()), subs
        glb = out / f"{name}.glb"
        L.export_glb([o], glb)
        lo, hi = L.bbox([o])
        entries[name] = {
            "group": "Bellwood", "sub_meshes": subs, "tris_total": sum(subs.values()),
            "size_studs_xyz": [round(float(hi[i] - lo[i]), 1) for i in range(3)],
            "bbox_min": [round(float(c), 2) for c in lo], "bbox_max": [round(float(c), 2) for c in hi],
            "materials": [MAT["Leaf"]], "file": glb.name, "builder": BUILDER,
            "no_decimation": True, "decimation": "none: built directly at game density, every sub < 17500 tris",
            "map_resolution": {"Leaf": L.N}, "maps": mapfiles,
            "base_layer": "procedural: numpy-painted atlas, no third-party sources",
            "pivot": "water surface at the piece centre (z = 0 / glTF y = 0); leaves float 0-0.05 above it, sunk edges dip below",
            "collision": {"Leaf": "None"},
            "two_sided": "real back faces on every blade and petiole; DoubleSided not needed",
        }
        built[key] = [o]
        log(f"{name}: {glb.name} {glb.stat().st_size / 1e3:.0f} kB; subs {subs}; size {entries[name]['size_studs_xyz']}")
    mf = out / "manifest.json"
    m = json.loads(mf.read_text()) if mf.exists() else {"kit": "Bellwood landmark: Sunken Temple floating maple leaves", "pieces": {}}
    m["pieces"].update(entries)
    mf.write_text(json.dumps(m, indent=2))
    if os.environ.get("MAPLE_NORENDER"):
        return
    sc, cam, fig = L.setup_render()
    all_objs = [o for v in built.values() for o in v]
    for key, objs in built.items():
        L.render_piece(PIECES[key][0], objs, all_objs, rdir, sc, cam, fig, None)
        leaf = objs[0]
        lo, hi = L.bbox(objs)
        ctr = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, 0.0))
        fig.hide_render = True
        L.shoot(sc, cam, ctr + Vector((-1.2, -2.2, 1.6)), ctr, 45, rdir / f"{PIECES[key][0]}_close.png")
    # beside the lotus for scale and palette: ClusterA built from the lotus kit (preview maps go to work/, not the kit)
    lmats, _ = L.make_materials(ROOT / "work/win-105/lotus_preview_maps")
    PB = L.build_piece(L.PIECES["ClusterA"][2], L.PIECES["ClusterA"][1])
    lotus = [PB[0].build("Prev_Pad", lmats["Pad"]), PB[1].build("Prev_Bloom", lmats["Bloom"])]
    for o in all_objs:
        o.hide_render = True
    tmp = []
    for key, (x, y, rz) in {"Drift": (-3, 16, 0.5), "Raft": (6, 9, 2.0)}.items():
        for o in built.get(key, []):
            cpy = bpy.data.objects.new("V_" + o.name, o.data)
            cpy.matrix_world = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(rz, 4, "Z")
            bpy.context.scene.collection.objects.link(cpy)
            tmp.append(cpy)
    for o in lotus:
        o.matrix_world = Matrix.Translation((1, 22, 0))
    fig.location, fig.hide_render = (5.5, 13, -0.8), False
    L.shoot(sc, cam, Vector((0, -4, 5.0)), Vector((1, 16, 0.3)), 28, rdir / "Bellwood_Maple_vignette_eye.png")
    log("MAPLE_OK", len(entries), "pieces")


if __name__ == "__main__":
    main()

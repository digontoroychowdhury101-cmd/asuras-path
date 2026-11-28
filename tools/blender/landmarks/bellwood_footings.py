"""Bellwood landmark: footings for the colossal temple's back and flanks (CLAUDE_BELLWOOD_REPLACEMENT_HANDOFF, "Finish the
art" step 4; WINDOWS_HANDOFF_2026-11-26 open item 4). In Studio the temple's back and sides stand as sheer coursed walls
120-160 studs tall, cut off flat on the lake bed. These pieces stand against those walls so the base reads as built on rock.

  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_footings.py -- [out_dir]
  default out_dir: assets/source/landmarks/bellwood_footings     env: FOOT_MODE=clay|bake  FOOT_PIECES=Bedrock,Buttress,Scree

  Bedrock   a long shelf of stratified bedrock whose ledges step back as they rise (the third overhangs the second), split
            by joints, with a broken course of set blocks bedded on top and a few fallen onto the lower ledges
  Buttress  a battered pier in three set-back stages of coursed blocks under sloped weathering caps, standing on a bedrock
            knuckle; a few corner blocks are gone and lie at its foot
  Scree     fallen squared blocks and broken stone half-sunk in a low mound of rock and soil
Roles (vesp_bake on CC0 Poly Haven bases, outputs/vesperhold/THIRD_PARTY.md):
  Stone  rock_04 tinted to the temple's cool dark grey   (collision: hull)
  Rock   dark_rock, the bedrock and the mound            (collision: hull)
  Vine   bark_willow_02 under blanket moss: pads and hanging strands (no collision)
Units studs, Z up. Pivot: the centre of the wall-contact line on the lake bed (x = 0, y = 0, z = 0). The back (-Y) is
buried in the temple wall and the front (+Y) faces out. Pieces run along X. LandmarkWorld places them at Scale 2.5.
"""
import math
import os
import random
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "vesperhold"))
import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import bellwood_colonnade as C  # noqa: E402  (Piece, T, rot, high, vines)
import bellwood_temple_hall as H  # noqa: E402  (objects, src)
import vesperhold_figures as FG  # noqa: E402
import vesperhold_gargoyles as G  # noqa: E402  (SDF field, surface nets, bake + export)
from vesperhold_figures import log  # noqa: E402

ROOT = HERE.parents[2]
BUILDER = "tools/blender/landmarks/bellwood_footings.py (win-112, coursed blocks + SDF bedrock + Cycles bake)"
MESH_ROLES = ("Stone", "Vine")  # built from Mesh primitives; Rock comes from the SDF
BACK = -3.0  # how far every piece runs back into the wall
COURSE = 1.55  # block course height, the temple's own courses at Scale 2.5
SOIL_H = 0.7  # SDF cell size for the LOW


def rough(prim, amp, freq, seed, squash=(1.0, 1.0, 2.4)):
    """An SDF primitive with fbm on its distance; squash > 1 on z bands the noise into strata."""
    lo, hi, fn = prim
    s = np.array(squash) * freq
    return lo - amp, hi + amp, lambda P: fn(P) + amp * FG.fbm(P * s, 3, seed)


def top_at(F, x, y, z0=-4.0, z1=40.0):
    """Highest solid z of field F above (x, y), or None."""
    zs = np.arange(z1, z0, -0.08)
    d = F.eval(np.stack([np.full(len(zs), x), np.full(len(zs), y), zs], 1))
    hit = np.nonzero(d < 0)[0]
    return float(zs[hit[0]]) if len(hit) else None


def rock_low(F, name):
    D, lo = F.grid(SOIL_H)
    V, Q = G.surface_nets(D, lo, SOIL_H)
    V = G.project(F, V, SOIL_H)
    ob = G.mesh_from(name, V, Q)
    bm = bmesh.new()  # surface nets leave a few collapsed quads where thin joints pinch; Cycles' bake faults on them
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.02)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.02)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.validate(clean_customdata=False)  # welding pinched joints leaves duplicate faces
    ob.data.shade_smooth()
    ob.data.set_sharp_from_angle(angle=math.radians(50))
    return ob


def block(s, rng, x, y, z, size, tilt=0.012, bevel=0.12):
    """One dressed block, its bed a little off level and its face a little off plumb."""
    j = lambda a: rng.uniform(-a, a)  # noqa: E731
    s.box((0, 0, 0), size, C.T(x, y, z) @ C.rot(j(tilt), j(tilt), j(tilt * 1.5)), bevel=bevel)


def fallen(pc, rng, x, y, z, big=1.0, broken=False):
    """A block lying where it fell: tipped, half on its side, sometimes snapped."""
    w = rng.uniform(2.2, 3.4) * big
    size = (w * (rng.uniform(0.45, 0.6) if broken else 1.0), rng.uniform(1.6, 2.2) * big, COURSE * big * rng.uniform(0.85, 1.0))
    M = C.T(x, y, z + size[2] * 0.3) @ C.rot(rng.uniform(-0.5, 0.5), rng.uniform(-0.45, 0.45), rng.uniform(0, 6.28))
    pc.m("Stone").box((0, 0, 0), size, M, bevel=0.14)
    if broken:
        pc.breaks.append((M @ Vector((size[0] / 2, 0, 0)), 1.2 * big))
    if rng.random() < 0.5:
        pc.mats.append((M @ C.T(0, 0, size[2] / 2 + 0.05) @ C.rot(rz=rng.uniform(0, 6.28)), rng.uniform(0.5, 1.1) * big))


def ledge_moss(pc, rng, x0, x1, y, z, every=0.9, drape=0.6):
    """Moss along a ledge lip: low pads on the top, strands hanging off the edge."""
    x = x0
    while x < x1:
        if rng.random() < drape:
            long = rng.random() < 0.22
            pc.hang.append((Vector((x, y + rng.uniform(-0.1, 0.15), z)), rng.uniform(2.5, 5.5) if long else rng.uniform(0.5, 2.2)))
        if rng.random() < 0.3:
            pc.mats.append((C.T(x, y - rng.uniform(1.4, 3.2), z - 0.14) @ C.rot(rz=rng.uniform(0, 6.28)), rng.uniform(0.8, 1.9)))
        x += every * rng.uniform(0.6, 1.4)


# ------------------------------------------------------------------------------------------------------- pieces
def bedrock(pc):
    rng = random.Random(41)
    F = G.Field()
    # (bottom, top, half-length, front): the ledges step back as they rise; the third overhangs the second
    layers = ((-3.0, 2.6, 31.0, 18.5), (2.6, 5.3, 29.5, 14.5), (5.3, 8.1, 27.0, 16.2), (8.1, 10.7, 24.5, 11.0),
              (10.7, 12.8, 21.0, 8.4))
    tops = []
    for i, (z0, z1, half, front) in enumerate(layers):
        cuts = sorted(rng.uniform(-half * 0.6, half * 0.6) for _ in range(rng.randint(1, 2)))
        xs = [-half + rng.uniform(-1.5, 1.5)] + cuts + [half + rng.uniform(-1.5, 1.5)]
        for a, b in zip(xs, xs[1:]):  # each ledge in two or three slabs with their own front and thickness
            f = front + rng.uniform(-1.6, 1.6)
            t = z1 + rng.uniform(-0.35, 0.3)
            prim = G.rbox(((a + b) / 2, (BACK + f) / 2, (z0 + t) / 2), ((b - a) / 2 - 0.15, (f - BACK) / 2, (t - z0) / 2), 0.32)
            F.u(rough(prim, 0.45, 0.22, 100 + 7 * i), k=0.25)
            tops.append((a + 0.8, b - 0.8, f, t))
    for _ in range(9):  # joints: narrow slots through one or two ledges, open at the face
        x = rng.uniform(-26, 26)
        z0 = rng.uniform(-1, 8)
        F.c(G.rbox((x, 14.0, z0 + 2.5), (0.22, 8.0, rng.uniform(2.0, 4.0)), 0.1), k=0.2)
    for k in range(16):  # bites out of the ledge fronts, so no slab reads as a sawn edge
        a, b, f, t = tops[rng.randrange(len(tops))]
        r = rng.uniform(1.0, 2.4)
        F.c(rough(G.rbox((rng.uniform(a, b), f + 0.3, t - rng.uniform(0.3, 2.0)), (r * 1.4, r * 0.8, r * 0.6), r * 0.55),
                  0.3, 0.45, 150 + k), k=0.5)
    for x, z, r in ((-30.5, 9.0, 4.5), (28.0, 11.5, 4.0), (-24.0, 13.0, 3.0), (31.5, 4.0, 3.2)):  # broken shelf ends
        F.c(G.rbox((x, 6.0, z), (r, 14.0, r * 0.8), 1.2), k=0.6)
    s = pc.m("Stone")
    crest = layers[-1][1]
    front = layers[-1][3]
    under = []  # first-course blocks as (x0, x1, top z): the second course only sits where the first still does
    for course, (skip, setback) in enumerate(((0.18, 0.0), (0.4, 0.5))):
        x = -19.5 + rng.uniform(0, 1.5) + course * 1.4
        while x < 19.0:
            w = rng.uniform(2.6, 3.8)
            xc = x + w / 2
            if course == 0:
                bed = top_at(F, xc, front - 1.5)
                z = None if bed is None or bed < crest - 1.4 else bed - 0.25 + COURSE / 2
            else:
                below = [u for u in under if u[0] < xc < u[1]]
                z = below[0][2] + COURSE / 2 if below else None
            if z is not None and rng.random() > skip:
                for y0, y1 in ((front - 2.6 - setback, front - setback), (BACK, front - 2.7 - setback)):
                    block(s, rng, xc, (y0 + y1) / 2, z + rng.uniform(-0.05, 0.05), (w - 0.1, y1 - y0 - 0.1, COURSE - 0.08))
                if course == 0:
                    under.append((x, x + w, z + COURSE / 2))
                elif rng.random() < 0.3:
                    pc.mats.append((C.T(xc, front - 1.4 - setback, z + COURSE / 2) @ C.rot(rz=rng.uniform(0, 6.28)),
                                    rng.uniform(0.7, 1.4)))
            elif course == 0 and z is not None:  # a gap in the course: the fallen block lies on a ledge below
                ledges = [t for t in tops if t[0] < xc < t[1] and t[3] < crest - 1]
                if ledges:
                    a, b, f, t = rng.choice(ledges)
                    fallen(pc, rng, xc, f - rng.uniform(1.5, 3.0), t, broken=rng.random() < 0.5)
            x += w
    for a, b, f, t in tops:
        ledge_moss(pc, rng, a, b, f - 0.2, t)
    for _ in range(7):  # spalls at the foot, in the water
        fallen(pc, rng, rng.uniform(-28, 28), rng.uniform(18.5, 23.0), -0.6, big=rng.uniform(0.6, 1.0), broken=rng.random() < 0.6)
    pc.rock = F
    return crest + 2 * COURSE


def buttress(pc):
    rng = random.Random(53)
    s = pc.m("Stone")
    # (bottom, top, half-width, projection) per stage; each stage leans in (batter) as it rises
    stages = ((0.0, 14.0, 7.0, 12.0), (15.6, 26.4, 6.0, 9.0), (28.0, 36.6, 5.0, 6.2))
    batter = 0.045
    for si, (z0, z1, hw, pj) in enumerate(stages):
        n = max(1, round((z1 - z0) / COURSE))
        ch = (z1 - z0) / n
        s.box((0, (BACK + pj - 1.9) / 2, (z0 + z1) / 2), (2 * hw - 3.6, pj - 1.9 - BACK, z1 - z0), bevel=0.0)  # rubble core
        for c in range(n):
            z = z0 + (c + 0.5) * ch
            lean = batter * (z - z0)
            h, p = hw - lean, pj - lean
            phase = 1.3 if c % 2 else 0.0
            x = -h - (phase and rng.uniform(0.3, 0.9))
            while x < h:  # the face course; its end blocks turn the corner as quoins
                w = rng.uniform(2.3, 3.4)
                x1 = min(x + w, h)
                corner = x <= -h + 0.05 or x1 >= h - 0.05
                gone = corner and rng.random() < (0.12 if si == 0 else 0.07)
                if not gone and x1 - x > 0.8:
                    xc = (max(x, -h) + x1) / 2
                    d = rng.uniform(1.6, 2.2)
                    block(s, rng, xc + rng.uniform(-0.03, 0.03), p - d / 2 + rng.uniform(-0.07, 0.05), z,
                          (x1 - max(x, -h) - 0.1, d, ch - 0.09))
                elif gone:
                    fallen(pc, rng, rng.uniform(-hw - 4, hw + 4), pj + rng.uniform(1.5, 6.0), 0.4 if si else 0.0,
                           broken=rng.random() < 0.6)
                x = x1
            for side in (-1, 1):  # the side courses back to the wall
                y = p - rng.uniform(1.6, 2.2) - (0.0 if c % 2 else rng.uniform(0.9, 1.4))
                while y > BACK + 0.4:
                    w = rng.uniform(2.3, 3.4)
                    y0 = max(y - w, BACK)
                    d = rng.uniform(1.6, 2.1)
                    block(s, rng, side * (h - d / 2) + rng.uniform(-0.04, 0.04), (y + y0) / 2, z, (d, y - y0 - 0.1, ch - 0.09))
                    y = y0
        # sloped weathering cap (wash) over the stage: lip proud of the face, falling to the next stage or into the wall
        nxt = stages[si + 1] if si + 1 < len(stages) else None
        lean = batter * (z1 - z0)
        lip, top_y, rise = pj - lean + 0.45, (nxt[3] - 0.3 if nxt else BACK), ((nxt[0] - z1 + 0.25) if nxt else 3.2)
        prof = [(BACK, 0.0), (lip, 0.0), (lip, 0.42), (top_y + 0.4, rise), (BACK, rise)]
        half = hw - lean + 0.45
        s.sweep(prof, [Vector((half, 0, z1)), Vector((-half, 0, z1))])
        pc.breaks.append((Vector((rng.uniform(-half, half), lip, z1 + 0.2)), 1.4))
        ledge_moss(pc, rng, -half + 0.3, half - 0.3, lip, z1 + 0.42, every=0.8, drape=0.7 if si == 0 else 0.5)
        for _ in range(3):
            t = rng.uniform(0.3, 0.8)
            pc.mats.append((C.T(rng.uniform(-half + 1, half - 1), lip + t * (top_y - lip), z1 + 0.42 + t * (rise - 0.42))
                            @ C.rot(rx=-math.atan2(rise - 0.42, lip - top_y), rz=rng.uniform(-0.2, 0.2)), rng.uniform(0.9, 1.7)))
    F = G.Field()  # the bedrock knuckle the pier stands on, swelling round its foot
    F.u(rough(G.rbox((0, 5.0, -1.0), (11.0, 10.5, 3.0), 1.2), 0.7, 0.2, 201), k=0.0)
    for x, y, z, r in ((-8.5, 10.5, 0.4, 3.4), (7.5, 13.5, 0.0, 4.0), (-2.0, 15.5, -0.6, 3.2), (9.5, 2.0, 1.4, 3.0),
                       (-9.0, 1.0, 1.2, 2.8), (3.0, 11.0, 0.8, 2.6)):
        F.u(rough(G.rbox((x, y, z), (r, r * 0.8, r * 0.55), r * 0.5), 0.45, 0.3, 211 + int(x)), k=1.2)
    for _ in range(5):
        fallen(pc, rng, rng.uniform(-9, 9), rng.uniform(13.0, 17.5), -0.4, big=rng.uniform(0.7, 1.0), broken=True)
    pc.rock = F
    return stages[-1][1] + 3.2


def scree(pc):
    rng = random.Random(67)
    F = G.Field()
    for _ in range(9):  # a low mound of rock and soil, highest against the wall
        x = rng.uniform(-11, 11)
        y = rng.uniform(1, 13)
        h = 3.2 - 0.12 * y + rng.uniform(-0.5, 0.6)
        F.u(rough(G.rbox((x, y, h / 2 - 1.5), (rng.uniform(3.5, 6.5), rng.uniform(3.0, 5.0), h / 2 + 1.5), 1.8),
                  0.7, 0.3, 300 + int(10 * x)), k=1.2)
    F.u(rough(G.rbox((0, 0.5, 0.0), (14.0, 3.5, 3.6), 1.0), 0.7, 0.3, 333), k=1.2)
    for k in range(7):  # bedrock breaking through the soil
        x, y, r = rng.uniform(-12, 12), rng.uniform(2, 14), rng.uniform(1.4, 2.6)
        F.u(rough(G.rbox((x, y, top_at(F, x, y) or 0.0), (r * 1.3, r, r * 0.7), r * 0.35), 0.4, 0.5, 340 + k), k=0.6)
    pc.rock = F
    for k in range(24):
        x, y = rng.uniform(-13, 13), rng.uniform(-1.0, 16.0)
        z = top_at(F, x, y) or 0.0
        fallen(pc, rng, x, y, z - rng.uniform(0.3, 0.8), big=rng.uniform(0.6, 1.15), broken=k % 3 == 0)
    s = pc.m("Stone")
    for x in (-8.0, 3.5):  # two face blocks spalled off the wall, leaning back against it
        w = rng.uniform(3.0, 3.8)
        s.box((0, 0, 0), (w, 1.4, COURSE * 2), C.T(x, 1.1, (top_at(F, x, 1.2) or 0.0) + COURSE * 0.8) @ C.rot(rx=-0.42, rz=rng.uniform(-0.2, 0.2)),
              bevel=0.14)
    return 7.0


PIECES = {"Bedrock": ("Bellwood_FootingBedrock", bedrock), "Buttress": ("Bellwood_FootingButtress", buttress),
          "Scree": ("Bellwood_FootingScree", scree)}


# --------------------------------------------------------------------------------------------------- HIGH
def rock_high(lo, seed):
    """HIGH bedrock: the colonnade's gentle weathering, then bedding grooves on the steep faces and broad lumps."""
    C.MAX_EDGE = 0.3
    hi = C.high(lo, seed)
    co, nr = G._co_nr(hi)
    band = (co[:, 2] + 0.9 * FG.fbm(co * 0.15, 2, seed + 11)) / 0.85
    groove = FG.sst(0.13, 0.02, np.abs(band - np.round(band))) * (1.0 - np.abs(nr[:, 2]))
    lumps = FG.fbm(co * np.array([0.5, 0.5, 1.4]), 3, seed + 13)
    d = -0.17 * groove * (0.45 + 0.55 * (FG.fbm(co * 0.4, 2, seed + 12) * 0.5 + 0.5)) + 0.16 * lumps
    hi.data.vertices.foreach_set("co", (co + nr * d[:, None]).astype(np.float32).ravel())
    hi.data.update()
    return hi


def cpu_cycles():
    """This PC's AMD card fails Cycles' HIPRT set-up on the larger HIGHs (win-112: segfault or "Failed to create HIPRT Function
    Table"), so the footings bake and render on the CPU."""
    import vesp_bake as VB
    if getattr(VB.cycles, "cpu", False):
        return
    gpu = VB.cycles

    def cycles(samples=4):
        sc = gpu(samples)
        bpy.context.scene.cycles.device = "CPU"
        return sc
    cycles.cpu = True
    VB.cycles = cycles


def run(key, out, mode):
    cpu_cycles()
    name, build = PIECES[key]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t = time.time()
    pc = C.Piece(name)
    pc.m("Stone"), pc.m("Vine")
    top = build(pc)
    C.vines(pc, random.Random(7))
    H.NAME, H.ROLES = name, MESH_ROLES
    lows = H.objects(pc)
    lows["Rock"] = rock_low(pc.rock, f"{name}__Rock")
    log("LOW " + " ".join(f"{r}={sum(len(p.vertices) - 2 for p in o.data.polygons)}" for r, o in lows.items())
        + f"  top={top:.1f}  {time.time() - t:.1f}s")
    lo_b, hi_b = FG.bbox(list(lows.values()))
    rkw = {"views": (("q34", 145.0), ("front", 180.0), ("side", 100.0)), "ez": 3.0, "res": (1600, 1000),
           "close": (160.0, lo_b, hi_b, 6.0)}
    highs = {}
    C.MAX_EDGE = 0.24
    highs["Stone"] = C.high(lows["Stone"], 61, (), pc.breaks)
    highs["Vine"] = C.high(lows["Vine"], 75)
    highs["Rock"] = rock_high(lows["Rock"], 89)
    if mode == "clay":
        cm = G.clay_mat()
        for role, o in lows.items():
            highs[role].data.materials.append(cm)
            o.hide_render = True
        return G.render_set(name, list(highs.values()), out / "renders", "clay", **rkw)
    import vesp_bake as VB
    srcs = {"Stone": (H.src("rock_04", "stone"), 5.0), "Rock": (H.src("dark_rock", "bedrock"), 9.0),
            "Vine": (H.src("bark_willow_02", "moss"), 3.0)}
    for role, (srcmap, tile) in srcs.items():
        highs[role].data.materials.append(VB.hi_material(f"Hi_Foot{role}", srcmap, tile=tile))
        VB.unwrap(lows[role])
        log(f"HIGH {role} {VB.tris(highs[role])} tris")
    moss = (0.25, 0.32, 0.12)
    cool = (0.9, 0.96, 1.0)  # the temple's masonry reads blue-grey in the Hollow's light
    looks = {
        "Stone": VB.Look(base=0.24, grime=0.45, edge=0.35, sat=0.2, stone_tint=cool, moss=0.8, moss_open=0.5, moss_col=moss,
                         lichen=0.25, cavity=0.8, rough_base=0.86),
        "Rock": VB.Look(base=0.19, grime=0.5, edge=0.25, sat=0.15, stone_tint=(0.84, 0.92, 1.0), moss=1.0, moss_open=0.65,
                        moss_col=moss, lichen=0.15, cavity=0.9, rough_base=0.9),
        "Vine": VB.Look(base=0.2, grime=0.4, edge=0.1, sat=0.6, stone_tint=(0.55, 0.7, 0.35), moss=1.0, moss_open=0.9,
                        moss_col=moss, cavity=0.6, rough_base=0.92),
    }
    rays = {"Stone": (0.35, 0.7), "Rock": (0.5, 1.0), "Vine": (0.35, 0.7)}
    files, entry = G.finish(name, "Bellwood", lows, highs, out, looks, rays,
                            "Poly Haven rock_04, dark_rock, bark_willow_02 (CC0)",
                            extra={"collision": {"Stone": "Hull", "Rock": "Hull"}}, builder=BUILDER, render_kw=rkw)
    G.merge_manifest(out, {name: entry}, "Bellwood landmark: colossal temple footings")
    return files


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_footings").resolve()
    (out / "renders").mkdir(parents=True, exist_ok=True)
    mode = os.environ.get("FOOT_MODE", "clay")
    for k in os.environ.get("FOOT_PIECES", "Bedrock,Buttress,Scree").split(","):
        log("files", run(k, out, mode))


if __name__ == "__main__":
    main()

"""Bellwood guardian pair, sculpted from the CC0 Zenodo lion scan (record 10324226).

The scan is a seated European lion holding an escutcheon. It is only the sculpt base. This recipe
removes the escutcheon and the slab, lowers the raised forearm onto a new support, and enlarges
the paws, chest and mane. It smooths the mane under rows of carved spiral curls and adds a collar.
East rests its paw on a carved ball in a lotus cushion and wears a bell. West rests it on an
eight-spoke wheel-stone in a lotus cradle and wears a lotus medallion.

Creator direction (22 Nov 2026): the heads are deliberately destroyed, with no faces. West's head is
sheared off through the mane line, and the stump tilts toward the stair. East lost its face and
the outer half of its head and mane, which leaves a stepped crag of rear mane, and a crack runs
down its chest. Both breaks are exact booleans against faceted conchoidal surfaces. The fallen
pieces are real chunks of each head's mane, cut by the same breaks. They lie with small rubble on
the terrace beside each coursed sumeru plinth.

Run headless from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender -b --offline-mode --python-exit-code 1 \
    --python assets/source/landmarks/bellwood_temple_colossal/guardians.py
Env: GUARD_RENDER=0 skips the review renders, GUARD_SAMPLES sets Cycles samples, GUARD_CLAY=1
adds clay turnarounds to the work folder.

Output frame (both GLBs): origin at the plinth's bottom centre, +Z up, the guardian faces +Y.
That is the frame `lion_plinth` uses in stair_reference.py, so placing a GLB is
`at(*location) @ Matrix.Rotation(yaw, 4, "Z")`.
"""
import hashlib
import math
import os
import random
import resource
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[4]
SCAN = ROOT / "assets/source/props_cc0/zenodo_lion_scan/lion_scan.glb"
SCAN_MD5 = "77f9da14228246a2758105c2368be79f"
REFERENCE = ROOT / "assets/source/landmarks/bellwood_temple_colossal/creator-stair-reference.png"
OUT = Path(os.environ.get("GUARD_OUT", str(ROOT / "work/claude-bellwood-guardians")))
SHOTS = ROOT / "outputs/claude-open-world-2026-11-14/captures/mac/bellwood_face"
SCAN_HEIGHT = 24.0  # the scan is normalised to this height, slab included, before sculpting
PLATE = 1.75        # top of the scan's slab after normalising; it becomes the lion's z = 0

# Landmarks in the normalised scan frame (lion faces -X, raised paw on +Y, slab top at z = PLATE).
# Read from 1-stud ortho grids of the scan; z values here still include the slab.
LM = {
    "head": (-5.3, -0.9, 20.6), "neck": (-3.0, -0.5, 16.0),
    "collar": (-4.2, -0.5, 14.6),
    "paw_raised": (-9.3, 1.2, 13.3), "elbow": (-4.0, 2.4, 8.5), "paw_fore": (-7.0, -3.6, 2.4),
    "hind_a": (1.4, -4.6, 2.5), "hind_b": (1.4, 4.6, 2.5), "tail_tip": (10.6, -1.0, 2.5),
}

SPECS = {
    # East: male, carved ball, bell. The face and the outer half of the head and mane split away,
    # leaving a stepped crag of rear mane on the stair side and a long crack down the chest.
    "east": dict(side=1, seed=4127, height=24.6, arm=-.84, head_scale=1.36,
                 support="ball", collar="bell", moss=.85, wear=.9,
                 fracture=dict(drop=-2.7, tilt=(.42, -.24), step=3.7, crack=True),
                 fragments=[((2.0, 3.1, .6), 2.7), ((1.6, 1.2, 3.0), 2.3), ((1.2, 3.6, -1.6), 1.9)],
                 scars=[("side", [(1.5, 9.2), (3.4, 7.6), (5.2, 6.4)], -1, .20, .36)],
                 chips=[((-3.4, -4.4, 3.6), (0, -1, .2), .55)]),
    # West: female, wheel, lotus medallion. Head sheared clean off through the mane line, the stump
    # tilted toward the stair; heavier moss and a shoulder slash.
    "west": dict(side=-1, seed=8803, height=24.0, arm=-.62, head_scale=1.31,
                 support="wheel", collar="lotus", moss=1.25, wear=.45,
                 fracture=dict(drop=-2.3, tilt=(.36, .44), step=0.0, crack=False),
                 fragments=[((2.2, -.4, 2.4), 2.6), ((1.4, -2.9, 1.0), 2.1), ((1.6, 2.9, 1.2), 2.0)],
                 scars=[("side", [(-2.2, 13.4), (-.4, 11.2), (1.4, 9.8), (2.6, 9.1)], -1, .22, .34),
                        ("side", [(2.0, 13.6), (3.3, 12.7)], -1, .14, .24)],
                 chips=[((-8.7, -4.6, 2.3), (-.6, -.7, .3), .45)]),
}


# ---------------------------------------------------------------- small helpers

def smooth01(d, r0, r1):
    t = np.clip((r1 - d) / max(r1 - r0, 1e-6), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def lm(name, shift=True):
    x, y, z = LM[name]
    return np.array((x, y, z - (PLATE if shift else 0.0)))


def rotate_about(points, pivot, axis, angles):
    """Rodrigues rotation with a per-point angle."""
    k = np.asarray(axis, float) / np.linalg.norm(axis)
    v = points - pivot
    c, s = np.cos(angles)[:, None], np.sin(angles)[:, None]
    return pivot + v * c + np.cross(k, v) * s + k * (v @ k)[:, None] * (1 - c)


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


def fbm(p, scale, octaves=4, seed=0.0):
    off = Vector((seed * 17.1, seed * 3.7, seed * 9.3))
    return noise.fractal(Vector(p) * scale + off, 1.0, 2.0, octaves)


class Builder:
    """Collects vertices and faces from many parts into one mesh."""

    def __init__(self):
        self.verts, self.faces = [], []

    def add(self, verts, faces):
        base = len(self.verts)
        self.verts.extend(tuple(v) for v in verts)
        self.faces.extend(tuple(i + base for i in f) for f in faces)

    def add_bm(self, bm, matrix=None):
        if matrix is not None:
            bm.transform(matrix)
        bm.verts.index_update()
        self.add([v.co for v in bm.verts], [[v.index for v in f.verts] for f in bm.faces])
        bm.free()

    def mesh_object(self, name, collection):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.verts, [], self.faces)
        me.validate(clean_customdata=False)
        ob = bpy.data.objects.new(name, me)
        collection.objects.link(ob)
        return ob


def lathe(profile, segments, matrix, cap_top=True, cap_bottom=True):
    """Revolve (r, z) about local Z; returns a bmesh already transformed."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z))
                      for a in (i * math.tau / segments for i in range(segments))])
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    if cap_bottom and profile[0][0] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bm.transform(matrix)
    return bm


def ring_lathe(section, radius, segments, matrix):
    """A closed ring: revolve a closed (dr, z) section offset by `radius`."""
    bm = bmesh.new()
    rings = [[bm.verts.new(((radius + dr) * math.cos(a), (radius + dr) * math.sin(a), z))
              for dr, z in section] for a in (i * math.tau / segments for i in range(segments))]
    n = len(section)
    for i in range(segments):
        a, b = rings[i], rings[(i + 1) % segments]
        for k in range(n):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    bm.transform(matrix)
    return bm


def frame_from(normal, centre, spin=0.0):
    n = Vector(normal).normalized()
    ref = Vector((0, 0, 1)) if abs(n.z) < .9 else Vector((1, 0, 0))
    u = ref.cross(n).normalized()
    v = n.cross(u)
    m = Matrix((u, v, n)).transposed().to_4x4()
    return Matrix.Translation(Vector(centre)) @ m @ Matrix.Rotation(spin, 4, "Z")


def grid_box(nx, ny, nz):
    """Closed box over [-1, 1]^3 with nx, ny, nz quads along each axis."""
    bm = bmesh.new()
    n = (nx, ny, nz)
    index = {}

    def vert(i, j, k):
        key = (i, j, k)
        if key not in index:
            index[key] = bm.verts.new((2 * i / nx - 1, 2 * j / ny - 1, 2 * k / nz - 1))
        return index[key]

    for axis in range(3):
        a, b = [x for x in range(3) if x != axis]
        for side in (0, n[axis]):
            for u in range(n[a]):
                for v in range(n[b]):
                    quad = []
                    for du, dv in ((0, 0), (1, 0), (1, 1), (0, 1)):
                        ijk = [0, 0, 0]
                        ijk[axis], ijk[a], ijk[b] = side, u + du, v + dv
                        quad.append(vert(*ijk))
                    if (side == 0) != (axis == 1):
                        quad.reverse()
                    bm.faces.new(quad)
    bm.normal_update()
    return bm


def stone_block(size, matrix, rng, radius=.22, erosion=.10, chips=1, cut=.75):
    """Rounded, weathered block: pitted faces, softened arrises, a chipped corner or two."""
    hx, hy, hz = (s / 2 for s in size)
    bm = grid_box(*(int(np.clip(round(s / cut), 2, 8)) for s in size))
    h = Vector((hx, hy, hz))
    r = min(radius, hx * .45, hy * .45, hz * .45)
    seed = rng.random() * 100
    cut_planes = []
    for _ in range(chips):
        corner = Vector((rng.choice((-1, 1)) * hx, rng.choice((-1, 1)) * hy, rng.choice((-1, 1)) * hz))
        n = Vector((corner.x / hx * rng.uniform(.6, 1), corner.y / hy * rng.uniform(.6, 1),
                    corner.z / hz * rng.uniform(.4, 1))).normalized()
        depth = rng.uniform(.25, .75) * min(hx, hy, hz, 1.6)
        cut_planes.append((corner - n * depth, n))
    for v in bm.verts:
        p = Vector((v.co.x * hx, v.co.y * hy, v.co.z * hz))
        q = Vector([max(-(h[i] - r), min(h[i] - r, p[i])) for i in range(3)])
        d = p - q
        nrm = d.normalized() if d.length > 1e-6 else Vector((0, 0, 1))
        p = q + nrm * r
        pit = fbm(p, .55, 4, seed)
        p += nrm * (-erosion * (.55 + .45 * pit) - .6 * erosion * max(0.0, fbm(p, 2.1, 2, seed + 3)))
        for origin, n in cut_planes:
            s = (p - origin).dot(n)
            if s > 0:
                p -= n * s * .96
        v.co = p
    bm.transform(matrix)
    return bm


def petal(base, out, up, length, width, thick, curl=.35):
    """A carved lotus petal growing from `base` along `out`, lifting toward `up`."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=1.0)
    out, up = Vector(out).normalized(), Vector(up).normalized()
    side = up.cross(out).normalized()
    up = out.cross(side).normalized()
    for v in bm.verts:
        x, y, z = v.co  # z runs base(-1) to tip(+1)
        u = (z + 1) / 2
        w = width * math.sin(math.pi * min(1, u * 1.05) ** .75) * (1 - .35 * u)
        t = thick * (1 - .7 * u)
        along = u * length
        lift = curl * length * u * u
        v.co = Vector(base) + out * along + up * (lift + y * t) + side * (x * w * .5)
    return bm


def wheel_relief(builder, matrix, radius, depth, spokes=8, rng=None):
    """Eight-spoke wheel: rim, spokes, petalled hub. Local plane XY, face +Z."""
    rr = radius
    sec = [(-.13 * rr, 0), (.13 * rr, 0), (.15 * rr, depth * .7), (.07 * rr, depth), (-.07 * rr, depth),
           (-.15 * rr, depth * .7)]
    builder.add_bm(ring_lathe(sec, rr * .86, 48, Matrix()), matrix)
    for k in range(spokes):
        a = (k + .5) * math.tau / spokes
        mid = Vector((math.cos(a), math.sin(a), 0)) * rr * .5
        m = Matrix.Translation(mid + Vector((0, 0, depth * .42))) @ Matrix.Rotation(a, 4, "Z")
        builder.add_bm(stone_block((rr * .6, rr * .15, depth * .84), m, rng or random.Random(k),
                                   radius=.05 * rr, erosion=.012 * rr, chips=0, cut=.25 * rr), matrix)
    hub = [(0, 0), (.24 * rr, 0), (.25 * rr, depth * .9), (.16 * rr, depth * 1.25), (0, depth * 1.35)]
    builder.add_bm(lathe(hub, 24, Matrix(), cap_top=False), matrix)
    for k in range(8):
        a = k * math.tau / 8
        out = Vector((math.cos(a), math.sin(a), .1))
        builder.add_bm(petal(Vector((0, 0, depth)) + out * rr * .12, out, (0, 0, 1),
                             rr * .2, rr * .14, rr * .05, .3), matrix)


def lotus_relief(builder, matrix, radius, depth):
    """Two rings of petals around a seed-pod boss. Local plane XY, face +Z."""
    for ring, (count, length, lift, phase) in enumerate(((10, .62, .08, 0), (8, .42, .5, .5))):
        for k in range(count):
            a = (k + phase) * math.tau / count
            out = Vector((math.cos(a), math.sin(a), lift))
            builder.add_bm(petal(Vector((0, 0, depth * (.2 + .5 * ring))) + out * radius * .18, out, (0, 0, 1),
                                 radius * length, radius * (.42 if ring == 0 else .36), depth * .55, .25),
                           matrix)
    boss = [(0, 0), (.24 * radius, 0), (.24 * radius, depth * 1.1), (.16 * radius, depth * 1.35), (0, depth * 1.4)]
    builder.add_bm(lathe(boss, 20, Matrix(), cap_top=False), matrix)


# ---------------------------------------------------------------- the scan

def scan_bmesh(untouched=False):
    """The normalised scan. `untouched` keeps its UVs, seams and material for the as-is mode."""
    digest = hashlib.md5(SCAN.read_bytes()).hexdigest()
    if digest != SCAN_MD5:
        raise SystemExit(f"lion scan MD5 {digest} != {SCAN_MD5}; refusing an unverified base")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(SCAN))
    new = set(bpy.data.objects) - before
    ob, = [o for o in new if o.type == "MESH"]
    me = ob.data.copy()
    me.transform(ob.matrix_world)
    material = ob.data.materials[0]
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    co = np.array([v.co for v in me.vertices])
    lo, hi = co.min(0), co.max(0)
    me.transform(Matrix.Scale(SCAN_HEIGHT / (hi[2] - lo[2]), 4)
                 @ Matrix.Translation(-Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]))))
    if untouched:
        return me, material
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=.004)  # glTF split the scan along UV seams
    for layer in list(bm.loops.layers.uv):
        bm.loops.layers.uv.remove(layer)
    return bm


def strip_escutcheon_and_slab(bm):
    """Delete the shield plate and the slab; keep the paw that rested on the shield."""
    doomed = set()
    for f in bm.faces:
        zs = [v.co.z for v in f.verts]
        if max(zs) < PLATE + .11:
            doomed.add(f)
            continue
        c = f.calc_center_median()
        d = .957 * (c.x + 10.3) + .29 * (c.z - 13.0)  # distance from the tilted shield plane
        if -.8 < d < 1.0 and 1.95 < c.z < 12.3 and -1.9 < c.y < 3.9:
            doomed.add(f)
    bmesh.ops.delete(bm, geom=list(doomed), context="FACES")
    # drop crumbs: islands far smaller than the lion
    seen, crumbs = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        island, stack = [], [v]
        seen.add(v)
        while stack:
            x = stack.pop()
            island.append(x)
            for e in x.link_edges:
                w = e.other_vert(x)
                if w not in seen:
                    seen.add(w)
                    stack.append(w)
        if len(island) < 400:
            crumbs.extend(island)
    bmesh.ops.delete(bm, geom=crumbs, context="VERTS")
    bm.transform(Matrix.Translation((0, 0, -PLATE)))


def mesh_arrays(me):
    n = len(me.vertices)
    co = np.empty(n * 3)
    me.vertices.foreach_get("co", co)
    ed = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", ed)
    return co.reshape(-1, 3), ed.reshape(-1, 2)


def vertex_normals(me, co):
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    nr = np.empty(len(me.vertices) * 3)
    me.vertex_normals.foreach_get("vector", nr)
    return nr.reshape(-1, 3)


def laplacian(co, edges, weight, iterations, lam=.5):
    n = len(co)
    deg = np.bincount(edges.ravel(), minlength=n).astype(float)
    deg[deg == 0] = 1
    for _ in range(iterations):
        acc = np.zeros_like(co)
        np.add.at(acc, edges[:, 0], co[edges[:, 1]])
        np.add.at(acc, edges[:, 1], co[edges[:, 0]])
        co = co + (lam * weight)[:, None] * (acc / deg[:, None] - co)
    return co


def region_weights(co):
    """Masks from the undeformed scan: mane (to smooth and curl), face (kept clear of curls)."""
    p = co
    head = lm("head")
    e1 = ((p - np.array((-2.8, 0, 19.0 - PLATE))) / np.array((5.2, 6.6, 5.9)))
    e2 = ((p - np.array((-3.6, 0, 13.4 - PLATE))) / np.array((4.1, 6.3, 3.9)))
    mane = np.maximum(smooth01(np.linalg.norm(e1, axis=1), .78, 1.08),
                      smooth01(np.linalg.norm(e2, axis=1), .72, 1.05) * (p[:, 0] < .5))
    rel = p - head
    face = (smooth01(np.abs(rel[:, 1] + .2), 2.4, 3.3) * smooth01(rel[:, 0], -1.4, -.6)
            * smooth01(np.abs(rel[:, 2] + .2), 2.6, 3.6))
    arm = smooth01(np.linalg.norm(p - lm("paw_raised"), axis=1), 2.2, 3.6)
    mane = mane * (1 - face) * (1 - arm)
    return mane, face


def sculpt_lion(spec, rng):
    bm = scan_bmesh()
    strip_escutcheon_and_slab(bm)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    me = bpy.data.meshes.new("sculpt")
    bm.to_mesh(me)
    bm.free()
    co, edges = mesh_arrays(me)
    mane, face = region_weights(co)
    marks = {k: lm(k) for k in LM}

    # 1. quiet the scan's long European locks so carved curls can own the mane
    co = laplacian(co, edges, mane * .85, 16)

    # 4..7 positional warps applied to mesh and landmarks alike
    def warp(points, marks=dict(marks)):
        p = points.copy()
        # lower the raised forearm about the elbow so the paw rests on a ground-level ball or wheel
        elbow, paw = marks["elbow"], marks["paw_raised"] + np.array((-.8, 0, .3))
        w = smooth01(seg_dist(p, elbow, paw), 1.5, 2.6) * smooth01(-p[:, 1], -.9, -.1)
        p = rotate_about(p, elbow, (0, 1, 0), spec["arm"] * w)
        lowered = rotate_about(marks["paw_raised"][None], elbow, (0, 1, 0), np.array([spec["arm"]]))[0]
        for key, scale, r0, r1 in (("paw_raised", 1.4, 1.5, 2.9), ("paw_fore", 1.45, 1.6, 3.2),
                                   ("hind_a", 1.15, 1.2, 2.6), ("hind_b", 1.15, 1.2, 2.6)):
            c = lowered if key == "paw_raised" else marks[key]
            base = c.copy()
            if key != "paw_raised":
                base[2] = 0.0
            w = smooth01(np.linalg.norm(p - c, axis=1), r0, r1)
            p = base + (p - base) * (1 + (scale - 1) * w)[:, None]
        h = marks["head"]
        w = smooth01(np.linalg.norm(p - h, axis=1), 4.2, 8.2)
        p = h + (p - h) * (1 + (spec["head_scale"] - 1) * w)[:, None]
        return p * np.array((.84, 1.32, .9))

    co = warp(co)
    marks = {k: warp(v[None])[0] for k, v in marks.items()}

    # 8. scars and chips
    for view, path, sign, depth, width in spec["scars"]:
        nr = vertex_normals(me, co)
        bvh = BVHTree.FromPolygons([tuple(v) for v in co], [tuple(p.vertices) for p in me.polygons])
        pts = []
        for i in range(len(path) - 1):
            for t in np.linspace(0, 1, 8, endpoint=False):
                x = path[i][0] + (path[i + 1][0] - path[i][0]) * t
                z = path[i][1] + (path[i + 1][1] - path[i][1]) * t
                z = z - PLATE
                hit = bvh.ray_cast(Vector((x * .86, sign * 20, z * .96)), Vector((0, -sign, 0)))
                if hit[0] is not None:
                    pts.append(np.array(hit[0]))
        if len(pts) < 2:
            continue
        pts = np.array(pts)
        d = np.min([seg_dist(co, a, b) for a, b in zip(pts, pts[1:])], axis=0)
        groove = smooth01(d, width * .25, width)
        jitter = np.array([fbm(p, 3.0, 2, 7) for p in co[groove > 0]])
        g = groove.copy()
        g[groove > 0] *= (.75 + .35 * jitter)
        co = co - nr * (depth * g)[:, None]
    for centre, normal, radius in spec["chips"]:
        c = np.array(centre) - np.array((0, 0, PLATE))
        c = warp(c[None])[0]
        n = np.array(normal) / np.linalg.norm(normal)
        inside = np.linalg.norm(co - c, axis=1) < radius * 1.6
        s = (co - (c - n * radius * .35)) @ n
        cut = inside & (s > 0)
        co[cut] -= n * s[cut, None] * .95

    # 9. weathered pitting over everything
    nr = vertex_normals(me, co)
    seed = spec["seed"] % 97
    pit = np.array([.6 * fbm(p, 1.7, 4, seed) + .4 * fbm(p, 6.5, 2, seed + 1) for p in co])
    co = co + nr * (.055 * pit - .02)[:, None]
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    return me, co, mane, face, marks


def surface_samples(me, co, weight, spacing, rng, keep):
    """Poisson-ish points on faces whose corners carry `weight`; `keep(p, n)` filters."""
    tri = np.array([p.vertices[:3] for p in me.polygons])
    a, b, c = co[tri[:, 0]], co[tri[:, 1]], co[tri[:, 2]]
    area = .5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    fw = weight[tri].mean(1)
    prob = area * (fw > .55)
    if prob.sum() == 0:
        return []
    count = int(prob.sum() / (spacing * spacing) * 6) + 50
    nprng = np.random.default_rng(rng.randrange(1 << 30))
    pick = nprng.choice(len(tri), size=count, p=prob / prob.sum())
    r1, r2 = nprng.random(count), nprng.random(count)
    flip = r1 + r2 > 1
    r1[flip], r2[flip] = 1 - r1[flip], 1 - r2[flip]
    pts = a[pick] + (b[pick] - a[pick]) * r1[:, None] + (c[pick] - a[pick]) * r2[:, None]
    nrm = np.cross(b[pick] - a[pick], c[pick] - a[pick])
    nrm /= np.linalg.norm(nrm, axis=1)[:, None] + 1e-9
    grid, chosen = {}, []
    for p, n in zip(pts, nrm):
        if not keep(p, n):
            continue
        key = tuple((p // spacing).astype(int))
        near = [q for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)
                for q in grid.get((key[0] + dx, key[1] + dy, key[2] + dz), ())]
        if all(np.linalg.norm(p - q) >= spacing for q in near):
            grid.setdefault(key, []).append(p)
            chosen.append((p, n))
    return chosen


def spiral_curl(builder, base, normal, radius, handed, spin):
    """A carved snail curl: a tapering tube winding in and up to a crown, sunk into the mane."""
    m = frame_from(normal, base, spin)
    turns, segs, sides = 2.15, 24, 6
    rings = []
    for i in range(segs + 1):
        s = i / segs
        th = handed * s * turns * math.tau
        r = radius * (1 - .82 * s)
        rings.append(Vector((r * math.cos(th), r * math.sin(th), radius * (.62 * s ** .8 - .28))))
    verts, faces = [], []
    for i, c in enumerate(rings):
        s = i / segs
        t = (rings[min(i + 1, segs)] - rings[max(i - 1, 0)]).normalized()
        nside = t.cross(Vector((0, 0, 1))).normalized()
        nup = nside.cross(t).normalized()
        tube = radius * .36 * (1 - .62 * s) + .02
        for k in range(sides):
            a = k * math.tau / sides
            verts.append(m @ (c + (nside * math.cos(a) + nup * math.sin(a) * 1.15) * tube))
    for i in range(segs):
        for k in range(sides):
            j = (k + 1) % sides
            faces.append((i * sides + k, i * sides + j, (i + 1) * sides + j, (i + 1) * sides + k))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple(segs * sides + k for k in range(sides)))
    builder.add(verts, faces)


def collar_loop(bvh, centre, forward, count=72):
    """Points around the neck found by casting outward from inside the body."""
    f = Vector(forward).normalized()
    side = Vector((0, 1, 0))
    up = f.cross(side).normalized()
    side = up.cross(f).normalized()
    radii, dirs = [], []
    for i in range(count):
        t = i * math.tau / count
        d = f * math.cos(t) + side * math.sin(t)
        hit = bvh.ray_cast(Vector(centre), d, 14.0)
        radii.append(hit[3] if hit[0] is not None else 5.0)
        dirs.append(d)
    r = np.array(radii)
    for _ in range(6):  # ride over lock tips instead of dipping between them
        r = np.maximum(r, .5 * (np.roll(r, 1) + np.roll(r, -1)))
        r = .25 * np.roll(r, 1) + .5 * r + .25 * np.roll(r, -1)
    return [Vector(centre) + d * (ri + .12) for d, ri in zip(dirs, r)], up


def sweep_loop(builder, loop, up, width, thick):
    sec = [(-thick * .2, -width / 2), (thick, -width * .42), (thick * 1.1, 0), (thick, width * .42),
           (-thick * .2, width / 2)]
    n = len(loop)
    verts = []
    for i, p in enumerate(loop):
        t = (loop[(i + 1) % n] - loop[i - 1]).normalized()
        out = t.cross(up).normalized()
        if out.dot(p - sum(loop, Vector()) / n) < 0:
            out = -out
        for o, z in sec:
            verts.append(p + out * o + up * z)
    k = len(sec)
    faces = [(i * k + j, i * k + j + 1, ((i + 1) % n) * k + j + 1, ((i + 1) % n) * k + j)
             for i in range(n) for j in range(k - 1)]
    builder.add(verts, faces)


def dress_lion(spec, me, co, mane, face, marks, rng):
    """Curls, collar, chest ornament and the paw support, all in the scan frame."""
    b = Builder()
    b.add(co, [tuple(p.vertices) for p in me.polygons])
    bvh = BVHTree.FromPolygons([tuple(v) for v in co], [tuple(p.vertices) for p in me.polygons])

    # collar first, so the curls can stay off it
    loop, up = collar_loop(bvh, marks["collar"], (-1, 0, -.55))
    sweep_loop(b, loop, up, 1.35, .5)
    for i in range(0, len(loop), 4):
        p = loop[i]
        out = (p - Vector(marks["collar"])).normalized()
        b.add_bm(lathe([(0, 0), (.24, 0), (.26, .16), (.17, .3), (0, .34)], 10, frame_from(out, p + out * .3)))
    front = loop[0]
    out = (front - Vector(marks["collar"])).normalized()
    if spec["collar"] == "bell":
        hang = front + out * .55 + Vector((0, 0, -.9))
        bell = [(0, 1.55), (.32, 1.5), (.7, 1.2), (.95, .5), (1.12, -.05), (1.0, -.18), (.0, -.12)]
        b.add_bm(lathe(bell, 28, Matrix.Translation(hang)))
        b.add_bm(ring_lathe([(-.06, -.06), (.06, -.06), (.06, .06), (-.06, .06)], .3, 16,
                            Matrix.Translation(hang + Vector((0, 0, 1.75))) @ Matrix.Rotation(math.pi / 2, 4, "X")))
        wheel_relief(b, frame_from(out, hang + out * .95 + Vector((0, 0, .55))), .48, .1, rng=rng)
    else:
        disc = front + out * .25 + Vector((0, 0, -.35))
        b.add_bm(lathe([(0, 0), (1.15, 0), (1.2, .22), (1.05, .34), (0, .38)], 32, frame_from(out, disc)))
        lotus_relief(b, frame_from(out, disc + out * .3), .95, .26)

    # deliberate rows of spiral curls: rings around the skull, then rings down the neck
    collar_pts = np.array([tuple(p) for p in loop])
    tri = np.array([p.vertices[:3] for p in me.polygons])
    face_weight = (mane * (1 - face))[tri].mean(1)
    sites = []

    def free(p, gap):
        return all(np.linalg.norm(p - q) >= gap for q, _ in sites)

    spacing = 1.42
    for centre, el_lo, el_hi in ((marks["head"] + np.array((1.2, 0, -.6)), -.35, 1.45),
                                 (marks["collar"] + np.array((.8, 0, .6)), -.55, .55)):
        centre = Vector(centre)
        el, row_i = el_lo, 0
        while el <= el_hi:
            ring = []
            for k in range(240):  # walk the ring finely, then drop curls at equal arc length
                az = k * math.tau / 240
                d = Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))
                hit = bvh.ray_cast(centre, d, 16.0)
                ring.append(hit if hit[0] is not None else None)
            run, offset = 0.0, (spacing / 2 if row_i % 2 else 0.0) + rng.uniform(0, .3)
            prev = None
            radii = [h[3] for h in ring if h]
            for h in ring:
                if h is None:
                    prev = None
                    continue
                if prev is not None:
                    run += (h[0] - prev).length
                prev = h[0]
                if run < offset:
                    continue
                offset = run + spacing
                p = np.array(h[0])
                n = Vector(h[1])
                if (p - centre) @ np.array(n) < 0:
                    n = -n
                if face_weight[h[2]] < .5 or n.z < -.45:
                    continue
                if np.min(np.linalg.norm(collar_pts - p, axis=1)) < 1.0 or not free(p, spacing * .82):
                    continue
                sites.append((p, n))
            step = spacing / (np.median(radii) if radii else 6.0)
            el += step * .93
            row_i += 1
    for p, n in sites:
        spiral_curl(b, Vector(p) - n * .12, n, rng.uniform(.6, .7), rng.choice((-1, 1)), rng.uniform(0, math.tau))
    tail = Vector(marks["tail_tip"])
    for k in range(7):
        a = k * math.tau / 7
        p = tail + Vector((math.cos(a) * .9, math.sin(a) * .9, .45 + .25 * math.sin(3 * a)))
        spiral_curl(b, p, (math.cos(a) * .6, math.sin(a) * .6, 1), .62, 1 if k % 2 else -1, a)
    spiral_curl(b, tail + Vector((0, 0, 1.1)), (0, 0, 1), .7, 1, 0)

    # the lowered paw rests on the support; find its underside
    paw = Vector(marks["paw_raised"])
    hit = bvh.ray_cast(Vector((paw.x, paw.y, -.5)), Vector((0, 0, 1)), 30)
    top = (hit[0].z if hit[0] is not None else paw.z - 1.0) + .22
    cx, cy = paw.x + .1, paw.y
    if spec["support"] == "ball":
        cushion = 1.5
        r = (top - cushion + .4) / 2
        cz = cushion - .4 + r
        b.add_bm(lathe([(0, 0), (r * 1.05, 0), (r * 1.1, .35), (r * .98, .6), (r * .9, cushion), (0, cushion)], 40,
                       Matrix.Translation((cx, cy, 0)), cap_bottom=False))
        for k in range(14):  # a lotus cushion cups the ball
            a = k * math.tau / 14
            out = Vector((math.cos(a), math.sin(a), 0))
            b.add_bm(petal(Vector((cx, cy, .5)) + out * r * .72, out + Vector((0, 0, .55)), (0, 0, 1),
                           r * .5, r * .62, .4, .45))
        ball = bmesh.new()
        bmesh.ops.create_uvsphere(ball, u_segments=44, v_segments=26, radius=r)
        b.add_bm(ball, Matrix.Translation((cx, cy, cz)))
        band = [(-.12, -.22), (.18, -.2), (.24, 0), (.18, .2), (-.12, .22)]
        for ax, ang in (("X", 0), ("X", math.pi / 3), ("X", -math.pi / 3), ("Y", math.pi / 2)):
            b.add_bm(ring_lathe(band, r, 60, Matrix.Translation((cx, cy, cz)) @ Matrix.Rotation(ang, 4, ax)
                                @ Matrix.Rotation(math.pi / 2, 4, "Y")))
        for k in range(5):  # small wheels in the ball's open panels; one faces the stair
            d = Vector((-math.cos(k * math.tau / 5), math.sin(k * math.tau / 5), .3)).normalized()
            wheel_relief(b, frame_from(d, Vector((cx, cy, cz)) + d * (r - .02)), .62, .14, rng=rng)
    else:
        base_h = 1.1
        r = (top - base_h + .5) / 2
        cz = base_h - .5 + r
        b.add_bm(lathe([(0, 0), (2.3, 0), (2.4, .35), (2.1, .6), (1.9, base_h), (0, base_h)], 36,
                       Matrix.Translation((cx, cy, 0)) @ Matrix.Diagonal((1.0, 1.45, 1, 1)), cap_bottom=False))
        for k in range(12):
            a = k * math.tau / 12
            out = Vector((math.cos(a) * .75, math.sin(a) * 1.3, 0))
            b.add_bm(petal(Vector((cx, cy, .45)) + out * 1.45, out + Vector((0, 0, 1.1)), (0, 0, 1),
                           1.3, 1.1, .3, .25))
        upright = Matrix.Translation((cx, cy, cz)) @ Matrix.Rotation(-math.pi / 2, 4, "Y")
        thick = 1.25
        # a solid wheel-stone: rounded disc, both faces carved with the eight-spoke wheel
        disc = [(0, -thick / 2), (r * .97, -thick / 2), (r, -thick * .3), (r, thick * .3), (r * .97, thick / 2),
                (0, thick / 2)]
        b.add_bm(lathe(disc, 64, upright))
        for flip in (0, math.pi):  # seen from the stair and from the rail
            wheel_relief(b, upright @ Matrix.Rotation(flip, 4, "X") @ Matrix.Translation((0, 0, thick / 2 - .08)),
                         r * .9, .42, rng=rng)
    return b


# ---------------------------------------------------------------- the broken heads

def fracture_surface(origin, normal, rng, half=10.0, step=.34, height=None):
    """Closed breaker solid whose underside is a crisp conchoidal break: Voronoi facets that meet
    in sharp ledges, shell ripples spreading from an impact point, all above `origin`/`normal`."""
    n = Vector(normal).normalized()
    e1 = (Vector((1, 0, 0)) - n * n.x).normalized()
    e2 = n.cross(e1)
    seeds = [(Vector((rng.uniform(-6, 6), rng.uniform(-6, 6))), Vector((rng.uniform(-.36, .36), rng.uniform(-.36, .36))),
              rng.uniform(-.5, .5)) for _ in range(9)]
    impact = Vector((rng.uniform(-3, 3), rng.uniform(-3, 3)))
    # shell-shaped scoops where flakes spalled off the rim
    scoops = [(Vector((math.cos(a), math.sin(a))) * rng.uniform(2.6, 4.8), rng.uniform(1.0, 2.0), rng.uniform(.35, .85))
              for a in (rng.uniform(0, math.tau) for _ in range(6))]
    count = int(2 * half / step)
    bm = bmesh.new()
    grid = []
    for i in range(count + 1):
        row = []
        for j in range(count + 1):
            uv = Vector((-half + i * step, -half + j * step))
            seed, grad, off = min(seeds, key=lambda t: (t[0] - uv).length)
            h = grad.dot(uv - seed) + off
            r = (uv - impact).length
            h += .08 * math.sin(r * 5.2) * math.exp(-r / 3.2) + .035 * noise.noise(Vector((uv.x, uv.y, 0)) * 1.7)
            for centre, radius, depth in scoops:
                t = 1 - ((uv - centre).length / radius) ** 2
                if t > 0:
                    h -= depth * t
            q = Vector(origin) + e1 * uv.x + e2 * uv.y
            if height:
                h += height(q)
            row.append(bm.verts.new(q + n * h))
        grid.append(row)
    for i in range(count):
        for j in range(count):
            bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    rim = [e for e in bm.edges if e.is_boundary]
    ext = bmesh.ops.extrude_edge_only(bm, edges=rim)
    top = [v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top, vec=n * 40)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if bm.calc_volume(signed=True) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("breaker")
    bm.to_mesh(me)
    bm.free()
    return me


def boolean(target_me, cutter_me, operation):
    """Exact boolean between two meshes; returns a new mesh. Inputs are left untouched."""
    col = bpy.context.scene.collection
    a = bpy.data.objects.new("bool_target", target_me)
    b = bpy.data.objects.new("bool_cutter", cutter_me)
    col.objects.link(a)
    col.objects.link(b)
    mod = a.modifiers.new("cut", "BOOLEAN")
    mod.object, mod.operation, mod.solver = b, operation, "EXACT"
    mod.use_self, mod.use_hole_tolerant = True, True
    dg = bpy.context.evaluated_depsgraph_get()
    out = bpy.data.meshes.new_from_object(a.evaluated_get(dg))
    bpy.data.objects.remove(a)
    bpy.data.objects.remove(b)
    return out


def tag_fracture(me, cutter_me):
    """Faces lying on the cutter are fresh breaks: flat-shaded facets and a 'Fracture' mask."""
    bvh = BVHTree.FromPolygons([v.co.copy() for v in cutter_me.vertices], [p.vertices[:] for p in cutter_me.polygons])
    mask = np.zeros(len(me.vertices), np.float32)
    old = me.attributes.get("Fracture")
    if old:
        old.data.foreach_get("value", mask)
    for p in me.polygons:
        hit = bvh.find_nearest(p.center)
        if hit[0] is not None and hit[3] < .012:
            p.use_smooth = False
            mask[list(p.vertices)] = 1.0
    attr = me.attributes.get("Fracture") or me.attributes.new("Fracture", "FLOAT", "POINT")
    attr.data.foreach_set("value", mask)


def crop(me, centre, radius):
    """Copy of `me` keeping only faces near `centre` (keeps booleans on fragments cheap)."""
    bm = bmesh.new()
    bm.from_mesh(me)
    c = Vector(centre)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if (f.calc_center_median() - c).length > radius], context="FACES")
    out = bpy.data.meshes.new("crop")
    bm.to_mesh(out)
    bm.free()
    return out


def split_by_plane(me, origin, normal, margin, centre, radius):
    """Faces above (plane - margin) within `radius` of `centre`, and the rest, as two meshes."""
    parts = []
    for keep_above in (True, False):
        bm = bmesh.new()
        bm.from_mesh(me)
        doomed = []
        for f in bm.faces:
            c = f.calc_center_median()
            near = (c - origin).dot(normal) > -margin and (c - centre).length < radius
            if near != keep_above:
                doomed.append(f)
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        out = bpy.data.meshes.new("part")
        bm.to_mesh(out)
        bm.free()
        parts.append(out)
    return parts


def chunk_hull(centre, radius, rng, cuts=2):
    """A convex, many-faceted chunk; its faces become the fragment's break surfaces."""
    bm = bmesh.new()
    for _ in range(18):
        d = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
        bm.verts.new(Vector(centre) + Vector((d.x, d.y * .85, d.z * .75)) * radius * rng.uniform(.75, 1.15))
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    me = bpy.data.meshes.new("chunk")
    bm.to_mesh(me)
    bm.free()
    return me


def break_head(lion_me, spec, marks, rng):
    """Shear or split the head away. Returns the broken statue mesh and the fallen fragments."""
    f = spec["fracture"]
    head = Vector(marks["head"])
    origin = head + Vector((0, 0, f["drop"]))
    a, b = f["tilt"]
    normal = Vector((-a, -b, 1)).normalized()  # front lower by a; b > 0 drops the stair side (-Y)

    step = None
    if f["step"]:
        def step(q):  # a stepped crag of rear mane stays standing on the stair side
            edge = .55 * noise.noise(q * .9)
            back = smooth01(np.array([-(q.x - head.x) + .2 + edge]), -.5, .45)[0]
            stair = smooth01(np.array([(q.y - head.y) + .4 + edge]), -.5, .45)[0]
            return f["step"] * back * stair
    cutter = fracture_surface(origin, normal, rng, height=step)

    # fragments are real pieces of the head's mane, taken before the head is removed
    fragments = []
    for offset, radius in spec["fragments"]:
        c = head + Vector(offset)
        hull = chunk_hull(c, radius, rng)
        piece = boolean(crop(lion_me, c, radius + 1.6), hull, "INTERSECT")
        piece = boolean(piece, cutter, "INTERSECT")  # only what lay above the break can have fallen
        if len(piece.polygons) > 40:
            tag_fracture(piece, hull)
            tag_fracture(piece, cutter)
            fragments.append(piece)
        bpy.data.meshes.remove(hull)

    # cut only the region near the break: the exact solver on the whole statue needed over 3 GB
    head_part, body_part = split_by_plane(lion_me, origin, normal, 2.4, head, 10.5)
    cut = boolean(head_part, cutter, "DIFFERENCE")
    bm = bmesh.new()
    bm.from_mesh(body_part)
    bm.from_mesh(cut)
    seam = [v for v in bm.verts if v.is_boundary]
    bmesh.ops.remove_doubles(bm, verts=seam, dist=1e-4)
    broken = bpy.data.meshes.new("broken")
    bm.to_mesh(broken)
    bm.free()
    for m in (head_part, body_part, cut):
        bpy.data.meshes.remove(m)
    tag_fracture(broken, cutter)
    bpy.data.meshes.remove(cutter)
    if f["crack"]:
        chest_crack(broken, head, rng)
    return broken, fragments


def chest_crack(me, head, rng):
    """A long, sharp-lipped crack from the break down the chest, with short side branches."""
    co, _ = mesh_arrays(me)
    nr = vertex_normals(me, co)
    bvh = BVHTree.FromPolygons([tuple(v) for v in co], [tuple(p.vertices) for p in me.polygons])
    paths, y = [], head.y + .9
    main = []
    for z in np.linspace(head.z - 2.6, 4.2, 34):
        y += rng.uniform(-.28, .28)
        hit = bvh.ray_cast(Vector((head.x - 14, y, z)), Vector((1, 0, 0)), 20)
        if hit[0] is not None:
            main.append(np.array(hit[0]))
    paths.append((main, .34, .42))
    for k in (9, 17, 25):
        if k < len(main):
            start, branch = main[k], [main[k]]
            dy = rng.choice((-1, 1))
            for t in range(1, 6):
                hit = bvh.ray_cast(Vector((head.x - 14, start[1] + dy * t * .45, start[2] - t * .35)), Vector((1, 0, 0)), 20)
                if hit[0] is not None:
                    branch.append(np.array(hit[0]))
            paths.append((branch, .2, .26))
    for pts, depth, width in paths:
        if len(pts) < 2:
            continue
        d = np.min([seg_dist(co, p0, p1) for p0, p1 in zip(pts, pts[1:])], axis=0)
        v = np.clip(1 - d / width, 0, 1)  # V profile: crisp lips, dark floor
        co = co - nr * (depth * v)[:, None]
    me.vertices.foreach_set("co", co.ravel())
    me.update()


def rubble_mesh(rng, spots):
    """Small angular chips of the same stone; `spots` lists (x, y, z, spread, count)."""
    b = Builder()
    for x, y, z, spread, count in spots:
        for _ in range(count):
            r = rng.uniform(.18, .55) * (1.6 if rng.random() < .2 else 1)
            c = Vector((x + rng.gauss(0, spread), y + rng.gauss(0, spread), z + r * .45))
            bm = bmesh.new()
            for _ in range(9):
                d = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, .6))).normalized()
                bm.verts.new(c + d * r * rng.uniform(.6, 1.2))
            bmesh.ops.convex_hull(bm, input=bm.verts[:])
            b.add_bm(bm)
    return b


# ---------------------------------------------------------------- scan as-is (default mode)

SCAN_SPECS = {
    # Sol's v10 heights (scan and its slab), plus a few degrees of extra turn toward the stair.
    # `support` only picks the plinth's front roundel: "ball" carves the wheel, "wheel" the lotus.
    "east": dict(side=1, seed=4127, height=23.9, turn=math.radians(5), support="ball", moss=.7, lichen=.55,
                 wear=.8, tint=(.68, .71, .63)),
    "west": dict(side=-1, seed=8803, height=22.1, turn=math.radians(2.5), support="wheel", moss=1.15, lichen=.3,
                 wear=.45, tint=(.62, .68, .61)),
}
SHIELD_OUT = Vector((-.957, 0, -.29)).normalized()  # the escutcheon's face looks forward and a little down
SHIELD_CENTRE = Vector((-8.95, 1.0, 8.4))          # its middle, in the normalised scan frame


def shield_emblem(me, rng, radius=1.55, depth=.15):
    """Shallow, worn eight-spoke wheel laid onto the escutcheon's face. Adds faces only; every scan
    vertex keeps its position. Each new vertex takes the shield's UV, so the relief carries the scan's
    own stone albedo."""
    from mathutils.interpolate import poly_3d_calc
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.active
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    hit = tree.ray_cast(SHIELD_CENTRE + SHIELD_OUT * 6, -SHIELD_OUT, 12)
    centre = hit[0] if hit[0] is not None else SHIELD_CENTRE
    b = Builder()
    wheel_relief(b, frame_from(SHIELD_OUT, Vector(), rng.uniform(0, math.pi / 8)), radius, depth, rng=rng)
    verts, uvs = [], []
    seed = rng.random() * 50
    for p in b.verts:
        p = Vector(p)
        h = p.dot(SHIELD_OUT)
        q = centre + p - SHIELD_OUT * h
        hit = tree.ray_cast(q + SHIELD_OUT * 1.5, -SHIELD_OUT, 3.0)
        if hit[0] is not None and abs((hit[0] - q).dot(SHIELD_OUT)) < .6:
            base, face = hit[0], bm.faces[hit[2]]
        else:
            base, face = q, bm.faces[tree.find_nearest(q)[2]]
        wear = .55 + .45 * max(0.0, fbm(base, 2.3, 3, seed))  # the relief is worn unevenly
        verts.append(base + SHIELD_OUT * (h * wear - .03))
        w = poly_3d_calc([v.co for v in face.verts], base)
        uvs.append(sum((l[uv].uv * wi for l, wi in zip(face.loops, w)), Vector((0, 0))))
    new = [bm.verts.new(v) for v in verts]
    for f in b.faces:
        try:
            face = bm.faces.new([new[i] for i in f])
        except ValueError:
            continue
        for loop, i in zip(face.loops, f):
            loop[uv].uv = uvs[i]
    bm.to_mesh(me)
    bm.free()


def scan_material(src, key, tint):
    """The scan's own albedo and normal map, with moss, lichen, grime and edge wear from masks."""
    mat = src.copy()
    mat.name = f"Bellwood guardian scan stone ({key})"
    N, L = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in N if n.type == "BSDF_PRINCIPLED")
    base = bsdf.inputs["Base Color"]
    albedo = base.links[0].from_socket if base.links else None
    attr = N.new("ShaderNodeAttribute")
    attr.attribute_name = "Weather"
    sep = N.new("ShaderNodeSeparateColor")
    L.new(attr.outputs["Color"], sep.inputs[0])
    coord = N.new("ShaderNodeTexCoord")

    def mix(a, b_color, factor, blend="MIX"):
        m = N.new("ShaderNodeMix")
        m.data_type, m.blend_type = "RGBA", blend
        L.new(factor, m.inputs["Factor"])
        if isinstance(a, tuple):
            m.inputs[6].default_value = a
        else:
            L.new(a, m.inputs[6])
        if isinstance(b_color, tuple):
            m.inputs[7].default_value = b_color
        else:
            L.new(b_color, m.inputs[7])
        return m.outputs[2]

    one = N.new("ShaderNodeValue")
    one.outputs[0].default_value = 1.0
    c = mix(albedo if albedo else tuple(base.default_value), (*tint, 1), one.outputs[0], "MULTIPLY")
    c = mix(c, (.22, .26, .18, 1), sep.outputs[0], "MULTIPLY")  # green-black grime, as on the reference
    recess = N.new("ShaderNodeMapRange")  # deep occlusion only: grime pools in the folds of the mane and legs
    recess.inputs["From Min"].default_value, recess.inputs["From Max"].default_value = .3, .75
    L.new(sep.outputs[0], recess.inputs["Value"])
    c = mix(c, (.42, .45, .36, 1), recess.outputs["Result"], "MULTIPLY")
    wear = N.new("ShaderNodeMath")
    wear.operation = "MULTIPLY"
    wear.inputs[1].default_value = .55
    L.new(sep.outputs[2], wear.inputs[0])
    c = mix(c, (.66, .64, .59, 1), wear.outputs[0])
    lichen_n = N.new("ShaderNodeTexNoise")
    lichen_n.inputs["Scale"].default_value = 9
    lichen_n.inputs["Detail"].default_value = 4
    L.new(coord.outputs["Object"], lichen_n.inputs["Vector"])
    lichen_r = N.new("ShaderNodeValToRGB")
    lichen_r.color_ramp.elements[0].position, lichen_r.color_ramp.elements[1].position = .52, .62
    L.new(lichen_n.outputs["Fac"], lichen_r.inputs[0])
    lichen_f = N.new("ShaderNodeMath")
    lichen_f.operation = "MULTIPLY"
    L.new(attr.outputs["Alpha"], lichen_f.inputs[0])
    L.new(lichen_r.outputs[0], lichen_f.inputs[1])
    c = mix(c, (.58, .57, .44, 1), lichen_f.outputs[0])
    moss_n = N.new("ShaderNodeTexNoise")
    moss_n.inputs["Scale"].default_value = 3.5
    moss_n.inputs["Detail"].default_value = 6
    L.new(coord.outputs["Object"], moss_n.inputs["Vector"])
    moss_r = N.new("ShaderNodeValToRGB")
    moss_r.color_ramp.elements[0].color, moss_r.color_ramp.elements[1].color = (.068, .078, .026, 1), (.14, .135, .048, 1)
    L.new(moss_n.outputs["Fac"], moss_r.inputs[0])
    c = mix(c, moss_r.outputs[0], sep.outputs[1])
    L.new(c, base)
    return mat


def build_scan_guardian(key, collection):
    """The scan exactly as captured (shield kept, our wheel on its face) on a sumeru plinth."""
    spec = SCAN_SPECS[key]
    rng = random.Random(spec["seed"])
    me, source_material = scan_bmesh(untouched=True)
    shield_emblem(me, rng)
    name = "Bellwood_Guardian_" + key.capitalize()
    me.name = name
    lion = bpy.data.objects.new(name, me)
    collection.objects.link(lion)
    frame = Matrix.Rotation(-math.pi / 2, 4, "Z")  # scan faces -X; the guardian faces +Y
    if spec["side"] < 0:
        frame = Matrix.Diagonal((-1, 1, 1, 1)) @ frame
    me.transform(Matrix.Scale(spec["height"] / SCAN_HEIGHT, 4) @ frame)
    if spec["side"] < 0:
        me.flip_normals()  # the mirror turned the winding inside out
    co, _ = mesh_arrays(me)
    slab = co[co[:, 2] < .25]
    span = slab[:, :2].max(0) - slab[:, :2].min(0)
    cx, cy = (slab[:, :2].max(0) + slab[:, :2].min(0)) / 2
    W, D = span[0] + 3.6, span[1] + 3.4  # about 1.7 studs of seat around the scan's slab
    plinth_b, seat = build_plinth(spec, rng, W, D)
    first_tuft = moss_tufts(plinth_b, rng, 7)
    plinth = plinth_b.mesh_object(name + "_Plinth", collection)
    tuft = np.zeros(len(plinth.data.vertices), np.float32)
    tuft[first_tuft:] = 1
    plinth.data.attributes.new("Tuft", "FLOAT", "POINT").data.foreach_set("value", tuft)
    for p in plinth.data.polygons:
        p.use_smooth = True
    recalc_normals(plinth.data)
    me.transform(Matrix.Translation((-cx, -cy, seat - .03)))  # slab flush on the seat
    turn = Matrix.Rotation(spec["side"] * spec["turn"], 4, "Z")  # a few degrees more toward the stair
    for ob in (lion, plinth):
        ob.data.transform(turn)
        ob.data.update()
    print(f"FOOTPRINT {key}: slab {span[0]:.1f} x {span[1]:.1f}, plinth {W:.1f} x {D:.1f}, seat {seat:.2f}")
    lion["source_material"] = source_material.name
    return (lion, plinth), spec, rng


# ---------------------------------------------------------------- plinth

def build_plinth(spec, rng, W, D):
    """Coursed sumeru pedestal: footing courses, moulding, articulated waist, petal band, seat.
    W and D are the footing's x (across) and y (front-back) sizes."""
    b = Builder()
    z = 0.0
    erosion_lo = .16 if spec["side"] < 0 else .12

    def course(width, depth, height, z0, length, erosion, stagger):
        # individual blocks around the perimeter, with a hidden core
        b.add_bm(stone_block((width - 1.2, depth - 1.2, height - .05), Matrix.Translation((0, 0, z0 + height / 2)),
                             rng, radius=.1, erosion=0, chips=0, cut=3.0))
        for axis, span, other in (("x", width, depth), ("y", depth, width)):
            for sign in (-1, 1):
                pos = -span / 2 + stagger
                while pos < span / 2 - .6:
                    L = min(rng.uniform(length * .7, length * 1.3), span / 2 - pos)
                    if L < 1.0:
                        break
                    thick = rng.uniform(1.6, 2.2)
                    c = pos + L / 2
                    lean = rng.uniform(-.015, .015)
                    if axis == "x":
                        m = Matrix.Translation((c, sign * (other / 2 - thick / 2 + rng.uniform(-.06, .06)),
                                                z0 + height / 2)) @ Matrix.Rotation(lean, 4, "X")
                        size = (L - .14, thick, height - .12)
                    else:
                        m = Matrix.Translation((sign * (other / 2 - thick / 2 + rng.uniform(-.06, .06)), c,
                                                z0 + height / 2)) @ Matrix.Rotation(lean, 4, "Y")
                        size = (thick, L - .14, height - .12)
                    b.add_bm(stone_block(size, m, rng, radius=rng.uniform(.2, .42),
                                         erosion=erosion * rng.uniform(.6, 1.4), chips=rng.choice((0, 1, 1, 2))))
                    pos += L

    course(W, D, 2.5, z, 4.6, erosion_lo, 0.0)
    z += 2.5
    course(W - .7, D - .7, 2.2, z, 5.4, erosion_lo * .8, 1.6)
    z += 2.2
    # projecting moulding with a chamfered nose
    b.add_bm(stone_block((W + .5, D + .5, .85), Matrix.Translation((0, 0, z + .42)), rng, radius=.32,
                         erosion=.08, chips=3, cut=.8))
    z += .85
    b.ledges = [((W + .5) / 2, (D + .5) / 2, z)]
    # waist: recessed core, proud corner posts, framed panels with carved roundels
    waist_h, cw, cd = 3.5, W - 3.2, D - 3.2
    b.add_bm(stone_block((cw, cd, waist_h), Matrix.Translation((0, 0, z + waist_h / 2)), rng, radius=.15,
                         erosion=.06, chips=0, cut=.9))
    for sx in (-1, 1):
        for sy in (-1, 1):
            m = Matrix.Translation((sx * (cw / 2 - .1), sy * (cd / 2 - .1), z + waist_h / 2))
            b.add_bm(stone_block((1.7, 1.7, waist_h), m, rng, radius=.25, erosion=.09, chips=1, cut=.5))
    frames = [("y", 1, cw), ("y", -1, cw), ("x", 1, cd), ("x", -1, cd)]
    for axis, sign, span in frames:
        inner = span - 3.4
        for k, (u, v, su, sv) in enumerate(((0, waist_h / 2 - .35, inner, .34), (0, -waist_h / 2 + .35, inner, .34),
                                             (-inner / 2, 0, .34, waist_h - .4), (inner / 2, 0, .34, waist_h - .4))):
            if axis == "y":
                m = Matrix.Translation((u, sign * (cd / 2 + .08), z + waist_h / 2 + v))
                size = (su, .4, sv)
            else:
                m = Matrix.Translation((sign * (cw / 2 + .08), u, z + waist_h / 2 + v))
                size = (.4, su, sv)
            b.add_bm(stone_block(size, m, rng, radius=.1, erosion=.03, chips=0, cut=.6))
        # carved roundels: the front carries the guardian's emblem, the sides the other motif
        own = spec["support"] == "ball"
        motif = own if (axis == "y" and sign > 0) else not own
        if axis == "y":
            centres = [(0, sign * (cd / 2 + .02))] if sign > 0 else []
        else:
            centres = [(sign * (cw / 2 + .02), y) for y in (-cd / 4, cd / 4)]
        for cx, cy in centres:
            normal = (0, sign, 0) if axis == "y" else (sign, 0, 0)
            m = frame_from(normal, (cx, cy, z + waist_h / 2))
            if motif:
                wheel_relief(b, m, 1.25, .28, rng=rng)
            else:
                lotus_relief(b, m, 1.25, .26)
    z += waist_h
    # upturned lotus petal band
    b.add_bm(stone_block((W - 1.0, D - 1.0, 1.0), Matrix.Translation((0, 0, z + .5)), rng, radius=.3,
                         erosion=.05, chips=1, cut=.9))
    pw, pd = W - 1.0, D - 1.0
    perim = 2 * (pw + pd)
    count = int(perim / 1.45)
    for k in range(count):
        s = (k + .5) / count * perim
        if s < pw:
            p, out = Vector((-pw / 2 + s, -pd / 2, 0)), Vector((0, -1, 0))
        elif s < pw + pd:
            p, out = Vector((pw / 2, -pd / 2 + s - pw, 0)), Vector((1, 0, 0))
        elif s < 2 * pw + pd:
            p, out = Vector((pw / 2 - (s - pw - pd), pd / 2, 0)), Vector((0, 1, 0))
        else:
            p, out = Vector((-pw / 2, pd / 2 - (s - 2 * pw - pd), 0)), Vector((-1, 0, 0))
        base = p + out * .05 + Vector((0, 0, z + .05))
        b.add_bm(petal(base, out * .45 + Vector((0, 0, 1)), out, .95, 1.25, .26, -.1))
    z += 1.0
    seat_h = .9
    b.add_bm(stone_block((W - .6, D - .6, seat_h), Matrix.Translation((0, 0, z + seat_h / 2)), rng, radius=.3,
                         erosion=.07, chips=4, cut=.7))
    z += seat_h
    b.ledges.append(((W - .6) / 2, (D - .6) / 2, z))
    return b, z


def moss_tufts(b, rng, count):
    """Moss cushions over the ledge lips, each trailing a fringe of drooping tapered strands.
    Returns the first vertex index of the tufts so the masks can mark them as moss."""
    first = len(b.verts)
    for _ in range(count):
        hx, hy, z = rng.choice(b.ledges)
        face = rng.choice(("front", "front", "left", "right"))  # the back faces the terrace and stays bare
        if face == "front":
            p, out, along = Vector((rng.uniform(-.8, .8) * hx, hy, z)), Vector((0, 1, 0)), Vector((1, 0, 0))
        else:
            sx = 1 if face == "right" else -1
            p, out, along = Vector((sx * hx, rng.uniform(-.8, .8) * hy, z)), Vector((sx, 0, 0)), Vector((0, 1, 0))
        spread = rng.uniform(.35, 1.3)
        pad = bmesh.new()
        bmesh.ops.create_icosphere(pad, subdivisions=2, radius=1)
        for v in pad.verts:
            v.co *= 1 + .25 * (rng.random() - .5)
        axes = Matrix((along * spread * 1.15, out * .55, Vector((0, 0, .22)))).transposed().to_4x4()
        b.add_bm(pad, Matrix.Translation(p + out * .02 + Vector((0, 0, .04))) @ axes)
        for _ in range(rng.randint(3, 13)):
            u = rng.uniform(-1, 1)
            root = p + along * u * spread + out * rng.uniform(.03, .35) - Vector((0, 0, rng.uniform(.04, .2)))
            length = rng.uniform(.25, 2.4) * (1.1 - .5 * abs(u)) * rng.choice((.5, 1, 1, 1.3))
            width = rng.uniform(.03, .08)
            sway = along * rng.uniform(-.25, .25)
            rings = []
            for k in range(7):
                t = k / 6
                c = root + out * (.16 * math.sin(math.pi * t * .7)) - Vector((0, 0, length * t)) + sway * t * t
                r = width * (1 - .85 * t)
                rings.append([c + (along * math.cos(a) + out * math.sin(a)) * r
                              for a in (j * math.pi / 2 for j in range(4))])
            tip = root - Vector((0, 0, length * 1.04)) + sway + out * .13
            verts = [v for ring in rings for v in ring] + [tip]
            faces = [(k * 4 + j, k * 4 + (j + 1) % 4, (k + 1) * 4 + (j + 1) % 4, (k + 1) * 4 + j)
                     for k in range(6) for j in range(4)]
            faces += [(24 + j, 24 + (j + 1) % 4, 28) for j in range(4)] + [(3, 2, 1, 0)]
            b.add(verts, faces)
    return first


# ---------------------------------------------------------------- weathering and materials

def weathering(ob, spec, rng, bake_with=(), gain=1.0, joints=.5):
    """Weather attribute: R grime (baked AO), G moss, B worn edges, A lichen. Masks only; no geometry moves."""
    me = ob.data
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.world.light_settings.distance = 2.6
    attr = me.color_attributes.new("AO", "FLOAT_COLOR", "POINT")
    me.color_attributes.active_color = attr
    hidden = {o.name: o.hide_render for o in bpy.data.objects}
    for o in bpy.data.objects:
        o.select_set(o == ob)
        o.hide_render = o not in (ob, *bake_with)
    bpy.context.view_layer.objects.active = ob
    scene.render.bake.target = "VERTEX_COLORS"
    bpy.ops.object.bake(type="AO")
    for name, flag in hidden.items():
        bpy.data.objects[name].hide_render = flag
    ao = np.empty(len(me.vertices) * 4)
    attr.data.foreach_get("color", ao)
    ao = ao.reshape(-1, 4)[:, 0]
    co, edges = mesh_arrays(me)
    nr = vertex_normals(me, co)
    # convexity from neighbours, smoothed: edges and lips are convex
    conv = np.zeros(len(co))
    cnt = np.zeros(len(co))
    for a, b_ in ((0, 1), (1, 0)):
        i, j = edges[:, a], edges[:, b_]
        d = co[j] - co[i]
        d /= np.linalg.norm(d, axis=1)[:, None] + 1e-9
        np.add.at(conv, i, -(nr[i] * d).sum(1))
        np.add.at(cnt, i, 1)
    conv /= np.maximum(cnt, 1)
    conv = laplacian(conv[:, None], edges, np.ones(len(co)), 3)[:, 0]
    grime = np.clip((1 - ao) * 1.35, 0, 1)
    seed = spec["seed"] % 89
    patch = np.array([fbm(p, .22, 3, seed) for p in co])
    up = np.clip(nr[:, 2], 0, 1) ** 1.3
    zrel = (co[:, 2] - co[:, 2].min()) / (np.ptp(co[:, 2]) + 1e-6)
    moss = np.clip(gain * spec["moss"] * (up * (.55 + .8 * grime) + joints * grime * (1 - .5 * zrel))
                   * np.clip(.55 + 1.6 * patch, 0, 1.3) - .12, 0, 1)
    wear = np.clip(conv * 2.6 - .1, 0, 1) * spec["wear"] * (1 - moss)
    fr = me.attributes.get("Fracture")
    if fr:  # old breaks: paler, less grimed, moss only starting in the cracks
        f = np.empty(len(co), np.float32)
        fr.data.foreach_get("value", f)
        moss = moss * (1 - f) + f * np.clip(grime * spec["moss"] * .45 - .08, 0, .35)
        grime = grime * (1 - .5 * f)
        wear = wear * (1 - f) + f * .72
    tuft = me.attributes.get("Tuft")
    if tuft:  # hanging moss is moss through and through
        t = np.empty(len(co), np.float32)
        tuft.data.foreach_get("value", t)
        moss, wear = np.maximum(moss, t), wear * (1 - t)
    print(f"WEATHER {ob.name}: grime {grime.mean():.2f}, moss {moss.mean():.2f} (>{.3}: {(moss > .3).mean():.0%}), "
          f"wear {wear.mean():.2f}")
    spots = np.array([fbm(p, .6, 2, seed + 11) for p in co])
    lichen = np.clip(spec.get("lichen", 0) * (1 - grime) * np.clip(nr[:, 2] + .4, 0, 1) * (.3 + 1.4 * spots), 0, 1)
    col = np.stack([grime, moss, wear, lichen], 1).astype(np.float32)
    me.color_attributes.remove(attr)
    weather = me.color_attributes.new("Weather", "FLOAT_COLOR", "POINT")
    weather.data.foreach_set("color", col.ravel())
    me.color_attributes.active_color = weather
    me.color_attributes.render_color_index = me.color_attributes.active_color_index


def granite(name, tint):
    """Dark grey-green granite: flecked grain, water stains running down from the ledges, grime in the
    joints (R), pale fresh stone on chipped arrises (B) and broken-edged moss (G)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    N, L = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in N if n.type == "BSDF_PRINCIPLED")
    attr = N.new("ShaderNodeAttribute")
    attr.attribute_name = "Weather"
    sep = N.new("ShaderNodeSeparateColor")
    L.new(attr.outputs["Color"], sep.inputs[0])
    obj = N.new("ShaderNodeTexCoord").outputs["Object"]
    geo = N.new("ShaderNodeNewGeometry")

    def noise(scale, detail, vector=obj):
        n = N.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        L.new(vector, n.inputs["Vector"])
        return n.outputs["Fac"]

    def ramp(fac, lo, hi, c0=(0, 0, 0, 1), c1=(1, 1, 1, 1)):
        r = N.new("ShaderNodeValToRGB")
        r.color_ramp.elements[0].position, r.color_ramp.elements[1].position = lo, hi
        r.color_ramp.elements[0].color, r.color_ramp.elements[1].color = c0, c1
        L.new(fac, r.inputs[0])
        return r.outputs[0]

    def math_(op, a, b):
        m = N.new("ShaderNodeMath")
        m.operation = op
        for i, v in enumerate((a, b)):
            if isinstance(v, (int, float)):
                m.inputs[i].default_value = v
            else:
                L.new(v, m.inputs[i])
        return m.outputs[0]

    def mix(a, b_, factor, blend="MIX"):
        m = N.new("ShaderNodeMix")
        m.data_type, m.blend_type = "RGBA", blend
        L.new(factor, m.inputs["Factor"])
        for i, v in ((6, a), (7, b_)):
            if isinstance(v, tuple):
                m.inputs[i].default_value = v
            else:
                L.new(v, m.inputs[i])
        return m.outputs[2]

    c = ramp(noise(.9, 8), 0, 1, (tint[0] * .7, tint[1] * .7, tint[2] * .7, 1), (*tint, 1))
    flecks = ramp(noise(38, 2), .62, .7)
    c = mix(c, (tint[0] * 1.9, tint[1] * 1.85, tint[2] * 1.8, 1), math_("MULTIPLY", flecks, .35))
    # water stains: noise stretched down the faces, strongest on walls, fading toward the footing
    stretch = N.new("ShaderNodeMapping")
    stretch.inputs["Scale"].default_value = (2.6, 2.6, .09)
    L.new(obj, stretch.inputs["Vector"])
    wall = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Normal"], wall.inputs[0])
    streak = math_("MULTIPLY", ramp(noise(3.0, 3, stretch.outputs[0]), .48, .66),
                   math_("SUBTRACT", 1.0, math_("ABSOLUTE", wall.outputs["Z"], 0)))
    height = N.new("ShaderNodeSeparateXYZ")
    L.new(obj, height.inputs[0])
    streak = math_("MULTIPLY", streak, math_("ADD", math_("MULTIPLY", height.outputs["Z"], .1), .2))
    c = mix(c, (.22, .27, .20, 1), math_("MINIMUM", streak, 1.0), "MULTIPLY")
    c = mix(c, (.34, .38, .29, 1), sep.outputs[0], "MULTIPLY")
    chips = math_("MINIMUM", math_("MULTIPLY", sep.outputs[2], math_("ADD", noise(11, 3), .55)), 1.0)
    c = mix(c, (.19, .195, .18, 1), chips)  # fresh stone on chipped arrises, a step lighter, not white
    # moss: the mask decides where, a fine noise breaks its edge into clumps
    clump = noise(7.5, 5)
    moss = ramp(math_("MULTIPLY", sep.outputs[1], math_("ADD", clump, .45)), .3, .55)
    mcol = ramp(noise(16, 4), .25, .8, (.068, .078, .026, 1), (.14, .135, .048, 1))
    mcol = mix(mcol, (.045, .05, .018, 1), ramp(sep.outputs[0], .6, .95))  # #3c3f24 in the joints
    m_f = math_("ADD", moss, 0)  # colour to scalar
    L.new(mix(c, mcol, m_f), bsdf.inputs["Base Color"])
    rough = math_("ADD", math_("MULTIPLY", chips, -.22), .86)
    L.new(math_("MINIMUM", math_("ADD", rough, math_("MULTIPLY", m_f, .14)), 1.0), bsdf.inputs["Roughness"])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = .4
    bump.inputs["Distance"].default_value = .05
    L.new(math_("ADD", noise(14, 6), math_("MULTIPLY", m_f, math_("MULTIPLY", noise(45, 3), 1.5))), bump.inputs["Height"])
    L.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# ---------------------------------------------------------------- assembly

def recalc_normals(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()


def rest(me, target, up, rng):
    """Turn a fallen piece so its old carved face looks along `up`, then sit it on `target`."""
    co, _ = mesh_arrays(me)
    mask = me.attributes["Fracture"].data
    outer = Vector()
    for p in me.polygons:
        if not any(mask[i].value for i in p.vertices):
            outer += p.normal * p.area
    centre = Vector(co.mean(0))
    turn = outer.normalized().rotation_difference(Vector(up).normalized()).to_matrix().to_4x4()
    spin = Matrix.Rotation(rng.uniform(-.6, .6), 4, Vector(up).normalized())
    me.transform(spin @ turn @ Matrix.Translation(-centre))
    co, _ = mesh_arrays(me)
    lo = co.min(0)
    me.transform(Matrix.Translation(Vector(target) - Vector((0, 0, lo[2] + .1))))


def build_guardian(key, collection):
    spec = SPECS[key]
    rng = random.Random(spec["seed"])
    me, co, mane, face, marks = sculpt_lion(spec, rng)
    lion_b = dress_lion(spec, me, co, mane, face, marks, rng)
    bpy.data.meshes.remove(me)
    whole = bpy.data.meshes.new("whole")
    whole.from_pydata(lion_b.verts, [], lion_b.faces)
    whole.validate(clean_customdata=False)
    for p in whole.polygons:
        p.use_smooth = True
    recalc_normals(whole)
    co, _ = mesh_arrays(whole)
    scale = spec["height"] / np.ptp(co[:, 2])  # measured intact, so the break does not grow the body
    zmin = co[:, 2].min()
    broken, fragments = break_head(whole, spec, marks, rng)
    bpy.data.meshes.remove(whole)
    name = "Bellwood_Guardian_" + key.capitalize()
    lion = bpy.data.objects.new(name, broken)
    collection.objects.link(lion)

    # scan frame (faces -X) -> guardian frame (faces +Y); West is the mirror image
    frame = Matrix.Rotation(-math.pi / 2, 4, "Z")
    if spec["side"] < 0:
        frame = Matrix.Diagonal((-1, 1, 1, 1)) @ frame
    linear = Matrix.Scale(scale, 4) @ frame @ Matrix.Translation((0, 0, -zmin))
    for m in [broken] + fragments:
        m.transform(linear)
        if spec["side"] < 0:
            m.flip_normals()
        recalc_normals(m)
    co, _ = mesh_arrays(broken)
    feet = co[co[:, 2] < 1.2 * scale]
    span = feet[:, :2].max(0) - feet[:, :2].min(0)
    cx, cy = (feet[:, :2].max(0) + feet[:, :2].min(0)) / 2
    # the seat keeps about 1.2 studs of stone around the paws, tail and support
    W, D = max(15.0, span[0] + 3.4), span[1] + 3.0
    plinth_b, seat = build_plinth(spec, rng, W, D)
    plinth = plinth_b.mesh_object(name + "_Plinth", collection)
    broken.transform(Matrix.Translation((-cx, -cy, seat - .14)))
    broken.update()
    print(f"FOOTPRINT {key}: paws+support {span[0]:.1f} x {span[1]:.1f}, plinth {W:.1f} x {D:.1f}, seat {seat:.2f}")

    # fallen pieces lie on the terrace cap beside the plinth (z = 0), carved face up and outward
    stair = -spec["side"]  # local x toward the stair centre
    spots = [((stair * (W / 2 + 2.7), D * .12, 0), (stair * .5, .3, 1)),
             ((-stair * (W / 2 + 2.4), D * .28, 0), (-stair * .4, .5, 1)),
             ((stair * (W / 2 + 2.2), -D * .22, 0), (stair * .6, -.2, 1))]
    debris, fracture, smooth = Builder(), [], []
    for piece, (target, up) in zip(fragments, spots):
        rest(piece, target, up, rng)
        frac = np.empty(len(piece.vertices), np.float32)
        piece.attributes["Fracture"].data.foreach_get("value", frac)
        debris.add([v.co for v in piece.vertices], [p.vertices[:] for p in piece.polygons])
        fracture += list(frac)
        smooth += [p.use_smooth for p in piece.polygons]
        bpy.data.meshes.remove(piece)
    chips = rubble_mesh(rng, [(stair * (W / 2 + 2.5), D * .05, 0, 1.6, 9), (-stair * (W / 2 + 2.2), D * .3, 0, 1.2, 6),
                              (stair * (W / 2 - 1.2), D / 2 - 1.0, seat, .5, 5), (-stair * (W / 2 - 1.0), -D / 2 + 1.0, seat, .5, 4),
                              (0, D / 2 + 1.6, 0, 2.2, 7)])
    n_frag = len(debris.verts)
    debris.add(chips.verts, [f for f in chips.faces])
    rubble = debris.mesh_object(name + "_Rubble", collection)
    rme = rubble.data
    frac = np.array(fracture + [.7] * (len(rme.vertices) - n_frag), np.float32)
    rme.attributes.new("Fracture", "FLOAT", "POINT").data.foreach_set("value", frac)
    for p, flag in zip(rme.polygons, smooth + [False] * (len(rme.polygons) - len(smooth))):
        p.use_smooth = flag
    recalc_normals(rme)
    recalc_normals(plinth.data)
    for p in plinth.data.polygons:
        p.use_smooth = True
    return (lion, plinth, rubble), spec, rng


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def export(objs, path, colors="ACTIVE"):
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs)
    kw = dict(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True,
              export_yup=True)
    try:
        bpy.ops.export_scene.gltf(**kw, export_vertex_color=colors)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)


# ---------------------------------------------------------------- upload parts (split, never decimated)

PART_LIMIT = 18000


def split_faces(ob, groups):
    """One new object per (name, face mask). Faces are only shared out; none are removed or simplified."""
    parts = []
    for name, keep in groups:
        me = ob.data.copy()
        me.name = name
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep[f.index]], context="FACES")
        bm.to_mesh(me)
        bm.free()
        part = bpy.data.objects.new(name, me)
        part.matrix_world = ob.matrix_world.copy()
        ob.users_collection[0].objects.link(part)
        parts.append(part)
    assert sum(tris(o) for o in parts) == tris(ob), "a split must keep every triangle"
    assert all(tris(o) <= PART_LIMIT for o in parts), [tris(o) for o in parts]
    return parts


def split_lion(lion):
    """Base (slab, paws, haunches) and body (chest, mane, head), cut at the narrowest level that leaves
    both under the limit. The cut stays in the lower body, far below the face."""
    me = lion.data
    tri = np.array([len(p.vertices) - 2 for p in me.polygons])
    cz = np.empty(len(me.polygons) * 3)
    me.polygons.foreach_get("center", cz)
    cz = cz.reshape(-1, 3)[:, 2]
    loop_edge = np.empty(len(me.loops), int)
    me.loops.foreach_get("edge_index", loop_edge)
    loop_face = np.repeat(np.arange(len(me.polygons)), [p.loop_total for p in me.polygons])
    lo = np.full(len(me.edges), np.inf)
    hi = np.full(len(me.edges), -np.inf)
    np.minimum.at(lo, loop_edge, cz[loop_face])
    np.maximum.at(hi, loop_edge, cz[loop_face])
    top, height = cz.max(), np.ptp(cz)
    best = None
    for z in np.linspace(cz.min(), top - .45 * height, 400):
        below = tri[cz < z].sum()
        if below <= PART_LIMIT and tri.sum() - below <= PART_LIMIT:
            seam = int(((lo < z) & (hi >= z)).sum())
            if best is None or seam < best[0]:
                best = (seam, z)
    assert best, "no level splits the scan under the limit"
    print(f"LION SPLIT {lion.name}: z {best[1]:.2f} ({(best[1] - cz.min()) / height:.0%} up), seam {best[0]} edges")
    return split_faces(lion, [(lion.name + "_Base", cz < best[1]), (lion.name + "_Body", cz >= best[1])])


def split_plinth(plinth):
    """Lower and upper plinth along a joint between whole stones (each block is its own island)."""
    bm = bmesh.new()
    bm.from_mesh(plinth.data)
    bm.faces.ensure_lookup_table()
    island = np.full(len(bm.faces), -1)
    for f in bm.faces:
        if island[f.index] >= 0:
            continue
        stack_ = [f]
        island[f.index] = f.index
        while stack_:
            g = stack_.pop()
            for e in g.edges:
                for h in e.link_faces:
                    if island[h.index] < 0:
                        island[h.index] = f.index
                        stack_.append(h)
    tri = np.array([len(f.verts) - 2 for f in bm.faces])
    cz = np.array([f.calc_center_median().z for f in bm.faces])
    bm.free()
    ids, inv = np.unique(island, return_inverse=True)
    iz = np.bincount(inv, cz * tri) / np.bincount(inv, tri)  # tri-weighted island height
    cut = min(np.unique(iz), key=lambda z: max(tri[iz[inv] < z].sum(), tri[iz[inv] >= z].sum()))
    low = iz[inv] < cut
    return split_faces(plinth, [(plinth.name + "_Lower", low), (plinth.name + "_Upper", ~low)])


def bake_maps(ob, folder, size=2048):
    """Own UV layout, then albedo, roughness and tangent normal baked from the render material
    (masks and all) into 2048 maps; the part ends with one UV map and a plain PBR material."""
    me = ob.data
    scene = bpy.context.scene
    source_uv = me.uv_layers[0].name if me.uv_layers else None
    me.uv_layers.new(name="Bake")
    me.uv_layers.active = me.uv_layers["Bake"]
    for o in bpy.context.view_layer.objects:
        o.select_set(o == ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    me.uv_layers["Bake"].active_render = True
    work = me.materials[0].copy()
    me.materials[0] = work
    N, L = work.node_tree.nodes, work.node_tree.links
    for n in [n for n in N if n.type == "TEX_IMAGE" and not n.inputs[0].is_linked]:
        uv = N.new("ShaderNodeUVMap")  # scan textures keep reading their own layout
        uv.uv_map = source_uv
        L.new(uv.outputs[0], n.inputs[0])
    target = N.new("ShaderNodeTexImage")
    N.active = target
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.cycles.texture_limit_render = "2048"
    scene.render.bake.target = "IMAGE_TEXTURES"
    scene.render.bake.margin = 16
    maps = {}
    for kind, bake, colour in (("albedo", "DIFFUSE", "sRGB"), ("roughness", "ROUGHNESS", "Non-Color"),
                               ("normal", "NORMAL", "Non-Color")):
        img = bpy.data.images.new(f"{ob.name}_{kind}", size, size, alpha=False)
        img.colorspace_settings.name = colour
        target.image = img
        kw = dict(pass_filter={"COLOR"}) if bake == "DIFFUSE" else {}
        bpy.ops.object.bake(type=bake, **kw)
        img.filepath_raw = str(folder / f"{ob.name}_{kind}.png")
        img.file_format = "PNG"
        img.save()
        maps[kind] = img
    if source_uv:
        me.uv_layers.remove(me.uv_layers[source_uv])
    final = bpy.data.materials.new(ob.name)
    final.use_nodes = True
    N, L = final.node_tree.nodes, final.node_tree.links
    bsdf = next(n for n in N if n.type == "BSDF_PRINCIPLED")
    tex = {}
    for kind, img in maps.items():
        tex[kind] = N.new("ShaderNodeTexImage")
        tex[kind].image = img
    L.new(tex["albedo"].outputs["Color"], bsdf.inputs["Base Color"])
    L.new(tex["roughness"].outputs["Color"], bsdf.inputs["Roughness"])
    nmap = N.new("ShaderNodeNormalMap")
    L.new(tex["normal"].outputs["Color"], nmap.inputs["Color"])
    L.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    me.materials[0] = final
    bpy.data.materials.remove(work)


# ---------------------------------------------------------------- review renders (not exported)

STEP_RUN, STEP_RISE, START_Y, GUARDIAN_STEP = 2.35, .88, 257.0, 23  # mirrors stair_reference.py


def stair_profile(k):
    return 0.0, START_Y - STEP_RUN * k, .6 + STEP_RISE * k, 77 - 33 * k / 128


def guardian_location(side):
    _, y, z, width = stair_profile(GUARDIAN_STEP + (4 if side < 0 else 0))
    return Vector((side * (width / 2 + 19), y, z + 9.15)), side * .47


def context_scene(built):
    """Stair, rails, terrace pedestals and 5-stud travellers around the placed pair."""
    rng = random.Random(5)
    col = bpy.data.collections.new("Review context")
    bpy.context.scene.collection.children.link(col)
    b = Builder()
    for k in range(0, 64):
        _, y, z, w = stair_profile(k)
        b.add_bm(stone_block((w, STEP_RUN + .05, z), Matrix.Translation((0, y, z / 2)), rng, radius=.12,
                             erosion=.03, chips=0, cut=6.0))
        if k % 3 == 0:
            for sx in (-1, 1):
                b.add_bm(stone_block((1.2, 1.2, 3.8), Matrix.Translation((sx * (w / 2 - .6), y, z + 1.9)), rng,
                                     radius=.2, erosion=.05, chips=1, cut=1.0))
        if k % 3 == 0 and k + 3 < 64:
            _, y2, z2, w2 = stair_profile(k + 3)
            for sx in (-1, 1):
                a = Vector((sx * (w / 2 - .6), y, z + 3.4))
                c = Vector((sx * (w2 / 2 - .6), y2, z2 + 3.4))
                d = c - a
                m = (Matrix.Translation((a + c) / 2) @ d.to_track_quat("Y", "Z").to_matrix().to_4x4())
                b.add_bm(stone_block((.8, d.length, .7), m, rng, radius=.2, erosion=.04, chips=0, cut=2.0))
    for side in (-1, 1):
        loc, yaw = guardian_location(side)
        z = loc.z - 9.15
        b.add_bm(stone_block((27, 27, z + 8), Matrix.Translation((loc.x, loc.y, (z + 8) / 2)), rng,
                             radius=.5, erosion=.15, chips=2, cut=4.0))
        b.add_bm(stone_block((29.5, 29.5, 1.6), Matrix.Translation((loc.x, loc.y, z + 8.4)), rng,
                             radius=.35, erosion=.08, chips=3, cut=2.0))
    stair = b.mesh_object("Review stair", col)
    ground = bpy.data.meshes.new("ground")
    ground.from_pydata([(-400, -100, 0), (400, -100, 0), (400, 600, 0), (-400, 600, 0)], [], [(0, 1, 2, 3)])
    gob = bpy.data.objects.new("Review ground", ground)
    col.objects.link(gob)
    stone = bpy.data.materials.new("Review stair stone")
    stone.use_nodes = True
    bsdf = next(n for n in stone.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (.20, .20, .19, 1)
    bsdf.inputs["Roughness"].default_value = .9
    for o in (stair, gob):
        o.data.materials.append(stone)
    cloth = bpy.data.materials.new("Traveller")
    cloth.use_nodes = True
    next(n for n in cloth.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (.05, .05, .055, 1)
    for i, (k, x) in enumerate(((-6, 7.0), (5, 4.0), (21, 28.0), (25, -26.0))):
        _, y, z, _ = stair_profile(k)
        z = max(z, 0.0)
        t = Builder()
        t.add_bm(lathe([(0, 0), (.75, 0), (.6, 2.6), (.75, 3.4), (.35, 3.9), (0, 3.95)], 16, Matrix()))
        head = bmesh.new()
        bmesh.ops.create_uvsphere(head, u_segments=16, v_segments=10, radius=.42)
        t.add_bm(head, Matrix.Translation((0, 0, 4.25)))
        t.add_bm(lathe([(0, 0), (1.25, 0), (0, .55)], 20, Matrix.Translation((0, 0, 4.5))))
        ob = t.mesh_object(f"Traveller {i}", col)
        ob.location = (x, y, z)
        ob.data.materials.append(cloth)
    for key, (parts, spec, rng) in built.items():
        loc, yaw = guardian_location(spec["side"])
        for o in parts:
            o.matrix_world = Matrix.Translation(loc) @ Matrix.Rotation(yaw, 4, "Z")
    return col


def look(cam, eye, target, lens):
    cam.location = eye
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens


def setup_render(samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"  # Metal pushed the process past 4 GB; CPU stays inside the RAM budget
    scene.cycles.samples = samples
    scene.cycles.texture_limit_render = "2048"  # the scan maps blew RSS to 3.5 GB; Roblox gets 2048 maps anyway
    scene.cycles.use_auto_tile = True
    scene.cycles.tile_size = 512
    scene.cycles.use_denoising = True
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 90
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = scene.world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (.30, .34, .40, 1)
    bg.inputs["Strength"].default_value = .85
    sun = bpy.data.objects.new("Review key", bpy.data.lights.new("Review key", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(9)
    sun.data.color = (1, .95, .88)
    sun.rotation_euler = (math.radians(52), 0, math.radians(200))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Review camera", bpy.data.cameras.new("Review camera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.clip_end = 2000
    return scene, cam


def shot(scene, cam, path, eye, target, lens, res):
    look(cam, eye, target, lens)
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = int(os.environ.get("GUARD_PERCENT", 100))
    scene.render.filepath = str(path)
    bpy.context.view_layer.update()
    print("CAMERA", path.name, tuple(round(c, 1) for c in cam.matrix_world.translation),
          tuple(round(c, 2) for c in cam.matrix_world.to_euler()))
    bpy.ops.render.render(write_still=True)
    print("RENDERED", path)


def load_pixels(path):
    im = bpy.data.images.load(str(path))
    w, h = im.size
    px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(im)
    return px  # row 0 is the bottom


def fit(px, height):
    """Nearest-neighbour resize to a target height (enough for a comparison sheet)."""
    h, w = px.shape[:2]
    width = max(1, round(w * height / h))
    ys = (np.arange(height) * h / height).astype(int)
    xs = (np.arange(width) * w / width).astype(int)
    return px[ys][:, xs]


def crop_top(px, x0, y0, x1, y1):
    """Crop with image-style coordinates (origin top-left)."""
    h = px.shape[0]
    return px[h - y1:h - y0, x0:x1]


def save_pixels(px, path):
    h, w = px.shape[:2]
    im = bpy.data.images.new("sheet", w, h)
    im.pixels[:] = px.ravel()
    im.filepath_raw = str(path)
    im.file_format = "JPEG"
    im.save()
    bpy.data.images.remove(im)


def row(tiles, gap=8):
    h = max(t.shape[0] for t in tiles)
    out = np.zeros((h, sum(t.shape[1] for t in tiles) + gap * (len(tiles) - 1), 4), np.float32)
    out[..., 3] = 1
    x = 0
    for t in tiles:
        out[h - t.shape[0]:, x:x + t.shape[1]] = t
        x += t.shape[1] + gap
    return out


def stack(rows, gap=8):
    w = max(r.shape[1] for r in rows)
    out = np.zeros((sum(r.shape[0] for r in rows) + gap * (len(rows) - 1), w, 4), np.float32)
    out[..., 3] = 1
    y = out.shape[0]
    for r in rows:
        out[y - r.shape[0]:y, :r.shape[1]] = r
        y -= r.shape[0] + gap
    return out


def projected_box(scene, cam, objs, res):
    from bpy_extras.object_utils import world_to_camera_view
    pts = [world_to_camera_view(scene, cam, o.matrix_world @ Vector(c)) for o in objs for c in o.bound_box]
    xs = [p.x * res[0] for p in pts]
    ys = [(1 - p.y) * res[1] for p in pts]
    return int(max(0, min(xs))), int(max(0, min(ys))), int(min(res[0], max(xs))), int(min(res[1], max(ys)))


def render_all(built, out, shots, breaks=False, closes_only=False):
    """closes_only: just the two closes and the reference sheet; its stair crop is rendered into `out`."""
    shots.mkdir(parents=True, exist_ok=True)
    context_scene(built)
    scene, cam = setup_render(int(os.environ.get("GUARD_SAMPLES", 64)))
    west, east = guardian_location(-1)[0], guardian_location(1)[0]
    mid = (west + east) / 2
    portrait = (960, 1440)
    pct = int(os.environ.get("GUARD_PERCENT", 100)) / 100
    # lower stair: standing on the approach just below the first step, as in the creator's frame
    stair_path = (out if closes_only else shots) / "mac94_guardians_stair_view.jpg"
    shot(scene, cam, stair_path, Vector((0, 300, 5.2)), Vector((0, 200, 42)), 17, portrait)
    stair_boxes = {k: projected_box(scene, cam, [o for o in built[k][0] if "Rubble" not in o.name],
                                    (portrait[0] * pct, portrait[1] * pct)) for k in built}
    if not closes_only:
        shot(scene, cam, shots / "mac94_guardians_front.jpg", Vector((0, 276, 5.2)), Vector((0, 200, 36)), 20,
             (1600, 1000))
        shot(scene, cam, shots / "mac94_guardians_back.jpg", Vector((6, 128, 72)), mid + Vector((0, 4, 18)), 26,
             (1600, 1000))
        _, yr, zr, wr = stair_profile(12)
        shot(scene, cam, shots / "mac94_guardians_rail_view.jpg", Vector((-wr / 2 + 2.5, yr, zr + 4.6)),
             west + Vector((2, 0, 20)), 30, (1000, 1200))
    for key, loc in (("west", west), ("east", east)):
        side = -1 if key == "west" else 1
        eye = loc + Vector((-side * 35, 23, 28))
        shot(scene, cam, shots / f"mac94_guardian_{key}_close.jpg", eye, loc + Vector((0, 0, 22)), 40, (1200, 1200))
        if breaks:  # the break itself, from above the stump and slightly toward the stair
            shot(scene, cam, shots / f"mac94_guardian_{key}_break_close.jpg", loc + Vector((-side * 14, 13, 41)),
                 loc + Vector((0, -1, 28)), 50, (1200, 1200))
    # reference lions (the viewer's left is East) beside ours from the same lower-stair viewpoint
    ref = load_pixels(REFERENCE)
    ours = load_pixels(stair_path)
    h, w = ours.shape[:2]
    pad = 20
    rows = []
    for key, box in (("east", (0, 880, 250, 1320)), ("west", (770, 940, 1024, 1330))):
        x0, y0, x1, y1 = stair_boxes[key]
        mine = crop_top(ours, max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad))
        close = load_pixels(shots / f"mac94_guardian_{key}_close.jpg")
        tiles = [fit(crop_top(ref, *box), 560)] + ([fit(mine, 560)] if mine.size else []) + [fit(close, 560)]
        rows.append(row(tiles))
    save_pixels(stack(rows), shots / "mac94_guardians_vs_reference.jpg")


def clay_sheet(built, path):
    """Neutral workbench turnaround of each guardian on its own."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.show_cavity = True
    scene.render.image_settings.file_format = "PNG"
    cam = bpy.data.objects.new("Clay camera", bpy.data.cameras.new("Clay camera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    tiles = []
    for key, (parts, spec, rng) in built.items():
        saved = [o.matrix_world.copy() for o in parts]
        for o in parts:
            o.matrix_world = Matrix()
        for o in bpy.context.scene.objects:
            o.hide_render = o.type == "MESH" and o not in parts
        r = []
        for a in (0, 50, 130, 180, 270):
            t = math.radians(a)
            eye = Vector((math.sin(t) * 62, math.cos(t) * 62, 24))
            shot(scene, cam, path.with_name(f"clay_{key}_{a}.png"), eye, (0, 0, 17), 50, (560, 700))
            r.append(load_pixels(path.with_name(f"clay_{key}_{a}.png")))
        tiles.append(row(r))
        for o, m in zip(parts, saved):
            o.matrix_world = m
    for o in bpy.context.scene.objects:
        o.hide_render = False
    save_pixels(stack(tiles), path)
    bpy.data.objects.remove(cam)


def peak_mb():
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (1024 * 1024)  # macOS reports bytes


def main():
    mode = os.environ.get("GUARD_MODE", "scan")
    if mode not in ("scan", "broken"):
        raise SystemExit(f"GUARD_MODE must be scan or broken, not {mode!r}")
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new("World")
    col = bpy.data.collections.new("Bellwood guardians")
    scene.collection.children.link(col)
    built = {}
    for key in ("west", "east"):
        built[key] = (build_scan_guardian if mode == "scan" else build_guardian)(key, col)
    plain = {}
    for key, (parts, spec, rng) in built.items():
        tint = (.12, .13, .11) if key == "east" else (.11, .125, .105)  # dark grey-green, as on the reference
        stone = granite(f"Bellwood guardian granite ({key})", tint)
        for ob in parts:
            if mode == "scan" and ob is parts[0]:
                plain[key] = bpy.data.materials[ob["source_material"]]
                ob.data.materials.clear()
                ob.data.materials.append(scan_material(plain[key], key, spec["tint"]))
            else:
                ob.data.materials.append(stone)
            heavy = mode == "scan" and ob is not parts[0]  # the plinth carries the reference's thick joint moss
            weathering(ob, spec, rng, bake_with=parts, **(dict(gain=1.5, joints=1.5) if heavy else {}))
    for key, (parts, spec, rng) in built.items():
        lion = parts[0]
        if mode == "scan":  # the GLB carries the scan's plain albedo and normal map; masks ride in COLOR_0
            render_mat = lion.data.materials[0]
            lion.data.materials[0] = plain[key]
        export(parts, OUT / f"bellwood_guardian_{key}.glb")
        if mode == "scan":
            lion.data.materials[0] = render_mat
        print(f"GUARDIAN {key} ({mode}): " + ", ".join(f"{o.name} {tris(o)}" for o in parts)
              + f"; GLB total {sum(tris(o) for o in parts)} tris; statue height {lion.dimensions.z:.2f}")
    if mode == "scan" and os.environ.get("GUARD_PARTS", "1") != "0":
        folder = OUT / "textures"
        folder.mkdir(exist_ok=True)
        for key, (parts, spec, rng) in list(built.items()):
            pieces = split_lion(parts[0]) + split_plinth(parts[1])
            for o in pieces:
                bake_maps(o, folder)
            export(pieces, OUT / f"bellwood_guardian_{key}_parts.glb", colors="NONE")
            for o in parts:  # the whole meshes stay in the .blend; the renders show the shipped parts
                o.hide_render = True
            built[key] = (pieces, spec, rng)
            print(f"PARTS {key}: " + ", ".join(f"{o.name} {tris(o)}" for o in pieces) + f"; peak {peak_mb():.0f} MB")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"bellwood_guardians{'' if mode == 'scan' else '_broken'}.blend"))
    if os.environ.get("GUARD_CLAY") == "1":
        clay_sheet(built, OUT / "clay_sheet.jpg")
    if os.environ.get("GUARD_RENDER", "1") != "0":
        render_all(built, OUT, SHOTS, breaks=(mode == "broken"), closes_only=os.environ.get("GUARD_SHOTS") == "closes")
    print(f"PEAK_RSS_MB {peak_mb():.0f}")


if __name__ == "__main__":
    main()

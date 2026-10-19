"""Regalia and overgrowth for the Veiled Ascetic (imported by build_titan.py).

crown()   angular Elden-Ring-style spired crown seated on the hood
halo()    broken stone halo behind the head
swords()  two fallen stone greatswords at her right side
roots()   pale roots that crawl up and coil around the figure (surface walker on a BVH)
canopy()  dead pale tree rising behind her, branches arching over the crown
leaves()  crimson leaf cards on the branch tips and strewn over robe and ground
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

rnd = random.Random(23)
Z = Vector((0, 0, 1))


def _obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _prism(bm, base, apex, half_w, half_d, side, depth_dir):
    """Faceted blade: diamond cross-section tapering from base to apex."""
    corners = [base + side * half_w, base + depth_dir * half_d, base - side * half_w, base - depth_dir * half_d]
    vs = [bm.verts.new(c) for c in corners]
    tip = bm.verts.new(apex)
    for i in range(4):
        bm.faces.new((vs[i], vs[(i + 1) % 4], tip))
    bm.faces.new(list(reversed(vs)))


def crown(head_c):
    """Band of angular plates with a fan of tall blades, tallest at the centre front."""
    bm = bmesh.new()
    c = head_c + Vector((0, -0.01, 0.07))
    rx, ry, n = 0.112, 0.124, 28
    ring_lo, ring_hi = [], []
    for j in range(n):
        a = 2 * math.pi * j / n - math.pi / 2
        p = Vector((math.cos(a) * rx, math.sin(a) * ry, 0))
        ring_lo.append(bm.verts.new(c + p * 1.0 + Vector((0, 0, -0.012))))
        ring_hi.append(bm.verts.new(c + p * 1.06 + Vector((0, 0, 0.018 + 0.01 * (j % 2)))))
    for j in range(n):
        k = (j + 1) % n
        bm.faces.new((ring_lo[j], ring_lo[k], ring_hi[k], ring_hi[j]))
    blades = 9
    for i in range(blades):
        u = (i / (blades - 1)) * 2 - 1                      # -1..1 across the front arc
        a = -math.pi / 2 + u * math.radians(100)
        out = Vector((math.cos(a), math.sin(a), 0))
        base = c + Vector((out.x * rx * 1.05, out.y * ry * 1.05, 0.02))
        h = 0.09 + 0.2 * (1 - abs(u)) ** 1.8 + (0.025 if i % 2 == 0 else 0)
        apex = base + Z * h + out * (0.015 + 0.06 * abs(u))
        side = Z.cross(out).normalized()
        _prism(bm, base, apex, 0.006 + 0.004 * (1 - abs(u)), 0.004, side, out)
    obj = _obj("TitanCrown", bm)
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.0015
    sol = obj.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.008
    return obj


def halo(head_c):
    """Broken ring behind the head with radiating spines; a fragment hangs loose."""
    bm = bmesh.new()
    c = head_c + Vector((0, 0.16, 0.08))
    R, r, segs, sides = 0.3, 0.011, 64, 6

    def arc(a0, a1):
        rings = []
        steps = max(2, int(segs * (a1 - a0) / (2 * math.pi)))
        for s in range(steps + 1):
            a = a0 + (a1 - a0) * s / steps
            p = c + Vector((math.sin(a) * R, 0, math.cos(a) * R))
            radial = (p - c).normalized()
            ring = []
            for k in range(sides):
                t = 2 * math.pi * k / sides
                ring.append(bm.verts.new(p + radial * math.cos(t) * r + Vector((0, math.sin(t) * r * 1.4, 0))))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for k in range(sides):
                bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
        for ring in (rings[0], rings[-1]):
            bm.faces.new(ring)
    arc(0.45, 2 * math.pi - 0.2)
    arc(0.08, 0.3)
    for k in range(24):
        a = 0.6 + k * (2 * math.pi - 1.0) / 23
        d = Vector((math.sin(a), 0, math.cos(a)))
        base = c + d * (R + r * 0.5)
        L = 0.07 if k % 3 == 0 else 0.035
        side = Vector((math.cos(a), 0, -math.sin(a)))
        _prism(bm, base, base + d * L, 0.006, 0.004, side, Vector((0, 1, 0)))
    return _obj("TitanHalo", bm)


def _blade(bm, guard, tip, roll=0.0, chip=False):
    X = (tip - guard)
    L = X.length
    X.normalize()
    S = Z.cross(X).normalized()
    U = X.cross(S)
    S, U = S * math.cos(roll) + U * math.sin(roll), U * math.cos(roll) - S * math.sin(roll)
    prof = [(0.0, 0.034, 0.007), (L * 0.5, 0.03, 0.006), (L * 0.85, 0.022, 0.005), (L, 0.0, 0.0)]
    rings = []
    for k, (x, w, t) in enumerate(prof):
        ww = w * (0.7 if chip and k == 2 else 1.0)
        pts = [(ww, 0), (ww * 0.4, t), (-w * 0.4, t), (-w, 0), (-w * 0.4, -t), (ww * 0.4, -t)]
        rings.append([bm.verts.new(guard + X * x + S * a + U * b) for a, b in pts])
    for i in range(len(rings) - 1):
        for k in range(6):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % 6], rings[i + 1][(k + 1) % 6], rings[i + 1][k]))
    bm.faces.new(list(reversed(rings[0])))
    # crossguard swept toward the blade, grip, faceted pommel
    for sgn in (1, -1):
        _prism(bm, guard - X * 0.004, guard + S * sgn * 0.09 + X * 0.025, 0.011, 0.011, X, U)
    grip0, grip1 = guard - X * 0.004, guard - X * 0.11
    _prism(bm, grip1, grip0, 0.009, 0.009, S, U)
    _prism(bm, grip0, grip1, 0.009, 0.009, S, U)
    pom = guard - X * 0.125
    _prism(bm, pom, pom + X * 0.02, 0.017, 0.017, S, U)
    _prism(bm, pom, pom - X * 0.02, 0.017, 0.017, S, U)


def swords():
    bm = bmesh.new()
    _blade(bm, Vector((-0.42, -0.08, 0.016)), Vector((-0.58, -0.56, 0.012)), chip=True)
    _blade(bm, Vector((-0.6, 0.02, 0.045)), Vector((-0.36, -0.6, 0.01)), roll=0.25)
    return _obj("TitanSwords", bm)


# ------------------------------------------------------------------------------------------ roots
def statue_bvh(objs):
    bm = bmesh.new()
    for o in objs:
        tmp = bmesh.new()
        tmp.from_mesh(o.data)
        tmp.transform(o.matrix_world)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    return bvh


def crawl(bvh, start, steps, twist, pitch=0.85, step=0.012, offset=0.012, zmax=2.0):
    """Walks over the statue surface, climbing in a spiral (pitch = climb vs. wrap)."""
    loc, n, _, _ = bvh.find_nearest(start)
    p = loc + n * offset
    heading = None
    path = [p.copy()]
    for i in range(steps):
        loc, n, _, _ = bvh.find_nearest(p)
        if loc is None:
            break
        up_t = Z - n * Z.dot(n)
        if up_t.length < 1e-3:
            up_t = Vector((1, 0, 0)) - n * n.x
        up_t.normalize()
        side = n.cross(up_t).normalized() * twist
        want = (up_t * pitch + side * (1 - pitch)).normalized()
        want += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * 0.25
        heading = want if heading is None else (heading * 0.75 + want * 0.25)
        heading = (heading - n * heading.dot(n)).normalized()
        p = loc + n * offset + heading * step
        path.append(p.copy())
        if p.z > zmax:
            break
    return smooth(path, 3)


def smooth(path, passes):
    for _ in range(passes):
        path = [path[0]] + [(path[i - 1] + path[i] * 2 + path[i + 1]) / 4 for i in range(1, len(path) - 1)] + [path[-1]]
    return path


def tube(bm, uv, path, r0, r1, sides=6, every=2, tip=True):
    pts = path[::every] + ([path[-1]] if (len(path) - 1) % every else [])
    if len(pts) < 2:
        return
    rings, length = [], 0.0
    nrm = None
    for i, p in enumerate(pts):
        t = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
        t.normalize()
        if nrm is None:
            nrm = t.cross(Z if abs(t.z) < 0.9 else Vector((1, 0, 0))).normalized()
        nrm = (nrm - t * nrm.dot(t)).normalized()
        b = t.cross(nrm)
        f = i / (len(pts) - 1)
        r = r0 + (r1 - r0) * f
        if tip and i == len(pts) - 1:
            r = r1 * 0.15
        if i:
            length += (p - pts[i - 1]).length
        bump = 1 + 0.12 * math.sin(i * 1.7) * (1 - f)
        rings.append(([bm.verts.new(p + (nrm * math.cos(a) + b * math.sin(a)) * r * bump)
                       for a in (2 * math.pi * k / sides for k in range(sides))], length))
    circ = 2 * math.pi * r0
    for i in range(len(rings) - 1):
        (ra, la), (rb, lb) = rings[i], rings[i + 1]
        for k in range(sides):
            k2 = (k + 1) % sides
            f = bm.faces.new((ra[k], ra[k2], rb[k2], rb[k]))
            us = (k / sides, (k + 1) / sides, (k + 1) / sides, k / sides)
            vs = (la / circ * 0.35, la / circ * 0.35, lb / circ * 0.35, lb / circ * 0.35)
            for loop, u, v in zip(f.loops, us, vs):
                loop[uv].uv = (u, v)


def roots(statue_objs, head_c):
    bvh = statue_bvh(statue_objs)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    # Climbers: start on the robe hem / ground line and spiral up the body.
    seeds = [  # (start, twist, pitch, steps, r0)
        (Vector((0.25, 0.25, 0.02)), 1, 0.62, 140, 0.026),      # coils the waist, rises over left shoulder
        (Vector((-0.28, 0.22, 0.02)), -1, 0.6, 150, 0.024),     # coils the torso the other way
        (Vector((0.0, 0.32, 0.02)), 1, 0.8, 120, 0.03),         # straight up the spine to the hood
        (Vector((0.45, -0.15, 0.02)), -1, 0.7, 70, 0.02),       # over the left knee
        (Vector((-0.48, -0.1, 0.02)), 1, 0.7, 70, 0.02),        # over the right knee
        (Vector((0.2, 0.1, 0.5)), 1, 0.35, 90, 0.016),          # tight coil around the left arm
        (Vector((-0.2, 0.1, 0.5)), -1, 0.35, 90, 0.016),        # tight coil around the right arm
        (Vector((0.08, 0.15, 0.62)), -1, 0.55, 60, 0.012),      # thin root across the veiled brow
    ]
    paths = []
    for start, tw, pitch, steps, r0 in seeds:
        path = crawl(bvh, start, steps, tw, pitch, zmax=head_c.z + 0.16)
        tube(bm, uv, path, r0, r0 * 0.25)
        paths.append((path, r0))
        # rootlets peeling off the main root
        for _ in range(len(path) // 30):
            i = rnd.randrange(10, len(path) - 5)
            sub = crawl(bvh, path[i], 25, rnd.choice((-1, 1)), 0.3, zmax=head_c.z + 0.2)
            tube(bm, uv, sub, r0 * 0.4, r0 * 0.1, sides=5)
    # Ground roots sprawling from the statue out over the dais and sinking into it.
    for k in range(7):
        a = 2 * math.pi * k / 7 + rnd.uniform(-0.35, 0.35)
        d = Vector((math.cos(a), math.sin(a), 0))
        pts, p = [], Vector((d.x * 0.35, d.y * 0.32, 0.01))
        for s in range(rnd.randrange(22, 44)):
            p = p + (d + d.cross(Z) * math.sin(s * 0.35 + k) * 0.6).normalized() * 0.02
            p.z = 0.012 * math.sin(s * 0.5) + 0.004 - max(0.0, s - 18) * 0.003
            pts.append(p.copy())
        tube(bm, uv, smooth(pts, 2), rnd.uniform(0.02, 0.036), 0.006)
    obj = _obj("TitanRoots", bm)
    return obj, paths


def canopy(head_c):
    """Pale dead tree behind her: trunk rises from her back, branches fork over the crown."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    tips = []

    def branch(p, d, length, r, depth):
        pts = [p.copy()]
        q = p.copy()
        for s in range(12):
            d = (d + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.5, 0.6))) * 0.18).normalized()
            q = q + d * length / 12
            pts.append(q.copy())
        tube(bm, uv, pts, r, r * 0.6, sides=7 if depth < 2 else 5, every=1, tip=depth >= 3)
        if depth >= 3:
            tips.append(q)
            return
        for _ in range(2 if depth else 3):
            nd = (d + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 0.5))) * 0.9).normalized()
            if nd.z < -0.2:
                nd.z = -nd.z
            branch(q, nd, length * 0.7, r * 0.6, depth + 1)

    # gnarled S-curved trunk from behind her back, leaning over so the crown sits above her head
    trunk = []
    for s in range(17):
        f = s / 16
        trunk.append(Vector((0.04 * math.sin(f * 7.0), 0.36 + 0.1 * math.sin(f * math.pi) - 0.32 * f ** 2, 1.12 * f)))
    tube(bm, uv, trunk, 0.085, 0.045, sides=9, every=1, tip=False)
    top = trunk[-1]
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        branch(top, Vector((math.cos(a), math.sin(a) * 0.9 - 0.15, 0.35)).normalized(), 0.34, 0.034, 0)
    return _obj("TitanCanopy", bm), tips


def leaves(tips, rest_bvh):
    """Leaf cards: clusters on branch tips plus leaves lying on the robe and dais."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    def card(c, normal, size):
        t1 = normal.cross(Vector((0.3, 0.7, 0.1))).normalized()
        a = rnd.uniform(0, 2 * math.pi)
        t1 = (t1 * math.cos(a) + normal.cross(t1) * math.sin(a))
        t2 = normal.cross(t1)
        cell = rnd.randrange(9)
        u0, v0 = (cell % 3) / 3, (cell // 3) / 3
        vs = [bm.verts.new(c + (t1 * x + t2 * y) * size) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        f = bm.faces.new(vs)
        for loop, (x, y) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uv].uv = (u0 + x / 3, v0 + y / 3)

    for tip in tips:
        for _ in range(14):
            c = tip + Vector((rnd.gauss(0, 0.06), rnd.gauss(0, 0.06), rnd.gauss(0, 0.04)))
            n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized()
            card(c, n, rnd.uniform(0.022, 0.034))
    placed = 0
    while placed < 260:
        r, a = abs(rnd.gauss(0, 0.45)), rnd.uniform(0, 2 * math.pi)
        o = Vector((math.cos(a) * r, math.sin(a) * r - 0.05, 2.0))
        hit, n, _, _ = rest_bvh.ray_cast(o, Vector((0, 0, -1)))
        if hit is None:
            hit, n = Vector((o.x, o.y, 0.0)), Z
        if n.z < 0.5 or r > 1.1:
            continue
        card(hit + n * 0.004, n, rnd.uniform(0.016, 0.026))
        placed += 1
    return _obj("TitanLeaves", bm)

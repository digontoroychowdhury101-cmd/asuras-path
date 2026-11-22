"""Staging scene for the creator's stair-side Bellwood reference. Blender units = studs.

Camera convention: the portrait camera looks down -Y, so image-left is world +X.
Env knobs: VESP_RENDER_SAMPLES, VESP_TREE_VOXEL (bark union voxel size), VESP_TWIG_DEPTH, VESP_YAW (portrait turn
left, degrees), VESP_GLOW (gallery light per stud of width), VESP_HAZE, VESP_EXPOSURE,
VESP_VIEWS (comma list of portrait,fork,root).
"""

import math
from array import array
import os
from pathlib import Path
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
from mathutils.noise import noise

sys.path.insert(0, str(Path(__file__).resolve().parent))
import temple_preview as kit
from temple_preview import Hall, at, figures, light

RNG = random.Random(711)
OUT = Path(os.environ.get("VESP_STUDY_OUT", str(Path.cwd() / "work/sol-bellwood-v9")))
UP = Vector((0, 0, 1))
STEP_COUNT = 128
STEP_RUN, STEP_RISE = 2.35, .88
START_Y = 257.0
GUARDIAN_STEP = 23
VOXEL = float(os.environ.get("VESP_TREE_VOXEL", 1.0))
TWIG_DEPTH = int(os.environ.get("VESP_TWIG_DEPTH", 5))
CROWN_SQUASH = .79
THICK = 1.9  # branches at least this thick join the voxel-united bark body
SPINE = []  # (centre, tangent, side, up, radius, s, base_radius, path_id) for every bark ring
CONTACTS = []  # root points where a root grips stone after dropping over an edge
# (centre x, y, floor z, width, depth, column height, bays, crest)
TIERS = [(0, -82, 113, 189, 78, 51, 7, True), (16, -120, 191, 236, 89, 46, 9, False),
         (-14, -143, 269, 211, 81, 42, 7, False), (12, -171, 338, 195, 76, 39, 7, False),
         (23, -204, 402, 151, 63, 33, 5, False), (34, -237, 459, 109, 53, 28, 5, False)]
TRUNK = [Vector(p) for p in ((46, -126, 228), (34, -133, 291), (15, -148, 358), (5, -162, 423),
                             (16, -169, 477), (5, -169, 505))]


def circle(sides):
    return [(math.cos(i * math.tau / sides), math.sin(i * math.tau / sides)) for i in range(sides)]


BARK_PROFILE = [((1 + .09 * math.sin(a * 6)) * math.cos(a), (1 + .11 * math.cos(a * 7)) * math.sin(a))
                for a in [k * math.tau / 28 for k in range(28)]]


def organic_path(mesh, profile, controls, radii, record=None):
    """Vary cross-sections in a smoothly transported frame, including near-vertical runs."""
    spine, scales = [], []
    for i in range(len(controls) - 1):
        p0, p1, p2, p3 = (controls[min(len(controls) - 1, max(0, j))] for j in range(i - 1, i + 3))
        for k in range(7):
            t = k / 7
            u = t * t
            spine.append((2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * t * u) * .5)
            scales.append(radii[i] * (1 - t) + radii[i + 1] * t)
    spine.append(controls[-1])
    scales.append(radii[-1])
    rings, uvs = [], []
    side = None
    tangent_prev = Vector((0, 0, 1))
    base = max(radii)
    path_id = len(SPINE) + RNG.random()
    s = 0.0
    for i, (p, radius) in enumerate(zip(spine, scales)):
        tangent = spine[min(i + 1, len(spine) - 1)] - spine[max(0, i - 1)]
        tangent = tangent.normalized() if tangent.length > 1e-6 else tangent_prev
        tangent_prev = tangent
        if side is None:
            cross = Vector((0, 1, 0)) if abs(tangent.y) < .9 else Vector((1, 0, 0))
            side = tangent.cross(cross).normalized()
        else:
            side = (side - tangent * tangent.dot(side)).normalized()
        local_up = side.cross(tangent).normalized()
        if i:
            s += (p - spine[i - 1]).length
        if record is not None:
            record.append((p.copy(), tangent.copy(), side.copy(), local_up.copy(), radius, s, base, path_id))
        ring = []
        for k, (x, y) in enumerate(profile):
            phase = k * math.tau / len(profile)
            cambium = 1 + .063 * math.sin(phase * 5.0 + i * .16) + .034 * math.sin(phase * 9.0 - i * .19)
            ring.append(p + (side * x + local_up * y) * (radius * cambium))
        rings.append(ring)
        around = math.tau * base / mesh.studs  # grain runs along the limb, not along a world axis
        uvs.append([(around * k / len(profile), s / mesh.studs) for k in range(len(profile) + 1)])
    mesh.grid(rings, uvs, wrap=True)
    mesh.poly(rings[0])
    mesh.poly(list(reversed(rings[-1])))


def root_bundle(mesh, pts, rr):
    """Strangler-fig root: a core plus thinner strands that weave apart and rejoin, leaving real gaps."""
    count = max(3, min(6, round(rr[0] / 1.8)))
    organic_path(mesh, circle(10), pts, [r * .42 for r in rr], SPINE)  # children fork from this core
    along = [0.0]
    for a, b in zip(pts, pts[1:]):
        along.append(along[-1] + (b - a).length)
    for _ in range(count - 1):
        amp, wave, phase = RNG.uniform(.95, 1.7), RNG.uniform(11, 24), RNG.uniform(0, math.tau)
        lift, thin = RNG.uniform(-.1, .45), RNG.uniform(.26, .38)
        ctrl, radii = [], []
        for i, (p, r) in enumerate(zip(pts, rr)):
            t = pts[min(i + 1, len(pts) - 1)] - pts[max(0, i - 1)]
            t = t.normalized() if t.length > 1e-6 else UP
            side = t.cross(UP)
            side = side.normalized() if side.length > 1e-3 else Vector((1, 0, 0))
            normal = side.cross(t).normalized()
            if normal.z < 0:
                normal = -normal
            ramp = min(1.0, along[i] / 22)  # strands grow out of a fused crown, then net apart
            ctrl.append(p + (side * amp * math.sin(along[i] / wave + phase) + normal * lift) * r * ramp)
            radii.append(r * thin)
        organic_path(mesh, circle(8), ctrl, radii, SPINE)


def curved(pts, rr):
    """Catmull-Rom midpoints so twigs arc instead of bending at hard elbows."""
    out, radii = [], []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = pts[max(0, i - 1)], pts[i], pts[i + 1], pts[min(len(pts) - 1, i + 2)]
        out += [p1, (-p0 + 9 * p1 + 9 * p2 - p3) / 16]
        radii += [rr[i], (rr[i] + rr[i + 1]) * .5]
    return out + [pts[-1]], radii + [rr[-1]]


def merge(hall, piece, frame):
    for role, mesh in piece.meshes.items():
        hall.m(role).merge(mesh.bm, frame)


def stair_profile(k):
    """Centre x, tread centre y, tread top z and width of step k."""
    fraction = k / STEP_COUNT
    return (0.0, START_Y - STEP_RUN * k, .6 + STEP_RISE * k, 77 - 33 * fraction)


def guardian_base(side):
    _, y, z, width = stair_profile(GUARDIAN_STEP + (4 if side < 0 else 0))
    return side * (width / 2 + 19), y, z


def coursed_face(stone, x0, x1, y, top, courses, rng_depth=(.7, 1.6)):
    """Individual chipped blocks on a retaining-wall face that looks toward +Y."""
    for course in range(courses):
        x = x0 + RNG.uniform(0, 3)
        while x < x1 - 2:
            length = RNG.uniform(4.6, 8.4)
            height = RNG.uniform(2.1, 2.9)
            if RNG.random() > .06:  # missing blocks leave dark sockets
                mv = at(x + length / 2, y, top - 1.6 - course * 2.95) @ Matrix.Rotation(RNG.uniform(-.03, .03), 4, "Y")
                stone.box((0, 0, 0), (length - .35, RNG.uniform(*rng_depth), height), mv, bevel=RNG.uniform(.12, .5))
            x += length


def stonework(h):
    stair, moss, leaf = (h.m(role) for role in ("Masonry", "Moss", "MapleDeep"))
    for k in range(STEP_COUNT):
        x, y, z, width = stair_profile(k)
        if k % 4 == 0 and z > 3:
            stair.box((x, y - 1.5 * STEP_RUN, (z - 1.1) / 2), (width + 5, 4 * STEP_RUN + .1, z - 1.1))
        # Each tread is two or three worn slabs with uneven joints, tilt and chipped arrises.
        cuts = sorted(RNG.uniform(-.3, .3) * width for _ in range(RNG.choice((1, 2, 2))))
        edges = [-width / 2] + cuts + [width / 2]
        for a, b in zip(edges, edges[1:]):
            mv = at(x + (a + b) / 2, y, z - .62 + RNG.uniform(-.07, .05)) @ Matrix.Rotation(
                RNG.uniform(-.012, .012), 4, "Y") @ Matrix.Rotation(RNG.uniform(-.006, .006), 4, "Z")
            stair.box((0, 0, 0), (b - a - .22, STEP_RUN + .05, 1.25), mv, bevel=RNG.uniform(.08, .22))
        for _ in range(9):
            offset = RNG.uniform(-.49, .49) * width
            if abs(offset) < width * .22 and RNG.random() < .8:
                continue
            radius = RNG.uniform(.28, .81)
            material = moss if RNG.random() < .45 else leaf
            material.poly([Vector((x + offset + dx * radius, y + dy * radius, z + RNG.uniform(.01, .09)))
                           for dx, dy in ((-1, -.24), (.18, -.5), (1, 0), (.42, .5))], open_surface=True)
    # Full-height cheek walls, a stone balustrade and lantern posts on both sides.
    lamps = []
    for side in (-1, 1):
        rail_hi, rail_lo = [], []
        for k in range(0, STEP_COUNT, 3):
            x, y, z, w = stair_profile(k)
            edge = x + side * (w / 2 + 2.2)
            stair.box((edge, y - STEP_RUN, (z + 1.2) / 2), (4.6, 3 * STEP_RUN + .05, z + 1.2), bevel=.3)
            if k % 15 == 6:
                lamps.append(lantern(h, (edge, y, z + 1.2), .66))
            else:
                stair.box((edge, y, z + 3.3), (1.9, 1.9, 4.2), bevel=.22)
                stair.lathe([(1.25, 0), (1.05, .4), (.55, 1.0), (0, 1.55)], 8, at(edge, y, z + 5.4))
            rail_hi.append(Vector((edge, y, z + 4.9)))
            rail_lo.append(Vector((edge, y, z + 2.5)))
        for rail, size in ((rail_hi, .62), (rail_lo, .42)):
            stair.sweep([(-size, -size * .8), (size, -size * .8), (size, size * .8), (-size, size * .8)], rail)
    # Stepped retaining terraces flank the raised stair; the left ones carry the root fall.
    for side in (-1, 1):
        for j in range(7):
            k0 = j * 16
            x, y, z, w = stair_profile(k0)
            front = y + STEP_RUN / 2 + 3 + RNG.uniform(-2, 4)
            top = max(4.0, z - 3 - RNG.uniform(0, 5))
            inner = w / 2 + 4.4
            outer = inner + 78 + 16 * j + RNG.uniform(-10, 10)
            back = -60.0
            cx = side * (inner + outer) / 2
            stair.box((cx, (front + back) / 2, top / 2), (outer - inner, front - back, top), bevel=.9)
            stair.box((cx, front - 1.4, top + .6), (outer - inner + 1.2, 3.6, 1.2), bevel=.3)
            x0, x1 = (inner, outer) if side > 0 else (-outer, -inner)
            coursed_face(stair, x0, x1, front + .45, top - .6, min(6, int(top / 3)))
            for _ in range(int((outer - inner) / 9)):  # tumbled blocks and leaf litter on the terrace
                bx = side * RNG.uniform(inner + 4, outer - 4)
                by = RNG.uniform(front - 30, front - 4)
                mv = at(bx, by, top + 1) @ Matrix.Rotation(RNG.uniform(-.6, .6), 4, "Z") @ Matrix.Rotation(
                    RNG.uniform(-.25, .25), 4, "X")
                stair.box((0, 0, 0), (RNG.uniform(2.5, 6), RNG.uniform(2, 5), RNG.uniform(1.5, 3.5)), mv,
                          bevel=RNG.uniform(.2, .6))
                for _ in range(5):
                    lx, ly = bx + RNG.uniform(-6, 6), by + RNG.uniform(-6, 6)
                    (moss if RNG.random() < .5 else leaf).poly(
                        [Vector((lx + dx, ly + dy, top + .05)) for dx, dy in ((-1, -.3), (.2, -.6), (1, 0), (.4, .6))],
                        open_surface=True)
    # Lion plinths stand on the terraces beside the stair.
    for side in (-1, 1):
        px, y, z = guardian_base(side)
        stair.box((px, y, (z + 8) / 2), (27, 27, z + 8), bevel=.8)
        stair.box((px, y, z + 8.4), (29.5, 29.5, 1.6), bevel=.4)
        coursed_face(stair, px - 13, px + 13, y + 13.9, z + 6.5, 3)
        growth = random.Random(371 + side)
        for _ in range(42):
            xx = px + growth.uniform(-13.6, 13.6)
            tip = z + growth.uniform(1, 8.7)
            size = growth.uniform(.2, .9)
            moss.poly([Vector((xx + dx * size, y + 14.25 + growth.uniform(-.16, .15), tip + dz * size))
                       for dx, dz in ((.2, .7), (1, .2), (.7, -.85), (.1, -.25), (-.5, -1), (-1, 0))],
                      open_surface=True)
    # Threshold platform for the gate hall and the stepped cores that carry the upper tiers.
    x, y, z, w = stair_profile(STEP_COUNT - 1)
    stair.box((0, -84, z / 2), (250, 88, z), bevel=1.2)
    stair.box((0, -40.8, z + .2), (252, 3.4, 1.6), bevel=.35)
    coursed_face(stair, -125, -w / 2 - 5, -39.6, z - 2, 7)
    coursed_face(stair, w / 2 + 5, 125, -39.6, z - 2, 7)
    # The complex climbs a cliff: stepped masonry masses beside the tiers carry roots down toward the stair.
    for side, steps in ((1, ((-40, 112, 96, 250), (-96, 172, 92, 270), (-138, 232, 70, 250), (-176, 292, 40, 200))),
                        (-1, ((-40, 112, 96, 240), (-100, 168, 92, 250), (-150, 226, 70, 220)))):
        for front, top, inner, outer in steps:
            cx = side * (inner + outer) / 2
            stair.box((cx, (front - 300) / 2, top / 2), (outer - inner, front + 300, top), bevel=1.2)
            stair.box((cx, front - 1.2, top + .6), (outer - inner + 1.4, 3.4, 1.2), bevel=.3)
            x0, x1 = (inner, outer) if side > 0 else (-outer, -inner)
            coursed_face(stair, x0, x1, front + .45, top - .6, 9)
    for (tx, ty, tz, tw, td, th, bays, _), (_, _, pz, *_) in zip(TIERS[1:], TIERS):
        stair.box((tx, ty, (pz + tz) / 2), (tw * .66, td * .72, tz - pz + 4), bevel=1.0)
        stair.box((tx, ty, tz - .8), (tw * .86, td * .86, 2.2), bevel=.45)
    return lamps


GLOWS = []  # (x, y, z, width) warm light inside each gallery


def gallery_tier(h, half_x, half_y, bottom, top, bays, radius):
    """Open colonnade around a recessed hall: railings, bracket sets, lattice transoms and hanging lanterns."""
    wood, so, stone, gold, amber = (h.m(role) for role in ("Lacquer", "Soffit", "Masonry", "Gold", "Lantern"))
    height = top - bottom
    core = half_y * .45
    so.box((0, 0, bottom + height / 2), (half_x * 2 - 6, core * 2, height - 1), bevel=.3)
    stone.box((0, 0, bottom - .7), (half_x * 2 + 7, half_y * 2 + 7, 1.6), bevel=.3)
    so.box((0, 0, top - 1.6), (half_x * 2 + 2, half_y * 2 + 2, 1.4), bevel=.2)  # gallery ceiling
    columns = [-half_x + 2 * half_x * i / bays for i in range(bays + 1)]
    for sign in (-1, 1):
        y = sign * half_y
        for i, x in enumerate(columns):
            stone.lathe([(radius * 1.65, 0), (radius * 1.65, .7), (radius * 1.28, 1.35), (radius * 1.2, 2.1)],
                        14, at(x, y, bottom))
            wood.lathe([(radius, 0), (radius * .94, 2.1), (radius * .81, height - 3), (radius * 1.1, height)],
                       14, at(x, y, bottom + 1.1))
            for z in (bottom + 3.2, top - 3.1):
                gold.lathe([(radius * 1.03, 0), (radius * 1.03, .6)], 14, at(x, y, z))
            for b in range(4):  # stepped bracket set carrying the eave
                z = top + b * 1.6
                so.box((x, y + sign * b * .9, z), (5.6 + b * 3.1, 7 + b * 2.4, 1.28), bevel=.18)
                wood.box((x, y + sign * (4 + b * 1.35), z + .32), (2.42, 8.7, 1.08), bevel=.13)
            for s in (-1, 1):  # cloud braces under the lintel
                wood.box((0, 0, 0), (1.1, 1.4, 6.5), at(x + s * (radius + 2.2), y, top - 5.2)
                         @ Matrix.Rotation(s * .62, 4, "Y"), bevel=.12)
            if i == bays:
                continue
            middle = (x + columns[i + 1]) / 2
            span = columns[i + 1] - x - radius * 2
            so.box((middle, y - .5 * sign, top - 4.6), (span, .7, 4.4), bevel=.1)  # lattice transom
            for k in range(1, 9):
                wood.box((middle - span / 2 + span * k / 9, y - .05 * sign, top - 4.6), (.38, .5, 4.2))
            gold.box((middle, y + .05 * sign, top - 7.1), (span, .45, .5), bevel=.05)
            if sign < 0:
                continue
            for zz, t in ((bottom + 4.6, .75), (bottom + 1.9, .5)):  # railing
                wood.box((middle, y + .6, zz), (span, t + .25, t), bevel=.08)
            pickets = max(2, int(span / 2.6))
            for k in range(1, pickets):
                wood.box((middle - span / 2 + span * k / pickets, y + .6, bottom + 3.2), (.42, .42, 2.9))
            if RNG.random() < .7:  # paper lanterns hang in the open bays
                lz = top - 9 - RNG.uniform(0, 4)
                ly = y - (half_y - core) * .45
                amber.lathe([(.01, -2.2), (1.5, -1.7), (2.0, 0), (1.5, 1.7), (.01, 2.2)], 10, at(middle, ly, lz))
                gold.box((middle, ly, (lz + top - 1.6) / 2 + 1.1), (.2, .2, top - 1.6 - lz - 2.2))
            if RNG.random() < .35:  # broken railing
                wood.box((0, 0, 0), (span * .4, .6, .6), at(middle + span * .2, y + 2.2, bottom + .6)
                         @ Matrix.Rotation(RNG.uniform(-.5, .5), 4, "Z"), bevel=.08)
        wood.box((0, y, top - 1), (half_x * 2 + 8, 7, 4.5), bevel=.35)
        wood.box((0, y, top + 5.6), (half_x * 2 + 11, 10, 2.6), bevel=.35)
        gold.box((0, y + sign * 3.7, top - .4), (half_x * 2 + 4, .66, 1.0), bevel=.1)
    for sign in (-1, 1):
        for y in (-half_y * .53, 0, half_y * .53):
            wood.lathe([(radius, 0), (radius * .85, height - 1), (radius * 1.13, height)], 14,
                       at(sign * half_x, y, bottom))
        wood.box((sign * half_x, 0, top - 1), (6, 2 * half_y + 3, 4.4), bevel=.35)


def panelwork(h, width, depth, base, z, banners=True):
    timber, brass, cloth = (h.m(key) for key in ("Lacquer", "Gold", "Cloth"))
    front = depth * .40 + 1.9
    frieze = width * .73
    timber.box((0, front, z - 1.0), (frieze, 1.45, 5.5), bevel=.17)
    for hh in (-2.25, .32):
        brass.box((0, front + .84, z + hh), (frieze, .45, .59), bevel=.08)
    for k in range(-int(frieze / 7.0), int(frieze / 7.0) + 1):
        x = k * 3.5
        for s in (-1, 1):
            off = s * .75
            ornament = [Vector((x + math.sin(t * 2.7 + off) * 1.53, front + .89,
                                z - 1.08 + (.42 + .48 * math.sin(t * 1.35)) * s))
                        for t in [m * .22 for m in range(13)]]
            brass.sweep(circle(5), ornament, scales=[.135] * len(ornament))
    for x in (-frieze / 3, frieze / 3) if banners else ():
        y = front - .55
        length = min(33, z - base - 7)
        span = max(9, width * .085)
        rows = [[Vector((x + span * (c / 8 - .5) + .55 * i / 18 * math.sin(i * .34),
                         y + .31 * math.sin(c * 1.41 + i * .32),
                         z - 7 - length * i / 18 + (i / 18) ** 11 * math.sin(c * 3.35) * .87))
                 for c in range(9)] for i in range(19)]
        cloth.grid(rows, None, expect=Vector((0, 1, 0)), open_surface=True)
        kit.wheel(brass, x, y + .65, z - 13.5, span * .22, .14)


def pavilion(hall, loc, width, depth, height, bays, arch=False):
    block = Hall()
    gallery_tier(block, width * .412, depth * .388, 0, height, bays, max(2.2, width * .019))
    eave = height + 8
    kit.roof(block, width, depth, width * .146, eave, min(116, max(34, int(width * .48))))
    # A lower skirt eave sits under the main roof so each tier reads as layered, upturned eaves.
    kit.roof(block, width * .93, depth * 1.04, width * .05, eave - 5.5, min(90, max(30, int(width * .4))))
    panelwork(block, width, depth, 0, height - 1.45, banners=arch)
    GLOWS.append((loc[0], loc[1] + depth * .3, loc[2] + height * .55, width))
    if arch:
        crest(block, width, depth, eave)
    merge(hall, block, at(*loc))


def crest(h, width, depth, roof_z):
    gold, wood, tile = (h.m(role) for role in ("Gold", "Lacquer", "Tile"))
    x_end = width * .36
    front = depth / 2 + 8.5
    curves = []
    for side in (-1, 1):
        curves.append([Vector((side * x_end * (i / 44), front - 8 * (i / 44) ** 1.65,
                               roof_z + 19 * (math.cos(math.pi * .67 * i / 44) ** 2) + 7 * (i / 44) ** 10))
                       for i in range(45)])
    path = list(reversed(curves[0])) + curves[1][1:]
    wood.sweep([(-2, -2), (1.7, -2), (1.7, 1.1), (-2, 1.1)], path, up=Vector((0, 1, 0)))
    for lift, inset in ((1.45, 2.1), (.44, 2.3), (-1.1, 2.25)):
        line = [p + Vector((0, inset, lift)) for p in path]
        gold.sweep(circle(7), line, up=Vector((0, 1, 0)), scales=[.23] * len(line))
    for i, p in enumerate(path[::2]):
        tile.lathe([(.58, 0), (.50, 1.4), (.35, 2.2)], 8,
                   at(p.x, p.y, p.z + 1.0) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
        if i % 4 == 0:
            gold.lathe([(.8, 0), (.48, 1.6), (0, 2.8)], 9, at(p.x, p.y, p.z + 2.2))
    kit.wheel(gold, 0, front + 1.75, roof_z + 15.2, width * .031, .34)


SIDE_SHRINES = [((-178, -74, 150), 80, 64, 32), ((182, -84, 140), 84, 66, 30), ((-204, -150, 232), 70, 60, 30),
                ((200, -162, 252), 66, 56, 28), ((-158, -206, 324), 60, 52, 26), ((156, -214, 336), 58, 50, 26)]


def galleries(h):
    """Side shrines on tall stone piers and timber bridges back to the main stack."""
    wood, stone, gold = (h.m(role) for role in ("Lacquer", "Masonry", "Gold"))
    for (x, y, z), w, d, ht in SIDE_SHRINES:
        pavilion(h, (x, y, z), w, d, ht, 3)
        stone.box((x, y, z - 1.5), (w * .92, d * .92, 3), bevel=.5)
        for px in (-.38, 0, .38):
            for py in (-.3, .3):
                stone.box((x + px * w, y + py * d, z / 2 - 1.5), (7.5, 7.5, z - 3), bevel=.6)
                stone.box((x + px * w, y + py * d, z - 4), (9.5, 9.5, 2), bevel=.4)
    for a, b, y, z in ((-140, -92, -70, 150), (92, 142, -80, 140), (-170, -96, -150, 232), (96, 168, -160, 252)):
        midpoint, width = (a + b) * .5, b - a
        stone.box((midpoint, y, z - 2), (width + 2.8, 14, 4), bevel=.45)
        for i in range(1, int(width / 8)):
            for s in (-1, 1):
                wood.box((a + i * 8, y + s * 5.6, z + 2.6), (1.8, 2.1, 5.2), bevel=.15)
        for s in (-1, 1):
            wood.box((midpoint, y + s * 5.6, z + 4.9), (width, 2.2, 1.04), bevel=.21)
            gold.box((midpoint, y + s * 6.58, z + 4.4), (width, .26, .35), bevel=.06)


def traveller(h):
    """Five-stud traveler in a conical straw hat, looking up at the entrance."""
    coat, leather, straw = (h.m(role) for role in ("TravelerCloth", "DarkStone", "Straw"))
    _, y, z, _ = stair_profile(4)
    x = 8.0
    origin = at(x, y, z + .07)
    for s in (-1, 1):
        leather.box((s * .28, .06 * s, .49), (.36, .46, .92), origin, bevel=.07)
        leather.box((s * .28, -.10 + .06 * s, .15), (.40, .66, .29), origin, bevel=.08)
        coat.sweep(circle(8), [Vector((x + s * .57, y, z + 3.43)), Vector((x + s * .74, y + .11, z + 2.8)),
                              Vector((x + s * .69, y - .12, z + 2.35))], scales=[.26, .25, .17])
    leather.lathe([(.38, 1.4), (.44, 2.3), (.55, 3.28), (.40, 3.62)], 12, origin)
    hem = []
    for j, (level, width, depth) in enumerate(((.82, 1.15, .62), (1.65, .90, .55), (2.57, .62, .47), (3.51, .57, .40))):
        hem.append([Vector((x + math.cos(a) * width, y + math.sin(a) * depth + .06 * j,
                            z + level + (.14 * math.sin(5 * a) if j == 0 else 0)))
                    for a in (k * math.tau / 28 for k in range(28))])
    coat.grid(hem, None, wrap=True)
    form(leather, (x, y, z + 3.99), (.38, .30, .47))
    straw.lathe([(1.17, 4.29), (1.22, 4.36), (.94, 4.44), (.50, 4.74), (.12, 4.93), (0, 4.97)],
                22, origin @ Matrix.Rotation(-.13, 4, "Y"))
    leather.lathe([(1.16, 4.28), (1.22, 4.34), (1.20, 4.38)], 22, origin @ Matrix.Rotation(-.13, 4, "Y"))


def form(mesh, point, dimensions, yaw=0):
    ox, oy, oz = point
    sx, sy, sz = dimensions
    transform = Matrix.Translation(Vector((ox, oy, oz))) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Diagonal((sx, sy, sz, 1))
    shape = [(math.cos(t), math.sin(t)) for t in [-math.pi / 2 + i * math.pi / 12 for i in range(13)]]
    return mesh.lathe(shape, 20, transform)


def lion(h, location, yaw, scale=1.0):
    carving = Hall()
    s, shade, gold = (carving.m(role) for role in ("Masonry", "DarkStone", "Gold"))
    s.box((0, 0, 2.8), (24.2, 25.4, 5.6), bevel=.55)
    s.box((0, 0, 6.1), (20.2, 20.8, 1.6), bevel=.32)
    form(s, (0, -2.8, 14), (6.8, 8.1, 7.7))
    form(s, (0, 2.4, 17.1), (6.4, 5.1, 8.1))
    form(s, (0, 2.8, 22.2), (7.2, 5.2, 6.6))
    form(s, (0, 5.2, 25.1), (5.9, 5.0, 5.1))
    form(shade, (0, 9.5, 23.15), (4.6, 1.1, 1.45))
    form(s, (0, 9, 24.5), (4.4, 2.0, 1.43))
    form(shade, (0, 10.4, 25.45), (1.8, 1.1, .57))
    form(s, (0, 8.4, 21.9), (4.0, 1.5, 1.23))
    for side in (-1, 1):
        for x, y in ((side * 3.6, 3.9), (side * 5.8, -3.9)):
            form(s, (x, y, 10.2), (2.2, 2.65, 4.5))
            form(s, (x, y + 1.65, 7.7), (2.7, 2.9, 1.32))
            for k in range(3):
                form(s, (x - 1.35 + k * 1.36, y + 3.35, 7.9), (.68, 1.28, .58))
        form(s, (side * 4.2, 3.6, 29.1), (1.8, 1.23, 2.2))
        form(s, (side * 2.55, 8.55, 26.79), (2.27, 1.25, .87), side * -.29)
        form(shade, (side * 2.55, 9.05, 26.3), (1.11, .83, .48), side * -.29)
        form(gold, (side * 2.42, 9.65, 26.35), (.30, .26, .29))
        form(s, (side * 3.5, 7.6, 23.9), (1.69, 1.30, 1.37))
        for row in range(3):
            for k in range(8):
                t = -.90 + k * .40 + row * .15
                c = Vector((side * (5.5 + math.cos(t) * 1.52), 4.1 + 3.26 * math.sin(t) - row * .49,
                            17.2 + row * 2.5 + (math.cos(t) + .65) * 2.9))
                curl = [c + Vector((side * (.92 * math.cos(j / 3.1) * (1 - j / 31)),
                                    .87 * math.sin(j / 3.1) * (1 - j / 31), -.05 * j))
                        for j in range(18)]
                s.sweep(circle(7), curl, scales=[.71 - .023 * j for j in range(18)])
    path = [Vector((0, 7.6, 18.6)), Vector((-2.5, 7.4, 17.8)), Vector((-5.6, 6.8, 19.1)),
            Vector((-6.3, 4.75, 20.1))]
    s.sweep(circle(10), path, scales=[.58, .55, .50, .42])
    kit.wheel(gold, 0, 8.25, 17.75, 1.9, .16)
    merge(h, carving, at(*location) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(scale, 4))


def lantern(h, centre, scale=1):
    x, y, z = centre
    stone, trim, amber = (h.m(role) for role in ("Masonry", "Soffit", "Lantern"))
    f = at(x, y, z) @ Matrix.Scale(scale, 4)
    stone.box((0, 0, .65), (3.83, 3.73, 1.3), f, bevel=.23)
    stone.lathe([(1.40, 1.3), (.93, 2.0), (.83, 7.1), (1.31, 7.35)], 8, f)
    stone.box((0, 0, 7.68), (3.36, 3.39, .56), f, bevel=.12)
    amber.box((0, 0, 9.5), (2.09, 2.08, 3.44), f, bevel=.12)
    for s in (-1, 1):
        for t in (-1, 1):
            trim.box((s * 1.16, t * 1.16, 9.5), (.33, .34, 3.75), f, bevel=.025)
        for zz in (8.35, 9.65, 10.85):
            trim.box((0, s * 1.20, zz), (2.34, .20, .18), f)
            trim.box((s * 1.20, 0, zz), (.21, 2.34, .18), f)
    trim.lathe([(2.15, 11.3), (2.02, 11.65), (1.37, 12.0), (.55, 12.81), (0, 13.47)], 8, f)
    return (x, y, z + 9.5 * scale)


def gate_lantern(h, x, y, z):
    frame = at(x, y, z)
    paper, iron, gold = (h.m(role) for role in ("Lantern", "Soffit", "Gold"))
    paper.lathe([(1.25, -4.4), (2.3, -2.8), (2.65, 0), (2.3, 2.8), (1.25, 4.4)], 16, frame)
    for height in (-4.4, -2.8, 2.8, 4.4):
        radius = 1.55 if abs(height) > 4 else 2.48
        iron.lathe([(radius, height - .19), (radius, height + .19)], 16, frame, caps=(False, False))
    for i in range(8):
        a = math.tau * i / 8
        path = [Vector((x + radius * math.cos(a), y + radius * math.sin(a), z + height))
                for height, radius in ((-4.4, 1.50), (-2.8, 2.45), (0, 2.79), (2.8, 2.45), (4.4, 1.50))]
        iron.sweep(circle(5), path, scales=[.155] * len(path))
    gold.lathe([(.32, -7.8), (.54, -6.8), (.48, -5.1), (.2, -4.3)], 8, frame)
    iron.box((0, 0, 8.1), (.34, .34, 7.5), frame, bevel=.045)


def gnarl(points, radii, amount=.13):
    """Insert kinked midpoints so limbs elbow instead of sweeping in even arcs; taper unevenly."""
    pts = [Vector(p) for p in points]
    out, rr = [pts[0]], [radii[0]]
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        seg = b - a
        side = seg.cross(UP)
        side = side.normalized() if side.length > 1e-3 else Vector((1, 0, 0))
        lift = seg.cross(side).normalized()
        out.append(a.lerp(b, RNG.uniform(.36, .64)) + (side * RNG.uniform(-amount, amount)
                                                         + lift * RNG.uniform(-amount, amount)) * seg.length)
        rr.append((radii[i] + radii[i + 1]) * .5 * RNG.uniform(.88, 1.04))
        out.append(b)
        rr.append(radii[i + 1])
    return out, rr


def random_unit():
    v = Vector((RNG.gauss(0, 1), RNG.gauss(0, 1), RNG.gauss(0, 1)))
    return v.normalized() if v.length > 1e-6 else Vector((1, 0, 0))


def aged_tree(h):
    bark, twigs, ivy, moss = h.m("Bark"), h.m("BarkTwigs"), h.m("Ivy"), h.m("Moss")
    centre = Vector((TRUNK[2].x, TRUNK[2].y, 0))
    stats = {"twigs": 0, "bark_branches": 0}

    def branch(start, direction, length, radius, depth):
        if radius < .075 or length < .9:
            return
        d = direction.normalized()
        side = d.cross(UP)
        side = side.normalized() if side.length > 1e-3 else Vector((1, 0, 0))
        lift = side.cross(d)
        bend = side * RNG.uniform(-.3, .3) * length + lift * RNG.uniform(-.18, .26) * length
        kink = (side * RNG.uniform(-.14, .14) + lift * RNG.uniform(-.1, .1)) * length
        pts = [start, start + d * length * .34 + bend * .55 + kink, start + d * length * .68 + bend - kink * .6,
               start + d * length + bend * .3 + UP * RNG.uniform(-.14, .24) * length]
        rr = [radius, radius * RNG.uniform(.7, .84), radius * RNG.uniform(.48, .6), radius * .2]
        if radius >= THICK:
            organic_path(bark, circle(12), pts, rr, SPINE)
            stats["bark_branches"] += 1
        else:
            path, scales = curved(pts, rr)
            twigs.sweep(circle(6 if radius > .5 else 4), path, scales=scales)
            stats["twigs"] += 1
        if not depth:
            return
        for _ in range(RNG.choice((2, 3, 3, 4)) if depth > 2 else RNG.choice((3, 3, 4))):
            seg = RNG.randrange(0, 3)
            t = RNG.uniform(.15, 1.0)
            where = pts[seg].lerp(pts[seg + 1], t)
            here = rr[seg] * (1 - t) + rr[seg + 1] * t
            vector = ((pts[seg + 1] - pts[seg]).normalized() * RNG.uniform(.5, 1.1)
                      + random_unit() * RNG.uniform(.45, .95) + UP * RNG.uniform(-.25, .45))
            branch(where, vector, length * RNG.uniform(.46, .7), here * RNG.uniform(.5, .78), depth - 1)

    def limb(points, radii, spawn=(2, 2, 3, 3), twig_depth=None):
        points = [Vector(p) for p in points]
        points = [Vector((p.x, p.y, 445 + (p.z - 445) * CROWN_SQUASH)) if p.z > 445 else p for p in points]
        pts, rr = gnarl(points, radii, .11)
        organic_path(bark, BARK_PROFILE, pts, rr, SPINE)
        for i in range(1, len(pts)):
            a, b = pts[i - 1], pts[i]
            r = (rr[i - 1] + rr[i]) * .5
            for _ in range(RNG.choice(spawn)):
                where = a.lerp(b, RNG.uniform(.1, .95))
                outward = Vector((where.x - centre.x, where.y - centre.y, 0))
                outward = outward.normalized() if outward.length > 1 else random_unit()
                vector = ((b - a).normalized() * RNG.uniform(.3, .9) + outward * RNG.uniform(.2, .8)
                          + random_unit() * .55 + UP * RNG.uniform(-.4, .75))
                radius = r * RNG.uniform(.3, .52)
                branch(where, vector, radius * RNG.uniform(10, 15), radius,
                       TWIG_DEPTH if twig_depth is None else twig_depth)
        return pts, rr

    # The trunk: one colossal pale column with a lean, a twist and three unequal leaders.
    organic_path(bark, BARK_PROFILE, TRUNK, [40, 39, 34, 30, 26, 22], SPINE)
    for i in range(18):  # rope-like strands spiral up the trunk and run on into leaders and roots
        phase = i * math.tau / 18 + RNG.uniform(-.12, .12)
        route, scales = [], []
        for j in range(len(TRUNK)):
            t = phase + .34 * j * (1 if i % 3 else -.6)
            r = (38 - 3.3 * j) * RNG.uniform(.86, .99)
            route.append(TRUNK[j] + Vector((math.cos(t) * r, math.sin(t) * r, RNG.uniform(-3, 3))))
            scales.append(RNG.uniform(3.0, 7.5) * (.6 if j == len(TRUNK) - 1 else 1))
        organic_path(bark, circle(10), route, scales, SPINE)
    fork = TRUNK[4]
    leaders = [
        ([fork, (34, -150, 488), (62, -146, 535), (80, -138, 590), (112, -130, 640), (146, -122, 690), (170, -110, 740)],
         [26, 21, 17, 14, 11, 7.5, 4.5]),
        ([TRUNK[3], (-16, -160, 490), (-32, -158, 550), (-24, -150, 615), (-44, -140, 680), (-52, -130, 750), (-40, -120, 810)],
         [29, 23, 19, 15, 11, 7, 3.5]),
        ([fork, (-34, -170, 478), (-80, -178, 508), (-122, -172, 550), (-160, -168, 590), (-206, -160, 628), (-240, -150, 660)],
         [23, 18, 15, 12, 9, 6, 3.5]),
    ]
    built = [limb(p, r) for p, r in leaders]
    l1, l2, l3 = built

    def on(pts, z):  # nearest gnarled control point to a height
        return min(pts, key=lambda p: abs(p.z - z))

    laterals = [
        ([on(l1[0], 488), (80, -136, 496), (140, -120, 484), (200, -104, 508), (262, -86, 498), (320, -70, 530),
          (380, -56, 548), (430, -40, 540)], [14, 12, 10, 8, 6.5, 5, 3.5, 2.2]),
        ([TRUNK[3] + Vector((-10, 6, 6)), (-54, -136, 425), (-112, -120, 415), (-172, -104, 442), (-232, -92, 436),
          (-292, -78, 466), (-352, -66, 458), (-400, -56, 480)], [16, 13, 10.5, 8.5, 6.5, 5, 3.5, 2.2]),
        ([on(l1[0], 590), (136, -116, 602), (196, -96, 632), (256, -62, 642), (318, -34, 684), (370, -10, 700)],
         [11, 9, 7, 5.5, 3.8, 2.4]),
        ([on(l2[0], 550), (-88, -140, 582), (-150, -116, 592), (-218, -88, 632), (-280, -60, 642), (-336, -36, 680)],
         [12, 10, 8, 6, 4, 2.5]),
        ([on(l2[0], 615), (-16, -104, 648), (0, -44, 676), (22, 16, 690), (36, 80, 720), (40, 140, 742)],
         [10, 9, 7, 5.5, 4, 2.6]),
        ([on(l1[0], 535), (88, -100, 570), (112, -44, 592), (140, 14, 628), (160, 70, 650)], [11, 9, 7, 5, 3]),
        ([on(l3[0], 508), (-92, -220, 552), (-104, -262, 596), (-86, -300, 646)], [10, 8, 6, 3.5]),
        ([on(l3[0], 550), (-128, -120, 590), (-130, -60, 615), (-120, 0, 650), (-110, 60, 665)], [9, 8, 6, 4.5, 3]),
        ([on(l1[0], 640), (120, -170, 690), (96, -210, 740), (110, -250, 790)], [8, 6.5, 5, 3]),
        ([on(l2[0], 490), (-44, -118, 500), (-72, -62, 522), (-112, -12, 512), (-170, 30, 540), (-222, 62, 532)],
         [11, 9, 7.5, 6, 4.2, 2.8]),
        ([on(l1[0], 488), (62, -110, 472), (102, -62, 456), (150, -22, 472), (204, 18, 462)], [10, 8, 6.4, 4.4, 2.8]),
    ]
    built_laterals = [limb(p, r) for p, r in laterals]
    # Drooping secondaries hang down and out from the long laterals.
    for (pts, rr), index, drop in ((built_laterals[1], 6, (-36, 10, -26)), (built_laterals[0], 6, (28, 12, -24)),
                                   (built_laterals[3], 4, (-30, 18, -22)), (built_laterals[2], 4, (30, 16, -20))):
        p = pts[index]
        r = rr[index] * .55
        limb([p, p + Vector(drop) * .5 + Vector((0, 0, 4)), p + Vector(drop), p + Vector(drop) * 1.6 + Vector((0, 0, 6))],
             [r, r * .8, r * .55, r * .28], spawn=(1, 2), twig_depth=max(1, TWIG_DEPTH - 1))

    # Roots pour down the terraces as load-bearing forms: draped over stone with BVH ray casts.
    trees = [BVHTree.FromBMesh(h.m(role).bm) for role in ("Masonry", "Tile", "Lacquer")]
    down = Vector((0, 0, -1))

    def surface(x, y, top):
        best = 0.0
        for tree in trees:
            hit = tree.ray_cast(Vector((x, y, top)), down, top + 10)
            if hit[0] is not None and hit[0].z > best:
                best = hit[0].z
        return best

    def blocked(p):
        _, _, _, w = stair_profile(max(0, min(STEP_COUNT - 1, (START_Y - p.y) / STEP_RUN)))
        return p.y > -46 and abs(p.x) < w / 2 + 7  # the player route stays clear

    def steer(p, heading, goal):
        heading = heading + (goal - Vector((p.x, p.y))).normalized() * .32
        if abs(p.x) < 104 and -128 < p.y and p.z > 60:  # flow around the gate hall, never over its face
            heading = heading + Vector((math.copysign(1.4, p.x if abs(p.x) > 1 else 1), -.2))
        return heading.normalized()

    def root(start, heading, r0, length, depth, goal):
        heading = Vector(heading).normalized()
        pts, rr = [start.copy()], [r0]
        p = start.copy()
        travelled, next_fork = 0.0, RNG.uniform(40, 80)
        step = 5.0
        while travelled < length and len(pts) < 160:
            r = max(.6, r0 * (1 - travelled / length) ** .8)
            heading = steer(p, heading @ Matrix.Rotation(RNG.uniform(-.24, .24), 2), goal)
            q = Vector((p.x, p.y)) + heading * step
            if blocked(Vector((q.x, q.y, p.z))):
                break
            hold = max(6.0, r * 1.5)
            ground = surface(q.x, q.y, p.z + r * .5 + 4) + r * .2
            if p.z - ground > hold:
                lo, hi = 0.0, 1.0
                for _ in range(6):
                    mid = (lo + hi) * .5
                    m = Vector((p.x, p.y)) + heading * step * mid
                    if p.z - (surface(m.x, m.y, p.z + r * .5 + 4) + r * .2) > hold:
                        hi = mid
                    else:
                        lo = mid
                edge = Vector((p.x, p.y)) + heading * step * lo
                drop = p.z - ground
                # Arch over the lip, then sweep diagonally down the face instead of hanging like a curtain.
                # Tall faces are crossed diagonally so neighbouring roots braid instead of curtaining.
                lateral = Vector((-heading.y, heading.x)) * RNG.choice((-1, 1)) * drop * RNG.uniform(.25, .6)
                land = edge + heading * (r * 1.3 + drop * .42) + lateral
                land_z = surface(land.x, land.y, ground + r + 6) + r * .2
                arc = ((edge, p.z + r * .75, 1.0),
                       (edge + heading * (r * .9 + drop * .07) + lateral * .25, p.z - drop * .28, .92),
                       (edge + heading * (r * 1.1 + drop * .22) + lateral * .7, land_z + drop * .3, .86),
                       (land, land_z, .8))
                for xy, z, shrink in arc:
                    pts.append(Vector((xy.x, xy.y, z)))
                    rr.append(r * shrink * RNG.uniform(.92, 1.04))
                r0 *= .92  # a root thins as it gives off grip forks over each course
                p = pts[-1].copy()
                travelled += step + drop * .6
                CONTACTS.append((p.copy(), r))
                if depth and r > .9:  # break into gripping forks along the wall foot
                    for sign in (-1, 1):
                        if RNG.random() < .7:
                            child = heading @ Matrix.Rotation(sign * RNG.uniform(.8, 1.5), 2)
                            root(pts[-2].lerp(pts[-1], .5), child, r * RNG.uniform(.35, .55),
                                 RNG.uniform(14, 34) + r * 3, depth - 1, goal + child * 60)
            elif ground - p.z > r * .8 + 3:  # a wall ahead: roots turn along it rather than climb
                heading = heading @ Matrix.Rotation(RNG.choice((-1, 1)) * RNG.uniform(.8, 1.5), 2)
                travelled += 1.5
            else:
                z = max(ground, p.z - step * 1.1) if ground < p.z else ground
                p = Vector((q.x, q.y, z))
                pts.append(p.copy())
                rr.append(r)
                travelled += step
            if travelled > next_fork and depth and r > 1.2:
                next_fork += RNG.uniform(35, 75)
                child = heading @ Matrix.Rotation(RNG.choice((-1, 1)) * RNG.uniform(.55, 1.1), 2)
                root(pts[-1].copy(), child, r * RNG.uniform(.42, .62), (length - travelled) * RNG.uniform(.45, .9) + 20,
                     depth - 1, goal + child * 80)
        if depth == 3:
            print("Root", tuple(round(c) for c in start), "->", tuple(round(c) for c in pts[-1]), len(pts), "pts",
                  round(travelled), "/", round(length), flush=True)
        if len(pts) < 3:
            return
        rr[-1] = max(.25, rr[-1] * .3)
        if rr[0] > 3.0:
            root_bundle(bark, pts, rr)
        elif rr[0] >= THICK:
            organic_path(bark, circle(12), pts, rr, SPINE)
        else:
            organic_path(twigs, circle(7), pts, rr)
        for p, r in zip(pts[::3], rr[::3]):  # greenery where root and stone meet
            if p.z < 330 and RNG.random() < .5:
                for _ in range(RNG.randrange(2, 7)):
                    kit.leaf(ivy if RNG.random() < .6 else moss,
                             p + Vector((RNG.uniform(-r, r), RNG.uniform(-r, r), -r * .3)), RNG.uniform(.6, 1.6))

    # Most of the root mass pours down the image-left (+X) terraces as separate, netted roots; a few go right.
    plan = [(1, RNG.uniform(-.25, .75), RNG.uniform(4.7, 8.3), RNG.uniform(430, 620),
             (RNG.uniform(55, 155), RNG.uniform(-25, 166))) for _ in range(9)]
    plan += [(-1, RNG.uniform(-.1, .6), RNG.uniform(5.5, 9.5), RNG.uniform(260, 360),
              (-RNG.uniform(60, 170), RNG.uniform(-50, 90))) for _ in range(5)]
    # The cascade: long roots that pour over the near left retaining walls down beside the stair.
    plan += [(1, RNG.uniform(.35, 1.1), RNG.uniform(4.3, 7.7), RNG.uniform(640, 820),
              goal) for goal in ((63, 176), (143, 211), (105, 154), (194, 163), (176, 127))]
    for side, lean, radius, length, goal in plan:
        h2 = Vector((side, lean)).normalized()
        z = RNG.uniform(232, 350)
        level = min(range(len(TRUNK)), key=lambda j: abs(TRUNK[j].z - z))
        around = h2 @ Matrix.Rotation(RNG.uniform(-.7, .7), 2)
        start = TRUNK[level] + Vector((around.x, around.y, 0)) * (40 - 2 * level) + Vector((0, 0, z - TRUNK[level].z))
        root(start, h2, radius, length, 3, Vector(goal))

    # Hanging aerial roots and ivy curtains under the eaves of the lower tiers.
    for x0, y0, z0, w, d, ht, _, _ in TIERS[:3]:
        y = y0 + d / 2 + 6
        z = z0 + ht + 7
        for i in range(23):
            x = x0 + RNG.uniform(-w * .46, w * .46)
            drop = RNG.uniform(8, 30)
            points = [Vector((x + math.sin(j * .71 + i) * 1.56, y + math.sin(j * 1.34) * .72, z - j / 8 * drop)) for j in range(9)]
            twigs.sweep(circle(5), points, scales=[.42 - j * .04 for j in range(9)])
            for p, q in zip(points, points[1:]):
                for k in range(3):
                    stem = p.lerp(q, k / 3) + Vector((RNG.uniform(-1.04, 1.04), .41, RNG.uniform(-.15, .15)))
                    kit.leaf(ivy if k % 3 else moss, stem, RNG.uniform(.48, 1.44))
    print("Tree", stats, "spine samples", len(SPINE), "root contacts", len(CONTACTS), flush=True)


def crags(h):
    """Columnar karst crags with vertical flutes, pine-crowned, flanking the temple."""
    rock, pine = h.m("Crag"), h.m("Pine")
    for side in (-1, 1):
        for i in range(10):
            near = i < 4
            x = side * (RNG.uniform(235, 380) if near else RNG.uniform(330, 680))
            y = RNG.uniform(-220, -480) if near else RNG.uniform(-450, -1000)
            height = RNG.uniform(330, 560) if near else RNG.uniform(400, 800)
            radius = RNG.uniform(55, 100) if near else RNG.uniform(40, 85)
            flutes = RNG.randrange(5, 9)
            rings = []
            # Stacked karst: bedded blocks, each offset and narrowed, with an undercut joint between beds.
            beds = RNG.randrange(6, 11)
            bed_scale = [RNG.uniform(.78, 1.06) for _ in range(beds)]
            bed_shift = [Vector((RNG.uniform(-.13, .13), RNG.uniform(-.13, .13), 0)) * radius for _ in range(beds)]
            for j in range(56):
                t = j / 55
                z = -40 + height * t
                bed = min(beds - 1, int(t * beds))
                within = t * beds - bed
                joint = .8 if within < .06 or within > .94 else 1.0
                shrink = (1 - .8 * t ** 1.3) * bed_scale[bed] * joint
                ring = []
                for k in range(30):
                    a = k * math.tau / 30
                    wobble = (1 + .2 * math.sin(a * flutes + i + bed * .7) + .32 * noise(Vector((a * 1.3, bed * .9, i)))
                              + .12 * noise(Vector((a * 4, t * 17, i))))
                    ring.append(Vector((x + bed_shift[bed].x + math.cos(a) * radius * shrink * wobble,
                                        y + bed_shift[bed].y + math.sin(a) * radius * shrink * wobble * 1.1, z)))
                rings.append(ring)
            rock.grid(rings, None, wrap=True)
            top = sum(rings[-1], Vector()) / len(rings[-1])
            rings.append([top + (q - top) * .05 + Vector((RNG.uniform(-6, 6), RNG.uniform(-6, 6), radius * .7)) for q in rings[-1]])
            rock.grid(rings[-2:], None, wrap=True)
            rock.poly(rings[-1])
            rock.poly(list(reversed(rings[0])))
            for _ in range(RNG.randrange(6, 14)):
                a = RNG.uniform(0, math.tau)
                t = RNG.uniform(.55, 1.0)
                r = radius * (1 - .8 * t ** 1.3) * .8
                base = Vector((x + math.cos(a) * r, y + math.sin(a) * r, -40 + height * t))
                size = RNG.uniform(12, 26)
                pine.lathe([(size * .08, 0), (size * .06, size * .5), (0, size * .55)], 6, at(*base))
                for c in range(3):
                    z = size * (.35 + c * .28)
                    w = size * (.55 - c * .14)
                    pine.lathe([(w, 0), (w * .35, size * .22), (0, size * .34)], 9,
                               at(base.x + RNG.uniform(-1, 1), base.y, base.z + z))


def sock(sockets, name, kind="RGBA"):
    return next(s for s in sockets if s.name == name and s.type == kind)


def bark_material(name, attributes):
    """Pale bleached bark, grain along each limb (UV), dark recesses, moss where the attribute says."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    folder = kit.POLY_HAVEN / "bark_willow_02"
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    scale = nodes.new("ShaderNodeVectorMath")
    scale.operation = "MULTIPLY"
    scale.inputs[1].default_value = (.55, .16, 1) if attributes else (.9, .25, 1)
    links.new(uv.outputs["UV"], scale.inputs[0])

    def image(file, colour):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(folder / file), check_existing=True)
        if not colour:
            tex.image.colorspace_settings.name = "Non-Color"
        links.new(scale.outputs[0], tex.inputs["Vector"])
        return tex

    diffuse = image("bark_willow_02_Diffuse_2k.jpg", True)
    normal_img = image("bark_willow_02_nor_gl_2k.jpg", False)
    rough_img = image("bark_willow_02_Rough_2k.jpg", False)
    grey = nodes.new("ShaderNodeRGBToBW")
    links.new(diffuse.outputs["Color"], grey.inputs[0])
    grey_out = grey.outputs[0]
    if attributes:
        coords = nodes.new("ShaderNodeTexCoord")
        box_scale = nodes.new("ShaderNodeVectorMath")
        box_scale.operation = "SCALE"
        box_scale.inputs["Scale"].default_value = .06
        links.new(coords.outputs["Object"], box_scale.inputs[0])
        boxed = nodes.new("ShaderNodeTexImage")
        boxed.image = diffuse.image
        boxed.projection = "BOX"
        boxed.projection_blend = .35
        links.new(box_scale.outputs[0], boxed.inputs["Vector"])
        boxed_grey = nodes.new("ShaderNodeRGBToBW")
        links.new(boxed.outputs["Color"], boxed_grey.inputs[0])
        junction = nodes.new("ShaderNodeAttribute")
        junction.attribute_name = "bark_blend"
        fade = nodes.new("ShaderNodeMix")
        fade.data_type = "FLOAT"
        links.new(junction.outputs["Fac"], sock(fade.inputs, "Factor", "VALUE"))
        links.new(grey.outputs[0], sock(fade.inputs, "A", "VALUE"))
        links.new(boxed_grey.outputs[0], sock(fade.inputs, "B", "VALUE"))
        grey_out = sock(fade.outputs, "Result", "VALUE")
    if attributes:
        ridge = nodes.new("ShaderNodeAttribute")
        ridge.attribute_name = "bark_ridge"
        ridge_out = ridge.outputs["Fac"]
    else:
        value = nodes.new("ShaderNodeValue")
        value.outputs[0].default_value = .62
        ridge_out = value.outputs[0]
    mix_r = nodes.new("ShaderNodeMath")
    mix_r.operation = "MULTIPLY_ADD"
    links.new(grey_out, mix_r.inputs[0])
    mix_r.inputs[1].default_value = .55
    links.new(ridge_out, mix_r.inputs[2])
    ramp = nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = .3, (.018, .017, .015, 1)
    els[1].position, els[1].color = 1.0, (.70, .68, .62, 1)
    mid = els.new(.62)
    mid.color = (.2, .19, .165, 1)
    links.new(mix_r.outputs[0], ramp.inputs[0])
    colour = ramp.outputs[0]
    if attributes:
        mossy = nodes.new("ShaderNodeAttribute")
        mossy.attribute_name = "bark_moss"
        speck = nodes.new("ShaderNodeTexNoise")
        speck.inputs["Scale"].default_value = .35
        speck.inputs["Detail"].default_value = 6
        speck_coord = nodes.new("ShaderNodeTexCoord")
        links.new(speck_coord.outputs["Object"], speck.inputs["Vector"])
        gate = nodes.new("ShaderNodeMapRange")
        gate.inputs["From Min"].default_value = .42
        gate.inputs["From Max"].default_value = .58
        links.new(speck.outputs["Fac"], gate.inputs["Value"])
        amount = nodes.new("ShaderNodeMath")
        amount.operation = "MULTIPLY"
        links.new(mossy.outputs["Fac"], amount.inputs[0])
        links.new(gate.outputs[0], amount.inputs[1])
        green = nodes.new("ShaderNodeMix")
        green.data_type = "RGBA"
        links.new(amount.outputs[0], sock(green.inputs, "Factor", "VALUE"))
        links.new(colour, sock(green.inputs, "A"))
        sock(green.inputs, "B").default_value = (.055, .075, .022, 1)
        colour = sock(green.outputs, "Result")
    if attributes:
        position = nodes.new("ShaderNodeNewGeometry")
        split = nodes.new("ShaderNodeSeparateXYZ")
        links.new(position.outputs["Position"], split.inputs["Vector"])
        damp = nodes.new("ShaderNodeMapRange")
        damp.inputs["From Min"].default_value = 22
        damp.inputs["From Max"].default_value = 310
        damp.inputs["To Min"].default_value = .46
        damp.inputs["To Max"].default_value = 1
        links.new(split.outputs["Z"], damp.inputs["Value"])
        darken = nodes.new("ShaderNodeMixRGB")
        darken.blend_type = "MULTIPLY"
        darken.inputs[0].default_value = 1
        links.new(colour, darken.inputs[1])
        links.new(damp.outputs["Result"], darken.inputs[2])
        colour = darken.outputs[0]
    links.new(colour, shader.inputs["Base Color"])
    links.new(rough_img.outputs["Color"], shader.inputs["Roughness"])
    nmap = nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 1.3
    links.new(normal_img.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], shader.inputs["Normal"])
    return m


def art_materials():
    kit.PALETTE.update({
        "Masonry": ((.27, .27, .245), (.055, .07, .05), .86, .08),
        "Tile": ((.06, .072, .082), (.014, .018, .021), .42, .27),
        "Lacquer": ((.25, .045, .033), (.075, .014, .010), .68, .20),
        "Gold": ((.39, .235, .085), (.17, .090, .025), .53, .30),
        "Cloth": ((.30, .061, .043), (.12, .020, .014), .92, .26),
        "DarkStone": ((.055, .066, .061), (.023, .026, .023), .85, .22),
        "Lantern": ((1, .78, .37), (.83, .39, .074), .47, .55),
        "Crag": ((.16, .17, .175), (.035, .04, .042), .9, .05),
        "Pine": ((.035, .06, .04), (.012, .022, .015), .9, .4),
        "TravelerCloth": ((.055, .050, .045), (.017, .022, .026), .91, .08),
        "Straw": ((.29, .19, .091), (.11, .069, .032), .83, .09),
    })
    kit.TEXTURES["Crag"] = ("dark_rock", .018, .85)
    mats = kit.materials()
    shader = mats["Lantern"].node_tree.nodes.get("Principled BSDF")
    shader.inputs["Emission Color"].default_value = (1, .43, .094, 1)
    shader.inputs["Emission Strength"].default_value = 7.5
    mats["Bark"] = bark_material("Bellwood bleached bark", True)
    mats["BarkTwigs"] = bark_material("Bellwood bleached twigs", False)
    return mats


def fuse_tree(obj):
    """Voxel-union the closed branch cores. Preserve the thinnest twigs as separate render geometry."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    obj.data.remesh_voxel_size = VOXEL
    bpy.ops.object.voxel_remesh()
    print("Remeshed tree", len(obj.data.vertices), "vertices", flush=True)
    tree = bmesh.new()
    tree.from_mesh(obj.data)
    remaining = set(tree.verts)
    components = []
    while remaining:
        start = remaining.pop()
        trunk = [start]
        for vertex in trunk:
            for edge in vertex.link_edges:
                adjacent = edge.other_vert(vertex)
                if adjacent in remaining:
                    remaining.remove(adjacent)
                    trunk.append(adjacent)
        components.append(trunk)
    components.sort(key=len, reverse=True)
    print("Bark islands", len(components), "largest share", round(len(components[0]) / len(tree.verts), 4), flush=True)
    assert components and len(components[0]) >= .95 * len(tree.verts), "Major branches detached from trunk"
    bmesh.ops.delete(tree, geom=[vertex for component in components[1:] for vertex in component], context="VERTS")
    assert all(edge.is_manifold for edge in tree.edges), "Fused bark contains open seams"
    tree.to_mesh(obj.data)
    tree.free()
    # Smooth limb junctions fully, but keep root strands crisp so their gaps do not melt shut.
    group = obj.vertex_groups.new(name="Smooth above roots")
    levels = {}
    for v in obj.data.vertices:
        levels.setdefault(round(.2 + .8 * min(1.0, max(0.0, (v.co.z - 230) / 120)), 1), []).append(v.index)
    for weight, indices in levels.items():
        group.add(indices, weight, "REPLACE")
    smooth = obj.modifiers.new("Blend grown wood junctions", "SMOOTH")
    smooth.factor = .55
    smooth.iterations = 4
    smooth.vertex_group = group.name
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    bark_grain(obj)
    obj.data.shade_smooth()
    print("United tree body", len(obj.data.vertices), "vertices", flush=True)


def bark_grain(obj):
    """Carve flutes, lobes and twist along each limb's own axis, then write UVs and ridge/moss masks."""
    kd = KDTree(len(SPINE))
    for i, record in enumerate(SPINE):
        kd.insert(record[0], i)
    kd.balance()
    vertices = obj.data.vertices
    count = len(vertices)
    coords = array("f", [0]) * (3 * count)
    normals = array("f", [0]) * (3 * count)
    vertices.foreach_get("co", coords)
    vertices.foreach_get("normal", normals)
    ridge = array("f", [0]) * count
    mossy = array("f", [0]) * count
    us = array("f", [0]) * count
    vs = array("f", [0]) * count
    period = array("f", [0]) * count
    blend = array("f", [0]) * count
    for i in range(count):
        p = Vector(coords[3 * i:3 * i + 3])
        total = height = 0.0
        best_u = best_v = best_w = 0.0
        best_period = 1.0
        hits = kd.find_n(p, 4)
        per_path = {}
        for _, index, _ in hits:
            c, t, side, up, r, s, base, pid = SPINE[index]
            d = p - c
            x, y = d.dot(side), d.dot(up)
            a = math.atan2(y, x)
            along = s + d.dot(t)
            twist = along / (base * 5.5) * (1 if int(pid) % 2 else -1)
            lobes = max(3, round(base / 7))
            flutes = max(6, round(math.tau * base / 4.6))
            wander = .7 * math.sin(along * .021 + pid)
            lobe = .5 + .5 * math.cos(lobes * (a + twist) + wander)
            flute = abs(math.sin(.5 * flutes * (a + twist * 1.15) + .45 * math.sin(along * .05 + pid * 1.3))) ** .55
            fine = min(1.0, max(0.0, (math.tau * r / flutes - 1.0) / 2.0))
            value = .5 * lobe + .5 * (flute * fine + .5 * (1 - fine)) + .18 * noise(Vector((along * .035, a, pid)))
            weight = 1 / (abs(math.hypot(x, y) - r) + 1.0) ** 2
            total += weight
            height += value * weight
            per_path[pid] = max(per_path.get(pid, 0.0), weight)
            if weight > best_w:
                best_w, best_u, best_v, best_period = weight, a * base / 6, along / 6, math.tau * base / 6
        value = height / total
        nearest_r = SPINE[hits[0][1]][4]
        amplitude = min(nearest_r * .26, 8.0)
        for axis in range(3):
            coords[3 * i + axis] += normals[3 * i + axis] * (value - .55) * amplitude
        ridge[i] = min(1.0, max(0.0, value))
        nz = normals[3 * i + 2]
        low = min(1.0, max(0.0, (340 - p.z) / 150))
        mossy[i] = min(1.0, max(0.0, (nz - .2) * 1.6) * low + max(0.0, .5 - value) * low * .8)
        us[i], vs[i], period[i] = best_u, best_v, best_period
        ranked = sorted(per_path.values(), reverse=True)
        # Where two limbs' UV frames compete (junctions), fade to a seamless projected bark instead.
        blend[i] = min(1.0, max(0.0, (ranked[1] / ranked[0] - .2) / .45)) if len(ranked) > 1 else 0.0
    vertices.foreach_set("co", coords)
    mesh = obj.data
    for name, data in (("bark_ridge", ridge), ("bark_moss", mossy), ("bark_blend", blend)):
        attribute = mesh.attributes.new(name, "FLOAT", "POINT")
        attribute.data.foreach_set("value", data)
    layer = mesh.uv_layers.new(name="UVMap")
    loop_vertex = array("i", [0]) * len(mesh.loops)
    mesh.loops.foreach_get("vertex_index", loop_vertex)
    uv = array("f", [0]) * (2 * len(mesh.loops))
    for polygon in mesh.polygons:
        start, total = polygon.loop_start, polygon.loop_total
        indices = loop_vertex[start:start + total]
        values = [us[v] for v in indices]
        wrap = period[indices[0]]
        if max(values) - min(values) > wrap * .5:  # this face straddles the angular seam
            values = [u + wrap if u < 0 else u for u in values]
        for k, v in enumerate(indices):
            uv[2 * (start + k)] = values[k]
            uv[2 * (start + k) + 1] = vs[v]
    layer.data.foreach_set("uv", uv)
    mesh.update()


def atmosphere(scene, mats, h):
    world = scene.world.node_tree
    background = world.nodes.get("Background")
    direction = world.nodes.new("ShaderNodeTexCoord")
    stretch = world.nodes.new("ShaderNodeVectorMath")
    stretch.operation = "MULTIPLY"
    stretch.inputs[1].default_value = (1, .8, 1.7)
    world.links.new(direction.outputs["Normal"], stretch.inputs[0])
    cloud = world.nodes.new("ShaderNodeTexNoise")
    cloud.inputs["Scale"].default_value = 3.4
    cloud.inputs["Detail"].default_value = 9
    cloud.inputs["Roughness"].default_value = .62
    cloud.inputs["Distortion"].default_value = .6
    world.links.new(stretch.outputs[0], cloud.inputs["Vector"])
    storm = world.nodes.new("ShaderNodeValToRGB")
    storm.color_ramp.elements[0].position = .4
    storm.color_ramp.elements[0].color = (.012, .014, .018, 1)
    storm.color_ramp.elements[1].position = .62
    storm.color_ramp.elements[1].color = (.42, .44, .47, 1)
    storm.color_ramp.elements.new(.5).color = (.07, .08, .095, 1)
    world.links.new(cloud.outputs["Fac"], storm.inputs[0])
    # Large cloud masses: darker banks and paler breaks so the sky is not one even texture.
    masses = world.nodes.new("ShaderNodeTexNoise")
    masses.inputs["Scale"].default_value = 1.1
    masses.inputs["Detail"].default_value = 3
    world.links.new(stretch.outputs[0], masses.inputs["Vector"])
    weight = world.nodes.new("ShaderNodeMapRange")
    weight.inputs["From Min"].default_value = .32
    weight.inputs["From Max"].default_value = .68
    weight.inputs["To Min"].default_value = .35
    weight.inputs["To Max"].default_value = 1.45
    world.links.new(masses.outputs["Fac"], weight.inputs["Value"])
    banks = world.nodes.new("ShaderNodeMix")
    banks.data_type = "RGBA"
    banks.blend_type = "MULTIPLY"
    sock(banks.inputs, "Factor", "VALUE").default_value = 1.0
    world.links.new(storm.outputs[0], sock(banks.inputs, "A"))
    world.links.new(weight.outputs[0], sock(banks.inputs, "B"))
    storm_out = sock(banks.outputs, "Result")
    glow_dot = world.nodes.new("ShaderNodeVectorMath")
    glow_dot.operation = "DOT_PRODUCT"
    glow_dot.inputs[1].default_value = Vector((.1, -.62, .78)).normalized()
    world.links.new(direction.outputs["Normal"], glow_dot.inputs[0])
    glow = world.nodes.new("ShaderNodeMapRange")
    glow.inputs["From Min"].default_value = .6
    glow.inputs["From Max"].default_value = 1.0
    glow.inputs["To Max"].default_value = 1.0
    world.links.new(glow_dot.outputs["Value"], glow.inputs["Value"])
    lit = world.nodes.new("ShaderNodeMix")
    lit.data_type = "RGBA"
    lit.blend_type = "SCREEN"
    world.links.new(glow.outputs[0], sock(lit.inputs, "Factor", "VALUE"))
    world.links.new(storm_out, sock(lit.inputs, "A"))
    sock(lit.inputs, "B").default_value = (.62, .66, .7, 1)
    world.links.new(sock(lit.outputs, "Result"), background.inputs["Color"])
    background.inputs["Strength"].default_value = .8
    # Thin aerial haze over the whole valley gives depth; drifting banks add intermittent mist.
    haze_mat = bpy.data.materials.new("Bellwood valley haze")
    haze_mat.use_nodes = True
    hn = haze_mat.node_tree.nodes
    hn.remove(hn.get("Principled BSDF"))
    scatter = hn.new("ShaderNodeVolumeScatter")
    scatter.inputs["Color"].default_value = (.7, .76, .82, 1)
    scatter.inputs["Density"].default_value = float(os.environ.get("VESP_HAZE", .00039))
    scatter.inputs["Anisotropy"].default_value = .3
    haze_mat.node_tree.links.new(scatter.outputs[0], hn.get("Material Output").inputs["Volume"])
    bpy.ops.mesh.primitive_cube_add(size=2, location=(0, -350, 420))
    haze = bpy.context.object
    haze.name = "Valley haze"
    haze.scale = (1500, 1500, 470)
    haze.data.materials.append(haze_mat)
    fog = bpy.data.materials.new("Bellwood drifting cliff mist")
    fog.use_nodes = True
    nodes, links = fog.node_tree.nodes, fog.node_tree.links
    nodes.remove(nodes.get("Principled BSDF"))
    mist = nodes.new("ShaderNodeVolumePrincipled")
    mist.inputs["Color"].default_value = (.68, .74, .78, 1)
    mist.inputs["Anisotropy"].default_value = .35
    noise_tex = nodes.new("ShaderNodeTexNoise")
    noise_tex.inputs["Scale"].default_value = 3.2
    noise_tex.inputs["Detail"].default_value = 4
    remap = nodes.new("ShaderNodeValToRGB")
    remap.color_ramp.elements[0].position = .42
    remap.color_ramp.elements[0].color = (0, 0, 0, 1)
    remap.color_ramp.elements[1].position = .72
    remap.color_ramp.elements[1].color = (.11, .11, .11, 1)
    coordinates = nodes.new("ShaderNodeTexCoord")
    geodistance = nodes.new("ShaderNodeVectorMath")
    geodistance.operation = "DISTANCE"
    geodistance.inputs[1].default_value = (.5, .5, .5)
    links.new(coordinates.outputs["Generated"], geodistance.inputs[0])
    falloff = nodes.new("ShaderNodeMapRange")
    falloff.clamp = True
    falloff.inputs["From Min"].default_value = .12
    falloff.inputs["From Max"].default_value = .5
    falloff.inputs["To Min"].default_value = 1
    falloff.inputs["To Max"].default_value = 0
    links.new(geodistance.outputs["Value"], falloff.inputs["Value"])
    density = nodes.new("ShaderNodeMath")
    density.operation = "MULTIPLY"
    links.new(noise_tex.outputs["Fac"], remap.inputs[0])
    links.new(remap.outputs["Color"], density.inputs[0])
    links.new(falloff.outputs[0], density.inputs[1])
    links.new(density.outputs[0], mist.inputs["Density"])
    links.new(mist.outputs["Volume"], nodes.get("Material Output").inputs["Volume"])
    for location, size in ((((95, 120, 14), (70, 110, 24)), ((-95, 130, 14), (70, 100, 22)),
                           ((250, -190, 140), (80, 60, 40)),
                           ((280, -230, 175), (95, 120, 45)), ((-215, -120, 160), (100, 130, 45)),
                           ((0, -330, 260), (260, 90, 60)), ((420, -520, 120), (200, 260, 80)),
                           ((-420, -560, 140), (220, 280, 80)), ((300, -300, 200), (120, 160, 70)),
                           ((-300, -320, 210), (120, 160, 70)),
                           # mid-ground banks either side of the upper stair and across its head
                           ((-120, 50, 52), (85, 60, 26)), ((0, -30, 108), (230, 26, 10)))
                           # thin layers that sit between the tiers, wrapping each floor line
                           + tuple(((x, y + d * .3, z + 3), (w * .62, d * .55, 7)) for x, y, z, w, d, *_ in TIERS[1:6])):
        bpy.ops.mesh.primitive_cube_add(size=2, location=location)
        obj = bpy.context.object
        obj.name = "Broken ribbons of fog"
        obj.scale = size
        obj.data.materials.append(fog)


def build_objects(temple, mats):
    for role, source in temple.meshes.items():
        if role == "Bark":
            # The grid builder duplicates end-cap vertices. Weld them so the voxel input is watertight.
            bm = source.bm
            bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0001)
            assert all(edge.is_manifold for edge in bm.edges), "Bark sweep has open ends"
        bm = source.finish()
        mesh = bpy.data.meshes.new(source.name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        if role in {"Bark", "BarkTwigs", "Masonry", "DarkStone", "Crag"}:
            mesh.shade_smooth()
        mesh.set_sharp_from_angle(angle=math.radians(31))
        obj = bpy.data.objects.new(source.name, mesh)
        obj.data.materials.append(mats[role])
        bpy.context.collection.objects.link(obj)
        if role == "Bark":
            fuse_tree(obj)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    temple = Hall()
    lamps = stonework(temple)
    for x, y, z, w, d, ht, bays, arch in TIERS:
        pavilion(temple, (x, y, z), w, d, ht, bays, arch=arch)
    galleries(temple)
    for side in (-1, 1):
        x, y, z = guardian_base(side)
        lion(temple, (x, y, z + 9.2), -side * .42, .95)
    for x, y, z in ((-34, -44, 113), (34, -44, 113), (-84, -44, 113), (84, -44, 113)):
        lamps.append(lantern(temple, (x, y, z), 1.0))
    for x in (-22, 22):  # big paper lanterns hang in the gate
        gate_lantern(temple, x, -46, 146)
        lamps.append((x, -46, 146))
    crags(temple)
    aged_tree(temple)
    traveller(temple)
    mats = art_materials()
    build_objects(temple, mats)
    scene, camera, mannequin = figures.setup_scene(samples=int(os.environ.get("VESP_RENDER_SAMPLES", 12)), cool_rim=True)
    atmosphere(scene, mats, temple)
    bpy.data.objects["Ground"].scale = (30, 30, 1)
    bpy.data.objects["Ground"].data.materials[0] = mats["Masonry"]
    bpy.data.objects.remove(mannequin, do_unlink=True)
    bpy.data.lights["overcast"].energy = 1.25
    bpy.data.lights["overcast"].color = (.72, .82, 1.0)
    bpy.data.lights["rim"].energy = 2.4
    bpy.data.lights["rim"].color = (.8, .88, .96)
    for i, position in enumerate(lamps):
        light("Temple amber " + str(i), position, (position[0], position[1] + 1, position[2] - 5), 380, 1.8, (1, .55, .2))
    for x, y, z, w in GLOWS:  # warm light inside each open gallery, aimed at the recessed hall wall
        light("Gallery glow", (x, y, z), (x, y - 40, z - 6), float(os.environ.get("VESP_GLOW", 65)) * w, w * .35,
              (1, .5, .18))
    light("Gate interior glow", (0, -60, 132), (0, -20, 128), 44000, 30.0, (1, .5, .2))
    light("Cool sky key", (300, 60, 640), (0, -150, 300), 420000, 220, (.74, .85, 1))
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 92
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.view_settings.exposure = float(os.environ.get("VESP_EXPOSURE", .7))
    camera.data.sensor_fit = "VERTICAL"
    camera.data.clip_end = 9000
    eye = Vector((-14, 347, 13.5))
    target = Vector((26, -86, 245))
    contact = min(CONTACTS, key=lambda c: (c[0] - Vector((70, 40, 50))).length)[0] if CONTACTS else Vector((70, 40, 50))
    print("Root close-up target", tuple(round(c) for c in contact), flush=True)
    views = {
        "portrait": (900, 1350, 73, eye, target),
        "approach": (1280, 900, 60, Vector((0, 208, 26)), Vector((14, -56, 172))),
        "fork": (900, 900, 46, Vector((95, -20, 500)), TRUNK[4] + Vector((0, 0, 20))),
        "root": (900, 900, 52, Vector((12, contact.y + 75, max(stair_profile((START_Y - contact.y - 75) / STEP_RUN)[2] + 14,
                                                              contact.z + 26))), contact + Vector((0, 0, 4))),
    }
    for name in os.environ.get("VESP_VIEWS", "portrait,approach,fork,root").split(","):
        width, height, angle, where, target = views[name]
        scene.render.resolution_x, scene.render.resolution_y = width, height
        scene.render.resolution_percentage = int(os.environ.get("VESP_RENDER_PERCENT", 100))
        camera.data.angle_y = math.radians(angle)
        figures.look_at(camera, where, target)
        scene.render.filepath = str(OUT / ("bellwood_stair_reference_view.jpg" if name == "portrait"
                                           else f"bellwood_stair_reference_{name}.jpg"))
        if name == "portrait":
            bpy.ops.file.pack_all()
            bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "bellwood_stair_reference.blend"))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()

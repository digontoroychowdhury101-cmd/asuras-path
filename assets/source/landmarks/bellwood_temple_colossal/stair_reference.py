"""Staging scene for the creator's stair-side Bellwood reference. Blender units = studs.

Camera convention: the portrait camera looks down -Y, so image-left is world +X.
Env knobs: VESP_RENDER_SAMPLES, VESP_TREE_VOXEL (bark union voxel size), VESP_TWIG_DEPTH, VESP_YAW (portrait turn
left, degrees), VESP_GLOW (gallery light per stud of width), VESP_HAZE, VESP_EXPOSURE,
VESP_VIEWS (comma list of views; a clay_ prefix renders that view in grey clay), VESP_CPU.
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
OUT = Path(os.environ.get("VESP_STUDY_OUT", str(Path.cwd() / "work/sol-bellwood-v10")))
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
TIPS = []  # (point, heading, radius, depth) at the ends of the finest crown wood, where the twig fringe grows
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


def root_rope(mesh, pts, rr, holds=()):
    """One load-bearing root that swells at each hold and necks between them. One or two strands peel away
    for a short span and rejoin, so gaps read without a continuous bundle of parallel cables."""
    along = [0.0]
    for a, b in zip(pts, pts[1:]):
        along.append(along[-1] + (b - a).length)
    wave, phase = RNG.uniform(26, 52), RNG.uniform(0, math.tau)
    grip = [0.0] * len(pts)
    for i in holds:  # a root thickens where it bears on stone
        for j in range(max(0, i - 3), min(len(pts), i + 2)):
            grip[j] = max(grip[j], 1 - abs(j - i) / 3.5)
    radii = [r * (.8 + .17 * math.sin(s / wave + phase) + .09 * math.sin(s / (wave * .31) + 2 * phase)
                  + .22 * max(0.0, 1 - s / 30) + .28 * g) for r, s, g in zip(rr, along, grip)]
    organic_path(mesh, BARK_PROFILE, pts, radii, SPINE)
    total = along[-1]
    for _ in range(1 if rr[0] < 6.5 else 2):
        s0 = total * RNG.uniform(.12, .55)
        span = [i for i, s in enumerate(along) if s0 <= s <= s0 + RNG.uniform(34, 70)]
        if len(span) < 4:
            continue
        sign, thin = RNG.choice((-1, 1)), RNG.uniform(.3, .42)
        ctrl, widths = [], []
        for k, i in enumerate(span):
            p = pts[i]
            t = pts[min(i + 1, len(pts) - 1)] - pts[max(0, i - 1)]
            t = t.normalized() if t.length > 1e-6 else UP
            side = t.cross(UP)
            side = side.normalized() if side.length > 1e-3 else Vector((1, 0, 0))
            out = math.sin(math.pi * k / (len(span) - 1))  # leaves the core and returns to it
            ctrl.append(p + side * sign * rr[i] * (.5 + 1.25 * out) + UP * rr[i] * .25 * out)
            widths.append(rr[i] * thin * (.75 + .25 * out))
        organic_path(mesh, circle(10), ctrl, widths, SPINE)


def path_point(points, segment, t):
    p0, p1, p2, p3 = (points[min(len(points) - 1, max(0, j))]
                      for j in range(segment - 1, segment + 3))
    return (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t**2
            + (-p0 + 3 * p1 - 3 * p2 + p3) * t**3) * .5


def curved(points, radii, sections):
    """Sample one spine for both the mesh and all the child attachments."""
    distances = [step / sections for step in range(sections)]
    path = [path_point(points, i, t) for i in range(len(points) - 1) for t in distances]
    scales = [radii[i] * (1 - t) + radii[i + 1] * t
              for i in range(len(points) - 1) for t in distances]
    return path + [points[-1]], scales + [radii[-1]]


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
    """Individual chipped blocks on a retaining-wall face that looks toward +Y. With stone=None it only
    makes the same random draws, so retiring a face does not reshuffle the tree grown after it."""
    for course in range(courses):
        x = x0 + RNG.uniform(0, 3)
        while x < x1 - 2:
            length = RNG.uniform(4.6, 8.4)
            height = RNG.uniform(2.1, 2.9)
            if RNG.random() > .06:  # missing blocks leave dark sockets
                mv = at(x + length / 2, y, top - 1.6 - course * 2.95) @ Matrix.Rotation(RNG.uniform(-.03, .03), 4, "Y")
                size, bevel = (length - .35, RNG.uniform(*rng_depth), height), RNG.uniform(.12, .5)
                if stone is not None:
                    stone.box((0, 0, 0), size, mv, bevel=bevel)
            x += length


SITE = []  # (x0, x1, y0, y1, top) solid masonry from the ground up: walls skip faces buried in it, posts stand on it
FLANKS = []  # the stair's flanking terraces, whose fronts are already coursed
# Terraces the complex climbs: A is the platform everything stands on; B, C and D step in on every side so
# each level leaves a walk behind its parapet. The upper ones keep clear of the tier galleries above them.
TERRACES = [(-252, -120, -284, -150, 112), (-262, -120, -150, -40, 112), (-120, 110, -296, -40, 112),
            (110, 254, -288, -176, 112), (110, 268, -176, -40, 112),
            (96, 248, -276, -96, 172), (-236, -96, -270, -100, 168),
            (118, 230, -262, -138, 232), (-216, -90, -256, -150, 226),
            (84, 160, -250, -182, 292)]


def inside(p, pad=0.0):
    return any(x0 + pad < p.x < x1 - pad and y0 + pad < p.y < y1 - pad and p.z < top - pad
               for x0, x1, y0, y1, top in SITE)


def footing(x, y, below):
    """Top of the highest masonry under (x, y) that is still below `below`; the ground otherwise."""
    return max((top for x0, x1, y0, y1, top in SITE if x0 <= x <= x1 and y0 <= y <= y1 and top <= below + .01),
               default=0.0)


def hall_volumes():
    """(x0, x1, y0, y1, z0, z1) of every pavilion, eaves included. A post never stands through one."""
    out = []
    for (x, y, z), w, d, ht in [((x, y, z), w, d, ht) for x, y, z, w, d, ht, *_ in TIERS] + SIDE_SHRINES:
        out.append((x - w / 2 - 5, x + w / 2 + 5, y - d * .52 - 5, y + d * .52 + 5, z - 2, z + ht + 8 + w * .15))
    return out


def beam(mesh, p, q, width, depth, bevel=.12):
    """A squared timber or stone from p to q."""
    axis = q - p
    z = axis.normalized()
    x = z.cross(UP) if abs(z.dot(UP)) < .95 else z.cross(Vector((1, 0, 0)))
    x.normalize()
    y = z.cross(x)
    mid = (p + q) / 2
    frame = Matrix(((x.x, y.x, z.x, mid.x), (x.y, y.y, z.y, mid.y), (x.z, y.z, z.z, mid.z), (0, 0, 0, 1)))
    mesh.box((0, 0, 0), (width, depth, axis.length), frame, bevel=bevel)


def rampart(h, rng, a, b, z0, z1, levels=(), walk=False, windows=False):
    """Dress one face of a masonry mass that runs from plan point a to b; the face looks to the left of a->b.
    Weathered courses lean back in lifts behind string-course ledges, buttresses and corner piers carry
    sloped caps, spouts drain each bay and stain the courses below, and a ground wall sits on bedrock."""
    stone, dark, moss, rock, wood, amber = (h.m(r) for r in ("Masonry", "DarkStone", "Moss", "Crag", "Soffit", "Lantern"))
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    length = (b - a).length
    if length < 6 or z1 - z0 < 3:
        return
    u = (b - a) / length
    n = Vector((-u.y, u.x, 0))
    frame = Matrix(((u.x, n.x, 0, a.x), (u.y, n.y, 0, a.y), (0, 0, 1, 0), (0, 0, 0, 1)))
    seed = rng.uniform(0, 100)

    def world(x, y, z):
        return frame @ Vector((x, y, z))

    def exposed(x, z, y=1.6):
        return not inside(world(x, y, z))

    if not any(exposed(length * (i + .5) / 10, z0 + (z1 - z0) * (j + .5) / 4) for i in range(10) for j in range(4)):
        return
    ground = z0 < 1
    lifts = [z0] + [z for z in levels if z0 + 8 < z < z1 - 8] + [z1]
    if len(lifts) == 2 and z1 - z0 > 50:
        count = round((z1 - z0) / 38)
        lifts = [z0 + (z1 - z0) * k / count for k in range(count + 1)]
    nl = len(lifts) - 1

    def lift_of(z):
        return min(nl - 1, max(k for k in range(nl) if lifts[k] <= z + 1e-6) if z >= lifts[0] else 0)

    def face(z):  # each lift sets back behind the ledge below it and leans back a little within itself
        k = lift_of(z)
        return 2.6 * (nl - 1 - k) + .03 * (lifts[k + 1] - z)

    def rock_top(x):
        if not ground:
            return z0 + 2.2
        swell = .5 + .5 * noise(Vector((x * .03, seed, 0)))  # outcrops the footing steps up over
        return z0 + 6 + 17 * swell ** 1.5 + 3 * noise(Vector((x * .12, seed, 3)))

    # Buttresses stand only where they work: at the corners, under a mass or hall bearing on the wall head,
    # and once in a long unloaded run. Everything between is a calm ashlar field.
    piers = []
    if length > 30:
        piers += [(4.6, 9.4, z1 - 2.6, True), (length - 4.6, 9.4, z1 - 2.6, True)]
    halls = hall_volumes()

    def loaded(x):
        p = world(x, -9, z1 + 3)
        return inside(p) or any(v[0] < p.x < v[1] and v[2] < p.y < v[3] and v[4] < z1 + 14 and v[5] > z1 for v in halls)

    x, last = rng.uniform(22, 34), 0.0
    while x < length - 22:
        if loaded(x) or x - last > 95:
            piers.append((x, rng.uniform(11, 15), z0 + (z1 - z0) * rng.uniform(.62, .86), False))
            last = x
        x += rng.uniform(30, 46)
    piers = [p for p in piers if exposed(p[0], (z0 + p[2]) / 2, 10)]
    bays = sorted([p[0] for p in piers] + [0, length])
    spouts = []
    for left, right in zip(bays, bays[1:]):
        if right - left > 13 and rng.random() < .8 and exposed((left + right) / 2, z1 - 4):
            spouts.append(((left + right) / 2 + rng.uniform(-2, 2), z1 - 4.4, rng.uniform(14, 36)))
        if nl > 2 and right - left > 13 and rng.random() < .35:
            k = rng.randrange(1, nl)
            spouts.append(((left + right) / 2 + rng.uniform(-3, 3), lifts[k] - 3.6, rng.uniform(10, 24)))
    openings = []
    if windows:
        for k in range(nl):
            if lifts[k + 1] - lifts[k] < 22:
                continue
            for left, right in zip(bays, bays[1:]):
                if right - left > 11 and rng.random() < .75:
                    w, ht = rng.uniform(3.2, 4.4), rng.uniform(6.5, 9)
                    zc = lifts[k] + (lifts[k + 1] - lifts[k]) * rng.uniform(.42, .58)
                    xc = (left + right) / 2 + rng.uniform(-2, 2)
                    if exposed(xc, zc):
                        openings.append((xc, zc, w, ht))

    rear = max(0.0, -n.y)  # the shaded back stays damp: streaks under every ledge and moss in the joints
    drips = list(spouts)
    if rear > .3:
        for k in range(nl):
            x = rng.uniform(4, 14)
            while x < length - 4:
                drips.append((x, lifts[k + 1] - 2.5, rng.uniform(10, 26) * rear))
                x += rng.uniform(9, 22)

    def wear(x, z):
        """0 in a calm ashlar field; up to 1 at the foot, under drips and against piers, where stone spalls."""
        foot = max(0.0, 1 - (z - rock_top(x)) / 16) if ground else max(0.0, 1 - (z - z0) / 7)
        wet = max(((1 - abs(x - sx) / 4) * (1 - (sz - z) / drop) for sx, sz, drop in drips
                   if sz - drop < z < sz and abs(x - sx) < 4), default=0.0)
        pier = max((1 - (abs(x - px) - pw / 2) / 5 for px, pw, ptop, _ in piers if abs(x - px) - pw / 2 < 5 and z < ptop),
                   default=0.0)
        return min(1.0, max(foot, wet, pier * .6))

    def in_pier(x0_, x1_, z):
        return any(x1_ > px - pw / 2 - .3 and x0_ < px + pw / 2 + .3 and z < ptop for px, pw, ptop, _ in piers)

    def in_opening(x0_, x1_, za, zb):
        return any(x1_ > xc - w / 2 - .7 and x0_ < xc + w / 2 + .7 and zb > zc - ht / 2 - .9 and za < zc + ht / 2 + .9
                   for xc, zc, w, ht in openings)

    # Courses: cyclopean in the bottom lift, smaller and more regular above.
    for k in range(nl):
        bottom = lifts[k] + (2.2 if k == 0 and not ground else 0)
        top = lifts[k + 1] - (2.6 if k == nl - 1 else 2.0)
        z = bottom
        while z < top - .8:
            hc = min(rng.uniform(3.4, 4.4) if k == 0 else rng.uniform(2.5, 3.3), top - z)
            x = rng.uniform(-1.5, 0)
            while x < length + .5:
                run = rng.uniform(7, 13) if k == 0 else rng.uniform(4.8, 9.5)
                x0_, x1_ = x, min(x + run, length + 1)
                x += run
                xm = (x0_ + x1_) / 2
                if in_pier(x0_, x1_, z) or in_opening(x0_, x1_, z, z + hc) or z + hc < rock_top(xm) + .6:
                    continue
                if not exposed(xm, z + hc / 2):
                    continue
                f = face(z + hc / 2)
                wv = wear(xm, z + hc / 2)
                if rng.random() < .045 * wv:  # a fallen block leaves a dark socket
                    dark.poly([world(x0_ + .2, .05, z + .2), world(x1_ - .2, .05, z + .2),
                               world(x1_ - .2, .05, z + hc - .2), world(x0_ + .2, .05, z + hc - .2)], open_surface=True)
                    continue
                # Dressed flush in the fields; worn blocks stand proud, twist and lose their arrises.
                front = f + .12 + wv * (rng.uniform(0, .35) + (.45 if rng.random() < .18 else 0))
                stained = [s for s in drips if abs(xm - s[0]) < (x1_ - x0_) / 2 + 1.1 and s[1] - s[2] < z < s[1]]
                spin = rng.uniform(-.016, .016) * wv
                stone.box((0, 0, 0), (x1_ - x0_ - .3, front + .4, hc - .22),
                          frame @ at(xm, (front - .4) / 2, z + hc / 2) @ Matrix.Rotation(spin, 4, "Z"),
                          bevel=.18 + wv * rng.uniform(0, .35))
                if rear and rng.random() < rear * (.08 + .5 * wv):  # moss in the bed joint along the block's head
                    moss.poly([world(x0_ + .3, front + .06, z + hc - 1.3), world(x1_ - .3, front + .06, z + hc - .9),
                               world(x1_ - .3, front + .06, z + hc - .12), world(xm, front + .06, z + hc - .05),
                               world(x0_ + .3, front + .06, z + hc - .12)], open_surface=True)
                for sx, sz, drop in stained:  # wet streak under a spout, fading as it runs down
                    if rng.random() < (z - (sz - drop)) / drop + .25:
                        l, r = max(x0_ + .3, sx - 1.3), min(x1_ - .3, sx + 1.3)
                        if r - l > .4:
                            dark.poly([world(l, front + .04, z + .2), world(r, front + .04, z + .2),
                                       world(r, front + .04, z + hc - .3), world(l, front + .04, z + hc - .3)],
                                      open_surface=True)
            z += hc
        # A scoured string course, or the cornice at the top, sits at the head of each lift.
        head = lifts[k + 1]
        x = -1.2
        while x < length + 1:
            run = rng.uniform(6, 14)
            xm = x + run / 2
            x += run
            if rng.random() < .07 or not exposed(xm, head - 1):
                continue
            if k == nl - 1:
                reach, tall, lift = face(head - 1) + rng.uniform(2.2, 3.2), 2.6, .6
            else:
                reach, tall, lift = face(head - 1) + rng.uniform(1.3, 2.6), 2.0, 0
            stone.box((0, 0, 0), (run - .25, reach + .6, tall),
                      frame @ at(xm, (reach - .6) / 2, head - tall / 2 + lift) @ Matrix.Rotation(rng.uniform(-.01, .01), 4, "Y"),
                      bevel=rng.uniform(.4, .8))
            if rng.random() < .25 + .5 * rear:  # cushions on the ledge; on the damp back they spill over its lip
                s = 1 + 2.4 * rear + rng.uniform(0, 1.2)
                cx, cy = xm + rng.uniform(-run / 3, run / 3), reach - rng.uniform(.6, 1.6)
                moss.poly([world(cx + dx * s, min(reach - .1, cy + dy * s * .5), head + lift + .03) for dx, dy in
                           ((-1.6, -.4), (-.2, -.7), (1.7, -.2), (.6, .5), (-1, .4))], open_surface=True)
                if rear > .3:
                    hang = head + lift - tall + .15  # down the ledge's own front, never into the air below it
                    moss.poly([world(cx - 1.5 * s, reach + .05, head + lift - .2), world(cx + 1.5 * s, reach + .05, head + lift - .2),
                               world(cx + .9 * s, reach + .05, hang + .6), world(cx, reach + .05, hang),
                               world(cx - 1.1 * s, reach + .05, hang + .9)], open_surface=True)
    if not ground:  # footing course where the wall stands on a lower terrace
        x = -1
        while x < length + 1:
            run = rng.uniform(8, 15)
            xm = x + run / 2
            x += run
            if exposed(xm, z0 + 1.1):
                reach = face(z0 + 1) + 1.8
                stone.box((0, 0, 0), (run - .3, reach + .6, 2.2), frame @ at(xm, (reach - .6) / 2, z0 + 1.1),
                          bevel=.5)
    # Buttress piers in stages, each stage narrower and shallower under a sloped weathering cap.
    for px, pw, ptop, corner in piers:
        base = rock_top(px) - 1.2
        stages = 3 if ptop - base > 50 else 2
        for s in range(stages):
            za, zb = base + (ptop - base) * s / stages, base + (ptop - base) * (s + 1) / stages
            w = pw - 1.6 * s
            reach = face(za + 1) + (6.4 if corner else rng.uniform(5.5, 7.5)) - 1.9 * s
            z = za
            while z < zb - .5:
                hc = min(rng.uniform(3.8, 4.8), zb - z)
                quoin = rng.uniform(-.6, .6)
                stone.box((0, 0, 0), (w + quoin, reach + .3 + rng.uniform(0, .3), hc - .14),
                          frame @ at(px + quoin * .3, (reach - .3) / 2, z + hc / 2), bevel=rng.uniform(.35, .6))
                z += hc
            back = face(zb) + .3
            rise = (reach - back) * .7
            stone.prism([(back - .3, 0), (reach + .3, 0), (reach + .3, .7), (back - .3, rise + .7)], (), w + .3,
                        frame @ Matrix(((0, 0, 1, px - (w + .3) / 2), (1, 0, 0, 0), (0, 1, 0, zb), (0, 0, 0, 1))))
    for sx, sz, drop in spouts:
        f = face(sz)
        tip = f + 4.6
        stone.box((0, 0, 0), (2.5, tip + .5, 1.7), frame @ at(sx, (tip - .5) / 2, sz) @ Matrix.Rotation(-.1, 4, "X"),
                  bevel=.3)
        dark.box((0, 0, 0), (1.0, tip, .3), frame @ at(sx, tip / 2, sz + .78) @ Matrix.Rotation(-.1, 4, "X"))
        foot = rock_top(sx) if sz - drop < rock_top(sx) + 12 else None
        if foot is not None:  # splash stone and moss where the water lands
            stone.box((0, 0, 0), (5, 4, .9), frame @ at(sx, face(foot) + 3, foot + .3), bevel=.3)
            for _ in range(4):
                cx, cy = sx + rng.uniform(-3, 3), face(foot) + rng.uniform(1, 6)
                moss.poly([world(cx + dx, cy + dy, foot + .82) for dx, dy in ((-1, -.5), (.3, -.8), (1.1, .2), (-.2, .9))],
                          open_surface=True)
    for xc, zc, w, ht in openings:  # deep lattice windows; a few are lit from inside
        f = face(zc)
        dark.poly([world(xc - w / 2, .06, zc - ht / 2), world(xc + w / 2, .06, zc - ht / 2),
                   world(xc + w / 2, .06, zc + ht / 2), world(xc - w / 2, .06, zc + ht / 2)], open_surface=True)
        if rng.random() < .3:
            amber.box((0, 0, 0), (w - .4, .2, ht - .4), frame @ at(xc, .35, zc))
        for i in range(1, 3):
            wood.box((0, 0, 0), (.35, f * .5 + .6, ht), frame @ at(xc - w / 2 + w * i / 3, f * .5, zc))
        wood.box((0, 0, 0), (w, f * .5 + .6, .35), frame @ at(xc, f * .5, zc))
        for zz, tall in ((zc + ht / 2 + .9, 1.8), (zc - ht / 2 - .6, 1.2)):  # lintel and sill
            stone.box((0, 0, 0), (w + 2.6, f + 1.3, tall), frame @ at(xc, (f + .5) / 2, zz), bevel=.25)
        for s in (-1, 1):  # jambs
            stone.box((0, 0, 0), (1.1, f + .9, ht + .4), frame @ at(xc + s * (w / 2 + .55), (f + .3) / 2, zc), bevel=.2)
    if ground:  # bedrock the lowest courses sit on, falling away to soil and broken stone
        rows = []
        for i in range(int((length + 12) / 3.2) + 1):
            x = -6 + i * 3.2
            r = rock_top(x)
            f = face(r)
            jit = [noise(Vector((x * .09 + j * 7.1, seed, j))) * .6 + noise(Vector((x * .31, seed + j, 9))) * .5
                   for j in range(6)]  # broad swells plus sharp facets
            body = r - z0
            rows.append([world(x, -1.5, r - 3), world(x, f + .6, r + .4 * jit[0]),
                         world(x, f + 2.2 + 1.5 * jit[1], r - 1.2 - 1.5 * abs(jit[2])),  # weathered lip
                         world(x, f + 3.4 + 2.5 * jit[3], z0 + body * .62),  # near-vertical rock face
                         world(x, f + 5.5 + 3 * jit[4], z0 + body * .3 + 1.2 * jit[5]),
                         world(x, f + 10 + 4 * jit[5], z0 + 2.2 + 1.5 * abs(jit[1])),  # soil and scree
                         world(x, f + 17 + 5 * jit[4], z0 + .4), world(x, f + 24 + 5 * jit[0], z0 - 1.5)])
        rock.grid(rows, None, expect=Vector((n.x, n.y, 1)), open_surface=True)
        x = 0
        while x < length:
            x += rng.uniform(4, 10)
            if not exposed(x, z0 + 2, 18):
                continue
            size = rng.uniform(1.3, 4.6)
            y = face(z0) + rng.uniform(13, 24)
            stone.box((0, 0, 0), (size * rng.uniform(.8, 1.6), size, size * .55),
                      frame @ at(x, y, z0 + size * .2) @ Matrix.Rotation(rng.uniform(-3, 3), 4, "Z")
                      @ Matrix.Rotation(rng.uniform(-.3, .3), 4, "X"), bevel=size * .14)
            leaf = h.m("Moss" if rng.random() < .6 else "MapleDeep")
            for _ in range(3):
                cx, cy = x + rng.uniform(-4, 4), y + rng.uniform(-3, 4)
                leaf.poly([world(cx + dx, cy + dy, z0 + .06) for dx, dy in ((-1, -.3), (.2, -.6), (1, 0), (.4, .6))],
                          open_surface=True)
    if walk:  # parapet balustrade along the walk on top; a few runs have fallen
        posts = []
        x = 2.5
        while x < length - 2:
            if exposed(x, z1 + 2.5, -2) and rng.random() > .05:
                posts.append(x)
            x += rng.uniform(5.2, 6.2)
        run = []
        for x in posts + [None]:
            if x is not None and (not run or x - run[-1] < 6.8):
                run.append(x)
                stone.box((0, 0, 0), (1.5, 1.5, 3.9), frame @ at(x, -1.7, z1 + .6 + 1.95), bevel=.2)
                stone.lathe([(1.0, 0), (.8, .35), (.4, .8), (0, 1.25)], 8, frame @ at(x, -1.7, z1 + 4.5))
                continue
            if len(run) > 1:
                for zz, size in ((z1 + 4.1, .52), (z1 + 2.2, .36)):
                    stone.sweep([(-size, -size * .8), (size, -size * .8), (size, size * .8), (-size, size * .8)],
                                [world(xx, -1.7, zz) for xx in run])
            run = [x] if x is not None else []
            if x is not None:
                stone.box((0, 0, 0), (1.5, 1.5, 3.9), frame @ at(x, -1.7, z1 + .6 + 1.95), bevel=.2)


def timber_face(h, rng, a, b, z0, z1, levels=(), capped=False, reach=15.0, bay=13.0, corner=2.3, band=7.5,
                balcony=0.0, split=44.0):
    """A timber-framed storey wall on the spine above the masonry: posts and beams, closed plank panels,
    a dark lattice band and a tiled pent eave on brackets at every storey line (two per storey taller than
    `split`), so the back reads as stacked layered eaves like the front. `balcony` is the depth of a railed
    walk on brackets at the foot of the wall."""
    post, plank, tile, dark, amber = (h.m(r) for r in ("Lacquer", "Soffit", "Tile", "DarkStone", "Lantern"))
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    length = (b - a).length
    if length < 6 or z1 - z0 < 6:
        return
    u = (b - a) / length
    n = Vector((-u.y, u.x, 0))
    frame = Matrix(((u.x, n.x, 0, a.x), (u.y, n.y, 0, a.y), (0, 0, 1, 0), (0, 0, 0, 1)))

    def world(x, y, z):
        return frame @ Vector((x, y, z))

    def exposed(x, z, y=1.6):
        return not inside(world(x, y, z))

    if not any(exposed(length * (i + .5) / 10, z0 + (z1 - z0) * (j + .5) / 4) for i in range(10) for j in range(4)):
        return
    bays = max(1, round(length / bay))
    xs = [length * k / bays for k in range(bays + 1)]
    storeys = [z0] + [z for z in levels if z0 + 10 < z < z1 - 10] + [z1]
    for x in xs:
        if exposed(x, (z0 + z1) / 2, 3):
            w = corner if x in (xs[0], xs[-1]) else 2.3
            post.box((0, 0, 0), (w, w, z1 - z0), frame @ at(x, w / 2, (z0 + z1) / 2), bevel=.15)
    if balcony and exposed(length / 2, z0 + 6, balcony):
        # Deck on raking struts. Each face's deck takes the corner square at its start, and the rails run
        # corner to corner, so four faces close round the stage without overlapping.
        deck, edge = z0 + 2.5, balcony - .6
        plank.box((0, 0, 0), (length + balcony, balcony, 1.2), frame @ at((length - balcony) / 2, balcony / 2, deck),
                  bevel=.1)
        x = -edge
        while x < length + edge + .1:
            post.box((0, 0, 0), (.8, .8, 4.4), frame @ at(x, edge, deck + 2.8), bevel=.08)
            x += (length + 2 * edge) / max(1, round((length + 2 * edge) / 5))
        for zz in (deck + 2.4, deck + 4.8):
            post.sweep([(-.35, -.3), (.35, -.3), (.35, .3), (-.35, .3)], [world(-edge, edge, zz), world(length + edge, edge, zz)])
        for x in xs:
            beam(plank, world(x, .4, deck - 6.5), world(x, balcony - 1, deck - .6), .9, .9)
    registers = []
    for za, zb in zip(storeys, storeys[1:]):  # tall storeys get a second eave so eaves keep the tiers' rhythm
        last = zb < z1 - 1 or capped
        if zb - za > split:
            cut = (za + zb) / 2
            registers += [(za, cut, True), (cut, zb, last)]
        else:
            registers.append((za, zb, last))
    for ra, rb, eave in registers:
        for zz, tall in ((ra + 1, 2.0), (rb - 2.2, 2.4)):  # sill and head beams
            plank.box((0, 0, 0), (length + 2, 1.6, tall), frame @ at(length / 2, 1.4, zz), bevel=.15)
        head = rb - (9 if eave else 3)  # the lattice band stops under the eave
        for left, right in zip(xs, xs[1:]):
            mid, span = (left + right) / 2, right - left - 2.6
            if not exposed(mid, (ra + rb) / 2):
                continue
            panel = head - band - 1 - (ra + 2.2)
            base, kind = ra + 2.2, rng.random()
            if panel > 7 and kind < .62:  # an opening in a frame: lattice window or shutters, a few lit inside
                ow, oz0, oz1 = span - 1.8, base + panel * (.22 if panel > 12 else .1), base + panel - .8
                zc = (oz0 + oz1) / 2
                plank.box((0, 0, 0), (span, .5, oz0 - base), frame @ at(mid, .3, (base + oz0) / 2))
                for zz in (oz0 - .4, oz1 + .4):  # sill and lintel
                    plank.box((0, 0, 0), (ow + 1.8, 1.3, .8), frame @ at(mid, .65, zz), bevel=.1)
                for s in (-1, 1):  # jambs
                    plank.box((0, 0, 0), (.9, 1.1, oz1 - oz0), frame @ at(mid + s * (ow / 2 + .45), .55, zc), bevel=.08)
                (amber if rng.random() < .2 else dark).box((0, 0, 0), (ow, .2, oz1 - oz0), frame @ at(mid, .12, zc))
                if kind < .34:  # lattice of thin square bars
                    cols, rows = max(2, round(ow / 1.7)), max(2, round((oz1 - oz0) / 1.7))
                    for j in range(1, cols):
                        plank.box((0, 0, 0), (.28, .45, oz1 - oz0), frame @ at(mid - ow / 2 + ow * j / cols, .45, zc))
                    for j in range(1, rows):
                        plank.box((0, 0, 0), (ow, .45, .28), frame @ at(mid, .45, oz0 + (oz1 - oz0) * j / rows))
                else:  # two louvred leaves, some swung out on their hinges
                    leaf = ow / 2
                    for s in (-1, 1):
                        hinge = frame @ at(mid + s * ow / 2, .5, zc) @ Matrix.Rotation(-s * rng.choice((0, 0, 1.1, 1.4)), 4, "Z")
                        plank.box((0, 0, 0), (leaf - .1, .35, oz1 - oz0 - .2), hinge @ at(-s * leaf / 2, 0, 0))
                        for j in range(int((oz1 - oz0 - 1) / 1.1)):
                            plank.box((0, 0, 0), (leaf - .6, .25, .6),
                                      hinge @ at(-s * leaf / 2, .3, oz0 - zc + .8 + j * 1.1) @ Matrix.Rotation(.5, 4, "X"))
            elif panel > 2:  # closed boards inside a raised frame, some braced
                plank.box((0, 0, 0), (span, .5, panel), frame @ at(mid, .3, base + panel / 2))
                for zz in (base + .5, base + panel - .5, base + panel * rng.uniform(.4, .6)):
                    plank.box((0, 0, 0), (span, 1.0, .9), frame @ at(mid, .6, zz), bevel=.08)
                for s in (-1, 1):
                    plank.box((0, 0, 0), (.9, 1.0, panel), frame @ at(mid + s * (span / 2 - .45), .6, base + panel / 2), bevel=.08)
                if rng.random() < .5:
                    beam(plank, world(mid - span / 2 + .9, .7, base + .9), world(mid + span / 2 - .9, .7, base + panel - .9), .7, .5)
            lo, hi = head - band, head - .8
            dark.box((0, 0, 0), (span, .2, hi - lo), frame @ at(mid, .15, (lo + hi) / 2))
            for j in range(1, 6):
                plank.box((0, 0, 0), (.3, .5, hi - lo), frame @ at(left + 1.3 + span * j / 6, .6, (lo + hi) / 2))
            for j in range(1, 3):
                plank.box((0, 0, 0), (span, .5, .3), frame @ at(mid, .6, lo + (hi - lo) * j / 3))
        if not eave:
            continue
        # Pent eave: concave, flared up at the corners and mitred so neighbouring faces meet. It breaks
        # round anything built against the wall, such as a projecting bay, and runs on either side of it.
        runs, rows = [], []
        x = -reach
        while x <= length + reach + .01:
            start = max(-.5, -x, x - length)
            if start < reach - 2 and exposed(min(max(x, .5), length - .5), rb - 2, 4):
                lift = max(0.0, min(1.0, 1 - min(x, length - x) / 14))
                row = []
                for j in range(4):
                    y = start + (reach - start) * j / 3
                    fall = 6.5 * reach / 15 * (1 - max(0.0, 1 - y / reach) ** 1.8)  # deeper eaves pitch lower
                    row.append(world(x, y, rb + 1 - fall + 3.4 * lift ** 2 * (y / reach) ** 2))
                rows.append(row)
            elif rows:
                runs.append(rows)
                rows = []
            x += 3
        runs.append(rows)
        for rows in runs:
            if len(rows) < 2:
                continue
            tile.grid(rows, None, expect=Vector((n.x, n.y, 1)), open_surface=True)
            plank.grid([[p - Vector((0, 0, .8)) for p in row] for row in rows], None, expect=Vector((0, 0, -1)),
                       open_surface=True)
            for row in rows:  # half-round tile runs down the slope
                tile.sweep(circle(5), [p + Vector((0, 0, .3)) for p in row[1:]], scales=[.6] * 3)
            plank.sweep([(-.5, -.7), (.5, -.7), (.5, .7), (-.5, .7)], [row[-1] - Vector((0, 0, .9)) for row in rows])
        for x in xs:  # bracket arms under the eave at each post; deeper eaves get a fourth arm
            if exposed(x, rb - 4, 3):
                for j in range(3 if reach < 17 else 4):
                    plank.box((0, 0, 0), (2.0, 2.6 + 2.4 * j, 1.1), frame @ at(x, 1.3 + 1.2 * j, rb - 4.4 + 1.3 * j),
                              bevel=.1)


def mass_faces(x0, x1, y0, y1):
    """The four faces of a plan rectangle as (a, b) runs with the outside on the left."""
    return (((x0, y1), (x1, y1)), ((x1, y1), (x1, y0)), ((x1, y0), (x0, y0)), ((x0, y0), (x0, y1)))


def face_floor(a, b, top):
    """Lowest support met just outside a face: the wall runs down to it."""
    a, b = Vector(a), Vector(b)
    u = (b - a).normalized()
    out = Vector((-u.y, u.x)) * 1.5
    return min(footing(p.x, p.y, top - 1) for p in (a.lerp(b, t) + out for t in (.1, .3, .5, .7, .9)))


def spine_stages():
    """Masonry stages behind the stack that carry each tier's back and flanks: a lower box flush with the
    stage in front, and an upper box kept behind the tier below so its rear gallery stays open."""
    stages = []
    for i in range(1, len(TIERS)):
        tx, ty, tz, tw, td, *_ = TIERS[i]
        px, py, pz, pw, pd, *_ = TIERS[i - 1]
        hx, hy = tw * .412, td * .388
        rear = ty - hy + 3
        prev_back = py - pd * .388 - 3.5
        prev_rear = py - pd * .388 + 3 if i > 1 else prev_back - 1
        x0, x1 = tx - hx + 3, tx + hx - 3
        if i > 1:
            stages.append((x0, x1, rear, prev_rear, pz - 12, 112, True))  # its head is a storey line: eave it
        stages.append((x0, x1, rear, prev_back - 1, tz - 12, pz - 12 if i > 1 else 112, False))
    return stages


SPINE_STONE = 179  # the spine is masonry up to the first tier's floor band and a timber frame above it
# The back of the stack rises as a tower: each stage narrower and set back behind the deep eave of the one
# below, with no two alike. It stands in front of the tiers' spine columns and carries the top tier.
# (x0, x1, y0, y1, bottom, top, eave reach, post bay, lattice band, balcony depth, split height)
TOWER = [(-66, 110, -296, -224, 112, 179, 0, 0, 0, 0, 0),  # masonry base with a walk behind its parapet
         (-54, 102, -286, -224, 179, 236, 21, 15.5, 9, 0, 44),  # double-eaved hall storey
         (12, 46, -295, -285, 179, 226, 9, 8.5, 4, 0, 99),  # bay projecting on the rear axis through the lower eave
         (-42, 95, -276, -224, 236, 288, 17, 11, 6, 7, 99),  # gallery storey ringed by a balcony
         (-32, 88, -268, -224, 288, 332, 11, 16, 3.5, 0, 99),  # low closed storey under a shallow eave (shrine close by)
         (-20, 82, -261, -224, 332, 390, 18, 10, 14, 4, 99)]  # tall lattice storey with a narrow walk


def weathered_footings(h):
    """The terraces and the stepped spine the tiers stand on, dressed on every exposed face."""
    stone, plank = h.m("Masonry"), h.m("Soffit")
    rng = random.Random(872)
    stages = spine_stages()
    for x0, x1, y0, y1, top in TERRACES:
        SITE.append((x0, x1, y0, y1, top))
        stone.box(((x0 + x1) / 2, (y0 + y1) / 2, top / 2), (x1 - x0, y1 - y0, top))
    for x0, x1, y0, y1, top, bottom, _ in stages:
        SITE.append((x0, x1, y0, y1, top))
        for lo, hi, mesh in ((bottom, min(top, SPINE_STONE), stone), (max(bottom, SPINE_STONE), top, plank)):
            if hi > lo:
                mesh.box(((x0 + x1) / 2, (y0 + y1) / 2, (lo + hi) / 2), (x1 - x0, y1 - y0, hi - lo))
    for x0, x1, y0, y1, bottom, top, *_ in TOWER:
        SITE.append((x0, x1, y0, y1, top))
        (stone if top <= SPINE_STONE else plank).box(((x0 + x1) / 2, (y0 + y1) / 2, (bottom + top) / 2),
                                                     (x1 - x0, y1 - y0, top - bottom))
    for x0, x1, y0, y1, bottom, top, reach, bay, band, balcony, split in TOWER:
        for a, b in mass_faces(x0, x1, y0, y1):
            z0 = max(bottom, face_floor(a, b, top))
            if top <= SPINE_STONE:
                rampart(h, rng, a, b, z0, top, walk=True, windows=True)
            else:
                timber_face(h, rng, a, b, z0, top, (), True, reach, bay, 3.6, band, balcony, split)
    floors = [z - 12 for *_, z, _w, _d, _h, _b, _a in TIERS[1:]]
    for x0, x1, y0, y1, top in TERRACES:
        for a, b in mass_faces(x0, x1, y0, y1):
            rampart(h, rng, a, b, face_floor(a, b, top), top, walk=True)
    for x0, x1, y0, y1, top, bottom, capped in stages:
        for a, b in mass_faces(x0, x1, y0, y1):
            z0 = max(bottom, face_floor(a, b, top))
            if z0 < SPINE_STONE:
                rampart(h, rng, a, b, z0, min(top, SPINE_STONE), windows=True)
            if top > SPINE_STONE:
                timber_face(h, rng, a, b, max(z0, SPINE_STONE), top, floors, capped)
    for x0, x1, y0, y1, top in FLANKS:
        for a, b in mass_faces(x0, x1, y0, y1)[1:]:
            rampart(h, rng, a, b, face_floor(a, b, top), top)
    # Terrace walks: moss gathers in the damp lee of walls, leaves drift, a few blocks have fallen from above.
    moss, litter = h.m("Moss"), h.m("MapleDeep")
    halls = hall_volumes()
    for x0, x1, y0, y1, top in TERRACES:
        for gx in range(int(x0) + 4, int(x1) - 3, 7):
            for gy in range(int(y0) + 4, int(y1) - 3, 7):
                x, y = gx + rng.uniform(-3, 3), gy + rng.uniform(-3, 3)
                if inside(Vector((x, y, top + .5))) or any(v[0] < x < v[1] and v[2] < y < v[3] and v[4] < top + 3
                                                         for v in halls):
                    continue
                damp = .5 + .5 * noise(Vector((x * .035, y * .035, top * .01)))
                if rng.random() < damp * .7:
                    leaf = moss if rng.random() < .7 else litter
                    for _ in range(rng.randrange(2, 6)):
                        cx, cy, r = x + rng.uniform(-3, 3), y + rng.uniform(-3, 3), rng.uniform(.6, 1.9)
                        leaf.poly([Vector((cx + dx * r, cy + dy * r, top + .05)) for dx, dy in
                                   ((-1, -.3), (-.2, -.8), (.9, -.4), (1, .3), (-.1, .8))], open_surface=True)
                if rng.random() < .05:
                    size = rng.uniform(1.6, 4.2)
                    stone.box((0, 0, 0), (size * 1.4, size, size * .6), at(x, y, top + size * .25)
                              @ Matrix.Rotation(rng.uniform(-3, 3), 4, "Z") @ Matrix.Rotation(rng.uniform(-.2, .2), 4, "X"),
                              bevel=size * .14)


def kakezukuri(h, rng, posts, top):
    """Posts on stone pads under a floor edge, tied with through-beams and braced in alternate bays.
    posts: [(x, y, foot)] in order along one edge."""
    wood, stone = h.m("Soffit"), h.m("Masonry")
    for x, y, foot in posts:
        stone.box((x, y, foot + .8), (4.2, 4.2, 1.6), bevel=.35)
        wood.box((x, y, (foot + 1.6 + top) / 2), (2.5, 2.5, top - foot - 1.6), bevel=.15)
    for (xa, ya, fa), (xb, yb, fb) in zip(posts, posts[1:]):
        span = math.hypot(xb - xa, yb - ya)
        if span > 26:
            continue
        low = max(fa, fb) + 9
        levels = [z for z in [low + 13 * k for k in range(12)] if z < top - 5] + [top - 2.6]
        for z in levels:
            beam(wood, Vector((xa, ya, z)), Vector((xb, yb, z)), 1.5, 1.9)
        if rng.random() < .6 and len(levels) > 1:  # one brace per bay, not an X in every panel
            beam(wood, Vector((xa, ya, levels[0])), Vector((xb, yb, levels[1] if len(levels) > 2 else levels[-1])),
                 1.3, 1.3)


def floor_supports(h, rng, x, y, z, w, d, bays, carriers=()):
    """Hold a pavilion floor up by what is really under each column line: bracket sets and struts off a
    masonry face within reach, timber posts down to a terrace, or nothing where a lower hall carries it."""
    wood, so, stone, lacquer = (h.m(r) for r in ("Soffit", "Soffit", "Masonry", "Lacquer"))
    hx, hy = w * .412, d * .388
    halls = [v for v in hall_volumes() if v[4] < z - 3]  # halls standing lower than this floor
    side_bays = max(2, round(bays * hy / hx))
    edges = (  # (column positions along the edge, outward)
        ([(x - hx + 2 * hx * k / bays, y + hy) for k in range(bays + 1)], Vector((0, 1, 0))),
        ([(x + hx, y + hy - 2 * hy * k / side_bays) for k in range(side_bays + 1)], Vector((1, 0, 0))),
        ([(x + hx - 2 * hx * k / bays, y - hy) for k in range(bays + 1)], Vector((0, -1, 0))),
        ([(x - hx, y - hy + 2 * hy * k / side_bays) for k in range(side_bays + 1)], Vector((-1, 0, 0))))
    for points, out in edges:
        posts = []
        for px, py in points:
            col = Vector((px, py, z - 13))
            foot = footing(px, py, z - 2)
            if z - 1.6 - foot < 4:
                stone.box((px, py, (foot + z - 1.6) / 2), (5, 5, max(.5, z - 1.6 - foot)), bevel=.4)
                continue
            if any(v[0] < px < v[1] and v[2] < py < v[3] for v in halls):
                continue  # the hall below carries this line
            # The masonry face this column line overhangs, if one is within bracket reach.
            reach = next((r for r in (3.3, 4.5, 6, 8, 10, 12) if inside(col - out * r)), None)
            if z - foot > 42 and reach is not None:  # cantilever: stepped bracket arms off the wall head, a strut
                wall_face = col - out * (reach - 1.0)
                turn = Matrix.Rotation(math.atan2(-out.x, out.y), 4, "Z")
                for k in range(4):
                    arm = 2.5 + (reach + 2.5) * (k + 1) / 4
                    lacquer.box((0, 0, 0), (2.0, arm, 1.4), at(*(wall_face + out * (arm / 2 - 1.2) + UP * (1.6 + k * 2.1)))
                                @ turn, bevel=.14)
                    so.box((0, 0, 0), (2.6, 2.6, .9), at(*(wall_face + out * (arm - 1.4) + UP * (2.7 + k * 2.1))), bevel=.12)
                knee = wall_face - UP * 16
                if not inside(knee + out * 1.6):
                    stone.box((0, 0, 0), (3.2, 3.2, 3.2), at(*(knee + out * 1.2)), bevel=.4)  # corbel
                    beam(wood, knee + out * 1.6 + UP, col + out * 2.6 + UP * 10.6, 1.7, 1.7)
                continue
            posts.append((px, py, foot))
        if posts:
            kakezukuri(h, rng, posts, z - 1.6)
    # Rim beam and joist ends round the deck edge.
    for points, out in edges:
        p, q = Vector((*points[0], z - 2.8)) + out * 3.2, Vector((*points[-1], z - 2.8)) + out * 3.2
        beam(lacquer, p, q, 1.6, 2.4, bevel=.2)


def tier_supports(h):
    rng = random.Random(4413)
    for x, y, z, w, d, ht, bays, _ in TIERS[1:]:
        floor_supports(h, rng, x, y, z, w, d, bays)


def stonework(h):
    stair, moss, leaf = (h.m(role) for role in ("Masonry", "Moss", "MapleDeep"))
    SITE.clear()
    FLANKS.clear()
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
            SITE.append((x0, x1, back, front, top))
            FLANKS.append((x0, x1, back, front, top))
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
    SITE.append((-125, 125, -128, -40, z))
    # The old cliff steps and the bare cores under the tiers are replaced by dressed terraces and a stepped
    # spine. Their coursed faces are only replayed as random draws so the tree grown later keeps its shape.
    for x0, x1 in ((96, 250), (92, 270), (70, 250), (40, 200), (-240, -96), (-250, -92), (-220, -70)):
        coursed_face(None, x0, x1, 0, 0, 9)
    weathered_footings(h)
    tier_supports(h)
    return lamps


GLOWS = []  # (x, y, z, width) warm light inside each gallery


def gallery_tier(h, half_x, half_y, bottom, top, bays, radius):
    """Colonnade on all four faces around a recessed hall: railings, bracket sets, lattice transoms, shutters.
    The front keeps the gold and most lanterns; the flanks are plainer and the back is closed and worn."""
    wood, so, stone, gold, amber = (h.m(role) for role in ("Lacquer", "Soffit", "Masonry", "Gold", "Lantern"))
    height = top - bottom
    core = half_y * .45
    inner_width = half_x * .68
    so.box((0, 0, bottom + height / 2), (inner_width * 2, core * 2, height - 1), bevel=.3)
    stone.box((0, 0, bottom - .7), (half_x * 2 + 7, half_y * 2 + 7, 1.6), bevel=.3)
    so.box((0, 0, top - 1.6), (half_x * 2 + 2, half_y * 2 + 2, 1.4), bevel=.2)  # gallery ceiling
    side_bays = max(2, round(bays * half_y / half_x))
    # (turn, half length, depth to the column line, core half length, core depth, bays, dress). Each face skips
    # its last column: the next face round sets that corner.
    faces = ((math.pi, half_x, half_y, inner_width, core, bays, "rear"),
             (0.0, half_x, half_y, inner_width, core, bays, "front"),
             (-math.pi / 2, half_y, half_x, core, inner_width, side_bays, "side"),
             (math.pi / 2, half_y, half_x, core, inner_width, side_bays, "side"))
    for f, (turn, length, depth, core_len, core_depth, n, dress) in enumerate(faces):
        turn_m = Matrix.Rotation(turn, 4, "Z")

        def F(x, y, z):
            return turn_m @ at(x, y, z)

        front = dress == "front"
        columns = [-length + 2 * length * i / n for i in range(n + 1)]
        for i, x in enumerate(columns):
            if i < n:
                stone.lathe([(radius * 1.65, 0), (radius * 1.65, .7), (radius * 1.28, 1.35), (radius * 1.2, 2.1)],
                            14, F(x, depth, bottom))
                wood.lathe([(radius, 0), (radius * .94, 2.1), (radius * .81, height - 3), (radius * 1.1, height)],
                           14, F(x, depth, bottom + 1.1))
                for z in ((bottom + 3.2, top - 3.1) if dress != "rear" else (top - 3.1,)):
                    gold.lathe([(radius * 1.03, 0), (radius * 1.03, .6)], 14, F(x, depth, z))
            for b in range(4):  # stepped bracket set carrying the eave
                z = top + b * 1.6
                so.box((0, 0, 0), (5.6 + b * 3.1, 7 + b * 2.4, 1.28), F(x, depth + b * .9, z), bevel=.18)
                wood.box((0, 0, 0), (2.42, 8.7, 1.08), F(x, depth + 4 + b * 1.35, z + .32), bevel=.13)
            for s in (-1, 1):  # cloud braces under the lintel
                wood.box((0, 0, 0), (1.1, 1.4, 6.5), F(x + s * (radius + 2.2), depth, top - 5.2)
                         @ Matrix.Rotation(s * .62, 4, "Y"), bevel=.12)
            if abs(x) < core_len - 1:  # posts frame the hall wall behind the gallery
                so.box((0, 0, 0), (1.3, .9, height - 1.4), F(x, core_depth + .35, bottom + height / 2), bevel=.1)
            if i == n:
                continue
            middle = (x + columns[i + 1]) / 2
            span = columns[i + 1] - x - radius * 2
            for b in range(3):  # a lighter bracket set between the columns
                so.box((0, 0, 0), (3.4 + b * 2.2, 5 + b * 1.8, 1.1), F(middle, depth + b * .8, top + b * 1.5), bevel=.15)
            so.box((0, 0, 0), (span, .7, 4.4), F(middle, depth - .5, top - 4.6), bevel=.1)  # lattice transom
            for k in range(1, 9):
                wood.box((0, 0, 0), (.38, .5, 4.2), F(middle - span / 2 + span * k / 9, depth - .05, top - 4.6))
            if dress != "rear":
                gold.box((0, 0, 0), (span, .45, .5), F(middle, depth + .05, top - 7.1), bevel=.05)
            local = random.Random(2101 + i + bays * 11 + 977 * f)
            # Hall-wall shutters: every bay is shut at the back, alternate bays elsewhere. Bars are gilt in front.
            if i % 2 == 0 or dress == "rear":
                for shutter in (-1, 1):
                    sx = middle + shutter * span * .16
                    if abs(sx) < core_len:
                        wood.box((0, 0, 0), (span * .27, .68, height * .56),
                                 F(sx, core_depth + .16, bottom + height * .34), bevel=.23)
                        for bar in range(5):
                            (gold if front else so).box((0, 0, 0), (.19, .25, height * .38),
                                                        F(sx + (bar - 2) * span * .04, core_depth + .58, bottom + height * .38))
            if dress == "rear" and i % 2 == 1:  # weather screens close alternate rear bays
                so.box((0, 0, 0), (span, .5, height * .58), F(middle, depth - 1.3, bottom + 4.4 + height * .29), bevel=.1)
                for k in range(1, 7):
                    wood.box((0, 0, 0), (.32, .7, height * .58),
                             F(middle - span / 2 + span * k / 7, depth - 1.0, bottom + 4.4 + height * .29))
                for k in range(1, 4):
                    wood.box((0, 0, 0), (span, .7, .32), F(middle, depth - 1.0, bottom + 4.4 + height * .58 * k / 4))
            for zz, t in ((bottom + 4.6, .75), (bottom + 1.9, .5)):  # railing
                wood.box((0, 0, 0), (span, t + .25, t), F(middle, depth + .6, zz), bevel=.08)
            pickets = max(2, int(span / 2.6))
            for k in range(1, pickets):
                wood.box((0, 0, 0), (.42, .42, 2.9), F(middle - span / 2 + span * k / pickets, depth + .6, bottom + 3.2))
            gallery_rng = RNG if front else local  # the front keeps the draws the tree's stream expects
            if gallery_rng.random() < {"front": .7, "side": .3, "rear": .12}[dress]:  # paper lanterns in open bays
                lz = top - 9 - gallery_rng.uniform(0, 4)
                ly = depth - (depth - core_depth) * .45
                amber.lathe([(.01, -1.7), (.86, -1.55), (1.16, -.8), (1.16, .8), (.86, 1.55), (.01, 1.7)],
                            12, F(middle, ly, lz))
                for ring in (-.85, .85):
                    so.lathe([(1.20, ring - .08), (1.20, ring + .08)], 12, F(middle, ly, lz), caps=(False, False))
                (gold if front else so).box((0, 0, 0), (.2, .2, top - 1.6 - lz - 2.2),
                                            F(middle, ly, (lz + top - 1.6) / 2 + 1.1))
            if gallery_rng.random() < {"front": .35, "side": .3, "rear": .45}[dress]:  # broken railing
                wood.box((0, 0, 0), (span * .4, .6, .6), F(middle + span * .2, depth + 2.2, bottom + .6)
                         @ Matrix.Rotation(gallery_rng.uniform(-.5, .5), 4, "Z"), bevel=.08)
        wood.box((0, 0, 0), (length * 2 + 8, 7, 4.5), F(0, depth, top - 1), bevel=.35)
        wood.box((0, 0, 0), (length * 2 + 11, 10, 2.6), F(0, depth, top + 5.6), bevel=.35)
        if front:
            gold.box((0, 0, 0), (length * 2 + 4, .66, 1.0), F(0, depth + 3.7, top - .4), bevel=.1)


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


# Each shrine stands on a terrace (TERRACES), raised on a timber frame clear of the wall behind it.
SIDE_SHRINES = [((-174, -64, 124), 80, 64, 32), ((180, -68, 122), 84, 60, 30), ((-178, -196, 240), 70, 60, 30),
                ((196, -186, 248), 66, 56, 28), ((-122, -228, 262), 60, 52, 26), ((130, -222, 316), 58, 50, 26)]


def galleries(h):
    """Side shrines on post-and-beam frames that stand on the terraces below them."""
    rng = random.Random(5180)
    for (x, y, z), w, d, ht in SIDE_SHRINES:
        pavilion(h, (x, y, z), w, d, ht, 3)
        floor_supports(h, rng, x, y, z, w, d, 3)


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


def lion_plinth(h, location, yaw, side):
    frame = at(*location) @ Matrix.Rotation(yaw, 4, "Z")
    stone, trim = h.m("Masonry"), h.m("DarkStone")
    stone.box((0, 0, 1.9), (23.6, 26.5, 3.8), frame, bevel=.58)
    stone.box((0, 0, 4.0), (22.1, 24.8, 1.3), frame, bevel=.37)
    stone.box((0, 0, 4.85), (20.8, 23.9, .9), frame, bevel=.21)
    trim.box((0, 13.05, 2.15), (15.6, .40, 2.05), frame, bevel=.30)
    local_rng = random.Random(113 + side)
    for sign in (-1, 1):
        for k in range(4):
            trim.box((sign * (10.7 + local_rng.uniform(-.2, .4)), -8.6 + k * 5.8, 2.1),
                     (1.38, 1.25, .92), frame, bevel=.18)
    for k in range(11):
        x = local_rng.uniform(-10.5, 10.5)
        z = local_rng.uniform(.25, 4.4)
        pts = [frame @ Vector((x+dx, 13.27, z+dz)) for dx,dz in ((-.46,.16),(.24,.32),(.55,-.22),(-.09,-.36))]
        h.m("Moss").poly(pts, open_surface=True)


def place_lion(location, yaw, side):
    """Seat a mirrored, moss-stained CC0 stone scan on the authored plinth."""
    source = kit.ROOT / "assets/source/props_cc0/zenodo_lion_scan/lion_scan.glb"
    previous = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(source))
    bpy.context.view_layer.update()
    imported = set(bpy.context.scene.objects) - previous
    ob, = [item for item in imported if item.type == "MESH"]
    corners = [ob.matrix_world @ Vector(point) for point in ob.bound_box]
    x, y = [(min(p[i] for p in corners)+max(p[i] for p in corners))*.5 for i in range(2)]
    low, high = min(p.z for p in corners), max(p.z for p in corners)
    size = (23.9 if side > 0 else 22.1) / (high-low)
    mirror = Matrix.Diagonal((side, 1, 1, 1))
    object_to_world = ob.matrix_world.copy()
    ob.parent = None
    ob.matrix_world = (at(location[0], location[1], location[2]+5.16)
                       @ Matrix.Rotation(yaw, 4, "Z") @ mirror
                       @ Matrix.Rotation(-math.pi/2, 4, "Z") @ Matrix.Scale(size, 4)
                       @ at(-x, -y, -low) @ object_to_world)
    ob.data.transform(ob.matrix_world)
    if side < 0:
        ob.data.flip_normals()
    ob.matrix_world = Matrix.Identity(4)
    ob.name = "Bellwood_Guardian_" + ("East" if side > 0 else "West")
    for item in imported - {ob}:
        bpy.data.objects.remove(item, do_unlink=True)
    for slot in ob.material_slots:
        if slot.material is None:
            continue
        material = slot.material.copy()
        slot.material = material
        material.name = "Weathered guardian sandstone"
        nodes, links = material.node_tree.nodes, material.node_tree.links
        shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
        base = shader.inputs["Base Color"]
        image = next((edge.from_socket for edge in base.links), None)
        moss = nodes.new("ShaderNodeTexNoise")
        moss.inputs["Scale"].default_value = 7.2
        moss.inputs["Detail"].default_value = 5
        coord = nodes.new("ShaderNodeTexCoord")
        links.new(coord.outputs["Generated"], moss.inputs["Vector"])
        patches = nodes.new("ShaderNodeValToRGB")
        patches.color_ramp.elements[0].position = .50
        patches.color_ramp.elements[0].color = (0,0,0,1)
        patches.color_ramp.elements[1].position = .79
        patches.color_ramp.elements[1].color = (.73,.73,.73,1)
        links.new(moss.outputs["Fac"], patches.inputs[0])
        mix = nodes.new("ShaderNodeMixRGB")
        links.new(patches.outputs[0], mix.inputs[0])
        if image:
            links.new(image, mix.inputs[1])
        else:
            mix.inputs[1].default_value = base.default_value
        mix.inputs[2].default_value = (.055,.075,.029,1)
        links.new(mix.outputs[0], base)
    return ob


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
    stats = {"twigs": 0, "bark_branches": 0, "pruned": 0}
    occupied = {}  # branch starts per size class on a coarse grid

    def crowded(p, d, length):
        """A fork beside a near-parallel sibling of the same size adds clutter, not form."""
        level = max(0, int(math.log2(max(1.0, length))))
        cell = 2 ** level * .45
        heads = occupied.setdefault((level, round(p.x / cell), round(p.y / cell), round(p.z / cell)), [])
        if any(d.dot(o) > .55 for o in heads):
            stats["pruned"] += 1
            return True
        heads.append(d)
        return False

    def branch(start, direction, length, radius, depth):
        if radius < .075 or length < .9:
            return
        d = direction.normalized()
        if crowded(start, d, length):
            return
        side = d.cross(UP)
        side = side.normalized() if side.length > 1e-3 else Vector((1, 0, 0))
        outward = Vector((start.x - centre.x, start.y - centre.y, 0))
        outward = outward.normalized() if outward.length > 1 else side
        # Thick wood climbs outward; the finest shoots droop. One steady curl per limb instead of zigzags.
        tropism = (outward * .45 + UP * (.32 if radius > .6 else -.2)).normalized()
        axis = d.cross(random_unit())
        turn = Matrix.Rotation(RNG.uniform(.07, .2), 3, axis.normalized() if axis.length > 1e-3 else side)
        pts, heading = [start], d
        for _ in range(4):
            heading = (turn @ heading).lerp(tropism, .14).normalized()
            pts.append(pts[-1] + heading * length * RNG.uniform(.21, .29))
        rr = [radius, radius * .8, radius * .62, radius * .42, radius * .16]
        if radius >= THICK:
            organic_path(bark, circle(12), pts, rr, SPINE)
            stats["bark_branches"] += 1
        else:
            sections = 3 if radius > .54 else 2
            path, scales = curved(pts, rr, sections)
            twigs.sweep(circle(8 if radius > .54 else 5), path, scales=scales)
            stats["twigs"] += 1
        if depth <= 1:  # the finest wood carries the lace fringe (crown_fringe)
            TIPS.append((pts[-1].copy(), (pts[-1] - pts[-2]).normalized(), rr[-1], depth))
            TIPS.append((pts[-2].copy(), (pts[-2] - pts[-3]).normalized(), rr[-2], depth + 1))
        if not depth:
            return
        count = RNG.choice((2, 2, 3)) if depth > 2 else 3  # sparse structure, dense fringe at the tips
        flip = RNG.choice((-1, 1))
        for c in range(count):
            f = (.25 + .55 * (c + RNG.uniform(.15, .85)) / count) * 4  # spread where the parent is still thick
            seg = min(3, int(f))
            t = f - seg
            where = path_point(pts, seg, t)
            here = rr[seg] * (1 - t) + rr[seg + 1] * t
            tangent = (path_point(pts, seg, min(1, t + .05)) - path_point(pts, seg, max(0, t - .05))).normalized()
            across = tangent.cross(UP)
            across = across.normalized() if across.length > 1e-3 else side
            flip = -flip  # children alternate sides and keep the parent's direction of growth
            vector = tangent + across * flip * RNG.uniform(.45, .85) + UP * RNG.uniform(-.1, .3)
            branch(where, vector, length * RNG.uniform(.55, .7), min(here, radius * RNG.uniform(.5, .64)), depth - 1)

    def limb(points, radii, spawn=(2, 3, 3, 4), twig_depth=None, collar=True):
        points = [Vector(p) for p in points]
        points = [Vector((p.x, p.y, 445 + (p.z - 445) * CROWN_SQUASH)) if p.z > 445 else p for p in points]
        pts, rr = gnarl(points, radii, .15)
        organic_path(bark, BARK_PROFILE, pts, rr, SPINE)
        # Branch collar: a broad swelling where the limb leaves its parent, so the joint reads as grown wood.
        d0 = (pts[1] - pts[0]).normalized()
        if collar:
            organic_path(bark, BARK_PROFILE, [pts[0], pts[0] + d0 * rr[0] * 1.0, pts[0] + d0 * rr[0] * 2.4],
                         [rr[0] * 1.35, rr[0] * 1.18, rr[0] * 1.02], SPINE)
        for i in range(1, len(pts)):
            a, b = pts[i - 1], pts[i]
            r = (rr[i - 1] + rr[i]) * .5
            for _ in range(RNG.choice(spawn)):
                t = RNG.uniform(.1, .95)
                where = path_point(pts, i - 1, t)
                outward = Vector((where.x - centre.x, where.y - centre.y, 0))
                if outward.length < 62 and where.z < 600:
                    continue  # keep the fork bare so the leaders read
                outward = outward.normalized()
                vector = ((b - a).normalized() * RNG.uniform(.5, 1.0) + outward * RNG.uniform(.2, .6)
                          + random_unit() * .25 + UP * RNG.uniform(0, .6))
                radius = r * RNG.uniform(.28, .46)
                branch(where, vector, radius * RNG.uniform(13, 19), radius,
                       TWIG_DEPTH if twig_depth is None else twig_depth)
        return pts, rr

    # The trunk: one colossal pale column with a lean, a twist and three unequal leaders.
    organic_path(bark, BARK_PROFILE, TRUNK, [40, 39, 34, 30, 26, 22], SPINE)
    for i in range(18):  # rope-like strands spiral up the trunk and run on into leaders and roots
        phase = i * math.tau / 18 + RNG.uniform(-.12, .12)
        route, scales = [], []
        for j in range(len(TRUNK) - 1):  # strands sink into the trunk below the fork, so no rope ends poke out of it
            t = phase + .34 * j * (1 if i % 3 else -.6)
            r = (38 - 3.3 * j) * RNG.uniform(.86, .99) * (.62 if j == len(TRUNK) - 2 else 1)
            route.append(TRUNK[j] + Vector((math.cos(t) * r, math.sin(t) * r, RNG.uniform(-3, 3))))
            scales.append(RNG.uniform(3.0, 7.5) * (.4 if j == len(TRUNK) - 2 else 1))
        organic_path(bark, circle(10), route, scales, SPINE)
    fork = TRUNK[4]
    # Three leaders in separate planes: image-left arches forward and over, the centre climbs behind,
    # image-right reaches out low and forward. Each rises, then levels, so the crown reads as a broad dome.
    # v12: the side leaders climb less and reach further, so the fork reads as massive limbs sweeping over the roofs.
    leaders = [
        ([fork, (50, -150, 506), (98, -136, 542), (152, -122, 570), (212, -106, 590), (274, -92, 598), (336, -78, 588)],
         [28, 23, 19, 15, 11.5, 8, 5]),
        ([TRUNK[3], (-8, -178, 500), (-14, -198, 568), (4, -214, 632), (-10, -226, 694), (-28, -236, 752)],
         [29, 23, 19, 15, 10, 6]),
        ([fork, (-36, -156, 502), (-84, -142, 536), (-138, -126, 562), (-198, -112, 582), (-260, -100, 590),
          (-322, -90, 578)], [25, 20, 16, 13, 10, 7, 4.5]),
    ]
    built = [limb(p, r, collar=False) for p, r in leaders]  # the trunk itself splits
    l1, l2, l3 = built

    def on(pts, f):  # gnarled control point a fraction of the way along a limb
        return pts[round(f * (len(pts) - 1))]

    laterals = [  # the first two are the heavy low limbs that sweep left and right just over the upper roofs
        ([on(l1[0], .08), (80, -136, 496), (140, -120, 484), (200, -104, 508), (262, -86, 498), (320, -70, 530),
          (380, -56, 548), (430, -40, 540)], [19, 16, 13, 10.5, 8, 6, 4, 2.4]),
        ([TRUNK[3] + Vector((-10, 6, 6)), (-54, -136, 425), (-112, -120, 415), (-172, -104, 442), (-232, -92, 436),
          (-292, -78, 466), (-352, -66, 458), (-400, -56, 480)], [21, 17, 13.5, 10.5, 8, 6, 4, 2.4]),
        ([on(l1[0], .5), (190, -100, 626), (246, -64, 646), (306, -34, 684), (362, -10, 700)],
         [11, 8.5, 6.5, 4.2, 2.6]),
        ([on(l2[0], .4), (-88, -140, 582), (-150, -116, 600), (-218, -88, 636), (-280, -60, 650), (-336, -36, 686)],
         [12, 10, 8, 6, 4, 2.5]),
        ([on(l1[0], .33), (100, -100, 586), (118, -44, 606), (140, 14, 636), (160, 70, 656)], [11, 9, 7, 5, 3]),
        ([on(l3[0], .25), (-92, -220, 556), (-104, -262, 600), (-86, -300, 650)], [10, 8, 6, 3.5]),
        ([on(l3[0], .5), (-140, -120, 600), (-136, -60, 625), (-122, 0, 656), (-110, 60, 670)], [9, 8, 6, 4.5, 3]),
        ([on(l1[0], .42), (120, -170, 680), (96, -210, 730), (110, -250, 780)], [8, 6.5, 5, 3]),
        ([on(l2[0], .2), (-44, -118, 500), (-72, -62, 522), (-112, -12, 512), (-170, 30, 540), (-222, 62, 532)],
         [11, 9, 7.5, 6, 4.2, 2.8]),
        # v12: two upper-dome limbs fill the empty sky between the leaders so the crown closes into one dome
        ([on(l2[0], .7), (60, -228, 700), (130, -214, 728), (200, -190, 734), (262, -160, 716)], [8, 6.5, 5, 3.5, 2.2]),
        ([on(l2[0], .85), (-70, -244, 732), (-140, -236, 742), (-210, -214, 730), (-268, -186, 706)],
         [7, 5.8, 4.6, 3.2, 2]),
        # v12c left the centre of the dome open sky: four limbs climb forward over the trunk to close it
        ([on(l2[0], .55), (40, -180, 660), (70, -140, 720), (90, -100, 790), (100, -60, 840)], [8, 6.5, 5, 3.4, 2]),
        ([on(l2[0], .6), (-40, -190, 670), (-80, -150, 735), (-100, -110, 800), (-110, -70, 840)], [8, 6.5, 5, 3.4, 2]),
        ([on(l1[0], .25), (74, -118, 604), (64, -70, 666), (44, -22, 724)], [8, 6, 4, 2.4]),
        ([on(l3[0], .25), (-62, -118, 602), (-52, -70, 662), (-32, -22, 720)], [8, 6, 4, 2.4]),
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
    trees = [BVHTree.FromBMesh(h.m(role).bm) for role in ("Masonry", "Tile", "Lacquer", "Soffit")]  # v13 eave soffits
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
        if abs(p.x) < 72 and p.y > -132 and p.z < 176:
            return True  # nothing hangs into the gate front below its first eave
        return p.y > -46 and abs(p.x) < w / 2 + 7  # the player route stays clear

    def steer(p, heading, goal):
        heading = heading + (goal - Vector((p.x, p.y))).normalized() * .32
        if abs(p.x) < 104 and -128 < p.y and p.z > 60:  # flow around the gate hall, never over its face
            heading = heading + Vector((math.copysign(1.4, p.x if abs(p.x) > 1 else 1), -.2))
        return heading.normalized()

    def face(xy, z, heading, r):
        """Where a root pressed to the wall at height z sits: just off the first face met coming back in."""
        h3 = Vector((heading.x, heading.y, 0))
        origin = Vector((xy.x, xy.y, z)) + h3 * 80
        best = None
        for tree in grip:  # an open gallery's columns are not a wall to hang on (v12d struts)
            hit = tree.ray_cast(origin, -h3, 130)
            if hit[0] is not None and (best is None or hit[3] < best[3]):
                best = hit
        if best is not None:
            back = (best[0].xy - xy).dot(heading)
            if -30 < back < r * 1.5 + 4:  # a face set back under an eave, never a far wall or a block's inside
                return best[0].xy + heading * r * 1.05, True
        return xy + heading * r * 1.05, False

    # Roots grip stone, crag and roof tiles only. Pressed onto lacquer columns and railings they became ladders of
    # struts in v12a, so an open gallery ends a root at its eave instead.
    grip = [BVHTree.FromBMesh(h.m(role).bm) for role in ("Masonry", "DarkStone", "Tile", "Crag")
            if role in h.meshes]  # DarkStone: the v13 ramparts' plinths and copings

    def nearest(p, reach):
        best = None
        for tree in grip:
            hit = tree.find_nearest(p, reach)
            if hit[0] is not None and (best is None or hit[3] < best[3]):
                best = hit
        return best

    trunk_radii = (40, 39, 34, 30, 26, 22)

    def trunk_gap(p):  # how far outside the trunk's bark a point sits, at its height
        j = min(range(len(TRUNK)), key=lambda k: abs(TRUNK[k].z - p.z))
        return (p.xy - TRUNK[j].xy).length - trunk_radii[j]

    def cling(pts, rr):
        """Resample a routed root every ~3 studs and press each sample onto the stone, roof or timber it crosses,
        so it follows the surface it grips. Where nothing lies within reach the root would span open air as a
        strut: it ends there instead. Returns the clinging spine, radii and the source index of each sample."""
        dense, radii, origin = [], [], []
        for i, (a, b) in enumerate(zip(pts, pts[1:])):
            n = max(1, round((b - a).length / 3))
            for k in range(n):
                dense.append(a.lerp(b, k / n))
                radii.append(rr[i] + (rr[i + 1] - rr[i]) * k / n)
                origin.append(i)
        dense.append(pts[-1].copy())
        radii.append(rr[-1])
        origin.append(len(pts) - 1)
        free = [i == 0 or trunk_gap(p) < 12 for i, p in enumerate(dense)]  # still merging into the trunk
        end = len(dense)
        reason = "whole"
        for sweep in range(3):
            # v13: the rebuilt walls are offset and buttressed, so a recess can leave a sample a little beyond the
            # contact probe. Samples within a wider reach are pulled onto the stone too; the root ends only after
            # three samples (~9 studs) in a row find nothing even there, or before its first hold if it is already
            # far from the trunk in open air (the v12e arch).
            held = [None if free[i] else nearest(dense[i], radii[i] * 1.2 + 30) for i in range(end)]
            seen, misses, cut = False, 0, None
            for i in range(1, end):
                if free[i]:
                    continue
                if held[i] is None:
                    misses += 1
                    if (seen or trunk_gap(dense[i]) > 60) and misses >= 3:
                        cut = i - 2
                        break
                else:
                    misses, seen = 0, True
            if cut is not None:
                end = cut
                reason = f"open air at sample {cut} of {len(dense)} z{round(dense[cut].z)} seen={seen}"
            for i in range(1, end):
                hit = held[i]
                if hit is None:
                    continue
                p, r = dense[i], radii[i]
                loc, normal = hit[0], hit[1]
                away = p - loc
                if away.length > 1e-3 and away.dot(normal) > 0:
                    normal = away.normalized()  # wraps round lips and arrises instead of jumping across them
                dense[i] = loc + normal * r * .8  # sunk a fifth of its girth into the surface it bears on
                if blocked(dense[i]):
                    end = i
                    reason = f"player route at sample {i} of {len(dense)} {tuple(round(c) for c in dense[i])}"
                    break
            if sweep == 2:  # two neighbouring samples pressed onto different stones far apart: the span is a strut
                for i in range(2, end):
                    a, b = dense[i - 1], dense[i]
                    # v13c cut legitimate wraps onto recessed buttressed walls; a span is a strut only where its
                    # middle hangs in open air, away from any stone.
                    if held[i] is not None and held[i - 1] is not None and not free[i] \
                            and (b - a).length > max(10.0, radii[i] * 1.6) \
                            and any(nearest(a.lerp(b, t), radii[i] + 5) is None for t in (.3, .5, .7)):
                        end = i
                        reason = f"jump at sample {i} z{round(dense[i].z)}"
                        break
            if sweep < 2:
                dense = [p if i in (0, end - 1) or free[i] or i >= end else (dense[i - 1] + p * 2 + dense[i + 1]) * .25
                         for i, p in enumerate(dense)]
        for k in range(min(4, end)):  # taper into the tip rather than ending at full girth where the stone runs out
            radii[end - 1 - k] *= .5 + .5 * k / 4
        if radii[0] > 3:
            print("Cling", tuple(round(c) for c in dense[0]), "r", round(radii[0], 1), "kept", end, "of", len(dense),
                  "-", reason, flush=True)
        # Samples pressed onto the same arris land on one point; coincident rings would weld into open seams.
        keep = [0]
        for i in range(1, end):
            if (dense[i] - dense[keep[-1]]).length > .6:
                keep.append(i)
        return [dense[i] for i in keep], [radii[i] for i in keep], [origin[i] for i in keep]

    def root(start, heading, r0, length, depth, goal):
        heading = Vector(heading).normalized()
        pts, rr, holds, children = [start.copy()], [r0], [], []
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
                # Arch over the lip, then hug the face on a diagonal and bear on it at mid height and at its foot.
                # The diagonal varies per root so neighbours cross instead of hanging as a parallel curtain.
                lateral = Vector((-heading.y, heading.x)) * RNG.choice((-1, 1)) * drop * RNG.uniform(.35, .75)
                hug, walled = face(edge + lateral * .66, p.z - drop * .66, heading, r)
                foot, _ = face(edge + lateral, ground + r * 1.5, heading, r)
                land = foot + heading * (r * .4 + drop * .1)
                if (not walled and drop > max(10.0, r * 1.5)) or blocked(Vector((hug.x, hug.y, p.z - drop * .66))) \
                        or blocked(Vector((land.x, land.y, ground))):
                    # An eave over open air or the gate front: follow the lip instead of spanning the gap as a strut.
                    heading = heading @ Matrix.Rotation(RNG.choice((-1, 1)) * RNG.uniform(.8, 1.5), 2)
                    travelled += 1.5
                    continue
                land_z = surface(land.x, land.y, ground + r + 6) + r * .2
                bulge = RNG.uniform(.4, 1.1)  # how far the root bows off the face between its holds
                upper, _ = face(edge + lateral * .3, p.z - drop * .3, heading, r)
                arc = ((edge, p.z + r * .75, 1.0),
                       (upper + heading * r * bulge, p.z - drop * .3, .86),
                       (hug, p.z - drop * .66, 1.0),
                       (land, land_z, .82))
                for k, (xy, z, shrink) in enumerate(arc):
                    pts.append(Vector((xy.x, xy.y, z)))
                    rr.append(r * shrink * RNG.uniform(.9, 1.06))
                    if k in (2, 3) and drop > 14:
                        holds.append(len(pts) - 1)
                r0 *= .9  # a root thins as it gives off grip forks over each course
                p = pts[-1].copy()
                travelled += step + drop * .6
                if depth and r > .9:  # break into gripping forks along the wall foot (grown after cling)
                    for sign in (-1, 1):
                        if RNG.random() < .7:
                            child = heading @ Matrix.Rotation(sign * RNG.uniform(.8, 1.5), 2)
                            children.append((len(pts) - 2, child, r * RNG.uniform(.35, .55),
                                             RNG.uniform(14, 34) + r * 3, goal + child * 60))
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
                children.append((len(pts) - 1, child, r * RNG.uniform(.42, .62),
                                 (length - travelled) * RNG.uniform(.45, .9) + 20, goal + child * 80))
        if depth == 3:
            print("Root", tuple(round(c) for c in start), "->", tuple(round(c) for c in pts[-1]), len(pts), "pts",
                  round(travelled), "/", round(length), flush=True)
        if len(pts) < 3:
            return
        source_holds = holds
        pts, rr, origin = cling(pts, rr)
        if len(pts) < 4:
            return
        first = {}
        for j, i in enumerate(origin):
            first.setdefault(i, j)
        holds = sorted({first[i] for i in source_holds if i in first})
        for j in holds:
            CONTACTS.append((pts[j].copy(), rr[j]))
        # The tip dives behind the block or into the joint it was following instead of ending on top.
        dive = pts[-1] - pts[-2]
        dive = Vector((dive.x, dive.y, 0)).normalized() if dive.xy.length > 1e-3 else Vector((0, 0, 0))
        pts.append(pts[-1] + dive * rr[-1] * 1.2 + Vector((0, 0, -rr[-1] * 2.2)))
        rr.append(rr[-1] * .4)
        rr[-1] = max(.25, rr[-1])
        holds.append(len(pts) - 2)
        # Spine control points every ~6 studs: the Catmull-Rom sweep still hugs the surface between them.
        keep = sorted(set(range(0, len(pts) - 2, 2)) | {len(pts) - 2, len(pts) - 1} | set(holds))
        remap = {j: n for n, j in enumerate(keep)}
        spine_pts, spine_rr = [pts[j] for j in keep], [rr[j] for j in keep]
        spine_holds = [remap[j] for j in holds if j in remap]
        for index, child, radius, child_length, child_goal in children:
            j = first.get(index)
            if j is None or j >= len(pts) - 3:
                continue  # the parent ended before this fork: no fork from thin air
            root(pts[j].copy(), child, min(radius, rr[j] * .62), child_length, depth - 1, child_goal)
        pts, rr, holds = spine_pts, spine_rr, spine_holds
        if rr[0] > 3.0:
            root_rope(bark, pts, rr, holds)
        elif rr[0] >= THICK:
            organic_path(bark, circle(12), pts, rr, SPINE)
        else:
            organic_path(twigs, circle(7), pts, rr)
        for i in holds:  # greenery only where the root bears on stone, thinning away from the hold
            p, r = pts[i], rr[i]
            if p.z > 340:
                continue
            for _ in range(RNG.randrange(3, 9)):
                spread = RNG.uniform(.3, 1.0) ** 2 * r * 2.6
                a = RNG.uniform(0, math.tau)
                kit.leaf(ivy if RNG.random() < .55 else moss,
                         p + Vector((math.cos(a) * spread, math.sin(a) * spread, -r * .35)), RNG.uniform(.6, 1.6))

    # Most of the root mass pours down the image-left (+X) terraces as separate, netted roots; a few go right.
    # Fewer, heavier ropes than v10: separate main roots with real gaps, each forking at its holds.
    # v12: the image-left is one delta. Four heavy roots leave the trunk together and fan out as they pour over the
    # retaining walls toward the west lion; two lighter ones cover the upper left cliff. The right gets a small fall.
    lion_x, lion_y, _ = guardian_base(1)
    # They leave the trunk's flank low, onto the stepped masonry beside the tiers, never across an open gallery:
    # unheld spans are cut by cling, so a root has to start on stone to survive to the terraces.
    # v13 (creator reference): heavy roots leave the trunk base over the upper roofs and cascade down the terraces
    # on both sides of the stair, framing the gate and splitting near the lion plinths. (side, lean, radius, length,
    # goal, spread, z range, depth); h2 @ M turns clockwise.
    east_x, east_y, _ = guardian_base(-1)
    plan = [(1, -.1, RNG.uniform(9.0, 11.0), RNG.uniform(760, 880), (lion_x + dx, lion_y + dy), (.2, .45),
             (240, 300), 3) for dx, dy in ((10, -22), (70, 4), (125, -40), (160, -120))]
    plan += [(-1, -.1, RNG.uniform(7.5, 9.0), RNG.uniform(700, 820), (east_x + dx, east_y + dy), (-.45, -.2),
              (250, 320), 3) for dx, dy in ((-10, -20), (-75, 0), (-140, -70))]
    # two lighter roots cross the side shrines' roofs
    plan += [(side, .3, RNG.uniform(5.5, 6.5), RNG.uniform(380, 460), (side * 182, -40), (-.2, .2), (280, 330), 2)
             for side in (1, -1)]
    # Buttress flares: short heavy roots that fold the trunk base over the roofs of the tiers it rises through.
    for k in range(8):
        a = math.radians(-20 + 220 * k / 7 + RNG.uniform(-8, 8))  # front half and both flanks, not the hidden back
        out = Vector((math.cos(a), math.sin(a)))
        plan.append((out.x, out.y, RNG.uniform(11, 15), RNG.uniform(70, 120), tuple(Vector(TRUNK[2].xy) + out * 150),
                     (0, 0), (318, 372), 1))
    for side, lean, radius, length, goal, spread, (z0, z1), depth in plan:
        h2 = Vector((side, lean)).normalized()
        z = RNG.uniform(z0, z1)
        level = min(range(len(TRUNK)), key=lambda j: abs(TRUNK[j].z - z))
        around = h2 @ Matrix.Rotation(RNG.uniform(*spread), 2)
        start = TRUNK[level] + Vector((around.x, around.y, 0)) * (40 - 2 * level) + Vector((0, 0, z - TRUNK[level].z))
        root(start, h2, radius, length, depth, Vector(goal))

    print("Tree", stats, "spine samples", len(SPINE), "root contacts", len(CONTACTS), flush=True)


def twig_spray(rng, index):
    """One spray of fine twigs, one unit long up +Z: a curling shoot with alternating side twigs that fork once."""
    mesh = kit.Mesh(f"Bellwood_Crown_Spray_{index:02d}", "BarkTwigs", 1.0)
    count = [0]

    def shoot(start, heading, length, radius, depth):
        count[0] += 1
        axis = heading.cross(Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))))
        curl = Matrix.Rotation(rng.uniform(.1, .32), 3, axis.normalized() if axis.length > 1e-4 else Vector((1, 0, 0)))
        pts, d = [start], heading.normalized()
        for _ in range(4):
            d = (curl @ d + Vector((0, 0, rng.uniform(-.08, .1)))).normalized()
            pts.append(pts[-1] + d * length / 4)
        mesh.sweep(circle(4 if depth else 3), pts, scales=[radius, radius * .82, radius * .64, radius * .46, radius * .26],
                   caps=False)
        if not depth:
            return
        side = rng.choice((-1, 1))
        for k in range(rng.randint(3, 5) if depth > 1 else rng.randint(1, 2)):
            f = .22 + .66 * (k + rng.uniform(.1, .9)) / 5
            seg = min(3, int(f * 4))
            where = pts[seg].lerp(pts[seg + 1], f * 4 - seg)
            along = (pts[seg + 1] - pts[seg]).normalized()
            across = along.cross(Vector((rng.gauss(0, .3), rng.gauss(0, .3), 1)))
            across = across.normalized() if across.length > 1e-4 else Vector((1, 0, 0))
            side = -side
            shoot(where, along + across * side * rng.uniform(.6, 1.1), length * (1 - f) * rng.uniform(.55, .8),
                  radius * rng.uniform(.5, .62) * (1 - f * .5), depth - 1)

    shoot(Vector((0, 0, 0)), Vector((rng.uniform(-.15, .15), rng.uniform(-.15, .15), 1)), 1.0, .03, 2)  # v13: fewer, thicker twigs per spray
    return mesh, count[0]


def crown_fringe(mats):
    """Lace fringe for the crown: many short curved twig sprays at the ends of the finest wood, densest at the dome
    edge. Twelve sprays are instanced by geometry nodes, so hundreds of thousands of twigs cost little memory."""
    if not TIPS:
        return
    rng = random.Random(1207)
    library = bpy.data.collections.new("Bellwood crown twig sprays")
    bpy.context.scene.collection.children.link(library)
    per_spray = []
    for index in range(12):
        source, twigs = twig_spray(rng, index)
        bm = source.finish()
        mesh = bpy.data.meshes.new(source.name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.shade_smooth()
        mesh.materials.append(mats["BarkTwigs"])
        library.objects.link(bpy.data.objects.new(source.name, mesh))
        per_spray.append(twigs)
    bpy.context.view_layer.layer_collection.children[library.name].exclude = True  # sources only, never at origin
    # Dome edge: distance through an ellipsoid fitted to the crown wood, 0 at its centre and ~1 at the rim.
    lo = Vector([min(t[0][i] for t in TIPS) for i in range(3)])
    hi = Vector([max(t[0][i] for t in TIPS) for i in range(3)])
    centre, half = (lo + hi) * .5, (hi - lo) * .5
    centre.z = lo.z + (hi.z - lo.z) * .25  # a dome, not a ball: its rim hangs low at the sides
    points, rotations, scales, variants = [], [], [], []
    for p, d, r, depth in TIPS:
        rel = p - centre
        edge = min(1.3, math.sqrt((rel.x / half.x) ** 2 + (rel.y / max(half.y, 1)) ** 2
                                  + (max(0.0, rel.z) / (hi.z - centre.z)) ** 2))
        # v12c: many small sprays per tip clumped into dark blobs; fewer, longer, more open sprays read as lace
        # v13: v12h's sprays read as grey tufts; about half as many, so sky shows between the twigs
        n = int(.2 + 1.8 * edge ** 2 + rng.random()) - (1 if depth > 1 else 0)
        outward = rel.normalized() if rel.length > 1e-3 else UP
        for _ in range(max(0, n)):
            heading = (d * rng.uniform(.6, 1.2) + outward * (.35 + .5 * edge) + UP * rng.uniform(-.1, .35)
                       + Vector((rng.gauss(0, .35), rng.gauss(0, .35), rng.gauss(0, .35)))).normalized()
            q = heading.to_track_quat("Z", "Y")
            q = q @ Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z").to_quaternion()
            points.append(p + d * rng.uniform(-1.5, .5))
            rotations.extend((q.w, q.x, q.y, q.z))
            scales.append(rng.uniform(12.0, 24.0) * (.8 + .45 * edge))
            variants.append(rng.randrange(12))
    mesh = bpy.data.meshes.new("Bellwood_Crown_Fringe_Points")
    mesh.from_pydata(points, [], [])
    for name, kind, data in (("spray_rot", "QUATERNION", rotations), ("spray_scale", "FLOAT", scales),
                             ("spray_variant", "INT", variants)):
        mesh.attributes.new(name, kind, "POINT").data.foreach_set("value", data)
    holder = bpy.data.objects.new("Bellwood_Crown_Fringe", mesh)
    bpy.context.collection.objects.link(holder)
    tree = bpy.data.node_groups.new("Bellwood crown fringe", "GeometryNodeTree")
    tree.interface.new_socket(name="Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    tree.interface.new_socket(name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    nodes, links = tree.nodes, tree.links
    group_in, group_out = nodes.new("NodeGroupInput"), nodes.new("NodeGroupOutput")
    sprays = nodes.new("GeometryNodeCollectionInfo")
    sprays.inputs["Collection"].default_value = library
    sprays.inputs["Separate Children"].default_value = True
    sprays.inputs["Reset Children"].default_value = True
    place = nodes.new("GeometryNodeInstanceOnPoints")
    place.inputs["Pick Instance"].default_value = True
    links.new(group_in.outputs[0], place.inputs["Points"])
    links.new(sprays.outputs[0], place.inputs["Instance"])
    for name, kind, socket in (("spray_rot", "QUATERNION", "Rotation"), ("spray_scale", "FLOAT", "Scale"),
                               ("spray_variant", "INT", "Instance Index")):
        attribute = nodes.new("GeometryNodeInputNamedAttribute")
        attribute.data_type = kind
        attribute.inputs["Name"].default_value = name
        links.new(next(s for s in attribute.outputs if s.enabled and s.name == "Attribute"), place.inputs[socket])
    links.new(place.outputs[0], group_out.inputs[0])
    holder.modifiers.new("Instanced twig sprays", "NODES").node_group = tree
    holder.data.materials.append(mats["BarkTwigs"])
    twigs = sum(per_spray[v] for v in variants)
    print("Crown fringe", len(points), "sprays,", twigs, "instanced twigs from", len(TIPS), "tips", flush=True)
    return twigs


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
        value.outputs[0].default_value = .36  # fine twigs a shade darker than the limbs, so the lace reads on the sky
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
    # The main fork is seen close up: split its voxel faces into thirds so the smoothing below can take out the
    # voxel stair-steps and the grain has the resolution to run through the crotch.
    fork = TRUNK[4] + Vector((0, 0, 14))
    region = [f for f in tree.faces if all((v.co - fork).length < 78 for v in f.verts)]
    edges = list({e for f in region for e in f.edges})
    bmesh.ops.subdivide_edges(tree, edges=edges, cuts=2, use_grid_fill=True)
    print("Fork detail faces", len(region), "subdivided; bark now", len(tree.verts), "vertices", flush=True)
    assert all(edge.is_manifold for edge in tree.edges), "Fused bark contains open seams"
    tree.to_mesh(obj.data)
    tree.free()
    detail = obj.vertex_groups.new(name="Fork detail")
    for v in obj.data.vertices:
        weight = min(1.0, max(0.0, (86 - (v.co - fork).length) / 22))
        if weight > 0:
            detail.add([v.index], weight, "REPLACE")
    soften = obj.modifiers.new("Melt voxel steps at the fork", "SMOOTH")
    soften.factor = .6
    soften.iterations = 18
    soften.vertex_group = detail.name
    bpy.ops.object.modifier_apply(modifier=soften.name)
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
    grip = KDTree(max(1, len(CONTACTS)))
    for i, (c, _) in enumerate(CONTACTS):
        grip.insert(c, i)
    grip.balance()
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
        hits = kd.find_n(p, 8)
        per_path = {}
        depth = 0.0
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
            # Sharp falloff: the nearest limb's grain wins, so grooves run through a crotch instead of averaging flat.
            weight = 1 / (abs(math.hypot(x, y) - r) + 1.0) ** 4
            total += weight
            height += value * weight
            depth += min(r * .26, 8.0) * weight  # groove depth blends too, so it never jumps in a voxel step
            per_path[pid] = max(per_path.get(pid, 0.0), weight)
            if weight > best_w:
                best_w, best_u, best_v, best_period = weight, a * base / 6, along / 6, math.tau * base / 6
        value = height / total
        nearest_r = SPINE[hits[0][1]][4]
        ranked = sorted(per_path.values(), reverse=True)
        clash = min(1.0, max(0.0, (ranked[1] / ranked[0] - .2) / .45)) if len(ranked) > 1 else 0.0
        amplitude = depth / total * (1 - .25 * clash)  # grain carries through junctions, slightly softened
        # v12h: where the sunk trunk strands end inside the fork their thin rings won the weighting and left a
        # flat patch; the fork keeps at least trunk-scale grooves.
        amplitude = max(amplitude, 3.2 * min(1.0, max(0.0, (90 - (p - TRUNK[4]).length) / 30)))
        for axis in range(3):
            coords[3 * i + axis] += normals[3 * i + axis] * (value - .55) * amplitude
        ridge[i] = min(1.0, max(0.0, value))
        nz = normals[3 * i + 2]
        # Moss gathers where a root bears on stone and fades over a few root widths, not everywhere low.
        hold = grip.find(p) if CONTACTS else None
        near = max(0.0, 1 - hold[2] / (CONTACTS[hold[1]][1] * 3.5 + 6)) ** 1.5 if hold and hold[0] is not None else 0.0
        mossy[i] = min(1.0, (max(0.0, (nz - .2) * 1.6) + max(0.0, .5 - value) * .8) * near)
        us[i], vs[i], period[i] = best_u, best_v, best_period
        blend[i] = clash  # where two limbs' UV frames compete (junctions), fade to a seamless projected bark
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
    glow.inputs["From Min"].default_value = .48  # a wider bright break behind the crown silhouettes the twig lace
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
        if role != "BarkTwigs":
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
    guardians = []
    for side in (-1, 1):
        x, y, z = guardian_base(side)
        location, yaw = (x, y, z + 9.15), side * .47
        lion_plinth(temple, location, yaw, side)
        guardians.append((location, yaw, side))
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
    crown_fringe(mats)
    for location, yaw, side in guardians:
        place_lion(location, yaw, side)
    scene, camera, mannequin = figures.setup_scene(samples=int(os.environ.get("VESP_RENDER_SAMPLES", 12)), cool_rim=True)
    atmosphere(scene, mats, temple)
    if os.environ.get("VESP_CPU"):  # Metal buffers sit in unified memory; CPU keeps the peak footprint lower
        scene.cycles.device = "CPU"
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
    # v12: a narrower lens from a step further back makes the six tiers larger; traveller and both lions stay in.
    eye = Vector((0, 366, 14))
    target = Vector((20, -100, 250))
    contact = min(CONTACTS, key=lambda c: (c[0] - Vector((70, 40, 50))).length)[0] if CONTACTS else Vector((70, 40, 50))
    print("Root close-up target", tuple(round(c) for c in contact), flush=True)
    views = {
        "portrait": (900, 1350, 66, eye, target),
        "approach": (1280, 900, 60, Vector((0, 208, 26)), Vector((14, -56, 172))),
        "side": (1152, 864, 53, Vector((480, 12, 139)), Vector((0, -125, 285))),
        "rear": (1152, 864, 56, Vector((-280, -720, 185)), Vector((0, -151, 271))),
        "guardian": (1080, 910, 42, Vector((-1, 258, 32)), Vector((2, 198, 43))),
        "left_guardian": (900, 900, 37, Vector((29, 252, 34)), Vector(guardian_base(1)) + Vector((0, 0, 24))),
        "right_guardian": (900, 900, 37, Vector((-29, 249, 32)), Vector(guardian_base(-1)) + Vector((0, 0, 24))),
        "fork": (900, 900, 46, Vector((95, -20, 500)), TRUNK[4] + Vector((0, 0, 20))),
        "root": (900, 900, 52, Vector((12, contact.y + 75, max(stair_profile((START_Y - contact.y - 75) / STEP_RUN)[2] + 14,
                                                              contact.z + 26))), contact + Vector((0, 0, 4))),
    }
    clay = bpy.data.materials.new("Neutral clay seam check")
    clay.diffuse_color = (.5, .5, .5, 1)
    clay.use_nodes = True
    next(n for n in clay.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Roughness"].default_value = .8
    for name in os.environ.get("VESP_VIEWS", "portrait,approach,fork,root").split(","):
        is_clay = name.startswith("clay_")  # grey override, fog hidden: seams and twig starts show
        width, height, angle, where, target = views[name[5:] if is_clay else name]
        scene.view_layers[0].material_override = clay if is_clay else None
        for ob in scene.objects:
            if ob.name.startswith(("Valley haze", "Broken ribbons of fog")):
                ob.hide_render = is_clay
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

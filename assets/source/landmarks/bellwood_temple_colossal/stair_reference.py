"""Staging scene for the creator's stair-side Bellwood reference. Blender units = studs."""

import math
from array import array
import os
from pathlib import Path
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.noise import noise_vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import temple_preview as kit
from temple_preview import Hall, at, figures, light, tier

RNG = random.Random(711)
OUT = Path.cwd() / "work/sol-bellwood-scale"
UP = Vector((0, 0, 1))
STEP_COUNT = 138
STEP_RUN, STEP_RISE = 2.55, .62
START_Y = 251.0


def circle(sides):
    return [(math.cos(i * math.tau / sides), math.sin(i * math.tau / sides)) for i in range(sides)]


def organic_path(mesh, profile, controls, radii):
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
    rings = []
    side = None
    for i, (p, radius) in enumerate(zip(spine, scales)):
        tangent = (spine[min(i + 1, len(spine) - 1)] - spine[max(0, i - 1)]).normalized()
        if side is None:
            cross = Vector((0, 1, 0)) if abs(tangent.y) < .9 else Vector((1, 0, 0))
            side = tangent.cross(cross).normalized()
        else:
            side = (side - tangent * tangent.dot(side)).normalized()
        local_up = side.cross(tangent).normalized()
        ring = []
        for k, (x, y) in enumerate(profile):
            phase = k * math.tau / len(profile)
            cambium = 1 + .063 * math.sin(phase * 5.0 + i * .16) + .034 * math.sin(phase * 9.0 - i * .19)
            ring.append(p + (side * x + local_up * y) * (radius * cambium))
        rings.append(ring)
    mesh.grid(rings, None, wrap=True)
    mesh.poly(rings[0])
    mesh.poly(list(reversed(rings[-1])))


def merge(hall, piece, frame):
    for role, mesh in piece.meshes.items():
        hall.m(role).merge(mesh.bm, frame)


def stair_profile(k):
    fraction = k / STEP_COUNT
    return (-12 + 28 * fraction + 12 * math.sin(fraction * math.pi),
            START_Y - STEP_RUN * k, 2.8 + STEP_RISE * k, 134 - 51 * fraction)


def stonework(h):
    stair, moss, leaf = (h.m(role) for role in ("Masonry", "Moss", "MapleDeep"))
    for k in range(STEP_COUNT):
        x, y, z, width = stair_profile(k)
        stair.box((x, y, z - 1.55), (width + .1, STEP_RUN + .045, 3.1), bevel=.10)
        # Crowded grooves and thin chips at the treads produce scale from ground level.
        for _ in range(10):
            offset = RNG.uniform(-.49, .49) * width
            if abs(offset) < width * .19 and RNG.random() < .82:
                continue
            radius = RNG.uniform(.28, .81)
            material = moss if RNG.random() < .55 else leaf
            material.poly([Vector((x + offset + dx * radius, y + dy * radius, z + RNG.uniform(.01, .09)))
                           for dx, dy in ((-1, -.24), (.18, -.5), (1, 0), (.42, .5))], open_surface=True)
    for side in (-1, 1):
        for k in range(3, STEP_COUNT - 3, 3):
            x, y, z, w = stair_profile(k)
            inset = x + side * (.51 * w + 2.4)
            stair.box((inset, y, z - 3.9), (6.2, 3 * STEP_RUN + .04, 8.8), bevel=.37)
            stair.box((inset, y, z + 1.7), (6.5, 3 * STEP_RUN - .11, 2.0), bevel=.26)
            if k % 9 == 0:
                column = .85 + RNG.random() * .17
                stair.box((inset, y, z + 4.45), (4.3, 4.1, 4.8 * column), bevel=.21)
                stair.lathe([(2.35, 0), (1.9, .31), (1.14, .75), (.0, 1.58)], 10, at(inset, y, z + 6.70 * column))
    # A walkable threshold and layered bases become part of the terraced cliff.
    for x, y, w, d, bottom, top in ((21, -131, 199, 153, 54, 89), (-40, -196, 290, 167, 73, 144),
                                     (10, -251, 237, 148, 137, 206), (-9, -298, 187, 125, 212, 263)):
        height = top - bottom
        stair.box((x, y, (top + bottom) / 2), (w, d, height), bevel=1.6)
        for dw, pad, zz in ((3, 3, top - 1), (1, 1.8, top - 5.2), (3.6, 2.7, bottom + 2.2)):
            stair.box((x, y, zz), (w + dw, d + pad, 2.5), bevel=.45)
        front = y + d / 2
        for course in range(4):
            for col in range(-int(w / 13), int(w / 13)):
                px = x + col * 6.5 + .45 * (course % 2)
                stone_h = RNG.uniform(1.9, 2.65)
                stair.box((px, front, top - 7.7 - course * 2.85), (RNG.uniform(6.2, 6.7), RNG.uniform(.7, 1.65), stone_h),
                          bevel=RNG.uniform(.1, .42))
    # Projecting close ledges and broken wall blocks tie roots into the site.
    for side in (-1, 1):
        for k in range(22):
            x, y, z, w = stair_profile(k * 6)
            dx = x + side * (w * .55 + RNG.uniform(7, 23))
            for j in range(3):
                mv = at(dx + side * j * 6.0, y + RNG.uniform(-3, 4), z - 3.3 * j - 4) @ Matrix.Rotation(
                    RNG.uniform(-.22, .22), 4, "Z")
                stair.box((0, 0, 0), (RNG.uniform(4, 11), RNG.uniform(5, 14), RNG.uniform(4, 12)), mv,
                          bevel=RNG.uniform(.4, 1.2))


def panelwork(h, width, depth, base, z):
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
    for x in (-frieze / 3, frieze / 3):
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
    tier(block, width * .412, depth * .388, 0, height, bays, max(2.2, width * .019))
    eave = height + 8
    kit.roof(block, width, depth, width * .146, eave, min(116, max(34, int(width * .48))))
    panelwork(block, width, depth, 0, height - 1.45)
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


def bridges(h):
    wood, stone, gold = (h.m(role) for role in ("Lacquer", "Masonry", "Gold"))
    for a, b, y, z in ((-238, -90, -173, 136), (94, 230, -150, 130), (-171, 134, -261, 206)):
        midpoint = (a + b) * .5
        width = b - a
        stone.box((midpoint, y, z - 2), (width + 2.8, 16, 4), bevel=.45)
        for i in range(1, int(width / 8)):
            x = a + i * 8
            for s in (-1, 1):
                wood.box((x, y + s * 6.4, z + 2.6), (1.8, 2.1, 5.2), bevel=.15)
        for s in (-1, 1):
            wood.box((midpoint, y + s * 6.4, z + 4.9), (width, 2.2, 1.04), bevel=.21)
            gold.box((midpoint, y + s * 7.38, z + 4.4), (width, .26, .35), bevel=.06)
        for x in (a + width * .26, b - width * .22):
            stone.box((x, y, z - 37), (13.1, 16.4, 69), bevel=.94)


def form(mesh, point, dimensions, yaw=0):
    ox, oy, oz = point
    sx, sy, sz = dimensions
    transform = Matrix.Translation(Vector((ox, oy, oz))) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Diagonal((sx, sy, sz, 1))
    shape = [(math.cos(t), math.sin(t)) for t in [-math.pi / 2 + i * math.pi / 12 for i in range(13)]]
    return mesh.lathe(shape, 20, transform)


def lion(h, location, yaw):
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
    merge(h, carving, at(*location) @ Matrix.Rotation(yaw, 4, "Z"))


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


def aged_tree(h):
    bark, twigs = h.m("Bark"), h.m("BarkTwigs")
    profile = [((1 + .09 * math.sin(a * 6)) * math.cos(a), (1 + .11 * math.cos(a * 7)) * math.sin(a))
               for a in [k * math.tau / 28 for k in range(28)]]
    trunk = [Vector(p) for p in ((-83, 6, 39), (-73, -42, 88), (-43, -83, 142),
             (-34, -114, 181), (-55, -165, 226), (-29, -211, 275),
             (-10, -234, 319), (-29, -227, 367), (-6, -240, 421))]
    organic_path(bark, profile, trunk, [36, 35, 29, 26, 26, 23, 23, 19, 7.5])
    roots = [
        [trunk[1], (-80, -18, 72), (-88, 13, 63), (-106, 67, 45), (-88, 113, 30), (-96, 152, 15)],
        [trunk[2], (-55, -59, 126), (-74, -29, 104), (-123, -6, 86), (-119, 19, 59), (-109, 66, 48), (-101, 97, 26)],
        [trunk[1], (-102, -15, 79), (-117, -2, 69), (-147, -1, 59), (-151, 33, 48), (-169, 42, 20)],
        [trunk[3], (-16, -94, 163), (-29, -67, 151), (-53, -41, 127), (-47, -9, 103)],
        [trunk[5], (15, -174, 245), (37, -144, 209), (66, -108, 183), (47, -84, 156)],
        [trunk[0], (-104, 20, 48), (-119, 48, 41), (-111, 82, 30), (-132, 151, 9)],
    ]
    for index, points in enumerate(roots):
        root_radius = (15.3, 16.0, 13.8, 12.5, 12.8, 10.9)[index]
        radii = [root_radius * (1 - i / (len(points) - 1)) ** .86 + 1.1 for i in range(len(points))]
        route = [Vector(p) for p in points]
        organic_path(bark, profile, route, radii)
        for j in range(2, len(points) - 1):
            p = route[j]
            side = -1 if (index + j) % 3 else 1
            organic_path(bark, circle(10), [p, p + Vector((side * 12, 7, -5)),
                        p + Vector((side * 17, 20, -18)), p + Vector((side * 12, 29, -24))],
                         [radii[j] * .48, radii[j] * .43, radii[j] * .17, .30])
    # Large lobes and bark fillets follow the trunk itself, with irregular spacing and scale.
    for i in range(15):
        phase = i * math.tau / 15 + RNG.uniform(-.15, .16)
        start = RNG.randrange(0, 5)
        finish = RNG.randrange(max(6, start + 3), len(trunk) + 1)
        route, scales = [], []
        for j in range(start, finish):
            t = phase + .22 * j + .28 * math.sin(j * .85 + i)
            r = (29 - 1.8 * j) * RNG.uniform(.89, 1.04)
            route.append(trunk[j] + Vector((math.cos(t) * r, math.sin(t) * r, RNG.uniform(-4, 4))))
            scales.append(RNG.uniform(1.1, 3.55) * (0.42 if j == finish - 1 else 1))
        organic_path(bark, circle(8), route, scales)
    limbs = [
        (6, [(-46, -222, 333), (-97, -207, 356), (-141, -218, 350), (-180, -217, 382),
             (-225, -239, 393), (-267, -225, 424)], [17, 14, 10.1, 8.0, 5.6, 3.5]),
        (6, [(27, -218, 344), (79, -207, 361), (135, -243, 368), (181, -257, 398),
             (233, -271, 396), (275, -287, 426)], [15.5, 12.9, 10.1, 7.2, 5.1, 3.3]),
        (7, [(-55, -240, 390), (-85, -267, 421), (-98, -269, 453), (-147, -299, 470)], [11, 8.0, 6.2, 3.0]),
        (7, [(-1, -245, 399), (44, -255, 419), (91, -276, 414), (143, -282, 458),
             (176, -290, 463)], [13, 10, 8.1, 5.5, 3.1]),
        (6, [(-30, -276, 353), (-63, -306, 390), (-91, -337, 399), (-129, -374, 433)], [10.6, 8.1, 5.8, 2.2]),
        (8, [(5, -233, 443), (23, -248, 471), (49, -236, 492), (46, -272, 526)], [7.6, 6.1, 4.0, 2.1]),
    ]
    def twig(start, direction, length, radius, depth):
        if length < 1.45:
            return
        direction = direction.normalized()
        side = direction.cross(UP).normalized()
        if side.length < .001:
            side = Vector((1, 0, 0))
        middle = start + direction * (length * .48) + side * length * RNG.uniform(-.17, .15)
        end = start + direction * length + UP * RNG.uniform(.06, .30) * length
        if radius >= 2.6:
            organic_path(bark, circle(9), [start, middle, end], [radius * 1.17, radius * .72, radius * .30])
        else:
            twigs.sweep(circle(6), [start, middle, end], scales=[radius, radius * .52, max(.06, radius * .20)])
        if depth:
            for k in range(3):
                sign = -1 if k % 2 == 0 else 1
                where = (middle.lerp(end, RNG.uniform(.18, .70)) if k < 2 else end)
                vector = direction * RNG.uniform(.5, 1.1) + side * RNG.uniform(.34, .92) * sign + UP * RNG.uniform(.22, .73)
                twig(where, vector, length * RNG.uniform(.43, .65), radius * RNG.uniform(.37, .54), depth - 1)
    for base, points, radii in limbs:
        route = [trunk[base]] + [Vector(x) for x in points]
        organic_path(bark, profile, route, [radii[0] * 1.15] + radii)
        for i in range(1, len(route)):
            v = (route[i] - route[i - 1]).normalized()
            for k in range(2):
                direction = v + Vector((RNG.uniform(-.33, .34), RNG.uniform(-.55, .45), RNG.uniform(.36, .99)))
                twig(route[i] if k else route[i - 1].lerp(route[i], .58), direction, RNG.uniform(31, 63),
                     radii[i - 1] * RNG.uniform(.38, .60), 3)
    # Small tendrils along the lowest roots and under the awnings.
    ivy, moss = h.m("Ivy"), h.m("Moss")
    for width, y, z in ((169, -74, 153), (254, -119, 205), (229, -169, 260), (180, -241, 304)):
        for i in range(44):
            x = RNG.uniform(-width * .48, width * .48)
            drop = RNG.uniform(6, 27)
            points = [Vector((x + math.sin(j * .71 + i) * 1.56, y + math.sin(j * 1.34) * .72, z - j / 8 * drop)) for j in range(9)]
            twigs.sweep(circle(5), points, scales=[.45 - j * .043 for j in range(9)])
            for p, q in zip(points, points[1:]):
                for k in range(4):
                    stem = p.lerp(q, k / 4) + Vector((RNG.uniform(-1.04, 1.04), .41, RNG.uniform(-.15, .15)))
                    kit.leaf(ivy if k % 3 else moss, stem, RNG.uniform(.48, 1.44))


def art_materials():
    kit.PALETTE.update({
        "Masonry": ((.30, .30, .27), (.069, .086, .057), .83, .08),
        "Tile": ((.076, .090, .102), (.016, .021, .025), .42, .27),
        "Lacquer": ((.245, .050, .037), (.085, .016, .010), .68, .20),
        "Bark": ((.48, .445, .375), (.073, .063, .045), .89, .18),
        "Gold": ((.39, .235, .085), (.17, .090, .025), .53, .30),
        "Cloth": ((.30, .061, .043), (.12, .020, .014), .92, .26),
        "DarkStone": ((.055, .066, .061), (.023, .026, .023), .85, .22),
        "Lantern": ((1, .78, .37), (.83, .39, .074), .47, .55),
    })
    mats = kit.materials()
    nodes = mats["Lantern"].node_tree.nodes
    shader = nodes.get("Principled BSDF")
    shader.inputs["Emission Color"].default_value = (1, .43, .094, 1)
    shader.inputs["Emission Strength"].default_value = 5.8
    bark = mats["Bark"].node_tree
    coord = next(n for n in bark.nodes if n.type == "TEX_COORD")
    scale = bark.nodes.new("ShaderNodeVectorMath")
    scale.operation = "MULTIPLY"
    scale.inputs[1].default_value = (.69, .63, .15)
    bark.links.new(coord.outputs["Object"], scale.inputs[0])
    grain = bark.nodes.new("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 1.65
    grain.inputs["Detail"].default_value = 5.0
    grain.inputs["Roughness"].default_value = .77
    bark.links.new(scale.outputs[0], grain.inputs["Vector"])
    layer = bark.nodes.new("ShaderNodeBump")
    layer.inputs["Strength"].default_value = .65
    layer.inputs["Distance"].default_value = .52
    bump = next(n for n in bark.nodes if n.type == "BUMP" and n != layer)
    bark.links.new(grain.outputs["Fac"], layer.inputs["Height"])
    bark.links.new(bump.outputs["Normal"], layer.inputs["Normal"])
    bark.links.new(layer.outputs["Normal"], bark.nodes.get("Principled BSDF").inputs["Normal"])
    return mats


def fuse_tree(obj):
    """Voxel-union the closed branch cores. Preserve the thinnest twigs as separate render geometry."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    obj.data.remesh_voxel_size = .92
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
    assert components and len(components[0]) >= .95 * len(tree.verts), "Major branches detached from trunk"
    bmesh.ops.delete(tree, geom=[vertex for component in components[1:] for vertex in component], context="VERTS")
    assert all(edge.is_manifold for edge in tree.edges), "Fused bark contains open seams"
    tree.to_mesh(obj.data)
    tree.free()
    smooth = obj.modifiers.new("Blend grown wood junctions", "SMOOTH")
    smooth.factor = .55
    smooth.iterations = 4
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    vertices = obj.data.vertices
    coords = array("f", [0]) * (3 * len(vertices))
    normals = array("f", [0]) * len(coords)
    vertices.foreach_get("co", coords)
    vertices.foreach_get("normal", normals)
    for i in range(0, len(coords), 3):
        p = Vector(coords[i:i + 3])
        texture = noise_vector(Vector((p.x * .48, p.y * .45, p.z * .15)))[0]
        for axis in range(3):
            coords[i + axis] += normals[i + axis] * texture * .50
    vertices.foreach_set("co", coords)
    obj.data.update()
    obj.data.shade_smooth()
    print("United tree body", len(obj.data.vertices), "vertices", flush=True)


def atmosphere(scene, mats):
    world = scene.world.node_tree
    background = world.nodes.get("Background")
    direction = world.nodes.new("ShaderNodeTexCoord")
    cloud = world.nodes.new("ShaderNodeTexNoise")
    cloud.inputs["Scale"].default_value = 7.6
    cloud.inputs["Detail"].default_value = 5.2
    cloud.inputs["Roughness"].default_value = .67
    world.links.new(direction.outputs["Normal"], cloud.inputs["Vector"])
    storm = world.nodes.new("ShaderNodeValToRGB")
    storm.color_ramp.elements[0].position = .27
    storm.color_ramp.elements[0].color = (.035, .044, .053, 1)
    storm.color_ramp.elements[1].position = .73
    storm.color_ramp.elements[1].color = (.64, .66, .68, 1)
    storm.color_ramp.elements.new(.54).color = (.13, .15, .17, 1)
    world.links.new(cloud.outputs["Fac"], storm.inputs[0])
    world.links.new(storm.outputs[0], background.inputs["Color"])
    background.inputs["Strength"].default_value = .66
    fog = bpy.data.materials.new("Bellwood drifting cliff mist")
    fog.use_nodes = True
    nodes, links = fog.node_tree.nodes, fog.node_tree.links
    nodes.remove(nodes.get("Principled BSDF"))
    haze = nodes.new("ShaderNodeVolumePrincipled")
    haze.inputs["Color"].default_value = (.68, .74, .76, 1)
    haze.inputs["Anisotropy"].default_value = .35
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 4.7
    remap = nodes.new("ShaderNodeValToRGB")
    remap.color_ramp.elements[0].position = .38
    remap.color_ramp.elements[0].color = (0, 0, 0, 1)
    remap.color_ramp.elements[1].position = .7
    remap.color_ramp.elements[1].color = (.007, .007, .007, 1)
    coordinates = nodes.new("ShaderNodeTexCoord")
    geodistance = nodes.new("ShaderNodeVectorMath")
    geodistance.operation = "DISTANCE"
    geodistance.inputs[1].default_value = (.5, .5, .5)
    links.new(coordinates.outputs["Generated"], geodistance.inputs[0])
    falloff = nodes.new("ShaderNodeMapRange")
    falloff.clamp = True
    falloff.inputs["From Min"].default_value = .10
    falloff.inputs["From Max"].default_value = .49
    falloff.inputs["To Min"].default_value = 1
    falloff.inputs["To Max"].default_value = 0
    links.new(geodistance.outputs["Value"], falloff.inputs["Value"])
    volume_density = nodes.new("ShaderNodeMath")
    volume_density.operation = "MULTIPLY"
    links.new(noise.outputs["Fac"], remap.inputs[0])
    links.new(remap.outputs["Color"], volume_density.inputs[0])
    links.new(falloff.outputs[0], volume_density.inputs[1])
    links.new(volume_density.outputs[0], haze.inputs["Density"])
    links.new(haze.outputs["Volume"], nodes.get("Material Output").inputs["Volume"])
    for location, size in (((-114, 72, 34),(123, 142, 20)), ((111, -17, 63),(126, 163, 21)),
                           ((-210, -191, 113),(132, 183, 41)), ((122, -277, 109),(212, 149, 35))):
        bpy.ops.mesh.primitive_cube_add(size=2, location=location)
        obj = bpy.context.object
        obj.name = "Broken ribbons of fog"
        obj.scale = size
        obj.data.materials.append(fog)
    for i in range(30):
        x = (i % 15 - 7) * 53
        y = -446 - (i // 15) * 122 + RNG.uniform(-40, 53)
        if abs(x) < 158:
            continue
        z = RNG.uniform(121, 234)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=1, location=(x, y, z * .49))
        rock = bpy.context.object
        rock.name = "Distant slate crag"
        for vert in rock.data.vertices:
            v = vert.co
            wave = math.sin(v.x * 5.2 + i) * math.cos(v.z * 4.7 - i) + math.sin(v.y * 11.3 + v.z * 7.5) * .29
            v.x += wave * .22
            v.y += wave * .24
            v.z += .085 * math.sin(v.x * 6.34 + v.y * 5.4)
        rock.scale = (RNG.uniform(23,49), RNG.uniform(20,51), z)
        rock.rotation_euler = (RNG.uniform(-.19, .19), RNG.uniform(-.15, .15), RNG.uniform(-.64, .64))
        rock.data.materials.append(mats["Masonry"])


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    temple = Hall()
    stonework(temple)
    pavilion(temple, (28, -106, 88), 184, 116, 64, 7, arch=True)
    pavilion(temple, (-19, -177, 142), 260, 139, 53, 9, arch=True)
    pavilion(temple, (6, -237, 199), 235, 139, 52, 7)
    pavilion(temple, (-9, -290, 255), 192, 120, 49, 7)
    pavilion(temple, (3, -308, 311), 148, 105, 34, 5)
    for location, w, d, ht in (((-228, -171, 132), 71, 67, 32), ((194, -165, 130), 75, 73, 30),
                                ((-148, -132, 105), 87, 64, 37), ((168, -226, 181), 63, 59, 34),
                                ((-147, -241, 208), 67, 60, 39)):
        pavilion(temple, location, w, d, ht, 3)
    bridges(temple)
    for side, k, angle in ((-1, 49, -.15), (1, 56, .30)):
        x, y, z, width = stair_profile(k)
        x += side * (.51 * width + 8.2)
        temple.m("Masonry").box((x, y, z + .9), (26.8, 25.6, 12.1), bevel=.77)
        lion(temple, (x, y, z + 6.65), angle)
    lamps = []
    for k in (13, 24, 42, 53, 68, 88, 101, 117, 130):
        x, y, z, w = stair_profile(k)
        for s in (-1, 1):
            lamps.append(lantern(temple, (x + s * (w * .52 + 3.1), y, z + 2.75), RNG.uniform(.73, 1.0)))
    for x, y, z in ((-13, -55, 90), (69, -55, 90), (-98, -122, 143), (85, -127, 143),
                    (-204, -166, 132), (175, -162, 130), (28, -84, 90), (14, -92, 90)):
        lamps.append(lantern(temple, (x, y, z), 1.02))
    aged_tree(temple)
    mats = art_materials()
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
        if role in {"Bark", "BarkTwigs", "Masonry", "DarkStone"}:
            mesh.shade_smooth()
        mesh.set_sharp_from_angle(angle=math.radians(31))
        obj = bpy.data.objects.new(source.name, mesh)
        obj.data.materials.append(mats["Bark" if role == "BarkTwigs" else role])
        bpy.context.collection.objects.link(obj)
        if role == "Bark":
            fuse_tree(obj)
    scene, camera, mannequin = figures.setup_scene(samples=int(os.environ.get("VESP_RENDER_SAMPLES", 12)), cool_rim=True)
    atmosphere(scene, mats)
    bpy.data.objects["Ground"].scale = (30, 30, 1)
    bpy.data.objects["Ground"].data.materials[0] = mats["Masonry"]
    mannequin.location = (-15.5, 268, 1.0)
    mannequin.data.materials[0] = mats["DarkStone"]
    bpy.data.lights["overcast"].energy = 1.45
    bpy.data.lights["rim"].energy = 2.55
    bpy.data.lights["rim"].color = (.83, .89, .94)
    for i, position in enumerate(lamps):
        light("Temple amber " + str(i), position, (position[0], position[1] + 1, position[2] - 5), 330, 1.8, (1, .59, .24))
    light("Doorway behind the shrine", (30, -92, 105), (33, -51, 111), 36000, 12.0, (1, .54, .23))
    light("Diffuse sky through fog", (162, -120, 391), (-29, -176, 234), 280000, 132, (.79, .89, 1))
    scene.render.resolution_x, scene.render.resolution_y = 900, 1350
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 94
    scene.view_settings.exposure = .65
    camera.data.sensor_fit = "VERTICAL"
    camera.data.clip_end = 8000
    camera.data.angle_y = math.radians(55)
    figures.look_at(camera, (-22, 325, 6.5), (5, -120, 167))
    scene.render.filepath = str(OUT / "bellwood_stair_reference_view.jpg")
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "bellwood_stair_reference.blend"))
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()

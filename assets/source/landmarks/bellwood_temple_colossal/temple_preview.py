"""Colossal Bellwood hall design study. Dimensions are in studs."""

import math
import os
from pathlib import Path
import random
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "tools/blender"))
sys.path.insert(0, str(ROOT / "tools/blender/vesperhold"))
import lobby_kit_roofs as roofs
from lobby_kit_geo import Mesh
import vesperhold_figures as figures
import vesperhold_gargoyles as render

OUT = ROOT / "work/sol-bellwood-scale"
SEED = random.Random(31)
PALETTE = {
    "Masonry": ((0.24, 0.225, 0.18), (0.084, 0.105, 0.062), 0.86, 0.09),
    "Lacquer": ((0.37, 0.070, 0.037), (0.100, 0.014, 0.009), 0.71, 0.13),
    "Tile": ((0.14, 0.20, 0.16), (0.041, 0.051, 0.039), 0.73, 0.23),
    "Soffit": ((0.15, 0.074, 0.032), (0.045, 0.026, 0.013), 0.82, 0.17),
    "Gold": ((0.51, 0.32, 0.11), (0.21, 0.10, 0.03), 0.64, 0.31),
    "Cloth": ((0.46, 0.052, 0.026), (0.23, 0.012, 0.010), 0.78, 0.35),
    "Bark": ((0.14, 0.078, 0.044), (0.054, 0.036, 0.022), 0.91, 0.14),
    "MapleRed": ((0.51, 0.057, 0.024), (0.29, 0.017, 0.012), 0.76, 0.23),
    "MapleAmber": ((0.62, 0.17, 0.035), (0.37, 0.042, 0.012), 0.74, 0.21),
    "MapleDeep": ((0.31, 0.036, 0.041), (0.14, 0.009, 0.025), 0.82, 0.25),
    "Ivy": ((0.21, 0.28, 0.085), (0.033, 0.052, 0.014), 0.84, 0.27),
    "Moss": ((0.19, 0.22, 0.073), (0.038, 0.052, 0.011), 0.94, 0.31),
}
POLY_HAVEN = ROOT / "assets/source/vesperhold/polyhaven"
TEXTURES = {
    "Masonry": ("medieval_blocks_03", 0.074, 0.81),
    "Tile": ("ceramic_roof_01", 0.13, 0.76),
    "Soffit": ("distressed_painted_planks", 0.16, 0.66),
    "Lacquer": ("distressed_painted_planks", 0.14, 0.65),
    "Bark": ("bark_willow_02", 0.19, 0.83),
}


class Hall:
    def __init__(self):
        self.meshes = {}

    def m(self, role):
        role = {"Roof": "Tile", "Timber": "Soffit"}.get(role, role)
        if role not in self.meshes:
            self.meshes[role] = Mesh("Bellwood_Colossal_" + role, role, 6.0)
        return self.meshes[role]


def at(x=0, y=0, z=0):
    return Matrix.Translation((x, y, z))


def organic_path(mesh, profile, steps, radii):
    points, scales = [], []
    for i in range(len(steps) - 1):
        p0, p1, p2, p3 = (steps[min(len(steps) - 1, max(0, k))] for k in range(i - 1, i + 3))
        for j in range(7):
            t = j / 7
            points.append(0.5 * (2 * p1 + (p2 - p0) * t
                                + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
            scales.append((radii[i] + (radii[i + 1] - radii[i]) * t) * (1 + 0.07 * math.sin((i + t) * 15.1)))
    mesh.sweep(profile, points + [steps[-1]], scales=scales + [radii[-1]])


def leaf(mesh, centre, length):
    angle = SEED.uniform(0, math.tau)
    axis = Vector((math.cos(angle), math.sin(angle), SEED.uniform(-0.5, 0.4))) * length
    side = Vector((-math.sin(angle), math.cos(angle), SEED.uniform(-0.5, 0.5))) * (length * 0.63)
    mesh.poly([centre - axis, centre - axis * .24 - side, centre + side * -.55 + axis * .30,
               centre + axis, centre + side * .58, centre - axis * .41 + side * .8], open_surface=True)


def platform(hall):
    stone = hall.m("Masonry")
    for w, d, z0, h in ((324, 219, 0, 4), (318, 212, 4, 8), (314, 208, 12, 2), (312, 206, 14, 2)):
        stone.box((0, 0, z0 + h / 2), (w, d, h), bevel=0.42)
    for i in range(24):
        high = 16 - 0.60 * i
        stone.box((0, 103 + (i + 0.5) * 2.05, high / 2), (94, 2.10, high), bevel=0.12)
    for x in (-49, 49):
        for i in range(6):
            y = 107 + i * 8.2
            high = 18 - 2.4 * i
            stone.box((x, y, high / 2), (4.7, 8.3, high), bevel=0.26)
            stone.box((x, y, high - 0.45), (5.3, 8.4, 0.9), bevel=0.19)
    # Separate ashlar blocks leave visible courses and broken joints at player height.
    for side in (-1, 1):
        for course in range(3):
            for x in range(-150 + course % 2 * 4, 152, 8):
                stone.box((x, side * (106 + SEED.uniform(-0.14, 0.20)), 5.0 + 2.1 * course),
                          (SEED.uniform(7.6, 7.95), 0.95, 1.88), bevel=SEED.uniform(0.08, 0.25))
        for x in range(-147, 152, 9):
            if side == 1 and abs(x) < 52:
                continue
            stone.lathe([(1.35, 0), (1.36, 0.48), (0.81, 0.8), (0.73, 3.6), (1.30, 4), (0.2, 4.7)],
                        10, at(x, 100 * side, 16))
        for y in range(-94, 100, 9):
            stone.lathe([(1.35, 0), (0.72, 0.6), (0.75, 3.6), (1.27, 4), (0.2, 4.7)], 10, at(151 * side, y, 16))


def wheel(mesh, x, y, z, radius, depth=0.28):
    ring = [Vector((x + radius * math.cos(t), y, z + radius * math.sin(t)))
            for t in [k * math.tau / 40 for k in range(41)]]
    mesh.sweep([(-depth, -depth), (depth, -depth), (depth, depth), (-depth, depth)], ring, up=Vector((0, 1, 0)), caps=False)
    centre = at(x, y, z) @ Matrix.Rotation(math.pi / 2, 4, "X")
    mesh.lathe([(radius * 0.19, -0.1), (radius * 0.19, 0.25), (0, 0.40)], 16, centre)
    for i in range(8):
        angle = i * math.tau / 8
        frame = at(x, y, z) @ Matrix.Rotation(angle, 4, "Y")
        mesh.box((radius * 0.55, 0, 0), (radius * 0.74, 0.28, depth * 1.6), frame, bevel=0.06)


def tier(hall, half_x, half_y, bottom, top, bays, radius):
    wood, so, stone, gold = (hall.m(role) for role in ("Lacquer", "Soffit", "Masonry", "Gold"))
    columns = [-half_x + 2 * half_x * i / bays for i in range(bays + 1)]
    for sign in (-1, 1):
        y = sign * half_y
        for i, x in enumerate(columns):
            stone.lathe([(radius * 1.65, 0), (radius * 1.65, 0.7), (radius * 1.28, 1.35), (radius * 1.20, 2.1)],
                        18, at(x, y, bottom))
            wood.lathe([(radius, 0), (radius * 0.94, 2.1), (radius * 0.81, top - bottom - 3),
                        (radius * 1.10, top - bottom)], 18, at(x, y, bottom + 1.1))
            for z in (bottom + 3.2, top - 3.1):
                gold.lathe([(radius * 1.03, 0), (radius * 1.03, 0.60)], 16, at(x, y, z))
            for b in range(4):
                z = top + b * 1.60
                so.box((x, y + sign * b * 0.90, z), (5.6 + b * 3.1, 7.0 + b * 2.4, 1.28), bevel=0.18)
                wood.box((x, y + sign * (4 + b * 1.35), z + 0.32), (2.42, 8.7, 1.08), bevel=0.13)
            if i < bays and (sign < 0 or abs((columns[i + 1] + x) * 0.5) > half_x * 0.30):
                middle = (x + columns[i + 1]) / 2
                span = columns[i + 1] - x - radius * 2
                soffit_y = y - 4 * sign
                so.box((middle, soffit_y, (bottom + top) / 2), (span, 0.9, top - bottom - 4), bevel=0.12)
                for k in range(1, 7):
                    xx = middle - span / 2 + span * k / 7
                    wood.box((xx, soffit_y + 0.55 * sign, (bottom + top) / 2), (0.48, 0.59, top - bottom - 5), bevel=0.05)
                for k in range(1, 4):
                    zz = bottom + (top - bottom) * k / 4
                    wood.box((middle, soffit_y + 0.58 * sign, zz), (span, 0.57, 0.52))
        wood.box((0, y, top - 1), (half_x * 2 + 8, 7, 4.5), bevel=0.35)
        wood.box((0, y, top + 5.6), (half_x * 2 + 11, 10, 2.6), bevel=0.35)
        gold.box((0, y + sign * 3.7, top - 0.4), (half_x * 2 + 4, 0.66, 1.0), bevel=0.10)
    for sign in (-1, 1):
        for y in (-half_y * 0.53, 0, half_y * 0.53):
            wood.lathe([(radius, 0), (radius * 0.85, top - bottom - 1), (radius * 1.13, top - bottom)], 16,
                       at(sign * half_x, y, bottom))
        wood.box((sign * half_x, 0, top - 1), (6, 2 * half_y + 3, 4.4), bevel=0.35)


def roof(hall, w, d, rise, z, n):
    roof_kit = Hall()
    roofs.hall(roof_kit, W=w, D=d, H=rise, tg=0.55, lift=7.5, kick=4.5, thick=(1.2, 2.6),
               ridge_scale=2.0, nu=n, nt=(13, 10))
    for role, mesh in roof_kit.meshes.items():
        hall.m(role).merge(mesh.bm, at(z=z))
    # The front roof reads as physical tile courses in grazing light. Missing
    # clusters make the undamaged courses the exception near the broken hips.
    tile = hall.m("Tile")
    for course in range(14):
        t0 = course / 14
        t1 = min(1, (course + 1.16) / 14)
        width = w - d * min(t0, .55)
        y0, y1 = d * (1 - t0) * .5, d * (1 - t1) * .5
        z0, z1 = rise * (.3 * t0 + .7 * t0 * t0), rise * (.3 * t1 + .7 * t1 * t1)
        for col in range(-int(width / 6) + 3, int(width / 6) - 2):
            if (course < 8 and abs(col + 19) < 2 + course // 3) or (course < 5 and 27 < col < 32):
                continue
            x = (col + .5 * (course % 2)) * 3.03 + SEED.uniform(-.13, .13)
            lift = SEED.uniform(.25, .56)
            profiles = []
            for y, zz in ((y0, z0), (y1, z1)):
                profiles.append([Vector((x + dx, y, z + zz + lift + dy)) for dx, dy in
                                 [(-.67, 0), (-.44, .36), (0, .55), (.44, .36), (.67, 0)]])
            tile.grid(profiles, None, expect=Vector((0, 0, 1)), open_surface=True)
    gold = hall.m("Gold")
    for s in (-1, 1):
        x = s * (w - 0.55 * d) * 0.5
        gold.lathe([(1.7, 0), (1.45, 0.65), (0.7, 2.1), (1.05, 2.7), (0, 4.1)], 14, at(x, 0, z + rise + 1.4))


def banners(hall):
    cloth, gold = hall.m("Cloth"), hall.m("Gold")
    for i, x in enumerate((-111, -84, -55, 55, 84, 111)):
        y, top = 68.3, 65
        length = 34 - (i % 3) * 3
        width = 6.3
        grid = []
        for r in range(21):
            t = r / 20
            row = []
            for c in range(8):
                u = c / 7
                drift = math.sin(t * 8 + i) * t * 0.62
                torn = t ** 10 * (math.sin(u * 35 + i) * 1.4 + math.cos(u * 57) * 0.28)
                row.append(Vector((x + (u - 0.5) * width + drift, y + math.sin(u * math.pi * 2 + t * 6) * 0.25, top - length * t - torn)))
            grid.append(row)
        cloth.grid(grid, None, expect=Vector((0, 1, 0)), open_surface=True)
        gold.box((x, y, top + 0.45), (width + 1.4, 0.7, 0.62), bevel=0.13)
        wheel(gold, x, y + 0.33, top - 8.5, 2.1, 0.12)
    wheel(gold, 0, 66.25, 61.8, 4.3, 0.38)


def maple(hall):
    bark = hall.m("Bark")
    circle = [(math.cos(i * math.tau / 12), math.sin(i * math.tau / 12)) for i in range(12)]
    base = Vector((-3, -9, 154))
    trunk = [base, base + Vector((-4, 1, 18)), base + Vector((-5, 3, 38)), base + Vector((5, 1, 56)),
             base + Vector((19, -5, 73)), base + Vector((21, -8, 89))]
    organic_path(bark, circle, trunk, [14.6, 11.7, 8.8, 6.0, 4.0, 0.55])
    for i, extent in enumerate((-118, -88, -62, -35, -12, 25, 43, 68, 104, 129)):
        rank = i % 4
        path = [base + Vector((extent * .04, 5, 8)),
                Vector((extent * .21, 14, 151)), Vector((extent * .43, 35, 145 + rank)),
                Vector((extent * .55, 43, 137)), Vector((extent * .72, 55, 116 + rank)),
                Vector((extent * .90, 66, 104)), Vector((extent, 76 + rank, 78)),
                Vector((extent * 1.03, 78 + rank * 3, 67 - rank * 4))]
        organic_path(bark, circle, path, [7.2, 6.7, 5.1, 4.3, 3.6, 2.8, 1.6, 0.30])
        fork = path[3] + Vector((SEED.uniform(-19, 19), -0.6, 1.5))
        organic_path(bark, circle, [path[2], fork, fork + Vector((extent * .13, 6.5, -8.1)),
                                    fork + Vector((extent * .19, 16, -16))], [2.2, 1.6, .83, .16])
    leaves = [hall.m(k) for k in ("MapleDeep", "MapleRed", "MapleAmber")]
    for i in range(13):
        ang = math.tau * i / 13 + SEED.uniform(-0.26, 0.26)
        x, y = math.cos(ang), math.sin(ang)
        foot = trunk[2 + i % 3]
        reach = SEED.uniform(48, 144)
        end = Vector((x * reach + 14, y * reach * 0.70, SEED.uniform(208, 251)))
        mid = foot.lerp(end, 0.51) + Vector((y * 7, -x * 8, 8.0))
        organic_path(bark, circle, [foot, foot.lerp(mid, 0.44), mid, mid.lerp(end, 0.49), end], [5.3, 4.2, 2.9, 1.6, 0.26])
        for j in range(4):
            cloud = end.lerp(mid, j * 0.16) + Vector((SEED.uniform(-13, 13), SEED.uniform(-13, 13), SEED.uniform(-2, 12)))
            for _ in range(225):
                u, v = SEED.uniform(-1, 1), SEED.uniform(-math.pi, math.pi)
                r = SEED.random() ** (1 / 3)
                h = math.sqrt(1 - u * u)
                offset = Vector((math.cos(v) * h * 21, math.sin(v) * h * 17, u * 9)) * r
                centre = cloud + offset
                ang2 = SEED.uniform(0, math.tau)
                scale = SEED.uniform(1.2, 2.35)
                axis = Vector((math.cos(ang2), math.sin(ang2), SEED.uniform(-0.25, 0.38))) * scale
                cross = Vector((-math.sin(ang2), math.cos(ang2), SEED.uniform(-0.4, 0.45))) * scale
                colour = leaves[SEED.choices((0, 1, 2), weights=(2, 5, 1))[0]]
                colour.poly([centre - cross, centre - axis * 0.77, centre - axis * 0.45 + cross * 0.2,
                             centre + cross, centre + axis * 0.53 + cross * 0.2, centre + axis,], open_surface=True)


def overgrowth(hall):
    ivy, stems, moss = (hall.m(k) for k in ("Ivy", "Bark", "Moss"))
    profile = [(-.78, .1), (0, -1), (.78, .1), (0, 1)]
    for width, front, top in ((282, 83, 67), (192, 60, 105), (122, 44, 136)):
        for _ in range(45):
            x = SEED.uniform(-width / 2, width / 2)
            if top < 70 and abs(x) < 38 and SEED.random() < .75:
                continue
            y = front + SEED.uniform(-1.2, 3.8)
            length = SEED.uniform(5, 36)
            bend = SEED.uniform(-6.4, 6.4)
            path = [Vector((x + bend * (k / 8) ** 1.3 + math.sin(k * .8) * .84, y + math.sin(k * 1.22) * .6,
                            top - length * k / 8)) for k in range(9)]
            organic_path(stems, profile, path, [.22 - .018 * k for k in range(9)])
            for p, q in zip(path, path[1:]):
                for i in range(4):
                    centre = p.lerp(q, (i + .4) / 4) + Vector((SEED.uniform(-1.5, 1.5), .36, SEED.uniform(-.28, .30)))
                    leaf(ivy, centre, SEED.uniform(.70, 1.40))
    for _ in range(1800):
        x = SEED.uniform(-160, 160)
        y = SEED.uniform(98, 110) if SEED.random() < .7 else SEED.choice((-1, 1)) * SEED.uniform(70, 98)
        if y > 100 and abs(x) < 48:
            continue
        z = 14.3 if abs(y) > 104 else 16.1
        leaf(moss, Vector((x, y, z + SEED.uniform(0.05, .43))), SEED.uniform(.52, 1.78))


def flooded_fragments(hall):
    s = hall.m("Masonry")
    for x, y, z, scale, lean in ((-171, 151, 1, 1.0, -0.21), (-191, 165, 0.4, .86, 0.11), (-212, 180, 0, .71, -0.66),
                                (142, 167, 0, .56, 1.22), (170, 192, 0, .44, -1.10)):
        frame = at(x, y, z) @ Matrix.Rotation(lean, 4, "Y") @ Matrix.Scale(scale, 4)
        s.box((0, 0, 1.45), (13, 12, 3.4), frame, bevel=.52)
        s.lathe([(5.2, 2.8), (4.0, 5.5), (3.6, 8), (3.21, 35.6), (3.72, 37.4), (4.4, 39.4)], 14, frame)
        s.box((0, 0, 40.2), (9.5, 10.1, 3.1), frame, bevel=.32)
    for _ in range(100):
        x, y = SEED.uniform(-235, 235), SEED.uniform(108, 198)
        if abs(x) < 52 and y < 164:
            continue
        size = SEED.uniform(.9, 4.9)
        a = SEED.uniform(-math.pi, math.pi)
        frame = at(x, y, SEED.uniform(.4, 2.3)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(a * .2, 4, "X")
        s.box((0, 0, 0), (size * SEED.uniform(.7, 1.6), size, size * .45), frame, bevel=size * .137)


def materials():
    out = {}
    for name, (light, dark, roughness, noise_scale) in PALETTE.items():
        m = bpy.data.materials.new("BellwoodPreview_" + name)
        m.diffuse_color = (*light, 1)
        m.use_nodes = True
        nodes, links = m.node_tree.nodes, m.node_tree.links
        shader = nodes.get("Principled BSDF")
        noise = nodes.new("ShaderNodeTexNoise")
        coords = nodes.new("ShaderNodeTexCoord")
        noise.inputs["Scale"].default_value = noise_scale
        noise.inputs["Detail"].default_value = 4
        noise.inputs["Roughness"].default_value = 0.68
        links.new(coords.outputs["Object"], noise.inputs["Vector"])
        color = nodes.new("ShaderNodeValToRGB")
        color.color_ramp.elements[0].color = (*dark, 1)
        color.color_ramp.elements[1].color = (*light, 1)
        links.new(noise.outputs["Fac"], color.inputs[0])
        links.new(color.outputs[0], shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value = roughness
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.27
        bump.inputs["Distance"].default_value = 0.16
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs[0], shader.inputs["Normal"])
        if name == "Gold":
            shader.inputs["Metallic"].default_value = 0.62
        if name in TEXTURES:
            asset, scale, influence = TEXTURES[name]
            folder = POLY_HAVEN / asset
            vector = nodes.new("ShaderNodeVectorMath")
            vector.operation = "SCALE"
            vector.inputs["Scale"].default_value = scale
            links.new(coords.outputs["Object"], vector.inputs[0])
            diffuse = nodes.new("ShaderNodeTexImage")
            diffuse.image = bpy.data.images.load(str(folder / f"{asset}_Diffuse_2k.jpg"), check_existing=True)
            diffuse.projection = "BOX"
            diffuse.projection_blend = .16
            links.new(vector.outputs[0], diffuse.inputs["Vector"])
            mixed = nodes.new("ShaderNodeMixRGB")
            mixed.blend_type = "MULTIPLY"
            mixed.inputs[0].default_value = influence
            links.new(color.outputs[0], mixed.inputs[1])
            links.new(diffuse.outputs["Color"], mixed.inputs[2])
            links.new(mixed.outputs[0], shader.inputs["Base Color"])
            links.new(diffuse.outputs["Color"], bump.inputs["Height"])
            bump.inputs["Strength"].default_value = .52
            bump.inputs["Distance"].default_value = .35
        out[name] = m
    return out


def scene_water():
    ground = bpy.data.objects["Ground"]
    ground.location.z = 2.7
    water = ground.data.materials[0]
    shader = water.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (0.024, 0.055, 0.046, 1)
    shader.inputs["Roughness"].default_value = .215
    shader.inputs["Metallic"].default_value = .38
    noise = water.node_tree.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.24
    noise.inputs["Detail"].default_value = 3.8
    tex = water.node_tree.nodes.new("ShaderNodeTexCoord")
    water.node_tree.links.new(tex.outputs["Object"], noise.inputs["Vector"])
    bump = water.node_tree.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = .46
    bump.inputs["Distance"].default_value = .31
    water.node_tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    water.node_tree.links.new(bump.outputs[0], shader.inputs["Normal"])
    bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 108, 10))
    haze = bpy.context.object
    haze.name = "Lake-level mist"
    haze.scale = (255, 194, 10.7)
    material = bpy.data.materials.new("Low drifting mist")
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.remove(nodes.get("Principled BSDF"))
    volume = nodes.new("ShaderNodeVolumePrincipled")
    volume.inputs["Color"].default_value = (.64, .72, .69, 1)
    volume.inputs["Anisotropy"].default_value = .27
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 5.2
    strength = nodes.new("ShaderNodeMath")
    strength.operation = "MULTIPLY"
    strength.inputs[1].default_value = .0030
    links.new(noise.outputs["Fac"], strength.inputs[0])
    links.new(strength.outputs[0], volume.inputs["Density"])
    links.new(volume.outputs["Volume"], nodes.get("Material Output").inputs["Volume"])
    haze.data.materials.append(material)


def backdrop(material):
    for i in range(21):
        x = -460 + i * 46
        if abs(x) < 133:
            continue
        y = SEED.uniform(-338, -272)
        height = SEED.uniform(43, 118) * (1 if abs(x) < 350 else 1.4)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1, location=(x, y, height * .33))
        rock = bpy.context.object
        rock.name = "Distant lake cliff"
        for vert in rock.data.vertices:
            v = vert.co
            v *= 1 + .14 * math.sin(5.6 * v.x + i) * math.cos(4.8 * v.z - i)
        rock.scale = (SEED.uniform(42, 71), SEED.uniform(42, 75), height)
        rock.rotation_euler = (0.18, SEED.uniform(-.32, .32), SEED.random() * math.tau)
        rock.data.materials.append(material)


def light(name, where, target, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size, data.color = energy, "DISK", size, color
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = where
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    hall = Hall()
    platform(hall)
    tier(hall, 124, 58, 16, 59, 9, 2.8)
    roof(hall, 306, 163, 30, 66, 106)
    tier(hall, 81, 41, 75, 96, 7, 2.1)
    roof(hall, 209, 116, 25, 103, 88)
    tier(hall, 53, 28, 110, 128, 5, 1.7)
    roof(hall, 137, 83, 21, 135, 64)
    banners(hall)
    maple(hall)
    overgrowth(hall)
    flooded_fragments(hall)
    palette = materials()
    objects = []
    for role, source in hall.meshes.items():
        bm = source.finish()
        mesh = bpy.data.meshes.new(source.name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        mesh.set_sharp_from_angle(angle=math.radians(33))
        obj = bpy.data.objects.new(source.name, mesh)
        obj.data.materials.append(palette[role])
        bpy.context.collection.objects.link(obj)
        objects.append(obj)
    lo, hi = figures.bbox(objects)
    print("Bellwood preview bounds (studs)", tuple(round(hi[i] - lo[i], 1) for i in range(3)), flush=True)
    scene, camera, mannequin = figures.setup_scene(samples=int(os.environ.get("VESP_RENDER_SAMPLES", 12)), cool_rim=True)
    scene.render.resolution_x = 1500
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 94
    bpy.data.objects["Ground"].scale = (20, 20, 1)
    scene_water()
    backdrop(palette["Masonry"])
    bpy.data.lights["overcast"].energy = 1.22
    bpy.data.lights["rim"].energy = 2.5
    bpy.data.lights["rim"].color = (0.91, 0.84, 0.69)
    light("Warm lanterns in hall", (0, 35, 31), (0, 98, 19), 125000, 21, (1, .69, .40))
    light("Low lake fill", (-135, 170, 88), (0, 25, 75), 600000, 175, (.69, .83, .76))
    scene.view_settings.exposure = 0.87
    mannequin.location = (38, 123, 10)
    camera.data.lens = 47
    camera.data.clip_end = 6000
    figures.look_at(camera, (248, 562, 94), (0, 27, 109))
    scene.render.filepath = str(OUT / "colossal_sunken_temple_preview.jpg")
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "colossal_sunken_temple_preview.blend"))
    bpy.ops.render.render(write_still=True)
    camera.data.lens = 34
    figures.look_at(camera, (-55, 170, 23), (10, 57, 42))
    scene.render.filepath = str(OUT / "colossal_sunken_temple_player_view.jpg")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()

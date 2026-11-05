"""Authors the Foundry wing's art kit: real geometry, procedural materials baked to one PBR atlas per piece.

Units are studs. Blender -Y faces world +Z at yaw 0, and every piece's origin is its ground centre.
  Blender -b --factory-startup --python tools/blender/foundry_kit.py -- preview OUT [piece ...]
  Blender -b --factory-startup --python tools/blender/foundry_kit.py -- bake OUT [piece ...]
Collision stays in BambooPassLayout: these are decorative meshes, sized to cover the boxes they replace.
"""
from math import atan2, cos, pi, radians, sin, tau
from pathlib import Path
import hashlib
import json
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

MAP_SIZE = 2048


# --- Materials ---------------------------------------------------------------------------------------------------
class Nodes:
    def __init__(self, name):
        self.mat = bpy.data.materials.new(name)
        self.mat.use_nodes = True
        self.tree = self.mat.node_tree
        self.bsdf = next(n for n in self.tree.nodes if n.type == "BSDF_PRINCIPLED")
        self.out = next(n for n in self.tree.nodes if n.type == "OUTPUT_MATERIAL")
        coord = self.tree.nodes.new("ShaderNodeTexCoord")
        self.obj = coord.outputs["Object"]
        uv = self.tree.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "Detail"
        self.detail = uv.outputs["UV"]
        ao = self.tree.nodes.new("ShaderNodeAmbientOcclusion")
        ao.samples = 8
        ao.inputs["Distance"].default_value = 0.8
        self.ao = ao.outputs["AO"]
        split = self.tree.nodes.new("ShaderNodeSeparateXYZ")
        self.tree.links.new(self.obj, split.inputs[0])
        self.x, self.y, self.z = split.outputs[0], split.outputs[1], split.outputs[2]

    def link(self, a, b):
        self.tree.links.new(a, b)

    def setv(self, socket, value):
        if hasattr(value, "is_linked") or hasattr(value, "links"):
            self.link(value, socket)
        else:
            socket.default_value = value if not isinstance(value, tuple) else (*value, 1)

    def noise(self, scale, detail=6, rough=0.55, vec=None, offset=0):
        node = self.tree.nodes.new("ShaderNodeTexNoise")
        node.inputs["Scale"].default_value = scale
        node.inputs["Detail"].default_value = detail
        node.inputs["Roughness"].default_value = rough
        vec = vec if vec is not None else self.obj
        if offset:
            vec = self.vec_add(vec, offset)
        self.link(vec, node.inputs["Vector"])
        return node.outputs[0]

    def vec_add(self, vec, amount):
        node = self.tree.nodes.new("ShaderNodeVectorMath")
        node.operation = "ADD"
        self.link(vec, node.inputs[0])
        node.inputs[1].default_value = (amount, amount * 1.7, amount * 0.6)
        return node.outputs[0]

    def stretch(self, vec, sx, sy, sz):
        node = self.tree.nodes.new("ShaderNodeVectorMath")
        node.operation = "MULTIPLY"
        self.link(vec, node.inputs[0])
        node.inputs[1].default_value = (sx, sy, sz)
        return node.outputs[0]

    def cracks(self, scale, vec=None, sparse=0.5):
        base = vec if vec is not None else self.obj
        wander = self.tree.nodes.new("ShaderNodeVectorMath")
        wander.operation = "ADD"
        self.link(base, wander.inputs[0])
        colour = self.tree.nodes.new("ShaderNodeTexNoise")
        colour.inputs["Scale"].default_value = scale * 1.6
        colour.inputs["Detail"].default_value = 5
        self.link(base, colour.inputs["Vector"])
        self.link(colour.outputs[1], wander.inputs[1])
        node = self.tree.nodes.new("ShaderNodeTexVoronoi")
        node.feature = "DISTANCE_TO_EDGE"
        node.inputs["Scale"].default_value = scale
        self.link(wander.outputs[0], node.inputs["Vector"])
        # Fade most of the network away, so a surface has a few long cracks rather than a tiled pattern.
        mask = self.ramp(self.noise(scale * 0.45, 4, 0.5, base, 3.1), sparse - 0.06, sparse + 0.06)
        return self.lerp(mask, 1, node.outputs[0])

    def ramp(self, value, a, b):
        node = self.tree.nodes.new("ShaderNodeMapRange")
        node.interpolation_type = "SMOOTHSTEP"
        node.inputs["From Min"].default_value = a
        node.inputs["From Max"].default_value = b
        self.link(value, node.inputs["Value"])
        return node.outputs[0]

    def math(self, op, a, b):
        node = self.tree.nodes.new("ShaderNodeMath")
        node.operation = op
        self.setv(node.inputs[0], a)
        self.setv(node.inputs[1], b)
        return node.outputs[0]

    def lerp(self, f, a, b):
        node = self.tree.nodes.new("ShaderNodeMix")
        node.data_type = "FLOAT"
        self.setv(next(s for s in node.inputs if s.identifier == "Factor_Float"), f)
        self.setv(next(s for s in node.inputs if s.identifier == "A_Float"), a)
        self.setv(next(s for s in node.inputs if s.identifier == "B_Float"), b)
        return next(s for s in node.outputs if s.identifier == "Result_Float")

    def mix(self, f, a, b, blend="MIX"):
        node = self.tree.nodes.new("ShaderNodeMix")
        node.data_type = "RGBA"
        node.blend_type = blend
        self.setv(next(s for s in node.inputs if s.identifier == "Factor_Float"), f)
        self.setv(next(s for s in node.inputs if s.identifier == "A_Color"), a)
        self.setv(next(s for s in node.inputs if s.identifier == "B_Color"), b)
        return next(s for s in node.outputs if s.identifier == "Result_Color")

    def occlude(self, color, floor=0.5):
        return self.mix(self.lerp(self.ao, 1 - floor, 0), color, (0, 0, 0))

    def finish(self, color, rough, metal, height, bump=1.0, distance=0.06, value=0.55, saturation=1.3):
        # Graded for the game's lighting, which runs far brighter than a neutral preview: measured against the first in-game bake.
        grade = self.tree.nodes.new("ShaderNodeHueSaturation")
        grade.inputs["Saturation"].default_value = saturation
        grade.inputs["Value"].default_value = value
        self.setv(grade.inputs["Color"], color)
        color = grade.outputs["Color"]
        self.color, self.rough, self.metal = color, rough, metal
        self.setv(self.bsdf.inputs["Base Color"], color)
        self.setv(self.bsdf.inputs["Roughness"], rough)
        self.setv(self.bsdf.inputs["Metallic"], metal)
        node = self.tree.nodes.new("ShaderNodeBump")
        node.inputs["Strength"].default_value = bump
        node.inputs["Distance"].default_value = distance
        self.setv(node.inputs["Height"], height)
        self.link(node.outputs[0], self.bsdf.inputs["Normal"])
        emit = self.tree.nodes.new("ShaderNodeEmission")
        self.emit = emit
        return self.mat


def bronze():
    n = Nodes("Bronze")
    streak = n.noise(1.0, 6, 0.55, n.stretch(n.obj, 2.4, 2.4, 0.28))
    cavity = n.lerp(n.ao, 1, 0)
    patina = n.ramp(n.math("ADD", n.math("MULTIPLY", streak, 0.72), n.math("MULTIPLY", cavity, 0.8)), 0.47, 0.72)
    tone = n.mix(n.noise(2.2, 7), (0.31, 0.19, 0.085), (0.19, 0.115, 0.055))
    worn = n.mix(n.ramp(n.noise(0.8, 5), 0.56, 0.68), tone, (0.47, 0.31, 0.14))
    color = n.occlude(n.mix(n.math("MULTIPLY", patina, 0.86), worn, (0.17, 0.30, 0.245)), 0.5)
    return n.finish(color, n.lerp(patina, 0.5, 0.85), n.lerp(patina, 0.6, 0.05), n.noise(14, 5), 0.3, 0.025, 0.5, 1.2)


def brick(mouth=None, top=26.0):
    n = Nodes("Brick")
    node = n.tree.nodes.new("ShaderNodeTexBrick")
    node.inputs["Scale"].default_value = 1
    node.inputs["Mortar Size"].default_value = 0.035
    node.inputs["Mortar Smooth"].default_value = 0.25
    node.inputs["Brick Width"].default_value = 1.3
    node.inputs["Row Height"].default_value = 0.44
    node.inputs["Color1"].default_value = (0.42, 0.17, 0.085, 1)
    node.inputs["Color2"].default_value = (0.27, 0.105, 0.06, 1)
    node.inputs["Mortar"].default_value = (0.46, 0.41, 0.33, 1)
    n.link(n.detail, node.inputs["Vector"])
    tinted = n.mix(n.math("MULTIPLY", n.noise(4.5, 6), 0.6), node.outputs["Color"], (0.5, 0.3, 0.18))
    streak = n.noise(1.0, 5, 0.55, n.stretch(n.obj, 0.9, 0.9, 0.07))
    rise = n.math("DIVIDE", n.z, top)
    soot = n.ramp(n.math("ADD", n.math("MULTIPLY", streak, 0.65), n.math("MULTIPLY", rise, 0.62)), 0.62, 0.92)
    if mouth:
        dist = n.tree.nodes.new("ShaderNodeVectorMath")
        dist.operation = "DISTANCE"
        n.link(n.obj, dist.inputs[0])
        dist.inputs[1].default_value = mouth
        soot = n.math("MAXIMUM", soot, n.math("MULTIPLY", n.ramp(n.math("ADD", dist.outputs["Value"], n.math("MULTIPLY", streak, 1.6)), 6.6, 3.2), 0.95))
    color = n.occlude(n.mix(n.math("MULTIPLY", soot, 0.86), tinted, (0.05, 0.045, 0.045)), 0.6)
    height = n.math("ADD", n.math("SUBTRACT", 1, node.outputs["Fac"]), n.math("MULTIPLY", n.noise(7, 6), 0.3))
    # Fired, smoke-dulled brick: at the shared grade it read as bright new orange in the game.
    return n.finish(color, n.lerp(soot, 0.86, 0.72), 0, height, 1.0, 0.09, 0.44, 0.72)


def stone():
    n = Nodes("Stone")
    crack = n.ramp(n.cracks(0.6, None, 0.6), 0, 0.012)
    base = n.mix(n.noise(2.6, 8, 0.6), (0.27, 0.25, 0.22), (0.44, 0.41, 0.36))
    color = n.occlude(n.mix(crack, (0.14, 0.13, 0.12), base), 0.55)
    return n.finish(color, 0.86, 0, n.math("ADD", crack, n.math("MULTIPLY", n.noise(11, 6), 0.4)), 0.9, 0.08)


def iron():
    n = Nodes("Iron")
    rust = n.ramp(n.noise(2.4, 8, 0.66), 0.46, 0.8)
    # Dull oxide under a dark bloom: harder, brighter rust looked like splashed orange paint in the game.
    color = n.occlude(n.mix(n.math("MULTIPLY", rust, 0.8), (0.1, 0.098, 0.095), (0.17, 0.095, 0.058)), 0.5)
    return n.finish(color, n.lerp(rust, 0.46, 0.92), n.lerp(rust, 1, 0.1), n.noise(18, 5), 0.7, 0.03, 0.5, 0.85)


def clay():
    n = Nodes("Clay")
    crack = n.ramp(n.cracks(0.9, None, 0.47), 0, 0.016)
    char = n.ramp(n.noise(0.7, 6), 0.55, 0.72)
    base = n.mix(n.noise(5, 7), (0.50, 0.35, 0.22), (0.32, 0.21, 0.13))
    color = n.occlude(n.mix(crack, (0.09, 0.07, 0.06), n.mix(char, base, (0.13, 0.11, 0.1))), 0.6)
    return n.finish(color, 0.92, 0, n.math("ADD", crack, n.math("MULTIPLY", n.noise(14, 6), 0.45)), 1.0, 0.09)


def slag():
    n = Nodes("Slag")
    oxide = n.ramp(n.noise(0.7, 7, 0.62), 0.55, 0.63)
    body = n.mix(n.noise(6, 5), (0.075, 0.07, 0.08), (0.17, 0.155, 0.15))
    color = n.occlude(n.mix(n.math("MULTIPLY", oxide, 0.6), body, (0.2, 0.1, 0.058)), 0.6)
    pitted = n.ramp(n.noise(9, 6, 0.65), 0.38, 0.62)
    return n.finish(color, n.lerp(oxide, 0.32, 0.88), n.lerp(oxide, 0.3, 0), n.math("ADD", pitted, n.math("MULTIPLY", n.noise(24, 5), 0.3)), 1.0, 0.12)


def molten():
    n = Nodes("Molten")
    vein = n.ramp(n.cracks(1.4), 0.0, 0.05)
    color = n.mix(vein, (1.0, 0.42, 0.07), n.mix(n.noise(4), (0.08, 0.07, 0.07), (0.18, 0.13, 0.11)))
    return n.finish(color, n.lerp(vein, 0.55, 0.9), 0, vein, 1.0, 0.12, 1.0, 1.0)


def timber(axis):
    n = Nodes("Timber" + axis)
    scale = {"X": (0.22, 3.6, 3.6), "Y": (3.6, 0.22, 3.6), "Z": (3.6, 3.6, 0.22)}[axis]
    grain = n.noise(1.0, 8, 0.62, n.stretch(n.obj, *scale))
    streak = n.noise(1.0, 3, 0.4, n.stretch(n.obj, scale[0] * 5, scale[1] * 5, scale[2] * 5))
    base = n.mix(n.ramp(grain, 0.34, 0.66), (0.36, 0.22, 0.12), (0.20, 0.115, 0.065))
    color = n.occlude(n.mix(n.math("MULTIPLY", streak, 0.5), base, (0.10, 0.06, 0.04)), 0.55)
    return n.finish(color, 0.74, 0, n.math("ADD", grain, n.math("MULTIPLY", streak, 0.6)), 0.8, 0.05)


# --- Geometry helpers --------------------------------------------------------------------------------------------
class Builder:
    def __init__(self, name, materials):
        self.name = name
        self.bm = bmesh.new()
        self.materials = materials
        self.index = {m.name.split(".")[0]: i for i, m in enumerate(materials)}
        self.cyl_layer = self.bm.faces.layers.int.new("uvcyl")
        self.fixed_layer = self.bm.faces.layers.int.new("fixedn")
        self.rng = random.Random(hash_name(name))

    def paint(self, faces, material, cylindrical=False, smooth=False):
        index = self.index[material]
        for f in faces:
            f.material_index = index
            f[self.cyl_layer] = 1 if cylindrical else 0
            f.smooth = smooth

    def aim(self, faces, facing):
        """Open surfaces cannot be oriented by volume, and Roblox culls back faces. `facing` is a direction, or a function of a face's centre."""
        for f in faces:
            f[self.fixed_layer] = 1
            f.normal_update()
            want = Vector(facing(f.calc_center_median())) if callable(facing) else Vector(facing)
            if f.normal.dot(want) < 0:
                f.normal_flip()

    def quad(self, points, material, facing):
        verts = [self.bm.verts.new(p) for p in points]
        face = self.bm.faces.new(verts)
        self.paint([face], material)
        self.aim([face], facing)
        return face

    def box(self, center, size, material, bevel=0.06, rot=(0, 0, 0)):
        matrix = Matrix.Translation(center) @ Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X") @ Matrix.Diagonal((*size, 1))
        verts = bmesh.ops.create_cube(self.bm, size=1, matrix=matrix)["verts"]
        edges = list({e for v in verts for e in v.link_edges})
        faces = list({f for v in verts for f in v.link_faces})
        if bevel:
            result = bmesh.ops.bevel(self.bm, geom=verts + edges, offset=bevel, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
            kept = {f for f in faces if f.is_valid} | set(result["faces"])
            for v in result["verts"]:
                kept |= set(v.link_faces)
            faces = list(kept)
        self.paint(faces, material)
        return faces

    def cylinder(self, p0, p1, radius, segments, material, radius2=None):
        p0, p1 = Vector(p0), Vector(p1)
        axis = p1 - p0
        rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
        matrix = Matrix.Translation((p0 + p1) / 2) @ rot
        verts = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius, radius2=radius if radius2 is None else radius2, depth=axis.length, matrix=matrix)["verts"]
        faces = list({f for v in verts for f in v.link_faces})
        self.paint(faces, material, True, True)
        return faces

    def lathe(self, profile, segments, material, a0=0.0, a1=tau, center=(0, 0, 0), wobble=0.0, close=True, facing=None):
        closed = close and abs(a1 - a0) >= tau - 1e-5
        rows = []
        count = segments if closed else segments + 1
        for point in profile:
            r, z = point[0], point[1]
            if r < 1e-4:
                rows.append([self.bm.verts.new((center[0], center[1], center[2] + z))])
                continue
            row = []
            for j in range(count):
                a = a0 + (a1 - a0) * j / segments
                radius = r + (self.rng.uniform(-wobble, wobble) if wobble else 0)
                row.append(self.bm.verts.new((center[0] + cos(a) * radius, center[1] + sin(a) * radius, center[2] + z)))
            rows.append(row)
        faces = []
        for i in range(len(rows) - 1):
            lo, hi = rows[i], rows[i + 1]
            spans = segments if closed else segments
            for j in range(spans):
                a, b = j % count, (j + 1) % count
                if len(lo) == 1:
                    faces.append(self.bm.faces.new((lo[0], hi[a], hi[b])))
                elif len(hi) == 1:
                    faces.append(self.bm.faces.new((lo[a], lo[b], hi[0])))
                else:
                    faces.append(self.bm.faces.new((lo[a], lo[b], hi[b], hi[a])))
        self.paint(faces, material, True, True)
        if facing == "out":
            self.aim(faces, lambda c: (c.x - center[0], c.y - center[1], 0))
        elif facing == "in":
            self.aim(faces, lambda c: (center[0] - c.x, center[1] - c.y, 0))
        elif facing:
            self.aim(faces, facing)
        return faces

    def torus(self, center, axis_a, axis_b, major, minor, seg, tube, material, a0=0.0, a1=tau):
        center, axis_a, axis_b = Vector(center), Vector(axis_a).normalized(), Vector(axis_b).normalized()
        closed = abs(a1 - a0) >= tau - 1e-5
        count = seg if closed else seg + 1
        normal = axis_a.cross(axis_b)
        rows = []
        for j in range(count):
            a = a0 + (a1 - a0) * j / seg
            out = axis_a * cos(a) + axis_b * sin(a)
            rows.append([self.bm.verts.new(center + out * (major + cos(k * tau / tube) * minor) + normal * sin(k * tau / tube) * minor) for k in range(tube)])
        faces = []
        for j in range(seg):
            lo, hi = rows[j], rows[(j + 1) % count]
            for k in range(tube):
                faces.append(self.bm.faces.new((lo[k], lo[(k + 1) % tube], hi[(k + 1) % tube], hi[k])))
        self.paint(faces, material, True, True)
        return faces

    def stud(self, center, radius, material, subdivisions=2, squash=1.0, normal=None):
        matrix = Matrix.Translation(center)
        if normal:
            matrix = matrix @ Vector((0, 0, 1)).rotation_difference(Vector(normal).normalized()).to_matrix().to_4x4()
        matrix = matrix @ Matrix.Diagonal((1, 1, squash, 1))
        verts = bmesh.ops.create_icosphere(self.bm, subdivisions=subdivisions, radius=radius, matrix=matrix)["verts"]
        faces = list({f for v in verts for f in v.link_faces})
        self.paint(faces, material, False, True)
        return faces

    def lump(self, center, radii, subdivisions, material, amount, scale, floor=None):
        matrix = Matrix.Translation(center) @ Matrix.Diagonal((*radii, 1))
        verts = bmesh.ops.create_icosphere(self.bm, subdivisions=subdivisions, radius=1, matrix=matrix)["verts"]
        c = Vector(center)
        seed = Vector((self.rng.uniform(0, 90), self.rng.uniform(0, 90), self.rng.uniform(0, 90)))
        from mathutils import noise as mnoise
        for v in verts:
            d = (v.co - c)
            n = d.normalized()
            low = mnoise.fractal(d * scale + seed, 1.0, 2.0, 4)
            high = mnoise.fractal(d * scale * 3.5 + seed, 1.0, 2.0, 3)
            v.co += n * (low * amount + high * amount * 0.28)
            if floor is not None and v.co.z < floor:
                v.co.z = floor
        faces = list({f for v in verts for f in v.link_faces})
        self.paint(faces, material, False, True)
        return faces

    def finish(self):
        bm = self.bm
        bm.normal_update()
        free = [f for f in bm.faces if not f[self.fixed_layer]]
        bmesh.ops.recalc_face_normals(bm, faces=free)
        for f in bm.faces:
            f.normal_update()
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0) > radians(42):
                e.smooth = False
        detail = bm.loops.layers.uv.new("Detail")
        for f in bm.faces:
            if f[self.cyl_layer]:
                ref = None
                for loop in f.loops:
                    co = loop.vert.co
                    u = atan2(co.y, co.x)
                    if ref is None:
                        ref = u
                    while u - ref > pi:
                        u -= tau
                    while ref - u > pi:
                        u += tau
                    loop[detail].uv = (u * 3.6, co.z)
            else:
                n = f.normal
                a = (abs(n.x), abs(n.y), abs(n.z))
                for loop in f.loops:
                    co = loop.vert.co
                    if a[2] >= a[0] and a[2] >= a[1]:
                        loop[detail].uv = (co.x, co.y)
                    elif a[0] >= a[1]:
                        loop[detail].uv = (co.y, co.z)
                    else:
                        loop[detail].uv = (co.x, co.z)
        mesh = bpy.data.meshes.new(self.name)
        bm.to_mesh(mesh)
        bm.free()
        for m in self.materials:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(self.name + "__Foundry", mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def hash_name(name):
    return int(hashlib.md5(name.encode()).hexdigest()[:8], 16)


def smooth_profile(points, steps=3):
    """Catmull-Rom through (r, z) points; keeps a hard corner at points marked with a third value."""
    out = []
    n = len(points)
    for i in range(n - 1):
        p0, p1, p2, p3 = points[max(i - 1, 0)], points[i], points[i + 1], points[min(i + 2, n - 1)]
        hard = len(p1) > 2 or len(p2) > 2
        for s in range(1 if hard else steps):
            t = s / (1 if hard else steps)
            r = 0.5 * (2 * p1[0] + (p2[0] - p0[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t * t + (3 * p1[0] - p0[0] - 3 * p2[0] + p3[0]) * t ** 3)
            z = 0.5 * (2 * p1[1] + (p2[1] - p0[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t * t + (3 * p1[1] - p0[1] - 3 * p2[1] + p3[1]) * t ** 3)
            out.append((max(r, 0), z))
    out.append(tuple(points[-1][:2]))
    return out


# --- Pieces ------------------------------------------------------------------------------------------------------
BELL_OUTER = [(3.02, 0.03, 1), (3.3, 0.03, 1), (3.44, 0.24), (3.47, 0.62), (3.34, 0.92, 1), (3.17, 1.0, 1), (3.15, 1.2, 1), (3.27, 1.24, 1), (3.27, 1.5, 1), (3.1, 1.55, 1),
              (2.95, 2.1), (2.8, 2.8), (2.72, 3.2, 1), (2.82, 3.24, 1), (2.82, 3.46, 1), (2.68, 3.5, 1), (2.65, 3.68, 1), (2.8, 3.72, 1), (2.8, 3.95, 1), (2.62, 4.0, 1),
              (2.5, 4.9), (2.4, 5.8, 1), (2.52, 5.84, 1), (2.52, 6.06, 1), (2.32, 6.1, 1), (2.14, 6.5), (1.72, 6.86), (1.05, 7.06), (0.72, 7.12, 1), (0.72, 7.26, 1), (0.9, 7.3, 1), (0.9, 7.46, 1), (0, 7.5, 1)]
BELL_INNER = [(0, 5.7, 1), (1.45, 5.55), (2.1, 4.3), (2.4, 2.4), (2.78, 0.4), (3.02, 0.03, 1)]


def bell_radius(z):
    pts = [(p[0], p[1]) for p in BELL_OUTER]
    for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
        if z0 <= z <= z1 and z1 > z0:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return 2.5


def build_bell():
    b = Builder("Foundry_Bell", [bronze(), iron(), timber("X")])
    b.lathe(smooth_profile(BELL_INNER, 3)[:-1] + smooth_profile(BELL_OUTER, 4), 72, "Bronze")
    # Four vertical straps, one raised ribbon each, divide the shoulder and the waist into panels.
    for k in range(4):
        a = k * tau / 4 + pi / 4
        c, s = cos(a), sin(a)
        for z0, z1 in ((1.55, 3.2), (4.0, 5.8)):
            rows = 7
            for edge in (-0.2, -0.13, 0.13, 0.2):
                pass
            def at(z, side, lift):
                r = bell_radius(z) + lift
                t = a + side / max(r, 1)
                return (cos(t) * r, sin(t) * r, z)
            for i in range(rows):
                za, zb = z0 + (z1 - z0) * i / rows, z0 + (z1 - z0) * (i + 1) / rows
                for (s0, l0), (s1, l1) in (((-0.22, -0.02), (-0.15, 0.08)), ((-0.15, 0.08), (0.15, 0.08)), ((0.15, 0.08), (0.22, -0.02))):
                    b.quad([at(za, s0, l0), at(za, s1, l1), at(zb, s1, l1), at(zb, s0, l0)], "Bronze", (c, s, 0))
    # Rows of cast bosses in the upper panels, four rows by five in each.
    for k in range(4):
        base = k * tau / 4
        for row in range(3):
            z = 4.42 + row * 0.5
            r = bell_radius(z)
            for col in range(5):
                a = base + (col - 2) * radians(13.5)
                p = Vector((cos(a) * r, sin(a) * r, z))
                b.stud(p, 0.15, "Bronze", 2, 1.0, (cos(a), sin(a), 0))
    # Striking bosses front and back: a lotus rosette in raised relief.
    for a in (-pi / 2, pi / 2):
        r = bell_radius(2.35)
        n = Vector((cos(a), sin(a), 0))
        side = Vector((0, 0, 1)).cross(n).normalized()
        c = Vector((n.x * r, n.y * r, 2.35))
        b.torus(c + n * 0.08, side, (0, 0, 1), 0.62, 0.09, 28, 6, "Bronze")
        b.stud(c + n * 0.06, 0.34, "Bronze", 2, 0.75, n)
        for i in range(12):
            t = i * tau / 12
            petal = c + (side * cos(t) + Vector((0, 0, 1)) * sin(t)) * 0.92 + n * 0.02
            b.stud(petal, 0.17, "Bronze", 2, 0.55, n)
    # Crown: two crossed cast loops, then the iron yoke it hangs from.
    b.torus((0, 0, 8.05), (1, 0, 0), (0, 0, 1), 0.62, 0.17, 26, 8, "Bronze")
    b.torus((0, 0, 8.05), (0, 1, 0), (0, 0, 1), 0.5, 0.15, 26, 8, "Bronze")
    b.stud((0, 0, 8.72), 0.28, "Bronze", 2, 1.2)
    b.box((0, 0, 8.68), (1.5, 0.26, 0.2), "Iron", 0.03)
    b.cylinder((0, 0, 8.72), (0, 0, 9.7), 0.13, 8, "Iron")
    return b.finish()


def build_kiln():
    mouth = (0, -5.2, 2.6)
    b = Builder("Foundry_KilnStack", [brick(mouth), stone(), iron()])
    half0, half1, top = 5.9, 5.45, 14.2
    z0 = 1.3
    # Stone plinth, in courses.
    b.box((0, 0, 0.45), (13.4, 13.4, 0.9), "Stone", 0.12)
    b.box((0, 0, 1.1), (12.5, 12.5, 0.5), "Stone", 0.08)
    # Battered brick body: back and sides; the front carries the arch.
    corners = lambda h: [(-h, -h), (h, -h), (h, h), (-h, h)]
    low, high = corners(half0), corners(half1)
    for i in (1, 2, 3):
        a, c = low[i], low[(i + 1) % 4]
        d, e = high[i], high[(i + 1) % 4]
        b.quad([(a[0], a[1], z0), (c[0], c[1], z0), (e[0], e[1], top), (d[0], d[1], top)], "Brick", lambda m: (m.x, m.y, 0))
    # Front wall fanned around a semicircular mouth.
    width, spring = 2.5, 2.9
    front = lambda x, z: (x, -(half0 + (half1 - half0) * (z - z0) / (top - z0)), z)
    arch = [(cos(pi - i * pi / 18) * width, z0 + spring + sin(i * pi / 18) * width) for i in range(19)]

    def rim(x, z):
        dx, dz = x, z - (z0 + spring)
        scale = min(half0 / max(abs(dx), 1e-6), (top - z0 - spring) / max(dz, 1e-6))
        return dx * scale, z0 + spring + dz * scale

    for (ax, az), (bx, bz) in zip(arch, arch[1:]):
        ox, oz = rim(ax, az)
        px, pz = rim(bx, bz)
        b.quad([front(ax, az), front(bx, bz), front(max(min(px, half1 if pz > 8 else half0), -half0), pz), front(max(min(ox, half1 if oz > 8 else half0), -half0), oz)], "Brick", (0, -1, 0))
    for side in (-1, 1):
        b.quad([front(side * width, z0), front(side * half0, z0), front(side * half0, z0 + spring), front(side * width, z0 + spring)], "Brick", (0, -1, 0))
    # The throat: a soot-black tunnel to a firebed.
    depth = 2.6
    for (ax, az), (bx, bz) in zip(arch, arch[1:]):
        fa, fb = Vector(front(ax, az)), Vector(front(bx, bz))
        b.quad([fa, fb, fb + Vector((0, depth, 0)), fa + Vector((0, depth, 0))], "Brick", lambda m: (-m.x, 0, z0 + spring - m.z))
    for side in (-1, 1):
        fa, fb = Vector(front(side * width, z0)), Vector(front(side * width, z0 + spring))
        b.quad([fa, fb, fb + Vector((0, depth, 0)), fa + Vector((0, depth, 0))], "Brick", (-side, 0, 0))
    y_back = front(0, z0)[1] + depth
    b.box((0, y_back - 1.25, z0 + 0.1), (2 * width + 0.4, 2.7, 0.3), "Iron", 0)
    back = [(-width, y_back, z0)] + [(x, y_back, z) for x, z in arch] + [(width, y_back, z0)]
    b.quad(back, "Brick", (0, -1, 0))
    # Dressed stone voussoirs around the arch and a keystone.
    count = 13
    for i in range(count):
        a = pi - (i + 0.5) * pi / count
        r = width + 0.55
        x, z = cos(a) * r, z0 + spring + sin(a) * r
        y = front(x, z)[1] - 0.14
        tall = i == count // 2
        b.box((x, y, z), (0.98 if not tall else 1.1, 0.5 if not tall else 0.72, (1.2 if not tall else 1.55)), "Stone", 0.07, (0, -(a - pi / 2) * -1, 0))
    for side in (-1, 1):
        for k in range(3):
            b.box((side * (width + 0.5 + (0.12 if k % 2 else 0)), front(side * width, z0 + 0.55 + k)[1] - 0.14, z0 + 0.5 + k * 0.95), (1.15 + (0.3 if k % 2 else 0), 0.5, 0.9), "Stone", 0.07)
    # Corner piers, stepping in as they rise, capped with a corbel course.
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z, h, inset in ((z0 + 3.0, 6.0, 0.0), (z0 + 8.6, 5.2, 0.3)):
                b.box((sx * (half0 - inset - 0.15), sy * (half0 - inset - 0.15), z), (1.5, 1.5, h), "Brick", 0.05)
    b.box((0, 0, top + 0.28), (12.2, 12.2, 0.55), "Stone", 0.1)
    b.box((0, 0, top + 0.8), (11, 11, 0.5), "Brick", 0.05)
    # Sloped shoulders running up into the round flue.
    base = [(5.3, top + 1.05, 1), (4.0, top + 2.6, 1)]
    b.lathe([(0, top + 1.04, 1)] + base + [(3.7, top + 3.0, 1), (3.5, top + 7, 1), (3.2, top + 11.2, 1), (3.5, top + 11.5, 1), (3.62, top + 12.4, 1), (3.2, top + 12.7, 1), (2.5, top + 12.72, 1), (2.45, top + 11.2, 1), (0, top + 11.1, 1)], 40, "Brick")
    # Iron hoops hold the flue together.
    for z in (top + 3.4, top + 5.9, top + 8.4, top + 10.7):
        r = 3.7 - (z - top - 3) * 0.052 + 0.03
        b.lathe([(r - 0.02, z - 0.16, 1), (r + 0.09, z - 0.13, 1), (r + 0.09, z + 0.13, 1), (r - 0.02, z + 0.16, 1)], 40, "Iron", close=True, facing="out")
        for k in range(6):
            a = k * tau / 6 + 0.26
            b.stud((cos(a) * (r + 0.09), sin(a) * (r + 0.09), z), 0.1, "Iron", 1)
    # Tie rods and plate washers across the battered body, because it has cracked before.
    for z in (6.1, 10.8):
        h = half0 + (half1 - half0) * (z - z0) / (top - z0) + 0.1
        for side in (-1, 1):
            b.box((side * h, 0, z), (0.12, 2 * half1, 0.16), "Iron", 0.02)
            for y in (-2.6, 2.6):
                b.box((side * h, y, z), (0.2, 1.1, 1.1), "Iron", 0.05)
                b.stud((side * (h + 0.1), y, z), 0.17, "Iron", 1)
        b.box((0, h, z), (2 * half1, 0.12, 0.16), "Iron", 0.02)
    # An iron door hung ajar on the mouth's east side.
    hinge = Vector((width + 0.2, front(width, z0 + 1)[1] - 0.45, z0))
    a = radians(-58)
    leaf_w, leaf_h = 2.3, 3.7
    centre = hinge + Vector((cos(a) * leaf_w / 2, sin(a) * leaf_w / 2, leaf_h / 2 + 0.2))
    b.box(centre, (leaf_w, 0.16, leaf_h), "Iron", 0.03, (0, 0, a))
    for s in (0.9, 2.1, 3.3):
        strap = hinge + Vector((cos(a) * leaf_w * 0.48, sin(a) * leaf_w * 0.48, s + 0.2))
        b.box(strap - Vector((sin(a), -cos(a), 0)) * 0.1, (leaf_w * 0.96, 0.08, 0.22), "Iron", 0.02, (0, 0, a))
    for s in (1.0, 3.0):
        b.cylinder(hinge + Vector((0, 0, s - 0.3)), hinge + Vector((0, 0, s + 0.3)), 0.11, 8, "Iron")
    return b.finish()


def build_crucible():
    b = Builder("Foundry_Crucible", [iron(), stone(), molten(), slag(), clay()])
    # A ring of dressed fire-stones with draught gaps.
    for k in range(16):
        a = k * tau / 16
        if k % 8 == 0:
            continue
        for level, (rad, h, z) in enumerate(((3.95, 0.8, 0.4), (3.7, 0.7, 1.15))):
            t = a + (level * 0.2)
            b.box((cos(t) * rad, sin(t) * rad, z), (1.42, 1.06, h), "Stone", 0.09, (0, 0, t))
    b.lump((0, 0, 0.2), (3.4, 3.4, 0.55), 3, "Slag", 0.3, 0.9, 0)
    # Iron saddle under the pot.
    for k in range(4):
        a = k * tau / 4 + pi / 4
        b.torus((cos(a) * 2.2, sin(a) * 2.2, 1.9), (cos(a), sin(a), 0), (0, 0, 1), 1.15, 0.17, 12, 6, "Iron", radians(150), radians(290))
    b.lathe([(2.05, 0.95, 1), (2.45, 1.0, 1), (2.45, 1.26, 1), (2.05, 1.3, 1)], 32, "Iron", facing="out")
    # The pot: heavy-walled cast iron, thick rim, poured surface crusted over.
    pot = smooth_profile([(0, 1.25, 1), (1.3, 1.3), (2.45, 1.9), (3.25, 3.0), (3.42, 4.0), (3.2, 5.0), (3.06, 5.42, 1), (3.42, 5.5, 1), (3.5, 5.72, 1), (3.42, 6.0, 1), (2.9, 6.05, 1), (2.76, 5.62, 1), (2.74, 5.4, 1), (0, 5.4, 1)], 4)
    b.lathe(pot, 72, "Iron")
    b.lathe([(0, 5.44, 1), (2.76, 5.44, 1)], 48, "Molten", center=(0, 0, 0), facing=(0, 0, 1))
    b.lump((0.6, 0.4, 5.5), (1.7, 1.2, 0.14), 3, "Slag", 0.12, 1.3)
    # Reinforcing bands and rivets.
    for z, r in ((2.95, 3.27), (4.45, 3.4)):
        b.lathe([(r - 0.02, z - 0.2, 1), (r + 0.1, z - 0.17, 1), (r + 0.1, z + 0.17, 1), (r - 0.02, z + 0.2, 1)], 72, "Iron", facing="out")
        for k in range(18):
            a = k * tau / 18
            b.stud((cos(a) * (r + 0.1), sin(a) * (r + 0.1), z), 0.09, "Iron", 1)
    # Pouring lip, with a frozen run of metal below it.
    a = radians(-90)
    for i, (r, w, z) in enumerate(((3.45, 1.7, 5.82), (3.95, 1.3, 5.72), (4.35, 0.95, 5.6))):
        b.box((0, -r, z), (w, 0.72, 0.34), "Iron", 0.08, (radians(-10), 0, 0))
    b.box((0, -3.7, 5.97), (0.8, 1.4, 0.05), "Molten", 0.01, (radians(-10), 0, 0))
    run = [(0, -4.5, 5.25, 0.26), (0.07, -4.6, 4.5, 0.2), (0.02, -4.52, 3.75, 0.17), (-0.05, -4.3, 3.1, 0.14)]
    for x, y, z, r in run:
        b.lump((x, y, z), (r, r, r * 2.4), 2, "Slag", 0.05, 2.5)
    # Trunnions and the bail that would lift it.
    for side in (-1, 1):
        b.cylinder((side * 3.3, 0, 4.45), (side * 4.35, 0, 4.45), 0.34, 16, "Iron")
        b.cylinder((side * 4.35, 0, 4.45), (side * 4.62, 0, 4.45), 0.5, 16, "Iron")
        b.box((side * 4.5, 0, 2.75), (0.46, 0.7, 3.0), "Iron", 0.08)
        b.box((side * 4.5, 0, 0.75), (1.1, 1.4, 1.5), "Stone", 0.1)
    return b.finish()


def build_slag():
    b = Builder("Foundry_SlagHeap", [slag(), iron(), clay()])
    b.lump((0, 0, 0.1), (6.9, 4.1, 3.3), 4, "Slag", 0.85, 0.36, 0)
    b.lump((-3.1, 0.7, 0.2), (3.6, 2.8, 3.3), 3, "Slag", 0.55, 0.62, 0)
    b.lump((3.3, -0.7, 0.1), (3.2, 2.4, 2.0), 3, "Slag", 0.45, 0.8, 0)
    rng = random.Random(9)
    for i in range(22):
        a, r = rng.uniform(0, tau), rng.uniform(0.82, 1.15)
        s = rng.uniform(0.2, 0.55)
        b.lump((cos(a) * 7 * r, sin(a) * 4.2 * r, 0.05), (s * 1.3, s, s * 0.6), 1, "Slag", 0.12, 2.0, 0)
    # Broken mould sherds and a bent crucible hoop poking from the pile.
    for x, y, z, sx, sy, sz, rx, ry in ((-1.4, -3.5, 1.05, 1.5, 0.3, 1.0, 0.5, 0.3), (2.4, 2.8, 0.9, 1.2, 0.26, 0.9, -0.5, 0.7), (4.9, -2.2, 0.55, 0.9, 0.22, 0.7, 0.3, -0.4)):
        b.box((x, y, z), (sx, sy, sz), "Clay", 0.05, (rx, ry, x))
    b.torus((1.0, 1.5, 2.3), (1, 0.2, 0), (0.1, 0.3, 1), 1.5, 0.09, 22, 6, "Iron", radians(20), radians(240))
    return b.finish()


def build_mould():
    b = Builder("Foundry_BellMould", [clay(), iron(), timber("X"), timber("Y"), bronze()])
    scale = 0.92
    outer = [(r * scale + 0.55, z * scale) for r, z in [(3.2, 0.0), (3.3, 0.6), (3.1, 1.5), (2.85, 2.8), (2.65, 4.2), (2.45, 5.6), (2.05, 6.6), (1.3, 7.1), (0.85, 7.3)]]
    inner = [(p[0], p[1] * scale) for p in smooth_profile([(3.05, 0.0), (2.95, 1.5), (2.72, 3.2), (2.5, 4.9), (2.14, 6.3), (1.3, 6.9), (0.62, 7.05)], 2)]
    cz = 0.7
    # The clay shell, split in half and stood open with its bell-shaped cavity facing out.
    a0, a1 = radians(30), radians(198)
    b.lathe(smooth_profile([(p[0], p[1] + cz) for p in outer], 3), 34, "Clay", a0, a1, wobble=0.035, close=False, facing="out")
    b.lathe([(p[0], p[1] + cz) for p in inner], 34, "Clay", a0, a1, close=False, facing="in")
    # Close the split faces and the base with thick slabs of clay.
    for a in (a0, a1):
        c, s = cos(a), sin(a)
        out = (s, -c, 0) if a == a0 else (-s, c, 0)
        for (ri, zi), (rj, zj) in zip(inner, inner[1:]):
            o0 = min(outer, key=lambda p: abs(p[1] - zi))[0]
            o1 = min(outer, key=lambda p: abs(p[1] - zj))[0]
            b.quad([(c * ri, s * ri, zi + cz), (c * o0, s * o0, zi + cz), (c * o1, s * o1, zj + cz), (c * rj, s * rj, zj + cz)], "Clay", out)
    b.lathe([(inner[0][0], cz, 1), (outer[0][0], cz, 1)], 34, "Clay", a0, a1, close=False, facing=(0, 0, -1))
    b.lathe([(inner[-1][0], inner[-1][1] + cz, 1), (0, inner[-1][1] + cz + 0.02, 1)], 34, "Clay", a0, a1, close=False, facing=(0, 0, -1))
    b.lathe([(inner[-1][0], inner[-1][1] + cz, 1), (outer[-1][0], outer[-1][1] + cz, 1)], 34, "Clay", a0, a1, close=False, facing=(0, 0, 1))
    # Iron bands strapped around the shell.
    for z, r in ((1.2, outer[1][0]), (3.5, outer[3][0] - 0.05), (5.7, outer[5][0] - 0.1)):
        b.lathe([(r - 0.02, z - 0.16, 1), (r + 0.09, z - 0.13, 1), (r + 0.09, z + 0.13, 1), (r - 0.02, z + 0.16, 1)], 34, "Iron", a0 - 0.02, a1 + 0.02, close=False, facing="out")
    # A pale core, lifted out and left beside it, its bronze skin half chipped away.
    core = [(0, 0.35, 1), (2.15, 0.35, 1)] + smooth_profile([(2.25, 0.5), (2.1, 1.8), (1.92, 3.2), (1.72, 4.4), (1.35, 5.2), (0.7, 5.55), (0, 5.62, 1)], 3)
    b.lathe(core, 36, "Clay", center=(-1.1, -3.7, 0.3))
    # Timber skids.
    for x in (-3.0, 0.2, 3.0):
        b.box((x, -1.2, 0.34), (0.8, 11.4, 0.68), "TimberY", 0.08)
    b.box((-1.1, -6.2, 0.68), (6.4, 0.6, 0.3), "TimberX", 0.05)
    return b.finish()


def build_hallwall():
    length, height, thick = 10.5, 14.0, 2.6
    half = length / 2
    b = Builder("Foundry_HallWall", [brick(None, 19.0), stone(), timber("X"), timber("Z"), iron()])
    # Brick infill; a frame stands proud of it on both faces.
    b.box((0, 0, height / 2), (length + 0.02, thick - 0.34, height), "Brick", 0)
    # Plinth courses of dressed stone, staggered.
    for side in (-1, 1):
        y = side * (thick / 2 - 0.05)
        for k in range(5):
            x = -half + (k + 0.5) * length / 5
            b.box((x, y, 0.65), (length / 5 - 0.05, 0.52, 1.3), "Stone", 0.08)
        for k in range(6):
            x = -half + k * length / 5
            w = length / 5 if 0 < k < 5 else length / 10
            b.box((x + (length / 20 if k == 0 else -length / 20 if k == 5 else 0), y - side * 0.05, 1.68), (w - 0.05, 0.44, 0.72), "Stone", 0.07)
        # Posts at the bay ends, a mid rail and a heavy wall plate.
        for x in (-half + 0.45, half - 0.45):
            b.box((x, y, 8.2), (0.9, 0.46, 11.6), "TimberZ", 0.06)
        b.box((0, y, 7.6), (length - 1.6, 0.36, 0.5), "TimberX", 0.05)
        b.box((0, y, height - 0.55), (length + 0.02, 0.56, 1.1), "TimberX", 0.07)
        # Diagonal braces under the plate.
        for s in (-1, 1):
            b.box((s * (half - 2.0), y + side * 0.02, 11.2), (0.36, 0.3, 4.3), "TimberZ", 0.04, (0, s * radians(45) * -1, 0))
        # Iron straps at the post heads.
        for x in (-half + 0.45, half - 0.45):
            b.box((x, y + side * 0.26, 7.6), (1.0, 0.05, 0.62), "Iron", 0.01)
            b.stud((x - 0.27, y + side * 0.28, 7.6), 0.07, "Iron", 1)
            b.stud((x + 0.27, y + side * 0.28, 7.6), 0.07, "Iron", 1)
    return b.finish()


PIECES = {"Foundry_Bell": build_bell, "Foundry_KilnStack": build_kiln, "Foundry_Crucible": build_crucible,
          "Foundry_SlagHeap": build_slag, "Foundry_BellMould": build_mould, "Foundry_HallWall": build_hallwall}


# --- Scene, baking, export ---------------------------------------------------------------------------------------
def fresh():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights, bpy.data.worlds):
        for item in list(coll):
            coll.remove(item)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for device in prefs.devices:
            device.use = True
        scene.cycles.device = "GPU"
    except (TypeError, ValueError):
        scene.cycles.device = "CPU"
    return scene


def preview(obj, out):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Dusk")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.75, 0.62, 0.55, 1)
    bg.inputs[1].default_value = 0.42
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 2.2
    sun.data.color = (1, 0.82, 0.68)
    sun.rotation_euler = (radians(55), 0, radians(-35))
    scene.collection.objects.link(sun)
    ground = bpy.data.meshes.new("G")
    ground.from_pydata([(-60, -60, -0.01), (60, -60, -0.01), (60, 60, -0.01), (-60, 60, -0.01)], [], [(0, 1, 2, 3)])
    gobj = bpy.data.objects.new("G", ground)
    scene.collection.objects.link(gobj)
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.cycles.samples = 40
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    centre = sum(corners, Vector()) / 8
    radius = max((c - centre).length for c in corners)
    for label, (a, e) in {"front": (-20, 12), "side": (-115, 25)}.items():
        direction = Vector((sin(radians(a)), -cos(radians(a)), sin(radians(e))))
        cam.location = centre + direction.normalized() * radius * 2.55
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out / f"{obj.data.name}_{label}.png")
        bpy.ops.render.render(write_still=True)


def unwrap(obj):
    mesh = obj.data
    atlas = mesh.uv_layers.new(name="AtlasUV")
    mesh.uv_layers.active = atlas
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=radians(52), island_margin=0.004, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return atlas


def bake(obj, out):
    scene = bpy.context.scene
    scene.cycles.samples = 12
    scene.cycles.use_denoising = False
    scene.render.bake.margin = 16
    scene.render.bake.use_clear = True
    scene.render.bake.use_pass_direct = scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    mesh = obj.data
    unwrap(obj)
    wrappers = NODE_REGISTRY[mesh.name]
    maps = {}
    for kind, socket in (("Color", "color"), ("Roughness", "rough"), ("Metalness", "metal"), ("Normal", None)):
        image = bpy.data.images.new(f"{mesh.name}_{kind}", MAP_SIZE, MAP_SIZE, alpha=False)
        if kind != "Color":
            image.colorspace_settings.name = "Non-Color"
        for w in wrappers:
            node = w.tree.nodes.new("ShaderNodeTexImage")
            node.image = image
            node.select = True
            w.tree.nodes.active = node
            if socket:
                value = getattr(w, socket)
                if hasattr(value, "links") or hasattr(value, "is_linked"):
                    w.link(value, w.emit.inputs["Color"])
                else:
                    v = value if isinstance(value, tuple) else (value, value, value)
                    w.emit.inputs["Color"].default_value = (*v, 1)
                w.link(w.emit.outputs[0], w.out.inputs["Surface"])
            else:
                w.link(w.bsdf.outputs[0], w.out.inputs["Surface"])
        bpy.ops.object.bake(type="EMIT" if socket else "NORMAL", normal_space="TANGENT", uv_layer="AtlasUV")
        image.filepath_raw = str(out / f"{mesh.name}_{kind}.png")
        image.file_format = "PNG"
        image.save()
        maps[kind] = image
    final = bpy.data.materials.new(mesh.name + "_PBR")
    final.use_nodes = True
    tree = final.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    for kind, image in maps.items():
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        if kind == "Normal":
            nm = tree.nodes.new("ShaderNodeNormalMap")
            tree.links.new(node.outputs["Color"], nm.inputs["Color"])
            tree.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            tree.links.new(node.outputs["Color"], bsdf.inputs[{"Color": "Base Color", "Roughness": "Roughness", "Metalness": "Metallic"}[kind]])
    mesh.uv_layers.remove(mesh.uv_layers["Detail"])
    mesh.materials.clear()
    mesh.materials.append(final)
    for poly in mesh.polygons:
        poly.material_index = 0
    mesh.calc_loop_triangles()
    triangles = len(mesh.loop_triangles)
    assert triangles < 20000, (mesh.name, triangles)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    path = out / f"{mesh.name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True, export_apply=True, export_tangents=True)
    size = path.stat().st_size
    assert size < 20_000_000, (mesh.name, size)
    return {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": size, "triangles": triangles,
            "dimensions": [round(d, 3) for d in obj.dimensions], "maps": MAP_SIZE, "uvSets": len(mesh.uv_layers)}


NODE_REGISTRY = {}
_finish = Nodes.finish


def tracked_finish(self, *args, **kwargs):
    material = _finish(self, *args, **kwargs)
    CURRENT.append(self)
    return material


Nodes.finish = tracked_finish
CURRENT = []


def main():
    arguments = sys.argv[sys.argv.index("--") + 1:]
    mode, out = arguments[0], Path(arguments[1]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    wanted = arguments[2:] or list(PIECES)
    report = {}
    for name in wanted:
        fresh()
        CURRENT.clear()
        obj = PIECES[name]()
        NODE_REGISTRY[obj.data.name] = list(CURRENT)
        obj.data.calc_loop_triangles()
        print("PIECE", name, "tris", len(obj.data.loop_triangles), "dims", [round(d, 2) for d in obj.dimensions], "origin-bounds z", round(min((obj.matrix_world @ Vector(c)).z for c in obj.bound_box), 3), flush=True)
        if mode == "preview":
            preview(obj, out)
        else:
            report[name] = bake(obj, out)
            print("BAKED", json.dumps(report[name]), flush=True)
    if mode == "bake":
        path = out / "manifest.json"
        existing = json.loads(path.read_text()) if path.exists() else {}
        existing.update(report)
        path.write_text(json.dumps(existing, indent=2) + "\n")


if __name__ == "__main__":
    main()

"""Build the Bellwood Jian, its packed 2K material, and the review cameras in Blender."""
import json
import math
import os
import struct
import zlib
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(os.environ.get("ASURA_JIAN_SOURCE", ROOT / "assets/source/weapons/jian"))
REVIEW = Path(os.environ.get("ASURA_JIAN_REVIEW", ROOT / "outputs/jian-art-2026-11-27"))
SIDE = 2048
ORIGIN = (0, 0, 0)
TIP = (0, 2.10, 0)
GRIP = (0, -1.70, 0)
TILES = {
    "Steel": (0, 0, 2048, 512), "Edge": (0, 512, 2048, 512),
    "Bronze": (0, 1024, 1024, 512), "Patina": (1024, 1024, 1024, 512),
    "Wrap": (0, 1536, 512, 512), "Jade": (512, 1536, 512, 512),
    "Silk": (1024, 1536, 512, 512), "Inlay": (1536, 1536, 512, 512),
}
FINISHES = {
    "Steel": ((139, 154, 159), 0.91, 0.365), "Edge": ((212, 221, 219), 0.93, 0.205),
    "Bronze": ((158, 117, 66), 0.79, 0.38), "Patina": ((54, 50, 35), 0.67, 0.47),
    "Wrap": ((47, 36, 31), 0.0, 0.78), "Jade": ((67, 135, 111), 0.0, 0.29),
    "Silk": ((104, 44, 35), 0.0, 0.54), "Inlay": ((206, 163, 91), 0.81, 0.29),
}


def png(path, pixels):
    height, width, _ = pixels.shape

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    rows = b"".join(b"\x00" + row.tobytes() for row in pixels)
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows, 6)) + chunk(b"IEND", b""))


def atlas(directory):
    colors, orm, normals = (np.zeros((SIDE, SIDE, 3), dtype=np.uint8) for _ in range(3))
    rng = np.random.default_rng(6270)
    for name, (x, y, w, h) in TILES.items():
        base, metal, rough = FINISHES[name]
        u, v = np.meshgrid(np.linspace(0, 1, w), np.linspace(0, 1, h))
        grain = rng.normal(0, 1, (h, w))
        field = 0.5 * np.sin(40 * u + 9 * v) + 0.28 * np.cos(83 * v - 11 * u) + 0.18 * np.sin(112 * u + 30 * v)
        if name in {"Steel", "Edge"}:
            shear = 0.12 * np.sin(403 * v + 0.8 * np.sin(19 * u)) + 0.065 * np.sin(1061 * v + 2.1 * u)
            field = 0.19 * field + shear
            grain *= 0.34
        elif name == "Jade":
            vein = np.sin(17 * v + 1.7 * np.sin(9 * u) + 12 * u)
            field = 0.45 * field + np.maximum(0, vein) ** 12
            grain *= 0.3
        elif name in {"Wrap", "Silk"}:
            weave = np.sin(510 * u + 45 * v) * np.sin(382 * v - 38 * u)
            field = 0.62 * field + 0.5 * weave
        field = field + grain * 0.22
        tile = np.s_[y:y + h, x:x + w]
        colors[tile] = np.clip(np.array(base)[None, None, :] + field[:, :, None] * (10 if name != "Jade" else 25), 0, 255)
        orm[tile] = np.stack([np.full_like(field, 255), np.clip(255 * rough + 10 * field, 0, 255), np.full_like(field, metal * 255)], axis=-1)
        dy, dx = np.gradient(field)
        amplitude = 0.07 if name in {"Steel", "Edge"} else 0.16
        normal = np.stack([-dx * amplitude, dy * amplitude, np.ones_like(field)], axis=-1)
        normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
        normals[tile] = np.rint(np.clip(normal * 0.5 + 0.5, 0, 1) * 255)
    for name, data in (("Color", colors), ("MetalRough", orm), ("Normal", normals)):
        png(directory / f"Jian_{name}.png", data)


def material(directory):
    mat = bpy.data.materials.new("Jian_Forged_Atlas")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    coords = nodes.new("ShaderNodeUVMap")
    coords.uv_map = "FinishAtlas"
    for name in ("Color", "MetalRough", "Normal"):
        tex = nodes.new("ShaderNodeTexImage")
        tex.label = name
        tex.image = bpy.data.images.load(str(directory / f"Jian_{name}.png"))
        tex.image.colorspace_settings.name = "sRGB" if name == "Color" else "Non-Color"
        tex.image.pack()
        links.new(coords.outputs["UV"], tex.inputs["Vector"])
        if name == "Color":
            links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        elif name == "Normal":
            normal = nodes.new("ShaderNodeNormalMap")
            normal.uv_map = "FinishAtlas"
            normal.inputs["Strength"].default_value = 0.68
            links.new(tex.outputs["Color"], normal.inputs["Color"])
            links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            split = nodes.new("ShaderNodeSeparateColor")
            links.new(tex.outputs["Color"], split.inputs["Color"])
            links.new(split.outputs["Green"], bsdf.inputs["Roughness"])
            links.new(split.outputs["Blue"], bsdf.inputs["Metallic"])
    return mat


def texture_uv(tile, u, v):
    x, y, w, h = TILES[tile]
    inset = 18
    return ((x + inset + u * (w - 2 * inset)) / SIDE, 1 - (y + inset + v * (h - 2 * inset)) / SIDE)


class Part:
    def __init__(self, name):
        self.name = name
        self.vertices = []
        self.faces = []
        self.uvs = []
        self.smooth = []

    def surface(self, pts, tile, uv, smooth=False):
        self.faces.append(tuple(pts))
        self.uvs.append([texture_uv(tile, u, v) for u, v in uv])
        self.smooth.append(smooth)

    def rings(self, sections, tile, smooth=True, closed=False, material_for=None):
        start = len(self.vertices)
        steps, width = len(sections), len(sections[0])
        self.vertices.extend(point for section in sections for point in section)
        for i in range(steps if closed else steps - 1):
            a, b = start + i * width, start + ((i + 1) % steps) * width
            u0, u1 = i / (steps if closed else steps - 1), (i + 1) / (steps if closed else steps - 1)
            for j in range(width):
                k = (j + 1) % width
                uv = [(u0, j / width), (u1, j / width), (u1, (j + 1) / width), (u0, (j + 1) / width)]
                self.surface((a + j, b + j, b + k, a + k), material_for(j) if material_for else tile, uv, smooth)
        if not closed:
            uv = [(0.5 + 0.49 * math.cos(j * math.tau / width), 0.5 + 0.49 * math.sin(j * math.tau / width)) for j in range(width)]
            self.surface(range(start, start + width), tile, uv)
            tail = start + (steps - 1) * width
            self.surface(range(tail, tail + width), tile, uv)

    def tube(self, points, radius, tile, closed=False, sides=6):
        path = [Vector(p) for p in points]
        sections = []
        for i, p in enumerate(path):
            after = path[(i + 1) % len(path)] if closed else path[min(len(path) - 1, i + 1)]
            before = path[i - 1] if closed else path[max(0, i - 1)]
            direction = (after - before).normalized()
            guide = Vector((1, 0, 0)) if abs(direction.x) < 0.9 else Vector((0, 0, 1))
            normal = direction.cross(guide).normalized()
            cross = normal.cross(direction)
            sections.append([p + radius * (normal * math.cos(a * math.tau / sides) + cross * math.sin(a * math.tau / sides)) for a in range(sides)])
        self.rings(sections, tile, closed=closed)

    def cylinder(self, profile, tile, sides=24, phase=0):
        sections = []
        for y, thickness, width in profile:
            sections.append([(thickness * math.cos(phase + a * math.tau / sides), y, width * math.sin(phase + a * math.tau / sides)) for a in range(sides)])
        self.rings(sections, tile)

    def badge(self, profile, center, tile, phase=0, sides=24):
        x, y, z = center
        sections = [[(x + a, y + ly * math.cos(phase + i * math.tau / sides), z + lz * math.sin(phase + i * math.tau / sides))
                     for i in range(sides)] for a, ly, lz in profile]
        self.rings(sections, tile)

    def object(self, mat, collection):
        mesh = bpy.data.meshes.new(f"SM_Jian_{self.name}")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        uv = mesh.uv_layers.new(name="FinishAtlas")
        for poly, coords, smooth in zip(mesh.polygons, self.uvs, self.smooth, strict=True):
            poly.use_smooth = smooth
            for loop, point in zip(poly.loop_indices, coords, strict=True):
                uv.data[loop].uv = point
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        assert all(edge.is_manifold for edge in bm.edges), self.name
        bm.to_mesh(mesh)
        bm.free()
        mesh.calc_loop_triangles()
        assert len(mesh.loop_triangles) < 18_000, self.name
        obj = bpy.data.objects.new(self.name, mesh)
        obj.data.materials.append(mat)
        collection.objects.link(obj)
        return obj


def blade():
    part = Part("Blade")
    profile = [(-1.31, .140, .054), (-1.21, .143, .055), (-.95, .140, .055), (-.41, .137, .053),
               (.32, .129, .048), (1.04, .121, .042), (1.61, .111, .035), (1.82, .095, .030),
               (1.95, .073, .023), (2.04, .042, .015), (2.088, .014, .006), (2.099, .0010, .0007)]
    facet = [(-1, .085), (-.80, .32), (-.39, .79), (0, 1), (.39, .79), (.80, .32), (1, .085)]
    shape = facet + [(z, -x) for z, x in reversed(facet)]
    sections = [[(t * x, y, w * z) for z, x in shape] for y, w, t in profile]
    part.rings(sections, "Steel", smooth=False, material_for=lambda i: "Edge" if i in {0, 5, 6, 7, 12, 13} else "Steel")
    # Small paired forge mark at the blade's shoulder, well inside the bright bevel.
    for sign in (-1, 1):
        for offset in (-.035, .035):
            part.badge([(0, .045, .017), (sign * .0025, .040, .014)], (sign * .053, -1.05 + offset, 0), "Patina", math.pi / 4, 4)
    return part


def guard():
    part = Part("Guard")
    half = [(-1.465, 0), (-1.463, .074), (-1.450, .130), (-1.419, .173), (-1.420, .225),
            (-1.397, .266), (-1.359, .283), (-1.327, .254), (-1.326, .206), (-1.285, .134), (-1.279, .066), (-1.274, 0)]
    outline = half + [(y, -z) for y, z in reversed(half[1:-1])]
    center = -1.37
    part.rings([[(x, center + (y - center) * scale, z * scale) for y, z in outline]
                for x, scale in [(-.106, .82), (-.117, .91), (-.095, 1), (.095, 1), (.117, .91), (.106, .82)]], "Bronze", smooth=False)
    for sign in (-1, 1):
        for scale, tile, radius in ((.83, "Patina", .007), (.74, "Inlay", .0036)):
            loop = [(sign * .116, center + (y - center) * scale, z * scale) for y, z in outline]
            part.tube(loop, radius, tile, closed=True)
        for side in (-1, 1):
            loc = (sign * .112, -1.37, side * .175)
            part.badge([(0, .036, .051), (sign * .009, .028, .045)], loc, "Patina", sides=12)
            part.badge([(sign * .008, .021, .033), (sign * .017, .016, .028), (sign * .022, .009, .017)], loc, "Jade", sides=12)
        part.badge([(0, .048, .052), (sign * .016, .039, .045)], (sign * .113, center, 0), "Patina", sides=20)
        part.badge([(sign * .014, .035, .039), (sign * .025, .028, .032)], (sign * .113, center, 0), "Inlay", sides=20)
        for spoke in range(6):
            angle = spoke * math.tau / 6
            points = [(sign * .139, center + r * math.cos(angle), r * math.sin(angle)) for r in (.011, .026)]
            part.tube(points, .0024, "Patina", sides=5)
    part.cylinder([(-1.48, .094, .101), (-1.473, .111, .118), (-1.435, .114, .122), (-1.418, .098, .111)], "Inlay")
    return part


def grip():
    part = Part("Grip")
    part.cylinder([(-2.055, .088, .095), (-2.021, .098, .105), (-1.83, .094, .103),
                   (-1.62, .095, .106), (-1.48, .108, .112), (-1.45, .100, .108)], "Wrap", 24)
    points = []
    for n in range(193):
        t = n / 192
        theta = 8.4 * math.tau * t
        x = .099 + .008 * t
        z = .105 + .006 * t
        points.append((x * math.cos(theta), -2.041 + .585 * t, z * math.sin(theta)))
    part.tube(points, .010, "Wrap", sides=7)
    part.tube([(x * .99, y - .017, z * .99) for x, y, z in points], .0045, "Patina", sides=5)
    for y in (-2.029, -1.483):
        part.cylinder([(y - .022, .101, .110), (y - .015, .113, .120), (y + .016, .113, .12), (y + .022, .102, .110)], "Bronze")
        part.cylinder([(y - .003, .114, .121), (y + .006, .114, .121)], "Silk")
    return part


def pommel():
    part = Part("Pommel")
    part.cylinder([(-2.209, .112, .104), (-2.190, .129, .131), (-2.173, .130, .150),
                   (-2.142, .113, .167), (-2.10, .109, .153), (-2.076, .108, .119), (-2.040, .094, .101)], "Bronze", 32)
    part.cylinder([(-2.199, .114, .109), (-2.189, .132, .133), (-2.178, .134, .143)], "Inlay", 32)
    for sign in (-1, 1):
        part.badge([(0, .054, .090), (sign * .012, .050, .080)], (sign * .106, -2.141, 0), "Patina", sides=20)
        part.badge([(sign * .012, .042, .068), (sign * .027, .036, .055), (sign * .034, .021, .030)], (sign * .106, -2.141, 0), "Jade", sides=20)
    return part


def camera(name, target, origin, width, roll=0, axis=(0, -1, 0)):
    data = bpy.data.cameras.new(name)
    data.type, data.ortho_scale = "ORTHO", width
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = origin
    look = (Vector(target) - obj.location).normalized()
    horizontal = Vector(axis)
    right = (horizontal - look.dot(horizontal) * look).normalized()
    up = right.cross(look).normalized()
    c, s = math.cos(roll), math.sin(roll)
    basis = Matrix((right * c + up * s, up * c - right * s, -look)).transposed()
    obj.rotation_euler = basis.to_euler()
    return obj


def panel(name, location, aim, strength, color, size, height):
    light = bpy.data.lights.new(name, "AREA")
    light.shape, light.energy, light.color, light.size, light.size_y = "RECTANGLE", strength, color, size, height
    obj = bpy.data.objects.new(name, light)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(aim) - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_review():
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new("Ink Cyclorama")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.035, 0.048, 0.043, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.36
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 95
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 0.3
    panel("LGT_Silkbox", (3.4, .8, 3.3), (0, .2, 0), 430, (0.87, .95, 1.0), 4.0, 1.1)
    panel("LGT_TungstenStrip", (2.7, -1, -.8), (0, -1.1, 0), 160, (1.0, .75, .48), 2.5, .38)
    panel("LGT_BronzeRim", (-2.4, -.65, 2.1), (0, -.8, 0), 380, (1.0, .84, .60), 3.7, .65)
    panel("LGT_Edge", (.5, 1.7, -2.8), (0, .5, 0), 250, (.61, .82, 1.0), 3.2, .8)
    panel("LGT_Bounce", (3.9, -.55, .25), (0, -.4, 0), 58, (.86, .92, 1.0), 5.1, 4.0)
    hero = camera("CAM_Hero", (0, -.055, 0), (6.2, -.32, 1.96), 4.94, -.18)
    detail = camera("CAM_Fittings", (0, -1.68, 0), (3.6, -2.26, 1.12), 1.51, -.25)
    profile = camera("CAM_Profile", (0, -.05, 0), (6.2, -.05, 0), 4.74)
    scene.camera = hero
    return scene, ((hero, "01-jian-hero.jpg", 1440, 780), (detail, "02-jian-fittings.jpg", 1320, 810), (profile, "03-jian-profile.jpg", 1440, 640))


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    maps = SOURCE / "Maps"
    maps.mkdir(exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    collection = bpy.data.collections.new("COL_Jian")
    bpy.context.scene.collection.children.link(collection)
    atlas(maps)
    mat = material(maps)
    objs = [part.object(mat, collection) for part in (blade(), guard(), grip(), pommel())]
    scene, shots = setup_review()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    root = bpy.data.objects.new("Jian", None)
    collection.objects.link(root)
    root["StockAxes"] = "glTF/Roblox: blade -Z, broad faces +/-X, cutting edges +/-Y"
    root["GripCenter"] = [0.0, 0.0, 1.70]
    for obj in objs:
        obj.parent = root
    root.select_set(True)
    scene.render.resolution_x, scene.render.resolution_y = shots[0][2:]
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "Jian.blend"))
    bpy.ops.export_scene.gltf(filepath=str(SOURCE / "Jian.glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_extras=True, export_cameras=False, export_lights=False)
    counts = {obj.name: len(obj.data.loop_triangles) for obj in objs}
    vertices = [v.co for obj in objs for v in obj.data.vertices]
    points = [(float(v.x), float(v.z), -float(v.y)) for v in vertices]
    info = {
        "unit": "stud", "stock_origin": ORIGIN, "grip_center_gltf": [0, 0, 1.70],
        "tip_nominal_gltf": [0, 0, -TIP[1]], "guard_center_gltf": [0, 0, 1.37],
        "gltf_bounds": [[min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]],
        "parts_triangles": counts, "texture_dimensions": [SIDE, SIDE], "source": "Original procedural geometry and maps",
    }
    (SOURCE / "manifest.json").write_text(json.dumps(info, indent=2), encoding="utf-8")
    if os.environ.get("ASURA_JIAN_NO_RENDER") != "1":
        for lit_camera, filename, width, height in shots:
            scene.camera = lit_camera
            scene.render.resolution_x, scene.render.resolution_y = width, height
            scene.render.filepath = str(REVIEW / filename)
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()

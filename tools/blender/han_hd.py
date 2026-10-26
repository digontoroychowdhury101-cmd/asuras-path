"""High-detail Han architecture for the campaign regions, built from the lobby kit's own vocabulary.

    blender -b --factory-startup --python-exit-code 1 -P tools/blender/han_hd.py

HanPagodaHD (five-storey pagoda) and HanGateHD (paifang) are composed from lobby_kit_pieces builders
(columns, bracket sets, architraves, balustrades, plaque) and lobby_kit_roofs.hall (curved tiled
roofs), textured with the lobby's PBR sets (lobby_textures) so they match the Shrine. Proportions
follow 0 A.D.'s han_pagoda (assets/github/0ad, CC BY-SA 3.0) as reference only; no geometry is copied.

Every Roblox MeshPart is one object <Piece>_<Section>__<Material> (single texture set); sections are
the base, each storey and the spire, and any object over CAP triangles is split by loose parts.
Outputs assets/build/han_hd/: AsuraHanHD.glb, manifest.json, contact sheet, textures/.
Blender units are studs, Z up, front faces -Y (Roblox -Z after Studio import).
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lobby_kit_pieces as K  # noqa: E402
import lobby_kit_roofs as roofs  # noqa: E402
import lobby_textures as TX  # noqa: E402
from lobby_kit import make_materials, roblox  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "build" / "han_hd"
CAP = 18000  # per MeshPart, under Roblox's ~20k import limit
SETS = {k: TX.SETS[k] for k in ("Roof", "Timber", "Lacquer", "Stone", "Bronze")}


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def S(x, y=None, z=None):
    return Matrix.Diagonal((x, y if y is not None else x, z if z is not None else x, 1))


def R(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


class Builder:
    """Collects finished, transformed bmeshes per (section, material) for one kit piece."""

    def __init__(self, name):
        self.name, self.parts = name, {}

    def stamp(self, section, fn, M=Matrix.Identity(4), **kw):
        pc = K.Piece(f"{self.name}_{section}")
        out = fn(pc, **kw) if kw else fn(pc)
        for material, mesh in pc.meshes.items():
            bm = mesh.finish()  # UVs authored/projected in the builder's own frame, then moved
            bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
            if M.determinant() < 0:
                bmesh.ops.reverse_faces(bm, faces=bm.faces)
            self.parts.setdefault((section, material), []).append(bm)
        return out

    def raw(self, section, material):
        """A fresh lobby Mesh to draw into directly (boxes, lathes) in piece space."""
        pc = K.Piece(f"{self.name}_{section}")
        mesh = pc.m(material)
        self.parts.setdefault((section, material), []).append(mesh)
        return mesh

    def objects(self, mats, collection):
        made = []
        for (section, material), items in self.parts.items():
            bm = bmesh.new()
            for it in items:
                src = it.finish() if isinstance(it, K.Mesh) else it
                me = bpy.data.meshes.new("tmp")
                src.to_mesh(me)
                bm.from_mesh(me)
                bpy.data.meshes.remove(me)
            me = bpy.data.meshes.new(f"{self.name}_{section}__{material}")
            bm.to_mesh(me)
            bm.free()
            me.shade_smooth()
            me.set_sharp_from_angle(angle=math.radians(38))
            ob = bpy.data.objects.new(me.name, me)
            ob.data.materials.append(mats[material])
            collection.objects.link(ob)
            made += split(ob, collection)
        return made


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def split(ob, collection):
    """Keeps every object under CAP triangles by regrouping its loose parts into chunks."""
    if tris(ob) <= CAP:
        return [ob]
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    islands, seen = [], set()
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, island = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        islands.append(island)
    islands.sort(key=lambda isl: sum(v.co.x for f in isl for v in f.verts) / max(1, sum(len(f.verts) for f in isl)))
    chunks, cur, count = [], [], 0
    for isl in islands:
        n = sum(len(f.verts) - 2 for f in isl)
        if cur and count + n > CAP:
            chunks.append(cur)
            cur, count = [], 0
        cur.append(isl)
        count += n
    chunks.append(cur)
    out = []
    for k, chunk in enumerate(chunks):
        keep = {f.index for isl in chunk for f in isl}
        part = bm.copy()
        part.faces.ensure_lookup_table()
        bmesh.ops.delete(part, geom=[f for f in part.faces if f.index not in keep], context="FACES")
        me = bpy.data.meshes.new(f"{ob.data.name}{k + 1}")
        part.to_mesh(me)
        part.free()
        o = bpy.data.objects.new(me.name, me)
        o.data.materials.append(ob.data.materials[0])
        collection.objects.link(o)
        out.append(o)
    bm.free()
    bpy.data.objects.remove(ob)
    return out


# -- shared details -------------------------------------------------------------------------------
def column_at(b, section, x, y, z, h, r=1.0):
    b.stamp(section, K.column, T(x, y, z) @ S(r, r, h / 10))


def lattice(m, x0, x1, z0, z1, y, M, bar=0.16, step=0.9, depth=0.18):
    """Timber lattice window in face space (front -Y), turned onto its face by M."""
    w, h = x1 - x0, z1 - z0
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    m.box((cx, y, z1), (w + 0.3, depth * 1.6, 0.3), M)
    m.box((cx, y, z0), (w + 0.3, depth * 1.6, 0.3), M)
    for x in (x0, x1):
        m.box((x, y, cz), (0.3, depth * 1.6, h), M)
    nx, nz = max(1, int(w / step)), max(1, int(h / step))
    for i in range(1, nx):
        m.box((x0 + w * i / nx, y, cz), (bar, depth, h), M)
    for j in range(1, nz):
        m.box((cx, y, z0 + h * j / nz), (w, depth, bar), M)


def bell(m, x, y, z):
    m.lathe([(0.0, -1.2), (0.42, -1.2), (0.46, -1.05), (0.34, -0.55), (0.24, -0.2), (0.08, 0.0), (0.02, 0.4)], 10, T(x, y, z))


def side_frames(w):
    """(rotation, sign) for the four faces of a square storey; face 0 is the front (-Y)."""
    return [R(0), R(90), R(180), R(270)]


# -- pagoda ---------------------------------------------------------------------------------------
def pagoda():
    b = Builder("HanPagodaHD")
    # Stone plinth with a front stair and balustrade.
    st = b.raw("Base", "Stone")
    st.box((0, 0, 1.6), (38, 38, 3.2), bevel=0.15)
    st.box((0, 0, 3.6), (34, 34, 0.8), bevel=0.1)
    for k in range(8):
        st.box((0, -19 - (8 - k) * 1.0 + 0.5, (k + 1) * 0.5 - 0.25 + 0.0), (11, 1.0, (k + 1) * 0.5), bevel=0.03)
    for frame in side_frames(34):
        for i in range(6):
            x = -14.0 + i * 5.6
            if frame == R(0) and abs(x) < 5.5:
                continue
            b.stamp("Base", K.rail_bay, frame @ T(x + 2.8 - 2.8, -16.6, 4.0) @ S(1.08, 1, 1))
        for x in (-16.6, 16.6):
            b.stamp("Base", K.rail_post, frame @ T(x, -16.6, 4.0))
    z0, w = 4.0, 20.0
    widths = [20.0, 17.0, 14.5, 12.0, 9.5]
    for k, w in enumerate(widths):
        sec = f"T{k + 1}"
        h = 12.0 if k == 0 else 9.0
        hw = w / 2
        ncol = 4 if k < 2 else 3
        xs = [-hw + w * i / (ncol - 1) for i in range(ncol)]
        lq, tb, br = b.raw(sec, "Lacquer"), b.raw(sec, "Timber"), b.raw(sec, "Bronze")
        if k > 0:  # balcony deck and railing around the storey
            d = hw + 2.2
            tb.box((0, 0, z0 - 0.3), (2 * d, 2 * d, 0.6), bevel=0.05)
            for frame in side_frames(w):
                for x in [-d + 2 * d * i / 8 for i in range(8)]:
                    lq.box((x, -d + 0.2, z0 + 0.75), (0.28, 0.28, 1.5), frame)
                for zz in (z0 + 0.6, z0 + 1.45):
                    lq.box((0, -d + 0.2, zz), (2 * d, 0.18, 0.16), frame)
        for frame in side_frames(w):
            for x in xs[:-1]:  # one corner column per face
                column_at(b, sec, *(frame @ Vector((x, -hw, z0))), h - 2.4, 1.15 if k == 0 else 0.9)
                if k == 0:
                    b.stamp(sec, K.column_base, frame @ T(x, -hw, z0) @ S(1.15))
            for i in range(ncol - 1):  # bays: lacquer wall, lattice, architrave
                xa, xb = xs[i], xs[i + 1]
                span = xb - xa
                lq.box(((xa + xb) / 2, -hw + 0.6, z0 + (h - 2.4) / 2), (span - 1.2, 0.4, h - 2.4), frame)
                door = k == 0 and frame == R(0) and i == (ncol - 1) // 2
                if door:
                    for side in (-1, 1):
                        tb.box(((xa + xb) / 2 + side * span / 4 - side * 0.3, -hw + 0.3, z0 + 3.6), (span / 2 - 1.0, 0.3, 7.0), frame)
                        for r in range(5):
                            for c in range(3):
                                br.lathe([(0.16, 0), (0.12, 0.12), (0.0, 0.16)], 6,
                                         frame @ T((xa + xb) / 2 + side * (span / 4 - 0.3) + (c - 1) * 0.9, -hw + 0.12, z0 + 1.2 + r * 1.2) @ Matrix.Rotation(math.radians(90), 4, "X"))
                else:
                    lattice(tb, xa + 1.0, xb - 1.0, z0 + h * 0.3, z0 + h - 3.2, -hw + 0.32, frame)
                b.stamp(sec, K.beam, frame @ T((xa + xb) / 2, -hw, z0 + h - 2.45) @ S(span / 8, 1, 1))
            for x in xs[:-1]:
                b.stamp(sec, K.bracket, frame @ T(x, -hw, z0 + h - 0.1) @ R(0) @ S(0.75))
            b.stamp(sec, K.bracket, frame @ T(0, -hw, z0 + h - 0.1) @ S(0.6))
        # Roof: concave pyramid; the next storey stands where the roof narrows to its balcony.
        W = w + 10
        H = 0.42 * W
        eave = z0 + h + 1.9
        top = k == len(widths) - 1
        b.stamp(sec, roofs.hall, T(0, 0, eave), W=W, D=W, H=H, tg=1.0, lift=1.8, kick=1.2, thick=(0.5, 1.0),
                ridge_scale=0.9, finial=None, nu=22, nt=(10, 0))
        corner = W / 2 + 1.2
        for sx in (-1, 1):
            for sy in (-1, 1):
                bell(b.raw(sec, "Bronze"), sx * corner * 0.97, sy * corner * 0.97, eave + 1.2)
        if top:
            spire(b, eave + H * 0.94)
        else:
            nxt = widths[k + 1] + 4.4
            t = max(0.0, 1 - nxt / W)
            z0 = eave + H * (0.3 * t + 0.7 * t * t)
    return b


def spire(b, z):
    """Bronze sorin: lotus base, nine rings, water flame and jewel."""
    m = b.raw("Spire", "Bronze")
    m.lathe([(2.2, 0), (2.4, 0.4), (1.6, 1.0), (1.2, 1.6), (1.4, 2.2), (0.9, 2.8), (0.45, 3.0)], 16, T(0, 0, z))
    m.lathe([(0.32, 0), (0.32, 14.0), (0.0, 14.2)], 10, T(0, 0, z + 3.0))
    for i in range(9):
        zz = z + 4.0 + i * 1.05
        m.lathe([(0.34, -0.12), (1.25 - i * 0.05, -0.08), (1.3 - i * 0.05, 0.0), (1.25 - i * 0.05, 0.08), (0.34, 0.12)], 16, T(0, 0, zz))
    m.lathe([(0.0, 0), (0.9, 0.5), (1.1, 1.4), (0.7, 2.4), (0.2, 3.2), (0.0, 3.4)], 12, T(0, 0, z + 13.6))
    m.lathe([(0.0, 0), (0.55, 0.35), (0.6, 0.7), (0.4, 1.1), (0.0, 1.3)], 12, T(0, 0, z + 17.0))


# -- paifang gate ---------------------------------------------------------------------------------
def gate():
    b = Builder("HanGateHD")
    xs = (-10.5, -3.6, 3.6, 10.5)
    st = b.raw("Frame", "Stone")
    for x in xs:
        h = 17.0 if abs(x) < 5 else 13.0
        column_at(b, "Frame", x, 0, 0, h, 1.2)
        st.box((x, 0, 1.6), (2.6, 3.6, 3.2), bevel=0.12)  # clamping drum stones
        st.lathe([(0.9, 3.2), (0.6, 3.9), (0.0, 4.2)], 12, T(x, -1.5, 0))
        st.lathe([(0.9, 3.2), (0.6, 3.9), (0.0, 4.2)], 12, T(x, 1.5, 0))
    for (a, c, z, h) in ((-3.6, 3.6, 17.0, 1.0), (-10.5, -3.6, 13.0, 1.0), (3.6, 10.5, 13.0, 1.0)):
        span = c - a
        b.stamp("Frame", K.beam, T((a + c) / 2, 0, z - 2.45) @ S(span / 8, 1, 1))
        b.stamp("Frame", K.beam, T((a + c) / 2, 0, z - 6.4) @ S(span / 8, 1, 1))
        for x in [a + span * i / 3 for i in range(4)]:
            b.stamp("Frame", K.bracket, T(x, 0, z) @ S(0.55))
    b.stamp("Frame", K.plaque, T(0, -0.5, 11.2) @ Matrix.Rotation(math.radians(0), 4, "Z"))
    b.stamp("Roofs", roofs.hall, T(0, 0, 18.5), W=11.0, D=6.0, H=3.6, tg=0.55, lift=1.0, kick=0.6, thick=(0.4, 0.8),
            ridge_scale=0.7, finial="Bronze", nu=16, nt=(6, 5))
    for x in (-7.05, 7.05):
        b.stamp("Roofs", roofs.hall, T(x, 0, 14.5), W=9.0, D=5.2, H=3.0, tg=0.55, lift=0.9, kick=0.5, thick=(0.4, 0.8),
                ridge_scale=0.6, finial=None, nu=14, nt=(6, 5))
    return b


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    (OUT / "textures").mkdir(parents=True, exist_ok=True)
    mats = make_materials(TX.save(str(OUT / "textures"), sets=SETS))
    kit = bpy.data.collections.new("AsuraHanHD")
    bpy.context.scene.collection.children.link(kit)
    manifest = {"units": "studs", "axes": "Roblox (x, y up, z) as imported", "cap": CAP, "pieces": {}}
    offset = 0.0
    for builder in (pagoda(), gate()):
        objs = builder.objects(mats, kit)
        pts = [v.co for o in objs for v in o.data.vertices]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        shift = Vector((offset - lo.x, 0, 0))
        for o in objs:
            o.data.transform(Matrix.Translation(shift))
        offset += hi.x - lo.x + 20
        parts = {o.name: {"triangles": tris(o), "material": o.data.materials[0].name.replace("Kit_", "")} for o in objs}
        size = hi - lo
        manifest["pieces"][builder.name] = {"origin": roblox(shift), "size": [round(size.x, 2), round(size.z, 2), round(size.y, 2)],
                                            "triangles": sum(p["triangles"] for p in parts.values()),
                                            "maxPartTriangles": max(p["triangles"] for p in parts.values()), "parts": parts}
        print("PIECE", builder.name, manifest["pieces"][builder.name]["triangles"], "tris in", len(parts), "parts; max",
              manifest["pieces"][builder.name]["maxPartTriangles"], "size", [round(v, 1) for v in size])
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
    for o in kit.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / "AsuraHanHD.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_animations=False, export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "AsuraHanHD.blend"))
    preview(kit)


def preview(kit):
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT") if e in engines)
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1000
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    sc.world = world
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value, bg.inputs[1].default_value = (0.55, 0.6, 0.68, 1), 0.9
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy, sun.rotation_euler = 4.0, (math.radians(52), 0, math.radians(-35))
    sc.collection.objects.link(sun)
    pts = [v.co for o in kit.objects for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) / 2
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    r = max(hi - lo) * 1.25
    cam.location = c + Vector((r * 0.3, -r * 1.25, r * 0.22))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 40
    sc.render.filepath = str(OUT / "contact_sheet.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()

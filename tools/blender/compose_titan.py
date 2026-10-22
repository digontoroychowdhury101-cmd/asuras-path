"""Composes the Veiled Ascetic and her sacred tree into one grounded piece, in studs (headless Blender).

Usage:
  Blender -b --python-exit-code 1 -P tools/blender/compose_titan.py -- <veiled_titan_original.glb> <out_dir>
      [--tree-ratio 4.5] [--trunk 175] [--ground 0.13]

Input is ingest_original.py's output (welded chunks, both models 1 unit tall, tree behind her at +Y).
  1. Her figure is scaled to 100 studs, plinth base centred on the origin (z = 0 is the floor).
  2. The tree is scaled to --tree-ratio times her and its trunk base set --trunk studs straight behind her centre. Its
     lowest --ground of height is hanging roots: that sinks below z = 0, so the root bed lies flat on
     the floor; faces fully under the floor (hidden in the terrace rock) are trimmed.
  3. Connecting roots in the tree's pale bark (Titan_Roots_NN): ground roots run from the tree's root
     bed to her plinth and climb her body; arching roots leave the trunk and grip her back/shoulders.
Writes <out_dir>/veiled_titan_composed.glb and composed_front.png / composed_side.png for QA.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).parent))
import titan_dressing as td  # noqa: E402  (crawl / tube / smooth / statue_bvh)

ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = Path(ARGS[0]), Path(ARGS[1])


def opt(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default


FIG_H = 100.0
TREE_H = FIG_H * opt("--tree-ratio", 4.5)
TRUNK_Y = opt("--trunk", 175.0)  # trunk base this far behind her centre (her back is ~37)
GROUND = opt("--ground", 0.13)
CAP = 19000
rnd = random.Random(7)
td.rnd.seed(11)


def select(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def box(objs):
    co = np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in objs])
    return co.min(0), co.max(0)


def move(objs, m):
    for o in objs:
        o.data.transform(m)
        o.data.update()


def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SRC))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    select(meshes)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    for o in meshes:  # importer suffixes (e.g. Titan_Figure_01.001) back to clean names
        o.name = o.name.split(".")[0]
    figs = sorted([o for o in meshes if o.name.startswith("Titan_Figure")], key=lambda o: o.name)
    trees = sorted([o for o in meshes if o.name.startswith("Titan_Canopy")], key=lambda o: o.name)
    return figs, trees


def place(figs, trees):
    lo, hi = box(figs)
    s = FIG_H / (hi[2] - lo[2])
    move(figs, Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))))
    lo, hi = box(trees)
    s = TREE_H / (hi[2] - lo[2])
    move(trees, Matrix.Translation(Vector((0, 0, -GROUND * TREE_H))) @ Matrix.Scale(s, 4)
         @ Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))))
    co = np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in trees])
    trunk = np.median(co[(co[:, 2] > 0.08 * TREE_H) & (co[:, 2] < 0.2 * TREE_H)][:, :2], 0)
    move(trees, Matrix.Translation(Vector((-trunk[0], TRUNK_Y - trunk[1], 0))))
    print("TRUNK aligned from", trunk.round(1), flush=True)
    fl, fh = box(figs)
    reach = max(fh[0], fh[1]) + 10

    def buried(f):
        # Under the floor (hidden in rock), or hanging-root tips poking up under/in front of her plinth.
        c = f.calc_center_median()
        top = max(v.co.z for v in f.verts)
        return top < -3.0 or (top < 22 and (Vector((c.x, c.y, 0)).length < reach or (c.y < 0 and abs(c.x) < 80)))

    kept = []
    for o in trees:  # trim faces buried in the terrace rock
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if buried(f)], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
        if len(o.data.polygons):
            kept.append(o)
        else:
            bpy.data.objects.remove(o)
    return kept


def bark_material(trees):
    """Tileable pale bark with dark grain and thin crimson veins, tinted from the tree's own trunk."""
    img = next(n.image for o in trees for m in o.data.materials for n in m.node_tree.nodes
               if n.type == "TEX_IMAGE" and n.image and n.image.colorspace_settings.name != "Non-Color")
    w, h = img.size
    px = np.array(img.pixels[:]).reshape(h, w, 4)
    # Sample the texture where the trunk is (mid-height faces near the tree's axis).
    lo, hi = box(trees)
    axis = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, 0))
    cols = []
    for o in trees:
        uv = o.data.uv_layers.active.data
        for p in o.data.polygons:
            c = p.center
            if 0.2 * TREE_H < c.z < 0.4 * TREE_H and (Vector((c.x, c.y, 0)) - axis).length < 0.12 * TREE_H:
                u, v = uv[p.loop_start].uv
                cols.append(px[int(v % 1 * (h - 1)), int(u % 1 * (w - 1)), :3])
    cols = np.array(cols) if cols else np.array([[0.7, 0.68, 0.66]])
    lum = cols @ np.array([0.3, 0.59, 0.11])
    pale = cols[lum >= np.quantile(lum, 0.6)]
    pale = pale[np.abs(pale[:, 0] - pale[:, 1]) < 0.06]  # bark, not the red veins
    base = np.median(pale, 0) if len(pale) else np.array([0.7, 0.68, 0.66])
    print("BARK base", base.round(3), len(cols), "samples", flush=True)
    n = 512
    g = np.random.default_rng(5)
    fu, fv = np.meshgrid(np.fft.fftfreq(n) * n, np.fft.fftfreq(n) * n)

    def noise(stretch, beta, seed):
        # Tileable fractal noise: filtered white noise, elongated along the root (v).
        spec = np.fft.fft2(np.random.default_rng(seed).standard_normal((n, n)))
        f = np.sqrt(fu ** 2 + (fv * stretch) ** 2) + 1.0
        out = np.real(np.fft.ifft2(spec / f ** beta))
        return (out - out.mean()) / out.std()

    plates = noise(4.0, 1.4, 1)
    ridge = 1 - np.abs(noise(5.0, 1.1, 2))
    crack = np.clip((ridge - 0.82) / 0.18, 0, 1) ** 1.5
    vein = np.clip((1 - np.abs(noise(6.0, 1.6, 3)) - 0.96) / 0.04, 0, 1) * (noise(1.0, 2.0, 4) > 0.6)
    height = 0.5 + 0.12 * plates - 0.45 * crack
    col = base[None, None, :] * (0.86 + 0.22 * plates[..., None]) * (1 - 0.6 * crack[..., None])
    col = col * (1 - vein[..., None]) + np.array([0.45, 0.03, 0.04]) * vein[..., None]
    rgba = np.concatenate([np.clip(col, 0, 1), np.ones((n, n, 1))], 2)
    dx = np.roll(height, -1, 1) - np.roll(height, 1, 1)
    dy = np.roll(height, -1, 0) - np.roll(height, 1, 0)
    nm = np.dstack([-dx * 3.0, -dy * 3.0, np.ones_like(dx)])
    nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    nrgba = np.concatenate([nm * 0.5 + 0.5, np.ones((n, n, 1))], 2)
    mat = bpy.data.materials.new("Titan_Roots_Mat")
    mat.use_nodes = True
    nt = mat.node_tree
    p = nt.nodes["Principled BSDF"]
    for name, arr, nc in (("Titan_Roots_Color", rgba, False), ("Titan_Roots_Normal", nrgba, True)):
        im = bpy.data.images.new(name, n, n)
        if nc:
            im.colorspace_settings.name = "Non-Color"
        im.pixels.foreach_set(arr.astype(np.float32).ravel())
        im.filepath_raw = str(OUT / "maps" / f"{name}.png")
        im.file_format = "PNG"
        im.save()
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = im
        if nc:
            nmap = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(node.outputs["Color"], nmap.inputs["Color"])
            nt.links.new(nmap.outputs["Normal"], p.inputs["Normal"])
        else:
            nt.links.new(node.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.85
    return mat


class RootSet:
    """Tubes packed into Titan_Roots_NN objects of at most CAP triangles."""

    def __init__(self, mat):
        self.mat, self.objs, self.bm = mat, [], None

    def add(self, path, r0, r1, sides=8):
        est = (len(path) // 2 + 1) * sides * 2
        if self.bm is None or len(self.bm.faces) * 2 + est > CAP:
            self.flush()
            self.bm = bmesh.new()
            self.uv = self.bm.loops.layers.uv.new("UVMap")
        knotty(self.bm, self.uv, path, r0, r1, sides)

    def flush(self):
        if self.bm is not None and len(self.bm.faces):
            bmesh.ops.triangulate(self.bm, faces=self.bm.faces[:])
            me = bpy.data.meshes.new(f"Titan_Roots_{len(self.objs) + 1:02d}")
            self.bm.to_mesh(me)
            o = bpy.data.objects.new(f"Titan_Roots_{len(self.objs) + 1:02d}", me)
            bpy.context.scene.collection.objects.link(o)
            me.materials.append(self.mat)
            for poly in me.polygons:
                poly.use_smooth = True
            self.objs.append(o)
        self.bm = None


def knotty(bm, uv, path, r0, r1, sides, every=2):
    """Root tube: tapering, with knots and swelling along its length and a slightly flattened
    cross-section near the floor (roots spread where they lie on stone). Start end dives under
    the floor or into the tree, the far end tapers to a point."""
    pts = path[::every] + ([path[-1]] if (len(path) - 1) % every else [])
    if len(pts) < 2:
        return
    phase, rings, length, nrm = rnd.uniform(0, 9), [], 0.0, None
    up = Vector((0, 0, 1))
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if nrm is None:
            nrm = t.cross(up if abs(t.z) < 0.9 else Vector((1, 0, 0))).normalized()
        nrm = (nrm - t * nrm.dot(t)).normalized()
        b = t.cross(nrm)
        f = i / (len(pts) - 1)
        if i:
            length += (p - pts[i - 1]).length
        r = (r0 + (r1 - r0) * f ** 0.8) * (1 + 0.22 * math.sin(length * 0.21 + phase) * math.sin(length * 0.053 + phase * 2))
        if i == len(pts) - 1:
            r = r1 * 0.2
        flat = 0.72 if p.z < r0 * 1.5 else 1.0
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            off = nrm * math.cos(a) + b * math.sin(a)
            off.z *= flat
            ring.append(bm.verts.new(p + off * r * (1 + 0.08 * math.sin(a * 3 + length * 0.3))))
        rings.append((ring, length))
    circ = 2 * math.pi * r0
    for i in range(len(rings) - 1):
        (ra, la), (rb, lb) = rings[i], rings[i + 1]
        for k in range(sides):
            k2 = (k + 1) % sides
            face = bm.faces.new((ra[k], ra[k2], rb[k2], rb[k]))
            for loop, u, v in zip(face.loops, (k / sides, (k + 1) / sides, (k + 1) / sides, k / sides),
                                  (la / circ, la / circ, lb / circ, lb / circ)):
                loop[uv].uv = (u, v * 0.5)


def bezier(a, b, c, d, n):
    return [a * (1 - t) ** 3 + b * 3 * t * (1 - t) ** 2 + c * 3 * t * t * (1 - t) + d * t ** 3
            for t in (i / (n - 1) for i in range(n))]


def connect(figs, trees, mat):
    fbvh, tbvh = td.statue_bvh(figs), td.statue_bvh(trees)
    tree_co = np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in trees])
    bed = tree_co[(tree_co[:, 2] > 0) & (tree_co[:, 2] < 10)]
    bed_d = np.linalg.norm(bed[:, :2], axis=1)
    bed_a = np.arctan2(bed[:, 0], bed[:, 1])          # 0 = straight behind her (+Y)
    roots = RootSet(mat)
    # Ground roots: from the tree's root bed, across the floor, up her plinth, climbing her body.
    for k in range(11):
        a = math.radians(-105 + k * 21 + rnd.uniform(-5, 5))
        far = Vector((math.sin(a), math.cos(a), 0)) * 200 + Vector((0, 0, 4))
        hit = fbvh.ray_cast(far, Vector((-far.x, -far.y, 0)).normalized(), 400)[0]
        if hit is None:
            continue
        pick = (np.abs(bed_a - a) < math.radians(14)) & (bed_d > hit.length + 25) & (bed_d < hit.length + 120)
        if not pick.any():
            continue
        start = Vector(bed[rnd.choice(np.flatnonzero(pick))])
        r0 = rnd.uniform(3.0, 5.0)
        ground = [start + Vector((0, 0, -r0 * 2.5)) + (start - hit).normalized() * 6]
        n = max(8, int((start - hit).length / 1.2))
        side = Vector((math.cos(a), -math.sin(a), 0))
        for i in range(n):
            t = i / (n - 1)
            p = start.lerp(hit, t) + side * math.sin(t * math.pi * 2 + k) * 6 * (1 - t)
            p.z = r0 * 0.3 + math.sin(t * math.pi * 3 + k) * 1.2
            ground.append(p)
        climb = td.crawl(fbvh, hit, rnd.randrange(35, 90), rnd.choice((-1, 1)), rnd.uniform(0.55, 0.8),
                         step=1.2, offset=r0 * 0.6, zmax=FIG_H * rnd.uniform(0.45, 0.85))
        path = td.smooth(ground + climb[1:], 3)
        roots.add(path, r0, 0.7)
        for _ in range(len(path) // 45):  # rootlets peeling off onto the robe
            i = rnd.randrange(len(ground), max(len(ground) + 1, len(path) - 5))
            sub = td.crawl(fbvh, path[i], 22, rnd.choice((-1, 1)), 0.35, step=1.0, offset=1.2, zmax=FIG_H)
            roots.add(sub, r0 * 0.35, 0.25, sides=6)
    # Arching roots: leave the trunk's front face and grip her back and shoulders.
    for k in range(4):
        x = -36 + k * 24 + rnd.uniform(-4, 4)
        z0 = rnd.uniform(20, 70)
        s = tbvh.find_nearest(Vector((x * 1.4, 40, z0)))[0]
        e = fbvh.find_nearest(Vector((x * 0.55, 45, rnd.uniform(48, 82))))[0]
        if s is None or e is None:
            continue
        lift = 18 + rnd.uniform(0, 14)
        wob = Vector((rnd.uniform(-14, 14), 0, rnd.uniform(-6, 6)))
        arch = bezier(s, s + Vector((0, -30, lift)) + wob, e + Vector((0, 35, lift)) - wob, e, 60)
        arch = [p + Vector((math.sin(i * 0.35 + k), 0, math.cos(i * 0.27 + k))) * 2.0 * math.sin(math.pi * i / 59)
                for i, p in enumerate(arch)]
        grip = td.crawl(fbvh, e, rnd.randrange(20, 45), rnd.choice((-1, 1)), 0.25, step=1.1, offset=2.5, zmax=FIG_H * 0.9)
        roots.add(td.smooth(arch + grip[1:], 2), rnd.uniform(3.5, 4.8), 0.6)
    roots.flush()
    return roots.objs


def render(objs, name, eye, look):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1000, 1000
    sc.view_settings.view_transform = "AgX"
    if not sc.world:
        sc.world = bpy.data.worlds.new("Sky")
        sc.world.use_nodes = True
        sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.42, 0.5, 1)
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy, sun.data.color = 4.0, (1.0, 0.82, 0.62)
        sun.rotation_euler = (0.9, 0, 0.6)
        sc.collection.objects.link(sun)
        floor = bpy.data.objects.new("Floor", bpy.data.meshes.new("Floor"))
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=600)
        bm.to_mesh(floor.data)
        bm.free()
        sc.collection.objects.link(floor)
    cam = sc.camera or bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    if not sc.camera:
        sc.collection.objects.link(cam)
        sc.camera = cam
    cam.data.lens = 28
    cam.data.clip_end = 5000
    cam.location = eye
    cam.rotation_euler = (look - eye).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)


def main():
    (OUT / "maps").mkdir(parents=True, exist_ok=True)
    figs, trees = load()
    trees = place(figs, trees)
    roots = connect(figs, trees, bark_material(trees))
    parts = figs + trees + roots
    for o in parts:
        print("PART", o.name, tris(o), flush=True)
    select(parts)
    glb = OUT / "veiled_titan_composed.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True)
    render(parts, "composed_front.png", Vector((40, -260, 60)), Vector((0, 60, 90)))
    render(parts, "composed_side.png", Vector((-230, -40, 25)), Vector((0, 90, 40)))
    render(parts, "composed_base.png", Vector((-90, -110, 12)), Vector((0, 20, 25)))
    print("COMPOSE_OK", glb, len(parts), "parts", round(glb.stat().st_size / 1e6, 2), "MB")


main()

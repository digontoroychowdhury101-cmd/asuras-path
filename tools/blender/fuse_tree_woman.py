"""Fuses the woman sculpt into the giant tree in tree+woman.blend and prepares it for Roblox (headless Blender).

Usage:
  Blender -b tree+woman.blend --python-exit-code 1 -P tools/blender/fuse_tree_woman.py -- <out_dir>
      [--ratio 4.0] [--gap 0.12] [--sink 0.04] [--reach 1.5] [--bed 1.0] [--preview] [--no-save] [--save-as PATH]

Works on the two sculpts already in the file: `model` (the woman, facing -Y) and `model.001` (the tree).
  1. The tree is turned so its crown leans over her and scaled to --ratio times her height. She stays a
     distinct figure: she stands on its root mass with a clear --gap (in her heights) between her back
     and the trunk, nothing of the tree in front of her body.
  2. Roots rise from the root bed and coil round her hem and feet, and two pairs of arching roots reach
     from the trunk toward her shoulders without touching her (Titan_Roots_NN). Crimson sap runs down the
     trunk, drips off the boughs and leaves a few thin trails on her (Titan_Sap_NN, roughness ~0.12).
  3. Solid blood-red leaves (real geometry, no alpha cards) cluster on the twig ends (Titan_Canopy_Leaves_NN).
  4. Her and the tree's 2K maps are re-baked (Cycles emission bakes on their own UVs): bark tints only her
     hem where the roots hold it, sap stains both; roughness and metalness are baked to match. Their own
     normal maps are kept.
  5. Nothing is decimated. Seams are welded, whole-mesh weighted normals are frozen, then each mesh is cut
     by recursive median splits into parts of <= 19,000 triangles (Titan_Figure_NN, Titan_Canopy_NN).
--preview stops after step 3 and only renders. Otherwise the parts are saved back into the .blend
(collection FusedTreeStatue, all origins at the world origin) unless --no-save, and <out_dir> gets
fused_tree_statue.glb/.fbx (her height = 100 units), maps/*.png (2048), previews and stats.json.
"""
import json
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
import titan_dressing as td  # noqa: E402  (crawl / smooth / statue_bvh)

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = Path(ARGS[0]).resolve()


def opt(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default


RATIO = opt("--ratio", 4.0)
GAP = opt("--gap", 0.12)  # clear space between her back and the trunk, in her heights
SINK = opt("--sink", 0.04)  # the whole piece drops this much of the tree's height: the root flare, not
#                             its hanging root tips, meets the floor; tips left under the floor are trimmed
REACH = opt("--reach", 1.5)  # the low roots' floor reach about the bed centre, in her heights
BED = opt("--bed", 1.0)  # bed centre this far behind her, in her heights (SanctuaryTitan.TreeSpan.Forward)
PREVIEW = "--preview" in ARGS
CAP = 19000
TEX = 2048
FIG_UNITS = 100.0  # her height in the exported GLB/FBX (the earlier titan pipeline's convention)
STUD_FIGURE = 150.0  # SanctuaryTitan.FIGURE_HEIGHT, for the TreeSpan numbers
Z = Vector((0, 0, 1))
rnd = random.Random(7)
td.rnd.seed(11)
H = TH = 1.0  # her height / the tree's height, set by place()
ZB = 0.0  # height of her feet above the floor (she stands on the root mass), set by place()
TRUNK = np.zeros(2)  # trunk centre (x, y); she is centred on x = y = 0


# ------------------------------------------------------------------------------------------ helpers
def select(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def verts(o):
    co = np.empty(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def vnormals(o):
    n = np.empty(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("normal", n)
    return n.reshape(-1, 3)


def bvh_of(objs):
    return td.statue_bvh(objs)


def link(o):
    bpy.context.scene.collection.objects.link(o)
    return o


def save_png(img, path):
    # Never touch colorspace here: changing it regenerates a generated image and wipes its pixels.
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def new_image(name, arr, non_color=False):
    """arr: (n, n, 3|4) floats in 0..1, already in the image's colour space."""
    n = arr.shape[0]
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((n, n, 1))], 2)
    im = bpy.data.images.new(name, n, n, alpha=False, is_data=non_color)
    im.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
    return save_png(im, OUT / "maps" / f"{name}.png")


def noise(n, stretch, beta, seed):
    """Tileable fractal noise, elongated along v (rows) by `stretch`."""
    fu, fv = np.meshgrid(np.fft.fftfreq(n) * n, np.fft.fftfreq(n) * n)
    spec = np.fft.fft2(np.random.default_rng(seed).standard_normal((n, n)))
    f = np.sqrt(fu ** 2 + (fv * stretch) ** 2) + 1.0
    out = np.real(np.fft.ifft2(spec / f ** beta))
    return (out - out.mean()) / out.std()


def normal_from_height(height, strength):
    dx = np.roll(height, -1, 1) - np.roll(height, 1, 1)
    dy = np.roll(height, -1, 0) - np.roll(height, 1, 0)
    nm = np.dstack([-dx * strength, -dy * strength, np.ones_like(dx)])
    nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    return nm * 0.5 + 0.5


def principled(name, color, rough, normal=None, metal=None, rough_value=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = False
    nt = mat.node_tree
    p = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = color
    nt.links.new(tex.outputs["Color"], p.inputs["Base Color"])
    if rough is not None:
        r = nt.nodes.new("ShaderNodeTexImage")
        r.image = rough
        nt.links.new(r.outputs["Color"], p.inputs["Roughness"])
    else:
        p.inputs["Roughness"].default_value = rough_value
    if metal is not None:
        m = nt.nodes.new("ShaderNodeTexImage")
        m.image = metal
        nt.links.new(m.outputs["Color"], p.inputs["Metallic"])
    else:
        p.inputs["Metallic"].default_value = 0.0
    if normal is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = normal
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    return mat


# ------------------------------------------------------------------------------------------ 1. place
def own(o):
    if o.data.users > 1:
        o.data = o.data.copy()
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
    o.data.update()


def weld_and_smooth(o):
    """Weld the importer's UV-seam splits (UVs live on loops, so they survive) and freeze smooth
    face-area weighted normals over the whole mesh, before any chunk cut."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    co = verts(o)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=float(np.linalg.norm(co.max(0) - co.min(0))) * 1e-6)
    print(f"WELD {o.name}: verts {before} -> {len(bm.verts)}", flush=True)
    bm.to_mesh(o.data)
    bm.free()
    select([o])
    if o.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bpy.ops.object.shade_smooth()
    m = o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    m.mode, m.keep_sharp, m.weight = "FACE_AREA", True, 50
    bpy.ops.object.modifier_apply(modifier=m.name)


def place(woman, tree):
    global H, TH
    co = verts(woman)
    lo, hi = co.min(0), co.max(0)
    woman.data.transform(Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))))
    H = float(hi[2] - lo[2])
    TH = RATIO * H
    co = verts(tree)
    lo, hi = co.min(0), co.max(0)
    s = TH / (hi[2] - lo[2])
    # Turn the tree half round: its crown leaned toward +Y (away from her face); now it leans over her.
    tree.data.transform(Matrix.Translation(Vector((0, 0, -0.012 * TH))) @ Matrix.Scale(s, 4)
                        @ Matrix.Rotation(math.pi, 4, "Z")
                        @ Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))))
    co = verts(tree)
    band = co[(co[:, 2] > 0.08 * TH) & (co[:, 2] < 0.2 * TH)]
    trunk = np.median(band[:, :2], 0)
    tree.data.transform(Matrix.Translation(Vector((-trunk[0], -trunk[1], 0))))
    tree.data.update()
    # The root flare reaches ~1.3x her height out from the trunk at the floor, so standing on the floor
    # she would be buried behind roots. She is raised onto the root mass instead: the lowest height
    # `zb` where nothing of the tree stands in front of her or touches her back above the knees, with
    # her hem resting on the roots, and GAP*H of open space behind her torso.
    tbvh = bvh_of([tree])

    def front(z):  # the tree's front-most surface (toward -Y) at height z, across her width
        ys = [h.y for x in (-0.25, 0, 0.25)
              if (h := tbvh.ray_cast(Vector((x * H, -5 * TH, z)), Vector((0, 1, 0)), 10 * TH)[0]) is not None]
        return min(ys) if ys else 0.0

    wco = verts(woman)
    torso = wco[(wco[:, 2] > 0.5 * H) & (wco[:, 2] < 0.75 * H) & (np.abs(wco[:, 0]) < 0.15 * H)]
    back_y = float(torso[:, 1].max())
    levels = np.arange(0.35, 1.0, 0.05) * H
    rows = [wco[(np.abs(wco[:, 2] - z) < 0.05 * H) & (np.abs(wco[:, 0]) < 0.3 * H)] for z in levels]
    her_front = [float(b[:, 1].min()) if len(b) else 0.0 for b in rows]
    her_back = [float(b[:, 1].max()) if len(b) else 0.0 for b in rows]
    hem = wco[wco[:, 2] < 0.06 * H][::40]
    best = None
    for zb in np.arange(0.0, 0.81, 0.025) * H:
        c = front(zb + 0.62 * H) - GAP * H - back_y  # her centre y with the trunk at the origin
        fronts = [front(zb + z) for z in levels]
        hidden = sum(t < c + f - 0.05 * H for t, f in zip(fronts, her_front)) +             sum(t < c + b + 0.03 * H for t, b in zip(fronts[2:], her_back[2:]))  # in front of her / touching her back
        held = np.mean([tbvh.ray_cast(Vector((p[0], c + p[1], zb + 0.03 * H)), Vector((0, 0, -1)), 0.15 * H)[0]
                        is not None for p in hem])
        if best is None or (hidden, -held) < best[2:]:
            best = (zb, c, hidden, -held)
        if hidden == 0 and held >= 0.5:
            best = (zb, c, hidden, -held)
            break
    global ZB, TRUNK
    ZB, c = float(best[0]), float(best[1])
    woman.data.transform(Matrix.Translation(Vector((0, 0, ZB))))
    tree.data.transform(Matrix.Translation(Vector((0, -c, 0))))
    TRUNK = np.array([0.0, -c])
    for o in (woman, tree):
        o.data.update()
    print(f"PLACE H={H:.3f} TH={TH:.3f} raised {ZB / H:.3f}H, trunk centre y {-c:.3f}, hidden {best[2]}, "
          f"hem held {-best[3]:.2f}", flush=True)
    ground(woman, tree)


def ground(woman, tree):
    """Seat the root flare on the floor and keep it on the terrace. The low roots are drawn in
    smoothly about the bed centre (BED*H behind her) past 0.8*REACH, so their reach ends near
    REACH*H; then everything sinks SINK*TH and root tips buried deeper than 0.03*TH are trimmed.
    Vertices move, none are removed from what stays above the floor."""
    global ZB
    me = tree.data
    co = verts(tree)
    centre = np.array([0.0, BED * H])
    d = co[:, :2] - centre
    r = np.linalg.norm(d, axis=1)
    knee, far = 0.8 * REACH * H, float(np.quantile(r[co[:, 2] < 0.06 * TH], 0.995))
    k = (REACH * H - knee) / max(far - knee, 1e-6)
    pulled = np.where(r > knee, knee + (r - knee) * k, r)
    t = np.clip((0.16 * TH - co[:, 2]) / (0.08 * TH), 0, 1)  # full below 0.08*TH, none above 0.16*TH
    w = t * t * (3 - 2 * t)
    scale = np.where(r > 1e-6, (r + (pulled - r) * w) / np.maximum(r, 1e-6), 1.0)
    co[:, :2] = centre + d * scale[:, None]
    co[:, 2] -= SINK * TH
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    woman.data.transform(Matrix.Translation(Vector((0, 0, -SINK * TH))))
    woman.data.update()
    ZB -= SINK * TH
    bm = bmesh.new()
    bm.from_mesh(me)
    buried = [f for f in bm.faces if max(v.co.z for v in f.verts) < -0.03 * TH]
    bmesh.ops.delete(bm, geom=buried, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.update()
    low = verts(tree)
    low = low[np.abs(low[:, 2]) < 0.01 * TH]
    print(f"GROUND sink {SINK * TH:.3f}m, roots drawn in past {knee / H:.2f}H (k={k:.2f}), trimmed {len(buried)} "
          f"buried faces, floor reach {np.linalg.norm(low[:, :2] - centre, axis=1).max() / H:.2f}H, she stands "
          f"{ZB / H:.3f}H up", flush=True)


# ------------------------------------------------------------------------------------------ geometry sets
class PartSet:
    """Generated geometry packed into <prefix>_NN objects of at most CAP triangles each."""

    def __init__(self, prefix, mat):
        self.prefix, self.mat, self.objs, self.bm = prefix, mat, [], None

    def begin(self, est):
        if self.bm is None or len(self.bm.faces) * 2 + est > CAP:
            self.flush()
            self.bm = bmesh.new()
            self.uv = self.bm.loops.layers.uv.new("UVMap")
        return self.bm, self.uv

    def flush(self):
        if self.bm is not None and len(self.bm.faces):
            bmesh.ops.triangulate(self.bm, faces=self.bm.faces[:])
            name = f"{self.prefix}_{len(self.objs) + 1:02d}"
            me = bpy.data.meshes.new(name)
            self.bm.to_mesh(me)
            o = link(bpy.data.objects.new(name, me))
            me.materials.append(self.mat)
            for poly in me.polygons:
                poly.use_smooth = True
            self.objs.append(o)
        self.bm = None


def rings_to_faces(bm, uv, rings, sides, circ, vscale):
    # Closed ends: an exposed tube end never shows as an open ring.
    bm.faces.new(list(reversed(rings[0][0])))
    bm.faces.new(rings[-1][0])
    for i in range(len(rings) - 1):
        (ra, la), (rb, lb) = rings[i], rings[i + 1]
        for k in range(sides):
            k2 = (k + 1) % sides
            face = bm.faces.new((ra[k], ra[k2], rb[k2], rb[k]))
            for loop, u, v in zip(face.loops, (k / sides, (k + 1) / sides, (k + 1) / sides, k / sides),
                                  (la, la, lb, lb)):
                loop[uv].uv = (u, v / circ * vscale)


def frame(pts, i, nrm):
    t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
    if nrm is None:
        nrm = t.cross(Z if abs(t.z) < 0.9 else Vector((1, 0, 0))).normalized()
    nrm = (nrm - t * nrm.dot(t)).normalized()
    return t, nrm, t.cross(nrm)


def knotty(parts, path, r0, r1, sides=8, every=2):
    """Root tube (as compose_titan): tapering, knotted, flattened where it lies on the ground."""
    pts = path[::every] + ([path[-1]] if (len(path) - 1) % every else [])
    if len(pts) < 2:
        return
    bm, uv = parts.begin(len(pts) * sides * 2)
    phase, rings, length, nrm = rnd.uniform(0, 9), [], 0.0, None
    for i, p in enumerate(pts):
        t, nrm, b = frame(pts, i, nrm)
        f = i / (len(pts) - 1)
        if i:
            length += (p - pts[i - 1]).length
        r = (r0 + (r1 - r0) * f ** 0.8) * (1 + 0.22 * math.sin(length / r0 * 0.9 + phase) * math.sin(length / r0 * 0.23 + phase * 2))
        if i == len(pts) - 1:
            r = r1 * 0.2
        flat = 0.72 if p.z < r0 * 1.5 else 1.0
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            off = nrm * math.cos(a) + b * math.sin(a)
            off.z *= flat
            ring.append(bm.verts.new(p + off * r * (1 + 0.08 * math.sin(a * 3 + length / r0 * 1.3))))
        rings.append((ring, length))
    rings_to_faces(bm, uv, rings, sides, 2 * math.pi * r0, 0.5)


def sap_tube(parts, path, r0, drip=0.0, sides=6):
    """Sap run: a thin bead that swells and thins along the bark, ending in a hanging drop of length `drip`."""
    pts = list(path)
    if drip > 0:
        end = pts[-1]
        pts += [end - Z * drip * f for f in (0.25, 0.5, 0.72, 0.86, 0.95, 1.0, 1.04)]
    if len(pts) < 2:
        return
    bm, uv = parts.begin(len(pts) * sides * 2)
    phase, rings, length, nrm = rnd.uniform(0, 9), [], 0.0, None
    n_run = len(path)
    for i, p in enumerate(pts):
        t, nrm, b = frame(pts, i, nrm)
        if i:
            length += (p - pts[i - 1]).length
        if i < n_run:
            f = i / max(1, n_run - 1)
            r = r0 * (1 - 0.35 * f) * (1 + 0.28 * math.sin(length / r0 * 0.45 + phase))
            if i == 0:
                r = r0 * 0.3
        else:  # neck, then the drop
            r = r0 * (0.55, 0.42, 0.75, 1.15, 1.2, 0.85, 0.15)[i - n_run]
        rings.append(([bm.verts.new(p + (nrm * math.cos(a) + b * math.sin(a)) * r)
                       for a in (2 * math.pi * k / sides for k in range(sides))], length))
    rings_to_faces(bm, uv, rings, sides, 2 * math.pi * r0, 0.25)


def bezier(a, b, c, d, n):
    return [a * (1 - t) ** 3 + b * 3 * t * (1 - t) ** 2 + c * 3 * t * t * (1 - t) + d * t ** 3
            for t in (i / (n - 1) for i in range(n))]


# ------------------------------------------------------------------------------------------ 2. fusion roots
def fuse_roots(woman, tree, mat):
    fbvh, tbvh = bvh_of([woman]), bvh_of([tree])
    roots = PartSet("Titan_Roots", mat)
    k = H / 100.0  # compose_titan's numbers were for a 100-stud figure
    wco = verts(woman)

    # Ground roots: from the tree's root bed over the root mass to her hem, coiling round her feet only.
    tco = verts(tree)
    bed = tco[(tco[:, 2] > 0) & (tco[:, 2] < 0.025 * TH)]
    bed_d = np.linalg.norm(bed[:, :2], axis=1)
    bed_a = np.arctan2(bed[:, 0], -bed[:, 1])  # 0 = straight in front of her (-Y)
    for j in range(10):
        a = math.radians(-120 + j * 26 + rnd.uniform(-6, 6))
        far = Vector((math.sin(a), -math.cos(a), 0)) * 4 * H + Vector((0, 0, ZB + 0.04 * H))
        hit = fbvh.ray_cast(far, Vector((-far.x, -far.y, 0)).normalized(), 8 * H)[0]
        if hit is None:
            continue
        pick = (np.abs(bed_a - a) < math.radians(20)) & (bed_d > hit.length + 0.2 * H) & (bed_d < hit.length + 1.2 * H)
        if not pick.any():
            continue
        start = Vector(bed[rnd.choice(np.flatnonzero(pick))])
        r0 = rnd.uniform(3.0, 5.0) * k
        ground = [start + Vector((0, 0, -r0 * 2.5)) + (start - hit).normalized() * 6 * k]
        n = max(8, int((start - hit).length / (1.2 * k)))
        side = Vector((math.cos(a), math.sin(a), 0))
        for i in range(n):
            t = i / (n - 1)
            p = start.lerp(hit, t) + side * math.sin(t * math.pi * 2 + j) * 6 * k * (1 - t)
            p.z = r0 * 0.3 + (hit.z - r0 * 0.3) * t ** 2 + math.sin(t * math.pi * 3 + j) * 1.2 * k
            ground.append(p)
        climb = td.crawl(fbvh, hit, rnd.randrange(35, 90), rnd.choice((-1, 1)), rnd.uniform(0.55, 0.8),
                         step=1.2 * k, offset=r0 * 0.6, zmax=ZB + H * rnd.uniform(0.08, 0.16))
        path = td.smooth(ground + climb[1:], 3)
        knotty(roots, path, r0, 0.7 * k)
        for _ in range(len(path) // 45):  # rootlets peeling off round the hem
            i = rnd.randrange(len(ground), max(len(ground) + 1, len(path) - 5))
            sub = td.crawl(fbvh, path[i], 22, rnd.choice((-1, 1)), 0.35, step=1.0 * k, offset=1.2 * k, zmax=ZB + 0.18 * H)
            knotty(roots, sub, r0 * 0.35, 0.25 * k, sides=6)

    # Arching roots: grow out of the trunk beside her and reach toward her shoulders, stopping short of
    # her (tips GAP-ish clear of her body). Their thick ends start buried in the bark.
    for j in range(4):
        side = -1 if j % 2 == 0 else 1
        r0 = rnd.uniform(0.022, 0.032) * H
        # The trunk face behind her (a ray toward the trunk), so the root leaves the trunk itself.
        loc, n = tbvh.ray_cast(Vector((side * rnd.uniform(0.35, 0.6) * H, -1.0 * H, ZB + rnd.uniform(0.7, 1.15) * H)),
                               Vector((0, 1, 0)), 4 * TH)[:2]
        e, en = fbvh.find_nearest(Vector((side * 0.3 * H, -0.05 * H, ZB + rnd.uniform(0.66, 0.8) * H)))[:2]
        if loc is None or e is None:
            continue
        reach = e + en * rnd.uniform(0.08, 0.14) * H  # stops in the air beside her
        start = loc + Vector((0, 1, 0)) * r0 * 5  # buried deep in the bark
        bend = Vector((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.12, -0.04), rnd.uniform(0.1, 0.22))) * H
        arch = bezier(start, loc + n * 0.24 * H + bend,
                      reach + Vector((side * 0.2 * H, -0.1 * H, 0.2 * H)) - bend * 0.5, reach, 48)
        knotty(roots, arch, r0, 0.004 * H)
    roots.flush()
    return roots.objs


# ------------------------------------------------------------------------------------------ 3. sap
def flow(bvh, start, steps, step, offset, wander=0.35):
    """Runs downhill over a surface. Returns the path and whether it ran off an underside (drips)."""
    loc, n, _, _ = bvh.find_nearest(start)
    if loc is None:
        return [], False
    p = loc + n * offset
    path, heading = [p.copy()], None
    for _ in range(steps):
        loc, n, _, _ = bvh.find_nearest(p)
        if loc is None:
            break
        down = -Z - n * (-Z).dot(n)
        if down.length < 0.2:
            return td.smooth(path, 2), n.z < 0  # underside: the bead lets go
        down.normalize()
        want = down + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0)) * wander
        heading = want if heading is None else heading * 0.7 + want * 0.3
        heading = (heading - n * heading.dot(n)).normalized()
        p = loc + n * offset + heading * step
        path.append(p.copy())
        if p.z < 0.01 * H:
            break
    return td.smooth(path, 2), False


def sap(woman, tree, roots, mat):
    fbvh, tbvh = bvh_of([woman]), bvh_of([tree])
    runs = PartSet("Titan_Sap", mat)
    tco, tn = verts(tree), vnormals(tree)
    g = np.random.default_rng(9)
    # Runs down the trunk and boughs: more of them around her, where the tree holds her.
    near = np.linalg.norm(tco[:, :2], axis=1) < 1.4 * H  # around her
    ok = (tco[:, 2] > 0.1 * TH) & (tco[:, 2] < 0.75 * TH) & (tn[:, 2] > -0.3)
    starts = list(g.choice(np.flatnonzero(ok & near), 45, replace=False)) + \
        list(g.choice(np.flatnonzero(ok & ~near), 55, replace=False))
    drips = 0
    for i in starts:
        r0 = rnd.uniform(0.0022, 0.005) * TH
        path, under = flow(tbvh, Vector(tco[i]), rnd.randrange(40, 170), 0.004 * TH, r0 * 0.45)
        if len(path) > 3:
            sap_tube(runs, path, r0, drip=rnd.uniform(0.012, 0.03) * TH if under else 0.0)
            drips += under
    # Drops hanging from the boughs' undersides.
    hang = np.flatnonzero((tco[:, 2] > 0.35 * TH) & (tn[:, 2] < -0.75))
    for i in g.choice(hang, min(70, len(hang)), replace=False):
        p = Vector(tco[i])
        sap_tube(runs, [p + Z * 0.002 * TH, p - Z * 0.001 * TH], rnd.uniform(0.0015, 0.0028) * TH,
                 drip=rnd.uniform(0.006, 0.03) * TH)
    # Trails over her, from where the tendrils hold her shoulders and chest.
    wco, wn = verts(woman), vnormals(woman)
    band = np.flatnonzero((wco[:, 2] > ZB + 0.6 * H) & (wco[:, 2] < ZB + 0.86 * H) & (wn[:, 2] > -0.2) & (wco[:, 1] < 0.05 * H))
    for i in g.choice(band, min(8, len(band)), replace=False):
        r0 = rnd.uniform(0.003, 0.005) * H
        path, _ = flow(fbvh, Vector(wco[i]), rnd.randrange(30, 110), 0.006 * H, r0 * 0.4, wander=0.25)
        if len(path) > 3:
            sap_tube(runs, path, r0, drip=rnd.uniform(0.01, 0.025) * H)
    runs.flush()
    print("SAP runs", len(starts), "drips off undersides", drips, flush=True)
    return runs.objs


# ------------------------------------------------------------------------------------------ 4. leaves
LEAF = [(0.0, 0.0), (-0.5, 0.3), (-0.36, 0.72), (0.0, 1.0), (0.36, 0.72), (0.5, 0.3), (0.0, 0.5)]
LEAF_TRIS = [(0, 1, 6), (1, 2, 6), (2, 3, 6), (3, 4, 6), (4, 5, 6), (5, 0, 6)]
TILES = 4


def leaves(tree, mat, total=16000):
    """Blood-red leaves on the twig ends. Twigs are the crown's sparsest surface cells (the trunk and
    main boughs fill their cells with far more surface); each holds a radiating cluster."""
    co = verts(tree)
    crown = co[co[:, 2] > 0.45 * TH]
    cell = 0.025 * TH
    keys = np.floor(crown / cell).astype(np.int64)
    uniq, inv, counts = np.unique(keys, axis=0, return_inverse=True, return_counts=True)
    inv = inv.ravel()
    cent = np.zeros((len(uniq), 3))
    np.add.at(cent, inv, crown)
    cent /= counts[:, None]
    twig = cent[counts <= np.quantile(counts, 0.55)]
    g = np.random.default_rng(21)
    per = max(2, int(round(total / max(1, len(twig)))))
    print(f"LEAVES twig cells {len(twig)} x {per}", flush=True)
    centres, bases, axes, norms, sizes, tiles = [], [], [], [], [], []
    up = np.array([0, 0, 1.0])
    for c in twig:
        tone = g.integers(0, TILES)  # atlas row: each cluster keeps one tone (maroon .. scarlet)
        out = c[:2] - TRUNK
        out = np.array([out[0], out[1], 0]) / (np.linalg.norm(out) + 1e-6)
        for _ in range(per):
            d = g.normal(size=3)
            d /= np.linalg.norm(d)
            base = c + d * g.uniform(0.1, 1.0) * 0.045 * TH
            ax = d * 0.7 + g.normal(size=3) * 0.5 + out * 0.3 - up * 0.25
            ax /= np.linalg.norm(ax)
            nv = g.normal(size=3) + up * 0.9 + out * 0.4
            nv -= ax * nv.dot(ax)
            nv /= np.linalg.norm(nv) + 1e-9
            centres.append(c)
            bases.append(base)
            axes.append(ax)
            norms.append(nv)
            sizes.append(g.uniform(0.018, 0.028) * TH)
            tiles.append(tone * TILES + g.integers(0, TILES))
    bases, axes, norms = np.array(bases), np.array(axes), np.array(norms)
    sizes, tiles = np.array(sizes), np.array(tiles)
    sides = np.cross(norms, axes)
    n = len(bases)
    # Spatially grouped so each part is one compact region of the crown.
    groups = median_groups(bases, np.full(n, len(LEAF_TRIS)), CAP)
    objs = []
    lc = np.array(LEAF)
    for gi, idx in enumerate(groups):
        L, W = sizes[idx, None], sizes[idx, None] * 0.46
        vs = []
        for s, t in lc:
            fold = (0.06 if (s, t) == (0.0, 0.5) else 0.0) - 0.08 * t * t  # midrib fold, drooping tip
            vs.append(bases[idx] + axes[idx] * (t * L) + sides[idx] * (s * W) + norms[idx] * (fold * L))
        vs = np.stack(vs, 1).reshape(-1, 3)
        base_i = (np.arange(len(idx)) * len(LEAF))[:, None, None]
        faces = (np.array(LEAF_TRIS)[None] + base_i).reshape(-1, 3)
        name = f"Titan_Canopy_Leaves_{gi + 1:02d}"
        me = bpy.data.meshes.new(name)
        me.from_pydata(vs.tolist(), [], faces.tolist())
        uvl = me.uv_layers.new(name="UVMap")
        tu, tv = (tiles[idx] % TILES) / TILES, (tiles[idx] // TILES) / TILES
        inset = 0.04 / TILES
        loop_uv = []
        for li in range(len(idx)):
            for tri in LEAF_TRIS:
                for vi in tri:
                    s, t = LEAF[vi]
                    loop_uv += [tu[li] + inset + (s + 0.5) * (1 / TILES - 2 * inset),
                                tv[li] + inset + t * (1 / TILES - 2 * inset)]
        uvl.data.foreach_set("uv", loop_uv)
        me.materials.append(mat)
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
        me.update()
        objs.append(link(bpy.data.objects.new(name, me)))
    print("LEAVES", n, "in", len(objs), "parts", flush=True)
    return objs


def median_groups(cen, weight, cap):
    """Recursive median split of items (centres, triangle weights) into groups of <= cap triangles."""
    out, stack = [], [np.arange(len(cen))]
    while stack:
        idx = stack.pop()
        if weight[idx].sum() <= cap:
            out.append(idx)
            continue
        c = cen[idx]
        axis = int(np.argmax(c.max(0) - c.min(0)))
        order = idx[np.argsort(c[:, axis], kind="stable")]
        half = len(order) // 2
        stack += [order[half:], order[:half]]
    out.sort(key=lambda i: (cen[i, 2].mean(), cen[i, 0].mean()))
    return out


# ------------------------------------------------------------------------------------------ 5. textures
def bark_maps(tree_color):
    """Tileable 2K bark for the tendrils, its pale base taken from the tree's own albedo."""
    px = np.array(tree_color.pixels[:]).reshape(tree_color.size[1], tree_color.size[0], 4)[::8, ::8, :3].reshape(-1, 3)
    lum = px @ np.array([0.3, 0.59, 0.11])
    pale = px[(lum >= np.quantile(lum, 0.5)) & (np.abs(px[:, 0] - px[:, 1]) < 0.06)]
    base = np.median(pale, 0) if len(pale) else np.array([0.72, 0.7, 0.68])
    print("BARK base", base.round(3), flush=True)
    n = TEX
    plates = noise(n, 4.0, 1.4, 1)
    ridge = 1 - np.abs(noise(n, 5.0, 1.1, 2))
    crack = np.clip((ridge - 0.82) / 0.18, 0, 1) ** 1.5
    vein = np.clip((1 - np.abs(noise(n, 6.0, 1.6, 3)) - 0.96) / 0.04, 0, 1) * (noise(n, 1.0, 2.0, 4) > 0.6)
    height = 0.5 + 0.12 * plates - 0.45 * crack
    col = base[None, None, :] * (0.86 + 0.22 * plates[..., None]) * (1 - 0.68 * crack[..., None])
    col = col * (1 - vein[..., None]) + np.array([0.45, 0.03, 0.04]) * vein[..., None]
    rough = np.clip(0.82 + 0.1 * crack - 0.5 * vein, 0, 1)
    return (new_image("Fused_Bark_Color", col), new_image("Fused_Bark_Normal", normal_from_height(height, 3.0), True),
            new_image("Fused_Bark_Roughness", np.repeat(rough[..., None], 3, 2), True))


def sap_maps():
    """Deep crimson, clotting darker in places, with a wet sheen that the low roughness carries."""
    n = TEX
    clot = noise(n, 0.35, 1.6, 11)  # varies mostly along the run (v)
    fine = noise(n, 1.0, 0.9, 12)
    t = np.clip(0.5 + 0.22 * clot + 0.06 * fine, 0, 1)[..., None]
    deep, bright = np.array([0.20, 0.0, 0.012]), np.array([0.62, 0.02, 0.05])
    col = deep * (1 - t) + bright * t
    height = 0.5 + 0.08 * clot + 0.03 * fine
    rough = np.clip(0.12 + 0.05 * fine - 0.03 * clot, 0.06, 0.2)
    return (new_image("Fused_Sap_Color", col), new_image("Fused_Sap_Normal", normal_from_height(height, 2.0), True),
            new_image("Fused_Sap_Roughness", np.repeat(rough[..., None], 3, 2), True))


def leaf_maps():
    """4x4 atlas of leaf blades in blood reds (maroon to scarlet): veins, darker base, lighter tip."""
    n, tile = TEX, TEX // TILES
    tones = np.array([[0.40, 0.0, 0.03], [0.58, 0.01, 0.035], [0.74, 0.03, 0.05], [0.86, 0.06, 0.06]])
    col = np.zeros((n, n, 3))
    height = np.zeros((n, n))
    rough = np.zeros((n, n))
    v, u = np.meshgrid(np.linspace(0, 1, tile), np.linspace(-0.5, 0.5, tile), indexing="ij")
    grain = noise(tile, 1.0, 1.2, 31)
    for ti in range(TILES * TILES):
        sh = tones[ti // TILES] * (0.9 + 0.2 * ((ti % TILES) * 3 % 4) / 3)
        mid = np.exp(-(u / 0.018) ** 2)
        side = np.exp(-(((np.abs(u) * 2.2 - (v - 0.08) % 0.16 * 1.0) / 0.03) ** 2)) * (np.abs(u) > 0.02)
        vein = np.clip(mid + 0.6 * side, 0, 1)
        shade = (0.78 + 0.3 * v) * (1 - 0.25 * (np.abs(u) * 2) ** 3) * (0.94 + 0.06 * grain)
        c = sh[None, None, :] * shade[..., None]
        c = c * (1 - 0.35 * vein[..., None]) + np.array([0.9, 0.2, 0.15]) * 0.25 * vein[..., None] * sh[0]
        y0, x0 = (ti // TILES) * tile, (ti % TILES) * tile
        # Atlas rows are v (along the blade), columns u (across it).
        col[y0:y0 + tile, x0:x0 + tile] = c.transpose(0, 1, 2)
        height[y0:y0 + tile, x0:x0 + tile] = 0.5 - 0.25 * vein + 0.03 * grain
        rough[y0:y0 + tile, x0:x0 + tile] = 0.42 + 0.15 * vein + 0.04 * grain
    return (new_image("Fused_Leaf_Color", col), new_image("Fused_Leaf_Normal", normal_from_height(height, 2.5), True),
            new_image("Fused_Leaf_Roughness", np.repeat(np.clip(rough, 0, 1)[..., None], 3, 2), True))


def source_maps(o):
    """The sculpt's own glTF maps: base colour, packed metal(B)/rough(G), normal."""
    nt = o.active_material.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

    def image(sock):
        node = sock.links[0].from_node if sock.is_linked else None
        while node is not None and node.type != "TEX_IMAGE":
            node = next((i.links[0].from_node for i in node.inputs if i.is_linked), None)
        return node.image if node else None

    return image(bsdf.inputs["Base Color"]), image(bsdf.inputs["Roughness"]), image(bsdf.inputs["Normal"])


def proximity(o, targets, reach, name):
    """Per-vertex 1 -> 0 over `reach` from the nearest target surface, stored as a float attribute."""
    bvh = bvh_of(targets)
    co = verts(o)
    val = np.zeros(len(co))
    for i, c in enumerate(co):
        hit = bvh.find_nearest(Vector(c), reach)
        if hit[0] is not None:
            val[i] = 1 - hit[3] / reach
    attr = o.data.attributes.get(name) or o.data.attributes.new(name, "FLOAT", "POINT")
    attr.data.foreach_set("value", val.astype(np.float32))
    return val


def setup_cycles():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 1
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = kind
                prefs.get_devices()
                if any(d.type == kind for d in prefs.devices):
                    for d in prefs.devices:
                        d.use = d.type == kind
                    sc.cycles.device = "GPU"
                    print("BAKE device", kind, flush=True)
                    return
            except TypeError:
                continue
    except Exception as e:  # noqa: BLE001
        print("BAKE GPU unavailable:", e, flush=True)
    sc.cycles.device = "CPU"


def bake_fused(o, name, color, packed, scale, stain_amount, bark=None):
    """Bakes colour / roughness / metalness on the sculpt's own UVs from an emission network:
    original maps, bark creeping in where attribute `fuse` is high (her only), crimson sap stains
    under the sap runs (attribute `sap`) plus vertical streaks."""
    mat = bpy.data.materials.new(name + "_Bake")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    N, L = nt.nodes.new, nt.links.new
    out = N("ShaderNodeOutputMaterial")
    emit = N("ShaderNodeEmission")
    L(emit.outputs["Emission"], out.inputs["Surface"])
    uv = N("ShaderNodeUVMap")
    tex = N("ShaderNodeTexImage")
    tex.image = color
    L(uv.outputs["UV"], tex.inputs["Vector"])
    mr = N("ShaderNodeTexImage")
    mr.image = packed
    L(uv.outputs["UV"], mr.inputs["Vector"])
    sep = N("ShaderNodeSeparateColor")
    L(mr.outputs["Color"], sep.inputs["Color"])
    geo = N("ShaderNodeNewGeometry")

    def math_node(op, a, b=None, clamp=False):
        m = N("ShaderNodeMath")
        m.operation, m.use_clamp = op, clamp
        for sock, v in ((m.inputs[0], a), (m.inputs[1], b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                sock.default_value = v
            else:
                L(v, sock)
        return m.outputs[0]

    def smooth(x, lo, hi):
        m = N("ShaderNodeMapRange")
        m.interpolation_type = "SMOOTHSTEP"
        m.inputs["From Min"].default_value, m.inputs["From Max"].default_value = lo, hi
        L(x, m.inputs["Value"])
        return m.outputs["Result"]

    def attr(nm):
        a = N("ShaderNodeAttribute")
        a.attribute_name, a.attribute_type = nm, "GEOMETRY"
        return a.outputs["Fac"]

    # Vertical streaks: noise squeezed along Z.
    mp = N("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (40 / scale, 40 / scale, 2.5 / scale)
    L(geo.outputs["Position"], mp.inputs["Vector"])
    nz = N("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.0
    nz.inputs["Detail"].default_value = 3.0
    L(mp.outputs["Vector"], nz.inputs["Vector"])
    streak = smooth(nz.outputs["Fac"], 0.7 - 0.06 * stain_amount, 0.74 - 0.06 * stain_amount)
    stain = math_node("MAXIMUM", smooth(attr("sap"), 0.25, 0.75), math_node("MULTIPLY", streak, attr("streakzone")))
    rough_src, metal_src, col = sep.outputs["Green"], sep.outputs["Blue"], tex.outputs["Color"]
    if bark is not None:
        bmap = N("ShaderNodeMapping")
        bmap.inputs["Scale"].default_value = (1 / (0.18 * scale),) * 3
        L(geo.outputs["Position"], bmap.inputs["Vector"])
        btex = N("ShaderNodeTexImage")
        btex.image, btex.projection, btex.projection_blend = bark, "BOX", 0.3
        L(bmap.outputs["Vector"], btex.inputs["Vector"])
        edge = N("ShaderNodeTexNoise")
        edge.inputs["Scale"].default_value = 7.0 / scale
        edge.inputs["Detail"].default_value = 6.0
        L(geo.outputs["Position"], edge.inputs["Vector"])
        wobble = math_node("MULTIPLY", math_node("SUBTRACT", edge.outputs["Fac"], 0.5), 0.7)
        mask = smooth(math_node("ADD", attr("fuse"), wobble), 0.42, 0.58)
        mix = N("ShaderNodeMix")
        mix.data_type = "RGBA"
        L(mask, mix.inputs["Factor"])
        L(col, mix.inputs["A"])
        L(btex.outputs["Color"], mix.inputs["B"])
        col = mix.outputs["Result"]
        rough_src = math_node("ADD", math_node("MULTIPLY", rough_src, math_node("SUBTRACT", 1.0, mask)),
                              math_node("MULTIPLY", mask, 0.85))
        metal_src = math_node("MULTIPLY", metal_src, math_node("SUBTRACT", 1.0, mask))
    smix = N("ShaderNodeMix")
    smix.data_type = "RGBA"
    L(stain, smix.inputs["Factor"])
    L(col, smix.inputs["A"])
    smix.inputs["B"].default_value = (0.16, 0.0, 0.006, 1)
    col = smix.outputs["Result"]
    rough_src = math_node("ADD", math_node("MULTIPLY", rough_src, math_node("SUBTRACT", 1.0, stain)),
                          math_node("MULTIPLY", stain, 0.12))
    metal_src = math_node("MULTIPLY", metal_src, math_node("SUBTRACT", 1.0, stain))

    o.data.materials.clear()
    o.data.materials.append(mat)
    target = N("ShaderNodeTexImage")
    nt.nodes.active = target
    sc = bpy.context.scene
    sc.render.bake.margin = 16
    select([o])
    baked = {}
    for kind, src, nc in (("Color", col, False), ("Roughness", rough_src, True), ("Metalness", metal_src, True)):
        im = bpy.data.images.new(f"{name}_{kind}", TEX, TEX, alpha=False, is_data=nc)
        target.image = im
        L(src, emit.inputs["Color"])
        bpy.ops.object.bake(type="EMIT", margin=16, use_clear=True)
        baked[kind] = save_png(im, OUT / "maps" / f"{name}_{kind}.png")
        print("BAKED", name, kind, flush=True)
    return baked


# ------------------------------------------------------------------------------------------ 6. split
def split(o, prefix):
    me = o.data
    n = len(me.polygons)
    cen = np.empty(n * 3)
    me.polygons.foreach_get("center", cen)
    cen = cen.reshape(-1, 3)
    tri = np.array([len(p.vertices) - 2 for p in me.polygons])
    out = []
    for k, idx in enumerate(median_groups(cen, tri, CAP)):
        part = o.copy()
        part.data = me.copy()
        part.name = part.data.name = f"{prefix}_{k + 1:02d}"
        link(part)
        keep = np.zeros(n, bool)
        keep[idx] = True
        bm = bmesh.new()
        bm.from_mesh(part.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep[f.index]], context="FACES")
        bm.to_mesh(part.data)
        bm.free()
        out.append(part)
    bpy.data.objects.remove(o)
    return out


# ------------------------------------------------------------------------------------------ previews / export
def render(name, eye, look, lens=32):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT") if e in engines)
    sc.render.resolution_x, sc.render.resolution_y = 1100, 1100
    sc.view_settings.view_transform = "AgX"
    if "FusePreviewSun" not in bpy.data.objects:
        world = bpy.data.worlds.new("FusePreviewSky")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.3, 0.33, 0.4, 1)
        world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
        sc.world = world
        sun = bpy.data.objects.new("FusePreviewSun", bpy.data.lights.new("FusePreviewSun", "SUN"))
        sun.data.energy, sun.data.color = 4.5, (1.0, 0.84, 0.66)
        sun.rotation_euler = (0.95, 0.15, -0.5)
        link(sun)
        fill = bpy.data.objects.new("FusePreviewFill", bpy.data.lights.new("FusePreviewFill", "SUN"))
        fill.data.energy, fill.data.color = 1.2, (0.7, 0.8, 1.0)
        fill.rotation_euler = (1.2, 0, 2.6)
        link(fill)
        floor = bpy.data.objects.new("FusePreviewFloor", bpy.data.meshes.new("FusePreviewFloor"))
        fb = bmesh.new()
        bmesh.ops.create_grid(fb, x_segments=1, y_segments=1, size=3 * TH)
        fb.to_mesh(floor.data)
        fb.free()
        stone = bpy.data.materials.new("FusePreviewStone")
        stone.use_nodes = True
        stone.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.1, 0.1, 1)
        floor.data.materials.append(stone)
        link(floor)
        cam = bpy.data.objects.new("FusePreviewCam", bpy.data.cameras.new("FusePreviewCam"))
        cam.data.clip_end = 1000 * TH
        link(cam)
        sc.camera = cam
    cam = sc.camera
    cam.data.lens = lens
    cam.location = eye
    cam.rotation_euler = (look - eye).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)


def previews(tag):
    render(f"{tag}_front.png", Vector((0.35 * TH, -1.45 * TH, 0.32 * TH)), Vector((0, 0, 0.42 * TH)))
    render(f"{tag}_side.png", Vector((1.5 * TH, -0.35 * TH, 0.3 * TH)), Vector((0, 0, 0.42 * TH)))
    render(f"{tag}_her.png", Vector((0.55 * H, -2.4 * H, ZB + 0.75 * H)), Vector((0, 0, ZB + 0.55 * H)), lens=40)
    render(f"{tag}_seam.png", Vector((1.3 * H, -1.0 * H, ZB + 0.9 * H)), Vector((0, 0.1 * H, ZB + 0.6 * H)), lens=45)


def cleanup_previews():
    for name in ("FusePreviewSun", "FusePreviewFill", "FusePreviewCam", "FusePreviewFloor"):
        o = bpy.data.objects.get(name)
        if o:
            bpy.data.objects.remove(o)


def main():
    (OUT / "maps").mkdir(parents=True, exist_ok=True)
    woman, tree = bpy.data.objects["model"], bpy.data.objects["model.001"]
    for o in (woman, tree):
        own(o)
    place(woman, tree)
    if "--profile" in ARGS:  # the tree's footprint by height, to choose --sink
        co = verts(tree)
        for f in np.arange(0.0, 0.31, 0.02):
            band = co[np.abs(co[:, 2] - f * TH) < 0.01 * TH]
            r = np.linalg.norm(band[:, :2] - TRUNK, axis=1) if len(band) else np.zeros(1)
            print(f"PROFILE z={f:.2f}TH n={len(band)} r95={np.quantile(r, 0.95) / H:.2f}H rmax={r.max() / H:.2f}H", flush=True)
        return
    for o in (woman, tree):
        weld_and_smooth(o)
    w_col, w_mr, w_nrm = source_maps(woman)
    t_col, t_mr, t_nrm = source_maps(tree)
    bark = bark_maps(t_col)
    sap_tex = sap_maps()
    leaf_tex = leaf_maps()
    bark_mat = principled("Fused_Bark", bark[0], bark[2], bark[1])
    sap_mat = principled("Fused_Sap", sap_tex[0], sap_tex[2], sap_tex[1])
    leaf_mat = principled("Fused_Leaves", leaf_tex[0], leaf_tex[2], leaf_tex[1])
    roots = fuse_roots(woman, tree, bark_mat)
    runs = sap(woman, tree, roots, sap_mat)
    canopy = leaves(tree, leaf_mat)
    if PREVIEW:
        previews("preview")
        print("PREVIEW_OK", flush=True)
        return

    # Bark tints only her hem, where the roots hold it; the rest of her stays her own.
    fuse = 0.85 * proximity(woman, roots, 0.05 * H, "fuse")
    ground = np.clip(1 - (verts(woman)[:, 2] - ZB) / (0.1 * H), 0, 1) * 0.8
    woman.data.attributes["fuse"].data.foreach_set("value", np.maximum(fuse, ground).astype(np.float32))
    proximity(woman, runs, 0.012 * H, "sap")
    proximity(tree, runs, 0.008 * TH, "sap")
    for o, zone in ((woman, lambda co: (fuse > 0.25).astype(float)),
                    (tree, lambda co: ((co[:, 2] > 0.05 * TH) & (co[:, 2] < 0.8 * TH)).astype(float))):
        a = o.data.attributes.new("streakzone", "FLOAT", "POINT")
        a.data.foreach_set("value", zone(verts(o)).astype(np.float32))
    setup_cycles()
    wb = bake_fused(woman, "Fused_Woman", w_col, w_mr, H, 0.0, bark=bark[0])
    tb = bake_fused(tree, "Fused_Tree", t_col, t_mr, TH, 1.0)
    for o, b, nrm, name in ((woman, wb, w_nrm, "Fused_Woman"), (tree, tb, t_nrm, "Fused_Tree")):
        nrm_png = save_png(nrm, OUT / "maps" / f"{name}_Normal.png")
        o.data.materials.clear()
        o.data.materials.append(principled(name, b["Color"], b["Roughness"], nrm_png, b["Metalness"]))
    previews("fused")
    cleanup_previews()

    # Footprint for SanctuaryTitan.TreeSpan, in studs with her at STUD_FIGURE.
    tco = verts(tree)
    bed_c = np.array([0.0, BED * H])
    f = STUD_FIGURE / H
    span = {"Forward": float(np.linalg.norm(bed_c) * f),
            "Radius": float(np.linalg.norm(tco[tco[:, 2] < 0.02 * TH][:, :2] - bed_c, axis=1).max() * f),
            "TreeHeight": float(TH * f), "FigureHeight": STUD_FIGURE, "Raised": float(ZB * f)}

    parts = split(woman, "Titan_Figure") + split(tree, "Titan_Canopy") + roots + runs + canopy
    coll = bpy.data.collections.get("FusedTreeStatue") or bpy.data.collections.new("FusedTreeStatue")
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    for o in parts:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
        o.matrix_world = Matrix.Identity(4)
    counts = {o.name: tris(o) for o in parts}
    # The floor (z = 0) above the lowest point of the whole piece, in her heights (roots dive below it).
    span["FloorAboveBottom"] = float(-min(verts(o)[:, 2].min() for o in parts) / H)
    stats = {"herHeight_m": H, "treeHeight_m": TH, "ratio": RATIO, "parts": counts,
             "maxPartTris": max(counts.values()), "totalTris": sum(counts.values()), "partCount": len(parts),
             "treeSpanStuds": span}
    print("STATS", json.dumps({k: v for k, v in stats.items() if k != "parts"}), flush=True)
    if "--no-save" not in ARGS:
        if "--save-as" in ARGS:
            bpy.ops.wm.save_as_mainfile(filepath=str(Path(opt("--save-as", "")).resolve()))
        else:
            bpy.ops.wm.save_mainfile()
        print("SAVED", bpy.data.filepath, flush=True)

    # Export copies at her = FIG_UNITS (the .blend stays in metres).
    s = FIG_UNITS / H
    for o in parts:
        o.data.transform(Matrix.Scale(s, 4))
    select(parts)
    glb = OUT / "fused_tree_statue.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True)
    fbx = OUT / "fused_tree_statue.fbx"
    bpy.ops.export_scene.fbx(filepath=str(fbx), use_selection=True, object_types={"MESH"}, global_scale=1.0,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                             path_mode="COPY", embed_textures=True, mesh_smooth_type="OFF", use_tspace=True)
    stats["glbMB"] = round(glb.stat().st_size / 1e6, 1)
    stats["fbxMB"] = round(fbx.stat().st_size / 1e6, 1)
    (OUT / "stats.json").write_text(json.dumps(stats, indent=2))
    print("FUSE_OK", glb, len(parts), "parts", stats["glbMB"], "MB", flush=True)


main()

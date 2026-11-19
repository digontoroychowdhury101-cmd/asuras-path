"""Vesperhold gargoyles v2, hand-modelled (mac-52): Gargoyle_A (crouching winged beast gripping a moulded corbel) and
Gargoyle_B (emaciated long-necked waterspout grotesque leaning out from a wall block). Replaces the near-identical kit pair.

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/vesperhold/vesperhold_gargoyles.py -- [out_dir]
  default out_dir: assets/source/vesperhold/props    env: VESP_ONLY=Gargoyle_A,Gargoyle_B  VESP_GARG_MODE=bake|clay
  VESP_BAKE_SIZE=1024 (look iterations; final 2048)  VESP_RENDER_SAMPLES

Method: every organic role (Body, Head, Wings) is a signed-distance sculpt: round-cone chains along splines, ellipsoids,
thick membrane sheets, smooth unions and carves (mouth, eye sockets, water channel). The SAME field is polygonised twice with
surface nets: LOW (shipped; Newton-projected onto the exact field) and HIGH (fine cells + erosion pits + chipped edges).
Corbel/Block: clean low loft; high = voxel remesh + chips. vesp_bake bakes HIGH -> LOW per role (Color/Normal/Roughness/Metal
2048 on the CC0 Poly Haven rock_04 base). Never decimated; roles over the cap are split into <18k-tri chunks sharing one map set.
Exports <Piece>.glb (no images; vesp_embed embeds by material name) and merges ONLY these two entries into <out_dir>/manifest.json.
Units studs, pivot foot centre (z=0 under the corbel/block), creature faces -Y. The render/export helpers below are reused by
vesperhold_trees.py. Imported by vesperhold_props.py only to keep these manifest entries.
"""
import json
import math
import os
import shutil
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
import vesperhold_figures as FG  # noqa: E402
from vesperhold_figures import MB, fbm, log, nrm, spline, sst  # noqa: E402

ROOT = HERE.parents[2]
PIECES = ("Gargoyle_A", "Gargoyle_B")
BUILDER = "tools/blender/vesperhold/vesperhold_gargoyles.py (mac-52, SDF hand-sculpt, Cycles-baked)"
PI = math.pi
BIG = 1e3
TIPMIN = 0.024  # >= ~1.2 HIGH cells: thinner tips polygonise into detached fragments
MARG = 0.3  # evaluation margin (studs) around every primitive; > 2 cells + blend radius at every resolution used here


# ============================================================================================ SDF primitives -> (lo, hi, fn)
def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def rotx(deg):
    a = math.radians(deg)
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])


def sphere(c, r):
    c = np.asarray(c, float)
    return c - r, c + r, lambda P: np.linalg.norm(P - c, axis=1) - r


def ellip(c, r, R=None):
    c, r = np.asarray(c, float), np.asarray(r, float)
    R = np.eye(3) if R is None else np.asarray(R, float)
    ext = np.abs(R) @ r

    def fn(P):
        q = (P - c) @ R
        k0 = np.linalg.norm(q / r, axis=1)
        k1 = np.linalg.norm(q / (r * r), axis=1)
        return k0 * (k0 - 1) / np.maximum(k1, 1e-9)
    return c - ext, c + ext, fn


def _rcone(a, b, ra, rb):
    """iq round cone between spheres (a, ra) and (b, rb)."""
    ba = b - a
    l2 = float(ba @ ba)
    rr = ra - rb
    a2 = l2 - rr * rr
    if l2 < 1e-10 or a2 <= 1e-10:
        c, r = (a, ra) if ra >= rb else (b, rb)
        return lambda P: np.linalg.norm(P - c, axis=1) - r
    il2 = 1.0 / l2

    def fn(P):
        pa = P - a
        y = pa @ ba
        z = y - l2
        x2 = ((pa * l2 - y[:, None] * ba) ** 2).sum(1)
        y2, z2 = y * y * l2, z * z * l2
        k = np.sign(rr) * rr * rr * x2
        d = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - ra
        d = np.where(np.sign(y) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - ra, d)
        return np.where(np.sign(z) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - rb, d)
    return fn


def _multi(parts):
    """Hard union of sub-primitives [(lo, hi, fn)] as one primitive (no blend bulges between consecutive segments)."""
    los = np.array([p[0] for p in parts])
    his = np.array([p[1] for p in parts])

    def fn(P):
        D = np.full(len(P), BIG)
        for lo, hi, f in parts:
            m = np.all((P >= lo - MARG) & (P <= hi + MARG), 1)
            if m.any():
                D[m] = np.minimum(D[m], f(P[m]))
        return D
    return los.min(0), his.max(0), fn


def tube(pts, radii, step=0.1):
    """Round-cone chain along a Catmull-Rom spline through pts; radii spread along arc length. Tip radius ~0 = a point."""
    pts = np.asarray(pts, float)
    Lc = float(np.linalg.norm(np.diff(pts, axis=0), axis=1).sum())
    C, s, L, _ = spline(pts, max(4, int(Lc / step) + 1))
    R = np.maximum(np.interp(s, np.linspace(0, 1, len(radii)), radii), TIPMIN)  # sub-cell tips fray into floating bits
    parts = []
    for i in range(len(C) - 1):
        lo = np.minimum(C[i] - R[i], C[i + 1] - R[i + 1])
        hi = np.maximum(C[i] + R[i], C[i + 1] + R[i + 1])
        parts.append((lo, hi, _rcone(C[i], C[i + 1], R[i], R[i + 1])))
    return _multi(parts)


def _tri(a, b, c, t):
    ba, cb, ac = b - a, c - b, a - c
    nor = np.cross(ba, ac)
    nn = float(nor @ nor)
    e1, e2, e3 = np.cross(ba, nor), np.cross(cb, nor), np.cross(ac, nor)

    def seg2(e, p):
        return ((e[None] * np.clip((p @ e) / max(float(e @ e), 1e-12), 0, 1)[:, None] - p) ** 2).sum(1)

    def fn(P):
        pa, pb, pc = P - a, P - b, P - c
        s = np.sign(pa @ e1) + np.sign(pb @ e2) + np.sign(pc @ e3)
        d2 = np.where(s < 2, np.minimum(np.minimum(seg2(ba, pa), seg2(cb, pb)), seg2(ac, pc)), (pa @ nor) ** 2 / max(nn, 1e-12))
        return np.sqrt(d2) - t
    lo = np.minimum(np.minimum(a, b), c) - t
    hi = np.maximum(np.maximum(a, b), c) + t
    return lo, hi, fn


def sheet(G, t):
    """Thick sheet through a grid of points G (ns, nt, 3), half-thickness t."""
    parts = []
    for i in range(G.shape[0] - 1):
        for j in range(G.shape[1] - 1):
            a, b, c, d = G[i, j], G[i + 1, j], G[i + 1, j + 1], G[i, j + 1]
            for p, q, r in ((a, b, c), (a, c, d)):
                if np.linalg.norm(np.cross(q - p, r - p)) > 1e-8:  # the wrist row collapses to one point
                    parts.append(_tri(p, q, r, t))
    return _multi(parts)


def rbox(c, half, rr=0.05):
    c, half = np.asarray(c, float), np.asarray(half, float)

    def fn(P):
        q = np.abs(P - c) - half + rr
        return np.linalg.norm(np.maximum(q, 0), axis=1) + np.minimum(q.max(1), 0) - rr
    return c - half, c + half, fn


class Field:
    """Ordered SDF ops: union (smooth by k) or carve (smooth by k). Later ops act on the result of earlier ones."""

    def __init__(self):
        self.ops = []

    def u(self, prim, k=0.0):
        self.ops.append((False, k) + tuple(prim))

    def c(self, prim, k=0.0):
        self.ops.append((True, k) + tuple(prim))

    def bounds(self):
        u = [o for o in self.ops if not o[0]]
        return np.min([o[2] for o in u], 0), np.max([o[3] for o in u], 0)

    @staticmethod
    def _apply(D, P, carve, k, fn):
        d = fn(P)
        return -smin(-D, d, k) if carve else smin(D, d, k)

    def eval(self, P):
        D = np.full(len(P), BIG)
        for carve, k, lo, hi, fn in self.ops:
            m = np.all((P >= lo - MARG - k) & (P <= hi + MARG + k), 1)
            if m.any():
                D[m] = self._apply(D[m], P[m], carve, k, fn)
        return D

    def grid(self, h, pad=4):
        lo, hi = self.bounds()
        lo, hi = lo - pad * h, hi + pad * h
        shp = np.ceil((hi - lo) / h).astype(int) + 1
        D = np.full(shp, BIG, np.float32)
        for carve, k, plo, phi, fn in self.ops:
            a = np.clip(np.floor((plo - MARG - k - lo) / h).astype(int), 0, shp)
            b = np.clip(np.ceil((phi + MARG + k - lo) / h).astype(int) + 1, 0, shp)
            if np.any(b <= a):
                continue
            ys, zs = lo[1] + h * np.arange(a[1], b[1]), lo[2] + h * np.arange(a[2], b[2])
            step = max(1, int(1.2e6 // ((b[1] - a[1]) * (b[2] - a[2]))))
            for i0 in range(a[0], b[0], step):
                i1 = min(b[0], i0 + step)
                P = np.stack(np.meshgrid(lo[0] + h * np.arange(i0, i1), ys, zs, indexing="ij"), -1).reshape(-1, 3)
                blk = D[i0:i1, a[1]:b[1], a[2]:b[2]]
                D[i0:i1, a[1]:b[1], a[2]:b[2]] = self._apply(blk.reshape(-1).astype(np.float64), P, carve, k, fn).reshape(blk.shape)
        return D, lo


_OFF = np.array([(i, j, k) for i in (0, 1) for j in (0, 1) for k in (0, 1)])
_EDGES = [(a, b) for a in range(8) for b in range(a + 1, 8) if np.abs(_OFF[a] - _OFF[b]).sum() == 1]


def surface_nets(D, lo, h):
    """Naive surface nets: one vertex per sign-changing cell (mean of edge crossings), one quad per crossing grid edge."""
    S = D < 0
    nx, ny, nz = D.shape
    cs = [S[i:nx - 1 + i, j:ny - 1 + j, k:nz - 1 + k] for i, j, k in _OFF]
    act = np.logical_or.reduce(cs) & ~np.logical_and.reduce(cs)
    del cs
    ci = np.argwhere(act)
    cid = np.full(act.shape, -1, np.int32)
    cid[tuple(ci.T)] = np.arange(len(ci))
    vals = np.stack([D[ci[:, 0] + o[0], ci[:, 1] + o[1], ci[:, 2] + o[2]] for o in _OFF], 1).astype(np.float64)
    acc, cnt = np.zeros((len(ci), 3)), np.zeros(len(ci))
    for e1, e2 in _EDGES:
        v1, v2 = vals[:, e1], vals[:, e2]
        m = (v1 < 0) != (v2 < 0)
        t = v1[m] / (v1[m] - v2[m])
        acc[m] += _OFF[e1] + t[:, None] * (_OFF[e2] - _OFF[e1])
        cnt[m] += 1
    V = lo + h * (ci + acc / np.maximum(cnt, 1)[:, None])
    Q = []
    E = np.eye(3, dtype=int)
    for a in range(3):
        b, c = (a + 1) % 3, (a + 2) % 3
        s0 = [slice(None)] * 3
        s1 = [slice(None)] * 3
        s0[a], s1[a] = slice(0, -1), slice(1, None)
        idx = np.argwhere(S[tuple(s0)] != S[tuple(s1)])
        ok = (idx[:, b] >= 1) & (idx[:, b] <= D.shape[b] - 2) & (idx[:, c] >= 1) & (idx[:, c] <= D.shape[c] - 2)
        idx = idx[ok]
        q = np.stack([cid[tuple((idx - E[b] - E[c]).T)], cid[tuple((idx - E[c]).T)], cid[tuple(idx.T)], cid[tuple((idx - E[b]).T)]], 1)
        out = ~S[tuple(idx.T)]  # lower end outside -> outward normal is -a -> reverse the winding
        q[out] = q[out][:, ::-1]
        Q.append(q)
    Q = np.vstack(Q)
    assert (Q >= 0).all()
    return V, Q


def project(F, V, h, it=2):
    """Newton steps onto the exact field (LOW sits on the same surface the HIGH is built from)."""
    e = h * 0.25
    for _ in range(it):
        d = F.eval(V)
        g = np.stack([(F.eval(V + e * ax) - F.eval(V - e * ax)) / (2 * e) for ax in np.eye(3)], 1)
        st = d[:, None] * g / np.maximum((g * g).sum(1), 1e-6)[:, None]
        ln = np.linalg.norm(st, axis=1)
        st *= np.minimum(1, h / np.maximum(ln, 1e-9))[:, None]
        V = V - st
    return V


def mesh_from(name, V, Q, void=None, smooth=True):
    mb = MB()
    mb.V.append(np.asarray(V, float))
    mb.VD.append(np.zeros(len(V)) if void is None else np.asarray(void, float))
    mb.n = len(V)
    mb.Q.append(np.asarray(Q, np.int64))
    mb.MQ.append(np.zeros(len(Q), int))
    return mb.build(name, smooth=smooth)


def voids(V, spheres=(), segs=()):
    v = np.zeros(len(V))
    for c, r, s in spheres:
        v = np.maximum(v, s * sst(r, 0.55 * r, np.linalg.norm(V - np.asarray(c), axis=1)))
    for a, b, r, s in segs:
        a, b = np.asarray(a, float), np.asarray(b, float)
        ba = b - a
        t = np.clip((V - a) @ ba / (ba @ ba), 0, 1)
        d = np.linalg.norm(V - a - t[:, None] * ba, axis=1)
        v = np.maximum(v, s * sst(r, 0.55 * r, d))
    return v


def _co_nr(obj):
    me = obj.data
    n = len(me.vertices)
    co, nr = np.zeros(n * 3, np.float32), np.zeros(n * 3, np.float32)
    me.vertices.foreach_get("co", co)
    try:
        me.vertex_normals.foreach_get("vector", nr)
    except AttributeError:
        me.vertices.foreach_get("normal", nr)
    return co.reshape(-1, 3).astype(np.float64), nr.reshape(-1, 3).astype(np.float64)


def detail(obj, bump=0.02, pit=0.02, freq=2.6, seed=0):
    """Stone erosion on a HIGH: broad lumps + small pits."""
    co, nr = _co_nr(obj)
    d = bump * fbm(co * freq, 3, seed) - pit * sst(0.3, 0.62, fbm(co * freq * 3.3, 2, seed + 5) * 0.5 + 0.5)
    obj.data.vertices.foreach_set("co", (co + nr * d[:, None]).astype(np.float32).ravel())
    obj.data.update()


def ashlar(obj, course=1.15, block=1.7, w=0.05, depth=0.07, z0=0.45, z1=3.75):
    """Cut mortar joints (staggered ashlar courses) into the side faces of a HIGH wall block."""
    co, nr = _co_nr(obj)
    side = (np.abs(nr[:, 2]) < 0.5) & (co[:, 2] > z0) & (co[:, 2] < z1)
    along = np.where(np.abs(nr[:, 0]) > np.abs(nr[:, 1]), co[:, 1], co[:, 0])
    zc = (co[:, 2] - z0) / course
    row = np.floor(zc)
    hj = np.abs(zc - np.round(zc)) * course
    vj = np.abs(((along / block + 0.5 * (row % 2)) % 1.0) - 0.5) * block
    vj = 0.5 * block - vj
    g = np.maximum(sst(w * 1.6, w * 0.4, hj), sst(w * 1.6, w * 0.4, vj))
    co[side] -= nr[side] * (depth * g[side])[:, None]
    obj.data.vertices.foreach_set("co", co.astype(np.float32).ravel())
    obj.data.update()


def rect_loft(mb, prof, rc=0.04, nc=3):
    """Moulded block: rows (half_x, half_y, z) with rounded corners (rectangular square_lathe)."""
    rows = []
    for dx, dy, z in prof:
        pts = []
        for cx, cy, a0 in ((1, 1, 0), (-1, 1, PI / 2), (-1, -1, PI), (1, -1, 1.5 * PI)):
            for a in np.linspace(a0, a0 + PI / 2, nc):
                pts.append((cx * (dx - rc) + rc * math.cos(a), cy * (dy - rc) + rc * math.sin(a), z))
        rows.append(pts)
    P = np.array(rows)
    mb.grid(P, P * [1.0, 1.0, 0.0], closed_u=True, cap0=True, cap1=True)


# ============================================================================================ shared: render / export / manifest
def frame_cam(cam, lo, hi, az, ez, res, fill=0.9):
    """Level camera at eye height ez (verticals stay vertical); distance + lens shift fit the box lo..hi."""
    from mathutils import Vector
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    cor = np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
    a = math.radians(az)
    back, right = np.array([math.sin(a), -math.cos(a), 0.0]), np.array([math.cos(a), math.sin(a), 0.0])
    tgt = (lo + hi) / 2
    tx = math.tan(cam.data.angle / 2)
    ty = tx * res[1] / res[0]
    xr, f, zz = (cor - tgt) @ right, (cor - tgt) @ -back, cor[:, 2] - ez
    D = 0.5
    for _ in range(600):
        dep = D + f
        if dep.min() > 0.3:
            xs, ys = xr / dep, zz / dep
            if xs.max() - xs.min() <= 2 * tx * fill and ys.max() - ys.min() <= 2 * ty * fill:
                break
        D *= 1.02
    eye = np.array([tgt[0], tgt[1], 0.0]) + back * D
    eye[2] = ez
    cam.location = Vector(eye)
    cam.rotation_euler = Vector(-back).to_track_quat("-Z", "Y").to_euler()
    cam.data.shift_x = float((xs.max() + xs.min()) / 2 / (2 * tx))
    cam.data.shift_y = float((ys.max() + ys.min()) / 2 / (2 * tx))
    cam.data.clip_end = 8000.0


def render_set(name, objs, rdir, tag, man_xy=None, views=(("q34", -35.0), ("side", 90.0)), close=None, res=(1400, 1000), ez=5.0):
    """3/4 + profile at eye level with the 5-stud mannequin (dim overcast + warm rim: figures.setup_scene); optional close-up
    close = (az, lo, hi, ez)."""
    sc, cam, man = FG.setup_scene(int(os.environ.get("VESP_RENDER_SAMPLES", 64)))
    bpy.data.objects["Ground"].scale = (8.0, 8.0, 1.0)
    cam.data.sensor_fit = "AUTO"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.image_settings.file_format = "PNG"
    lo, hi = FG.bbox(objs)
    mx, my = man_xy if man_xy else (hi[0] + 1.6, (lo[1] + hi[1]) / 2)
    man.location = (mx, my, 0.0)
    lo2, hi2 = FG.bbox(objs + [man])
    out = []
    todo = [(v, az, lo2, hi2, ez) for v, az in views] + ([("close",) + tuple(close)] if close else [])
    for view, az, blo, bhi, e in todo:
        man.hide_render = view == "close"
        frame_cam(cam, blo, bhi, az, e, res)
        f = Path(rdir) / f"{name}_{tag}_{view}.png"
        sc.render.filepath = str(f)
        bpy.ops.render.render(write_still=True)
        out.append(f)
        log(f"render {f.name}")
    return out


def export_glb(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=False, export_image_format="NONE")


def finish(name, group, lows, highs, out, looks, rays, base, extra=None, builder=BUILDER, render_kw=None):
    """Bake HIGH -> LOW per role, split (never decimate), export GLB, render; returns (render files, manifest entry)."""
    import vesp_bake as VB
    maps = out / "maps"
    res = VB.bake(name, {r: (lows[r], [highs[r]]) for r in lows}, maps, size=2048, look=looks, log=log, rays=rays)
    hi_tris = {r: VB.tris(o) for r, o in highs.items()}
    for o in list(highs.values()):
        bpy.data.meshes.remove(o.data)
    subs, objs = {}, []
    for r, o in lows.items():
        for so in VB.split_cap(o, 17500):
            subs[so.name] = VB.tris(so)
            objs.append(so)
    glb = out / f"{name}.glb"
    export_glb(objs, glb)
    lo, hi = FG.bbox(objs)
    e = {"group": group, "sub_meshes": subs, "tris_total": sum(subs.values()),
         "size_studs_xyz": [round(float(hi[i] - lo[i]), 1) for i in range(3)],
         "bbox_min": [round(float(c), 2) for c in lo], "bbox_max": [round(float(c), 2) for c in hi],
         "materials": sorted({m.name for o in objs for m in o.data.materials}), "file": glb.name, "builder": builder,
         "no_decimation": True, "decimation": "none: roles over the cap are split into <18k-tri subs; LOW is a separate polygonisation",
         "map_resolution": {r: v["size"] for r, v in res.items()},
         "maps": {r: {k: Path(p).relative_to(out).as_posix() for k, p in v["maps"].items()} for r, v in res.items()},
         "base_layer": base, "high_poly_tris": hi_tris}
    e.update(extra or {})
    log(f"{name}: exported {glb.name} {glb.stat().st_size / 1e6:.1f} MB; subs {subs}")
    files = render_set(name, objs, out / "renders", "baked", **(render_kw or {}))
    return files, e


def merge_manifest(out, entries, title):
    mf = out / "manifest.json"
    m = json.loads(mf.read_text()) if mf.exists() else {"kit": title, "pieces": {}}
    m.setdefault("pieces", {}).update(entries)
    mf.write_text(json.dumps(m, indent=2))
    log("manifest merged:", list(entries))


def clay_mat():
    m = bpy.data.materials.new("Clay")
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (0.09, 0.09, 0.095, 1)
    p.inputs["Roughness"].default_value = 0.8
    return m


# ============================================================================================ anatomy helpers
def mirror(fn):
    for sx in (-1, 1):
        fn(sx)


def wing(F, sx, root, elbow, wrist, tips, rbone=(0.24, 0.16, 0.11), t=0.06, sag=0.26, billow=0.12, flank=None, tatter=None, rng=None):
    """Bat wing: arm bones, thumb claw, finger bones tapering to points, scalloped membrane panels between bones and to the flank."""
    F.u(tube([root, (np.asarray(root) + elbow) / 2 + [0, 0, 0.12], elbow], [rbone[0], 0.85 * rbone[0], rbone[1]]), 0.05)
    F.u(tube([elbow, (np.asarray(elbow) + wrist) / 2 + [0, -0.05, 0.08], wrist], [rbone[1], 0.85 * rbone[1], rbone[2]]), 0.04)
    F.u(sphere(wrist, rbone[2] * 1.35), 0.04)
    w = np.asarray(wrist, float)
    F.u(tube([w, w + [0.0, -0.22, 0.3], w + [-sx * 0.1, -0.42, 0.42]], [0.085, 0.05, 0.004]), 0.03)  # thumb claw
    bones = []
    for tp in tips:
        tp = np.asarray(tp, float)
        mid = w + (tp - w) * 0.5 + np.array([0, 0.12, 0.08])
        F.u(tube([w, mid, tp], [rbone[2] * 0.85, rbone[2] * 0.55, 0.012]), 0.03)
        F.u(sphere(mid, rbone[2] * 0.7), 0.03)  # knuckle
        bones.append(spline(np.array([w, mid, tp]), 24)[0])
    if flank is not None:
        bones.append(spline(np.asarray(flank, float), 24)[0])
    for Ba, Bb in zip(bones, bones[1:]):
        ns, nt = 8, 11
        S, U = np.linspace(0, 1, ns), np.linspace(0, 1, nt)
        tm = 1 - sag * np.sin(PI * S)
        nb = nrm(np.cross(Ba[-1] - w, Bb[-1] - w))
        nb = nb if nb[1] > 0 else -nb
        G = np.zeros((ns, nt, 3))
        for i, s_ in enumerate(S):
            ui = U * tm[i] * (len(Ba) - 1)
            pa = np.stack([np.interp(ui, np.arange(len(Ba)), Ba[:, k]) for k in range(3)], 1)
            pb = np.stack([np.interp(ui, np.arange(len(Bb)), Bb[:, k]) for k in range(3)], 1)
            G[i] = (1 - s_) * pa + s_ * pb + billow * nb * (math.sin(PI * s_) * np.sin(PI * U * 0.95))[:, None]
        F.u(sheet(G, t), 0.025)
        if tatter:
            for _ in range(tatter):
                s_, u_ = rng.uniform(0.2, 0.8), rng.uniform(0.8, 1.0)  # edge notches only: inner holes cut islands
                i, j = int(s_ * (ns - 1)), int(u_ * (nt - 1))
                F.c(sphere(G[i, j] + rng.normal(0, 0.05, 3), rng.uniform(0.07, 0.14)), 0.02)


def claws(F, base, d1, d2, r=0.07):
    """Hooked claw from base along d1 then curling to d2, tapering to a point."""
    b = np.asarray(base, float)
    F.u(tube([b, b + np.asarray(d1), b + np.asarray(d1) + np.asarray(d2)], [r, r * 0.62, 0.005]), 0.02)


def teeth(F, c, r, R, up, ts, lens, rad=0.05, xf=0.74):
    """Teeth rooted on a jaw ellipsoid's rim (local frame R), pointing along +-local z; ts = local y fractions (front < 0)."""
    c, r, R = np.asarray(c, float), np.asarray(r, float), np.asarray(R, float)
    d = R[:, 2] * up
    for t, L in zip(ts, lens):
        f = math.sqrt(max(0.0, 1 - t * t))
        for sx in (-1, 1):
            base = c + R @ np.array([sx * r[0] * xf * f, t * r[1], up * r[2] * 0.45])
            F.u(tube([base - d * 0.04, base + d * (L * 0.6) - R[:, 1] * 0.02, base + d * L - R[:, 1] * 0.05], [rad * (1.5 + L), rad * 0.75 * (1 + L), 0.0]), 0.015)


# ============================================================================================ Gargoyle_A: crouching winged beast on a corbel
def spec_A():
    body, head, wings = Field(), Field(), Field()
    zt = 2.2  # corbel top
    torso = np.array([(0, 1.15, 3.2), (0, 0.45, 3.78), (0, -0.35, 4.3), (0, -0.95, 4.45)])
    tr = [0.9, 0.84, 0.95, 0.8]
    body.u(tube(torso, tr))
    body.u(ellip((0, -0.55, 4.08), (1.0, 0.85, 0.92)), 0.25)  # chest
    body.u(ellip((0, 0.2, 3.4), (0.66, 0.85, 0.6)), 0.2)  # belly
    mirror(lambda sx: body.u(ellip((sx * 0.48, -0.98, 4.12), (0.42, 0.34, 0.46), rotx(-20)), 0.14))  # pectorals

    def side(sx):
        body.u(ellip((sx * 0.6, -0.12, 4.78), (0.48, 0.7, 0.3), rotx(-12)), 0.18)  # shoulder blade
        body.u(ellip((sx * 0.78, 0.95, 3.05), (0.62, 0.9, 0.78)), 0.2)  # haunch
        body.u(tube([(sx * 0.85, 1.0, 3.2), (sx * 1.12, 0.45, 3.0), (sx * 1.15, 0.05, 2.86)], [0.5, 0.44, 0.36]), 0.12)  # thigh
        body.u(tube([(sx * 1.15, 0.05, 2.86), (sx * 1.1, 0.7, 2.62), (sx * 1.03, 1.25, 2.46)], [0.33, 0.27, 0.22]), 0.08)  # shin
        body.u(tube([(sx * 1.03, 1.25, 2.46), (sx * 1.0, 0.8, 2.36), (sx * 1.0, 0.45, 2.35)], [0.22, 0.2, 0.21]), 0.06)  # metatarsus
        for dx in (-0.17, 0.0, 0.17):
            x = sx * 1.0 + dx
            body.u(tube([(sx * 1.0 + dx * 0.5, 0.45, 2.34), (x, 0.12, 2.32), (x + dx * 0.15, -0.08, 2.3)], [0.11, 0.09, 0.075]), 0.04)
            claws(body, (x + dx * 0.15, -0.08, 2.3), (0, -0.2, -0.02), (0, -0.12, -0.11))
        body.u(tube([(sx * 0.8, -0.75, 4.35), (sx * 1.2, -0.95, 3.75), (sx * 1.25, -1.15, 3.35)], [0.44, 0.38, 0.32]), 0.12)  # upper arm
        body.u(tube([(sx * 1.25, -1.15, 3.35), (sx * 1.12, -1.6, 2.9), (sx * 1.0, -2.0, 2.56)], [0.31, 0.26, 0.24]), 0.08)  # forearm
        body.u(ellip((sx * 0.98, -2.2, 2.42), (0.3, 0.28, 0.17)), 0.08)  # hand
        for dx in (-0.22, -0.075, 0.075, 0.22):
            x = sx * 0.98 + dx
            body.u(tube([(sx * 0.98 + dx * 0.6, -2.2, 2.42), (x, -2.42, 2.37), (x, -2.62, 2.26), (x, -2.66, 2.05)], [0.1, 0.095, 0.085, 0.075]), 0.04)
            claws(body, (x, -2.66, 2.06), (0, 0.01, -0.2), (0, 0.1, -0.16))
    mirror(side)
    # tail resting on the corbel top, curling round the right hind foot
    tp = np.array([(0, 1.7, 3.1), (0, 2.2, 2.62), (0.7, 2.35, 0), (1.55, 1.85, 0), (1.95, 0.9, 0), (1.85, -0.1, 0), (1.55, -0.75, 0)], float)
    trr = np.array([0.36, 0.3, 0.24, 0.19, 0.15, 0.11, 0.015])
    tp[2:, 2] = zt + trr[2:] * 0.95
    body.u(tube(tp, trr), 0.1)
    # vertebra ridge: knobs along the hunched spine (computed from the torso spline)
    C, s, _, _ = spline(torso, 40)
    R = np.interp(s, np.linspace(0, 1, len(tr)), tr)
    body.u(tube(C[3:39] + np.array([0, 0, 1.0]) * (R[3:39, None] * 0.9), [0.13, 0.15, 0.1]), 0.08)  # spine ridge
    for i in range(14, 27, 3):  # gaunt ribs under the hide on both flanks (the torso read as a smooth sack)
        for sx in (-1, 1):
            arc = [C[i] + np.array([sx * R[i] * 0.99 * math.cos(a), 0.12 * (1 - math.sin(a)), R[i] * 0.99 * math.sin(a)])
                   for a in np.linspace(math.radians(55), math.radians(-40), 7)]
            body.u(tube(arc, [0.07, 0.08, 0.06]), 0.09)
    for i in range(3, 39, 2):
        top = C[i] + np.array([0, 0, R[i] * 0.97])
        n = nrm(np.array([0, 0.45, 1.0]))
        body.u(tube([top - n * 0.08, top + n * (0.3 + 0.12 * math.sin(PI * i / 40))], [0.17, 0.03]), 0.05)
    # ---- head
    head.u(tube([(0, -0.6, 4.55), (0, -1.2, 4.92), (0, -1.65, 5.1)], [0.62, 0.55, 0.48]))
    head.u(ellip((0, -1.9, 5.2), (0.62, 0.74, 0.42)), 0.15)  # cranium: low and flat (a dome reads cat-like)
    head.u(tube([(0, -2.45, 5.48), (0, -1.9, 5.66), (0, -1.25, 5.5)], [0.07, 0.1, 0.05]), 0.08)  # sagittal crest
    head.u(ellip((0, -2.62, 5.18), (0.4, 0.62, 0.27), rotx(12)), 0.12)  # snout
    head.u(ellip((0, -2.45, 4.72), (0.34, 0.55, 0.13), rotx(28)), 0.1)  # open jaw
    head.c(ellip((0, -2.5, 4.88), (0.28, 0.5, 0.1), rotx(14)), 0.05)  # mouth cavity
    mirror(lambda sx: head.u(ellip((sx * 0.42, -2.2, 5.12), (0.2, 0.36, 0.2)), 0.1))  # cheeks
    mirror(lambda sx: head.u(tube([(sx * 0.04, -2.72, 5.3), (sx * 0.32, -2.62, 5.46), (sx * 0.62, -2.3, 5.56)], [0.15, 0.19, 0.12]), 0.07))  # heavy V scowl brow
    mirror(lambda sx: head.c(sphere((sx * 0.3, -2.5, 5.27), 0.155), 0.03))  # deep eye sockets under the brow
    mirror(lambda sx: head.u(sphere((sx * 0.3, -2.38, 5.25), 0.06), 0.01))  # small eyes sunk deep inside
    for y, z in ((-2.58, 5.41), (-2.7, 5.38), (-2.82, 5.34)):  # snarl wrinkles on the muzzle
        head.u(tube([(-0.27, y + 0.03, z - 0.08), (0, y, z), (0.27, y + 0.03, z - 0.08)], [0.035, 0.05, 0.035]), 0.04)
    mirror(lambda sx: head.c(ellip((sx * 0.11, -3.12, 5.1), (0.07, 0.04, 0.022), rotx(-30)), 0.012))  # nostril slits (dots read as eyes)
    teeth(head, (0, -2.62, 5.18), (0.4, 0.62, 0.27), rotx(12), -1, (-0.8, -0.66, -0.5, -0.36, -0.22), (0.16, 0.34, 0.14, 0.12, 0.1))
    teeth(head, (0, -2.45, 4.72), (0.34, 0.55, 0.13), rotx(28), 1, (-0.82, -0.66, -0.5, -0.34), (0.14, 0.28, 0.12, 0.1))
    mirror(lambda sx: head.u(tube([(sx * 0.3, -1.85, 5.65), (sx * 0.55, -1.6, 6.2), (sx * 0.8, -1.05, 6.55), (sx * 1.0, -0.45, 6.5),
                                    (sx * 1.08, -0.1, 6.15), (sx * 0.98, -0.3, 5.92)], [0.21, 0.17, 0.13, 0.09, 0.05, 0.012]), 0.06))  # horns
    mirror(lambda sx: head.u(tube([(sx * 0.5, -1.75, 5.46), (sx * 0.68, -1.5, 5.62), (sx * 0.84, -1.3, 5.7)], [0.13, 0.07, 0.008]), 0.05))  # ears
    # ---- wings: half-open, raised and swept back
    rng = np.random.default_rng(3)

    def wg(sx):
        wing(wings, sx, (sx * 0.6, -0.1, 4.92), (sx * 1.35, 0.45, 5.75), (sx * 1.95, 0.85, 6.95),
             [(sx * 3.25, 1.35, 6.75), (sx * 3.4, 1.6, 5.25), (sx * 2.85, 1.7, 4.25), (sx * 2.05, 1.5, 3.85)],
             flank=[(sx * 1.95, 0.85, 6.95), (sx * 1.35, 0.45, 5.75), (sx * 1.0, 0.4, 4.85), (sx * 0.95, 0.95, 3.75)], rng=rng)
    mirror(wg)
    hvoid = dict(spheres=[((0.3, -2.47, 5.3), 0.17, 0.9), ((-0.3, -2.47, 5.3), 0.17, 0.9), ((0, -2.42, 4.86), 0.34, 0.8)])
    prof = [(1.5, 1.8, 0.0), (1.5, 1.8, 0.22), (1.62, 1.92, 0.28), (1.62, 1.92, 0.42), (1.5, 1.8, 0.48), (1.5, 1.8, 1.05), (1.56, 1.86, 1.1),
            (1.62, 1.92, 1.2), (1.76, 2.06, 1.36), (1.92, 2.22, 1.5), (2.0, 2.3, 1.6), (2.06, 2.36, 1.68), (2.2, 2.5, 1.75), (2.2, 2.5, 2.14),
            (2.15, 2.45, 2.2)]
    return {"Corbel": dict(loft=prof),
            "Body": dict(field=body, lo=0.065, hi=0.024),
            "Head": dict(field=head, lo=0.042, hi=0.018, void=hvoid),
            "Wings": dict(field=wings, lo=0.05, hi=0.022)}, dict(man_xy=(3.6, 3.6), views=(("q34", 35.0), ("side", 90.0)), close=(30.0, (-1.2, -3.4, 4.3), (1.2, -1.0, 6.9), 5.6))


# ============================================================================================ Gargoyle_B: emaciated waterspout
def spec_B():
    body, head, wings = Field(), Field(), Field()
    zt, yf = 4.4, -1.75  # block top, cornice front face

    def side(sx):
        # hind legs crouched on the block top
        body.u(tube([(sx * 0.55, 0.75, 5.25), (sx * 0.85, 0.2, 5.15), (sx * 0.95, -0.25, 5.05)], [0.36, 0.3, 0.26]), 0.1)
        body.u(tube([(sx * 0.95, -0.25, 5.05), (sx * 0.92, 0.45, 4.88), (sx * 0.85, 1.05, 4.75)], [0.22, 0.18, 0.15]), 0.06)
        body.u(tube([(sx * 0.85, 1.05, 4.75), (sx * 0.8, 0.7, 4.56), (sx * 0.78, 0.45, 4.53)], [0.14, 0.13, 0.13]), 0.05)
        for dx in (-0.14, 0.0, 0.14):
            x = sx * 0.78 + dx
            body.u(tube([(sx * 0.78 + dx * 0.4, 0.45, 4.52), (x, 0.15, 4.48), (x + dx * 0.2, -0.08, 4.47)], [0.075, 0.065, 0.055]), 0.03)
            claws(body, (x + dx * 0.2, -0.08, 4.47), (0, -0.16, -0.01), (0, -0.1, -0.08), r=0.05)
        # ribs round the narrow cage
        for i in range(7):
            yi = -0.85 - i * 0.2
            f = math.sqrt(max(0.05, 1 - ((yi + 1.45) / 1.0) ** 2))
            arc = []
            for a in np.linspace(math.radians(80), math.radians(-62), 9):
                arc.append((sx * (0.6 * f + 0.03) * math.cos(a), yi - 0.18 * (1 - math.sin(a)) * 0.5, 5.3 + (0.58 * f + 0.03) * math.sin(a)))
            body.u(tube(arc, [0.06, 0.055, 0.045]), 0.035)
        body.u(ellip((sx * 0.42, -2.2, 5.25), (0.3, 0.35, 0.3)), 0.12)  # shoulder
        # thin arms bracing on the cornice edge, elbows up and out
        body.u(tube([(sx * 0.5, -2.3, 5.12), (sx * 0.85, -2.25, 5.0), (sx * 1.05, -2.05, 4.86)], [0.2, 0.17, 0.15]), 0.06)
        body.u(tube([(sx * 1.05, -2.05, 4.86), (sx * 0.95, -1.8, 4.7), (sx * 0.85, -1.58, 4.56)], [0.14, 0.12, 0.1]), 0.04)
        body.u(tube([(sx * 1.08, -2.0, 4.95), (sx * 0.9, -1.7, 4.68)], [0.045, 0.04]), 0.02)  # sinew
        body.u(ellip((sx * 0.85, -1.52, 4.5), (0.17, 0.2, 0.08)), 0.05)  # hand
        for dx in (-0.15, -0.05, 0.05, 0.15):
            x = sx * 0.85 + dx
            body.u(tube([(sx * 0.85 + dx * 0.5, -1.52, 4.5), (x, -1.72, 4.49), (x, -1.86, 4.42), (x, -1.88, 4.18)], [0.065, 0.06, 0.058, 0.055]), 0.03)
            claws(body, (x, -1.88, 4.2), (0, 0.0, -0.17), (0, 0.08, -0.13), r=0.05)
    body.u(ellip((0, 0.8, 5.4), (0.55, 0.55, 0.42)))  # pelvis
    body.u(tube([(0, 0.8, 5.45), (0, 0.0, 5.5), (0, -0.8, 5.4)], [0.42, 0.33, 0.4]), 0.15)  # sunken waist
    body.u(ellip((0, -1.45, 5.3), (0.56, 0.95, 0.54)), 0.15)  # rib cage
    body.u(ellip((0, -2.15, 5.08), (0.45, 0.4, 0.45)), 0.15)  # chest
    mirror(side)
    sp = np.array([(0, 1.05, 5.8), (0, 0.0, 5.88), (0, -1.4, 5.9), (0, -2.3, 5.6)])
    body.u(tube(sp, [0.1, 0.1, 0.1, 0.1]), 0.06)
    for p in spline(sp, 16)[0]:
        body.u(sphere(p + [0, 0, 0.05], 0.12), 0.05)  # vertebra knobs
    tl = np.array([(0, 1.25, 5.3), (0, 1.75, 4.85), (0.5, 1.6, 4.5), (0.95, 1.1, 4.5)])  # tail draped over the back of the block
    body.u(tube(tl, [0.24, 0.18, 0.12, 0.02]), 0.08)
    # ---- neck + head
    neck = np.array([(0, -2.15, 5.3), (0, -3.4, 5.18), (0, -4.8, 4.98), (0, -6.2, 4.88), (0, -7.35, 4.95), (0, -7.85, 5.0)])
    nr_ = [0.5, 0.36, 0.31, 0.29, 0.31, 0.34]
    head.u(tube(neck, nr_))
    mirror(lambda sx: head.u(tube([(sx * 0.22, -2.4, 5.0), (sx * 0.2, -4.8, 4.78), (sx * 0.18, -7.2, 4.75)], [0.09, 0.07, 0.08]), 0.06))  # tendons
    C, s, _, _ = spline(neck, 30)
    R = np.interp(s, np.linspace(0, 1, len(nr_)), nr_)
    for i in range(3, 27, 4):  # sparse: a dense row read as scales
        mirror(lambda sx, i=i: head.u(sphere(C[i] + [sx * 0.15, 0, R[i] * 0.84], 0.07), 0.05))  # paired vertebra knobs
    head.u(ellip((0, -8.0, 5.12), (0.42, 0.55, 0.4)), 0.15)  # cranium
    head.u(ellip((0, -8.65, 5.18), (0.3, 0.6, 0.19), rotx(-18)), 0.1)  # upper jaw, tipped up: screaming
    head.u(ellip((0, -8.5, 4.58), (0.28, 0.6, 0.13), rotx(35)), 0.1)  # lower jaw, dropped
    head.c(ellip((0, -8.55, 4.88), (0.23, 0.62, 0.19), rotx(8)), 0.04)  # maw
    mirror(lambda sx: head.u(ellip((sx * 0.33, -8.2, 4.98), (0.12, 0.3, 0.12)), 0.06))  # cheekbones
    mirror(lambda sx: head.c(sphere((sx * 0.45, -7.85, 5.15), 0.12), 0.08))  # sunken temples
    mirror(lambda sx: head.c(sphere((sx * 0.22, -8.42, 5.22), 0.13), 0.03))  # empty eye sockets (an eyeball read cartoonish)
    mirror(lambda sx: head.u(tube([(sx * 0.07, -8.6, 5.36), (sx * 0.24, -8.5, 5.42), (sx * 0.4, -8.22, 5.36)], [0.06, 0.08, 0.05]), 0.05))  # brow ridge
    mirror(lambda sx: head.u(tube([(sx * 0.22, -7.85, 5.42), (sx * 0.38, -7.35, 5.72), (sx * 0.42, -6.75, 5.75), (sx * 0.36, -6.35, 5.55)],
                                   [0.1, 0.08, 0.05, 0.008]), 0.04))  # swept-back horns
    teeth(head, (0, -8.65, 5.18), (0.3, 0.6, 0.19), rotx(-18), -1, (-0.86, -0.72, -0.58, -0.44, -0.3, -0.16), (0.14, 0.24, 0.13, 0.12, 0.11, 0.09), rad=0.05)
    teeth(head, (0, -8.5, 4.58), (0.28, 0.6, 0.13), rotx(35), 1, (-0.84, -0.7, -0.56, -0.42, -0.28), (0.12, 0.22, 0.11, 0.1, 0.09), rad=0.05)
    # water channel: open trough along the back of the neck + a bore through the throat into the maw
    trough = np.array([(0, -2.3, 5.8), (0, -3.4, 5.54), (0, -4.8, 5.29), (0, -6.2, 5.17), (0, -7.3, 5.26)])
    head.c(tube(trough, [0.11, 0.1, 0.1, 0.1, 0.1]), 0.03)
    head.c(tube([(0, -6.6, 4.9), (0, -7.6, 4.92), (0, -8.4, 4.85)], [0.12, 0.14, 0.16]), 0.03)
    rng = np.random.default_rng(11)

    def wg(sx):  # small tattered wings folded along the back
        wing(wings, sx, (sx * 0.38, -1.7, 5.72), (sx * 0.85, -1.05, 6.35), (sx * 1.12, -0.25, 6.55),
             [(sx * 1.75, 0.45, 6.05), (sx * 1.55, 0.95, 5.5), (sx * 1.0, 0.8, 5.25)], rbone=(0.16, 0.11, 0.08), t=0.05, sag=0.38,
             billow=0.08, flank=[(sx * 1.12, -0.25, 6.55), (sx * 0.85, -1.05, 6.35), (sx * 0.5, -0.4, 5.85)], tatter=2, rng=rng)
    mirror(wg)
    hvoid = dict(spheres=[((0.22, -8.4, 5.24), 0.13, 0.85), ((-0.22, -8.4, 5.24), 0.13, 0.85), ((0, -8.55, 4.86), 0.3, 0.8)],
                 segs=[((0, -6.6, 4.9), (0, -8.4, 4.85), 0.22, 0.9)])
    prof = [(2.12, 1.62, 0.0), (2.12, 1.62, 0.3), (2.0, 1.5, 0.38), (2.0, 1.5, 3.8), (2.08, 1.58, 3.88), (2.16, 1.66, 3.96), (2.24, 1.74, 4.08),
            (2.25, 1.75, 4.36), (2.21, 1.71, 4.4)]
    return {"Block": dict(loft=prof),
            "Body": dict(field=body, lo=0.05, hi=0.02),
            "Head": dict(field=head, lo=0.045, hi=0.018, void=hvoid),
            "Wings": dict(field=wings, lo=0.04, hi=0.02)}, dict(man_xy=(3.0, 3.0), views=(("q34", 35.0), ("side", 90.0)), close=(35.0, (-0.8, -9.4, 4.0), (0.8, -6.6, 6.0), 5.0))


SPEC = {"Gargoyle_A": spec_A, "Gargoyle_B": spec_B}


# ============================================================================================ build
def gargoyle(name, out, mode):
    import vesp_bake as VB
    bpy.ops.wm.read_factory_settings(use_empty=True)
    roles, rkw = SPEC[name]()
    lows, highs = {}, {}
    for i, (role, R) in enumerate(roles.items()):
        t = time.time()
        if "loft" in R:
            mb = MB()
            rect_loft(mb, R["loft"])
            lo = mb.build(f"{name}__{role}", smooth=False)
            hi = lo.copy()
            hi.data = lo.data.copy()
            hi.name = f"HI_{name}__{role}"
            bpy.context.scene.collection.objects.link(hi)
            FG.remesh_hi(hi, 0.03)
            if role == "Block":
                ashlar(hi)
            FG.weather(hi, chip=0.045, erode=0.004, freq=1.6, seed=31 + i, edge_pct=(85, 99.5))
            detail(hi, bump=0.006, pit=0.012, freq=3.0, seed=i)
        else:
            F = R["field"]
            V, Q = surface_nets(*F.grid(R["lo"]), R["lo"])
            V = project(F, V, R["lo"])
            lo = mesh_from(f"{name}__{role}", V, Q)
            V, Q = surface_nets(*F.grid(R["hi"]), R["hi"])
            vd = voids(V, **R["void"]) if R.get("void") else None
            hi = mesh_from(f"HI_{name}__{role}", V, Q, vd)
            co0, nr0 = _co_nr(hi)
            thin = sst(-0.04, -0.012, F.eval(co0 - nr0 * 0.05))  # 1 in teeth/claws/horn tips: chips there fray them into bits
            detail(hi, bump=0.005, pit=0.008, freq=3.2, seed=7 + i)
            FG.weather(hi, chip=0.012, erode=0.002, freq=3.0, seed=17 + i, edge_pct=(94, 99.7))
            co1, _ = _co_nr(hi)
            hi.data.vertices.foreach_set("co", (co0 + (co1 - co0) * (1 - thin)[:, None]).astype(np.float32).ravel())
            hi.data.update()
        FG.weighted_normals(lo)
        lows[role], highs[role] = lo, hi
        log(f"{name}__{role}: low {VB.tris(lo)} tris, high {VB.tris(hi)} tris  {time.time() - t:.1f}s")
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    if mode == "clay":
        cm = clay_mat()
        for o in highs.values():
            o.data.materials.append(cm)
        for o in lows.values():
            o.hide_render = True
        return render_set(name, list(highs.values()), rdir, "clayhi", **rkw), None
    maps = out / "maps"
    src = VB.stone_source("Vesp_Weathered", maps)
    stone = VB.hi_material("Hi_Stone", src, tile=3.0)
    for o in highs.values():
        o.data.materials.append(stone)
    for o in lows.values():
        VB.unwrap(o)
    look = VB.Look(base=0.12, grime=0.4, frost=0.5, streak_dark=0.26, sat=0.4)  # sat<1: rock_04 read brown, target soot-black
    rays = {r: ((0.1, 0.25) if "loft" in R else (0.06, 0.16)) for r, R in roles.items()}
    return finish(name, "F", lows, highs, out, {"*": look}, rays, src["source"], render_kw=rkw)


def keep_in_props_manifest(K):
    """vesperhold_props.py imports this module and no longer builds the gargoyles: re-seed its manifest with our entries so a
    props run (which rewrites manifest.json from K.manifest) keeps them."""
    mf = Path(K.OUT) / "manifest.json"
    if mf.exists():
        old = json.loads(mf.read_text()).get("pieces", {})
        for n in PIECES:
            if n in old and old[n].get("builder", "").startswith("tools/blender/vesperhold/vesperhold_gargoyles.py"):
                K.manifest["pieces"].setdefault(n, old[n])


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/vesperhold/props").resolve()
    only = [s for s in os.environ.get("VESP_ONLY", "").split(",") if s] or list(PIECES)
    mode = os.environ.get("VESP_GARG_MODE", "bake")
    tag = "clayhi" if mode == "clay" else "baked"
    rows, entries = [], {}
    for name in PIECES:
        if name not in only:
            old = sorted((out / "renders").glob(f"{name}_{tag}_*.png"))
            if old:
                rows.append(old)
            continue
        files, e = gargoyle(name, out, mode)
        rows.append(files)
        if e:
            entries[name] = e
    if entries:
        merge_manifest(out, entries, "Vesperhold props (group F)")
    if rows:
        dst = out / "renders" / f"F2_gargoyles_v2_{tag}.jpg"
        FG.sheet(rows, dst)
        log("sheet", dst)
        if mode != "clay":
            v2 = Path(os.environ.get("VESP_SHEET_DIR", ROOT / "outputs/vesperhold/kit-renders-v2"))
            v2.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dst, v2 / os.environ.get("VESP_SHEET_NAME", "F2_gargoyles_v2.jpg"))


if __name__ == "__main__":
    main()
elif "vesperhold_kit" in sys.modules:  # imported by vesperhold_props.py
    keep_in_props_manifest(sys.modules["vesperhold_kit"])

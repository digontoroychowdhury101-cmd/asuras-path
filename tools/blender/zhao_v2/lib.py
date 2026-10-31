"""Geometry helpers for General Zhao v2.

Units are studs at scale 1. Blender Z is Roblox +Y, Blender +Y is Roblox -Z (the character faces +Y),
Blender +X is the character's right. Every helper builds real closed forms into a Piece (one bmesh per
output object) and tags faces with a material name; nothing is painted onto a single lump.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

V = Vector


class Piece:
    """One output mesh object: a bmesh plus its material list and a 0..1 'detail' UV per grid."""

    def __init__(self, name, bone, role=None):
        self.name, self.bone, self.role = name, bone, role
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("detail")
        self.mats = []

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    # -- core: a grid of points (rows along v, columns along u) -----------------------------------------
    def grid(self, P, mat, closed_u=False, cap0=False, cap1=False, flip=False, recalc=True):
        bm, m = self.bm, self.mi(mat)
        rows = [[bm.verts.new(p) for p in row] for row in P]
        nv, nu = len(rows), len(rows[0])
        faces = []
        ucount = nu if closed_u else nu - 1
        for i in range(nv - 1):
            for j in range(ucount):
                j2 = (j + 1) % nu
                q = [rows[i][j], rows[i][j2], rows[i + 1][j2], rows[i + 1][j]]
                uvs = [(j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1)]
                if flip:
                    q.reverse()
                    uvs.reverse()
                f = bm.faces.new(q)
                f.material_index = m
                for k, (b, a) in enumerate(uvs):
                    f.loops[k][self.uv].uv = (b / max(1, ucount), a / max(1, nv - 1))
                faces.append(f)
        for cap, row in ((cap0, rows[0]), (cap1, rows[-1])):
            if cap and closed_u:
                c = bm.verts.new(sum((v.co for v in row), V()) / len(row))
                for j in range(nu):
                    f = bm.faces.new([row[j], row[(j + 1) % nu], c])
                    f.material_index = m
                    faces.append(f)
        if recalc:
            bmesh.ops.recalc_face_normals(bm, faces=faces)
        for f in faces:
            f.smooth = True
        return [v for row in rows for v in row] + [], faces

    def transform(self, verts, M):
        for v in verts:
            v.co = M @ v.co

    def finish(self, coll, materials, sharp_angle=35, mirror=False):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        self.bm.to_mesh(me)
        self.bm.free()
        for name in self.mats:
            me.materials.append(materials[name])
        ob = bpy.data.objects.new(self.name, me)
        coll.objects.link(ob)
        try:
            me.set_sharp_from_angle(angle=math.radians(sharp_angle))
        except (AttributeError, TypeError):
            pass
        ob["AsuraBone"] = self.bone
        if self.role:
            ob["AsuraRole"] = self.role
        return ob


# -- point generators --------------------------------------------------------------------------------------

def sring(c, u, w, ru, rw, n, p=2.0, a0=0.0, rw_back=None, bump=None):
    """Superellipse ring around centre c in the plane spanned by unit vectors u, w.
    rw applies on +w (front), rw_back on -w. bump(theta) -> radial multiplier."""
    out = []
    for k in range(n):
        t = a0 + 2 * math.pi * k / n
        ct, st = math.cos(t), math.sin(t)
        x = math.copysign(abs(ct) ** (2 / p), ct) * ru
        r2 = rw if st >= 0 or rw_back is None else rw_back
        y = math.copysign(abs(st) ** (2 / p), st) * r2
        s = bump(t) if bump else 1.0
        out.append(c + u * (x * s) + w * (y * s))
    return out


def hring(z, rx, ry, n, p=2.0, cx=0.0, cy=0.0, ry_back=None, bump=None):
    """Horizontal ring (XY plane) at height z; +Y is the front."""
    return sring(V((cx, cy, z)), V((1, 0, 0)), V((0, 1, 0)), rx, ry, n, p, -math.pi / 2, ry_back, bump)


def frames(path, up=V((0, 0, 1))):
    """Parallel-transport frames (tangent, normal, binormal) along a polyline."""
    T = []
    for i in range(len(path)):
        a, b = path[max(0, i - 1)], path[min(len(path) - 1, i + 1)]
        T.append((b - a).normalized())
    n0 = up - T[0] * up.dot(T[0])
    if n0.length < 1e-4:
        n0 = V((1, 0, 0)) - T[0] * T[0].x
    N = [n0.normalized()]
    for i in range(1, len(path)):
        n = N[-1] - T[i] * N[-1].dot(T[i])
        N.append(n.normalized() if n.length > 1e-6 else N[-1])
    B = [t.cross(n).normalized() for t, n in zip(T, N)]
    return T, N, B


def tube(piece, path, radius, n, mat, cap0=True, cap1=True, p=2.0, flat=1.0, up=V((0, 0, 1)), twist=0.0):
    """Sweep a (super)elliptic section along path. radius: float or f(t in 0..1) -> r or (ru, rw)."""
    T, N, B = frames(path, up)
    rows = []
    L = len(path)
    for i, c in enumerate(path):
        t = i / max(1, L - 1)
        r = radius(t) if callable(radius) else radius
        ru, rw = (r if isinstance(r, tuple) else (r, r * flat))
        a = twist * t
        u = N[i] * math.cos(a) + B[i] * math.sin(a)
        w = -N[i] * math.sin(a) + B[i] * math.cos(a)
        rows.append(sring(c, u, w, ru, rw, n, p))
    return piece.grid(rows, mat, closed_u=True, cap0=cap0, cap1=cap1)


def lathe(piece, profile, n, mat, M=Matrix(), cap0=False, cap1=False, p=2.0, sx=1.0, sy=1.0, a0=0.0, arc=None):
    """Revolve a (radius, z) profile around local Z, then place with matrix M. sx/sy squash the section."""
    rows = []
    closed = arc is None
    cnt = n if closed else n + 1
    for r, z in profile:
        row = []
        for k in range(cnt):
            t = a0 + (2 * math.pi if closed else arc) * k / n
            ct, st = math.cos(t), math.sin(t)
            x = math.copysign(abs(ct) ** (2 / p), ct) * r * sx
            y = math.copysign(abs(st) ** (2 / p), st) * r * sy
            row.append(M @ V((x, y, z)))
        rows.append(row)
    return piece.grid(rows, mat, closed_u=closed, cap0=cap0, cap1=cap1)


def slab(piece, P, thick, mat, edge_mat=None, recalc=True, offset=0.0):
    """Thicken an open surface grid P (rows x cols) into a closed slab of thickness `thick`.
    Normals come from the grid; offset shifts the slab along them (0 = centred)."""
    nv, nu = len(P), len(P[0])
    Nrm = [[V() for _ in range(nu)] for _ in range(nv)]
    for i in range(nv):
        for j in range(nu):
            du = P[i][min(nu - 1, j + 1)] - P[i][max(0, j - 1)]
            dv = P[min(nv - 1, i + 1)][j] - P[max(0, i - 1)][j]
            n = du.cross(dv)
            Nrm[i][j] = n.normalized() if n.length > 1e-9 else V((0, 0, 1))
    th = thick if callable(thick) else (lambda i, j: thick)
    front = [[P[i][j] + Nrm[i][j] * (offset + th(i, j) / 2) for j in range(nu)] for i in range(nv)]
    back = [[P[i][j] + Nrm[i][j] * (offset - th(i, j) / 2) for j in range(nu)] for i in range(nv)]
    # one closed ring per row: front row left->right, then back row right->left (wraps the edges)
    bm, mf = piece.bm, piece.mi(mat)
    me = piece.mi(edge_mat or mat)
    F = [[bm.verts.new(p) for p in row] for row in front]
    Bk = [[bm.verts.new(p) for p in row] for row in back]
    faces = []

    def add(q, m, uvs):
        f = bm.faces.new(q)
        f.material_index = m
        for k, uv in enumerate(uvs):
            f.loops[k][piece.uv].uv = uv
        f.smooth = True
        faces.append(f)

    for i in range(nv - 1):
        for j in range(nu - 1):
            uv = [(j / (nu - 1), i / (nv - 1)), ((j + 1) / (nu - 1), i / (nv - 1)),
                  ((j + 1) / (nu - 1), (i + 1) / (nv - 1)), (j / (nu - 1), (i + 1) / (nv - 1))]
            add([F[i][j], F[i][j + 1], F[i + 1][j + 1], F[i + 1][j]], mf, uv)
            add([Bk[i + 1][j], Bk[i + 1][j + 1], Bk[i][j + 1], Bk[i][j]], mf, uv[::-1])
    z = [(0, 0)] * 4
    for j in range(nu - 1):  # first and last rows
        add([Bk[0][j], Bk[0][j + 1], F[0][j + 1], F[0][j]], me, z)
        add([F[-1][j], F[-1][j + 1], Bk[-1][j + 1], Bk[-1][j]], me, z)
    for i in range(nv - 1):  # first and last columns
        add([F[i][0], F[i + 1][0], Bk[i + 1][0], Bk[i][0]], me, z)
        add([Bk[i][-1], Bk[i + 1][-1], F[i + 1][-1], F[i][-1]], me, z)
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=faces)
    return [v for row in F + Bk for v in row], faces


def box(piece, c, size, mat, M=None, bevel=0.0):
    """Axis box (optionally placed by matrix M about its centre); bevel rounds edges in bmesh."""
    sx, sy, sz = (s / 2 for s in size)
    pts = [V((x, y, z)) for z in (-sz, sz) for y in (-sy, sy) for x in (-sx, sx)]
    bm = piece.bm
    vs = [bm.verts.new((M or Matrix()) @ p + c) for p in pts]
    idx = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    faces = []
    for q in idx:
        f = bm.faces.new([vs[i] for i in q])
        f.material_index = piece.mi(mat)
        faces.append(f)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    if bevel > 0:
        edges = list({e for f in faces for e in f.edges})
        res = bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=2, affect="EDGES", profile=0.5)
        faces = [f for f in faces if f.is_valid] + res["faces"]
    for f in faces:
        if f.is_valid:
            f.smooth = True
    return vs, faces


def curve_pts(ctrl, n):
    """Catmull-Rom through control points, n samples."""
    P = [V(p) for p in ctrl]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    seg = len(P) - 3
    for k in range(n):
        s = k / (n - 1) * seg
        i = min(int(s), seg - 1)
        t = s - i
        p0, p1, p2, p3 = P[i:i + 4]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return out


def gauss(d2, s):
    return math.exp(-d2 / (2 * s * s))


def mirror_x(P):
    return [[V((-p.x, p.y, p.z)) for p in row[::-1]] for row in P]


def rot(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def tr(v):
    return Matrix.Translation(V(v))

"""Geometry helpers for lobby_kit.py. Blender units are studs, Z up, pieces built at their origin.

A Mesh holds one material's geometry for one kit piece. Solids (boxes, lathes, prisms, swept
profiles with caps) get outward normals from recalc_face_normals; open surfaces (roof skins) are
oriented explicitly with an `expect` direction. Faces without authored UVs get a world-scaled box
projection, so every piece in a material family shares one texel density (lobby_textures.STUDS).
"""
import math

import bmesh
import numpy as np
from mathutils import Matrix, Vector
from mathutils.geometry import tessellate_polygon

I4 = Matrix.Identity(4)


class Mesh:
    def __init__(self, name, material, studs):
        self.name, self.material, self.studs = name, material, studs
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.fixed = self.bm.faces.layers.int.new("fixed_uv")
        self.open = self.bm.faces.layers.int.new("open_surface")

    # -- primitives ---------------------------------------------------------------------------
    def grid(self, P, UV=None, wrap=False, expect=None, open_surface=False):
        """P[i][j] rows x cols of Vectors; UV[i][j] (cols+1 when wrap). Returns the faces."""
        rows, cols = len(P), len(P[0])
        V = [[self.bm.verts.new(P[i][j]) for j in range(cols)] for i in range(rows)]
        span = cols if wrap else cols - 1
        faces = []
        for i in range(rows - 1):
            for j in range(span):
                jn = (j + 1) % cols
                quad = [V[i][j], V[i][jn], V[i + 1][jn], V[i + 1][j]]
                uvs = None
                if UV is not None:
                    uvs = [UV[i][j], UV[i][j + 1], UV[i + 1][j + 1], UV[i + 1][j]]
                f = self._face(quad, uvs)
                if f:
                    f[self.open] = 1 if open_surface else 0
                    faces.append(f)
        if expect is not None and faces:
            mid = faces[len(faces) // 2]
            mid.normal_update()
            if mid.normal.dot(expect) < 0:
                for f in faces:
                    f.normal_flip()
        return faces

    def _face(self, verts, uvs=None):
        unique = []
        for v in verts:
            if not any(v == u for u in unique):
                unique.append(v)
        if len(unique) < 3 or len(unique) < len(verts):
            return None
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        if uvs:
            for loop, uv in zip(f.loops, uvs):
                loop[self.uv].uv = uv
            f[self.fixed] = 1
        return f

    def poly(self, pts, uvs=None, open_surface=False):
        f = self._face([self.bm.verts.new(p) for p in pts], uvs)
        if f:
            f[self.open] = 1 if open_surface else 0
        return f

    def box(self, center, size, M=I4, bevel=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(center)
        if bevel > 0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges) + list(tmp.verts), offset=bevel, segments=1,
                            affect="EDGES", profile=0.5)
        self.merge(tmp, M)
        tmp.free()

    def merge(self, other, M=I4):
        """Copies another bmesh in (winding kept; open-surface flags kept so orientation survives)."""
        flag = other.faces.layers.int.get("open_surface")
        remap = {}
        for v in other.verts:
            remap[v] = self.bm.verts.new(M @ v.co)
        for f in other.faces:
            g = self._face([remap[v] for v in f.verts])
            if g and flag is not None:
                g[self.open] = f[flag]

    def lathe(self, profile, segs, M=I4, phase=0.0, caps=(True, True)):
        """profile [(r, z)] bottom to top; square/octagon lathes come from segs 4/8."""
        P, UV = [], []
        rmax = max(r for r, _ in profile)
        around = 2 * math.pi * rmax / self.studs
        length = 0.0
        for k, (r, z) in enumerate(profile):
            if k:
                pr, pz = profile[k - 1]
                length += math.hypot(r - pr, z - pz)
            ring = [M @ Vector((r * math.cos(phase + 2 * math.pi * j / segs),
                                r * math.sin(phase + 2 * math.pi * j / segs), z)) for j in range(segs)]
            P.append(ring)
            UV.append([(around * j / segs, length / self.studs) for j in range(segs + 1)])
        self.grid(P, UV, wrap=True)
        if caps[0] and profile[0][0] > 1e-4:
            self.poly(list(reversed(P[0])))
        if caps[1] and profile[-1][0] > 1e-4:
            self.poly(P[-1])

    def prism(self, outer, holes=(), depth=1.0, M=I4):
        """2-D outline (+ holes) in local XY, extruded from z = 0 to `depth`, then transformed."""
        def area(loop):
            return sum(loop[i][0] * loop[(i + 1) % len(loop)][1] - loop[(i + 1) % len(loop)][0] * loop[i][1]
                       for i in range(len(loop))) * 0.5
        loops = [list(outer) if area(outer) > 0 else list(reversed(outer))]
        for h in holes:
            loops.append(list(h) if area(h) < 0 else list(reversed(h)))
        flat = [p for loop in loops for p in loop]
        tris = tessellate_polygon([[Vector((x, y, 0)) for x, y in loop] for loop in loops])
        bottom = [self.bm.verts.new(M @ Vector((x, y, 0))) for x, y in flat]
        top = [self.bm.verts.new(M @ Vector((x, y, depth))) for x, y in flat]
        for a, b, c in tris:
            pa, pb, pc = (Vector((*flat[i], 0)) for i in (a, b, c))
            if (pb - pa).cross(pc - pa).z < 0:
                b, c = c, b
            self._face([top[a], top[b], top[c]])
            self._face([bottom[a], bottom[c], bottom[b]])
        start = 0
        for loop in loops:
            n = len(loop)
            for i in range(n):
                a, b = start + i, start + (i + 1) % n
                self._face([bottom[a], bottom[b], top[b], top[a]])
            start += n

    def sweep(self, profile, path, up=Vector((0, 0, 1)), scales=None, caps=True):
        """Closed 2-D profile [(side, lift)] swept along a polyline; optional per-point scale."""
        frames, side_prev = [], None
        for k, p in enumerate(path):
            a = path[max(k - 1, 0)]
            b = path[min(k + 1, len(path) - 1)]
            t = (b - a).normalized()
            side = t.cross(up)
            if side.length < 1e-4:
                side = side_prev if side_prev is not None else Vector((1, 0, 0))
            side = side.normalized()
            side_prev = side
            frames.append((side, side.cross(t).normalized()))
        P, UV = [], []
        per = [0.0]
        for i in range(1, len(profile) + 1):
            x0, y0 = profile[i - 1]
            x1, y1 = profile[i % len(profile)]
            per.append(per[-1] + math.hypot(x1 - x0, y1 - y0))
        along = 0.0
        for k, p in enumerate(path):
            if k:
                along += (p - path[k - 1]).length
            s = scales[k] if scales else 1.0
            side, nrm = frames[k]
            P.append([p + side * (x * s) + nrm * (y * s) for x, y in profile])
            UV.append([(per[j] / self.studs, along / self.studs) for j in range(len(profile) + 1)])
        self.grid(P, UV, wrap=True)
        if caps:
            self.poly(P[0])
            self.poly(list(reversed(P[-1])))

    # -- finishing ----------------------------------------------------------------------------
    def finish(self):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if not f[self.open]])
        bm.normal_update()
        s = self.studs
        for f in bm.faces:
            if f[self.fixed]:
                continue
            n = f.normal
            axis = max(range(3), key=lambda i: abs(n[i]))
            for loop in f.loops:
                c = loop.vert.co
                uv = {0: (c.y, c.z), 1: (c.x, c.z), 2: (c.x, c.y)}[axis]
                loop[self.uv].uv = (uv[0] / s, uv[1] / s)
        return bm


def superellipse(cx, cy, a, b, power=4.0, n=28):
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        c, s = math.cos(t), math.sin(t)
        pts.append((cx + a * math.copysign(abs(c) ** (2 / power), c), cy + b * math.copysign(abs(s) ** (2 / power), s)))
    return pts


def rect(cx, cy, w, h):
    return [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2), (cx - w / 2, cy + h / 2)]


def xz_plane(y=0.0, depth=0.0):
    """Matrix taking a prism drawn in XY (extruded +Z) into the XZ plane centred on `y`."""
    return Matrix.Translation((0, y + depth / 2, 0)) @ Matrix.Rotation(math.radians(90), 4, "X")


def rock_body(mesh, rx, ry, top, bottom, seed, taper=(1.0, 0.3), layer=(2.5, 5.5), n_theta=44, n_z=26,
              upward=False, cap_top=True):
    """Layered karst rock: stacked strata with per-layer offsets, tapering away from the cap side."""
    rng = np.random.default_rng(seed)
    harm = [(k, rng.uniform(0, 2 * math.pi), rng.uniform(0.03, 0.11) / k ** 0.6) for k in range(1, 7)]
    height = abs(top - bottom)
    bounds, z = [0.0], 0.0
    while z < height:
        z += rng.uniform(*layer)
        bounds.append(min(z, height))
    shifts = [(rng.uniform(-0.035, 0.035), rng.uniform(0, 2 * math.pi), rng.uniform(0.01, 0.05)) for _ in bounds]
    flutes = [(m, rng.uniform(0, 2 * math.pi), rng.uniform(0.012, 0.03)) for m in range(8, 17, 2)]
    P, UV = [], []
    perimeter = 2 * math.pi * math.sqrt((rx * rx + ry * ry) / 2)
    for i in range(n_z):
        f = i / (n_z - 1)
        depth = f * height
        zz = top - depth if not upward else bottom + depth
        k = max(0, min(len(bounds) - 2, int(np.searchsorted(bounds, depth, side="right") - 1)))
        frac = (depth - bounds[k]) / max(bounds[k + 1] - bounds[k], 1e-3)
        scale = taper[0] + (taper[1] - taper[0]) * f ** 1.25
        ring, uvs = [], []
        for j in range(n_theta + 1):
            th = 2 * math.pi * j / n_theta
            wob = sum(a * math.sin(h * th + p) for h, p, a in harm)
            sh, sp, sa = shifts[k]
            wob += sh + sa * math.sin(2 * th + sp) - 0.05 * frac ** 2 + 0.02 * math.sin(7 * th + 3 * k)
            wob += sum(fa * math.sin(m * th + fp + 0.04 * zz) for m, fp, fa in flutes)
            r = 1 + wob
            if j < n_theta:
                ring.append(Vector((rx * scale * r * math.cos(th), ry * scale * r * math.sin(th), zz)))
            uvs.append((perimeter * j / n_theta / mesh.studs, zz / mesh.studs))
        P.append(ring)
        UV.append(uvs)
    mesh.grid(P, UV, wrap=True)
    first, last = P[0], P[-1]
    if cap_top:
        mesh.poly(list(reversed(first)) if not upward else first)
    mesh.poly(last if not upward else list(reversed(last)))

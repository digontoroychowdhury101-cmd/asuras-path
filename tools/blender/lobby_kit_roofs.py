"""Roof pieces for the lobby kit: hip-and-gable hall roof, pyramidal kiosk roof, gallery bays.

Blender units are studs, Z up, X along the ridge, origin at the eave-line centre (the top of the
column frame). The eave curves up toward each corner (lift) and kicks outward in plan (kick); the
slope is concave, flat at the eave and steep at the ridge. Tile courses come from the Roof texture;
the silhouette - curved eave, ridges, horns, upturned hip tips, tile ends - is modelled.
"""
import math

from mathutils import Matrix, Vector

from lobby_kit_geo import I4

SU, SV = 17.6, 14.4  # Roof texture repeat across and up the slope (lobby_textures.ROOF_TILES)
UP = Vector((0, 0, 1))


def ridge_profile(w, h):
    return [(-w / 2, 0), (w / 2, 0), (w / 2, h * 0.65), (w * 0.32, h), (-w * 0.32, h), (-w / 2, h * 0.65)]


def _axis_matrix(origin, axis):
    z = axis.normalized()
    x = z.cross(UP) if abs(z.dot(UP)) < 0.95 else z.cross(Vector((1, 0, 0)))
    x.normalize()
    y = z.cross(x)
    return Matrix(((x.x, y.x, z.x, origin.x), (x.y, y.y, z.y, origin.y), (x.z, y.z, z.z, origin.z), (0, 0, 0, 1)))


def _samples(a, b, n):
    return [a + (b - a) * k / n for k in range(n + 1)]


def hall(pc, W=30.0, D=18.0, H=7.5, tg=0.6, lift=1.8, kick=1.0, thick=(0.55, 1.3), top="Roof", under="Timber",
         tile_ends=True, ridge_scale=1.0, finial=None, nu=26, nt=(7, 6), rafters=True):
    """Hip-and-gable (tg < 1) or pyramidal (tg = 1, W = D) roof."""
    a, b = W / 2, D / 2
    pyramid = tg >= 0.999
    t_top = 0.94 if pyramid else 1.0
    xg = a - b * tg

    def Zt(t):
        return H * (0.3 * t + 0.7 * t * t)

    def P(face, s, t):
        if abs(face) == 1:
            y = face * b * (1 - t)
            x = s * (a - b * min(t, tg))
        else:
            x = (1 if face == 2 else -1) * (a - b * t)
            y = s * b * (1 - t)
        c = min(abs(x) / a, 1) * min(abs(y) / b, 1)
        X = x + math.copysign(kick * c ** 4, x) if x else 0.0
        Y = y + math.copysign(kick * c ** 4, y) if y else 0.0
        return Vector((X, Y, Zt(t) + lift * c ** 3))

    def thickness(t):
        return thick[0] + (thick[1] - thick[0]) * t

    t_long = _samples(0, min(tg, t_top), nt[0]) + (_samples(tg, t_top, nt[1])[1:] if not pyramid else [])
    t_end = _samples(0, min(tg, t_top), nt[0])
    faces = [(1, nu, t_long), (-1, nu, t_long), (2, max(6, int(nu * D / W)), t_end), (-2, max(6, int(nu * D / W)), t_end)]
    skin, soffit = pc.m(top), pc.m(under)
    for face, n, ts in faces:
        ss = _samples(-1.0, 1.0, n)
        grid = [[P(face, s, t) for s in ss] for t in ts]
        slope = [0.0]
        for k in range(1, len(ts)):
            slope.append(slope[-1] + (P(face, 0, ts[k]) - P(face, 0, ts[k - 1])).length)
        uv = [[((p.x if abs(face) == 1 else p.y) / SU, slope[i] / SV) for p in row] for i, row in enumerate(grid)]
        outward = Vector((0, face, 1) if abs(face) == 1 else (face / 2, 0, 1))
        skin.grid(grid, uv, expect=outward, open_surface=True)
        low = [[p - Vector((0, 0, thickness(ts[i]))) for p in row] for i, row in enumerate(grid)]
        soffit.grid(low, None, expect=Vector((0, 0, -1)), open_surface=True)

    # Eave fascia around the whole perimeter, counter-clockwise seen from above.
    loop = []
    for face, n, ss in ((1, nu, _samples(1, -1, nu)), (-2, 8, _samples(1, -1, 8)), (-1, nu, _samples(-1, 1, nu)), (2, 8, _samples(-1, 1, 8))):
        pts = [P(face, s, 0) for s in ss]
        loop.extend(pts if not loop else pts[1:])
    loop = loop[:-1]
    for i, p in enumerate(loop):
        q = loop[(i + 1) % len(loop)]
        f = soffit.poly([p, q, q - Vector((0, 0, thick[0])), p - Vector((0, 0, thick[0]))], open_surface=True)
        if f:
            f.normal_update()
            mid = (p + q) * 0.5
            if f.normal.dot(Vector((mid.x, mid.y, 0))) < 0:
                f.normal_flip()
    if tile_ends:
        ends = pc.m(top)
        travelled, step = 0.0, 1.1
        for i, p in enumerate(loop):
            q = loop[(i + 1) % len(loop)]
            seg = (q - p).length
            while travelled <= seg:
                at = p + (q - p) * (travelled / max(seg, 1e-6))
                out = Vector((at.x, at.y, 0)).normalized() * 0.32 - Vector((0, 0, 0.12))
                M = _axis_matrix(at - Vector((0, 0, 0.18)) - out * 0.6, out)
                ends.lathe([(0.27, 0), (0.27, 0.42)], 6, M)
                travelled += step
            travelled -= seg

    if rafters:
        # Exposed rafters under the overhang; they fan at the corners like the real thing.
        w = pc.m(under)
        travelled = 0.55
        for i, p in enumerate(loop):
            q = loop[(i + 1) % len(loop)]
            seg = (q - p).length
            while travelled <= seg:
                at = p + (q - p) * (travelled / max(seg, 1e-6))
                ux, uy = at.x / a, at.y / b
                inward = Vector((-math.copysign(abs(ux) ** 8, ux), -math.copysign(abs(uy) ** 8, uy), 0)).normalized()
                run = 0.3 * b
                start = at - Vector((0, 0, thick[0] + 0.12)) - inward * 0.25
                end = start + inward * run + Vector((0, 0, Zt(0.3) - thick[0] * 0.2 - lift * 0.15))
                M = _axis_matrix(start, end - start)
                w.box((0, 0, (end - start).length / 2), (0.24, 0.24, (end - start).length), M)
                travelled += 1.1
            travelled -= seg

    rs = ridge_scale
    ridge = pc.m(top)
    if not pyramid:
        xs = _samples(-(xg + 0.2), xg + 0.2, 12)
        path = [Vector((x, 0, H - 0.25 * rs)) for x in xs]
        scales = [1.0] * len(path)
        horn = [(0.45, 0.35, 0.95), (0.8, 1.0, 0.85), (0.85, 1.75, 0.72), (0.55, 2.3, 0.58), (0.15, 2.5, 0.45)]
        left = [Vector((path[0].x - o * rs, 0, path[0].z + h * rs)) for o, h, _ in reversed(horn)]
        right = [Vector((path[-1].x + o * rs, 0, path[-1].z + h * rs)) for o, h, _ in horn]
        ridge.sweep(ridge_profile(1.1 * rs, 1.15 * rs), left + path + right,
                    scales=[s for *_, s in reversed(horn)] + scales + [s for *_, s in horn])
        for sx in (-1, 1):
            up_front = [P(1, sx, t) + Vector((0, 0, 0.05)) for t in _samples(tg, 1, 6)]
            down_back = [P(-1, sx, t) + Vector((0, 0, 0.05)) for t in _samples(1, tg, 6)[1:]]
            ridge.sweep(ridge_profile(0.75 * rs, 0.7 * rs), up_front + down_back)
            base = [P(2 * sx, s, tg) + Vector((0, 0, 0.02)) for s in _samples(-1, 1, 8)]
            ridge.sweep(ridge_profile(0.55 * rs, 0.45 * rs), base)
            # Recessed gable wall under the barge ridges, with a bronze rosette.
            outline = [(p.y, p.z - 0.25) for p in up_front + down_back]
            Mg = Matrix.Translation((sx * (xg - 0.55) - 0.15, 0, 0)) @ Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
            soffit.prism(outline, (), 0.3, Mg)
            if finial:
                Mr = Matrix.Translation((sx * (xg - 0.35), 0, Zt(tg) + (H - Zt(tg)) * 0.42)) @ Matrix.Rotation(math.radians(90 * sx), 4, "Y")
                pc.m(finial).lathe([(0.75 * rs, 0), (0.6 * rs, 0.18 * rs), (0.25 * rs, 0.3 * rs)], 10, Mr)
    for sx in (-1, 1):
        for sy in (-1, 1):
            t0 = t_top if pyramid else tg
            seam = [P(sy, sx, t) + Vector((0, 0, 0.06)) for t in _samples(t0, 0, 7)]
            c = seam[-1]
            d = Vector((sx, sy, 0)).normalized()
            tip = [c + d * 0.6 * rs + UP * 0.25 * rs, c + d * 1.1 * rs + UP * 0.85 * rs, c + d * 1.35 * rs + UP * 1.5 * rs]
            ridge.sweep(ridge_profile(0.8 * rs, 0.7 * rs), seam + tip, scales=[1.0] * len(seam) + [0.9, 0.72, 0.5])
    if pyramid:
        cap = pc.m(finial or top)
        Mf = Matrix.Translation((0, 0, Zt(t_top) - 0.35 * rs))
        cap.lathe([(x * rs, z * rs) for x, z in ((1.25, 0), (1.0, 0.35), (0.45, 0.6), (0.62, 0.95), (0.6, 1.25),
                                                  (0.35, 1.6), (0.14, 1.85), (0.06, 1.95))], 12, Mf)
    return H


def gallery(pc, L=8.8, D=10.0, H=3.4, thick=(0.45, 0.9), end=False, nt=9, nu=8):
    """Straight gable bay of a covered gallery (chains along X), or its gable end cap."""
    b = D / 2

    def Zt(t):
        return H * (0.3 * t + 0.7 * t * t)

    x0, x1 = (-L / 2, L / 2) if not end else (0.0, 0.9)
    skin, soffit = pc.m("Roof"), pc.m("Timber")
    ts = _samples(0, 1, nt)
    for face in (1, -1):
        grid = [[Vector((x, face * b * (1 - t), Zt(t))) for x in _samples(x0, x1, nu if not end else 1)] for t in ts]
        slope = [0.0]
        for k in range(1, len(ts)):
            slope.append(slope[-1] + (grid[k][0] - grid[k - 1][0]).length)
        uv = [[(p.x / SU, slope[i] / SV) for p in row] for i, row in enumerate(grid)]
        skin.grid(grid, uv, expect=Vector((0, face, 1)), open_surface=True)
        low = [[p - Vector((0, 0, thick[0] + (thick[1] - thick[0]) * ts[i])) for p in row] for i, row in enumerate(grid)]
        soffit.grid(low, None, expect=Vector((0, 0, -1)), open_surface=True)
        e0, e1 = grid[0][0], grid[0][-1]
        f = soffit.poly([e0, e1, e1 - Vector((0, 0, thick[0])), e0 - Vector((0, 0, thick[0]))], open_surface=True)
        f.normal_update()
        if f.normal.y * face < 0:
            f.normal_flip()
        x = x0 + 0.55
        while x < x1 - 0.2 or (end and x <= x1):
            at = Vector((x, face * b, -0.18))
            out = Vector((0, face * 0.32, -0.12))
            skin.lathe([(0.25, 0), (0.25, 0.4)], 6, _axis_matrix(at - out * 0.6, out))
            x += 1.1
    if not end:
        skin.sweep(ridge_profile(0.8, 0.75), [Vector((x, 0, H - 0.2)) for x in _samples(x0, x1, 4)])
        return
    curve = [Vector((x1 - 0.2, b * (1 - t), Zt(t) + 0.05)) for t in ts] + \
            [Vector((x1 - 0.2, -b * (1 - t), Zt(t) + 0.05)) for t in reversed(ts[:-1])]
    skin.sweep(ridge_profile(0.6, 0.6), curve)
    under = [(p.y, p.z - 0.2 - thick[0] - (thick[1] - thick[0]) * (1 - abs(p.y) / b)) for p in curve]
    Mg = Matrix.Translation((x1 - 0.45, 0, 0)) @ Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    soffit.prism(under, (), 0.28, Mg)
    skin.sweep(ridge_profile(0.8, 0.75), [Vector((x, 0, H - 0.2)) for x in (x0, x1 + 0.15)])

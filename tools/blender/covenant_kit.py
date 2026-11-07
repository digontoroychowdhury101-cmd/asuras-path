"""AR01 The Ashen Covenant: Grandmaster Shen's funerary amphitheatre kit (B01 ruin, B07 monument, B09 ground, B10 props).

Original architecture. Units are studs; every piece's origin is its ground centre and its front faces Blender -Y, which
the Roblox import maps to -Z (the LookVector), so CFrame.lookAt(foot, foot + towardViewer) turns a piece to its viewer.
Reuses the Foundry pipeline (materials, Builder, unwrap, 4-map PBR bake, GLB export) from foundry_kit.py.
  blender -b --factory-startup --python tools/blender/covenant_kit.py -- preview OUT [piece ...]
  blender -b --factory-startup --python tools/blender/covenant_kit.py -- bake OUT [piece ...]
Collision stays in AshColosseumLayout: these meshes are decorative and envelope the boxes they dress.
"""
from math import cos, pi, radians, sin, tau
from pathlib import Path
import json
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import foundry_kit as fk  # noqa: E402
from foundry_kit import Builder, Nodes  # noqa: E402


# --- Materials: charcoal basalt, cold-grey ash and weathered stone, old bronze -------------------------------------
def _up(n):
    geo = n.tree.nodes.new("ShaderNodeNewGeometry")
    sep = n.tree.nodes.new("ShaderNodeSeparateXYZ")
    n.link(geo.outputs["Normal"], sep.inputs[0])
    return sep.outputs[2]


def basalt():
    n = Nodes("Basalt")
    seams = n.ramp(n.noise(0.32, 6, 0.6, n.stretch(n.obj, 1, 1, 3.2)), 0.53, 0.6)
    crack = n.ramp(n.cracks(0.42, None, 0.55), 0, 0.014)
    base = n.mix(n.noise(3.4, 8, 0.62), (0.085, 0.087, 0.095), (0.16, 0.16, 0.17))
    base = n.mix(n.math("MULTIPLY", seams, 0.55), base, (0.2, 0.225, 0.26))
    # Ash settles on what faces the sky and wears off the arrises.
    dust = n.ramp(n.math("ADD", _up(n), n.math("MULTIPLY", n.noise(1.3, 5), 0.55)), 1.0, 1.32)
    color = n.mix(n.math("MULTIPLY", dust, 0.8), base, (0.42, 0.415, 0.405))
    color = n.occlude(n.mix(crack, (0.04, 0.04, 0.045), color), 0.55)
    height = n.math("ADD", crack, n.math("MULTIPLY", n.noise(9, 7), 0.45))
    return n.finish(color, n.lerp(dust, 0.78, 0.95), 0, height, 0.9, 0.08, 0.78, 0.95)


def ashstone():
    n = Nodes("AshStone")
    crack = n.ramp(n.cracks(0.55, None, 0.58), 0, 0.013)
    soot = n.ramp(n.noise(1.0, 5, 0.5, n.stretch(n.obj, 1.1, 1.1, 0.09)), 0.5, 0.78)
    base = n.mix(n.noise(2.4, 8, 0.6), (0.29, 0.285, 0.28), (0.43, 0.42, 0.405))
    color = n.mix(n.math("MULTIPLY", soot, 0.75), base, (0.12, 0.115, 0.115))
    dust = n.ramp(n.math("ADD", _up(n), n.math("MULTIPLY", n.noise(1.6, 5), 0.5)), 1.05, 1.35)
    color = n.mix(n.math("MULTIPLY", dust, 0.6), color, (0.47, 0.46, 0.45))
    color = n.occlude(n.mix(crack, (0.07, 0.07, 0.07), color), 0.6)
    height = n.math("ADD", crack, n.math("MULTIPLY", n.noise(12, 7), 0.4))
    return n.finish(color, 0.88, 0, height, 0.9, 0.07, 0.62, 0.85)


def ash():
    n = Nodes("Ash")
    ripple = n.noise(0.6, 4, 0.5, n.stretch(n.obj, 0.35, 2.2, 1))
    base = n.mix(n.noise(3.0, 7, 0.6), (0.38, 0.375, 0.37), (0.5, 0.49, 0.48))
    cinder = n.ramp(n.noise(16, 4, 0.7), 0.66, 0.72)
    color = n.occlude(n.mix(n.math("MULTIPLY", cinder, 0.7), n.mix(n.math("MULTIPLY", ripple, 0.25), base, (0.33, 0.325, 0.32)), (0.09, 0.085, 0.085)), 0.45)
    return n.finish(color, 0.96, 0, n.math("ADD", n.math("MULTIPLY", ripple, 0.5), n.noise(22, 5)), 0.6, 0.05, 0.66, 0.7)


def reed():
    n = Nodes("Reed")
    rise = n.ramp(n.z, 0.3, 4.4)
    streak = n.noise(1.0, 3, 0.4, n.stretch(n.obj, 6, 6, 0.4))
    stem = n.mix(n.math("MULTIPLY", streak, 0.4), (0.27, 0.285, 0.25), (0.36, 0.37, 0.33))
    color = n.occlude(n.mix(rise, stem, (0.74, 0.74, 0.7)), 0.4)
    return n.finish(color, n.lerp(rise, 0.7, 0.55), 0, streak, 0.3, 0.02, 0.8, 0.7)


# --- Geometry helpers ----------------------------------------------------------------------------------------------
def hexa(b, bottom, top, material, bevel=0.0):
    """A closed six-faced solid from two corner quads (any taper, lean or twist), optionally bevelled."""
    vs = [b.bm.verts.new(p) for p in list(bottom) + list(top)]
    faces = [b.bm.faces.new([vs[i] for i in q]) for q in ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))]
    if bevel:
        edges = list({e for f in faces for e in f.edges})
        result = fk.bmesh.ops.bevel(b.bm, geom=vs + edges, offset=bevel, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
        kept = {f for f in faces if f.is_valid} | set(result["faces"])
        for v in result["verts"]:
            kept |= set(v.link_faces)
        faces = list(kept)
    b.paint(faces, material)
    return faces


def voussoirs(b, cx, cz, r0, r1, y0, y1, count, material, keep=lambda i, a: True, gap=0.035, key=0.0, bevel=0.05):
    """A semicircular arch ring in the XZ plane: `count` wedges from the right springing (a=0) to the left (a=pi)."""
    for i in range(count):
        a0 = pi * i / count + gap / 2
        a1 = pi * (i + 1) / count - gap / 2
        if not keep(i, (a0 + a1) / 2):
            continue
        extra = key if i == count // 2 else 0.0
        out = r1 + extra
        p = lambda r, a, y: (cx + r * cos(a), y, cz + r * sin(a))
        hexa(b, [p(r0, a0, y0 - extra * 0.3), p(out, a0, y0 - extra * 0.3), p(out, a1, y0 - extra * 0.3), p(r0, a1, y0 - extra * 0.3)],
             [p(r0, a0, y1), p(out, a0, y1), p(out, a1, y1), p(r0, a1, y1)], material, bevel)


def spandrel(b, cx, cz, r1, x_end, z_top, y0, y1, material, course=1.0, keep=lambda x, z: True, rough=0.06):
    """Coursed masonry filling between an arch extrados and a rectangle: one block row per course on each side."""
    z = cz
    while z < z_top - 1e-3:
        h = min(course, z_top - z)
        mid = z + h / 2
        inner = (r1 * r1 - (mid - cz) ** 2) ** 0.5 if mid - cz < r1 else 0.0
        for s in (-1, 1):
            if inner < x_end - 0.2 and keep(s, mid):
                lo, hi = cx + s * inner, cx + s * x_end
                w = abs(hi - lo)
                setback = b.rng.uniform(0, rough)
                b.box(((lo + hi) / 2, (y0 + y1) / 2 - setback * 0, mid), (w, (y1 - y0) - setback, h - 0.04), material, 0.05)
        z += course


def mound(b, center, radii, material, amount=0.25, scale=0.3, subdivisions=3):
    return b.lump(center, radii, subdivisions, material, amount, scale, floor=center[2])


# --- Pieces --------------------------------------------------------------------------------------------------------
def build_seat(name, heavy):
    """B07 radial seating front: one 20-stud bay of the five-tier side cavea (tiers 8 deep x 4 high, front = arena)."""
    b = Builder(name, [basalt(), ash(), ashstone()])
    rng = b.rng
    L = 20.0
    for k in range(1, 6):
        y0, top = -20.0 + (k - 1) * 8, 4.0 * k
        b.box((0, y0 + 4, top / 2 - 0.15), (L + 0.02, 8.04, top - 0.3), "Basalt", 0.18)
        # The seat course: dressed slabs with a nosing over the riser; some missing, lifted or slipped down a tier.
        x = -L / 2
        while x < L / 2 - 0.3:
            w = min(rng.uniform(2.1, 3.1), L / 2 - x)
            roll = rng.random()
            cx = x + w / 2
            if roll < (0.16 if heavy else 0.07):
                if k > 1 and rng.random() < 0.6:
                    b.box((cx + rng.uniform(-0.4, 0.4), y0 - rng.uniform(2.4, 4.5), top - 4 + 0.32), (w - 0.1, 2.3, 0.6), "AshStone", 0.1,
                          (radians(rng.uniform(-9, 9)), radians(rng.uniform(-6, 6)), radians(rng.uniform(-25, 25))))
            else:
                tilt = (radians(rng.uniform(-3, 3)), 0, radians(rng.uniform(-2, 2))) if roll > (0.82 if heavy else 0.9) else (0, 0, 0)
                b.box((cx, y0 + 1.05, top + 0.22), (w - 0.07, 2.6, 0.58), "AshStone", 0.1, tilt)
            x += w
        # Radial divider ribs on the riser: the seating reads as fronts, not a stair.
        for rx in (-L / 2 + 0.35, 0.0, L / 2 - 0.35):
            w = 0.7 if rx else 0.9
            b.box((rx, y0 - 0.12, top - 2.1), (w, 0.5, 3.6), "AshStone", 0.08)
        # Ash banked against the next riser.
        for _ in range(3 if heavy else 2):
            mound(b, (rng.uniform(-8, 8), y0 + 6.6, top), (rng.uniform(2.2, 4.2), 1.5, rng.uniform(0.5, 1.1)), "Ash", 0.18, 0.35)
    if heavy:
        # A fallen arcade block on the crown and a toppled drum in the third tier.
        b.box((rng.uniform(-6, 6), 18.0, 20.9), (3.2, 2.0, 1.8), "AshStone", 0.15, (radians(8), radians(14), radians(32)))
        b.cylinder((-4.0, 0.6, 12.9), (-1.0, 3.0, 13.4), 1.15, 14, "AshStone")
    return b.finish()


def build_arcade(name, broken):
    """B01/B07 cavea arcade bay: half-piers at both ends (bays tile into whole piers), voussoir arch, coursed spandrels."""
    b = Builder(name, [ashstone(), basalt()])
    rng = b.rng
    L, D, hp = 20.0, 4.6, 2.1
    y0, y1 = -D / 2, D / 2
    spring, r0, r1 = 10.4, L / 2 - hp, L / 2 - hp + 1.6
    top = spring + r1 + 0.5
    for s in (-1, 1):
        snapped = broken and s == 1
        px = s * (L / 2 - hp / 2)
        b.box((px - s * 0.02, 0, 0.75), (hp + 0.34, D + 0.7, 1.5), "Basalt", 0.12)
        if snapped:
            hexa(b, [(px - hp / 2, y0, 1.5), (px + hp / 2, y0, 1.5), (px + hp / 2, y1, 1.5), (px - hp / 2, y1, 1.5)],
                 [(px - hp / 2, y0, 5.2), (px + hp / 2, y0, 6.4), (px + hp / 2, y1, 6.0), (px - hp / 2, y1, 4.6)], "AshStone", 0.08)
            b.lump((px, 0, 5.6), (hp * 0.55, D * 0.48, 0.55), 2, "AshStone", 0.18, 0.8)
            continue
        for c in range(7):
            z = 1.5 + c * (spring - 0.8 - 1.5) / 7
            h = (spring - 0.8 - 1.5) / 7
            b.box((px, 0, z + h / 2), (hp - rng.uniform(0, 0.08), D - rng.uniform(0, 0.1), h - 0.05), "AshStone", 0.06)
        b.box((px - s * 0.25, 0, spring - 0.4), (hp + 0.5, D + 0.4, 0.8), "AshStone", 0.1)
    keep = (lambda i, a: a > 1.25) if broken else (lambda i, a: True)
    voussoirs(b, 0, spring, r0, r1, y0, y1, 15, "AshStone", keep, key=0.0 if broken else 0.45)
    spandrel(b, 0, spring, r1, L / 2, top, y0 + 0.1, y1 - 0.1, "AshStone", 1.05,
             (lambda s, z: s < 0 or z < spring + 2.5 - 0) if broken else (lambda s, z: True))
    if broken:
        b.box((-5.2, 0, top + 0.5), (9.4, D + 0.3, 1.0), "AshStone", 0.1, (0, radians(-1.5), 0))
        for i in range(4):
            b.box((rng.uniform(1, 8), -D / 2 - rng.uniform(0.8, 3.8), 0.55), (1.9, D * 0.7, 1.0), "AshStone", 0.08,
                  (radians(rng.uniform(-10, 10)), radians(rng.uniform(-12, 12)), radians(rng.uniform(0, 180))))
        b.box((6.5, -D / 2 - 2.2, 1.05), (2.0, 2.1, 4.2), "AshStone", 0.1, (radians(84), 0, radians(30)))
    else:
        for seg in range(4):
            if rng.random() < 0.2:
                continue
            b.box((-L / 2 + 2.5 + seg * 5, 0, top + 0.5), (5.0 - 0.06, D + 0.3, 1.0), "AshStone", 0.1)
            b.box((-L / 2 + 2.5 + seg * 5, 0, top + 1.3), (5.0 - 0.06, D + 0.9, 0.6), "AshStone", 0.12)
    return b.finish()


def build_facade(name):
    """B01 facade bay: a 3-thick, 22-high wall bay with blind arches on both faces and a broken crown (8 bays per side)."""
    b = Builder(name, [ashstone(), basalt(), bronze_mat()])
    rng = b.rng
    L, H, core = 21.125, 22.0, 2.2
    b.box((0, 0, H / 2), (L + 0.01, core, H), "AshStone", 0)
    for s in (-1, 1):
        f = s * core / 2
        y = lambda proud: (f, f + s * proud) if s > 0 else (f + s * proud, f)
        def slab(x0, x1, z0, z1, proud, mat="AshStone", bevel=0.06):
            a, c = y(proud)
            b.box(((x0 + x1) / 2, (a + c) / 2, (z0 + z1) / 2), (abs(x1 - x0), abs(c - a), abs(z1 - z0)), mat, bevel)
        slab(-L / 2, L / 2, 0, 1.7, 0.6, "Basalt", 0.1)
        for e in (-1, 1):
            slab(e * L / 2 - e * 1.8, e * L / 2, 1.7, 16.6, 0.5)
        spring, r0, r1 = 8.8, 6.4, 7.6
        for e in (-1, 1):
            slab(e * r0, e * (L / 2 - 1.8), 1.7, spring, 0.25)
        a, c = y(0.36)
        voussoirs(b, 0, spring, r0, r1, min(a, c), max(a, c), 13, "AshStone", key=0.35)
        a, c = y(0.25)
        spandrel(b, 0, spring, r1, L / 2 - 1.8, 16.6, min(a, c), max(a, c), "AshStone", 1.3)
        slab(-L / 2, L / 2, 16.6, 17.4, 0.7, "AshStone", 0.1)
        slab(-L / 2, L / 2, 17.4, H - 0.4, 0.22)
        # A bronze tablet in the blind arch, worn smooth: the order's roll of champions.
        if s < 0:
            a, c = y(0.12)
            b.box((0, (a + c) / 2, 5.6), (3.4, abs(c - a), 4.6), "Bronze", 0.05)
    # Broken crown: coping blocks with gaps and a few fallen to lower heights.
    x = -L / 2
    while x < L / 2 - 0.2:
        w = min(rng.uniform(1.6, 2.6), L / 2 - x)
        r = rng.random()
        if r > 0.18:
            h = rng.uniform(0.5, 1.2) if r > 0.4 else rng.uniform(0.15, 0.4)
            b.box((x + w / 2, rng.uniform(-0.1, 0.1), H - 0.4 + h / 2), (w - 0.08, core + 0.9, h + 0.02), "Basalt", 0.1,
                  (radians(rng.uniform(-3, 3)), radians(rng.uniform(-3, 3)), 0))
        x += w
    return b.finish()


def bronze_mat():
    """Old bronze: dark, with grey-green patina in the hollows; the Foundry bronze read orange against the cold ash."""
    n = Nodes("Bronze")
    streak = n.noise(1.0, 6, 0.55, n.stretch(n.obj, 2.4, 2.4, 0.28))
    patina = n.ramp(n.math("ADD", n.math("MULTIPLY", streak, 0.7), n.math("MULTIPLY", n.lerp(n.ao, 1, 0), 0.9)), 0.42, 0.7)
    metal = n.mix(n.noise(2.2, 7), (0.17, 0.12, 0.075), (0.11, 0.08, 0.05))
    color = n.occlude(n.mix(n.math("MULTIPLY", patina, 0.85), metal, (0.15, 0.19, 0.17)), 0.5)
    return n.finish(color, n.lerp(patina, 0.45, 0.85), n.lerp(patina, 0.75, 0.1), n.noise(14, 5), 0.3, 0.025, 0.62, 0.8)


def blackstone():
    """The cenotaph's polished-then-weathered black stone: near black faces, pale ash only where it can settle."""
    n = Nodes("Basalt")
    crack = n.ramp(n.cracks(0.12, None, 0.5), 0, 0.006)
    streak = n.ramp(n.noise(1.0, 5, 0.5, n.stretch(n.obj, 0.5, 0.5, 0.03)), 0.5, 0.75)
    base = n.mix(n.noise(1.2, 8, 0.6), (0.045, 0.045, 0.05), (0.085, 0.085, 0.095))
    base = n.mix(n.math("MULTIPLY", streak, 0.5), base, (0.16, 0.165, 0.17))
    dust = n.ramp(n.math("ADD", _up(n), n.math("MULTIPLY", n.noise(0.6, 5), 0.5)), 1.0, 1.3)
    color = n.occlude(n.mix(crack, (0.02, 0.02, 0.022), n.mix(n.math("MULTIPLY", dust, 0.85), base, (0.4, 0.395, 0.39))), 0.5)
    return n.finish(color, n.lerp(streak, 0.55, 0.82), 0, n.math("ADD", crack, n.math("MULTIPLY", n.noise(3, 6), 0.3)), 0.8, 0.12, 0.85, 0.9)


def build_gate(name, jamb, half, jamb_h, lintel_z, depth, roof):
    """Victor's gate (jambs 4x4 at +/-16) or the Champions' low arcade (towers 6x6 at +/-18 with a deep coffered roof)."""
    b = Builder(name, [basalt(), ashstone(), bronze_mat()])
    rng = b.rng
    w = jamb + 0.5
    for s in (-1, 1):
        x = s * half
        b.box((x, 0, 0.9), (w + 2.0, w + 2.0, 1.8), "Basalt", 0.18)
        b.box((x, 0, 2.3), (w + 1.0, w + 1.0, 1.0), "Basalt", 0.12)
        hexa(b, [(x - w / 2, -w / 2, 2.8), (x + w / 2, -w / 2, 2.8), (x + w / 2, w / 2, 2.8), (x - w / 2, w / 2, 2.8)],
             [(x - w / 2 + 0.12, -w / 2 + 0.12, jamb_h - 1.2), (x + w / 2 - 0.12, -w / 2 + 0.12, jamb_h - 1.2), (x + w / 2 - 0.12, w / 2 - 0.12, jamb_h - 1.2),
              (x - w / 2 + 0.12, w / 2 - 0.12, jamb_h - 1.2)], "Basalt", 0.14)
        # Shallow fluting bands on the shaft faces (real relief, not paint).
        for k in range(3):
            z = 5 + k * (jamb_h - 8) / 3
            b.box((x, 0, z), (w + 0.16, w + 0.16, 0.4), "AshStone", 0.06)
        b.box((x, 0, jamb_h - 0.6), (w + 1.4, w + 1.4, 1.2), "AshStone", 0.15)
    span = 2 * half + w + 1.6
    # The lintel, cracked through and slipped; the name tablet on both faces.
    gap = 2.4
    for side, (x0, x1) in ((-1, (-span / 2, gap / 2 - 0.2)), (1, (gap / 2 + 0.2, span / 2))):
        drop = 0.0 if side < 0 else 0.35
        b.box(((x0 + x1) / 2, 0, lintel_z + 1.4 - drop), (x1 - x0, depth, 2.8), "Basalt", 0.15, (0, radians(-1.4 if side > 0 else 0), 0))
    b.box((0, 0, lintel_z + 3.3), (span + 1.2, depth + 0.7, 0.9), "AshStone", 0.15)
    for s in (-1, 1):
        b.box((0, s * (depth / 2 + 0.12), lintel_z + 1.5), (9.0, 0.3, 2.2), "Bronze", 0.06)
        for k in range(5):
            b.box((-3.2 + k * 1.6, s * (depth / 2 + 0.29), lintel_z + 1.5), (0.5, 0.06, 1.4), "Bronze", 0.02)
    if roof:
        # The low, dark champion arcade: an attic over the lintel and a ribbed roof slab reaching into the arena.
        b.box((0, 0, lintel_z + 3.75 + 2.4), (span - 2, depth, 4.8), "AshStone", 0.12)
        y0, y1 = -roof, depth / 2
        b.box((0, (y0 + y1) / 2, lintel_z - 0.05), (2 * half - jamb - 0.6, y1 - y0, 1.6), "Basalt", 0.12)
        for k in range(int((y1 - y0) // 2.2)):
            yy = y0 + 1.1 + k * 2.2
            b.box((0, yy, lintel_z - 1.0), (2 * half - jamb - 0.6, 0.5, 0.5), "Basalt", 0.06)
        for s in (-1, 1):
            b.box((s * (half - jamb / 2 - 0.5), (y0 + y1) / 2 - 0.6, lintel_z - 1.7), (0.9, y1 - y0 - 1.2, 1.0), "Basalt", 0.08)
    return b.finish()


def build_cenotaph(name):
    """B07 split cenotaph: a stepped basalt base and a black shaft cleft to its foot, the two halves leaning apart."""
    b = Builder(name, [blackstone(), ashstone(), bronze_mat()])
    rng = b.rng
    for k, (w, d) in enumerate(((70, 46), (58, 37), (48, 30))):
        b.box((0, 0, 2.2 + k * 4.4), (w, d, 4.4), "Basalt" if k else "AshStone", 0.35)
    base = 13.2
    for s in (-1, 1):
        height = 150 if s > 0 else 136
        segs = 9
        lean = 3.5 * s
        for j in range(segs):
            t0, t1 = j / segs, (j + 1) / segs
            z0, z1 = base + t0 * height, base + t1 * height
            jag0 = rng.uniform(-0.6, 0.6) if j else 0.0
            jag1 = rng.uniform(-0.6, 0.6)
            inner0 = s * (2.6 + t0 * 3.0 + jag0) + lean * t0
            inner1 = s * (2.6 + t1 * 3.0 + jag1) + lean * t1
            outer0 = s * (19.0 - t0 * 4.2) + lean * t0
            outer1 = s * (19.0 - t1 * 4.2) + lean * t1
            inset = 0.0
            d0, d1 = 11.0 - t0 * 2.4 - inset, 11.0 - t1 * 2.4 - inset
            top1 = z1 - 0.12
            if j == segs - 1:
                # Snapped crowns: a slanting break, higher at the outer edge.
                top_in, top_out = z1 - (9 if s < 0 else 4), z1
            else:
                top_in = top_out = top1
            xs0 = sorted((inner0, outer0))
            xs1 = sorted((inner1, outer1))
            zi, zo = (top_in, top_out) if s > 0 else (top_out, top_in)
            hexa(b, [(xs0[0], -d0, z0), (xs0[1], -d0, z0), (xs0[1], d0, z0), (xs0[0], d0, z0)],
                 [(xs1[0], -d1, zi if s > 0 else zo), (xs1[1], -d1, zo if s > 0 else zi), (xs1[1], d1, zo if s > 0 else zi), (xs1[0], d1, zi if s > 0 else zo)],
                 "Basalt", 0.3)
        # Fallen shards at the foot of the cleft.
    for i in range(6):
        b.box((rng.uniform(-6, 6), rng.uniform(-20, -13), 14.2), (rng.uniform(2, 5), rng.uniform(2, 4), rng.uniform(1.2, 2.6)), "Basalt", 0.2,
              (radians(rng.uniform(-20, 20)), radians(rng.uniform(-20, 20)), radians(rng.uniform(0, 180))))
    # One surviving bronze band, torn where the stone split.
    b.box((11.5 + 1.75, 0, base + 70), (8.6, 20.6, 1.4), "Bronze", 0.1)
    return b.finish()


def build_weapons(name):
    """B10 the order's last stand: spears driven into the ash, a snapped jian, a half-buried shield."""
    b = Builder(name, [fk.timber("Z"), bronze_mat(), fk.iron(), ash()])
    rng = b.rng
    for i in range(4):
        foot = Vector((rng.uniform(-2.2, 2.2), rng.uniform(-1.6, 1.6), -0.6))
        tip = foot + Vector((rng.uniform(-1.4, 1.4), rng.uniform(-1.4, 1.4), rng.uniform(4.2, 5.6)))
        snap = rng.random() < 0.4
        end = foot + (tip - foot) * (0.62 if snap else 1.0)
        b.cylinder(foot, end, 0.12, 8, "TimberZ")
        if not snap:
            axis = (tip - foot).normalized()
            b.cylinder(end - axis * 0.25, end + axis * 0.15, 0.17, 8, "Bronze")
            b.cylinder(end + axis * 0.1, end + axis * 1.35, 0.3, 4, "Bronze", 0.0)
    # Snapped jian, blade down in the ash.
    b.box((1.6, 1.2, 0.9), (0.5, 0.1, 2.6), "Iron", 0.03, (radians(8), radians(14), radians(30)))
    b.box((1.86, 1.08, 2.25), (1.3, 0.3, 0.22), "Bronze", 0.05, (radians(8), radians(14), radians(30)))
    b.cylinder((1.9, 1.05, 2.3), (2.1, 0.95, 3.4), 0.13, 8, "Bronze")
    # A round shield fallen against a mound, half under the ash.
    c = Vector((-1.4, 1.6, 0.55))
    n = Vector((0.25, -0.45, 0.86)).normalized()
    b.cylinder(c - n * 0.1, c + n * 0.12, 1.65, 28, "Bronze")
    b.cylinder(c + n * 0.1, c + n * 0.3, 0.38, 14, "Iron")
    b.torus(c + n * 0.12, n.orthogonal(), n.cross(n.orthogonal()), 1.62, 0.1, 32, 6, "Iron")
    for _ in range(3):
        mound(b, (rng.uniform(-2.5, 2.5), rng.uniform(-1.8, 1.8), 0.0), (rng.uniform(1.4, 2.6), rng.uniform(1.2, 2.0), rng.uniform(0.35, 0.7)), "Ash", 0.15, 0.6)
    return b.finish()


def build_reeds(name):
    """Sparse silver reeds for the outer ash banks (R07): bent triangular blades and a few plumes."""
    b = Builder(name, [reed(), ash()])
    rng = b.rng
    bm = b.bm
    for i in range(58):
        r = 2.4 * rng.random() ** 0.7
        a = rng.uniform(0, tau)
        foot = Vector((cos(a) * r, sin(a) * r, -0.2))
        h = rng.uniform(2.4, 4.8)
        yaw = rng.uniform(0, tau)
        lean = Vector((cos(a), sin(a), 0)) * rng.uniform(0.25, 0.6) + Vector((0.35, 0.15, 0))
        rings = []
        steps = 4
        for j in range(steps):
            t = j / steps
            c = foot + Vector((0, 0, t * h)) + lean * (t ** 1.7) * h * 0.45
            w = 0.1 * (1 - t) + 0.015
            rings.append([bm.verts.new(c + Vector((cos(yaw + k * tau / 3) * w, sin(yaw + k * tau / 3) * w * 0.55, 0))) for k in range(3)])
        tip = bm.verts.new(foot + Vector((0, 0, h)) + lean * h * 0.45)
        faces = []
        for j in range(steps - 1):
            lo, hi = rings[j], rings[j + 1]
            for k in range(3):
                faces.append(bm.faces.new((lo[k], lo[(k + 1) % 3], hi[(k + 1) % 3], hi[k])))
        for k in range(3):
            faces.append(bm.faces.new((rings[-1][k], rings[-1][(k + 1) % 3], tip)))
        b.paint(faces, "Reed", False, True)
        if i % 7 == 0:
            b.stud(tip.co + Vector((0, 0, 0.35)), 0.16, "Reed", 1, 3.2)
    mound(b, (0, 0, 0), (2.9, 2.6, 0.45), "Ash", 0.12, 0.6)
    return b.finish()


def build_votive(name):
    """B10 worn votive figure: a kneeling robed disciple, hands joined, on a sunken plinth, an empty bronze bowl before it."""
    b = Builder(name, [ashstone(), basalt(), bronze_mat()])
    b.box((0, 0, 0.3), (2.8, 2.4, 0.9), "Basalt", 0.14)
    robe = fk.smooth_profile([(0, 0.75, 1), (1.18, 0.75, 1), (1.24, 1.15), (1.08, 1.9), (0.86, 2.6), (0.72, 3.0), (0.48, 3.3), (0, 3.36, 1)], 3)
    b.lathe(robe, 22, "AshStone", center=(0, 0.1, 0), wobble=0.05)
    b.lump((0, 0.08, 3.18), (0.8, 0.52, 0.3), 2, "AshStone", 0.05, 1.2)
    b.lump((0, 0.02, 3.82), (0.4, 0.43, 0.5), 3, "AshStone", 0.07, 1.6)
    b.lump((0, -0.62, 2.45), (0.34, 0.26, 0.42), 2, "AshStone", 0.06, 1.5)
    b.lump((0, -0.95, 1.05), (1.05, 0.5, 0.28), 2, "AshStone", 0.07, 1.2, floor=0.75)
    b.lathe([(0, 0.76, 1), (0.36, 0.76, 1), (0.46, 0.98), (0.5, 1.02, 1), (0.42, 1.0, 1), (0.3, 0.86), (0, 0.84, 1)], 16, "Bronze", center=(0, -1.6, 0))
    return b.finish()


def build_ashbank(name):
    """B09 coarse ash bank against the cavea foot: a long drift with buried fractured blocks and a column drum."""
    b = Builder(name, [ash(), basalt(), ashstone()])
    rng = b.rng
    b.lump((0, 0, 0), (14.5, 5.2, 2.6), 4, "Ash", 1.25, 0.16, floor=0)
    for i in range(5):
        b.box((rng.uniform(-12, 12), rng.uniform(-4, 4), rng.uniform(0.2, 1.4)), (rng.uniform(1.6, 3.2), rng.uniform(1.4, 2.6), rng.uniform(1.0, 2.0)),
              "Basalt", 0.2, (radians(rng.uniform(-25, 25)), radians(rng.uniform(-25, 25)), radians(rng.uniform(0, 180))))
    b.cylinder((-6.5, -2.6, 0.9), (-3.4, -1.0, 1.1), 1.2, 16, "AshStone")
    return b.finish()


PIECES = {
    "Covenant_SeatFront_A": lambda: build_seat("Covenant_SeatFront_A", False),
    "Covenant_SeatFront_B": lambda: build_seat("Covenant_SeatFront_B", True),
    "Covenant_ArcadeBay": lambda: build_arcade("Covenant_ArcadeBay", False),
    "Covenant_ArcadeBay_Broken": lambda: build_arcade("Covenant_ArcadeBay_Broken", True),
    "Covenant_FacadeBay": lambda: build_facade("Covenant_FacadeBay"),
    "Covenant_VictorGate": lambda: build_gate("Covenant_VictorGate", 4.0, 16.0, 20.0, 19.2, 4.6, 0),
    "Covenant_ChampionGate": lambda: build_gate("Covenant_ChampionGate", 6.0, 18.0, 28.0, 14.0, 6.4, 9.0),
    "Covenant_Cenotaph": lambda: build_cenotaph("Covenant_Cenotaph"),
    "Covenant_WeaponFragments": lambda: build_weapons("Covenant_WeaponFragments"),
    "Covenant_ReedClump": lambda: build_reeds("Covenant_ReedClump"),
    "Covenant_VotiveFigure": lambda: build_votive("Covenant_VotiveFigure"),
    "Covenant_AshBank": lambda: build_ashbank("Covenant_AshBank"),
}
SMALL = {"Covenant_WeaponFragments", "Covenant_ReedClump", "Covenant_VotiveFigure"}


def fresh():
    scene = fk.fresh()
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            used = 0
            for device in prefs.devices:
                device.use = device.type == kind
                used += device.use
            if used:
                scene.cycles.device = "GPU"
                break
        except (TypeError, ValueError):
            continue
    return scene


def main():
    arguments = sys.argv[sys.argv.index("--") + 1:]
    mode, out = arguments[0], Path(arguments[1]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    wanted = arguments[2:] or list(PIECES)
    report = {}
    for name in wanted:
        fresh()
        fk.CURRENT.clear()
        obj = PIECES[name]()
        obj.name = name + "__Covenant"
        fk.NODE_REGISTRY[obj.data.name] = list(fk.CURRENT)
        obj.data.calc_loop_triangles()
        lo = min((obj.matrix_world @ Vector(c)).z for c in obj.bound_box)
        print("PIECE", name, "tris", len(obj.data.loop_triangles), "dims", [round(d, 2) for d in obj.dimensions], "min z", round(lo, 3), flush=True)
        if mode == "preview":
            fk.preview(obj, out)
        else:
            fk.MAP_SIZE = 1024 if name in SMALL else 2048
            report[name] = fk.bake(obj, out)
            corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
            report[name]["boundsMin"] = [round(min(c[i] for c in corners), 3) for i in range(3)]
            report[name]["boundsMax"] = [round(max(c[i] for c in corners), 3) for i in range(3)]
            print("BAKED", json.dumps(report[name]), flush=True)
    if mode == "bake":
        path = out / "manifest.json"
        existing = json.loads(path.read_text()) if path.exists() else {}
        existing.update(report)
        path.write_text(json.dumps(existing, indent=2) + "\n")


if __name__ == "__main__":
    main()

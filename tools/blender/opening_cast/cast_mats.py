"""Procedural PBR materials for the opening enemy cast (monk, swordsman, warden).

Reuses Zhao v2's node builder and its iron/bronze/leather/steel/cord recipes, and adds the cloth, skin and
fittings of the fallen monastery family. Every material ends in OUT_COLOR / OUT_ROUGH / OUT_METAL so the
shared bake reads exactly what the renders show.
"""
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "zhao_v2"))
import mats as zm  # noqa: E402

G = zm.G


def vmath(g, op, a, b):
    m = g.n("ShaderNodeVectorMath", operation=op)
    g.link(a, m.inputs[0])
    m.inputs[1].default_value = b
    return m.outputs[0]


def patchwork(g, a, b, fade, cells=(4, 3), seam=(0.03, 0.014, 0.01), burn=0.0):
    """Kasaya field cloth: the detail UV is cut into stitched patches, each its own dye lot, faded on top,
    muddy at the hem; `burn` adds scorched, blackened tears (the fallen monk's robe)."""
    uv = g.uv()
    warp = g.n("ShaderNodeTexNoise")
    warp.inputs["Scale"].default_value = 3.0
    g.link(uv, warp.inputs["Vector"])
    cv = g.n("ShaderNodeVectorMath", operation="MULTIPLY_ADD")
    g.link(warp.outputs["Color"], cv.inputs[0])
    cv.inputs[1].default_value = (0.35, 0.35, 0.0)
    g.link(g.scale(uv, (*cells, 1)), cv.inputs[2])
    cv = cv.outputs[0]
    lot = g.noise(41.0, 1, 0.5, vmath(g, "SNAP", cv, (1, 1, 1)))
    col = g.mix(a, b, g.rng(lot, 0.3, 0.7))
    big = g.noise(4, 5, 0.55, dist=0.4)
    col = g.mix(col, b, g.rng(big, 0.45, 0.75, 0, 0.5))
    col = g.mix(col, fade, g.math("MULTIPLY", g.facing_up(), g.rng(g.noise(9, 4), 0.4, 0.65, 0.15, 0.6), True))
    s = g.sep(cv)
    fu = g.math("ABSOLUTE", g.math("SUBTRACT", g.math("FRACT", s[0]), 0.5))
    fv = g.math("ABSOLUTE", g.math("SUBTRACT", g.math("FRACT", s[1]), 0.5))
    seams = g.math("MAXIMUM", g.rng(fu, 0.475, 0.497), g.rng(fv, 0.47, 0.495))
    col = g.mix(col, seam, g.math("MULTIPLY", seams, 0.4))
    low = g.height_z(-1.4, -2.3)
    mud = g.math("MULTIPLY", low, g.rng(g.noise(14, 8, 0.7), 0.35, 0.6, 0.3, 1.0), True)
    col = g.mix(col, (0.035, 0.026, 0.02), mud)
    if burn:
        scorch = g.rng(g.noise(6, 8, 0.7, dist=0.6), 0.62, 0.7, 0, burn)
        col = g.mix(col, (0.012, 0.009, 0.008), scorch)
    w1 = g.wave(300, None, 0.5, "BANDS", "X")
    w2 = g.wave(300, None, 0.5, "BANDS", "Z")
    weave = g.math("MULTIPLY", g.math("ADD", w1, w2), 0.5)
    col = g.mix(col, g.rng(weave, 0, 1, 0.85, 1.05), 1.0, blend="MULTIPLY")
    col = g.mix(col, g.rng(g.cavity(0.06), 0.1, 1.0, 0.45, 1.0), 1.0, blend="MULTIPLY")
    rough = g.rng(big, 0.3, 0.7, 0.8, 0.95)
    h = g.math("ADD", g.math("MULTIPLY", weave, 0.25), g.math("MULTIPLY", seams, -0.5))
    h = g.math("ADD", h, g.math("MULTIPLY", g.noise(30, 6, 0.6), 0.4))
    g.finish(col, rough, 0.0, h, bump=0.3, dist=0.003, sheen=0.4)


def wrap_linen(g, a, b, grime, sheen=0.35):
    """Hand-wound linen strips: bands along the detail UV's v, grime soaked into the folds and the low end."""
    uv = g.uv()
    s = g.sep(uv)
    band = g.math("SINE", g.math("MULTIPLY", s[1], 6.2832 * 7))
    col = g.mix(a, b, g.rng(g.noise(12, 5, 0.6), 0.3, 0.7))
    col = g.mix(col, grime, g.rng(band, -0.2, -0.95, 0, 0.55))
    col = g.mix(col, grime, g.math("MULTIPLY", g.rng(g.noise(5, 6, 0.7), 0.5, 0.72), 0.7))
    w = g.wave(420, None, 0.4, "BANDS", "Z")
    col = g.mix(col, g.rng(w, 0, 1, 0.88, 1.04), 1.0, blend="MULTIPLY")
    col = g.mix(col, g.rng(g.cavity(0.04), 0.1, 1.0, 0.4, 1.0), 1.0, blend="MULTIPLY")
    h = g.math("ADD", g.math("MULTIPLY", band, 0.4), g.math("MULTIPLY", w, 0.15))
    g.finish(col, g.rng(band, -1, 1, 0.92, 0.82), 0.0, h, bump=0.35, dist=0.003, sheen=sheen)


def ash_skin(g, scar=False):
    """Weathered, ash-pale skin of a monk who stopped eating at the temple: sun-dark on top, sallow below,
    dark corrupted veins rising through the right arm and chest, pores and fine lines."""
    co = g.coord()
    base = g.mix((0.20, 0.125, 0.085), (0.13, 0.078, 0.052), g.rng(g.noise(18, 6), 0.3, 0.7))
    base = g.mix(base, (0.24, 0.10, 0.06), g.math("MULTIPLY", g.facing_up(), 0.3))            # sun and wind on top
    base = g.mix(base, (0.12, 0.10, 0.085), g.math("MULTIPLY", g.rng(g.noise(3, 3), 0.4, 0.7), 0.4))   # ashen, sallow
    # per-vertex weights from the head sculpt (absent elsewhere, reads 0): shaved-scalp and beard stubble, sooty sockets
    stub = g.n("ShaderNodeAttribute", attribute_name="stubble", attribute_type="GEOMETRY").outputs["Fac"]
    soot = g.n("ShaderNodeAttribute", attribute_name="soot", attribute_type="GEOMETRY").outputs["Fac"]
    dots = g.rng(g.noise(900, 2, 0.5), 0.42, 0.62, 0.45, 1.0)
    base = g.mix(base, (0.045, 0.042, 0.042), g.math("MULTIPLY", g.math("MULTIPLY", stub, dots), 0.85, True))
    base = g.mix(base, (0.045, 0.026, 0.026), g.math("MULTIPLY", soot, 0.75, True))
    vein = g.rng(g.voronoi(26, "DISTANCE_TO_EDGE", g.scale(co, (1, 1, 0.45))), 0.035, 0.0)
    vmask = g.math("MULTIPLY", vein, g.rng(g.noise(2.2, 3, 0.5), 0.5, 0.7), True)
    vmask = g.math("MULTIPLY", vmask, g.height_z(1.12, 0.98))   # corruption climbs the chest, never crazes the face
    base = g.mix(base, (0.07, 0.025, 0.03), g.math("MULTIPLY", vmask, 0.55))
    if scar:   # healed burn: darker, waxy, faintly purple
        base = g.mix(base, (0.15, 0.065, 0.055), 0.9)
    pores = g.voronoi(900, "F1")
    wr = g.noise(60, 3, 0.5, g.scale(co, (1, 1, 6)))
    col = g.mix(base, g.rng(g.cavity(0.02), 0.2, 1.0, 0.5, 1.0), 1.0, blend="MULTIPLY")
    rough = 0.35 if scar else g.rng(g.noise(20, 4), 0.3, 0.7, 0.5, 0.7)
    h = g.math("ADD", g.math("MULTIPLY", pores, 0.25), g.math("MULTIPLY", wr, 0.6))
    h = g.math("ADD", h, g.math("MULTIPLY", vmask, 0.4))
    g.finish(col, rough, 0.0, h, bump=0.3, dist=0.002, sss=0.08, spec=0.35)


def ember_eye(g):
    v = g.sep(g.uv())[1]
    col = g.mix((0.10, 0.07, 0.045), (1.0, 0.36, 0.05), g.rng(v, 0.34, 0.26))   # bloodshot-dark sclera, burning ember iris
    col = g.mix(col, (0.02, 0.004, 0.0), g.rng(v, 0.12, 0.09))
    g.finish(col, 0.1, 0.0, None, coat=1.0, coat_rough=0.02)


def ember(g):
    """Solid burning ember (the swordsman's eyes in the helmet's shadow): white-hot core, red rim, no eyeball."""
    col = g.mix((1.0, 0.42, 0.08), (0.75, 0.10, 0.02), g.rng(g.edges(0.5, 0.56), 0.0, 1.0))
    g.finish(col, 0.25, 0.0, None)


def bead(g, cracked=False):
    grain = g.wave(18, g.scale(g.coord(), (6, 6, 0.4)), 5.0, "RINGS", "Z")
    col = g.mix((0.050, 0.024, 0.012), (0.022, 0.011, 0.007), g.rng(g.noise(9, 4), 0.3, 0.7))
    col = g.mix(col, (0.016, 0.008, 0.005), g.math("MULTIPLY", grain, 0.35))
    col = g.mix(col, (0.11, 0.065, 0.035), g.math("MULTIPLY", g.edges(0.5, 0.56), 0.6))   # hand polish
    h = g.math("MULTIPLY", grain, 0.15)
    if cracked:
        crack = g.rng(g.voronoi(14, "DISTANCE_TO_EDGE"), 0.05, 0.0)
        col = g.mix(col, (0.55, 0.12, 0.025), crack)
        h = g.math("ADD", h, g.math("MULTIPLY", crack, -0.8))
    g.finish(col, 0.32, 0.0, h, bump=0.25, dist=0.002, coat=0.5, coat_rough=0.2)


def straw(g):
    tw = g.wave(140, None, 1.5, "BANDS", "Y")
    col = g.mix((0.26, 0.19, 0.085), (0.13, 0.085, 0.04), g.rng(tw, 0.2, 0.8))
    col = g.mix(col, (0.05, 0.035, 0.02), g.rng(g.noise(10, 6, 0.7), 0.5, 0.7))
    col = g.mix(col, g.rng(g.cavity(0.03), 0.1, 1.0, 0.4, 1.0), 1.0, blend="MULTIPLY")
    g.finish(col, 0.85, 0.0, tw, bump=0.5, dist=0.002)


def douli(g, under=False):
    """Woven bamboo hat: radial splints over-under concentric rings (detail UV: u around, v apex to rim), sun-greyed on
    top, rotting dark at the rim; the underside is kept dark so the face stays in shadow under any lighting."""
    s = g.sep(g.uv())
    spl = g.math("SINE", g.math("MULTIPLY", s[0], 6.2832 * 260))
    ring = g.math("SINE", g.math("MULTIPLY", g.math("ADD", s[1], g.math("MULTIPLY", g.noise(9, 3), 0.01)), 6.2832 * 38))
    weave = g.math("MULTIPLY", g.math("ADD", g.math("MULTIPLY", spl, ring), 1.0), 0.5)
    col = g.mix((0.13, 0.095, 0.05), (0.06, 0.045, 0.026), g.rng(g.noise(8, 5), 0.3, 0.7))
    col = g.mix(col, (0.085, 0.08, 0.072), g.rng(g.noise(3, 4), 0.45, 0.7, 0.0, 0.65))   # sun- and rain-greyed
    col = g.mix(col, (0.022, 0.017, 0.012), g.math("MULTIPLY", g.rng(s[1], 0.6, 1.0), g.rng(g.noise(10, 6, 0.7), 0.4, 0.65), True))
    col = g.mix(col, g.rng(weave, 0, 1, 0.78, 1.04), 1.0, blend="MULTIPLY")
    if under:
        col = g.mix(col, (0.0, 0.0, 0.0), 0.72)
    g.finish(col, 0.82, 0.0, weave, bump=0.5, dist=0.003)


def straw_cape(g):
    """Rain-cape straw: long strands along the detail UV's v, sun-bleached on the shoulders, rotting toward the hem."""
    s = g.sep(g.uv())
    strand = g.math("SINE", g.math("MULTIPLY", g.math("ADD", s[0], g.math("MULTIPLY", g.noise(6, 3), 0.02)), 6.2832 * 220))
    col = g.mix((0.19, 0.145, 0.07), (0.085, 0.062, 0.032), g.rng(g.noise(14, 5, 0.6), 0.3, 0.7))
    col = g.mix(col, (0.115, 0.105, 0.09), g.math("MULTIPLY", g.facing_up(), 0.55))
    col = g.mix(col, (0.035, 0.028, 0.02), g.math("MULTIPLY", g.rng(s[1], 0.55, 1.0), g.rng(g.noise(7, 6, 0.7), 0.35, 0.65), True))
    col = g.mix(col, g.rng(strand, -1, 1, 0.65, 1.05), 1.0, blend="MULTIPLY")
    col = g.mix(col, g.rng(g.cavity(0.04), 0.1, 1.0, 0.4, 1.0), 1.0, blend="MULTIPLY")
    g.finish(col, 0.88, 0.0, strand, bump=0.45, dist=0.003, sheen=0.3)


def rope(g, a=(0.20, 0.15, 0.08), b=(0.08, 0.055, 0.03)):
    tw = g.wave(260, None, 2.0, "BANDS", "X")
    col = g.mix(a, b, g.rng(tw, 0.2, 0.8))
    col = g.mix(col, g.rng(g.cavity(0.03), 0.1, 1.0, 0.45, 1.0), 1.0, blend="MULTIPLY")
    g.finish(col, 0.85, 0.0, tw, bump=0.45, dist=0.002, sheen=0.3)


BUILDERS = {
    "KASAYA": lambda g: patchwork(g, (0.085, 0.030, 0.018), (0.045, 0.021, 0.015), (0.12, 0.085, 0.06), burn=1.0),
    "SHROUD": lambda g: wrap_linen(g, (0.036, 0.029, 0.023), (0.022, 0.018, 0.015), (0.008, 0.006, 0.005), 0.05),
    "DOULI": douli, "DOULI_IN": lambda g: douli(g, True), "STRAW_CAPE": straw_cape,
    "ROBE": lambda g: zm.cloth(g, (0.10, 0.085, 0.065), (0.055, 0.047, 0.038), (0.16, 0.14, 0.11), weave=380),
    "TROUSER": lambda g: zm.cloth(g, (0.028, 0.026, 0.024), (0.014, 0.013, 0.012), (0.06, 0.055, 0.05)),
    "LINEN": lambda g: wrap_linen(g, (0.21, 0.18, 0.14), (0.15, 0.125, 0.095), (0.05, 0.038, 0.028)),
    "SKIN": ash_skin, "SCAR": lambda g: ash_skin(g, True), "EYE": ember_eye, "EMBER": ember,
    "BEAD": bead, "BEAD_CRACK": lambda g: bead(g, True),
    "STRAW": straw, "ROPE": rope, "CORD": zm.cord,
    "IRON": zm.iron, "BRONZE": zm.bronze, "LEATHER": zm.leather, "STEEL": zm.steel, "LACQUER": zm.lacquer,
    "HAIR": zm.hair, "HAIR_CORE": lambda g: zm.hair(g, True), "WOOD_RED": zm.wood_red, "POLE": zm.pole,
    # Cursed Swordsman: near-black guard's robe, a blood-crimson silk scarf, crimson lacing through the lamellar
    "ROBE_DARK": lambda g: zm.cloth(g, (0.020, 0.020, 0.026), (0.010, 0.010, 0.013), (0.045, 0.044, 0.048), weave=360),
    "SCARF": lambda g: zm.cloth(g, (0.15, 0.016, 0.014), (0.062, 0.009, 0.008), (0.17, 0.065, 0.05), weave=420),
    "LACE": lambda g: rope(g, (0.22, 0.025, 0.02), (0.08, 0.012, 0.01)),
}


def make(prefix, name):
    mat = bpy.data.materials.new(f"{prefix}_{name}")
    mat.use_nodes = True
    BUILDERS[name](G(mat))
    return mat


def make_all(prefix, names=None):
    return {k: make(prefix, k) for k in (names or BUILDERS)}

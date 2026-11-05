"""PBR materials shared by the three armour sets. Palette taken from the swatches on the concept sheets:
cinnabar cloth, charcoal cloth, leather, iron, bronze, jade. Same OUT_* graph contract as zhao_v2/mats.py,
so the bake reads exactly what the renders show.
"""
import bpy

from mats import G  # zhao_v2/mats.py node-graph builder


def cinnabar(g):
    big = g.noise(4, 5, 0.55, dist=0.5)
    col = g.mix((0.205, 0.019, 0.017), (0.095, 0.011, 0.012), g.rng(big, 0.3, 0.72))
    # the sheet's woven mottling: small dark flecks and a worn, sun-faded top
    fleck = g.rng(g.voronoi(30, "F1"), 0.0, 0.26, 1.0, 0.0)
    col = g.mix(col, (0.030, 0.008, 0.010), g.math("MULTIPLY", fleck, g.rng(g.noise(11, 4), 0.40, 0.60, 0.25, 1.0)))
    col = g.mix(col, (0.27, 0.060, 0.045), g.math("MULTIPLY", g.facing_up(), g.rng(g.noise(9, 4), 0.4, 0.65, 0.05, 0.4), True))
    low = g.height_z(-1.6, -2.3)
    col = g.mix(col, (0.035, 0.022, 0.018), g.math("MULTIPLY", low, g.rng(g.noise(14, 8, 0.7), 0.35, 0.6, 0.2, 0.9), True))
    w1, w2 = g.wave(300, None, 0.4, "BANDS", "X"), g.wave(300, None, 0.4, "BANDS", "Z")
    weave = g.math("MULTIPLY", g.math("ADD", w1, w2), 0.5)
    col = g.mix(col, g.rng(weave, 0, 1, 0.82, 1.08), 1.0, blend="MULTIPLY")
    col = g.mix(col, g.rng(g.cavity(0.06), 0.1, 1.0, 0.42, 1.0), 1.0, blend="MULTIPLY")
    h = g.math("ADD", g.math("MULTIPLY", weave, 0.3), g.math("MULTIPLY", g.noise(30, 6, 0.6), 0.5))
    g.finish(col, g.rng(big, 0.3, 0.7, 0.78, 0.94), 0.0, h, bump=0.28, dist=0.003, sheen=0.45)


def charcoal(g, plaid=False, lift=1.0):
    big = g.noise(5, 5, 0.55, dist=0.4)
    col = g.mix((0.066 * lift, 0.066 * lift, 0.068 * lift), (0.030 * lift, 0.030 * lift, 0.032 * lift), g.rng(big, 0.3, 0.72))
    if plaid:  # the trousers' fine window-pane check, in faded tan
        lines_a = g.rng(g.wave(1.5, None, 0.2, "BANDS", "X", "SIN"), 0.955, 1.0)
        lines_b = g.rng(g.wave(1.5, None, 0.2, "BANDS", "Z", "SIN"), 0.955, 1.0)
        pane = g.math("MAXIMUM", lines_a, lines_b)
        col = g.mix(col, (0.20, 0.135, 0.075), g.math("MULTIPLY", pane, g.rng(g.noise(16, 4), 0.35, 0.65, 0.35, 0.8)))
    col = g.mix(col, (0.070, 0.066, 0.060), g.math("MULTIPLY", g.facing_up(), g.rng(g.noise(9, 4), 0.4, 0.65, 0.05, 0.45), True))
    low = g.height_z(-1.9, -2.6)
    col = g.mix(col, (0.030, 0.024, 0.018), g.math("MULTIPLY", low, g.rng(g.noise(14, 8, 0.7), 0.35, 0.6, 0.2, 0.8), True))
    w1, w2 = g.wave(340, None, 0.5, "BANDS", "X"), g.wave(340, None, 0.5, "BANDS", "Z")
    weave = g.math("MULTIPLY", g.math("ADD", w1, w2), 0.5)
    col = g.mix(col, g.rng(weave, 0, 1, 0.80, 1.15), 1.0, blend="MULTIPLY")
    col = g.mix(col, g.rng(g.cavity(0.06), 0.1, 1.0, 0.45, 1.0), 1.0, blend="MULTIPLY")
    h = g.math("ADD", g.math("MULTIPLY", weave, 0.3), g.math("MULTIPLY", g.noise(30, 6, 0.6), 0.5))
    g.finish(col, g.rng(big, 0.3, 0.7, 0.8, 0.96), 0.0, h, bump=0.28, dist=0.003, sheen=0.4)


def ash(g):
    big = g.noise(4, 6, 0.6, dist=0.6)
    col = g.mix((0.40, 0.35, 0.29), (0.24, 0.205, 0.165), g.rng(big, 0.3, 0.72))
    stain = g.rng(g.noise(7, 8, 0.65), 0.52, 0.70)
    col = g.mix(col, (0.11, 0.09, 0.075), g.math("MULTIPLY", stain, 0.55))
    low = g.height_z(-0.9, -1.9)
    col = g.mix(col, (0.055, 0.042, 0.032), g.math("MULTIPLY", low, g.rng(g.noise(13, 8, 0.7), 0.35, 0.6, 0.2, 0.95), True))
    w1, w2 = g.wave(260, None, 0.5, "BANDS", "X"), g.wave(260, None, 0.5, "BANDS", "Z")
    weave = g.math("MULTIPLY", g.math("ADD", w1, w2), 0.5)
    col = g.mix(col, g.rng(weave, 0, 1, 0.82, 1.12), 1.0, blend="MULTIPLY")
    col = g.mix(col, g.rng(g.cavity(0.06), 0.1, 1.0, 0.42, 1.0), 1.0, blend="MULTIPLY")
    h = g.math("ADD", g.math("MULTIPLY", weave, 0.35), g.math("MULTIPLY", g.noise(26, 6, 0.6), 0.6))
    g.finish(col, g.rng(big, 0.3, 0.7, 0.82, 0.97), 0.0, h, bump=0.32, dist=0.003, sheen=0.35)


def pale(g):
    big = g.noise(6, 5)
    col = g.mix((0.46, 0.44, 0.40), (0.25, 0.235, 0.21), g.rng(big, 0.3, 0.72))
    col = g.mix(col, g.rng(g.cavity(0.05), 0.1, 1.0, 0.45, 1.0), 1.0, blend="MULTIPLY")
    g.finish(col, 0.9, 0.0, g.noise(40, 5), bump=0.15, dist=0.002, sheen=0.3)


def black_iron(g):
    """Forged black iron: hammered, darkened, polished to pale steel only on worn edges."""
    hammer = g.voronoi(34, "SMOOTH_F1")
    big = g.noise(7, 6)
    col = g.mix((0.032, 0.031, 0.031), (0.013, 0.013, 0.014), g.rng(big, 0.35, 0.7))
    run = g.noise(9, 6, 0.6, g.scale(g.coord(), (18, 18, 2.2)))
    rust = g.math("MULTIPLY", g.rng(run, 0.56, 0.74), g.rng(g.cavity(0.08), 0.95, 0.4), True)
    col = g.mix(col, (0.075, 0.032, 0.016), g.math("MULTIPLY", rust, 0.75))
    edge = g.math("MULTIPLY", g.edges(0.525, 0.60), g.rng(g.noise(25, 6), 0.45, 0.7), True)
    col = g.mix(col, (0.115, 0.11, 0.105), edge)
    col = g.mix(col, g.rng(g.cavity(0.05), 0.15, 1.0, 0.4, 1.0), 1.0, blend="MULTIPLY")
    rough = g.mix(g.rng(big, 0.3, 0.7, 0.44, 0.62), 0.86, rust, color=False)
    rough = g.mix(rough, 0.34, edge, color=False)
    metal = g.mix(0.92, 0.25, rust, color=False)
    h = g.math("ADD", g.math("MULTIPLY", hammer, 0.8), g.math("MULTIPLY", rust, 0.3))
    g.finish(col, rough, metal, h, bump=0.28, dist=0.004)


def bronze(g):
    big = g.noise(14, 6)
    hammer = g.voronoi(90, "SMOOTH_F1")
    col = g.mix((0.235, 0.145, 0.058), (0.092, 0.058, 0.027), g.rng(big, 0.3, 0.7))
    pat = g.rng(g.cavity(0.03), 0.9, 0.35)
    col = g.mix(col, (0.040, 0.030, 0.018), g.math("MULTIPLY", pat, 0.85))     # dark in recesses, as on the sheet
    edge = g.edges(0.505, 0.55)
    col = g.mix(col, (0.44, 0.31, 0.15), g.math("MULTIPLY", edge, 0.7))
    rough = g.mix(g.rng(big, 0.3, 0.7, 0.42, 0.58), 0.28, edge, color=False)
    g.finish(col, rough, g.mix(1.0, 0.4, pat, color=False), g.math("ADD", big, g.math("MULTIPLY", hammer, 0.5)), bump=0.2)


def leather(g):
    big = g.noise(10, 6)
    crease = g.rng(g.voronoi(18, "DISTANCE_TO_EDGE"), 0.0, 0.05, 1.0, 0.0)
    grain = g.voronoi(220, "F1")
    col = g.mix((0.092, 0.044, 0.024), (0.034, 0.018, 0.012), g.rng(big, 0.3, 0.7))
    col = g.mix(col, (0.030, 0.015, 0.010), g.math("MULTIPLY", crease, 0.6))
    edge = g.edges(0.54, 0.62)
    col = g.mix(col, (0.15, 0.09, 0.052), g.math("MULTIPLY", edge, 0.7))
    col = g.mix(col, g.rng(g.cavity(0.05), 0.1, 1.0, 0.4, 1.0), 1.0, blend="MULTIPLY")
    rough = g.mix(g.rng(big, 0.3, 0.7, 0.46, 0.7), 0.32, edge, color=False)
    h = g.math("ADD", grain, g.math("ADD", g.math("MULTIPLY", big, 0.4), g.math("MULTIPLY", crease, -0.6)))
    g.finish(col, rough, 0.0, h, bump=0.24, dist=0.002)


def lace(g):
    tw = g.wave(260, None, 2.0, "BANDS", "X")
    col = g.mix((0.26, 0.070, 0.032), (0.090, 0.024, 0.014), g.rng(tw, 0.2, 0.8))
    g.finish(col, 0.8, 0.0, tw, bump=0.4, dist=0.002, sheen=0.3)


def jade(g):
    veins = g.rng(g.noise(5, 9, 0.62, dist=1.6), 0.46, 0.60)
    col = g.mix((0.33, 0.47, 0.40), (0.13, 0.25, 0.21), veins)
    col = g.mix(col, (0.60, 0.68, 0.62), g.rng(g.noise(9, 5, 0.5, dist=2.0), 0.62, 0.72, 0.0, 0.5))
    g.finish(col, 0.17, 0.0, None, spec=0.6)


def tassel(g):
    fine = g.wave(120, None, 0.3, "BANDS", "X")
    col = g.mix((0.34, 0.205, 0.075), (0.11, 0.066, 0.028), g.rng(fine, 0.25, 0.8))
    g.finish(col, 0.62, 0.15, fine, bump=0.5, dist=0.003)


def skin(g):
    # R137 G116 B94, FighterAppearance's skin tone, so hands match the head they share a body with
    big = g.noise(6, 5)
    col = g.mix((0.262, 0.178, 0.114), (0.190, 0.120, 0.078), g.rng(big, 0.3, 0.7))
    col = g.mix(col, g.rng(g.cavity(0.03), 0.2, 1.0, 0.6, 1.0), 1.0, blend="MULTIPLY")
    g.finish(col, g.rng(big, 0.3, 0.7, 0.48, 0.62), 0.0, g.noise(120, 4), bump=0.08, dist=0.001, sss=0.3)


def mantle(g):
    """Charcoal cloth with old red stains soaked into it, as on the Ashen sheet."""
    big = g.noise(5, 5, 0.55, dist=0.4)
    col = g.mix((0.09, 0.09, 0.092), (0.04, 0.04, 0.043), g.rng(big, 0.3, 0.72))
    stain = g.rng(g.noise(4, 9, 0.68, dist=0.8), 0.53, 0.63)
    speck = g.rng(g.noise(38, 6, 0.6), 0.35, 0.55, 0.45, 1.0)
    col = g.mix(col, (0.27, 0.026, 0.022), g.math("MULTIPLY", stain, speck))
    w1, w2 = g.wave(320, None, 0.5, "BANDS", "X"), g.wave(320, None, 0.5, "BANDS", "Z")
    weave = g.math("MULTIPLY", g.math("ADD", w1, w2), 0.5)
    col = g.mix(col, g.rng(weave, 0, 1, 0.80, 1.15), 1.0, blend="MULTIPLY")
    col = g.mix(col, g.rng(g.cavity(0.06), 0.1, 1.0, 0.45, 1.0), 1.0, blend="MULTIPLY")
    g.finish(col, g.rng(big, 0.3, 0.7, 0.8, 0.96), 0.0, g.math("MULTIPLY", weave, 0.4), bump=0.28, dist=0.003, sheen=0.4)


def boot_leather(g):
    big = g.noise(10, 6)
    col = g.mix((0.040, 0.024, 0.016), (0.014, 0.010, 0.009), g.rng(big, 0.3, 0.7))
    crease = g.rng(g.voronoi(14, "DISTANCE_TO_EDGE"), 0.0, 0.05, 1.0, 0.0)
    edge = g.edges(0.505, 0.56)
    col = g.mix(col, (0.11, 0.075, 0.05), g.math("MULTIPLY", edge, 0.6))
    col = g.mix(col, (0.05, 0.04, 0.03), g.math("MULTIPLY", g.height_z(-2.75, -3.0), 0.6))
    col = g.mix(col, g.rng(g.cavity(0.05), 0.1, 1.0, 0.4, 1.0), 1.0, blend="MULTIPLY")
    g.finish(col, g.rng(big, 0.3, 0.7, 0.5, 0.74), 0.0, g.math("ADD", big, g.math("MULTIPLY", crease, -0.7)), bump=0.28, dist=0.003)


def sole(g):
    big = g.noise(14, 5)
    col = g.mix((0.075, 0.046, 0.026), (0.020, 0.014, 0.010), g.rng(big, 0.3, 0.7))
    g.finish(col, 0.82, 0.0, big, bump=0.3, dist=0.003)


BUILDERS = {
    "BOOT": boot_leather, "LEATHER_SOLE": sole, "MANTLE": mantle,
    "CINNABAR": cinnabar, "CHARCOAL": lambda g: charcoal(g), "PLAID": lambda g: charcoal(g, True), "TROUSER": lambda g: charcoal(g, False, 1.8), "CHARCOAL_LT": lambda g: charcoal(g, False, 1.9), "ASH": ash, "PALE": pale,
    "IRON": black_iron, "BRONZE": bronze, "LEATHER": leather, "LACE": lace, "JADE": jade, "TASSEL": tassel, "SKIN": skin,
}


def make_all():
    out = {}
    for name, fn in BUILDERS.items():
        mat = bpy.data.materials.new("Armour_" + name)
        mat.use_nodes = True
        fn(G(mat))
        out[name] = mat
    return out

"""Procedural PBR materials for Zhao v2.

Every material ends in three reroutes, OUT_COLOR / OUT_ROUGH / OUT_METAL, plus a bump height, so the bake step
reads exactly the channel values the renders use. Wear is layered the way the real objects age: lacquer chips
to a black undercoat and then to bare iron on edges; iron rusts in streaks below rivets and polishes on edges;
cloth fades on top surfaces and picks up mud toward the hem; skin has tonal zones, pores and stubble.
"""
import bpy


class G:
    """Tiny node-graph builder."""

    def __init__(self, mat):
        self.nt = mat.node_tree
        self.nt.nodes.clear()
        self.x = -1600

    def n(self, kind, **kw):
        node = self.nt.nodes.new(kind)
        node.location = (self.x, 0)
        self.x += 40
        for k, v in kw.items():
            setattr(node, k, v)
        return node

    def link(self, a, b):
        self.nt.links.new(a, b)

    def val(self, v):
        node = self.n("ShaderNodeValue")
        node.outputs[0].default_value = v
        return node.outputs[0]

    def rgb(self, c):
        node = self.n("ShaderNodeRGB")
        node.outputs[0].default_value = (*c, 1)
        return node.outputs[0]

    def sock(self, v, color=False):
        if isinstance(v, bpy.types.NodeSocket):
            return v
        if color:
            return self.rgb(v)
        return self.val(v)

    def coord(self, kind="Object"):
        tc = getattr(self, "_tc", None) or self.n("ShaderNodeTexCoord")
        self._tc = tc
        return tc.outputs[kind]

    def uv(self, name="detail"):
        return self.n("ShaderNodeUVMap", uv_map=name).outputs["UV"]

    def scale(self, vec, s):
        m = self.n("ShaderNodeVectorMath", operation="MULTIPLY")
        self.link(vec, m.inputs[0])
        m.inputs[1].default_value = s
        return m.outputs[0]

    def noise(self, scale, detail=6, rough=0.5, vec=None, dist=0.0, dims="3D"):
        t = self.n("ShaderNodeTexNoise", noise_dimensions=dims)
        t.inputs["Scale"].default_value = scale
        t.inputs["Detail"].default_value = detail
        t.inputs["Roughness"].default_value = rough
        t.inputs["Distortion"].default_value = dist
        self.link(vec if vec is not None else self.coord(), t.inputs["Vector"])
        return t.outputs["Fac"]

    def voronoi(self, scale, feature="F1", vec=None, out="Distance"):
        t = self.n("ShaderNodeTexVoronoi", feature=feature)
        t.inputs["Scale"].default_value = scale
        self.link(vec if vec is not None else self.coord(), t.inputs["Vector"])
        return t.outputs[out]

    def wave(self, scale, vec=None, dist=0.0, kind="BANDS", direction="X", profile="SIN"):
        t = self.n("ShaderNodeTexWave", wave_type=kind, bands_direction=direction, wave_profile=profile)
        t.inputs["Scale"].default_value = scale
        t.inputs["Distortion"].default_value = dist
        self.link(vec if vec is not None else self.coord(), t.inputs["Vector"])
        return t.outputs["Fac"]

    def rng(self, v, a, b, c=0.0, d=1.0):
        m = self.n("ShaderNodeMapRange", clamp=True)
        self.link(self.sock(v), m.inputs["Value"])
        m.inputs["From Min"].default_value, m.inputs["From Max"].default_value = a, b
        m.inputs["To Min"].default_value, m.inputs["To Max"].default_value = c, d
        return m.outputs[0]

    def math(self, op, a, b=0.0, clamp=False):
        m = self.n("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.link(self.sock(a), m.inputs[0])
        self.link(self.sock(b), m.inputs[1])
        return m.outputs[0]

    def mix(self, a, b, fac, color=True, blend="MIX"):
        m = self.n("ShaderNodeMix", data_type="RGBA" if color else "FLOAT", blend_type=blend)
        t = "RGBA" if color else "VALUE"
        ins = [s for s in m.inputs if s.type == t and s.name != "Factor"]
        self.link(self.sock(a, color), ins[0])
        self.link(self.sock(b, color), ins[1])
        self.link(self.sock(fac), m.inputs["Factor"])
        return [s for s in m.outputs if s.type == t][0]

    def sep(self, vec):
        s = self.n("ShaderNodeSeparateXYZ")
        self.link(vec, s.inputs[0])
        return s.outputs

    def edges(self, lo=0.52, hi=0.6):
        geo = self.n("ShaderNodeNewGeometry")
        return self.rng(geo.outputs["Pointiness"], lo, hi)

    def cavity(self, dist=0.05):
        ao = self.n("ShaderNodeAmbientOcclusion", samples=12)
        ao.inputs["Distance"].default_value = dist
        return ao.outputs["AO"]

    def facing_up(self):
        geo = self.n("ShaderNodeNewGeometry")
        return self.rng(self.sep(geo.outputs["Normal"])[2], 0.2, 0.9)

    def height_z(self, lo, hi):
        geo = self.n("ShaderNodeNewGeometry")
        return self.rng(self.sep(geo.outputs["Position"])[2], lo, hi)

    def finish(self, color, rough, metal, height, bump=0.2, dist=0.004, coat=0.0, coat_rough=0.1, sheen=0.0,
               sss=0.0, spec=0.5):
        out = self.n("ShaderNodeOutputMaterial")
        out.location = (1400, 0)
        b = self.n("ShaderNodeBsdfPrincipled")
        b.location = (1100, 0)
        self.link(b.outputs[0], out.inputs["Surface"])
        for key, s in (("OUT_COLOR", color), ("OUT_ROUGH", rough), ("OUT_METAL", metal)):
            r = self.n("NodeReroute")
            r.name = r.label = key
            r.location = (900, {"OUT_COLOR": 200, "OUT_ROUGH": 0, "OUT_METAL": -200}[key])
            self.link(self.sock(s, key == "OUT_COLOR"), r.inputs[0])
            self.link(r.outputs[0], b.inputs[{"OUT_COLOR": "Base Color", "OUT_ROUGH": "Roughness", "OUT_METAL": "Metallic"}[key]])
        if height is not None:
            bp = self.n("ShaderNodeBump")
            bp.inputs["Strength"].default_value = bump
            bp.inputs["Distance"].default_value = dist
            self.link(self.sock(height), bp.inputs["Height"])
            self.link(bp.outputs["Normal"], b.inputs["Normal"])
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = coat_rough
        b.inputs["Sheen Weight"].default_value = sheen
        b.inputs["Specular IOR Level"].default_value = spec
        if sss:
            b.inputs["Subsurface Weight"].default_value = sss
            b.inputs["Subsurface Radius"].default_value = (0.012, 0.005, 0.003)
            b.inputs["Subsurface Scale"].default_value = 1.0


def lacquer(g):
    big = g.noise(5, 4)
    tone = g.mix((0.072, 0.0085, 0.007), (0.040, 0.006, 0.0055), g.rng(big, 0.35, 0.7))
    # brush streaks in the lacquer, mostly vertical
    streak = g.noise(3, 8, 0.6, g.scale(g.coord(), (40, 40, 3)))
    tone = g.mix(tone, (0.095, 0.012, 0.01), g.rng(streak, 0.55, 0.75, 0, 0.35))
    edge = g.edges(0.51, 0.58)
    chips = g.rng(g.noise(16, 12, 0.7), 0.48, 0.62)
    under = g.math("MULTIPLY", g.math("ADD", edge, g.math("MULTIPLY", chips, 0.55)), 1.2, True)
    bare = g.math("MULTIPLY", g.rng(under, 0.55, 1.0), g.rng(g.noise(30, 8), 0.45, 0.6), True)
    col = g.mix(tone, (0.012, 0.010, 0.010), g.rng(under, 0.25, 0.55))      # black undercoat
    col = g.mix(col, (0.16, 0.15, 0.14), bare)                                # bright scuffed iron
    grime = g.rng(g.cavity(0.05), 0.15, 1.0, 0.35, 1.0)
    col = g.mix(col, grime, 1.0, blend="MULTIPLY")
    rough = g.mix(g.rng(big, 0.3, 0.7, 0.16, 0.34), 0.55, g.rng(under, 0.3, 0.6), color=False)
    rough = g.mix(rough, 0.38, bare, color=False)
    metal = g.mix(0.0, 0.9, bare, color=False)
    h = g.math("ADD", g.math("MULTIPLY", g.rng(under, 0.25, 0.55), -0.4), g.math("MULTIPLY", streak, 0.15))
    g.finish(col, rough, metal, h, bump=0.35, dist=0.003, coat=0.6, coat_rough=0.18)


def iron(g):
    hammer = g.voronoi(55, "SMOOTH_F1")
    big = g.noise(6, 6)
    col = g.mix((0.070, 0.067, 0.064), (0.034, 0.031, 0.029), g.rng(big, 0.35, 0.7))
    # rust running down from crevices and rivets: noise stretched along Z
    run = g.noise(9, 6, 0.6, g.scale(g.coord(), (18, 18, 2.2)))
    rust = g.math("MULTIPLY", g.rng(run, 0.55, 0.72), g.rng(g.cavity(0.08), 0.95, 0.4), True)
    col = g.mix(col, g.mix((0.11, 0.045, 0.02), (0.05, 0.022, 0.012), g.noise(40, 4)), g.math("MULTIPLY", rust, 0.85))
    edge = g.math("MULTIPLY", g.edges(0.51, 0.57), g.rng(g.noise(25, 6), 0.4, 0.6), True)
    col = g.mix(col, (0.38, 0.37, 0.35), edge)
    col = g.mix(col, g.rng(g.cavity(0.06), 0.15, 1.0, 0.4, 1.0), 1.0, blend="MULTIPLY")
    rough = g.mix(g.rng(big, 0.3, 0.7, 0.5, 0.72), 0.88, rust, color=False)
    rough = g.mix(rough, 0.28, edge, color=False)
    metal = g.mix(0.88, 0.2, rust, color=False)
    h = g.math("ADD", g.math("MULTIPLY", hammer, 0.6), g.math("MULTIPLY", rust, 0.3))
    g.finish(col, rough, metal, h, bump=0.3, dist=0.004)


def bronze(g):
    big = g.noise(14, 6)
    col = g.mix((0.19, 0.12, 0.05), (0.075, 0.06, 0.035), g.rng(big, 0.3, 0.7))
    pat = g.rng(g.cavity(0.03), 0.9, 0.3)
    col = g.mix(col, (0.05, 0.09, 0.07), g.math("MULTIPLY", pat, 0.7))     # verdigris in recesses
    edge = g.edges(0.51, 0.56)
    col = g.mix(col, (0.45, 0.32, 0.16), edge)
    rough = g.mix(0.5, 0.28, edge, color=False)
    g.finish(col, rough, g.mix(0.95, 0.3, pat, color=False), big, bump=0.15)


def cloth(g, a, b, fade, mud=True, weave=320):
    big = g.noise(4, 5, 0.55, dist=0.4)
    col = g.mix(a, b, g.rng(big, 0.3, 0.72))
    col = g.mix(col, fade, g.math("MULTIPLY", g.facing_up(), g.rng(g.noise(9, 4), 0.4, 0.65, 0.15, 0.6), True))
    if mud:
        low = g.height_z(-2.0, -2.7)
        mudmask = g.math("MULTIPLY", low, g.rng(g.noise(14, 8, 0.7), 0.35, 0.6, 0.3, 1.0), True)
        col = g.mix(col, (0.035, 0.028, 0.022), mudmask)
    w1 = g.wave(weave, None, 0.5, "BANDS", "X")
    w2 = g.wave(weave, None, 0.5, "BANDS", "Z")
    weave_h = g.math("MULTIPLY", g.math("ADD", w1, w2), 0.5)
    col = g.mix(col, g.rng(weave_h, 0, 1, 0.85, 1.05), 1.0, blend="MULTIPLY")
    col = g.mix(col, g.rng(g.cavity(0.06), 0.1, 1.0, 0.45, 1.0), 1.0, blend="MULTIPLY")
    rough = g.rng(big, 0.3, 0.7, 0.82, 0.95)
    h = g.math("ADD", g.math("MULTIPLY", weave_h, 0.25), g.math("MULTIPLY", g.noise(30, 6, 0.6), 0.5))
    g.finish(col, rough, 0.0, h, bump=0.25, dist=0.003, sheen=0.4)


def cord(g):
    tw = g.wave(260, None, 2.0, "BANDS", "X")
    col = g.mix((0.024, 0.040, 0.068), (0.010, 0.014, 0.022), g.rng(tw, 0.2, 0.8))
    col = g.mix(col, (0.06, 0.06, 0.06), g.math("MULTIPLY", g.facing_up(), 0.3))
    g.finish(col, 0.85, 0.0, tw, bump=0.4, dist=0.002, sheen=0.3)


def leather(g):
    big = g.noise(10, 6)
    grain = g.voronoi(220, "F1")
    col = g.mix((0.055, 0.034, 0.022), (0.022, 0.015, 0.011), g.rng(big, 0.3, 0.7))
    edge = g.edges(0.51, 0.57)
    col = g.mix(col, (0.11, 0.075, 0.05), g.math("MULTIPLY", edge, 0.8))
    col = g.mix(col, g.rng(g.cavity(0.05), 0.1, 1.0, 0.4, 1.0), 1.0, blend="MULTIPLY")
    rough = g.mix(g.rng(big, 0.3, 0.7, 0.5, 0.75), 0.35, edge, color=False)
    g.finish(col, rough, 0.0, g.math("ADD", grain, g.math("MULTIPLY", big, 0.4)), bump=0.2, dist=0.002)


def skin(g, scar=False):
    co = g.coord()
    s = g.sep(co)
    base = g.mix((0.33, 0.20, 0.145), (0.24, 0.135, 0.095), g.rng(g.noise(18, 6), 0.3, 0.7))
    # weather: ruddier cheeks and nose, paler forehead, stubble shadow on the jaw and upper lip
    red = g.math("MULTIPLY", g.rng(s[2], -0.05, 0.08, 1.0, 0.0), g.rng(s[1], 0.02, 0.06), True)
    base = g.mix(base, (0.33, 0.12, 0.08), g.math("MULTIPLY", red, 0.45))
    jaw = g.math("MULTIPLY", g.rng(s[2], 0.0, -0.12), g.rng(s[1], -0.05, 0.05), True)
    stub = g.math("MULTIPLY", jaw, g.rng(g.noise(400, 2), 0.4, 0.6, 0.55, 1.0), True)
    base = g.mix(base, (0.10, 0.075, 0.06), g.math("MULTIPLY", stub, 0.55))
    if scar:
        base = g.mix(base, (0.36, 0.18, 0.15), 0.8)
    pores = g.voronoi(900, "F1")
    wr = g.noise(60, 3, 0.5, g.scale(co, (1, 1, 6)))     # horizontal fine lines (brow, crow's feet)
    col = g.mix(base, g.rng(g.cavity(0.02), 0.2, 1.0, 0.55, 1.0), 1.0, blend="MULTIPLY")
    rough = g.rng(g.noise(20, 4), 0.3, 0.7, 0.52, 0.72)
    h = g.math("ADD", g.math("MULTIPLY", pores, 0.25), g.math("MULTIPLY", wr, 0.6))
    g.finish(col, rough, 0.0, h, bump=0.3, dist=0.002, sss=0.2, spec=0.35)


def hair(g, core=False):
    # salt-and-pepper: mostly black, iron-grey strands creeping in (age, years under the oath)
    grey = g.rng(g.noise(40, 1, 0.5, g.scale(g.coord(), (1, 1, 0.15))), 0.45, 0.65)
    col = g.mix((0.016, 0.014, 0.013), (0.13, 0.125, 0.12), g.math("MULTIPLY", grey, 0.0 if core else 0.55))
    strands = g.wave(900, None, 3.0, "BANDS", "Z")
    g.finish(col, g.rng(strands, 0, 1, 0.38, 0.55), 0.0, strands, bump=0.25, dist=0.001, sheen=0.3, spec=0.35)


def eye(g):
    # sclera -> dark brown iris -> pupil along the lathe profile (detail UV v = 0 at the front pole)
    v = g.sep(g.uv())[1]
    col = g.mix((0.40, 0.34, 0.29), (0.075, 0.04, 0.02), g.rng(v, 0.30, 0.24))
    col = g.mix(col, (0.006, 0.005, 0.005), g.rng(v, 0.13, 0.10))
    g.finish(col, 0.1, 0.0, None, coat=1.0, coat_rough=0.02)


def plume(g):
    uv = g.sep(g.uv())
    across = g.math("ABSOLUTE", g.math("SUBTRACT", uv[0], 0.5))
    # pheasant bars: crescent-shaped (offset by distance from the shaft), darker toward the tip
    bar = g.math("SINE", g.math("MULTIPLY", g.math("ADD", uv[1], g.math("MULTIPLY", across, 0.035)), 150.0))
    barm = g.rng(bar, 0.25, 0.65)
    base = g.mix((0.44, 0.29, 0.11), (0.30, 0.17, 0.06), g.rng(g.noise(20, 4), 0.3, 0.7))
    base = g.mix(base, (0.30, 0.10, 0.035), g.rng(across, 0.25, 0.5))         # rufous rims
    col = g.mix(base, (0.03, 0.022, 0.016), barm)
    col = g.mix(col, (0.06, 0.05, 0.04), g.rng(uv[1], 0.8, 1.0, 0, 0.6))      # dark tip
    barbs = g.wave(600, g.uv(), 1.0, "BANDS", "X")
    g.finish(col, g.rng(barm, 0, 1, 0.55, 0.75), 0.0, barbs, bump=0.3, dist=0.002, sheen=0.6)


def wood_red(g):
    grain = g.wave(25, g.scale(g.coord(), (12, 0.3, 12)), 6.0, "RINGS", "X")
    big = g.noise(3, 4)
    col = g.mix((0.075, 0.010, 0.008), (0.040, 0.007, 0.006), g.rng(big, 0.3, 0.7))
    wear = g.math("MULTIPLY", g.rng(g.noise(8, 8, 0.7), 0.5, 0.7), 1.0, True)
    col = g.mix(col, g.mix((0.06, 0.035, 0.02), (0.03, 0.017, 0.01), grain), wear)  # hand-worn to bare wood
    rough = g.mix(0.2, 0.55, wear, color=False)
    g.finish(col, rough, 0.0, g.math("MULTIPLY", grain, 0.3), bump=0.2, coat=0.5, coat_rough=0.15)


def steel(g):
    big = g.noise(4, 4)
    # faint folded-steel grain (distorted bands), a darker oxidised flat and a bright honed edge
    grain = g.wave(22, None, 9.0, "BANDS", "Y")
    col = g.mix((0.50, 0.505, 0.515), (0.40, 0.405, 0.415), g.rng(big, 0.3, 0.7))
    col = g.mix(col, (0.33, 0.335, 0.345), g.math("MULTIPLY", g.rng(grain, 0.3, 0.7), 0.25))
    edge = g.edges(0.5, 0.56)
    col = g.mix(col, (0.82, 0.82, 0.83), edge)
    nicks = g.rng(g.noise(80, 2), 0.62, 0.7)
    col = g.mix(col, (0.16, 0.09, 0.05), g.math("MULTIPLY", g.rng(g.cavity(0.03), 0.9, 0.5), 0.5))
    rough = g.rng(big, 0.3, 0.7, 0.16, 0.30)
    g.finish(col, rough, 1.0, g.math("ADD", g.math("MULTIPLY", grain, 0.08), nicks), bump=0.1, dist=0.002)


def enamel(g):
    crack = g.voronoi(60, "DISTANCE_TO_EDGE")
    col = g.mix((0.03, 0.12, 0.30), (0.015, 0.06, 0.16), g.rng(g.noise(20, 4), 0.3, 0.7))
    col = g.mix(col, (0.01, 0.01, 0.012), g.rng(crack, 0.03, 0.0))
    g.finish(col, g.rng(crack, 0.0, 0.05, 0.6, 0.18), 0.0, crack, bump=0.2, dist=0.001, coat=0.8, coat_rough=0.05)


def pole(g):
    big = g.noise(4, 5)
    col = g.mix((0.030, 0.022, 0.020), (0.014, 0.011, 0.010), g.rng(big, 0.3, 0.7))
    col = g.mix(col, (0.09, 0.06, 0.04), g.math("MULTIPLY", g.edges(0.51, 0.56), 0.6))
    g.finish(col, g.rng(big, 0.3, 0.7, 0.3, 0.5), 0.0, big, bump=0.1, coat=0.4)


BUILDERS = {
    "LACQUER": lacquer, "IRON": iron, "BRONZE": bronze,
    "CLOTH_RED": lambda g: cloth(g, (0.050, 0.010, 0.009), (0.022, 0.007, 0.007), (0.075, 0.035, 0.03)),
    "CLOTH_DARK": lambda g: cloth(g, (0.022, 0.022, 0.028), (0.011, 0.011, 0.014), (0.045, 0.042, 0.04)),
    "AZURE": lambda g: cloth(g, (0.022, 0.060, 0.13), (0.012, 0.030, 0.065), (0.05, 0.07, 0.09), mud=False),
    "ENAMEL": enamel, "CORD": cord, "LEATHER": leather,
    "SKIN": skin, "SCAR": lambda g: skin(g, True), "HAIR": hair, "HAIR_CORE": lambda g: hair(g, True), "EYE": eye, "PLUME": plume,
    "WOOD_RED": wood_red, "STEEL": steel, "POLE": pole,
}
SPEC = BUILDERS  # names used by the build


def make(name):
    mat = bpy.data.materials.new("ZhaoV2_" + name)
    mat.use_nodes = True
    BUILDERS[name](G(mat))
    return mat


def make_all():
    return {k: make(k) for k in BUILDERS}

"""Kit pieces for the Shrine of the Ascendant (lobby_kit.py builds, lays out and exports them).

Each builder fills a Piece: one Mesh per material, named <Piece>__<Material>, so every Roblox
MeshPart carries exactly one shared texture set. Origins: base centre on the floor for upright
pieces; eave-line centre for roofs; the top of the rock for hanging cliff modules. X is the long
axis; a piece's front faces Blender -Y (Roblox +Z after export) unless noted.
"""
import math

from mathutils import Matrix, Vector

import lobby_kit_roofs as roofs
from lobby_kit_geo import Mesh, rect, rock_body, superellipse, xz_plane
from lobby_textures import STUDS


class Piece:
    def __init__(self, name):
        self.name, self.meshes = name, {}

    def m(self, material):
        if material not in self.meshes:
            self.meshes[material] = Mesh(f"{self.name}__{material}", material, STUDS[material])
        return self.meshes[material]


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


# -- timber frame -------------------------------------------------------------------------------
def column(pc):
    """Lacquered timber column, 10 tall, slight entasis, bronze collars (scale Y in Roblox)."""
    prof = [(0.6, 0), (0.6, 0.5), (0.585, 3.0), (0.57, 6.5), (0.54, 9.4), (0.52, 10.0)]
    pc.m("Lacquer").lathe(prof, 16)
    br = pc.m("Bronze")
    for z0 in (0.25, 9.35):
        br.lathe([(0.64, z0), (0.66, z0 + 0.08), (0.66, z0 + 0.22), (0.64, z0 + 0.3)], 16)


def column_base(pc):
    s = pc.m("Stone")
    s.box((0, 0, 0.2), (2.1, 2.1, 0.4), bevel=0.05)
    s.lathe([(0.95, 0.4), (1.02, 0.52), (0.98, 0.68), (0.8, 0.86), (0.68, 0.9)], 16)


def bracket(pc):
    """Dougong cluster sitting on a column top: bearing block, crossed arms, small blocks, 2 tiers."""
    w = pc.m("Timber")
    w.lathe([(0.72, 0.0), (0.95, 0.28), (1.0, 0.28), (1.0, 0.7)], 4, phase=math.pi / 4)

    def arm(length, z, along_y=False, depth=0.46):
        h = 0.52
        e = length / 2
        outline = [(-e, h), (-e, 0.24), (-e + 0.12, 0.09), (-e + 0.32, 0.0), (e - 0.32, 0.0), (e - 0.12, 0.09), (e, 0.24), (e, h)]
        M = T(0, 0, z) @ (Matrix.Rotation(math.radians(90), 4, "Z") if along_y else Matrix.Identity(4)) @ xz_plane(0, depth)
        w.prism(outline, (), depth, M)
        for x in (-e + 0.3, 0.0, e - 0.3):
            c = Vector((0, x, 0)) if along_y else Vector((x, 0, 0))
            w.box((c.x, c.y, z + h + 0.16), (0.56, 0.56, 0.32), bevel=0.03)
    arm(3.4, 0.7)
    arm(3.4, 0.7, along_y=True)
    arm(5.0, 1.55)
    arm(4.2, 1.55, along_y=True)
    w.box((0, 0, 2.6), (6.2, 0.6, 0.38), bevel=0.04)


def beam(pc):
    """Architrave for an 8-stud bay: dark main beam, lacquer lintel below, spacer blocks."""
    w, lq = pc.m("Timber"), pc.m("Lacquer")
    w.box((0, 0, 1.55), (8.0, 0.75, 0.95), bevel=0.07)
    lq.box((0, 0, 0.3), (8.0, 0.55, 0.6), bevel=0.05)
    for x in (-3.0, -1.0, 1.0, 3.0):
        w.box((x, 0, 0.84), (0.5, 0.45, 0.5), bevel=0.03)
    lq.box((0, 0, 0.84), (8.0, 0.22, 0.42))


# -- stone balustrade -------------------------------------------------------------------------
def _rail_body(s, L, shear=0.0):
    first = len(s.bm.verts)
    s.box((0, 0, 0.2), (L, 0.78, 0.4), bevel=0.05)
    holes = [superellipse(x, 1.02, 0.95, 0.33, 4.0, 28) for x in (-L * 0.25, L * 0.25)]
    s.prism(rect(0, 1.02, L, 1.24), holes, 0.32, xz_plane(0, 0.32))
    s.prism(rect(0, 1.02, L - 0.12, 1.14), [rect(0, 1.02, L - 0.42, 0.86)], 0.42, xz_plane(0, 0.42))
    for x in (-L / 3, 0.0, L / 3):
        s.lathe([(0.17, 1.64), (0.25, 1.76), (0.14, 1.95), (0.21, 2.12), (0.15, 2.3)], 8, T(x))
    s.sweep(roofs.ridge_profile(0.44, 0.34), [Vector((x, 0, 2.28)) for x in (-L / 2, 0, L / 2)])
    if shear:
        s.bm.verts.ensure_lookup_table()
        for v in list(s.bm.verts)[first:]:
            v.co.z += v.co.x * shear


def rail_bay(pc):
    _rail_body(pc.m("Stone"), 5.1)


def rail_bay_stair(pc):
    """Same bay sheared for the 1:2 Ascension stair (rises toward +X)."""
    _rail_body(pc.m("Stone"), 5.1, shear=0.5)


def rail_post(pc):
    s = pc.m("Stone")
    s.box((0, 0, 0.22), (1.15, 1.15, 0.44), bevel=0.05)
    s.box((0, 0, 1.72), (0.86, 0.86, 2.6), bevel=0.06)
    s.box((0, 0, 3.06), (0.98, 0.98, 0.14), bevel=0.03)
    s.lathe([(0.5, 3.12), (0.56, 3.26), (0.46, 3.44), (0.52, 3.6), (0.42, 3.86), (0.24, 4.06), (0.08, 4.16)], 8, phase=math.pi / 8)


# -- lanterns --------------------------------------------------------------------------------
def lantern_stone(pc):
    """Square stone lantern, 5.5 tall. The glowing paper box (a separate Roblox part) is 1.15 wide
    and sits at z 2.75-3.95 between the corner posts."""
    s = pc.m("Stone")
    s.box((0, 0, 0.2), (2.0, 2.0, 0.4), bevel=0.06)
    s.box((0, 0, 0.55), (1.6, 1.6, 0.3), bevel=0.05)
    s.box((0, 0, 1.55), (0.9, 0.9, 1.7), bevel=0.07)
    s.box((0, 0, 1.4), (1.02, 1.02, 0.16), bevel=0.03)
    s.box((0, 0, 2.55), (1.85, 1.85, 0.3), bevel=0.06)
    for x in (-0.66, 0.66):
        for y in (-0.66, 0.66):
            s.box((x, y, 3.35), (0.3, 0.3, 1.3), bevel=0.03)
    s.box((0, 0, 4.08), (1.7, 1.7, 0.2), bevel=0.03)
    sub = Piece("tmp")
    roofs.hall(sub, W=2.7, D=2.7, H=0.8, tg=1.0, lift=0.3, kick=0.16, thick=(0.28, 0.4), top="Stone", under="Stone",
               tile_ends=False, ridge_scale=0.17, finial="Stone", nu=8, nt=(5, 0), rafters=False)
    for mesh in sub.meshes.values():
        mesh.bm.transform(T(0, 0, 4.45))
        s.merge(mesh.bm)


def lantern_hanging(pc):
    """Hexagonal timber lantern under bronze cap, 2.2 tall, origin at its hook."""
    w, br = pc.m("Timber"), pc.m("Bronze")
    for k in range(6):
        a = math.radians(60 * k + 30)
        w.box((0.55 * math.cos(a), 0.55 * math.sin(a), -1.3), (0.1, 0.1, 1.1))
    w.lathe([(0.72, -1.95), (0.72, -1.82), (0.6, -1.78)], 6, phase=math.radians(30))
    w.lathe([(0.62, -0.78), (0.7, -0.72), (0.7, -0.66)], 6, phase=math.radians(30))
    br.lathe([(0.95, -0.66), (0.8, -0.5), (0.4, -0.3), (0.12, -0.12), (0.06, 0.0)], 6, phase=math.radians(30))
    br.lathe([(0.2, -2.0), (0.14, -2.25), (0.04, -2.35)], 6)


# -- carved stone -------------------------------------------------------------------------------
def _crest(width, base, crown, lobes=5, n=48, amp=0.2):
    r = width / 2
    pts = [(-r, base), (r, base), (r, crown)]
    for k in range(1, n):
        th = math.pi * k / n
        rr = r * (1 + amp * abs(math.sin(lobes * th)) ** 1.5)
        pts.append((rr * math.cos(th), crown + rr * math.sin(th) * 0.8))
    pts.append((-r, crown))
    return pts


def stele(pc):
    """Memorial stele, 9 tall: moulded pedestal, slab with dragon-crest crown, raised text frames."""
    s = pc.m("Stone")
    s.box((0, 0, 0.3), (4.4, 2.0, 0.6), bevel=0.08)
    s.box((0, 0, 0.78), (3.9, 1.6, 0.36), bevel=0.06)
    s.box((0, 0, 1.0), (3.5, 1.3, 0.12))
    s.prism(_crest(3.0, 1.0, 6.6), (), 0.84, xz_plane(0, 0.84))
    s.prism(rect(0, 3.75, 2.3, 4.3), [rect(0, 3.75, 1.9, 3.9)], 1.0, xz_plane(0, 1.0))
    s.prism(superellipse(0, 7.0, 0.62, 0.5, 2.0, 24), [superellipse(0, 7.0, 0.45, 0.34, 2.0, 24)], 0.98, xz_plane(0, 0.98))


def stele_broken(pc):
    s = pc.m("Stone")
    s.box((0, 0, 0.3), (4.4, 2.0, 0.6), bevel=0.08)
    s.box((0, 0, 0.78), (3.9, 1.6, 0.36), bevel=0.06)
    jag = [(-1.5, 1.0), (1.5, 1.0), (1.5, 3.4), (1.1, 3.9), (0.6, 3.5), (0.1, 4.4), (-0.5, 3.8), (-1.0, 4.1), (-1.5, 3.6)]
    s.prism(jag, (), 0.84, xz_plane(0, 0.84))
    shard = [(-1.2, 0.0), (1.0, 0.0), (1.3, 0.6), (0.4, 0.95), (-0.9, 0.7)]
    s.prism(shard, (), 0.8, T(2.6, -0.6, 0.0) @ Matrix.Rotation(math.radians(20), 4, "Z"))


def ruin_pillar(pc):
    """Octagonal banded pillar broken off at ~11 studs, on a moulded plinth."""
    s = pc.m("Stone")
    s.box((0, 0, 0.3), (2.8, 2.8, 0.6), bevel=0.08)
    s.lathe([(1.25, 0.6), (1.3, 0.8), (1.1, 1.05), (1.0, 1.15)], 8, phase=math.pi / 8)
    prof = [(0.95, 1.15)]
    for z in (3.2, 6.4, 9.0):
        prof += [(0.95, z - 0.25), (1.05, z - 0.15), (1.05, z + 0.15), (0.95, z + 0.25)]
    prof.append((0.92, 11.8))
    first = len(s.bm.verts)
    s.lathe(prof, 8, phase=math.pi / 8)
    s.bm.verts.ensure_lookup_table()
    for k, v in enumerate(list(s.bm.verts)[first:]):
        if v.co.z > 11.0:
            v.co.z = 10.4 + 1.4 * ((k * 0.61803) % 1)


def ruin_gate(pc):
    """Fragment of a stone pailou: one standing post with its cap, one broken, a fallen lintel."""
    s = pc.m("Stone")
    for x, h in ((-4.5, 10.0), (4.5, 6.2)):
        s.box((x, 0, 0.35), (2.4, 2.4, 0.7), bevel=0.08)
        s.box((x, 0, 0.7 + h / 2), (1.35, 1.35, h), bevel=0.07)
    s.box((-4.5, 0, 10.9), (2.0, 2.0, 0.5), bevel=0.06)
    sub = Piece("tmp")
    roofs.hall(sub, W=2.8, D=2.8, H=0.9, tg=1.0, lift=0.35, kick=0.2, thick=(0.15, 0.3), top="Stone", under="Stone",
               tile_ends=False, ridge_scale=0.18, finial="Stone", nu=8, nt=(5, 0), rafters=False)
    for mesh in sub.meshes.values():
        mesh.bm.transform(T(-4.5, 0, 11.3))
        s.merge(mesh.bm)
    lintel = T(0.2, 0, 8.3) @ Matrix.Rotation(math.atan2(-3.8, 9.0), 4, "Y")
    s.box((0, 0, 0), (10.8, 1.1, 1.2), lintel, bevel=0.07)
    s.box((-4.5, 0, 9.25), (2.6, 1.3, 0.5), bevel=0.05)


# -- courtyard stonework -----------------------------------------------------------------------
RIM = [(0.0, -0.9), (1.25, -0.9), (1.25, 0.33), (1.15, 0.43), (0.9, 0.47), (0.25, 0.47), (0.05, 0.42),
       (-0.06, 0.34), (-0.06, 0.2), (0.0, 0.14)]


def pool_rim(pc):
    """8-stud basin coping; water side toward Blender -Y (Roblox +Z), pivot on the water edge."""
    s = pc.m("Stone")
    xs = [-4.0, 4.0]
    P = [[Vector((x, -y, z)) for x in xs] for y, z in RIM]
    s.grid(P)
    s.poly([Vector((xs[0], -y, z)) for y, z in reversed(RIM)])
    s.poly([Vector((xs[1], -y, z)) for y, z in RIM])
    s.grid([P[-1], P[0]])


def pool_corner(pc):
    s = pc.m("Stone")
    s.box((0, 0, -0.22), (1.31, 1.31, 1.36), bevel=0.07)


def dais(pc):
    """Low three-step bonfire dais with a bronze bowl and a floor inlay ring (radius 9)."""
    s, br = pc.m("Stone"), pc.m("Bronze")
    s.lathe([(6.4, 0.0), (6.4, 0.28), (6.25, 0.38), (5.15, 0.38), (5.15, 0.66), (5.0, 0.78), (3.85, 0.78),
             (3.85, 1.04), (3.65, 1.18), (2.2, 1.18)], 40)
    br.lathe([(2.25, 1.1), (2.4, 1.34), (2.3, 1.5), (2.1, 1.52), (1.9, 1.42), (1.2, 1.56), (0.4, 1.6)], 24)
    br.lathe([(9.0, -0.05), (9.0, 0.035), (8.6, 0.035), (8.6, -0.05), (9.0, -0.05)], 64, caps=(False, False))
    for k in range(8):
        a = math.radians(45 * k + 22.5)
        c = Vector((math.cos(a), math.sin(a), 0))
        M = T(*(c * 7.6)) @ Matrix.Rotation(a, 4, "Z")
        br.box((0, 0, 0.0), (2.0, 0.22, 0.07), M)


def medallion(pc):
    """Ring of radial paving around the dais (Paving texture; its maps also feed MaterialVariants)."""
    p = pc.m("Paving")
    p.lathe([(10.4, 0.0), (10.4, 0.04), (6.5, 0.04), (6.5, 0.0), (10.4, 0.0)], 48, caps=(False, False))


def plaque(pc):
    w, br = pc.m("Timber"), pc.m("Bronze")
    w.box((0, 0, 0), (6.4, 0.28, 2.5), bevel=0.04)
    br.prism(rect(0, 0, 7.0, 3.1), [rect(0, 0, 6.3, 2.4)], 0.4, xz_plane(0, 0.4))


# -- rock ---------------------------------------------------------------------------------------
def cliff_ledge(pc):
    """Under-platform cliff, top flat at z 0, 30 deep, tapering into the clouds."""
    rock_body(pc.m("Rock"), 20, 18, 0.0, -30.0, seed=7, taper=(1.0, 0.22))


def cliff_shelf(pc):
    rock_body(pc.m("Rock"), 30, 11, 0.0, -22.0, seed=19, taper=(1.0, 0.35), layer=(2.0, 4.5))


def cliff_spur(pc):
    rock_body(pc.m("Rock"), 7, 6.5, 0.0, -46.0, seed=29, taper=(1.0, 0.12), layer=(3.0, 7.0), n_theta=28)


def karst_spire(pc):
    """Distant limestone tower, 170 tall from its base, mossy ledges."""
    rock_body(pc.m("Rock"), 22, 19, 170.0, 0.0, seed=41, taper=(1.0, 0.55), layer=(6.0, 16.0), n_theta=36, n_z=30, upward=True)


def outcrop(pc):
    rock_body(pc.m("Rock"), 4.5, 3.6, 4.0, -1.0, seed=53, taper=(1.0, 0.45), layer=(0.8, 1.6), n_theta=20, n_z=10, upward=True)


def roof_hall(pc):
    roofs.hall(pc, finial="Bronze")


def roof_square(pc):
    roofs.hall(pc, W=14.0, D=14.0, H=5.6, tg=1.0, lift=1.3, kick=0.8, thick=(0.5, 1.0), ridge_scale=0.8,
               finial="Bronze", nu=18, nt=(9, 0))


def roof_gallery(pc):
    roofs.gallery(pc)


def roof_gallery_end(pc):
    roofs.gallery(pc, end=True)


PIECES = [
    ("Roof_Hall", roof_hall), ("Roof_Square", roof_square), ("Roof_Gallery", roof_gallery),
    ("Roof_GalleryEnd", roof_gallery_end), ("Column_Lacquer", column), ("Column_Base", column_base),
    ("Bracket_Set", bracket), ("Beam_Architrave", beam), ("Rail_Bay", rail_bay), ("Rail_BayStair", rail_bay_stair),
    ("Rail_Post", rail_post), ("Lantern_Stone", lantern_stone), ("Lantern_Hanging", lantern_hanging),
    ("Stele_Dragon", stele), ("Stele_Broken", stele_broken), ("Ruin_Pillar", ruin_pillar), ("Ruin_Gate", ruin_gate),
    ("Pool_Rim", pool_rim), ("Pool_Corner", pool_corner), ("Dais_Bonfire", dais), ("Paving_Medallion", medallion),
    ("Gate_Plaque", plaque), ("Cliff_Ledge", cliff_ledge), ("Cliff_Shelf", cliff_shelf), ("Cliff_Spur", cliff_spur),
    ("Karst_Spire", karst_spire), ("Rock_Outcrop", outcrop),
]

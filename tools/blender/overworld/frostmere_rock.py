"""Frostmere Heads rock family (lane M6): snow-capped boulders (3), ice shards, cliff pieces (2 walls plus a corner), frozen scree.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b --python tools/blender/overworld/frostmere_rock.py
  env FROST_ONLY=Name1,Name2 builds a subset; FROST_NORENDER=1 skips renders.

Supersedes: nothing (searched first: no earlier Frostmere scripts; amberfall_rock.py is the pattern and its block()/wall()/talus() helpers are exec'd, not replaced).
Linked via workers/23c-frost-kit.md (the lane lead links it from LEDGER.md). New file because the lane run rules want one script run per family.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Frost_Slate is a 1024 atlas of four 512 quadrants (slice_kit.rock() / block() pick one per face by UV, never tiled): dark cold slate, wind-packed snow on up-facing
patches (the 'moss' quadrant), damp dark base with rime, pale lichen. Boulders match the slots Snow_Boulder_A (15x8x10), _B (11x11x8), _C (22x4x10).
"""
from pathlib import Path

FAMILY = "rock"
_here = Path(__file__).resolve().parent
exec(compile((_here / "frostmere_common.py").read_text(encoding="utf-8"), "frostmere_common.py", "exec"), globals())
_rk = (_here / "amberfall_rock.py").read_text(encoding="utf-8")  # block / shift / wall / talus, exec'd without the Amberfall piece list
exec(compile(_rk[_rk.index("def block("):_rk.index("# ---", _rk.index("def talus("))], "amberfall_rock.py", "exec"), globals())
_block = block


def block(*a, **k):  # more snow on up-facing ledges than Amberfall's dust crust (wall() and the corner call this by global name)
    k["dust"] = k.get("dust", 0.0) + 0.35
    return _block(*a, **k)


# ------------------------------------------------------------------------------------------ pieces
def boulder_a():
    rr = random.Random(2701)
    a = bmesh.new()
    rock(a, (0, 0, 2.8), (5.6, 4.4, 3.8), rr, sub=5, planes=3, rough=0.08, lump=0.2, moss_bias=0.35)
    rock(a, (6.4, 1.6, 1.2), (2.9, 2.5, 2.1), rr, sub=4, planes=3, moss_bias=0.3)
    rock(a, (-4.6, -3.2, 0.5), (1.9, 1.7, 1.4), rr, sub=4, moss_bias=0.3)
    obj("Frost_Boulder_A", "Stone", a, MATS["Frost_Slate"], smooth=True)


def boulder_b():
    rr = random.Random(2702)
    b = bmesh.new()
    rock(b, (0, 0, 5.0), (3.6, 3.0, 5.4), rr, sub=5, planes=9, lump=0.16, rough=0.05, rz=0.4, moss_bias=0.1)
    rock(b, (4.0, 1.4, 1.5), (2.4, 2.1, 2.5), rr, sub=4, planes=7, lump=0.16, rough=0.05, moss_bias=0.2)
    rock(b, (-3.4, -2.2, 0.8), (1.7, 1.5, 1.5), rr, sub=4, planes=6, lump=0.14, rough=0.05, moss_bias=0.2)
    obj("Frost_Boulder_B", "Stone", b, MATS["Frost_Slate"], smooth=False)


def boulder_c():
    rr = random.Random(2703)
    c = bmesh.new()
    rock(c, (0, 0, 1.3), (8.6, 4.4, 2.6), rr, sub=5, planes=5, flat_top=2.9, lump=0.14, rough=0.06, moss_bias=0.5)
    rock(c, (9.2, -1.2, 0.8), (4.6, 3.4, 1.8), rr, sub=4, planes=4, flat_top=1.8, lump=0.14, rough=0.06, moss_bias=0.45)
    rock(c, (-8.4, 3.2, 0.3), (2.0, 1.8, 1.1), rr, sub=3, moss_bias=0.3)
    obj("Frost_Boulder_C", "Stone", c, MATS["Frost_Slate"], smooth=False)


def ice_shards(name, seed, n, Lr, wr, spread):
    rr = random.Random(seed)
    rng.seed(seed)
    ice, bs = bmesh.new(), bmesh.new()
    for _ in range(n):
        a = rr.uniform(0, TAU)
        d = spread * rr.uniform(0, 1) ** 0.7
        base = Vector((math.cos(a) * d, math.sin(a) * d, -0.6))
        tilt, az = rr.uniform(0.0, 0.55) * (0.4 + d / spread), a + rr.uniform(-0.5, 0.5)
        dv = Vector((math.cos(az) * math.sin(tilt), math.sin(az) * math.sin(tilt), math.cos(tilt)))
        L, w = rr.uniform(*Lr) * (1.25 - 0.55 * d / spread), rr.uniform(*wr)
        tube(ice, [base, base + dv * L * 0.12, base + dv * L * 0.7, base + dv * L], [w, w, w * 0.72, 0.04], sides=6, uvs=6.0)
    rock(bs, (0, 0, 0.0), (spread * 1.1, spread * 0.95, 1.7), rr, sub=3, planes=3, bottom=-0.6, lump=0.2, moss_bias=0.5)
    for _ in range(4):
        a = rr.uniform(0, TAU)
        rock(bs, (math.cos(a) * spread, math.sin(a) * spread, 0.1), (1.3, 1.1, 0.9), rr, sub=3, bottom=-0.5, lump=0.2, moss_bias=0.4, S=6.0)
    obj(name, "Base", bs, MATS["Frost_Slate"], smooth=True)
    obj(name, "Ice", ice, MATS["Frost_Ice"], smooth=False)


def scree(name, seed, n, big, R):
    rr = random.Random(seed)
    bm = bmesh.new()
    for _ in range(big):
        r = rr.uniform(1.6, 2.6)
        rock(bm, (rr.uniform(-R * 0.4, R * 0.4), rr.uniform(-R * 0.4, R * 0.4), r * 0.15), (r, r * rr.uniform(0.7, 1.0), r * rr.uniform(0.6, 0.85)), rr, sub=2,
             planes=3, bottom=-0.5, lump=0.2, rough=0.08, rz=rr.uniform(0, 3.14), moss_bias=0.3, S=6.0)
    for _ in range(n):
        a, d = rr.uniform(0, TAU), R * rr.uniform(0, 1) ** 0.7
        r = rr.uniform(0.4, 1.1)
        rock(bm, (math.cos(a) * d, math.sin(a) * d, r * 0.1), (r, r * rr.uniform(0.7, 1.0), r * rr.uniform(0.5, 0.8)), rr, sub=1, planes=2, bottom=-0.3,
             lump=0.25, rough=0.1, rz=rr.uniform(0, 3.14), moss_bias=0.25, S=4.0)
    obj(name, "Stone", bm, MATS["Frost_Slate"], smooth=False)


def cliff_wall(name, seed, W, D, Ht, nl):
    rr = random.Random(seed)
    bm = bmesh.new()
    wall(bm, rr, W, D, Ht, nl)
    talus(bm, rr, -W / 2, W / 2, -D / 2 - 5.0, -D / 2 - 1.0, 5, 1.8, 3.2)
    obj(name, "Stone", bm, MATS["Frost_Slate"], smooth=False)


def cliff_corner():
    rr = random.Random(2715)
    bm = bmesh.new()
    W, D = 30.0, 10.0
    wall(bm, rr, W, D, 26.0, 5)
    n0 = len(bm.faces)
    wall(bm, rr, W, D, 24.0, 5)
    shift(bm, n0, dx=W / 2 + D / 2 - 1.0, dy=W / 2 - D / 2 + 1.0, rz=-math.pi / 2)  # second wall turned 90 degrees; corner block fills the join
    block(bm, (W / 2 - 1.0, 0.0, 11.0), (D + 4, D + 4, 26.0), rr, cuts=9, disp=0.08, dust=0.1, mud_h=1.5)
    talus(bm, rr, -W / 2, W / 2, -D / 2 - 5.0, -D / 2 - 1.0, 4, 1.8, 3.0)
    obj("Frost_Cliff_Corner", "Stone", bm, MATS["Frost_Slate"], smooth=False)


BUILD = [
    ("Frost_Boulder_A", boulder_a), ("Frost_Boulder_B", boulder_b), ("Frost_Boulder_C", boulder_c),
    ("Frost_Ice_Shards_A", lambda: ice_shards("Frost_Ice_Shards_A", 2711, 11, (6.0, 16.0), (0.9, 1.8), 5.0)),
    ("Frost_Ice_Shards_B", lambda: ice_shards("Frost_Ice_Shards_B", 2712, 7, (3.0, 8.0), (0.6, 1.1), 3.5)),
    ("Frost_Cliff_Wall_A", lambda: cliff_wall("Frost_Cliff_Wall_A", 2713, 40.0, 12.0, 30.0, 7)),
    ("Frost_Cliff_Wall_B", lambda: cliff_wall("Frost_Cliff_Wall_B", 2714, 28.0, 10.0, 44.0, 9)),
    ("Frost_Cliff_Corner", cliff_corner),
    ("Frost_Scree_A", lambda: scree("Frost_Scree_A", 2721, 45, 9, 11.0)), ("Frost_Scree_B", lambda: scree("Frost_Scree_B", 2722, 90, 5, 9.0)),
]

prep()
common_mats()
slate_mat()
run_family(BUILD)

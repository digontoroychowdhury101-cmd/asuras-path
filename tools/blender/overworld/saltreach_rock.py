"""Saltreach rock family (lane M5): weathered sea-stack pieces, tide boulders, salt-crust slabs, shore cliff pieces.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b --python tools/blender/overworld/saltreach_rock.py     (env SALT_ONLY=A,B subset, SALT_NORENDER=1)

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Supersedes: nothing (no earlier saltreach rock script; searched first). Linked from LEDGER.md: not yet (outside this lane's write set; integrator adds the row for workers/23b-salt-kit.md).
Why new: the rock family run of the Saltreach kit; writes only assets/source/overworld/saltreach/rock/ + family_rock.json (pack merge via saltreach_lib).
Rocks use slice_kit.rock() on the Salt_Rock atlas: limestone, salt bloom on up-facing patches, wet tide band at the base, rust stain.
"""
from pathlib import Path

exec(compile((Path(__file__).resolve().parent / "saltreach_lib.py").read_text(encoding="utf-8"), "saltreach_lib.py", "exec"))


def srock(name, parts, smooth=True):
    """parts: [(centre, radii, kwargs)] all merged into one Stone sub-mesh on Salt_Rock."""
    rr = random.Random(sum(map(ord, name)))
    bm = bmesh.new()
    for c, R, kw in parts:
        rock(bm, c, R, rr, **kw)
    obj(name, "Stone", bm, MATS["Salt_Rock"], smooth=smooth)
    return bm


def sea_stack_base():
    srock("Sea_Stack_Base", [((0, 0, 8.0), (12.5, 10.5, 12.0), dict(sub=5, planes=6, flat_top=17.0, lump=0.2, rough=0.08, bottom=-1.5, mud_h=3.2, moss_bias=-0.2, S=28.0)),
                             ((11.0, 5.0, 1.8), (5.0, 4.2, 3.4), dict(sub=4, planes=4, lump=0.2, rough=0.08, bottom=-1.0, mud_h=2.4, S=16.0)),
                             ((-10.5, -4.5, 1.2), (4.0, 3.5, 2.6), dict(sub=4, planes=3, lump=0.2, rough=0.08, bottom=-1.0, mud_h=2.0, S=16.0)),
                             ((4.0, -11.0, 0.8), (3.2, 2.8, 1.9), dict(sub=3, planes=3, bottom=-0.8, mud_h=1.8, S=16.0))])


def sea_stack_mid():
    srock("Sea_Stack_Mid", [((0, 0, 8.0), (10.2, 8.8, 12.0), dict(sub=5, planes=8, flat_top=16.0, lump=0.2, rough=0.1, bottom=0.0, mud_h=0.0, moss_bias=-0.5, rz=0.5, S=26.0))])


def sea_stack_cap():
    srock("Sea_Stack_Cap", [((0, 0, 6.5), (8.0, 7.0, 11.0), dict(sub=5, planes=7, lump=0.22, rough=0.1, bottom=0.0, mud_h=0.0, moss_bias=0.6, rz=0.2, S=24.0)),
                            ((6.0, 2.5, 2.0), (3.0, 2.6, 2.6), dict(sub=3, planes=3, bottom=0.0, mud_h=0.0, S=12.0))])


def tide_boulder(name, kind):
    if kind == "A":  # rounded tide-worn boulder + companions
        srock(name, [((0, 0, 3.2), (6.2, 5.4, 4.4), dict(sub=5, lump=0.22, rough=0.08, bottom=-1.0, mud_h=2.2, moss_bias=0.1, S=18.0)),
                     ((7.6, 3.2, 1.2), (3.4, 3.0, 2.4), dict(sub=4, bottom=-1.0, mud_h=1.6, S=12.0)),
                     ((-6.8, -3.6, 0.7), (2.2, 2.0, 1.6), dict(sub=4, bottom=-0.8, mud_h=1.2, S=12.0)),
                     ((3.6, -5.8, 0.3), (1.4, 1.2, 1.0), dict(sub=3, bottom=-0.6, mud_h=1.0, S=8.0))])
    elif kind == "B":  # tall faceted block
        srock(name, [((0, 0, 5.0), (4.2, 3.2, 6.6), dict(sub=5, planes=9, lump=0.16, rough=0.05, rz=0.4, bottom=-1.0, mud_h=2.6, moss_bias=-0.5, S=18.0)),
                     ((5.0, 1.8, 1.6), (3.0, 2.5, 2.8), dict(sub=4, planes=7, lump=0.16, rough=0.05, bottom=-1.0, mud_h=1.8, moss_bias=-0.3, S=12.0)),
                     ((-4.4, -3.0, 0.8), (2.2, 1.8, 1.8), dict(sub=4, planes=6, lump=0.15, rough=0.05, bottom=-0.8, mud_h=1.2, S=12.0))])
    else:  # low flat-topped reef ledge
        srock(name, [((0, 0, 1.6), (8.4, 5.6, 3.4), dict(sub=5, planes=5, flat_top=3.4, lump=0.15, rough=0.07, bottom=-1.0, mud_h=2.0, moss_bias=0.3, S=22.0)),
                     ((12.0, -1.6, 1.0), (4.8, 3.8, 2.4), dict(sub=4, planes=4, flat_top=2.4, lump=0.15, rough=0.07, bottom=-1.0, mud_h=1.6, moss_bias=0.2, S=14.0)),
                     ((-9.4, 4.8, 0.4), (2.2, 1.9, 1.3), dict(sub=3, bottom=-0.6, mud_h=0.8, S=8.0))])


def plate(bm, x, y, z0, sx, sy, sz, rz, tx=0.0, ty=0.0):
    before = set(bm.verts)
    bx(bm, x, y, z0, sx, sy, sz, rz=rz, bev=0.25, uvs=8.0)
    pivot = Vector((x, y, z0 + sz / 2))
    M = Matrix.Rotation(tx, 3, "X") @ Matrix.Rotation(ty, 3, "Y")
    for v in set(bm.verts) - before:
        v.co = M @ (v.co - pivot) + pivot
        v.co.z = max(v.co.z, -0.3)


def crust_slab(name, seed, plates):
    rr = random.Random(seed)
    bm = bmesh.new()
    for (x, y, sx, sy, sz, rz, tx, ty) in plates:
        plate(bm, x, y, 0.0, sx, sy, sz, rz, tx, ty)
    # small salt cairn lumps along the cracks
    for _ in range(5):
        x, y = rr.uniform(-9, 9), rr.uniform(-7, 7)
        plate(bm, x, y, 0.5, rr.uniform(1.0, 2.0), rr.uniform(1.0, 2.0), rr.uniform(0.8, 1.6), rr.uniform(0, 3), 0.2, 0.2)
    obj(name, "Crust", bm, MATS["Salt_Crust"], smooth=False)


def cliff(name, kind):
    rr = random.Random(sum(map(ord, name)))
    bm = bmesh.new()
    rows = []
    if kind == "A":
        for i, h in enumerate((16, 22, 19, 25)):
            rows.append(((-15 + i * 10.2, 0, h / 2 - 1), (7.4, 6.5, h / 2 + 1), 0.0))
    elif kind == "B":
        for i, h in enumerate((20, 28, 30, 22, 26)):
            rows.append(((-18 + i * 9.0, 0, h / 2 - 1), (6.4, 6.0, h / 2 + 1), 0.4 * i))
    else:  # corner: arm along X then along Y
        for i, h in enumerate((18, 24, 28)):
            rows.append(((-10 + i * 9.0, -9 if i < 2 else 0, h / 2 - 1), (6.6, 6.2, h / 2 + 1), 0.0))
        for i, h in enumerate((22, 18)):
            rows.append(((10, 0 + (i + 1) * 9.0, h / 2 - 1), (6.2, 6.6, h / 2 + 1), 0.0))
    for c, R, rz in rows:
        rock(bm, c, R, rr, sub=4, planes=8, flat_top=c[2] + R[2] * 0.82, lump=0.2, rough=0.07, bottom=-2.0, mud_h=3.0, moss_bias=-0.1, rz=rz, S=26.0)
    if kind != "C":
        for v in bm.verts:  # flat back to bed against the terrain bank
            v.co.y = min(v.co.y, 4.5)
    obj(name, "Stone", bm, MATS["Salt_Rock"], smooth=False)


BUILD = [
    ("Sea_Stack_Base", sea_stack_base), ("Sea_Stack_Mid", sea_stack_mid), ("Sea_Stack_Cap", sea_stack_cap),
    ("Tide_Boulder_A", lambda: tide_boulder("Tide_Boulder_A", "A")), ("Tide_Boulder_B", lambda: tide_boulder("Tide_Boulder_B", "B")),
    ("Tide_Boulder_C", lambda: tide_boulder("Tide_Boulder_C", "C")),
    ("Salt_Crust_Slab_A", lambda: crust_slab("Salt_Crust_Slab_A", 901, [(-7, -4, 9.0, 7.0, 0.9, 0.1, 0.02, 0.03), (3, -5, 8.0, 6.5, 0.8, 0.5, -0.03, 0.02),
                                                                          (10, 3, 7.5, 8.0, 1.0, 1.2, 0.03, -0.04), (-4, 4, 8.0, 8.5, 0.9, 0.3, -0.02, -0.03),
                                                                          (4, 8, 7.0, 6.0, 0.8, 0.8, 0.04, 0.02), (-12, 5, 6.0, 7.0, 0.8, 1.5, 0.02, 0.05),
                                                                          (14, -6, 6.5, 6.0, 0.7, 0.2, -0.04, 0.03)])),
    ("Salt_Crust_Slab_B", lambda: crust_slab("Salt_Crust_Slab_B", 902, [(-5, 0, 10.0, 9.0, 1.1, 0.4, 0.07, 0.06), (6, -3, 9.0, 8.0, 1.0, 1.1, -0.08, 0.05),
                                                                          (2, 8, 8.5, 7.0, 0.9, 0.2, 0.06, -0.07), (-8, -9, 7.0, 7.5, 0.9, 0.9, -0.05, 0.08),
                                                                          (12, 7, 6.0, 6.5, 0.8, 0.5, 0.08, 0.02)])),
    ("Shore_Cliff_A", lambda: cliff("Shore_Cliff_A", "A")), ("Shore_Cliff_B", lambda: cliff("Shore_Cliff_B", "B")),
    ("Shore_Cliff_Corner", lambda: cliff("Shore_Cliff_Corner", "C")),
]

run("rock", BUILD, ["Salt_Rock", "Salt_Crust"])

"""Frostmere Heads hero beacon (lane M6): Frost_Beacon_Hero, 18 x 100 x 18 studs, sub-meshes Stone / Timber / Fire (slot Snow_Watch_Beacon, Sink 2).

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b --python tools/blender/overworld/frostmere_hero.py

Supersedes: the Snow_Watch_Beacon blockout (hero_silhouettes.py, assets/source/overworld/hero/) stays on disk as the placeholder; this is the refined replacement
with the same footprint, height and sub-mesh names (src/shared/BiomeDressing.luau slot Snow_Watch_Beacon). Searched first: no earlier Frostmere file exists.
Linked via workers/23c-frost-kit.md (the lane lead links it from LEDGER.md). New file because the hero is its own family run (one script run per family).
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Layout (Z up, base sunk 2 studs, top at 98): double plinth with a timber door under a voussoir arch, a 16-course battered stone shaft (14.6 -> 10.2 wide) with quoins, string
courses and arrow slits, a stepped corbel table carrying a timber-decked gallery with a crenellated stone parapet and a stone hearth, four timber legs rising to a slatted
fuel basket, a tall signal fire, and a tapered timber ladder up the back. Stone uses the Frost_Slate quadrant atlas (snow on every up-facing ledge); slits and the tympanum use the dark quadrant.
"""
from pathlib import Path

FAMILY = "hero"
exec(compile((Path(__file__).resolve().parent / "frostmere_common.py").read_text(encoding="utf-8"), "frostmere_common.py", "exec"), globals())


def place(bm, n0, rz=0.0):
    bm.faces.ensure_lookup_table()
    bmesh.ops.rotate(bm, verts=list({v for f in bm.faces[n0:] for v in f.verts}), cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(rz, 3, "Z"))


def beacon():
    rr = random.Random(2901)
    rng.seed(2901)
    S, T, F = bmesh.new(), bmesh.new(), bmesh.new()
    dark = set()

    def mark(n0):
        S.faces.ensure_lookup_table()
        dark.update(S.faces[n0:])

    # plinth, door, arch
    bx(S, 0, 0, -2.0, 18.0, 18.0, 11.0, bev=0.25)
    bx(S, 0, 0, 9.0, 16.2, 16.2, 2.6, bev=0.2)
    for sx in (-1, 1):
        bx(S, sx * 2.15, -8.6, 0.0, 0.8, 0.8, 6.4, bev=0.08)  # jambs
    arch(S, 0.0, -8.6, 6.4, 1.7, 0.8, 0.8, n=9)
    n0 = len(S.faces)
    arch(S, 0.0, -8.85, 6.4, 0.05, 1.65, 0.3, n=10)  # dark tympanum
    mark(n0)
    for k in range(6):  # door boards
        bx(T, -1.4 + 0.56 * k + 0.28, -8.9, 0.0, 0.54, 0.3, 6.3, mode="timber", bev=0.04, uvs=6.0)
    # shaft
    w = lambda z: 14.6 - (z - 11.6) / 52.4 * 4.4
    ch = 52.4 / 16
    for i in range(16):
        z = 11.6 + i * ch
        wi = w(z)
        bx(S, 0, 0, z, wi, wi, ch - 0.04, bev=0.12, rz=rr.uniform(-0.01, 0.01))
        e = wi / 2 + 0.5
        for sx in (-1, 1):
            for sy in (-1, 1):
                lx, ly = (2.8, 1.6) if i % 2 == 0 else (1.6, 2.8)
                bx(S, sx * (e - lx / 2), sy * (e - ly / 2), z, lx, ly, ch - 0.04, bev=0.1)
    for z in (30.0, 46.0):  # string courses
        bx(S, 0, 0, z, w(z) + 1.4, w(z) + 1.4, 0.7, bev=0.1)
    for j, z in enumerate((21.0, 33.0, 45.0, 57.0)):  # arrow slits on the front, east and west faces
        for face in ((0, 1, 3) if j % 2 == 0 else (1, 3)):
            n0 = len(S.faces)
            bx(S, 0, -w(z) / 2 - 0.05, z, 0.8, 0.3, 2.6, bev=0.04)
            mark(n0)
            bx(S, 0, -w(z) / 2 - 0.1, z + 2.6, 1.9, 0.6, 0.45, bev=0.06)
            bx(S, 0, -w(z) / 2 - 0.1, z - 0.45, 1.9, 0.6, 0.45, bev=0.06)
            place(S, n0, rz=face * math.pi / 2)
    # corbel table, gallery floor edge, parapet, hearth
    for zc, wc, hc in ((64.0, 12.4, 1.1), (65.1, 14.4, 1.1), (66.2, 16.6, 1.1)):
        bx(S, 0, 0, zc, wc, wc, hc, bev=0.1)
    bx(S, 0, 0, 67.3, 18.0, 18.0, 0.9, bev=0.2)
    for i in range(5):
        x = -6.4 + 3.2 * i
        for sy in (-8.55, 8.55):
            bx(S, x, sy, 68.2, 2.4, 0.9, 2.4, bev=0.1)
        for sx in (-8.55, 8.55):
            bx(S, sx, x, 68.2, 0.9, 2.4, 2.4, bev=0.1)
    cyl(S, 0, 0, 68.2, 4.2, 3.8, 2.6, seg=12)
    # timber: deck, legs, ties, basket, ladder
    for k in range(9):
        bx(T, -8.0 + 2.0 * k, 0, 68.2, 1.94, 17.0, 0.5, mode="timber", bev=0.05, uvs=6.0)
    legs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            a, b = Vector((sx * 7.4, sy * 7.4, 70.4)), Vector((sx * 2.6, sy * 2.6, 84.0))
            tube(T, [a, a.lerp(b, 0.5), b], [0.6, 0.55, 0.5], sides=6, uvs=6.0)
            legs.append(a.lerp(b, 0.559))
    for p, q in ((0, 1), (1, 3), (3, 2), (2, 0)):
        tube(T, [legs[p], legs[q]], [0.35, 0.35], sides=5, uvs=4.0)
    cyl(T, 0, 0, 83.6, 3.0, 2.8, 0.6, seg=10, uvs=4.0)
    for k in range(10):  # basket staves
        a = k * TAU / 10
        bx(T, math.cos(a) * 2.7, math.sin(a) * 2.7, 84.2, 0.55, 0.55, 3.0, mode="timber", bev=0.05, uvs=4.0, rz=a)
    for z in (85.0, 86.8):
        for k in range(10):
            a = (k + 0.5) * TAU / 10
            bx(T, math.cos(a) * 2.85, math.sin(a) * 2.85, z, 1.7, 0.35, 0.35, mode="timber", bev=0.04, uvs=4.0, rz=a + math.pi / 2)
    yl = lambda z: w(z) / 2 + 0.55
    for sx in (-0.9, 0.9):
        tube(T, [Vector((sx, yl(12.0), 11.6)), Vector((sx, yl(38.0), 38.0)), Vector((sx, yl(64.0) - 0.3, 66.8))], [0.2, 0.2, 0.2], sides=4, uvs=4.0)
    for z in np.arange(13.0, 66.5, 2.4):
        bx(T, 0, yl(z), z, 2.0, 0.22, 0.22, mode="timber", bev=0.03, uvs=4.0)
    # fire
    for (fx, fy, prof) in ((0.0, 0.0, [(0.01, 86.8), (2.2, 87.3), (2.4, 88.5), (1.7, 91.0), (0.8, 94.5), (0.02, 98.0)]),
                           (1.6, 0.9, [(0.01, 87.0), (1.1, 87.5), (1.2, 89.0), (0.6, 91.5), (0.02, 94.0)]),
                           (-1.4, -1.2, [(0.01, 87.0), (1.2, 87.5), (1.3, 88.8), (0.6, 91.5), (0.02, 93.5)]),
                           (-0.4, 1.8, [(0.01, 87.0), (1.0, 87.5), (1.0, 89.0), (0.5, 91.0), (0.02, 92.6)])):
        lathe(F, prof, x=fx, y=fy, seg=10, turns=1, uvs=4.0)
    lathe(F, [(0.01, 86.6), (2.6, 86.8), (2.3, 87.4), (0.01, 87.6)], seg=12, turns=1, uvs=4.0)  # ember bed
    S.normal_update()
    slate_uv(S, list(S.faces), rr, S=16.0, mud_h=1.5, dust=0.1, dark=dark)
    obj("Frost_Beacon_Hero", "Stone", S, MATS["Frost_Slate"], recalc=True)
    obj("Frost_Beacon_Hero", "Timber", T, MATS["Frost_Timber"])
    obj("Frost_Beacon_Hero", "Fire", F, MATS["Frost_Glow"], smooth=True)


BUILD = [("Frost_Beacon_Hero", beacon)]
prep()
frost_built_mats()
run_family(BUILD)
if not NORENDER:  # second view: the gallery, hearth and fire from a ridge-height eye (crown view)
    sc, cam, ground = bpy.context.scene, bpy.data.objects["cam"], bpy.data.objects["Ground"]
    shoot(sc, cam, Vector((0, -62.0, 52.0)), Vector((0, 0, 80.0)), 40.0, CAP / "eye_Frost_Beacon_Hero_top.png")
    print("AMBER_PIECE_EXTRA", "eye_Frost_Beacon_Hero_top.png", flush=True)

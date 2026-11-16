"""Ashen Stair hero temple (lane M7): Ash_Summit_Pagoda (60 x 160 x 60 studs XYZ Roblox: Stone / Timber / Roof / Bronze) and Ash_Summit_Wing
(40 x 60 x 50: Stone / Roof / Timber), the refined replacements for the Summit_Temple_Pagoda / Summit_Temple_Wing slots in src/shared/BiomeDressing.luau.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/ashen_hero.py

Supersedes: the hero_silhouettes.py blockouts assets/source/overworld/hero/Summit_Temple_Pagoda.glb and Summit_Temple_Wing.glb stay on disk as the placeholders; these are the
refined replacements with the same sizes and sub-mesh names (the wing slot has no Bronze sub-mesh, so the wing's bronze rides in Timber).
Linked via workers/23d-ashen-kit.md (the lead links it from LEDGER.md). New file because the hero is its own family run (one script run per family).
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Pagoda: stair-notched three-tier stone terrace (front stair on -Y), five timber storeys (vermilion body, pillars, brackets) each under an upturned dark basalt-tile hip roof
that steps in 24.5 -> 10.5 studs, bronze hip horns and eave bells, one tall bronze spire. Reads as a stepped, widening-down silhouette from ~1000 studs (C3 ruling 6).
Wing: same language, two roof tiers on a two-tier plinth, built square and squeezed to 40 wide (x scale 0.8).
"""
from pathlib import Path

FAMILY = "hero"
exec(compile((Path(__file__).resolve().parent / "ashen_common.py").read_text(encoding="utf-8"), "ashen_common.py", "exec"), globals())


def plinth(s, H, z0, z1, notch, y_back, uvs=12.0):
    """Square terrace of half-width H split around a front stair notch (|x| < notch, y < y_back)."""
    for sx in (-1, 1):
        w = H - notch
        bx(s, sx * (notch + w / 2), 0, z0, w, 2 * H, z1 - z0, bev=0.3, uvs=uvs)
    bx(s, 0, (y_back + H) / 2, z0, 2 * notch, H - y_back, z1 - z0, bev=0.3, uvs=uvs)


def treads(s, y0, n, tread, rise, half, uvs=12.0):
    for i in range(n):
        bx(s, 0, y0 + i * tread + tread / 2, -3.0, 2 * half - 0.2, tread, (i + 1) * rise + 3.0, bev=0.16, uvs=uvs)


def bellh(b, x, y, z, k):
    """Small hanging bronze bell (8 sided)."""
    lathe(b, [(0.3 * k, 2.2 * k), (0.55 * k, 2.1 * k), (0.9 * k, 1.6 * k), (1.2 * k, 0.7 * k), (1.35 * k, 0.2 * k), (1.4 * k, 0), (1.15 * k, 0), (0.95 * k, 0.6 * k),
              (0.6 * k, 1.5 * k), (0.2 * k, 1.9 * k)], x=x, y=y, z0=z, seg=8)


def tiered(s, t, rf, b, base0, tiers, rr):
    """Stack of timber storeys, each under an upturned hip roof. tiers = [dict(hw, sh, h, n, nt)]: eave half-width, storey height, roof rise, roof grid, tails per side.
    Returns (top z of the last roof, its roof dict)."""
    prev, top = None, None
    for i, T in enumerate(tiers):
        hw, sh, h = T["hw"], T["sh"], T["h"]
        a = hw * 0.52
        P = a + 1.0
        base = base0 if i == 0 else top - 3.0
        z0 = base + sh
        R = dict(hw=hw, z0=z0, h=h, flat=0.2, p=1.6, curl=0.3 * hw, thick=0.12 * hw)
        zb = base0 if i == 0 else roof_pt(prev, P / prev["hw"], P / prev["hw"]).z - 0.6  # wall + pillars sink into the lower roof
        bx(t, 0, 0, zb, 2 * a, 2 * a, z0 + 1.0 - zb, bev=0.12, uvs=8.0)  # vermilion storey body
        r = max(0.5, 0.034 * hw)
        for px, py in ((-P, -P), (P, -P), (-P, P), (P, P), (0, P), (-P, 0), (P, 0)) + (((0, -P),) if i else ()):
            cyl(t, px, py, zb, r, r * 0.85, z0 - zb + 0.2, seg=10)
            for k, w in enumerate((r * 3.2, r * 5.0)):
                bx(t, px, py, z0 - 1.5 + k * 0.7, w, w, 0.7, mode="timber", bev=0.04, uvs=4.0)
        for sy in (-P, P):
            bx(t, 0, sy, z0 - 2.3, 2 * P + 1.2, r * 1.4, 1.0, mode="timber", bev=0.05, uvs=6.0)
        for sx in (-P, P):
            bx(t, sx, 0, z0 - 2.3, r * 1.4, 2 * P + 1.2, 1.0, mode="timber", bev=0.05, uvs=6.0)
        roof(rf, R, n=T["n"])
        tails(t, R, T["nt"], 0.35 + 0.012 * hw)
        horns(b, R, 0.04 * hw + 0.2)
        kb = 0.3 + 0.3 * hw / 24.5
        for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):  # bell hung just inside each eave corner
            c = roof_pt(R, sx, sy)
            bellh(b, c.x * 0.93, c.y * 0.93, c.z - R["thick"] - 2.4 * kb, kb)
        prev, top = R, z0 + h
    return top, prev


def pagoda():
    rr = random.Random(2991)
    s, t, rf, b = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    # terrace: 60 / 52 / 46 square plinths, front stair (13 treads, y -30 .. -4) cut through all three
    plinth(s, 30.0, -2.0, 4.0, 6.0, -4.0)
    plinth(s, 26.0, 4.0, 8.0, 6.0, -4.0)
    plinth(s, 23.0, 8.0, 12.0, 6.0, -4.0)
    treads(s, -30.0, 13, 2.0, 12.0 / 13, 5.9)
    for sx in (-1, 1):  # parapet blocks on the top plinth, open at the stair
        for i in range(15):
            bx(s, sx * 22.4, -21.0 + i * 3.0 + 1.5, 12.0, 1.4, 2.8, 2.0, bev=0.1, uvs=6.0)
        x = 7.5
        while x < 21.0:
            bx(s, sx * (x + 1.5), -22.4, 12.0, 2.8, 1.4, 2.0, bev=0.1, uvs=6.0)
            x += 3.0
    for i in range(15):
        bx(s, -21.0 + i * 3.0 + 1.5, 22.4, 12.0, 2.8, 1.4, 2.0, bev=0.1, uvs=6.0)
    for sx in (-1, 1):  # stone lantern posts on the middle plinth corners
        for sy in (-1, 1):
            for z, w, h in ((8.0, 2.4, 1.4), (9.4, 1.5, 3.2), (12.6, 2.6, 0.9)):
                bx(s, sx * 25.0, sy * 25.0, z, w, w, h, bev=0.1, uvs=6.0)
    a0 = 24.5 * 0.52
    for sx in (-1, 1):  # stone portal on the first storey
        bx(s, sx * 3.4, -a0 - 0.9, 12.0, 1.6, 1.3, 9.6, bev=0.1, uvs=6.0)
    bx(s, 0, -a0 - 0.9, 21.6, 8.6, 1.4, 1.2, bev=0.12, uvs=6.0)
    bx(t, -1.5, -a0 - 0.3, 12.0, 2.8, 0.5, 9.0, mode="timber", bev=0.05, uvs=4.0)
    bx(t, 1.5, -a0 - 0.3, 12.0, 2.8, 0.5, 9.0, mode="timber", bev=0.05, uvs=4.0)
    tiers = [dict(hw=24.5, sh=20, h=11, n=22, nt=24), dict(hw=21.0, sh=18, h=10, n=20, nt=22), dict(hw=17.5, sh=16, h=9, n=18, nt=20),
             dict(hw=14.0, sh=14, h=8, n=16, nt=18), dict(hw=10.5, sh=13, h=7.5, n=14, nt=16)]
    top, R = tiered(s, t, rf, b, 12.0, tiers, rr)
    finial(b, top - 0.3, 2.8, seg=16)  # the tall bronze spire: carries the skyline at 1000 studs
    obj("Ash_Summit_Pagoda", "Stone", s, MATS["Ash_Stone"])
    obj("Ash_Summit_Pagoda", "Timber", t, MATS["Ash_Timber"])
    obj("Ash_Summit_Pagoda", "Roof", rf, MATS["Ash_Roof"])
    obj("Ash_Summit_Pagoda", "Bronze", b, MATS["Ash_Bronze"])


def wing():
    rr = random.Random(2992)
    s, t, rf = bmesh.new(), bmesh.new(), bmesh.new()
    b = t  # the wing slot has no Bronze sub-mesh (Stone / Roof / Timber): horns, bells and the finial ride in Timber
    plinth(s, 25.0, -2.0, 3.0, 4.5, -7.0)
    plinth(s, 21.0, 3.0, 6.0, 4.5, -7.0)
    treads(s, -25.0, 9, 2.0, 6.0 / 9, 4.4)
    a0 = 20.0 * 0.52
    for sx in (-1, 1):
        bx(s, sx * 2.8, -a0 - 0.9, 6.0, 1.4, 1.2, 8.0, bev=0.1, uvs=6.0)
    bx(s, 0, -a0 - 0.9, 14.0, 7.0, 1.2, 1.0, bev=0.1, uvs=6.0)
    bx(t, -1.2, -a0 - 0.3, 6.0, 2.4, 0.5, 7.6, mode="timber", bev=0.05, uvs=4.0)
    bx(t, 1.2, -a0 - 0.3, 6.0, 2.4, 0.5, 7.6, mode="timber", bev=0.05, uvs=4.0)
    tiers = [dict(hw=20.0, sh=17, h=10, n=18, nt=17), dict(hw=14.2, sh=12, h=8, n=14, nt=13)]
    top, R = tiered(s, t, rf, b, 6.0, tiers, rr)
    finial(b, top - 0.3, 0.65, seg=12)
    for bm in (s, t, rf):  # build square, then squeeze to a 40 wide hall
        scale_xy(bm, 0, sx=0.8)
    obj("Ash_Summit_Wing", "Stone", s, MATS["Ash_Stone"])
    obj("Ash_Summit_Wing", "Roof", rf, MATS["Ash_Roof"])
    obj("Ash_Summit_Wing", "Timber", t, MATS["Ash_Timber"])


def silhouette(name, sc, cam, ground):
    """Roblox default 70 degree vertical FOV on a 1920x1080 frame from 850 studs: how the landmark reads across the map."""
    objs = PIECES[name]
    lo, hi = bbox(objs)
    ground.scale, ground.location = (3000, 3000, 1), Vector((0, 0, 0))
    ht = hi.z
    shoot(sc, cam, Vector(((lo.x + hi.x) / 2, -850.0, 5.0)), Vector(((lo.x + hi.x) / 2, 0, ht * 0.45)), 12 / math.tan(math.radians(35)), CAP / f"sil_{name}.png",
          res=(1920, 1080), vert=True)


BUILD = [("Ash_Summit_Pagoda", pagoda), ("Ash_Summit_Wing", wing)]
prep()
built_mats()
run_family(BUILD, extra=silhouette)

"""Amberfall aqueduct masonry builders (lane M4), exec'd after amberfall_common.py by amberfall_built.py and amberfall_hero.py.

Supersedes: nothing (the hero blockout in hero_silhouettes.py stays as the placeholder; this is the refined masonry). Linked via workers/23a-amber-kit.md
(the lead links it from LEDGER.md). New file because the span sections and the hero share one set of pier / arch / spandrel / deck builders.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

All builders append to three bmeshes: P (piers), A (arch rings + spandrel fill), D (deck: corbel course, slab, parapets). Blender X = along the aqueduct, Y = depth, Z up.
"""


def pier(bm, rr, cx, y, w, d, z0, z1, bw_=0.0, bd=0.0, ch=2.0, clip=None, bev=0.1):
    """Courses of blocks from z0 to z1; width / depth grow toward the base by bw_ / bd per side (batter). clip = (xmin, xmax) cuts to the piece edge."""
    z = z0
    while z < z1 - 0.05:
        h = min(ch * rr.uniform(0.92, 1.12), z1 - z)
        if z1 - (z + h) < 0.8:
            h = z1 - z
        f = (z1 - (z + h / 2)) / max(z1 - z0, 1e-6)
        x0, x1 = cx - (w / 2 + bw_ * f), cx + (w / 2 + bw_ * f)
        if clip:
            x0, x1 = max(x0, clip[0]), min(x1, clip[1])
        if x1 - x0 > 0.3:
            brick_h(bm, x0, x1, z, z + h, y, d + 2 * bd * f, rr, bw=(2.2, max(3.0, (x1 - x0) * 0.8)), bev=bev)
        z += h


def spandrel(bm, rr, cx, span, r_out, spring, z_top, y, d, ch=1.8, bev=0.1):
    """Masonry courses from the springline to z_top in the bay |x - cx| < span/2, leaving the arch opening (stepped just inside the ring)."""
    z = spring
    xl, xr = cx - span / 2, cx + span / 2
    while z < z_top - 0.05:
        h = min(ch * rr.uniform(0.92, 1.12), z_top - z)
        if z_top - (z + h) < 0.7:
            h = z_top - z
        dz = z + h - spring
        if dz >= r_out:
            brick_h(bm, xl, xr, z, z + h, y, d, rr, bw=(3.0, 4.6), bev=bev)
        else:
            xo = math.sqrt(r_out ** 2 - dz ** 2)
            for a, b in ((xl, cx - xo), (cx + xo, xr)):
                if b - a > 0.3:
                    brick_h(bm, a, b, z, z + h, y, d, rr, bw=(2.2, 3.6), bev=bev)
        z += h


def deck(bm, rr, x0, x1, z, y, d, slab=2.2, par=1.6, par_t=1.3, bev=0.1):
    """Corbel course under the slab (projects a little), slab, and two parapets leaving a water channel between them."""
    bx(bm, (x0 + x1) / 2, y, z - 0.9, x1 - x0, d + 0.9, 0.9, bev=bev)
    brick_h(bm, x0, x1, z, z + slab, y, d, rr, bw=(4.0, 6.0), bev=bev)
    for sg in (-1, 1):
        brick_h(bm, x0, x1, z + slab, z + slab + par, y + sg * (d / 2 - par_t / 2), par_t, rr, bw=(3.0, 5.0), bev=bev)


def bay(P, A, D, rr, cx, span, pw, y, d_pier, d_arch, spring, r_in, thick, z0, deck_z, bw_=0.0, bd=0.0, clip=None, piers=(True, True), n=13,
        ch=2.0, bev=0.1, with_deck=False, d_deck=None):
    """One arch bay: its pier(s) from z0 to deck_z, the voussoir ring, the spandrel fill and (optionally) the deck run across the bay."""
    r_out = r_in + thick
    for sg, on in zip((-1, 1), piers):
        if on:
            px = cx + sg * (span / 2 + pw / 2)
            pier(P, rr, px, y, pw, d_pier, z0, spring - 0.9, bw_, bd, ch, clip, bev)
            x0, x1 = px - pw / 2 - 0.4, px + pw / 2 + 0.4  # impost block the ring springs from
            if clip:
                x0, x1 = max(x0, clip[0]), min(x1, clip[1])
            bx(P, (x0 + x1) / 2, y, spring - 0.9, x1 - x0, d_pier + 0.4, 0.9, bev=bev)
            pier(P, rr, px, y, pw, d_pier, spring, deck_z, 0.0, 0.0, ch, clip, bev)
    arch(A, cx, y, spring, r_in, thick, d_arch + 0.4, n=n)
    spandrel(A, rr, cx, span, r_out, spring, deck_z, y, d_arch, bev=bev)
    if with_deck:
        lo, hi = cx - span / 2 - pw / 2, cx + span / 2 + pw / 2
        if clip:
            lo, hi = max(lo, clip[0]), min(hi, clip[1])
        deck(D, rr, lo, hi, deck_z, y, d_deck or d_arch, bev=bev)

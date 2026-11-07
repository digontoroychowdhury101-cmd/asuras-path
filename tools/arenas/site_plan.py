#!/usr/bin/env python3
"""AR00 site plan: old/new arena footprints, overlap tests and the rendered top-down map.

    work/bin/luau/luau tools/arenas/spatial_extract.luau > OUT/spatial-current.json
    python tools/arenas/site_plan.py OUT

Reads OUT/spatial-current.json (tools/arenas/spatial_extract.luau) and writes OUT/spatial-manifest.json,
OUT/OVERLAPS.md, OUT/site-plan.png and OUT/site-<arena>.png. Proposals live in PLAN below; they are the
reviewable AR00 decision, not engine-measured facts. All coordinates are XZ studs, floor Y=0.
"""
from __future__ import annotations
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WALK = 22.4  # CombatSettings.Movement.WalkSpeed, live Humanoid value measured in C00
SPRINT = 33.6

# Arena plan. core = (cx, cz, sx, sz). Variant B is the chosen 1.0 target; A is the ~0.8 linear variant.
# 'own' are the zones the arena legitimately replaces/extends; 'migrate' records the planned changes.
PLAN = {
    'GrandmasterShen': {
        'title': 'AR01 The Ashen Covenant', 'region': 'AshColosseum', 'ownZones': ['AC_Arena', 'AC_South'],
        'A': (0, -1971, 192, 152), 'B': (0, -1990, 240, 190),
        'regionAfter': {'centre': [0, 40, -1900], 'size': [480, 200, 440]},
        # Scenic: lateral sightlines only. The split cenotaph stands south-west (x ~ -330, z ~ -2180), outside
        # every region's X range, so nothing scenic lands inside the Pagoda region.
        'service': (-150, 150, -1877, -2120), 'scenic': (-420, 420, -1700, -2300),
        'gateX': 0,
        'why': 'Z is pinned between the Champions Hall facade (z -1877, both hall foe pockets) and the Pagoda cloud stair '
               '(z -2120, CelestialPagoda region). The bowl grows mainly east-west; the region widens to 480 so the '
               'cavea and outer ash banks stay inside it, and the valley-wall terrain moves out with the bounds.',
        'migrate': ['Boss.Arena centre/size', 'FogGate placement/trigger/inside/outside (north face unchanged)',
                    'boss Spawn (engagement 45 studs, not half the floor)', 'AC_Arena / AC_South zones and doors',
                    'Victor gate mark, causeway, Veil fences', 'Region bounds X 360->480', 'ColosseumDressing positions',
                    'Objectives BOSS_APPROACH unchanged (gate outside)'],
    },
    'TwinSentinels': {
        'title': 'AR02 Broken Processional Court', 'region': 'DesecratedMonastery', 'ownZones': [],
        'A': (330, -948, 208, 216), 'B': (340, -975, 260, 270),
        'regionAfter': {'centre': [0, 40, -900], 'size': [1000, 200, 440]},
        'service': (190, 490, -800, -1118), 'scenic': (120, 760, -640, -1300),
        'gateX': 300,
        'why': 'Keep the north gate on the courtyard road (z -840) and grow south-east, clear of the Cloister (x<=128) '
               'and of Bamboo Pass (x<=200 below z -1120). EastPass zone and the monastery bounds widen east.',
        'migrate': ['Boss.Arena/Spawn/FogGate (gate X stays 300: needs an entrance offset or a gate move to x340)',
                    'MonasteryZones.EastPass x1 404->490', 'Region bounds X 900->1000', 'CourtyardRoad end',
                    'Twins duo separation checks'],
    },
    'VenerableBaize': {
        'title': 'AR03 Frost-Hollow Hunting Ground', 'region': 'BambooPass', 'ownZones': ['BP_Arena'],
        'A': (-48, -1454, 240, 160), 'B': (-60, -1474, 300, 200),
        'regionAfter': {'centre': [-20, 40, -1400], 'size': [520, 200, 560]},
        'service': (-230, 110, -1366, -1590), 'scenic': (-520, 380, -1250, -1700),
        'gateX': 0,
        'why': 'Depth is pinned by the shrine (z -1366) and the moon-gate descent (z -1577): a west side-basin instead '
               'of scale-in-place. The Foundry wing (x -192..-140) ends at z -1345, north of the basin.',
        'migrate': ['Boss.Arena/Spawn/FogGate (entrance offset or shrine path bend)', 'BP_Arena zone', 'BossBodies.pillars offsets',
                    'Region bounds X 400->520 (centre x -20)', 'Bamboo backdrop terrain', 'BP_Ridge overlap review'],
    },
    'SlumberingTitan': {
        'title': 'AR04 Cathedral Beneath the Roots', 'region': 'SanctuaryDepths', 'ownZones': ['SD_Arena'],
        'A': (526, 840, 224, 256), 'B': (554, 808, 280, 320),
        'regionAfter': {'centre': [560, 40, 860], 'size': [440, 200, 480]},
        'service': (400, 720, 1046, 630), 'scenic': (300, 900, 1200, 450),
        'gateX': 520,
        'why': 'Hold the west edge at x 414 (ossuary, loft, reliquary) and the north edge at z 968 (nave); grow east '
               'and south into the uncut cavern. The arena mouth moves east along the nave.',
        'migrate': ['Boss.Arena/Spawn/FogGate (mouth x520->554 in the nave)', 'SD_Arena zone', 'Region bounds',
                    'Titan chains (SD-04) and pit catch review', 'Ceiling roots non-colliding'],
    },
    'SovereignWu': {
        'title': 'AR05 Starless Mirror Court', 'region': 'CelestialPagoda', 'ownZones': ['CP_Arena'],
        'A': (0, -2380, 272, 176), 'B': (0, -2380, 340, 176),
        'regionAfter': {'centre': [0, 40, -2330], 'size': [440, 200, 420]},
        'service': (-180, 180, -2252, -2540), 'scenic': (-600, 600, -2200, -2700),
        'gateX': 0,
        'why': 'The forecourt/loft (z -2292) and the dawn terrace/summit bridge (z -2470..-2540) pin depth; the court '
               'opens sideways into a connected mirror expanse and noncolliding lake beyond.',
        'migrate': ['Boss.Arena size', 'CP_Arena zone', 'four corner HanPagodaHD placements and their rock pillars',
                    'Region bounds X 360->440', 'Wu teleport clamp/retreat review'],
    },
    'AzureWyrm': {
        'title': 'AR06 Storm-Crowned Expanse', 'region': 'SkyCitadel', 'ownZones': ['SC_Arena'],
        'A': (0, -2916, 320, 352), 'B': (0, -2960, 400, 440),
        'regionAfter': {'centre': [0, 40, -2880], 'size': [520, 200, 680]},
        'service': (-210, 210, -2670, -3190), 'scenic': (-800, 800, -2600, -3600),
        'gateX': 0,
        'why': 'Nothing lies south of the summit, so the landing shelf extends south from the bastion gate (z -2740); '
               'the bastion and return portal stay outside the flight floor.',
        'migrate': ['Boss.Arena/Spawn', 'SC_Arena zone, summit catch', 'CampaignTerrain perch/support absolute coords',
                    'Region bounds Z 440->680', 'BossMotion aerial review'],
    },
}
BASE = {'GrandmasterShen': (120, 130)}


def rect(c):
    cx, cz, sx, sz = c
    return (cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2)  # x0, x1, zmin, zmax


def overlap(a, b):
    return a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3]


def zrect(z):
    return (z['x0'], z['x1'], min(z['z0'], z['z1']), max(z['z0'], z['z1']))


def main(out: Path) -> int:
    data = json.loads((out / 'spatial-current.json').read_text(encoding='utf-8'))
    manifest = {'source': 'tools/arenas/spatial_extract.luau + site_plan.py', 'walkSpeed': WALK, 'arenas': {}}
    lines = ['# AR00 overlap tests', '', 'AABB tests of each proposed combat core against every zone, altar pocket, foe spawn, lore tablet, cache, '
             'PvP ring and region bound it does not own. "Own" zones are replaced by the arena. Heights are ignored on purpose '
             '(conservative): stacked crypt/pagoda levels count as conflicts until resolved.', '']
    for bid, plan in PLAN.items():
        boss = data['bosses'][bid]
        oc = (boss['centre'][0], boss['centre'][2], boss['size'][0], boss['size'][2])
        entry = {'title': plan['title'], 'region': plan['region'], 'old': {'centre': [oc[0], 0, oc[1]], 'size': [oc[2], oc[3]]},
                 'why': plan['why'], 'migrate': plan['migrate'], 'regionBefore': data['regions'][plan['region']],
                 'regionAfter': plan['regionAfter'], 'variants': {}}
        lines += [f"## {plan['title']} ({bid})", '', plan['why'], '']
        for v in ('A', 'B'):
            c = plan[v]
            r = rect(c)
            conflicts = []
            for z in data['zones'] + [dict(m, region='DesecratedMonastery') for m in data['monastery']]:
                if z['id'] in plan['ownZones']:
                    continue
                if overlap(r, zrect(z)):
                    conflicts.append(f"zone {z['id']} ({z.get('region')})")
            pts = []
            for k, a in data['altars'].items():
                pts.append((f'altar {k}', a['placement'][0], a['placement'][2], a['radius'] + 3.5))
            for s in data['spawns']:
                pts.append((f"spawn {s['id']}", s['placement'][0], s['placement'][2], 6))
            for k, l in data['lore'].items():
                pts.append((f'lore {k}', l['at'][0], l['at'][2], 5))
            for k, l in data['caches'].items():
                pts.append((f'cache {k}', l['at'][0], l['at'][2], 5))
            for g in data['rings']:
                pts.append((f"ring {g['id']}", g['centre'][0], g['centre'][2], g['apothem'] + g['band']))
            for name, x, z, rad in pts:
                if r[0] - rad < x < r[1] + rad and r[2] - rad < z < r[3] + rad:
                    conflicts.append(name)
            for rid, reg in data['regions'].items():
                if rid == plan['region']:
                    continue
                rr = (reg['centre'][0] - reg['size'][0] / 2, reg['centre'][0] + reg['size'][0] / 2, reg['centre'][2] - reg['size'][2] / 2, reg['centre'][2] + reg['size'][2] / 2)
                if overlap(r, rr):
                    conflicts.append(f'region {rid}')
            ra = plan['regionAfter']
            inside = (r[0] >= ra['centre'][0] - ra['size'][0] / 2 and r[1] <= ra['centre'][0] + ra['size'][0] / 2
                      and r[2] >= ra['centre'][2] - ra['size'][2] / 2 and r[3] <= ra['centre'][2] + ra['size'][2] / 2)
            area = c[2] * c[3]
            run = {'centreToSide': round(min(c[2], c[3]) / 2 / WALK, 2), 'centreToCorner': round(math.hypot(c[2], c[3]) / 2 / WALK, 2),
                   'fullLength': round(max(c[2], c[3]) / WALK, 2), 'cornerToCorner': round(math.hypot(c[2], c[3]) / WALK, 2),
                   'cornerToCornerSprint': round(math.hypot(c[2], c[3]) / SPRINT, 2)}
            entry['variants'][v] = {'centre': [c[0], 0, c[1]], 'size': [c[2], c[3]], 'rect': {'x0': r[0], 'x1': r[1], 'zN': r[3], 'zS': r[2]},
                                     'areaFactor': round(area / (oc[2] * oc[3]), 2), 'insideRegionAfter': inside,
                                     'conflicts': conflicts, 'walkSeconds': run,
                                     'lockBreakExceededByDiagonal': math.hypot(c[2], c[3]) > 80}
            lines.append(f"- **{v}** {c[2]}x{c[3]} at ({c[0]}, {c[1]}): area x{area / (oc[2] * oc[3]):.2f} of baseline; inside planned region: "
                         f"{'yes' if inside else 'NO'}; conflicts: {', '.join(conflicts) if conflicts else 'none'}; walk centre->side "
                         f"{run['centreToSide']} s, corner->corner {run['cornerToCorner']} s ({run['cornerToCornerSprint']} s sprint).")
        entry['gateX'] = plan['gateX']
        entry['service'] = dict(zip(('x0', 'x1', 'zN', 'zS'), plan['service']))
        entry['scenic'] = dict(zip(('x0', 'x1', 'zN', 'zS'), plan['scenic']))
        lines += ['', 'Planned migration: ' + '; '.join(plan['migrate']) + '.', '']
        manifest['arenas'][bid] = entry
    (out / 'spatial-manifest.json').write_text(json.dumps(manifest, indent=1), encoding='utf-8')
    (out / 'OVERLAPS.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    render(data, out)
    return 0


def render(data, out: Path) -> None:
    try:
        font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 15)
        big = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 20)
    except Exception:
        font = big = ImageFont.load_default()

    def draw_area(name, x0, x1, zmin, zmax, scale, file, focus=None):
        W, H = int((x1 - x0) * scale) + 40, int((zmax - zmin) * scale) + 80
        im = Image.new('RGB', (W, H), (24, 25, 28))
        d = ImageDraw.Draw(im)

        def P(x, z):  # north (+Z) at top
            return (20 + (x - x0) * scale, 60 + (zmax - z) * scale)

        def R(r, **kw):
            a, b = P(r[0], r[3]), P(r[1], r[2])
            d.rectangle([min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])], **kw)
        grid = 100 if scale > 0.6 else 200
        for gx in range(int(x0 // grid * grid), int(x1) + 1, grid):
            d.line([P(gx, zmin), P(gx, zmax)], fill=(36, 38, 42))
            d.text(P(gx + 2, zmax - 2), str(gx), fill=(80, 82, 88), font=font)
        for gz in range(int(zmin // grid * grid), int(zmax) + 1, grid):
            d.line([P(x0, gz), P(x1, gz)], fill=(36, 38, 42))
            d.text(P(x0 + 2, gz + 2), str(gz), fill=(80, 82, 88), font=font)
        for rid, reg in data['regions'].items():
            c, s = reg['centre'], reg['size']
            R((c[0] - s[0] / 2, c[0] + s[0] / 2, c[2] - s[2] / 2, c[2] + s[2] / 2), outline=(70, 90, 120), width=1)
            d.text(P(c[0] - s[0] / 2 + 3, c[2] + s[2] / 2 - 3), rid, fill=(100, 125, 160), font=font)
        for z in data['zones'] + data['monastery']:
            R(zrect(z), outline=(110, 110, 100), width=1)
        for bid, plan in PLAN.items():
            boss = data['bosses'][bid]
            ra = plan['regionAfter']
            R((ra['centre'][0] - ra['size'][0] / 2, ra['centre'][0] + ra['size'][0] / 2, ra['centre'][2] - ra['size'][2] / 2, ra['centre'][2] + ra['size'][2] / 2),
              outline=(60, 140, 200), width=2)
            sc = plan['scenic']
            R((sc[0], sc[1], sc[3], sc[2]), outline=(70, 70, 130), width=1)
            se = plan['service']
            R((se[0], se[1], min(se[2], se[3]), max(se[2], se[3])), outline=(150, 120, 60), width=1)
            oc = (boss['centre'][0], boss['centre'][2], boss['size'][0], boss['size'][2])
            R(rect(oc), outline=(220, 70, 60), width=2)
            R(rect(plan['A']), outline=(230, 200, 90), width=1)
            R(rect(plan['B']), outline=(90, 220, 120), width=3)
            b = rect(plan['B'])
            d.text(P(b[0] + 4, b[3] - 4), plan['title'].split(' ')[0], fill=(140, 240, 160), font=big)
        for k, a in data['altars'].items():
            x, _, z = a['placement'][:3]
            p = P(x, z); d.ellipse([p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4], fill=(250, 170, 60))
        for s in data['spawns']:
            p = P(s['placement'][0], s['placement'][2]); d.ellipse([p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3], fill=(200, 80, 200))
        for g in data['fogGates'].values():
            p = P(g['placement'][0], g['placement'][2]); d.rectangle([p[0] - 5, p[1] - 2, p[0] + 5, p[1] + 2], fill=(255, 240, 120))
        for g in data['rings']:
            p = P(g['centre'][0], g['centre'][2]); r = (g['apothem']) * scale
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], outline=(120, 200, 230), width=2)
        d.text((20, 8), name, fill=(240, 240, 240), font=big)
        d.text((20, 34), 'red: current arena · yellow: variant A (~0.8) · green: chosen B · blue: planned region · brown: service/entry · indigo: scenic envelope · grey: zones · orange: altars · magenta: foes · gold bar: fog gate',
               fill=(170, 170, 170), font=font)
        im.save(out / file)

    draw_area('AR00 site plan: campaign chain (north at top, studs)', -460, 760, -3700, -600, 0.33, 'site-plan.png')
    draw_area('AR00 site plan: Sunken Crypt (Titan)', 280, 920, 420, 1220, 1.0, 'site-SlumberingTitan.png')
    for bid, plan in PLAN.items():
        if bid == 'SlumberingTitan':
            continue
        ra = plan['regionAfter']
        x0, x1 = ra['centre'][0] - ra['size'][0] / 2 - 40, ra['centre'][0] + ra['size'][0] / 2 + 40
        zmin, zmax = ra['centre'][2] - ra['size'][2] / 2 - 40, ra['centre'][2] + ra['size'][2] / 2 + 40
        draw_area(f"AR00 site plan: {plan['title']}", x0, x1, zmin, zmax, 1500 / (x1 - x0) if (x1 - x0) > 900 else 1.6, f'site-{bid}.png')


if __name__ == '__main__':
    raise SystemExit(main(Path(sys.argv[1])))

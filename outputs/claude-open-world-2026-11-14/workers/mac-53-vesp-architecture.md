# mac-53: Vesperhold architecture kit upgrade (groups A-E, Ruined_Arch, waterfalls)

Worker: mac-53 (observed model: Opus 5.5, claude-opus-5-5). Branch ux/onboarding-overhaul. Not committed: the lead commits.

## Plan (priority order from the lead)
1. Spire stack (Base_Oct, Belfry, Lucarne, Needle, Broken, Tower stage) + C3 render with 5-stud mannequin.
2. West front (Portal_Great, Rose_Window_Great, Lancet_Tall/Pair) + D4_west_front assembly render.
3. Glass (gen_glass rewrite, polar UVs on roses).
4. Arcades / bastion / buttresses / flyers / viaduct density + weathering + ledge-only frost.
5. Ruined_Arch, waterfalls (props), manifest merge fix (vesp_common.run + kit main).
6. Full kit + props regen, embed sizes, renders to outputs/vesperhold/kit-renders-v2/.

## Status log
- Session 1 (before the 429): TILE retune (Soot 64, Charcoal 15, Slate 14) and gen_glass rewrite landed in vesperhold_kit.py.
  The lead's recovery run (candidate-2026-11-19/kit) shows the glass now reads as leaded medallions; next: per-sub UVs, weathering,
  ledge frost, manifest merge, spire stack.
- Session 2 (19:00-19:30, code only, untested until the lock frees):
  - vesperhold_kit.py: per-sub UV hook, noise weathering (amp 0.16, faded at z=0 and stack interfaces; not on glass/iron/frost),
    ledge-only frost (nz >= 0.72, narrow ledges, patchy), manifest merge, stone finials. Spire stack + west front rebuilt
    (tower_stage, spire_base_oct, belfry, lucarne_mid, needle_tip, broken_top, rose/rose_great/rose_small, lancet_tall/pair,
    portal_great) with blind arcading, wimpergs, pinnacle clusters, gargoyles, statue niches. Composite renders C3/C3b/D4 with a
    5-stud mannequin. Group A/B/E density pass: bay (wimperg on a backing slab, buttresses with gablets/blind panels/gargoyles,
    pinnacle clusters), bastion_face (irregular coursed rubble, relieving arch, machicolation), buttress_pier (gablets + engaged
    pinnacles on every set-off, flank blind panels), flying_buttress (cusped lancet web, finials, gargoyle spout), viaduct_bay
    (4 stepped rolled orders, 3-shaft clustered piers, stepped cutwaters with caps, gargoyles), arcade_corner (cluster + gargoyles).
  - vesp_common.py: run() merges the manifest; finish_mixed(weather=) opt-in; gen_water feathered 4-column card map;
    Vesp_Water back-face culled (cards carry explicit back faces).
  - vesperhold_props.py: Ruined_Arch and Waterfall_Sheet_A/B builders rewritten (see below); `ruined_arch.cfg` adds weather.
  - Waterfall banding diagnosis: each strip was a 0.05-thick two-sided shell with 6 layers 0.45 apart; dark lines sat on every row
    boundary. New cards: single sheets (duplicated-vert back faces, culled), v = arclength, feathered column edges, 3 layers >= 1.1 apart.

## Blender runs (heavy lock each time; memory_pressure free % before -> after)
| Run | Pieces | Before -> after | Result |
|---|---|---|---|

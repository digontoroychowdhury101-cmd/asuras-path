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

## Blender runs (heavy lock each time; memory_pressure free % before -> after)
| Run | Pieces | Before -> after | Result |
|---|---|---|---|

# win-63: Vesperhold architecture kit density on Windows (spire stack, west front, viaduct, arcades, Ruined_Arch, waterfalls)

Worker: win-63 (observed model: Opus 5.5, claude-opus-5-5). Branch ux/onboarding-overhaul. Not committed: the lead commits.
Continues mac-53 (session-2 code edits were never run). Rules: mac-50 (never decimate, subs < 18,000 tris, CC0 Poly Haven tiled
maps 2048, black Metal linked, shared origins, GLB < 50 MB, one heavy job machine-wide).

## Plan
1. Run the mac-53 session-2 spire stack (Base_Oct, Belfry, Lucarne, Needle, Broken, Tower stage) + C3 composite (5-stud mannequin); fix.
2. West front (Portal_Great, Rose_Window_Great, Lancet_Tall/Pair) + D4 assembly; fix.
3. Viaduct bay + balustrade, arcade bays, bastion, buttresses, flyers; fix.
4. Ruined_Arch + Waterfall_Sheet_A/B (props; manifest backed up, statues + gargoyles verified after every run).
5. Review sheets in outputs/vesperhold/kit-renders-win/.

Output: assets/source/vesperhold/candidate-win-2026-11-19/{kit,props}. Maps reused (VESP_REUSE_MAPS=1) from the candidate copy.

## Files (owned)
tools/blender/vesperhold/vesperhold_kit.py, vesp_common.py, vesperhold_props.py (Ruined_Arch / Waterfall only).

## Blender runs (heavy lock each; free RAM before -> after)
| Run | Pieces | Mem | Result |
|---|---|---|---|
| r1 | 6 spire pieces (mac-53 session-2 code as left) | 5.1 -> 5.4 GB | ok 14 s; dense, but louvres frosted white, continuous frost rings, spear "foils" read as a broken clock face, tower lancets blind rubble, C3 stood on the ground without the tower stage |
| r2 | same + louvre sub (no frost), patchy ledge frost, glazed tower lancets, gable blind lights, C3 = tower + spire stack (~246) beside a broken stack | 6.6 -> 6.3 GB | ok 13 s; glass a cropped wallpaper grid, foils still notched rings, C3 framed too far |
| r3 | spire 6 + west front (Portal_Great, Rose_Window_Great/Small, Lancet_Tall/Pair, Buttress_Pier); lobed foils (n tangent lobes, sharp cusps), medallion-column glass UVs on lancets | 6.4 -> 6.4 GB | ok 15 s; west front reads; D4 backdrop hid the great rose glass, portal gable a bare rubble triangle, glass ground blue-heavy pinwheels |

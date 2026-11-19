# win-61: Vesperhold hooded statues, pass 2 (Windows PC)

Worker: win-61 (observed model: Opus 5.5, claude-opus-5-5). Branch ux/onboarding-overhaul. Not committed (lead commits).
Continues mac-51 (`mac-51-vesp-statues.md`). Rules: `mac-50-vesp-rebuild-rules.md`. Open items: `WINDOWS_HANDOFF.md` §3.

## Plan
1. Clay-check the mac-51 pass-2 shapes (never rendered after the edits), one piece per Blender run.
2. Fix the open oversight items in `vesperhold_figures.py` (sleeves, P chest, hood seam, slender silhouette, A/B 22-23 studs),
   grade in `vesp_bake.py` only via optional params (win-62 imports it).
3. Bake 2048 per piece into `assets/source/vesperhold/candidate-win-2026-11-19/props` (never the Mac candidate).
4. Review sheet `outputs/vesperhold/kit-renders-win/F1_statues_win.jpg` (q34, side, close, far fog per statue), < ~1 MB.

## Files
- tools/blender/vesperhold/vesperhold_figures.py, tools/blender/vesperhold/vesp_bake.py (owned).

## Blender runs (heavy lock each time; free RAM before -> after)
- 22:06 clay A (mac-51 pass-2 shapes, 32 spp, q34/side/close/far34): ok, 65 s, 3.4 -> 3.8 GB
- 22:10 clay B: ok, 3.9 -> 3.7 GB; clay P: ok, 3.7 -> 3.9 GB; clay Scan: ok, 3.9 -> 3.8 GB
  Clay verdict: hoods small and gnome-pointed (heads tiny at range); capelet a wide bell with pie-crust scallops; A's
  fingers poke out of the cuffs like twigs; elbow bunching rings too regular (puffer jacket); B torso a blank barrel;
  P tabard/cloak opening/clasp now read (no blank oval). Scan reads haunting (veil, crown, chains, sword, book).
  Edits: HOOD_S 1.18, PEAK_S 0.7; per-figure `slim` XY scale (A/B 0.88, P 0.92; plinth follows); capelet hem
  ragged-but-worn; A hands tucked into the cuffs; irregular diagonal elbow bunching; chest folds to the capelet
  (n4 11, amp4 0.14, chest 1.0).
- 22:23 clay A iter2: ok, 3.7 -> 3.8 GB (top 22.91 studs; wrist tubes poked out of the bent sleeves -> wrist shortened)
- 22:25 clay B iter2: ok, 3.8 -> 3.9 GB (top 22.96 studs; slender, chest folds read)
- 22:29 bake A 2048 #1: ok, 4.0 -> 4.6 GB, 213 s (AO 19 s, ~30 s/role). Albedo median 0.094 (too dark, folds vanish), soot streaks
  barely fire, frost only as hard salt blotches on the plinth. -> vesp_bake.Look gains optional streak_lo/hi, wash,
  frost_nz, frost_break (defaults = old behaviour, win-62 unaffected); figures use STONE_LOOK (base 0.16).
- 22:38 bake A 2048 #2 (STONE_LOOK v1, frost 0.85): ok, ~3.5 min; median albedo 0.106; streaks read, frost soft but thin.
  -> frost 1.0, frost_nz (0.35, 0.75); far-view fog 0.014 -> 0.009 (statue washed pale; refs read dark).
- 22:43 bake A 2048 #3 (final): ok, 5.0 -> 5.4 GB
- 22:46 bake B 2048: ok, 5.4 -> 5.3 GB (reads like ref_05 staff-bearer; grip palm boxy)
- 22:51 bake P 2048: ok, 5.2 -> 6.2 GB (cloak, tabard V folds, clasp read; grip palms boxy)
- 22:56 bake Scan 2048: ok, 6.2 -> 6.2 GB, 44 s (frost on the wide flat plinth/train read as camouflage)
  -> grip palm superellipsoid e 0.4 -> 0.8; scan frost 0.6 with even breakup (0.22, 0.6).
- 23:05 bake Scan 2048 (final): ok, 5.6 -> 6.2 GB (frost now an even dusting, no camouflage)
- 23:07 bake B 2048 (final): ok, 6.2 -> 6.2 GB (round grip fist)
- 23:11 bake P 2048 (final): ok, 6.2 -> 6.4 GB
No Blender run went below 3.4 GB free; no retries needed. Sheet and embeds use PIL only (not heavy).

## Result (all in `assets/source/vesperhold/candidate-win-2026-11-19/props`)
Final tris per sub (low, shipped; every sub < 18,000 asserted in split_cap; never decimated):
| Piece | Subs (tris) | Total | High bake source | Height |
|---|---|---|---|---|
| Hooded_Statue_A | Robe 17164, Robe_2 17164, Hood 9312, Hood_2 9312, Arms 9772, Arms_2 9772, Plinth 216 | 72,712 | 2,373,220 | 22.9 |
| Hooded_Statue_B | Robe 17164, Robe_2 17164, Hood 9312, Hood_2 9312, Arms 8952, Arms_2 8952, Plinth 216, Staff 8776 | 79,848 | 2,552,276 | 23.0 figure, 27.6 staff |
| Pedestal_Statue_Staff | Robe 13242/13244/13244, Hood 12336/12336/12338, Arms 12612/12612, Plinth 13848, Sword 2642 | 118,454 | 3,685,244 | 23.4 |
| Statue_Veiled_Scan | Body 13869, Body_2 13870, Plinth 216 | 27,955 | 654,111 | 18.5 |
Maps: 2048 px for every role (Color, tangent Normal, Roughness, Metal; Metal black on stone, live on staff iron/verdigris).
Base layer: Poly Haven rock_04 2K (CC0), desaturated (sat 0.15). Weighted normals on every low; pivot = foot centre, z min 0.
GLBs (no images): A 1.9, B 2.1, P 3.3, Scan 0.9 MB. Embedded (vesp_embed, VESP_NORMAL=jpeg) in `props/embedded/`:
A 7.8, B 8.5, P 11.3, Scan 5.3 MB (all < 50 MB). Albedo (A final) median ~0.1, p95 ~0.2 sRGB, grey-black.
Sheet: `outputs/vesperhold/kit-renders-win/F1_statues_win.jpg` (q34, side, close, far fog per statue; 350 KB).

## Still weak (honest)
- A's cuffs read as open trumpet bells from the front; the tucked fingers barely show. Elbow bunching is softer but still smooth.
- Hands overall are simple (B/P fists are rounder now but still not sculpted fingers up close).
- Torso between capelet and belt on A/B is still a smooth barrel with shallow folds; robes read clean-ish at close range,
  weathering is mostly in the maps (streaks, cavity grime, frost on hood tops, cuffs, plinth tops), not in the silhouette.
- Frost on the capelet shoulders is faint (the hood covers the flattest part).
- Scan plinth is a 15.5 x 15.5 stud square slab (sized to the scan's train): too big for niches; a rectangular or
  smaller plinth would place better. Scan figure itself reads best of the four.
- Pedestal sword is plain (fuller only); the far fog views are a render test, not an in-game capture.

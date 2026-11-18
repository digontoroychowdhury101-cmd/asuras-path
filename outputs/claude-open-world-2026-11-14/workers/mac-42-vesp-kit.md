# mac-42 Vesperhold kit A-E (worker log, 2026-11-19)

Supersedes: nothing. Linked from CONTINUATION.md "Vesperhold — 2026-11-19". New because no gothic kit exists. Order: lead's mac-42 order per workers/mac-41-vesperhold-plan.md.

## Plan
- tools/blender/vesperhold/vesperhold_kit.py: one headless script. Own tiny mesh builder (welded primitives: prism-with-holes, sweep, loft, lathe) -> bmesh recalc normals -> triplanar UV -> auto-split subs at 15.5k tris (assert < 18k, never decimate) -> frost = up-facing faces copied to a Frost sub -> GLB per piece -> manifest.json -> contact sheets.
- 7 materials at 2048 (Color/Normal/Roughness/Metal, Metal always linked, black for non-metal): Soot, Charcoal, Frost, Slate, Iron, Verdigris, Glass.
- 31 pieces, groups A-E per the mac-41 table. Output assets/source/vesperhold/kit (+ renders/), upload pack assets/source/vesperhold/upload/kit via make_upload_pack.py (vesperhold target, registry assets/VESPERHOLD_KIT_UPLOADED.json).

## Files
- tools/blender/vesperhold/vesperhold_kit.py (new)
- tools/blender/overworld/make_upload_pack.py (minimal: vesperhold kit entry + UPLOAD.md + optional kit arg)
- assets/source/vesperhold/kit/**, assets/source/vesperhold/upload/kit/** (generated)

## Checkpoints
- run1 (maps+geometry+GLB, no render): 31 pieces exported in 19s total, every sub < 18k (max 11.9k after split), mem free 49% -> 40%. Fixed Arcade_Bay archivolt overhang past x=+-20.
- run2 (maps reuse + renders): 12 contact sheets in assets/source/vesperhold/kit/renders/. Fixes after looking: gable holes exceeded the gable triangle, frost on tiny cusps (area>=1.0, nz>=0.6 now), iron crust too heavy, finials moved to Verdigris, crocketed hood moulds on arcade/lancet/portal/viaduct arches.
- run3 final (full, maps regenerated): 27 s wall, 31 GLBs, max sub 11,880 tris, mem free 52% -> 40%. Upload pack built: assets/source/vesperhold/upload/kit (31 GLB, 28 maps, upload_manifest.json problems: none, UPLOAD.md). make_upload_pack.py extended (vesperhold/kit entry, registry assets/VESPERHOLD_KIT_UPLOADED.json, optional kit arg).
- Not done: no Studio import / upload; GLBs carry no embedded textures (maps/ is the single source); nothing committed.

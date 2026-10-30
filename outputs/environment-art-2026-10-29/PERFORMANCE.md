# Environment performance — incomplete acceptance

Apple M5 MacBook Air (10 CPU cores / 8 GPU cores / 16 GB RAM), Studio 0.745.0.7451137, local Play. Logical viewport 1221 × 503; screenshots 1920 × 790. Saved and editor quality Automatic; entry run reports Detailed landscape. ~60 fps median/mean pacing is observed; the exact FramerateCap API is unavailable. Measurements use RenderStepped dt and Stats.RenderCPUFrameTime/RenderGPUFrameTime. Stats memory includes this Studio session; it is not a standalone mobile-client memory result.

| Run | Scope / focus | Frame p95 | CPU p95 | GPU p95 | Result |
|---|---|---:|---:|---:|---|
| Original baseline | 60.01s, Bamboo → Monastery, 276.4 studs; 19 initially unknown / 0 unfocused | 17.21 ms | 16.27 ms | 14.52 ms | 16.7 ms target not met; not final representative route |
| Entry v6 first attempt | 60.03s; background/unknown focus contamination | 67.53 ms | 16.11 ms | 14.14 ms | **Invalid for performance comparison** |
| Entry v6 foreground repeat | 60.01s / 3601 frames; 358.46 studs; normal movement/jump/dodge/attack/lock inputs; repeated Bamboo/Monastery entry; 0 unknown / 0 unfocused | 17.57 ms | 16.70 ms | 14.52 ms | **16.7 ms target not met**; not final Baize/full-pass route |

The traces differ, so these runs do not establish an exact before/after regression delta. Automatic graphics can adapt. Neither the old 24 fps cap nor a physical-mobile result was observed here. No physical mobile device has been verified; ≤33.3 ms Balanced mobile acceptance stays open.

Foreground entry run: memory start/peak/end 4728.1/4808.7/4801.1 MB. Registrations remain 373. Maximum sampled one-second mean wind update 0.285 ms. Separate v6 timed-motion capture mean 0.228 ms, maximum reported peak 2.10 ms.

Entry composition at foreground start: 631,318 visible triangles / 219 draw calls including terrain, native grass, particles and UI; separately **938,414 shadow triangles / 666 shadow draw calls**. Native Grass contributes 29,382 triangles / 20 draws. These are view-dependent diagnostics, not whole-asset counts. Next: inspect distance-bounded culm shadow cost and confirm graphics-tier behavior, then repeat a genuinely equivalent final 60-second traversal/combat route. Retain the existing targets.

Raw evidence: `baseline_sample.json`, `entry-performance-v6/sample.json` (invalid focus), `entry-performance-v6/foreground-sample.json`, `entry-wind-v6/motion_summary.json`.

## v8 pause checkpoint

The production fine-foliage shadow budget is implemented, but its first short before/after diagnostics were background-throttled (FRM 2, ~15 fps, GPU counters near zero). They are invalid for performance comparisons. V7 normal-quality captures reached FRM 21 and ~60 fps; their short GPU p95 values were 13.28–14.19 ms, but initial focus was unknown. V8 changes the grove distribution, broken/fallen assets, arena dressing/floor and mist, so a new qualified 60-second traversal/combat run is still required. The last valid 17.57 ms p95 remains the outstanding result; neither desktop nor physical-mobile acceptance is claimed. Work paused at the user's request.

## v9 slice close — Mac Studio diagnostics only

Same Mac (Apple M5 MacBook Air), Studio Play, Automatic quality, 1221 × 503 viewport. **No qualified foreground timing was obtained.** Studio stayed off-Space or the screen was locked, and the focus observer recorded no focus event after activation. The A/B timing runs (`final-slice-v9/slice-cost-ab-background-invalid.json`) were throttled to ~15 fps with GPU counters at 0 and 483/485 unknown-focus frames. They are **invalid** and not cited. The 17.57 ms p95 from v6 remains the last valid run; the 16.7 ms desktop target is still **not met / not re-measured**.

Valid cost evidence is rendered composition (unaffected by frame pacing), with this slice's additions present vs hidden client-side at the same pinned cameras (`tools/qa/SliceComposition.luau`):

| Camera | First pass (present / hidden) | After budget (present / hidden) | Added after budget |
|---|---:|---:|---:|
| Arena (combat view) | 473,478 / 312,195 tris; 146 / 134 draws | 381,809 / 315,203; 141 / 129 | **+66,606 tris (+21%), +12 draws** |
| Moon gate | 381,202 / 217,212; 135 / 132 | 283,515 / 220,224; 130 / 129 | **+63,291 (+29%), +1 draw** |

The first pass was material (+52% at the arena), so the slice was optimized before closing: the south clumps lost their sculpted crowns (~72k tris at the arena) and dropped to one fern each. Budgeted totals stay below the v6 entry view's 631,318 visible triangles. Registered moving plants are 792 (v8: 736); the active wind set is capped at 112 Detailed / 64 Balanced, unchanged. Raw files: `slice-composition-prebudget.json`, `slice-composition-budgeted.json`.

**Open gates (not claimable from this Mac):** desktop ≤16.7 ms p95 over a 60-second foreground traversal and Baize combat on the Windows machine; physical-mobile ≤33.3 ms Balanced; a Balanced-tier composition check of the new south grove; and a GPU timing delta for this slice under foreground conditions.

## 30 October continuation

`../environment-art-2026-10-30/mixed-run-not-acceptance.json` records 60.00 s / 3,299 frames,
p95 20.15 ms, including 97 unfocused frames and a death/respawn into Sanctuary. Its foreground
subset p95 is 17.65 ms; the mixed route is not the required Baize/full-pass sequence. It does not
replace the last valid v6 result or establish an art regression delta. Balanced emulator views
(750×381, iPhone 17 Pro preset, Automatic quality) validate 792 registered / 64 active plants;
no physical-mobile timing is claimed. Sanctuary's existing 1.18M-triangle monument contributes
814k–999k rendered triangles at the two forward cameras; a material tint adds no geometry.

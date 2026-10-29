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

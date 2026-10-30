# Bamboo Pass baseline — screenshot-grounded defects

All images are from the unchanged canonical game in Studio Play, ordinary player-height cameras,
FOV 70, HUD retained, automatic quality, original regional lighting. Camera/state metadata:
`baseline-eight/before_cameras.json`. These are teleported Studio diagnostics, not earned traversal.

| Priority | Visible problem and evidence | Resolving change | State |
|---|---|---|---|
| 1 | Entry, close path and ground transition show isolated culms, large sky holes and little overlapping foliage; the grove reads as evenly scattered poles. | Five clump silhouettes, irregular patch edges, near-route vertical curtains and broad drooping upper crowns, followed by same-camera review. | Clustered grove zones and broken/fallen units integrated v8–v9; final full-route/coverage gates remain open. |
| 2 | Entry/ground transition/shrine show bare, uniformly green ground with no root-to-soil transition or middle-scale cover. | Grounded fern colonies, litter, shoots, rocks and localized native Grass openings; retain clear combat/camera volumes. | Ferns/litter/grass/shoots and soil beds integrated; scanned roots/trunk grounded and inspected v9. Regional coverage remains in review. |
| 3 | Close path/ground transition show a broad white retaining-wall shape across the crest and ridge. | Localized frost on ledges, weathered rock transitions and irregular snow margins while preserving authored floor elevations. | v9: ridge/crest drifts are sunk irregular disc clusters, off paved floors. V10 material-only mask breaks the straight crest lip; same-camera review shows exposed irregular stone, with occupancy/colliders unchanged. |
| 4 | Entry gate and shrine are conspicuous flat bars, boards and roof planes; joinery and grounded construction are absent. | Reuse original uploaded stone bases, columns, brackets and tiled roof modules. Preserve existing collision and altar access. | Gate uses uploaded joinery/roof v5; shrine pavilion and planting integrated v8 and reviewed v9. |
| 5 | Arena view exposes four rectangular frost pillars and a flat green fight floor. Bright yellow light bands compete with the stone/frost identity. | Dress exact colliders with weathered rock/frost shells, keep silhouettes and dodge gaps; correct localized floor materials and light falloff after geometry. | Stone shells/paving integrated v8; actual body, pounce and impact captured v10. Sustained fight and performance gates remain open. |
| 6 | Frost overlook has oversized stone grain and a flat parapet; the reverse arena lacks a layered edge. | Shared erosion/stone modules, better texture scale, planted edge detail and a coherent arena surround. | v9: parapet coping and end crags added; the paving reads cleanly at an 8 s settle. Stone grain scale and the reverse arena edge are unchanged: partly open. |
| 7 | Moon gate has a faceted arch with mismatched box jambs and a bare road immediately beyond it. | Logical stone voussoirs/coping, planted shoulders and layered southern grove framing, with gate aperture preserved. | **Resolved v9** (`final-slice-v9/after_moon_gate.jpg`): 25 voussoirs with coping and keystone, jamb shells over unchanged colliders, planted shoulders, budgeted southern grove. |
| 8 | All views show a cyan atmospheric wash; near vegetation and characters have weak material/value separation. | Refine neutral fill, atmospheric depth and canopy shading after geometry and materials work together. | v5 fill/tint improved; further material/value and other-region inspection remains open. |

At the unchanged baseline, motion was absent in imported foliage. GlobalWind=(0,0,0) and LeafyGrass terrain do not
establish native Grass or custom-mesh animation. A rooted, spatially budgeted client wind prototype
will be verified by actual part motion and a running-client capture.

The eight baseline images are captured and reviewed. The numbered arena entrance image does not
yet provide an active Baize combat/telegraph comparison; that additional gameplay check remains open.

Current wind proof: `entry-wind-v6/` timed client frames and transforms show subtle bamboo, fern, shoot and grass motion; rooted error <0.001 stud. Late-part/reentry and actual reduced-motion UI checks pass. Continuous wind/traversal video remains open.

New angled-view defect: `entry-wind-v6/frame_000.jpg` exposes the fallen JadeRootGiant as a conspicuous green cylinder. Replace it with an original branching, grounded root/trunk asset; retain lore access and camera clearance.

Performance blocker to scaling: the valid foreground entry diagnostic is 17.57 ms p95 versus 16.7 required. Native Grass renders, but distant culm shadow cost and final route/tier/device gates remain open. See `PERFORMANCE.md`.

V8 handoff: all original grove zones now use clustered silhouettes; three broken clumps and two fallen poles are integrated. The shrine has a modeled pavilion and planted edges. The green cylinder is replaced by a licensed scanned trunk/root assembly, but needs a dedicated close inspection. The four arena blocks have stone pillar shells over unchanged collision proxies, and the paving slab is exposed at its original Y=0. Mist/brazier treatment is restrained. These are checkpoint improvements, not full resolution: remaining moon-gate/overlook/snow margins, texture repetition, final composition, active combat/camera clearance and performance acceptance remain open.

V9 close (30 October 2026): the final eight ordinary views plus `root_detail` are in `final-slice-v9/` (before/after, same cameras, 8 s settle). New defect found and fixed: the scanned fallen trunk floated 2.1–4.6 studs above the soil; it now bears on the ground (±0.5 stud). Active Baize combat (`combat/`): banner, telegraph ring, target mark, player and sword are readable over the paving and the camera is clear; **Baize's body and sustained-fight camera clearance are not yet captured** (Air Glide opener killed the level-1 test character in three seeds). Still open: crest snow lip, overlook stone grain/reverse edge, texture repetition, and the Windows/hardware gates in `PERFORMANCE.md`.

V10: see `../environment-art-2026-10-30/README.md`. Snow border corrected, four Balanced emulator views inspected, normal-health Baize body/pounce captured. Sustained fight, video, full-route and hardware gates stay open.

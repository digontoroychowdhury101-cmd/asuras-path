# Bamboo Pass baseline — screenshot-grounded defects

All images are from the unchanged canonical game in Studio Play, ordinary player-height cameras,
FOV 70, HUD retained, automatic quality, original regional lighting. Camera/state metadata:
`baseline-eight/before_cameras.json`. These are teleported Studio diagnostics, not earned traversal.

| Priority | Visible problem and evidence | Resolving change | State |
|---|---|---|---|
| 1 | Entry, close path and ground transition show isolated culms, large sky holes and little overlapping foliage; the grove reads as evenly scattered poles. | Five clump silhouettes, irregular patch edges, near-route vertical curtains and broad drooping upper crowns, followed by same-camera review. | Entry slice substantially improved in v5; remaining groves and broken/fallen silhouettes still open. |
| 2 | Entry/ground transition/shrine show bare, uniformly green ground with no root-to-soil transition or middle-scale cover. | Grounded fern colonies, litter, shoots, rocks and localized native Grass openings; retain clear combat/camera volumes. | Grounded imported ferns/litter/grass/shoots and soil beds visible in entry v5; roots and other zones open. |
| 3 | Close path/ground transition show a broad white retaining-wall shape across the crest and ridge. | Localized frost on ledges, weathered rock transitions and irregular snow margins while preserving authored floor elevations. | Rock below thin snow cap visible; slab outline/irregular margins still open. |
| 4 | Entry gate and shrine are conspicuous flat bars, boards and roof planes; joinery and grounded construction are absent. | Reuse original uploaded stone bases, columns, brackets and tiled roof modules. Preserve existing collision and altar access. | Gate improved with uploaded modular roof/joinery in v5; shrine still open. |
| 5 | Arena view exposes four rectangular frost pillars and a flat green fight floor. Bright yellow light bands compete with the stone/frost identity. | Dress exact colliders with weathered rock/frost shells, keep silhouettes and dodge gaps; correct localized floor materials and light falloff after geometry. | Pending. |
| 6 | Frost overlook has oversized stone grain and a flat parapet; the reverse arena lacks a layered edge. | Shared erosion/stone modules, better texture scale, planted edge detail and a coherent arena surround. | Pending. |
| 7 | Moon gate has a faceted arch with mismatched box jambs and a bare road immediately beyond it. | Logical stone voussoirs/coping, planted shoulders and layered southern grove framing, with gate aperture preserved. | Pending. |
| 8 | All views show a cyan atmospheric wash; near vegetation and characters have weak material/value separation. | Refine neutral fill, atmospheric depth and canopy shading after geometry and materials work together. | v5 fill/tint improved; further material/value and other-region inspection remains open. |

At the unchanged baseline, motion was absent in imported foliage. GlobalWind=(0,0,0) and LeafyGrass terrain do not
establish native Grass or custom-mesh animation. A rooted, spatially budgeted client wind prototype
will be verified by actual part motion and a running-client capture.

The eight baseline images are captured and reviewed. The numbered arena entrance image does not
yet provide an active Baize combat/telegraph comparison; that additional gameplay check remains open.

Current wind proof: `entry-wind-v6/` timed client frames and transforms show subtle bamboo, fern, shoot and grass motion; rooted error <0.001 stud. Late-part/reentry and actual reduced-motion UI checks pass. Continuous wind/traversal video remains open.

New angled-view defect: `entry-wind-v6/frame_000.jpg` exposes the fallen JadeRootGiant as a conspicuous green cylinder. Replace it with an original branching, grounded root/trunk asset; retain lore access and camera clearance.

Performance blocker to scaling: the valid foreground entry diagnostic is 17.57 ms p95 versus 16.7 required. Native Grass renders, but distant culm shadow cost and final route/tier/device gates remain open. See `PERFORMANCE.md`.

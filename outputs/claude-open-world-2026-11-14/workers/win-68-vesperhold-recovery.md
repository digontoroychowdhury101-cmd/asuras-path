# Vesperhold Windows recovery and review

Codex resumed the creator's “Asura's Path Mac handoff resume” Claude chat after the usage limit. The branch started at
`e3b471c` with the pass 4 Blender edits in the worktree. The existing upload ledgers cover 38 approved Vesperhold pieces
in 67 Model assets and 101 forest re-tones. All 168 uploads were read back in the original upload session. A fresh
registry check against the Windows candidate matched the 205 submeshes registered for the 38 pieces.

## Held art

Claude's five statue bakes and four-piece tree bake survived the chat interruption. They completed under the shared
lock. The two viaduct GLBs came from Claude's final scratch exports. Codex rebuilt the waterfalls after the latest
waterfall and texture edits so the exported transparencies match the current generators.

The Wraith bake warned about a zero denominator in the new cavity shading. The blade's median and fourth-percentile
pointiness were equal. About 60.5% of pixels covered by the sword normal bake came out black in the Color map. The
cavity pass now skips this term where those percentiles coincide. A focused NumPy check passed with floating-point
division and invalid-value errors enabled. It tested both flat and concave samples, including black stone Metal maps.
The fresh sword Color map measured 0% fully black against the same exported Normal-map mask. The blade remains dark.

The assembled pack covers 13 pieces and 86 submeshes (726,889 triangles). Geometry uses the authored split meshes
without decimation. Direct GLB checks matched the manifests, confirmed foot origins and bounds, and read all used
PBR images at 2048 × 2048. Non-metal materials have black Metal maps. The packed Metal channel matches the source
byte for byte. Both waterfalls carry 2K RGBA Color maps with transparent texels and use glTF BLEND.

| Held piece | Height (studs) | Triangles | Largest submesh | Parts |
|---|---:|---:|---:|---:|
| Wraith | 23.5 | 154,840 | 16,744 | 2 |
| Mourner and tomb | 18.6 | 170,028 | 17,368 | 2 |
| Hooded monk A | 22.9 | 152,442 | 17,164 | 2 |
| Staff-bearer B | 27.6 | 159,282 | 17,164 | 2 |
| Veiled scan | 17.2 | 27,955 | 13,870 | 1 |
| Snapped pine A | 71.1 | 6,352 | 2,307 | 1 |
| Snapped pine B | 73.5 | 5,509 | 2,108 | 1 |
| Stump A | 8.6 | 1,264 | 661 | 1 |
| Stump B | 8.4 | 1,241 | 626 | 1 |
| Viaduct bay | 120.1 | 27,038 | 8,446 | 2 |
| Viaduct balustrade | 21.7 | 7,826 | 4,564 | 2 |
| Waterfall A | 81.5 | 3,328 | 3,272 | 1 |
| Waterfall B | 161.5 | 9,784 | 9,704 | 1 |

The largest combined GLB weighs 32,611,416 bytes. The 19 local upload parts under
`work/vesperhold-claude/win68/split` top out at 19,264,656 bytes. An independent pass over the actual part files
checked every SHA-256, confirmed each mesh node occurs once and compared embedded texture bytes against the
combined GLBs. See the [pass 4 mesh ledger](../../vesperhold/kit-renders-win/gate_a_pass4_meshes.json).

### Visual review

- The Wraith and monks lose the horizontal banding and show stepped, torn layers. The Wraith's hilt reads as dark iron.
  The robe hem remains straighter and less moss-covered than reference 07, especially at the base.
- The Mourner's face turns upward and the fingers meet the tomb edge. The bouquet is visible. Its roses and the
  face still read as stylized at close range compared with reference 06. The retone keeps the veiled scan's distinct silhouette.
- Pine A has a hanging split crown. Pine B has an exposed jagged break. Both stumps read above the five-stud reference
  figure in the assembly render. The three viaduct bays meet at shared piers and show deeper arches from below.
- The tall water ribbon showed a visible grid in the first assembly. Its coincident front and rear surfaces used
  opposing triangulation diagonals. A shared diagonal reduced the artifact. Removing the duplicate surface and
  exporting the water material as double-sided removed the visible grid and halved the waterfall triangles.
  The waterfall remains a static mesh review. Check Roblox's alpha and double-sided import during an approved pilot.

The first 2400 × 1100 Cycles lineup hit a Windows allocation failure on the fog render. A dedicated review rerun at
1320 × 605 and six threads rendered both lineups. The source meshes and maps kept their original resolution.
See the [statue comparison](../../vesperhold/kit-renders-win/F1_statues_v4_win.jpg) and
[assembly renders](../../vesperhold/kit-renders-win/gate_a_held_pass4.jpg).

## Approved set in local Studio

The first source build passed the local verifier and matched its Studio script digest. Play stopped at the first
registered thorn in `GothicMarch.verges`. The running server cannot write `MeshPart.CollisionFidelity`. The loader now
uses a cached collision template created with `AssetService:CreateMeshPartAsync`, applies the geometry to an imported
clone, and restores its texture content. The clone retains its SurfaceAppearance. A failed cook reuses the imported
collision and warns once for that source and fidelity. The regression fake now forbids runtime property writes and
checks the cook cache, texture retention, and the fallback.

The next Play reached server readiness. Client startup still stopped in `WeatherController` because
`VesperholdAtmosphere` existed in source without a Rojo mapping. The module is now packaged beside its caller. The
project mapping check covers that normal build entry point.

The first placement audit found three published `GlassR` submeshes still on their imported material and two
approved belfry stand-ins at the ends of 26- and 30-stud spire stacks. `GlassR` now uses the same Neon and
collision rules as `Glass`, with the crimson tint for rose windows and the portal. The layout now fits the tip
inside short stacks and skips a belfry when it has no positive height. The massing suite checks every module
height and every authored spire top.

The final source build passes `bash tools/verify_all.sh` in all 14 stages, including loader 47/0, atmosphere 26/0,
and massing 15,072/0. It has 314 mapped sources and 2,222 distinct referenced Roblox asset IDs.
The disposable source build is `work/vesperhold-claude/win68/AsurasPath_Vesperhold_Approved_Final.rbxlx`.
Its script fingerprint is **287 / 3437403 / 2079555092** and its SHA-256 is
`fbb1988bca3cf401ac706ff212181c358437aba3382adc9cb28d4ac4099a3031`.

The two seven-view passes each used a fresh local copy of that file with one capture-only script.
It briefly prioritized terrain around the viewpoints in the existing writer and restored the normal queue before
capture. Studio and offline fingerprints matched on both local copies. The observer stayed on the ridge at full
weather weight. The cameras used the regular in-game Snow profile around 15:50, with the avatar and HUD hidden.
The session files keep exact eye positions, draw calls and frame times. The final view requested the distant
foreground through the existing streaming API.

### Studio results

The first pass had 24 unique content IDs with HTTP 406 “Asset content representation is being generated.” Foreground
meshes in its first two shots appeared untextured. A fresh Play pass with 28 seconds of render warm-up showed textured
bark and stone. The repeat logged zero of those 406 warnings. Its remaining console entries were the previously
recorded asset type mismatch for `203785492` and one server heartbeat budget warning during startup.

- The server placed **639 loaded kit models** and counted **3,959 MeshParts** among the castle's 5,439 parts. The
  Windows manifests give **17,242,824 source triangles** across those placed kit submeshes. The repeat client had
  3,739 castle MeshParts streamed in at the observer position.
- Zero bad pivots. Worst positional deviation was **0.00071 studs**. The 242 cladding offsets agreed within
  **0.00010 studs** and all 16 flying buttresses used the intended yaw. The 3,894 split submesh centres agreed within
  **0.00028 studs**.
- All **86 collidable kit submeshes** used the expected fidelity (10 Hull and 76 Box). Three rays across the gate,
  from 3 studs above the floor at lateral offsets of −3, 0 and +3 studs, were clear for 48 studs. The stray red
  trail stake is absent in view 01.
- All **22 glass submeshes** had four SurfaceAppearance maps and Neon. The rose-window pair looks nearly identical
  with Neon enabled or disabled beneath SurfaceAppearance. The centre crop averaged **1.05 RGB levels** of absolute
  difference on a 0–255 scale. The warm glow in the brief is still weak.

| View | Rendered scene triangles | Draw calls | Mean frame (ms) | P95 (ms) |
|---|---:|---:|---:|---:|
| 01 Snow Refuge | 8,835,295 | 334 | | |
| 02 Pilgrim road | 8,896,911 | 281 | 65.47 | 67.17 |
| 03 Viaduct midspan | 1,905,441 | 106 | 45.87 | 49.19 |
| 04 Gate | 1,280,064 | 64 | | |
| 05 Gorge flank | 6,695,227 | 310 | | |
| 06 Inside the close | 181,844 | 36 | 56.23 | 68.68 |
| 07 Silhouette, 1,630 studs | 518,853 | 386 | | |

Frame times are 180 RenderStepped samples per measured view in one Studio client at 1736 × 824, saved quality
Level 10, with the world still writing terrain. The far view can include incomplete terrain outside the sampled
foreground. These timings cover a seeded review run. Multiplayer and device profiling remain open.

The views 01 and 02 are still screened by foreground branches. The gate and close are very dark, and most of the
spire detail is lost in the far silhouette. The approved-set scene continues to show authored stand-ins for held
pieces. The frame-time and visual evidence are open for creator review before the checkpoint is promoted.
See the [seven views](../../vesperhold/kit-renders-win/gate_b_studio_approved_set.jpg),
[rose window pair](../../vesperhold/kit-renders-win/gate_b_glass_comparison.jpg), and
[Studio measurements](../../vesperhold/kit-renders-win/gate_b_studio_metrics.json).

## Resume point

Creator review of the held meshes and the approved-set Play views comes next. The held files are ready in the local
split folder for an approved pilot. Check placement and collision when those parts enter the registry and confirm the
waterfall importer keeps alpha and both faces. Checkpoint promotion, forest re-captures and the grass decision follow
the active review. Guarded M2 integration, multiplayer and device profiling remain open. The last verified cloud
checkpoint is M1 v9. The existing local master and Mac handoff checkpoint hashes still match their earlier values.

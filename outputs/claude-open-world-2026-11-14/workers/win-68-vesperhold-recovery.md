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

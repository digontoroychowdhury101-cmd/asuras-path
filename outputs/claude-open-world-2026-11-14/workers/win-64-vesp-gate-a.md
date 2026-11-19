# Vesperhold Windows continuation and gate (a)

Codex (GPT-6) resumed from Claude's most recent “Asura's Path Mac handoff resume” chat and branch commit `067bcd9`.
Claude had baked the final gargoyle pair, interrupted the weighted-normal tree rebake, and completed only a partial
architecture pass. The creator's later statue references supersede pass 2.

## Statues

- Wraith uses the sword-bearer's pose with a hollow hood, overlapping ragged stone drapery, and an ivy-covered block.
  `Statue_Wraith` is the candidate replacement for the `Pedestal_Statue_Staff` layout slot. The quatrefoil alternate
  can still be built with `VESP_ONLY=Pedestal_Statue_Staff`.
- The Mourner is a new graveyard piece with a hand-carved upturned face, wavy hair under the veil, a carved rose brooch,
  a bouquet, and a hand at the edge of a tracery tomb. It has no layout slot or published ID yet.
- Both hooded monks use the same lighter stone and torn outer layers. A has narrower cuffs and B keeps the crescent staff.
  The existing Poly Haven veiled scan uses a lower rectangular plinth and the same stone grade.
- The torn drapery is modelled from pinned surfaces with irregular hems and closed holes. Cycles projects the high-poly
  surfaces onto the UV-unwrapped export meshes. The material uses the existing CC0 Poly Haven base layers with stronger
  cavity grime, rain streaks, lichen and moss.

Windows candidate files live under `assets/source/vesperhold/candidate-win-2026-11-19/{kit,props,trees}`.
The review renders show the assets on a Blender stage with a 5-stud scale figure. The citadel-in-world views are the later
Studio gate.

## Review and checks

| Statue | Height in studs | Triangles | Largest submesh |
|---|---:|---:|---:|
| Wraith | 23.8 | 141,712 | 15,736 |
| Mourner and tomb | 18.9 | 176,624 | 17,368 |
| Hooded monk | 22.9 | 108,272 | 17,164 |
| Staff-bearer, including crescent | 27.6 | 115,412 | 17,164 |
| Veiled scan | 17.2 | 27,955 | 13,870 |

The Mourner's face and hands are stylized up close. Some oak branch junctions also remain visible in close-ups.
The [full contact sheet](../../vesperhold/kit-renders-win/gate_a_contact_sheet.jpg) combines the five statues, gargoyles,
withered trees and architecture. The [mesh and map ledger](../../vesperhold/kit-renders-win/gate_a_tris.md) covers
all 69 exports. Direct GLB checks counted 335 submeshes, with every submesh under 18,000 triangles, and confirmed
2048 × 2048 Color, Normal, Roughness and Metal maps for every used material.

The built exports are in the candidate's `embedded/` folders, and the group manifests identify the current files.
The largest embedded GLBs are 34.20 MB (kit), 43.32 MB (props) and 20.62 MB (trees). The packed blue channel matches
the loose Metal map byte for byte. The earlier JPEG encoder introduced nonzero metalness on stone.
The guarded final statue bake started at 6.86 GiB free and ended at 6.57 GiB free. Blender 5.2.2 spent approximately
7:23 on Wraith, 10:56 on Mourner, 5:52 on A, 6:44 on B and 1:56 on the veiled scan, including their four views.

The full local verifier passed all 14 stages. See [the Windows handoff](../WINDOWS_HANDOFF.md) for the temporary build and
checkpoint details. Studio integration, the seven in-world views, multiplayer and device profiling are pending.

The handoff stops at the creator's pre-upload review. No Roblox operations were submitted. The Wraith slot binding and
Mourner placement belong to the subsequent integration pass after approval.

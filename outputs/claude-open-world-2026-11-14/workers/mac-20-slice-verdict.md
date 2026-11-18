# Slice review verdict — real-mesh forest slice (captures/win/slice_real_01..07)

Reviewer: overall-lead oversight session, 2026-11-18 Mac. Model: **Opus 5.5** (the creator switched this
session from Fable 5.2 with /model; the handoff's "Fable" oversight role is filled by Opus 5.5 here).
Inspected directly: 01, 03, 05, 07. 02, 04, 06 taken from the handoff and win-16 notes.
Build: 78662d6 runtime, 281 / 3254714 (third digest not recomputed in that session).

**Verdict: NOT ACCEPTED. M2 stays held.** The real meshes work (lantern, stone, ferns, flowers, broken
tower read well); the slice fails as a forest and on materials.

## Must fix before re-capture (in order)

1. **Far trees render as glossy lime stacked discs** (01 left, 05 centre-left, 07 left): textures missing.
   Diagnose one far-tree ID end to end before any re-upload (handoff "Real-mesh forest" section). Until fixed,
   no far tree may sit closer than the near-tree ring would cover.
2. **It reads as a park, not a wilderness.** Open grass between single trees; sky dominates every view.
   Required: clustered stands where crowns overlap, continuous canopy over parts of the road, darker
   understory light under stands, clearings as the exception. Keep the tower sightline from 01/07 and the
   road/combat/camera clearance (canopy undersides >= 14 studs over the road). Prove it with the same seven
   views plus the canopy number, and say what the number measures.
3. **Built pieces render near-black**: pavilion and cart (05), shed roof and the grey box (07 left), the
   red-black box by the cart (05). Find whether this is missing textures, inverted/absent normals, a
   material with no colour map, or placement inside terrain/shadow. Fix the asset or its import, not the
   lighting. Lobby lighting is untouchable.
4. **Foreground grass cards** dominate the eye-height view (01, 07): blades too large and too yellow-olive.
   Scale down near the road and arrival points and pull the colour toward the terrain grass.
5. **Foliage colour**: near crowns are saturated neon green with hard specular, trunks near black. Tone the
   leaf material toward the terrain palette (less saturation and specular), lift trunks to readable bark.

## Not blocking this verdict (record, do later)
- Far ridges are hard-faceted terrain; acceptable for now.
- The 24 unique far-tree IDs with "No asset content representation" console lines are the same defect as 1.
- Frame time 57 ms mean at Level21 on Windows is a single-machine diagnostic; re-measure on this Mac after fixes.

## Gate for the next review
Same seven camera positions (win-16 method), clear weather ~11:54, eye 5 studs, the third digest computed in
the capture session, console content-failure count, canopy number with method, MeshPart count and frame time.

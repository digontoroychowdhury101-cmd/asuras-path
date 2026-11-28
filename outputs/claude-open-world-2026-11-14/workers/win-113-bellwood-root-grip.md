# win-113: Bellwood root grip, a new method (Windows, 28 Nov 2026)

## Why
The handoff's Bellwood art order still listed the tree's root grip. Two procedural cling attempts had failed (v12/v13). Below z 160, the v20 pack's hand-guided roots lay on the terraces as thin, even, round tubes in parallel lanes. In game they read as hoses. The creator asked for a new method. The kept tree above z 160 and the pack itself are unchanged.

## Method
**Generator:** `tools/blender/landmarks/bellwood_root_grip.py`. Run it with `ROOT_MODE=clay|bake` and `ROOT_FLOWS`. Sources are in `assets/source/landmarks/bellwood_root_grip/`, which is gitignored.

1. **Rebuild.** The generator rebuilds the temple's stone and tree with the recipe, `stair_reference.py`, unchanged. It reads `SPINE` to find the eight roots crossing the z 160 cut. Each new root starts on that root's own rings, as a sleeve that grows from 0.9x to 1.12x. The sleeve swallows the open cut of the section kept above.
2. **Route.** Each root follows the v20 guide from the cut down to the platform lip, around the side shrines. Below the lip it follows new terrace stations: coping, a slanting or S-shaped run down the face, and a wide elbow onto the tread below.
3. **Drape.** Every sample is snapped to the nearest stone (a BVH of the recipe's masonry, crags, tiles and soffits), then smoothed and snapped again, seven passes in all. The normal is taken from the nearest stone point to the sample, so a root wraps a lip at its own thickness instead of flipping between faces. The report shows no air gaps.
4. **Form.** Each flow is one SDF.
   - Roots are flattened capsule chains: plank-flat on treads, pressed against faces, round at the seam.
   - A thin sole under each root fillets it onto the stone.
   - Each cut root fans into a main root and branches. They share the seam and the platform run, braid there, and part over the terraces.
   - Two or three spreaders splay at every foot, and sparser fingers leave the long runs. Every tip is buried in a joint.
5. **Bake.**
   - LOW is a surface net at 0.95 studs.
   - HIGH is the LOW subdivided, with flutes running along each root and fine bark noise.
   - Each flow bakes at 2048 on Poly Haven `bark_willow_02` (CC0, already credited in THIRD_PARTY), with a weathered moss grade.
   - Nothing is decimated.

## Art
- `Bellwood_RootGrip` has four flows: RootL1, RootL2, RootR1 and RootR2.
- 23 sub-meshes, each 15.0k to 16.5k tris, about 354k in total.
- GLB 11.4 MB. Embedded and split into three parts under 20 MB.
- Clay passes 1 to 5 are in `work/win-113/grip_clay*`. Each pass fixed one problem:
  1. Lumps at the lips.
  2. Routing through the shrine.
  3. Squat pillows.
  4. A plumbing look.
  5. Columns on the platform wall.

## Upload and placement
- **Upload:** ledger `uploads/win_root_grip_landmark_ledger.json`. All three parts Approved. The readback merged 1 piece and 23 subs, additions only. The registry now has 694 subs in 21 pieces.
- **Layout:** `LandmarkLayout` Basin.ColossalTemple.RootGrip lists the model, its Foot (bbox in model axes) and `Replaces`. Replaces holds the 21 pack subs under the cut: Roots02-07 and BarkTwigs03/05/07.
- **Build:** `LandmarkWorld` places the grip in the pack's frame before the pack pieces, with no collision, as the v20 roots had. Only if the grip places does it add `Replaces` to the pack's Omit. If the pack fails, the grip is destroyed with it.

## Verification
- **Tests:**
  - `test_bellwood_fit` 13 passed. New checks: the grip is laid out and registered, and it replaces exactly the bark under the cut.
  - `test_kit_registry` 23 passed.
  - `test_vesperhold_loader` 235 passed. New check: the grip joins the pack.
- **verify_all:** all checks pass. Digest 306/4106085/2009391872 matches Studio Edit.
- **Single-client Play:**
  - The grip placed with 23 MeshParts, and no Roots02-07 or BarkTwigs03/05/07 part was left in the pack.
  - On first load the new textures showed white for about a minute while Roblox processed them, then loaded.
  - Inspected from the hero view, both flanks, the plinth and the cut joint, with a brightened client grade. The roots drape, braid and splay on the stone and join the kept roots above.
- **Two-client Play:** not run. The roots are static, non-colliding scenery.
- **Save:** Development v100. Never published.

## Open
- A few foot spreaders on the right outer flank climb back up a face in a small "A" shape. This is minor and visible only close up.
- The joint at the cut shows a slight neck where the sleeve meets the kept tube.
- Two-client Sutra ally-heal check, carried over from win-111.

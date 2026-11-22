# Codex handoff: Bellwood roots, lions in scene, then the Roblox replacement (23 Nov 2026)

## 23 November Codex checkpoint

The v17 art recipe and pilot baker are on the raw asset branch at `ed2ebf7`. The editable Blender scene is `work/sol-bellwood-v17/bellwood_stair_reference.blend`. It uses the finished, baked guardian GLBs from `work/claude-bellwood-guardians`. Rebuild them with `guardians.py` if those files are missing.

- Eight authored roots now leave the trunk and descend both stair flanks, with toes beyond the lion plinths. The low paths follow measured retaining-wall and coping profiles. Upper guides use roof, masonry, soffit and lacquer contacts. A surface survey reduced unsupported upper intervals from 28 reported guide segments to 10. Some of the remaining segments still cross open bays. Keep the eight full paths and move those spans against walls or piers before export.
- The approved lion faces, mane and shield carving are intact. Both lions and their weathered plinths are in the temple scene with the final 2048 maps. The original light GLBs include color masks used by the bake and are unsuitable for final scene renders. Use the `_parts.glb` variants. Each guardian’s four mesh parts remain under 18,000 triangles. The six locally split files are under `work/sol-bellwood-guardian-pilot/split/`. They were not sent to Roblox.
- The crown now uses single tapered shoots and fewer terminal forks. Branch collars follow the limb and taper beneath its surface. The stair has new stone piers, lanterns, patchy moss and chipped tread lips. The full study still needs closer grain and support checks before a production pack.
- `export_pilot.py` baked the v16 study’s eave and stair surfaces at 2048. The stair has 2,902 triangles and the eave 2,428. After JPEG embed and split, the two meshes fit into one roughly 15.4 MB GLB under `work/sol-bellwood-v15/pilot/split/`. This is an offline material and file-size check. Full production topology, collision, bake, upload and registry work remain.
- The terrain-only fit survey found all eight road viewpoints still see the upper roof and crown at every measured site. A front rock ridge behind the giant face hid all 48 crown rays at a 420-stud world crest for the candidate at Across 30, Along −115. That candidate’s sampled foundation corners fit inside the inner rim, and its stair toe is about 148 studs from the gate origin. The ridge existed only in `work/sol-bellwood-v14/world_fit.luau`. It needs shape, clearances, an entry approach and inspection in Studio before use.
- All 14 local project verification stages passed. Layout passed 71 checks and loader 202. There was no new Studio Play, Development save or Publish. The older hall remains the game’s registered temple.

Review the [reference comparison](../captures/mac/bellwood_face/sol_bellwood_v17_reference_comparison.jpg), [root close-up](../captures/mac/bellwood_face/sol_bellwood_v17_root.jpg) [side view](../captures/mac/bellwood_face/sol_bellwood_v17_side.jpg), [fork close-up](../captures/mac/bellwood_face/sol_bellwood_v17_fork.jpg) and [approved lion in context](../captures/mac/bellwood_face/sol_bellwood_guardian_in_context.jpg). The roots reach the lower terraces, but the lower bark still reads too smooth in close-up.

The notes below describe Claude’s earlier v13 checkpoint and the original art brief. Use the v17 state above when resuming.


Claude stopped at mac-94 because the root delta failed twice (v12, v13). Everything below is ready for you to pick up. Read `CLAUDE.md` / `AGENTS.md` standing decisions first. The rules that matter most here:
- Never modify `places/` or `outputs/AsurasPath.rbxlx`.
- Use no Meshy, paid, NC, ND or Creator Store assets.
- Never decimate.
- Keep sub-meshes at 18–20k tris or fewer.
- Use 2048 maps.
- Run one heavy Blender job at a time under `work/vesperhold-claude/heavy.lock`.
- Stage explicit paths only.
- Save to Development, never Publish.

## Where things are
- **Recipe:**
  - The recipe is `assets/source/landmarks/bellwood_temple_colossal/stair_reference.py` (2,409 lines), plus `temple_preview.py` and `guardians.py`.
  - `assets/source/` is gitignored. Get the latest from branch `landmark-assets-2026-11-21`; commit 32e6d37 has `stair_reference.py` v13 and d4dce56 has `guardians.py`.
- **Target:** `assets/source/landmarks/bellwood_temple_colossal/creator-stair-reference.png`.
- **Latest renders:** `outputs/claude-open-world-2026-11-14/captures/mac/bellwood_face/`:
  - `mac94_v13_*` is the tree.
  - `mac94_arch_*` is the architecture, which is done.
  - `mac94_guardian*` is the lions, which are done.
- **Full render** (CPU, peak about 6.3 GB):
  `VESP_CPU=1 VESP_STUDY_OUT=$PWD/work/<new-dir> VESP_VIEWS=portrait,approach,side,rear,fork,root VESP_RENDER_PERCENT=100 VESP_RENDER_SAMPLES=24 VESP_TWIG_DEPTH=4 Blender -b --offline-mode --python-exit-code 1 --python assets/source/landmarks/bellwood_temple_colossal/stair_reference.py`
- **Architecture-only render:** set `VESP_SKIP_TREE=1`.

## 1. Root delta: the blocker, and it needs a new approach
**Problem:** In the reference, 6–10 thick roots leave the trunk base. They wrap over the upper tier roofs and eaves, then pour down the terrace walls on both sides of the main stair, framing the gate. Near the lion plinths they split into finer gripping roots. Ours stop around mid-tier (z ≈ 193 floor and z ≈ 124 terrace top), so the tree looks perched.

**Cause:** In `aged_tree()` (≈L1261), roots are routed procedurally, and `cling()` (≈L1473) cuts any span with no stone within about 3 studs. The rebuilt, offset masonry walls and the terrace drops therefore end almost every root. Loosening the gap tolerance brought the struts and arches back. Do not tune `cling` a third time.

**Do instead: hand-authored root guides.**
- Write an explicit list of about 8–10 root paths, each a list of waypoints traced from the reference, running trunk base → tier roofs → terrace wall faces → the stair flanks and lion plinths. Keep roughly mirrored counts left and right, but no mirrored shapes.
- For each waypoint, snap it onto the nearest surface using the existing BVH set at ≈L1416 (`Masonry`, `Tile`, `Lacquer`, `Soffit`). Use `find_nearest`, then offset outward by the root radius.
- Densify each path by resampling, then snap again so the root drapes over cornices and down wall faces. Where a path crosses a terrace edge, add an "over-the-lip" sample so the root bends over the edge instead of bridging the air.
- Sweep each path with the existing `root_rope()` / `organic_path()`. Taper the radius from about 6–8 studs at the trunk to about 1 at the tips. Branch 2–4 finer roots off the lower third of each main root.
- Keep `cling` out of this path. If needed, keep the old procedural roots only as the small upper-tier grip roots.

**Done when:**
- No root spans open air for more than about 2 studs.
- No arches or struts.
- At least two thick roots on each side reach the terrace beside the stair.
- `mac94_v14_sidebyside.jpg` reads like the reference from the stair view.

Also aim the `root` view at a low terrace root, not the upper tiers.

## 2. Lions into the scene (small)
The finished lions are built by `guardians.py` (scan mode, the default). Run it first; it writes `work/claude-bellwood-guardians/bellwood_guardian_{east,west}.glb`, and each GLB includes its own plinth.

In `stair_reference.py`:
- Replace the body of `place_lion` (≈L1147) so it imports that GLB at `at(*location) @ Matrix.Rotation(yaw, 4, "Z")`, applies that matrix to each imported mesh and deletes any non-mesh objects. `key = "east" if side > 0 else "west"`.
- Delete the `lion_plinth(temple, location, yaw, side)` call in `main()` (≈L2326).
- Check the plinth footprint against the stair's 29.5-stud cap. The old plinths overhung it, so widen the cap or reduce the yaw.

## 3. Smaller art fixes, after 1 and 2
- **Crown lace (`crown_fringe`, `twig_spray`):** it still reads as grey and dark tufts. Replace the spray clumps with single thin curved dark shoots, fewer and crisper against the sky.
- **Main stair:** it is plain against the reference. Add stone balustrade posts with lanterns on the flanking rails, moss on the treads' edges, and a few broken steps.
- **Fork:** a smooth patch with no grooves remains at the front of the trunk fork (see `mac94_v13_fork.jpg`).

## 4. Then the Roblox replacement
Follow steps 1–6 of "Replace the actual temple" in `CLAUDE_BELLWOOD_REPLACEMENT_HANDOFF.md`: production meshes, bake, upload, registry, placement, Play walk, then save to Development. The lions are already split for upload in `work/claude-bellwood-guardians/bellwood_guardian_{east,west}_parts.glb`. Each has four parts of 18k tris or fewer, with 2048 maps in `textures/`. Regenerate them with `guardians.py` if `work/` is missing on your machine.

When the lions ship, turn the "(pending ship)" lion bullets in `assets/CREDITS.md` into table rows and add matching `Source = "..."` entries in `src/shared/EndingCredits.luau`. verify_all stage 10 checks that they match. Run `ASURA_BUILD_OUTPUT=work/verify.rbxlx bash tools/verify_all.sh` before committing.

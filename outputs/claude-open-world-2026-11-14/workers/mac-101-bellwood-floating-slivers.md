# mac-101: the Hollow's floating rock (and 82 more), fixed at the carve (2026-11-25, Mac)

This fixes item 3 of mac-99: the "floating rock" at the upper left of the tunnel-exit reveal.

## What it was
- **The visible rock:** a screen ray from the reveal eye hit Terrain Mud 58 studs out, at (-3670, 184, -2327). It is a 2-voxel island (4 x 8 x 4 studs) with air on every side for 12 studs, at the old overworld surface height (`heightAt` 187.5), well inside the bowl (ellipse 0.83).
- **How many:** an exact voxel scan of the bowl found **83** such cells, each with partial occupancy (0.05 to 0.46).
- **Where they sit:** every cell lies within 2 studs of a seam between `World.basin`'s 6-stud air strips. The cells are not on the 128-stud terrain tile grid, and terrain was complete at 67 s against a 201 s basin build, so this is not a late tile write.
- **Root cause:** the strips are turned about 4 degrees off the voxel grid (basin yaw 94). A voxel that straddles a seam is only partly covered by each neighbouring strip, and an Air `FillBlock` keeps the part it does not cover.

## Fix (`LandmarkWorld.strips`)
- Neighbouring strips now overlap by `World.StripSeam = 3` studs on each side. That 6-stud overlap holds any 4-stud voxel (at most 5.66 studs across at 45 degrees) wholly inside one strip, at any yaw.
- Each strip's width is taken at its extended edge, so the corners still stay inside the shore (the existing "air strips inside the shore" check still passes).
- The same helper writes the bed, water and dish strips. For them the overlap is harmless.

## Tests
- New check in `test_vesperhold_loader`: "basin air strips overlap a voxel's span at every seam". It failed first (overlap 0.00 against the 4.27 needed, over 348 seams) and passes after the fix.
- Results:
  - loader: 225 passed
  - landmark_layout: 80 passed
  - bellwood_fit: 6 passed
  - slice_dressing: 1380 passed
  - weather: 482 passed
  - verify_all: passed

## Studio (Play, single client)
- Digest 295 / 3928949 / 1036487552 in both the build and Studio.
- After the basin build, the same voxel scan finds **0** floating cells (was 83), and the reveal blob's voxels read occupancy 0.
- `captures/mac/bellwood_reveal/mac101_exit_reveal_no_floating_rock.jpg`: the same framing as mac-100, with the upper-left rock gone.
- Saved to Development 118614906972571 with File > Save to Roblox. Studio's log reads "Saved new changes in 'Asura's Path — Development' to Roblox". Never published.
- Capture note: `screen_capture` camera parameters were overridden by the game camera in this session. A client `BindToRenderStep("QAView")` holding a Scriptable camera works.

## Still open from mac-99
- The empty foreground lake (lotus, broken columns, wreck).
- The temple on the centre line, a composition choice.

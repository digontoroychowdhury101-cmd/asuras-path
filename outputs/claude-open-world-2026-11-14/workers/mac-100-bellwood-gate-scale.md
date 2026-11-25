# mac-100: Bellwood gate towers at 3x (2026-11-25, Mac)

This fixes item 1 of mac-99: the gate towers were a 51-stud speck at the foot of the 795-stud colossal temple.

## Change
- `LandmarkLayout` `Basin.Gate`:
  - The new `Scale = 3`. Radius, Steps, Back, Width, Landing, Height and Foot are the 1x kit numbers times 3.
  - The towers moved from Across 150 / Along 140 to Across 250 / Along 120, further left of the exit. At the old spot the 126-stud footprint left no seat for the temple base in `test_bellwood_fit`; the new spot passes it and stays inside the bowl (ellipse 0.17).
- `LandmarkWorld`:
  - `Kit.place` passes `Vector3.one * Scale`.
  - The gate accent lights ride the scaled towers. Their offsets are multiplied by Scale; ranges are unchanged.
  - The Mud footing under the towers is `44 * Scale` wide.
- The route's causeway already follows `Landing` and `Back`, so it starts on the raised landing unchanged.

## Tests
These were added first and failed as expected:
- Towers at least 140 studs tall at Scale at least 2.5.
- The scaled stair riser is 1.5 studs or less.
- The gate numbers equal the 1x kit's times Scale.
- The loader places the kit at Scale.
- A tower-foot probe at x = 13 × Scale sits on the footing.

The route-start distance bound now scales with the gate. Results:
- landmark_layout: 80 passed
- loader: 224 passed
- bellwood_fit: 6 passed
- slice_dressing: 1380 passed
- weather: 482 passed
- verify_all: passed

## Studio (Play, single client)
- Digest 295 / 3928510 / 251686768 in both the build and Studio.
- `Bellwood_GateTowers` bounding box: 163 x 152 x 163 studs (was 54 x 51 x 54). All 5 gate accents are placed.
- Walk with MoveTo:
  - stair foot to landing (Y 154 to 194) in 7.5 s, state Running, no stall;
  - landing to causeway start in 1.0 s;
  - along the causeway in 1.6 s.
- `captures/mac/bellwood_reveal/mac100_exit_reveal_gate3x_fov70.jpg`: the towers now stand as a tall mass in the left third, beside the temple.
- Not Play-checked: the wider Mud footing (terrain under the lake). It is covered by the loader test.
- Saved to Development 118614906972571 with Save to Roblox As > Overwrite (never Publish).

## Still open from mac-99
- The empty foreground lake.
- The floating rock: still visible at the upper left of the reveal.
- The temple on the centre line, a composition choice.

# Bellwood basin expansion plan (design note, 22 Nov 2026; no live layout change)

Inputs: `survey.luau` (room for 1400 x 1120 near X/Z -4178/-2298, Back = 750), `sightlines.luau` (0/40 on the old 320 hall), the reference stair (134 wide at the foot, rises ~86, tree to ~500), and the live 350 x 300 basin (Bed -36, Water 2.5, Thick 28, RimRise 24, bore to kit y -132).

## 1. Footprint (basin axes: Along = toward the face, Across = right)
| | now | proposed |
|---|---|---|
| Width x Depth | 350 x 300 | **1400 x 1120** (semi-axes 700 / 560) |
| Back | 260 | **750** (centre 750 behind Origin; survey's best fit) |
| Bed / Water / Deep / Shelf | -36 / 2.5 / 8 / 36 | keep -36 / 2.5 / 8; Shelf 60 |
| Thick, RimRise | 28, 24 | Thick 40; RimRise 60 (rim crest = floor + 60..75 with the existing +-7 wobble) |
| RimSegments | 128 | **320** (about 27 studs per chord at the new perimeter) |

The front shore is then 190 studs behind Origin; the bore's terrain passage must extend from kit y -132 to about **-215**, level at floor -27 kit Z, so the exit opens at the shore with the reveal below.

## 2. Reveal composition (exit at the front shore, along = -560)
- **Exit terrace** at floor + 16.5 (current 14 over water), 30 deep, centred on the bore axis.
- **Stair foot** (134 wide) at along **-20**, across **+110** (right of the exit axis, as the hall is today): 540 studs from the exit. The stair climbs away from the exit to the threshold at along +180 (about 740 from the exit), top at floor + 86 + Lift.
- **Tree** root mass at along +230, across +110; crown to floor + 500. The back rim is at +560, so the tree stands 330 inside the rim and reads above it.
- Gate towers (Vesperhold-scale, Radius ~90) move to across -150, along -140, front to the basin centre, so the left third of the exit view holds the gate and the right third the stair.
- Targets from a 3 m eye (20 studs over the terrace): stair top 4-6 deg, threshold 5-7 deg, tree crown 28-34 deg. The lake between is ~540 studs; give it two islands/ruins and a causeway ledge so it is not empty water.

## 3. Route: gate terrace -> rim -> forest (all gradients <= 35 deg, target <= 28)
1. **Gate stair to terrace** as built (ends floor + 16.5).
2. **Ledge walk** (12 wide, cut 1.5 above the water shelf) along the left shore, 90 studs.
3. **Switchback up the rim**, 3 legs of ~50 studs horizontal, 20 rise each (22 deg), 14 wide, landings 16 x 16 every 20 rise, rail/lantern per landing. Total rise 60 to the crest.
4. **Crest notch** through Thick 40: 14 wide cut (air box like `World.carves`), leaving the outer grass wedge as the exit ramp (run = 1.8 x drop, ~29 deg).
5. **Forest path**: the ramp lands on the outer wedge; a 14-wide dirt road to the nearest existing road/node (survey corridor list), kept clear in `SliceDressing` as a lane.

## 4. Must-fix code before carving
- `SliceDressing.circles` excludes the basin with **one circle of radius = long semi-axis + Thick + 6** (734 studs at 1400 wide). It would erase forest well outside the rim; replace with an ellipse test (`LandmarkLayout.basinEllipse` with pad = Thick + wedge run) plus `carvedSurface` for placements on the wedge (added 22 Nov).
- `World.strips` / `World.basin`: air strips go from ~50 to ~190 across; fills grow ~5x. Chunk fills across frames and profile collision cook first (5.5 min startup today).
- `lowerFloorAt` already follows the ellipse; extend it to the switchback and notch cavities.
- Rim strata fields (`stratumWidth`, `stratumWander`) are angle-smooth; recheck with 320 segments (jump <= 1.5 studs).

## 5. Gates that must pass before any carve
1. `tools/test_landmark_layout.luau` with the new numbers: clearances (altars, nodes, POIs, caches, lore, rings, minibosses, encounters, Vesperhold), roads and rivers.
2. `survey.luau` rerun: nearest-clearance margin >= 110 at the chosen centre, all four corners.
3. `sightlines.luau` with final bounds: 0 road eyes see temple or tree top over the rim (hidden-basin rule), and **new**: exit eye sees stair top, threshold and tree crown within the angle bands above, with no gate/pavilion occluder.
4. New route probe: sample the switchback every 4 studs against the carved surface; max gradient <= 35 deg, widths >= 12, no gap > 1 stud between landing and tread; walkable graph connects terrace to a Road point.
5. `test_vesperhold_loader.luau`: strata (no dark band > 4, no streak), `carvedSurface` vs wedge, `lowerFloorAt` over route cavities.
6. `test_slice_dressing.luau`: nothing placed inside the ellipse; wedge placements within 4 studs of `carvedSurface`.
7. Mesh world-fit: stair/tree bounds inside the ellipse minus Shelf, tree crown above no other landmark, each upload submesh < 20k tris.
8. Studio Play (main agent): startup-to-collision time, fall guard zero rescues walking terrace -> rim -> forest, gate/exit/aerial captures at the documented camera.

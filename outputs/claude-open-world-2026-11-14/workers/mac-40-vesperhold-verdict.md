# Vesperhold citadel — oversight verdict and art brief (2026-11-19)

Reviewer: overall-lead oversight (Opus 5.5). Supersedes: nothing (first castle review). Linked from CONTINUATION.md.
Creator's words: "still lacking the gothic haunted looming, colossal size we need. we need exceptional detail with
withered trees, etc."; "if there [are] open-source repos that help make it a lot better please feel free to use those";
plus a reference image (described below; it was given in chat, not saved as a file).

Reviewed: Codex pass committed e8be23c (src/server/Services/GothicCitadel.luau 1054 lines, GothicMarch.luau 569, terrain
ridge in Overworld.sampleAt, Vesperhold weather weight). Place outputs/vesperhold/AsurasPath-Vesperhold.rbxlx (local,
untracked, 56 MB). Captures: outputs/vesperhold/01-snow-refuge.jpg, 02-pilgrim-road.jpg, work/vesperhold/film-qa/frame_12.00.png,
captures/mac/vesperhold_review_approach.jpg, _flank.jpg.
Measured in Edit: Vesperhold 7452 parts / 6 MeshParts, bbox 343 x 702 x 435 studs, Y 638..1340; Limestone 4415, Slate 1612,
Metal 620, SmoothPlastic 447. Vesper March 1137 parts / 270 MeshParts. Lighting there: clock 15.7, blue sky, FogEnd 1600.

**Verdict: NOT ACCEPTED as the colossal haunted citadel.** Keep: the site (gate at -2800, 650, -6400, yaw -90), the ridge
carving, processional bridge, pilgrim road and named March areas, the spire height, the region weather weight, sounds.

## The creator's reference image (the target look)
Low camera looking UP at a black gothic cathedral-fortress that climbs a sheer cliff in 3-4 stacked TIERS. Each tier is
a long arcaded gallery / flying-buttress run with pointed arches, topped by balustrades and rows of pinnacles; dozens of
needle spires of varied height rise behind, the tallest pair framing a huge west front with a tall glowing rose window and
stained-glass lancets lit warm from inside. In front, a high many-arched stone viaduct with a balustrade lined by hooded
monk statues leads to the gate; small candle/brazier flames dot every parapet and ledge; torn dark-crimson banners hang
from a near tower. Sky: churning charcoal storm cloud with a blood-red eclipse/black sun and red glow. Thick fog banks
roll between the tiers and swallow the cliff base. Palette: black and charcoal stone, grey fog, crimson accents, warm
orange points of light. Density of vertical detail (crockets, finials, tracery) is extreme; nothing reads as a box.

### More references (2026-11-19, saved as outputs/vesperhold/reference/ref_02..05.webp; ref_01 was chat-only)
- **ref_02 aerial:** the citadel is a SPRAWL across several cliff pinnacles linked by arched viaducts at different heights;
  small spired outposts sit on far crags; long stairs climb between tiers; bridge piers carry hooded staff-bearing statues;
  banners and candles along every run.
- **ref_03 grand stair:** a wide stair climbs straight to the glowing portal, lined by brazier posts and pedestal statues,
  with banners on poles either side. This is the arrival moment: the player should climb it.
- **ref_04 approach:** the viewpoint is a ruined arch with withered trees and tattered banners on a cliff edge; across a
  deep gorge with waterfalls the citadel stacks up on terraced cliffs, with viaducts at three levels and graves on the
  lower terraces. This is the 01/02 reveal to match.
- **ref_05 storm:** lightning in the clouds; massive arched viaduct towers hung with long banners; stairs and statues.
- Banner emblem: make OUR OWN sigil (e.g. the Asura order's mark). The references show a white-tree emblem that reads as
  a well-known film franchise's crest — do not copy it.

Added targets: (a) >= 3 viaducts at different levels linking >= 3 pinnacles, plus >= 2 distant spired outposts on crags
for the skyline; (b) a grand stair (>= 60 steps, braziers + statues every ~20 studs) from the last viaduct to the portal;
(c) waterfalls/spray down the gorge walls under the citadel; (d) a ruined-arch viewpoint with dead trees and banners at the
reveal (view 01/02); (e) lightning flashes that briefly light the silhouette.

## What is wrong now
1. **Only the spires are big.** The gatehouse and curtain wall are ~40-60 studs: a toy castle in front of two towers.
   From Snow Refuge the mass fills a sliver of the frame; nothing hangs over the player on the approach.
2. **Two palettes, fairy-tale shapes.** White limestone towers with cone caps and neat crenels, then black spires behind.
   Reads Disney, not haunted. Twin spires are mirror-symmetric; there are ~10 spires, the reference has dozens.
3. **Primitive surfaces.** Parts with stock materials; no tracery depth, buttresses, gargoyles, statues, grime, frost,
   breakage. The rose window is a flat disc of coloured circles.
4. **No withered trees, graves, gibbets, fences, crows, statues, candles, banners** — nothing tells the story.
5. **Bright afternoon.** Blue sky, white clouds, light grade. Snow particles render as huge screen blobs (01, 02).
6. Stray red wooden post in the foreground of 01. A camera at the gate (-2680, 660, -6400) sits inside solid stone: check
   that the gate passage is open and walkable.

## Targets (measurable, judged in the same views)
1. **Scale and tiers.** Build the citadel as 3-4 terraces stepping up the ridge, each fronted by an arcaded gallery /
   buttress run (arches 40-80 studs tall). Lowest bastions drop >= 150 studs into the gorge; the cathedral ridge reaches
   >= 220 studs above the gate road; main spires keep ~700. Doors 20-30 studs for contrast. From the Snow Refuge eye the
   body (excluding spires) spans >= 45% of frame width and >= 35% of height at FOV 70; for the last 400 studs of the
   road the player looks UP (>= 25 degrees to the first parapet).
2. **Silhouette.** >= 30 spires/pinnacle towers of varied height, asymmetric grouping; >= 8 pairs of flying buttresses
   with crocketed pinnacles; a dominant west front with a 40+ stud rose window over a deep portal. One spire may be
   broken for story, but the reference's density comes first. No cone-capped white turrets.
3. **One palette.** Soot-black and wet charcoal stone (albedo value ~0.08-0.25), frost only on ledges, grime streaks,
   iron and verdigris; crimson only in banners, glass and the sky; warm light only from glass, candles, braziers.
4. **Detail through meshes.** Blender-built gothic kit with PBR maps (2048+): lancet windows and rose windows with real
   stone tracery and stained glass (emissive warm), arcade bays, buttresses and flying buttresses, crocketed pinnacles
   and finials, spire segments, balustrades, gargoyles, hooded statues, portal with archivolts, portcullis and iron
   gates, ruined chunks and rubble, chains, gibbet cages, iron fences, gravestones, banners. Split meshes under
   ~18-20k tris per MeshPart; never decimate; reuse modules by instancing. Luau keeps the layout, collision and walk
   paths; meshes replace Part shells wherever seen. Link a black Metal map on every non-metal material (mac-28 lesson).
5. **The viaduct.** The processional bridge becomes a tall many-arched viaduct with a balustrade, hooded statues every
   ~25-35 studs and candle clusters; the near gate tower carries torn crimson banners.
6. **Withered trees.** >= 3 dead species (gnarled broad oak, snapped pine, twisted thorn) + stumps and fallen logs,
   sizes up to 60-90 studs, frosted bark PBR; clustered and leaning along the pilgrim road, the gorge rim and a graveyard
   below the walls; a few carry hanging cages or rope. They frame the castle in views 01/02, never block it.
7. **Atmosphere, local to the Vesperhold weight only** (EnvironmentProfiles input `Vesperhold`, WeatherController
   `Overworld.vesperholdWeight`): dark storm overcast, dense haze, fog banks between tiers and in the gorge, cold
   desaturated grade with a faint red cast near the sun, a blood-red eclipse disc behind the spires, rare lightning,
   crows circling the towers, warm glass and candle glow, small snowflakes. Blend on entry; lobby and other regions
   untouched.
8. **Gameplay safety.** Walkable gate and approach, the single Shen barrier, persistent IDs, lobby, combat and
   progression untouched. Record frame time at three views, MeshPart and triangle counts, console content failures.

## Review gate (same capture method each time)
Views: 01 Snow Refuge (Codex's eye), 02 pilgrim road, 03 viaduct mid-span looking up (match the reference framing),
04 at the gate looking up, 05 flank from the gorge floor, 06 inside the close, 07 silhouette from >= 1500 studs.
Fixed clock and weather, eye 5 studs, avatar hidden. Plus the numbers in target 8.

## Open-source use (creator-approved 2026-11-19)
Allowed and encouraged where it raises quality: CC0 textures/models (Poly Haven, ambientCG), GPL/MIT generators run as
tools (e.g. Blender's Sapling Tree Gen extension, friggog/tree-gen) whose output we own. Pin the exact version/commit,
record source URL + licence per item in outputs/vesperhold/THIRD_PARTY.md. Download into its own folder under
work/third_party/ and treat it as untrusted (no running bundled scripts). Not allowed: non-commercial or no-derivatives
licences, ripped game assets, Creator Store free models (script risk, unknown rights).

## Uploads
Only route that works on this Mac: the CLOUD place window (workers/mac-25-upload-route.md); local windows are refused the
asset scope. Uploading our own generated meshes/textures there is approved; the cloud DataModel must not be edited or
saved during it. Batch the castle kit with the forest re-tone re-upload (mac-30) in one cloud-window session; record every
operation ID; register only returned IDs via tools/assets/kit_registry.py.

# Root material investigation — 31 October 2026

The world goal remains active and unfinished. The root-material checkpoint used **261 scripts /
1,943,649 bytes / digest 458197530**. Later General Zhao source commits were script-synced and matched
**261 / 1,951,058 / 193360600** before the entry-rock change below. The root candidate remains
**uninstalled**. No region or new performance gate is claimed complete.

## What the inspection found

The previous actual Sanctuary views show a blurred lower root mass, angular canopy leaves and a
crowded east reveal. Studio's permission-checked EditableMesh API successfully recovered 16 original
lower-trunk sections, plus a separate root and leaf sample, with exact vertices, corner normals, UVs,
template transforms and PBR references. Existing uploads, source masters and the game library remain intact.

The original lower sections have approximately **0.75 pixels per production stud at 1024**, or 1.5 at
2048, measured by surface-area-weighted median. The template figure is 100.000002 studs and production
is 150, confirming the 1.5 scale used by this calculation. The separate tendril root has about 29.4
pixels/stud at 1024. Adding polygons would not fix this density difference.

The readback maps are 1024×1024 because EditableImage is capped at that size. **This does not establish
the native renderer's texture resolution.** Macro colour and existing normal detail were retained as
read back, then rebaked with new detail. Original higher-resolution sources were not overwritten.

## Candidate and rejected attempts

- The first 16-section smart-projection atlas looked worse: approximately 0.33 pixels/stud at 2048,
  blurred detail and dark seams. Rejected; never uploaded or installed. A connected UV carrier improves
  chart continuity, but the second full-base atlas still failed its density gate before baking.
- The four-section pilot (`Titan_Canopy_13`–`16`) retains the original UV charts and packs them on a
  temporary connected carrier. Original exported vertices, faces and custom normals are untouched.
  The final atlas has about **3.8 pixels/stud at 2048** (2.5× the original at the same map size).
- Version 3's grain was too faint. `root-detail-offline-v4/` shows the revised offline comparison:
  visible bark grain and the original broad shading, with no first-attempt dark triangles. Broad soft
  colour patches remain. These are material crops of one section, whose cut edges are exposed because
  neighbouring sections are hidden; **they are not game views or silhouette-completion evidence**.
- The actual GLB, then its tangent-enabled copy, were imported into a separate factory Blender process:
  **62,405 evaluated triangles / four meshes / max 15,602 per mesh**, one UV set and material each,
  maximum vertex-position delta **0.0**. Bake-time custom-normal delta is **0.0**. See the round-trip JSONs.
  The pilot still requires Studio import, scale/normal/seam checks and an actual gameplay comparison.

Local sources (normal repository convention keeps `assets/build/` ignored):

- `assets/build/fused_tree_base_recovered_2026-10-31/`: 16 sections, 249,622 triangles, checksummed
  geometry and the capped map readbacks.
- `assets/build/fused_tree_recovered_2026-10-31-b/`: root, lower trunk and leaf samples, 32,491 triangles.
- `assets/build/fused_root_detail_pilot_v4/`: separate `.blend`, 2048 colour/normal masters, 1024
  roughness, GLB and **`FusedRootDetail_Tangents.glb`** (preferred import candidate).
- `root-candidate.json` and `root-material-audit.json` copy the manifests, checksums and conditions.

Reproduction uses `recover_fused_tree.py`, `recovered_monument.py`, `fused_root_detail.py`,
`review_fused_root_detail.py` and `validate_fused_root_detail.py`. Run Blender helpers in a separate
factory-startup background process. The detail uses the existing licensed Poly Haven
[bark_platanus](https://polyhaven.com/a/bark_platanus) CC0 source, already credited in `assets/CREDITS.md`.

## Running-client recordings — 31 October / 1 November

The user approved command-line viewport recording and activation of the confirmed local Studio.
`studio_record.swift` uses Apple's window-specific ScreenCaptureKit filter, audio/microphone/cursor off,
with bounded clips; `studio_activate.swift` targets the canonical window's verified Roblox PID only.
These replace the native Screenshot/QuickTime automation that repeatedly hung. No game publication,
spending or new art upload occurred.

- `wind-wide-video-v2/clip.mp4` (19.97 s) and `wind-ground-video/clip.mp4` (20.12 s) are real running-client
  motion recordings, decoded and resized for viewing without retiming or synthetic frames. Their
  source masters remain local under ignored `video-take3/`; `media.json` records both SHA-256 hashes.
  Frames, capture metadata and phase-specific session snapshots accompany the viewing copies.
- Both use a seeded observer camera and a mock avatar parked outside combat. Production lighting,
  HUD, wind and geometry were retained. Studio was in the background during these clips: these are
  **motion diagnostics, not foreground performance or final gameplay-quality acceptance**. The
  source was digest 458197530. Native terrain grass is not established by these lower-quality clips.
- The wide view sampled the same **visible** plant of each kind 32 times over about 16 seconds.
  Tip spans: grass 0.0793, bamboo 0.2137, shoots 0.0718, fern 0.0903 studs. Bamboo base error peaked
  at 0.000736 studs; other plant base errors were **unmeasured** (`null`), not zero. This proves actual
  custom-plant transforms rather than inferring motion from GlobalWind. Review subtle motion at full size.
- `entry-traversal-video/clip.mp4` records normal W / Q dash / Space jump controls and the production
  camera after a seeded entry start. Normal portal touch established Monastery arrival, and documented
  `VirtualInput.SendMouseDelta` turned the existing camera into Bamboo. Start: (0,3.2,-1126), 100 HP;
  end: (2.53,3,-1404.03), 100 HP, Baize encounter. This is a **seeded route segment, not an earned
  campaign run or sustained fight**. Its source digest is 193360600.
- The entry clip used coordinates calibrated with the still-image API: part of the command bar
  appears at the bottom and top CoreGui is clipped. A later decoded-video calibration established
  a 33-point vertical difference between still and stream capture in this window setup. Retained as diagnostic footage; **not final viewport-only
  acceptance**. Earlier wrong-heading and narrower-crop attempts remain local and excluded.
- Play used Automatic quality with FRM enabled, measured around levels 19–20; it was **not fixed
  Level21**. EditQualityLevel was temporarily 21 for inspection, then restored to the original
  Automatic. `graphics-before.json` / `graphics-restored.json` record this. The owned test returned
  to Edit, removed its probe, restored camera/keys, and reported no cleanup errors.

The saved General Zhao Blender master was preserved. The earlier inactive-Scene library write crash
was reproduced headlessly and fixed by collection-only writing; root helpers require a separate
factory-startup background process. Subsequent unrelated animation work remains outside this batch.

## Entry limestone — 1 November

The matching `entry-crags/before_*` views showed eight flat-grey faceted scatter rocks close to the
path. Production now reuses the existing MIT Terrain3D Crag A/B/C meshes and their ambientCG Rock023
PBR maps. Horizontal placement, a muted green-grey tint and measured world bounds replace the
oversized scatter silhouettes. The first upright/incorrect-bound attempt is retained in
`entry-crags/rejected-v1/`; it was corrected before acceptance of this small treatment.

`entry-crags/after_*` uses the same cameras, 1271×685, normal HUD and ordinary Automatic settings.
The after shots report FRM 2 (Studio had lost foreground); these show placement/materials, **not a
fixed-quality or performance comparison**. Later foreground capture remains necessary. Both captures
report 100 HP, no controls overlay and no cleanup errors. No actors or scene elements were hidden.

The Play server audit found all eight decorative rocks noncolliding, nonqueryable and nontouching,
with rotated bounds embedded 0.2000 studs into the Terrain under their centres; no floating bounds.
Spans are 3.68–5.54 studs, heights 1.68–2.90. The map retains **73 colliders**. The same random draws
are retained, so subsequent plant positions do not change. Uploaded-mesh readback counts:
Crag A/B/C 248/290/246 triangles; eight rocks total **2,106 triangles**, versus 784 before (+1,322),
with the same eight MeshParts and an already-loaded shared texture set. `runtime-audit.json` and
`mesh-counts.json` record the actual measurements. Original mesh masters and uploads are unchanged.

The three largest visible remaining Bamboo problems in these and the wind views:

1. Mid-distance grove floors still have broad bare, flat patches. Add irregular leaf-litter/moss
   colonies around existing clumps and use low groundcover masses outside the route and combat lane.
2. The crest reads as one hard horizontal wall behind a straight stair. Break its visible edge with
   grounded stone/root transitions while preserving its traversable surfaces and approach sightline.
3. Canopy/sky balance remains thin in reverse and side views. Add selective overlapping crowns in
   background gaps, retaining shrine/karst landmarks and the established camera-clearance volume.

`python3 tools/build.py` rebuilt both canonical places. All 14 local verifier stages passed
(`verification.log`), including 333 campaign-region and 27 campaign-build checks. After a comment-only clarification and rebuild, the saved place and connected Edit scripts match
**261 scripts / 1,952,592 bytes / digest 42186667**. The verifier exercised the same functional code. New Swift helpers were compiled and exercised; Python helpers compile.
These checks do not certify foreground timing, physical mobile or completion of the whole pass.

## Corrected full-viewport videos — 1 November

- `entry-traversal-full/clip.mp4`: **14.68 seconds**, normal production camera and W / Q / Space
  controls, from seeded entry (0,3.2,-1126), 100 HP to (1.93,3,-1395.11), 100 HP, Baize encounter.
  Reviewed decoded frames at 0, 8 and 14.58 seconds: full CoreGui/HUD, no Studio panels, no foliage
  covering the route or camera along this segment. This covers entry, crest and arena approach;
  **not the full pass, optional ridge/glide route, lock-on clearance or a sustained fight**.
- `wind-ground-full/clip.mp4`: **20.04 seconds**, player-height observer at (-8,5.5,-1184), looking
  at (-25,1.3,-1200), FOV 70. Reviewed full-size decoded frames at 0, 8 and 19 seconds: full HUD,
  no Studio panels; native blades in the foreground and custom plants in the grove. Studio was
  foreground at both recording endpoints; Automatic quality, measured FRM **14** throughout the
  32 plant samples. No quality, lighting, wind, combat, health or geometry override was applied.
- Same visible custom plants over 32 samples: grass tip span **0.0802**, fern **0.0508**, bamboo
  **0.2193**, shoot **0.0731** studs; bamboo base error ≤**0.000482** studs. Other base errors remain
  unmeasured. `motion-summary.json` and `session.json` retain transforms, on-screen coordinates,
  wall-clock times and a stable 1271×685 viewport. Motion is subtle, rather than whole-plant swaying.
- Both are actual video, resized to 1920×1036 without retiming, synthetic frames or audio. Source
  masters remain local under ignored `video-take6/` and `video-take8/`; hashes and durations accompany
  each copy. **Encoded frame rate is not game performance**. Endpoint foreground checks do not
  replace a continuous focus-qualified 60-second performance run.
- A bounded two-second **video** calibration fixed framing. For this exact window [0,33,1470,923],
  stream rect [2,162,1271,685] works; the still-image API used Y=195. Recalibrate actual video after
  layout/window changes. `wind-ground-foreground/` is the earlier rejected still-calibrated crop,
  explicitly labeled. The setup-only take7 returned to Edit before recording and produced no movie.
- Both owned tests reported `ownedTestStopped=true`; Studio is confirmed Edit, original Automatic
  graphics retained, and their temporary probes/camera/keys removed. Source digest remains 42186667.
  The concurrent General Zhao animation-library commit is preserved; these source and art checks
  do not certify its authored animation playback.

New footage makes the three **white FrostStone climb blocks** conspicuous beside the crest.
They are established optional-route colliders at (39,13.5,-1268), (46,15,-1270), (53,16.5,-1268).
Next, prepare convincing frost-worn step-stone visuals while preserving those exact surfaces and
jump gaps; then address the broader floor/crest/canopy defects listed above. Nothing in these
clips establishes whole-region visual completion or either device performance gate.

## Next concrete actions

1. Dress the three white FrostStone climb blocks, preserving the optional ridge route, then improve floor/crest/canopy composition.
2. Extend the verified video framing to the full route, optional ridge/glide and lock-on tests; complete
   the representative 60-second traversal/combat measurement with continuous observed focus.
3. Import one root-pilot section, verify actual scale/UVs/tangent normal/permissions, and compare the
   same Sanctuary cameras before deciding whether to install its material treatment.

All earlier incomplete gates remain open: desktop ≤16.7 ms (last qualified run 17.57), physical mobile
Balanced ≤33.3 ms, full traversal/combat/respawn, final continuous video, root/canopy composition and
broader world finish. No target has been relaxed.

API references checked: [EditableMesh](https://create.roblox.com/docs/reference/engine/classes/EditableMesh),
[EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage),
[EncodingService](https://create.roblox.com/docs/reference/engine/classes/EncodingService),
[AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService),
[texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications),
[RenderSettings](https://create.roblox.com/docs/reference/engine/classes/RenderSettings),
[VirtualInput](https://create.roblox.com/docs/reference/engine/classes/VirtualInput).

## Frost Ridge steps checkpoint — 1 November

Replaced three floating white climb-block visuals with an original 384-triangle PBR stone, uploaded
once and reused. Native import scale, foot pivot, real asset IDs and typed map loads were checked;
the native library is mapped into the canonical build. Three broad ground-bearing supports now meet
the landings. Original landing boxes and jump gaps remain; three narrow footings add collision below
them (Bamboo 73→76). Six decorative mesh copies total 2,304 triangles. Source/master locations,
reproduction scripts and remaining checks are documented in `frost-step-candidate/README.md`.

`frost-steps/before_*` and `after_*` contain three actual Play views at identical poses with the normal
HUD and 100 HP. Before viewport 1271×685 and after 1221×503, with differing Automatic FRM levels;
these establish placement and material changes only. The earlier pointed support design is retained
as rejected. Broad supports fix floating contact, but their vertical map stretch still looks poor.
The normal jump/return route, matched foreground-quality images and timing remain unverified.
No Bamboo or world completion is claimed. Next: correct support texel scale, ordinary ridge traversal,
then grove-floor/crest/canopy refinement and the 60-second desktop route/combat benchmark.

Final checkpoint: 14/14 local verifier stages pass; canonical and open Edit scripts match **261 /
1,954,426 / 781841931**. Native library ID/size/flags were read back separately. Owned Play returned to
Edit with no comparison-restoration errors. See `frost-steps/checkpoint.json` and `verification-final.log`.

# Environment continuation — 30 October 2026

Active goal; Bamboo performance/video/full-route gates and the broader world remain unfinished.
Canonical: **261 scripts / 1,941,899 bytes / digest 1384380081**. Edit resync matches disk;
this batch does not claim a fresh canonical reopen. Both build hashes are in `checkpoint-digest.json`.
Full verifier: `verify-sanctuary-v1.log`, all 14 stages pass. Campaign build: 27/0, Bamboo 73 colliders.

## Bamboo v10

- Broke the straight crest/ridge snow border with a deterministic material-only mask. Terrain voxel
  occupancy, route slabs and collider transforms are preserved. Three matching before/after views
  are in `bamboo-v10/`; the close path no longer exposes a continuous white retaining-wall stripe.
- Four production Balanced views are in `bamboo-v10/balanced-emulation/`. Studio's iPhone 17 Pro
  preset, LandscapeRight, Automatic quality, TouchEnabled true, 750×381 logical viewport: **792
  registered / 64 active wind plants / 9 entry shadows**. This is emulation, not phone performance.
  The default desktop viewport (1221×503) and Automatic quality were restored.
- `detailed-validation/` retains a separate four-view Detailed run. The scripted quality setter
  failed; those images are correctly labelled Detailed, not Balanced.
- `baize-camera/`: eight actual ordinary-camera/lock-on frames over 7.52 seconds, started through
  the normal gate interaction with original 100 HP and combat rules. Body centre stays in viewport
  in all eight; body, pounce and impact are visible. HP falls 100→68→36→0. This is a seeded Studio
  diagnostic, not a sustained/earned fight. Normal combat teaches lock-on and kills the mock
  character; no live persistence is used. The temporary probe is removed afterwards.
- `mixed-run-not-acceptance.json`: 60.00 seconds, 3,299 frames, 97 unfocused, p95 20.15 ms; known
  foreground subset p95 17.65 ms. Entry death/respawn and Sanctuary travel make this unsuitable for
  the required Baize/full-pass route. No passing performance result or exact art delta is claimed.
- `video-capability.json`: native CaptureService in a genuine LocalScript reports Start Success and
  successful Stop, but no began/ended event, completion callback or capture object after 8 seconds
  plus 20 seconds completion wait. No continuous video was produced. Diagnostic script removed.
  API reference: https://create.roblox.com/docs/reference/engine/classes/CaptureService

## Sanctuary v1 — first material correction

Three reproducible ordinary player-height baseline views are in `sanctuary-baseline/`.
The upper camera was corrected against a runtime floor ray (ProcessionalWay Y=620.05); the initial
camera draft is preserved locally and excluded from committed evidence. Camera JSON is under
`tools/qa/cameras/sanctuary.json`. `sanctuary-v1/` is the fresh production Play result; `sanctuary-tint-preview/`
is only the earlier prototype.

The first visible defect was the pale figure merging into equally pale bark. A shared PBR tint
(145,136,129) on 41 existing tree/root sections separates their values. The 32 figure sections and
five glossy sap sections retain their original surfaces. No source mesh, UV, map, asset ID, scale,
collision or geometry was replaced. Runtime confirms 78 MeshParts, figure 150 studs, tree 613.26
studs (4.09×); no preview attributes remain. All 78 retain Automatic render fidelity.

Before adding geometry, `HeroComposition.luau` isolated the existing monument's rendered cost:

| View | Present tris / draws | Hidden tris / draws | Monument triangle contribution |
|---|---:|---:|---:|
| Plaza axis | 1,328,469 / 293 | 514,391 / 220 | 814,078 |
| Upper approach | 1,057,343 / 84 | 57,952 / 13 | 999,391 |
| Plaza reverse | 264,630 / 184 | 264,702 / 188 | Outside view; small unrelated frame variation |

Shadows excluded; this is view-dependent composition, not qualified GPU/foreground timing. The
original uploaded asset remains **78 sections / 1,180,276 triangles**, source masters untouched.
The tint adds no geometry. Supported tint API: https://create.roblox.com/docs/art/modeling/surface-appearance

## Three next Sanctuary defects

1. Upper root bed has soft, stretched surface detail at player distance. Inspect its UV/source
   density and grounding from side approaches before preparing new maps or validated duplicates.
2. Canopy leaves read as large angular fragments in close upward views. Preserve the master and
   evaluate silhouette/leaf detail copies against the approximately one-million-triangle near cost.
3. Side routes, cloud sea, terrace margins, forge and reverse approaches still need matching normal
   gameplay inspection. The three current images do not certify the whole region.

Remaining Bamboo: desktop ≤16.7 ms / physical-mobile Balanced ≤33.3 ms, sustained fight and full
walk/dodge/jump/glide/respawn/route checks, overlook grain/reverse edge, and continuous wind/traversal
video. No target is relaxed. Other campaign regions still need their own finish pass.

Existing unrelated General Zhao files and `outputs/blender-connection-2026-10-29/` are preserved
and excluded from this environment checkpoint. Connected Blender is currently on General Zhao v2;
its scene was inspected read-only and left intact. No art upload, public publishing or spending.

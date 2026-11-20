# Asset compliance for Studio MCP

Load before any MCP action that generates, inserts, imports, uploads, or saves
content, and before preparing anything for the Creator Store. This is a
pre-upload risk assessment, not a prediction of Roblox moderation. Never claim
an asset will pass. Recheck official policy when anything here looks outdated.

Tool names below are those the Roblox Studio MCP server currently exposes;
verify against the actual tool list (see [tool modes](tool-modes.md)).

| Capability | Typical tools | Main concern |
|---|---|---|
| Generate mesh / material / model | `generate_mesh`, `generate_material`, `generate_procedural_model` | Texture content (blood, symbols, text), IP look-alikes, silhouettes |
| Generate animation | `generate_animation` | Sexualised motion, graphic violence, threatening gestures |
| Insert store assets | `search_asset`, `insert_asset` | Scripts, dependencies, redistribution rights |
| Upload images | `upload_image`, `store_image` | Uploads create moderated assets on the user's account |
| Save | `save_place` | Persists everything into a new place version |

Review with capture, instance inspection, tree search, script grep/read, and
read-only Luau. Avatar Marketplace items are out of scope; NPC outfits,
uniforms, and custom character meshes are in scope.

## Modes

Checks are identical in both modes; only the approval point differs.

- **Preview (default).** On the first asset task in a session, ask once
  whether to preview each asset or run on autopilot. After each asset (or batch
  of up to ~5 similar ones), stop with a Preview Card and wait for: approve,
  revise, regenerate, discard, or approve all / switch to autopilot.
- **Autopilot (opt-in only).** Triggered by the user ("autopilot", "just do
  it", "run it all"). PASS moves on; REVISE self-corrects with at most two
  retries (more conservative prompt, swapped material); anything still failing,
  DO NOT UPLOAD, or NEEDS POLICY CHECK goes to quarantine and the run continues.
  End with an Autopilot Report.

Acknowledge mode changes in one line. A mode lasts for the session or the scope
the user named; never carry it into a new session. Assets made by other skills
or from previously approved prompts are still unreviewed output: preview them.

### Staging and quarantine

Generate or insert into `ServerStorage/_AssetStaging`; move failures to
`ServerStorage/_AssetQuarantine`. ServerStorage does not replicate, so nothing
unreviewed appears in a playtest. Quarantine is not deletion; the user decides.

### Hard stops (every mode)

Stop, explain in one or two lines, and wait before:

1. Any image upload. Show the exact image first.
2. Inserting a store asset containing `Script`, `LocalScript`, `ModuleScript`,
   or code loading (`require(assetId)`, `loadstring`, `LinkedSource`). Show the
   script inventory and findings.
3. Acting on any DO NOT UPLOAD finding.
4. Using third-party content with unknown rights (music, recordings, brands,
   fonts, textures from URLs).
5. Saving a cloud place after adding assets, unless the user asked to save.
6. Replacing or deleting user content outside the staging folders.

The user may pre-approve a named kind of hard stop for the current task
("you can upload the decals too"). Never assume that approval.

## Results

| Result | Meaning | Preview | Autopilot |
|---|---|---|---|
| PASS | No obvious concern; normal moderation still applies | Card, await approval | Proceed |
| REVISE | Specific fixable risk | Card with proposed fix | ≤2 retries, else quarantine |
| DO NOT UPLOAD | Clear policy issue | Card, recommend removal | Quarantine + hard stop |
| NEEDS POLICY CHECK | Genuinely uncertain | Card citing the doc to check | Quarantine, flag in report |

Separate explicitly prohibited content, context-dependent content, and
conservative recommendations. Do not invent blanket bans Roblox does not impose.

## Prompting generators

Most avoidable risk enters at the prompt.

- Describe wear as rust, mud, oil stains, chipped paint, scorch marks, moss, or
  water damage. Avoid blood, gore, wounds, or "splattered red" unless the user
  explicitly asks; then warn about the risk before generating.
- Convey horror or combat without injury cues (peeling paint, flickering light).
- No brands, logos, named characters, or "in the style of [franchise]".
- No text in textures unless requested; generated text can garble into
  offensive words. Prefer a controlled `SurfaceGui`/`TextLabel` for signage.
- No real people, extremist or hate insignia, or realistic drugs.
- Describe animations neutrally ("overhead sword swing", "victory jump").
- Record the final prompt in the review.

## What to inspect

Inspect the whole asset, not a thumbnail. Record which component causes each
finding. Anything not viewable at sufficient resolution goes under
**Uninspected components**, never PASS.

- **Images, decals, atlases.** Blood or injury, sexual content, hate symbols,
  extremism, self-harm, drugs, personal information, copyrighted art or logos,
  QR codes or off-platform links. Inspect atlases region by region, including
  "unused" areas and every map (colour, normal, roughness, metalness). Fix
  problems at the source; never hide them through UV placement.
- **Meshes, models, NPC clothing.** Geometry and anatomy; every `Material`,
  `MaterialVariant`, `TextureID`, `Decal`, `Texture`, `SurfaceAppearance` map;
  particle, beam, and trail textures; instance names and attributes; all script
  descendants. Fictional weapons are not automatically prohibited; assess
  realism and presentation.
- **Materials.** Tile on a large test part and capture close up. Watch for
  blood-like splatter, embedded text, and tiling that forms symbols.
- **Procedural models.** Check the silhouette from several angles and any
  reference image used (which must pass the image checks itself).
- **Animations.** Play on a rig and capture key frames. Ordinary dancing,
  sports, emotes, and fictional combat are fine; sexualised, torture, execution,
  or harassment motions are not.
- **Scripts in inserts.** Grep for numeric `require(`, `loadstring`,
  `getfenv`/`setfenv`, `HttpService`, `MarketplaceService` prompts,
  `TeleportService`, `LinkedSource`, long encoded strings, and obfuscation. Flag
  credential collection, exfiltration, backdoors, remote code, admin grants to
  unknown IDs, and edits outside the model. Unexplained or obfuscated code is
  DO NOT UPLOAD for the Creator Store and should be removed for in-game use.
- **Audio.** Explicit content, hate, threats, and copyrighted recordings.
  A download elsewhere grants no upload rights; keep licence evidence.
- **Thumbnails and metadata.** Review icons, previews, name, description, tags,
  and links. A safe thumbnail never covers for the asset's actual content.
- **Placement.** Individually fine props can compose a symbol, sexual shape, or
  gore scene. Capture the composed scene after placing assets.

## Blood and gore

Images are moderated independently of the experience. Environmental textures
are not exempt, and a small region of a larger atlas can trigger action. One
reported case: a developer received a one-day suspension (*Violent Content and
Gore*) for an atlas of ordinary environment materials that contained visible
blood-like stains. That is why image upload is always a hard stop.

| Appearance | Risk | Approach |
|---|---|---|
| Rust, mud, paint, ordinary wear | Lower | Ensure it doesn't read as bodily material |
| Abstract red markings, small stylised blood | Context-dependent | Check maturity rules; avoid realistic patterns |
| Splatters, pools, blood baked into atlases | High | Replace with dirt, rust, oil, or paint |
| Realistic wounds, dismemberment, torture | Prohibited | Don't create or upload |

An experience's maturity rating, including Restricted, does not authorise an
otherwise prohibited asset. Design Creator Store assets for broad use.

## Rights

Before inserting, uploading, or distributing: who made it, does the licence
allow redistribution and commercial use on Roblox, does it contain third-party
textures/fonts/models/audio, and does it resemble protected characters, logos,
or products? Credit is not permission; free is not open-source. Keep source
links and licences with the project.

## Workflow

1. **Destination**: private use, Creator Store, thumbnail, promo, or package.
   Unknown means conservative general standards.
2. **Stage**: generate or insert into staging; record prompt or asset ID.
3. **Inventory**: walk the full hierarchy (meshes, textures, materials,
   particles, audio, animations, scripts, dependencies, metadata).
4. **Review**: content, rights, and placement checks above, with multi-angle
   captures and texture close-ups.
5. **Technical/security**: validity, size, dependencies, script behaviour,
   current Creator Store requirements. Technical validity is not compliance.
6. **Resolve**: remove or replace problems; re-inspect after every change.
7. **Gate**: Preview Card or autopilot rules; hard stops always wait.
8. **Final**: inspect the exact files and metadata that will ship, then move
   out of staging, upload, or save.

## Output formats

```
ASSET PREVIEW · 2 of 5 · "rusted shipping container"
[capture: front] [three-quarter] [texture close-up]
Source:     generate_mesh: "rusted blue shipping container, chipped paint, dents"
Location:   ServerStorage/_AssetStaging/ShippingContainer
Components: MeshPart ×1, TextureID ×1, no scripts
Result:     PASS. Texture reviewed close up; wear reads as rust and paint.
Approve · Revise · Regenerate · Discard · Approve all / Autopilot
```

For non-PASS results or on request, a full review lists: mode, destination,
asset type, source, components inspected, result, findings (component, issue,
reason), required changes, uninspected components, and the limitation that this
is not a moderation decision.

```
AUTOPILOT REPORT · 12 assets
Placed (PASS):      9
Self-corrected:     2  ("bloodstained floor" → "oil-stained concrete floor")
Quarantined:        1  → ServerStorage/_AssetQuarantine/WallAtlas_03
  Reason: REVISE after 2 retries; red splatter in top-right atlas region
Hard stops reached: 0
Not saved, not uploaded. Captures kept for every asset.
```

## Official sources

Roblox Community Standards; Content Maturity & Compliance; Age-Restricted
Content; Creator Store technical requirements; Content Moderation; Studio MCP
server docs (`create.roblox.com/docs/studio/mcp`); Marketplace Policy (global
avatar items only). Update this file when those or the MCP tool list change;
don't hard-code temporary limits, fees, or eligibility rules.

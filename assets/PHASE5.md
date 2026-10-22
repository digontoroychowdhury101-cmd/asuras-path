# Phase 5 audiovisual delivery — 2026-10-19

The presentation code, eight scenery imports and 29 media uploads are implemented. Final placement,
authentic boss sculpts and device performance inspection are tracked separately below; this is not
a claim that every primitive has been replaced or that the game has reached final AAA art quality.

## What is implemented

- Client biome transitions: Sanctuary at 17:40, outdoor ambient 80/75/70, density .35, haze 1.8,
  rays .25/.4; cool 15:00 monastery, bamboo, crypt, pagoda, citadel and charcoal arenas. Only a
  player's own encounter can trigger the blood-crimson Phase 2 profile; respawn/exit restores the
  biome. Arena point lights change locally with the profile. The server authors the shrine baseline.
- Combat: .15-second elemental ribbons on weapon attachments, white-to-element color, 25–40
  directional deflect embers, .2-second circular shockwave, geometric ricochets before texture import,
  directional flesh sprays, ground-aligned fading stains and floor-following slam fissures. Existing
  hit-stop, trauma blur, FOV impulses and camera sway are preserved in a separate feedback module.
- Qi: expanding rotating hand seals, projectile ribbon/smoke tails and rupture effects. Every
  particle emitter has an authored texture slot; missing image uploads never enable default particles.
- Spatial audio: InverseTapered rolloff to 120 studs, .95–1.05 pitch variation, bounded voices,
  protected ambient loops, cloister/ravine reverb and EQ, movement loops, positioned bell/water and
  boss drone support. Original bundled combat cue fallbacks stay usable until owned masters are
   registered; all twelve new masters are now registered. Unuploaded future layers stay silent.
- Scenery: validated PBR template mounting, anchored decoration with collision/query/touch disabled,
  simple retained movement collision proxies, shared mesh/texture references, capped placements.
  Optional multipart boss skins weld to existing animated R15 limbs through explicit bind attachments.
- Rendering uses Roblox's supported lighting, SurfaceAppearance, Glass and Terrain water settings.
  Basin Glass reflectance and Terrain water reflectance are .94. No arbitrary GLSL shader or newly
  circular terrain basin is claimed.

## Asset package

`assets/build/phase5_import/` contains eight named GLBs, twelve 48 kHz mono PCM16 WAV masters,
eleven VFX PNG masks, six matching charcoal skybox faces, README and scenery preview contact sheet.
Each processed material has exact 1024×1024 Color, Normal, Roughness and Metalness PNGs alongside its
source export. Every mesh object is at or below 19,500 triangles; the frequently repeated rubble scan
uses a tighter 2,400-triangle cap. Source models with several materials can import as several MeshParts.

Sources are Poly Haven, Kenney and Ron Kapaun's CC0 Fantasy Ruins pack. The ruins are authored
architecture with diffuse/normal maps and newly authored scalar roughness/metalness, not scans.
See CREDITS.md and PHASE5_SOURCES.json. Generated WAVs include original synthetic bass, wind, bell,
water and bowed-string drone layers. The score is not a recorded cello track.

## Studio workflow

1. Import the prepared GLBs with 3D Importer as Creator: Me. Preserve their material maps, rename
   each model to its Asura name from PHASE5_IMPORT_QUEUE.json and put it in ServerStorage.AsuraAssets.
   Upload the WAV/PNG files; named SoundService.AsuraAudio Sound templates override audio slots.
   Export the real references with tools/qa/ExportPresentationAssets.luau, then register that JSON
   through tools/assets/register_uploads.py. Save a temporary XML place and extract the library with
   tools/assets/extract_studio_assets.py. The current Rojo library is AsuraAssets_Phase5.rbxmx.
   Rebuild/reopen after adding MeshParts: live sync cannot assign their new MeshIds. Automatic
   RenderFidelity is saved on the templates; server code reads the supported *MapContent properties.
2. Play locally and run tools/qa/InspectAudiovisual.luau in the server command bar. Inspect Shrine,
   Monastery and an arena; trigger Phase 2, leave, die and respawn. Check movement loops, seals,
   deflects, impact cleanup, SurfaceAppearance and decorative physics. Measure actual rendering
   statistics and device memory in Studio; instance/texture counts are estimates rather than draw calls.

## Verification and remaining work

The existing eleven combat/profile/movement/boss/objective/progression check groups pass. The new
runtime harness checks biome/phase isolation, acoustic zones, rolloff/pitch, voice eviction, ambient
preservation, anchor cleanup, effect budgets, ash teardown and PBR rejection. Export validation checks
GLB triangle totals, embedded PBR references, four exact PNG dimensions, audio peak/DC and format.
Blender QA renders exist for all eight meshes; previews use full-object orthographic framing.
Roblox-aware type analysis of the changed presentation modules has no TypeErrors in a temporary
relative-require mirror; older dependency errors and mirror-only unused-variable lint remain.

The place was opened in Studio and current source sync confirmed (`PHASE5_SYNC true true`).
All eight scenery imports passed PBR validation in Edit. The saved text library contains twelve models
(the original four plus eight new) and 23 MeshParts, all with complete map IDs and Automatic fidelity.
The 12 sounds, 11 VFX images and six sky faces are registered with real uploaded IDs. Typed
ContentProvider preloads returned Success for all 29 at 22:26:34 on 2026-10-19. The reusable check is
tools/qa/PreloadPresentationAssets.luau; passing raw WAV IDs as strings incorrectly treats them as images.

Two local playtests reached both server/client ready and displayed the shrine and crimson leaves.
They exposed restricted legacy SurfaceAppearance reads and RenderFidelity writes in the new dressing;
both are fixed, with regression coverage. The final clean rebuild is
/private/tmp/AsurasPath_Phase5_verified.rbxlx. Desktop control then failed with native pipe startup
errors, so the clean build's scenery placement, fight effects and GPU/memory inspection remain unverified.
The original saved place and binary asset library were preserved. No experience was published.

Still required for the full original vision: purpose-made or appropriately licensed crowned-colossus,
horned-beast and corrupted-abbot animated meshes; matching paifang roofs, bell tower, sacred weeping
tree, bridge and memorial detail; final placement and replacement of the remaining blockouts; published
experience permissions and real device/GPU budgets. The rejected procedural titan remains unused.

Boss skin template convention: AsuraBoss_<encounterId>, with optional _<AsuraAnimationSet> phase
variant. Each MeshPart needs complete PBR maps, an AsuraBone R15 limb-name attribute and an
AsuraBind Attachment that represents that limb's bind frame in mesh-local coordinates. Required
coverage includes head, upper torso, both upper arms and both upper legs. Invalid/missing skins leave
the existing rig intact. Static process_asset.py rejects armatures instead of destroying skinning.

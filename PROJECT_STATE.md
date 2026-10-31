# ASURA'S PATH (修羅之道) — LIVING PROJECT STATE & HANDOVER JOURNAL

## General Zhao attack polish — 2026-10-31 (Mac)

Re-authored Zhao attack windups (Heavy, L1, L2, Art, Quickstep); smooth per-frame clearance/elbow fields; attacks now start/end exactly on idle guard; Art spin unwind bug fixed. 27/59 clips validate; residual grazes ≤0.16 except L2 (0.32), wrists ~90°. Studio recheck skipped (Play mode). Next: L2/wrist polish, then upload.

## General Zhao animation phase 1 — 2026-10-31 (Mac)

59 procedurally authored clips (`assets/animations/general_zhao/`, not uploaded), previewed on the v2 mesh; Studio playback matches bake (0.0006 studs). Client phase-locks authored attacks to server impact, re-times Lightning Spear pulses, Oath_ keys, Zhao Guandao BossSwing. 25/59 clips validate; attacks still clip/pop. Next: polish attack clips, then upload.

## General Zhao v2 design review — 2026-10-31 (Mac)

Rebuilt Zhao in Blender by script (`tools/blender/zhao_v2/`): strand facial hair, irises, lacquered collar, calmer blade. Game mesh 22,090 tris, tip 9.246 studs, 1024²/512² textures. Assets in gitignored `assets/source/.../v2_design/` (local only). Not uploaded, not Studio-tested. Next: user visual review, then fix face bake and 40-stud read.

## Root material investigation — 2026-10-31 (Mac)

Recovered uploaded root geometry; diagnosed low UV density. Separate four-section bark pilot preserves geometry/normals; GLB round-trip passes. Uninstalled, no game-source change; digest 458197530. Evidence: `outputs/environment-art-2026-10-31/`. Mac lock blocks video/Play review. Blender crashed on Scene-library writing; headless collection workflow fixed, saved Zhao master intact, editor reopening pending. Next: unlock, restore editor, Studio pilot comparison.

## Sanctuary reliquary — 2026-10-31 (Mac)

Tiled shelter and bronze vessel replace exposed cache dressing; coplanar timber visual hidden. Original colliders/query/prompt remain. Normal Z hold grants Catalyst/two spells in mock Play. Verifier 14/14; digest 458197530. Evidence: `outputs/environment-art-2026-10-30/`. Next: root/canopy, side routes, other regions. Hardware/video/full-route gates open; General Zhao work preserved.

## Environment continuation — 2026-10-30 (Mac)

Bamboo snow edge corrected; Balanced emulator 792/64 plants; Baize body/pounce captured with normal health. Sanctuary bark tint separates figure; original 1.18M-triangle asset preserved/profiled. Verifier passes; digest 1384380081. Evidence: `outputs/environment-art-2026-10-30/`. Performance/video/full-route gates remain open. Next: Sanctuary side routes, root detail and canopy; remaining regions. General Zhao work preserved.

## Bamboo Pass art slice closed (v9) — 2026-10-30 (Mac)

Moon gate rebuilt, south grove, ridge drifts/coping, trunk grounded; colliders, elevations, altar, asset IDs unchanged. Nine views plus Baize telegraph captured; verifier 14/14, digest 803029733. Slice cost budgeted to +21% triangles. Mac timing not qualified; desktop/mobile gates open. Next: Windows 60-second Baize/traversal run, then Sanctuary.

## Environment checkpoint paused — 2026-10-29 (Mac)

User requested pause. Saved/closed Studio and Blender. Broken/fallen bamboo uploaded/integrated; grove clustering expanded, shrine/root assembly and arena pillars improved; original Y=0 floor exposed. Full verifier passes; digest 991116205. See `outputs/environment-art-2026-10-29/PROGRESS.md`. Next: final Bamboo views, moon gate/overlook, performance/regressions, then other regions. Desktop target remains unmet.

## Living bamboo entry checkpoint — 2026-10-29 (Mac)

Uploaded five original ecology meshes; entry has clustered canopy, grounded undergrowth, native grass, roofed gate and rooted client wind. Late-replication/removal/reduced-motion checks pass; verifier green. Evidence: `outputs/environment-art-2026-10-29/`. Foreground p95 17.57 ms exceeds 16.7 target. Next: shadow cost, root giant, shrine and remaining Bamboo views; other regions unfinished. Push/art approvals recorded.

## Environment art baseline — 2026-10-29 (Mac)

Canonical Studio digest 1174798130 matches source; no art changed. Eight-view capture tool, 60-second sampler and direction/ledger prepared in `outputs/environment-art-2026-10-29/`. Rojo can serialize Decoration/GrassLength despite unavailable MCP property reads. Rodin balance is zero. Next: confirm local Studio target, unlock Mac, capture running baseline, then implement Bamboo. Commits remain local pending push approval.

## 24 fps cap investigation — 2026-10-28 (Computer A)

Studio Play here is held at exactly 24 fps by a time limiter: unaffected by scene size, focus, power, Roblox caps (-1) or Process Lasso; panel is 60 Hz. Prime suspect: NVIDIA Max Frame Rate (global or Roblox Studio profile). Next: owner checks NVIDIA App, then rerun RegionFrameTime. Notes in `outputs/han-kit-2026-10-26/README.md`.

## Region frame time — 2026-10-28 (Computer A)

New `tools/qa/RegionFrameTime.luau`. Studio here is capped at 24 fps, so wall time is flat; GPU time 7.4–13.2 ms in Pagoda/Citadel/Bamboo views (worst: Citadel bastion), kits' cost below the ~2–3 ms noise. Next: find the 24 fps cap, uncapped run, phone check. See `outputs/han-kit-2026-10-26/README.md`.

## Han kits in Bamboo Pass and Sky Citadel — 2026-10-28 (Computer A)

Citadel floating boxes, glass cloud sheets and hanging platforms replaced: rock-peak massifs and pillars, Han towers, bastion pagodas, saddle paifang, dressed gate towers, mist. Bamboo: valley-wall pagodas on terraces, shrine lanterns/cauldron, bixies, ridge pines/crags. Pagoda models now face the path. Verifier green. Next: device FPS, human walk.

## Han architecture kits — 2026-10-26 (Computer A)

Pagoda primitives replaced: uploaded HD pagoda/paifang (original Blender builds, ≤18k tris per part) plus 0 A.D. Han kit (CC BY-SA, credited), MIT pines/rocks. Pagodas stand on terrain pillars; massifs under the gorge, forecourt, hall, terrace; floating roof ring and rafters removed. Verifier green. Next: device FPS, place kits in Bamboo/Citadel. See `outputs/han-kit-2026-10-26/`.

## Terrain footing pass — 2026-10-26 (Computer A)

Probe found terrain 0.3–3.9 studs above walkways; fixed (insets, deep ground fills, walkway carve, Monastery south clamp). RouteGuide walks clean on Bamboo, Ash, Pagoda, Citadel; stalls identical with terrain off. `studio_mcp.py` now runs on Windows. See `outputs/terrain-reuse-2026-10-26/FOOTING_WALK.md`. Next: human feel, FPS.

## Campaign terrain from GitHub — 2026-10-26 (Computer A)

Four PBR terrain variants (Terrain3D, Babylon.js, Godot demos; all >1,000★) uploaded. Natural campaign boxes now render as smooth Terrain over invisible colliders; ridged valley walls frame Bamboo, Ash, Pagoda, Citadel; parts use lobby PBR. Verifier green; Studio screenshots in `outputs/terrain-reuse-2026-10-26/`. Next: human walk of all regions, FPS check.

## Post-F26 step 6 (D1): Iron Bull maul and shield — 2026-10-26 (Computer B)

Bull uses boss-only IronBullMaul (6 moves, registry stays 12); arcs and records match spec in seeded Studio fights; back punish lands. Toast yields to perilous banner; crane fixes north-edge squeeze; Rafters roof fades. Mastery unchanged. Digest 1556498119. Next: Bull clips, Windows human feel. See `outputs/post-f26-step6-2026-10-26/`.

## Expanded GitHub reuse and combined sync — 2026-10-26

149 candidates, 135 above 1,000 stars; six repositories reused. Studio: 16 verified media templates, impacts/whooshes/thunder active. Nine CC0 motion sources and validated mesh/LOD pipeline included. Pending Iron Bull/camera edits preserved; offline camera/roof adapters fixed. Full verifier and builds pass. Next: R15 retargeting, visual/listening QA; forest ambience awaits Roblox approval. See `outputs/github-search-2026-10-26/README.md`.

## GitHub reuse — 2026-10-26

Integrated FastNoiseLite cliff profiles and Effekseer easing; uploaded six CC0 textures (6/6 typed preload), four active in parry/Blazing Sun. Two CC0 impacts prepared locally. Licenses, pinned hashes, tests and credits included. Full local verifier passed; final presentation checks/build repeated. Next: visual playtest, audio-upload approval; horizontal thunder variant awaits verification. See `docs/GITHUB_REUSE.md`.

## Post-F26 Steps 4–5: Twins greybox, Monastery approach — 2026-10-26 (Computer B)

Twins: kept spaced (6.3–7.8 studs), one perilous at a time, lock camera no longer floor-pitched, near-lens fade, banner below bars. Monastery: routes, ladder, tablets II–IV walked; bridge rail-gap fall fixed. Verifier green, digest 557606020. Next: Step 6 art (`STEP6_TWINS_ASSET_BRIEF.md`), Windows human/two-client. See `outputs/post-f26-step4-5-2026-10-26/`.

## Post-F26 batch 3: playtest kit, ledger, Shen handoff — 2026-10-25 (Computer B)

Studio-only 20-minute playtest panel and route; Claude diagnostics kept separate. Earned ledger opened (0/6). Shen P1/P2 asset handoff; skin loader now requires 15 limbs and lets templates own the weapon. Verifier green, digest 1661908618. Next: human playtest, earned session 1, Windows two-client OmniPvP. See `outputs/post-f26-batch3-2026-10-25/README.md`.

## Post-F26 step 2: omnidirectional combat — 2026-10-25 (Computer B)

StrikeGeometry: shared commit, tracking and air rules; the server-validated arc is drawn; the dash is fixed. Verifier and 21 suites green; single-client Studio duels (`OMNI_COMBAT.md`). Digest 1219538751. Next, on the other computer (not this MacBook): run the two-client `tools/qa/OmniPvP.*` test, then a human fairness playtest.

## Post-F26 audit — 2026-10-25 (Computer B)

Audit only, no source change. 2aa5000, digest 1438804042: verifier 14/14, 20 shim suites (2,191 checks), place rebuild byte-identical, clean Studio boot. Studio confirms 0 `AsuraBoss_*` templates and 0 authored boss tracks. Findings 3 Verified / 37 pending / 4 Blocked. Live ranked stays closed. Backlog: `outputs/claude-followup-2026-10-21/POST_F26_AUDIT.md`. Next: earned six-boss run, private live harness.

## Follow-ups 21–26: ending, gate, multi-client, sign-off — 2026-10-25 (Computer A)

Ending verified in Studio; fixed death-mid-scene overlay, three shot framings, ending text scale. 3-client duel/wager diagnostic 25/25 (exactly-once payout). Earned campaign 0/6; no hardware, listening or live-service runs. `FINAL_ACCEPTANCE.md`: conditional GO for private playtesting, NO-GO for launch. Next: owner actions there.

## Follow-ups 14–20: world, traversal, minimap route — 2026-10-25 (Computer A)

Minimap now draws RouteGuide's walked route (portal/climb/stain nodes). Guided Studio walks fixed crypt, Ash court, Pagoda stair/beam routing, optional-jump avoidance, grave path, Citadel catches (destroy height −400), Eaves rail, Ash darkness, stale stain card. Evidence: `outputs/claude-followup-2026-10-21/F14_20_WORLD_NAV.md`. Next: human bridge duel, Rafters ladder, Bamboo inscriptions/glide, art kits.

## Showcase spell sounds uploaded — 2026-10-24 (Computer B)

Uploaded the 18 original Supernova/Blazing Sun cues (OGG of `build_skill_audio.py` output) to Sheashing123 via Creator Hub and registered their IDs; all 18 load in Studio, so SkillAudio now plays the real masters. `register_uploads.py` now keeps hand-written ASSET_IDS sections. Next: mix levels by ear, other-player view.

## Showcase spells: cohesion pass + sound — 2026-10-24 (Computer B)

Matched more reference beats (ink burst, red splatter, shard flash, in-camera firestorm, hollow stars, merged blast blob). Added SkillAudio: 18 timed cues using pitched owned sounds; original masters from `tools/assets/build_skill_audio.py` await upload. Split modules under 150 lines. Studio real-speed pass clean. Next: upload the WAVs, other-player view.

## Showcase spells rebuilt to TikTok frames — 2026-10-24 (Computer B)

Supernova and Blazing Sun now follow the reference beat-for-beat: caster-only void, glowing ring, banded planet, ink frames, slivered pillar, whiteout; duotone close-ups, BOOM bubble, toon fire, silhouette star-eyes, crescent fists. Studio-verified with stretched cues. Next: real-speed playtest feel, other-player view, performance.

## Showcase spell VFX revamp — 2026-10-24 (Computer B)

Supernova (6 s charge, 3 pulses) and Blazing Sun (4 s charge, 4 pulses) rebuilt: sigils, lightning well, helix column with rune rings, miniature sun, fire pillar rings, cracks, rays, palette impact frames + negatives, multi-shot cameras that avoid walls. Per-hit damage cut so totals hold. Studio-tested; verifier 14/14.

## Showcase spells in Studio — 2026-10-24 (Computer B)

First Studio playtest of Celestial Supernova and Blazing Sun Awakening (3b2601f): unlock from caches, equip, cast, levitation (+10, lands cleanly), pillar, manga frame all work. Fixed: opaque orb (ForceField shell), voxels passing the lens, Blazing Sun charge camera blocked by the body, eye close-up filling the screen. Verifier 14/14.

## Bamboo Pass art — 2026-10-24 (Computer B)

Replaced the pass's placeholder bamboo (cylinder + flat leaf board) and grey KarstSpire slabs, seen from the monastery, with Blender assets (`tools/blender/bamboo_karst_kit.py` → `AsuraBambooKit`): 3 leafy bamboo variants, 3 fluted frost-capped karst towers. Old parts remain as fallback. Verifier 14/14. Next: device FPS.

## Bug sweep — 2026-10-24 (Computer B)

Play-tested lobby and regions. Fixed: monastery dead trees (scaled 4x and buried; world-space fit), loggia lookout solid black rail walls (open timber railing), black crag-garden beds (mossy). Rest, cache, reliquary jumps checked. Tree costs ~4–7ms GPU (RTX 4050). Verifier 14/14. Next: device FPS, monastery bamboo/cliff placeholders.

## Lobby fixes — 2026-10-24 (Computer B)

Mouse-look fixed (Alt now hold-to-free, cleared on focus). Tree re-grounded: flare planted, roots inside the rim. Front karst no longer overhangs the stairs. Lions now a mirrored pair facing the plaza. Cloud Reliquary has Blender-built floating stones and a shrine isle. Play-tested; verifier 14/14. Next: device FPS check.

## Fused tree statue — 2026-10-23 (Computer B)

`FusedTreeStatue` replaces AsuraVeiledTitan: woman stands clear of a 4x sacred tree, blood-red crown, glossy sap, 78 PBR MeshParts under 20k tris, no decimation. Play-tested in Studio; verifier 14/14. Source `tree+woman.blend` stays local (gitignored, >100 MB). Next: device FPS check of its 1.18M triangles.

## F03 input + HUD — 2026-10-23 (Computer B)

Seeded Studio diagnostic in `places/AsurasPath.rbxlx` (digest 48998423), two viewports. Fixed the menu-owner input leak, the Esc/Backspace close, stacked Respite, missing glyphs, small survival values and the respawn sky-camera, with regressions. `verify_all` 14/14. Next: prompt 04; device/lock-switch checks → 24. See `F03_INPUT_HUD.md`.

## F02d closing pass — 2026-10-23 (Computer B, Windows)

Same-UserId save/rejoin is still **Blocked**. The source confirms the Studio mock store is in-memory per server and keyed by UserId. Add Clients gets a new UserId, and a restart empties the store. No new Studio run was made; F02c coordinates stand: wake (60, 3.2, −1018). A human must run Team Test, or solo route B (test experience, API access, temporary `StudioLiveData=true`), per `F02_RECOVERY.md`.

## Detail/device handoff — 2026-10-23

Integrated Blender cliff/foliage detail, client landscape budgets, phone controls and local Rojo preloader fix. Canonical/mirrored place SourceDigest 1045496687. Verifier 14/14; movement 50; device 89; four Studio form-factor bounds audits pass. Physical hardware/FPS and successful two-client duel remain deferred. Latest build and editable assets are included; see [computer B handoff](outputs/lobby-finish-2026-10-23/COMPUTER_B_HANDOFF.md).

## Shrine monumental environment verification — 2026-10-23

The monumental lobby is integrated into `outputs/AsurasPath.rbxlx`: 150-stud goddess, active golden-hour atmosphere (Density 0.38/Haze 2.2), 48-stud pool promenade, 30-stud main stair, modular gate/cloisters, jagged floating terrace and eleven physical karst peaks over the cloud sea. Gao's cyan interaction cube is now a carved seal; the existing prompt and callback remain. Final local verifier passed 14/14. SourceDigest `1060436377` / 234 scripts agrees between the saved place, freshly opened Studio and verification build. Current stair climb, outer-cap landings and Gao interaction passed in Studio. Before/after images and explicit remaining fidelity, performance and device limits: [art-pass report](outputs/lobby-monumental-2026-10-23/ART_PASS_REPORT.md). No publishing performed.

## Unified Master Sync (Computer A + Computer B) — 2026-10-23

- **State Unified**: Merged Computer A's monumental Sanctuary art pass, Guardian Lion PBR models, and lighting into the branch with Computer B's F02 checkpoint findings and Windows rojo tooling.
- **Clean Place Build**: Rebuilt `outputs/AsurasPath.rbxlx` and mirrored to `places/AsurasPath.rbxlx`. Orphaned TikTokVFX references are fully cleared; `places/server.rbxl` is deleted.
- **Next on Computer B**: Run `git pull origin ux/onboarding-overhaul`. Open `places/AsurasPath.rbxlx` in Studio to see the complete, unified game.

## F02c checkpoint rejoin attempt — 2026-10-23 (Computer B, Windows)

- **Run**: Studio Server & Clients (set player count to 1; the default is 0). Seeded Studio diagnostic on `places/AsurasPath.rbxlx` (digest 761943064): rested at the Cloister, one monk KO left a 500 stain at (42.86, 3.2, −1047.8), woke at (60, 3.2, −1018), Essence 0. Exit Client was clean.
- **Finding**: Add Clients rejoins as a *new* UserId (−2), so local Studio cannot test same-user rejoin. **Blocked**: run Team Test on a separate test experience (steps in `F02_RECOVERY.md`).
- **Fix**: `tools/build.py` finds `rojo.exe` on Windows. `verify_all.sh` 14/14 (temp build).
- **Note**: the saved `places/AsurasPath.rbxlx` still contains TikTokVFX scripts that were removed from the tree in 83eb67f.

## Portable Prompt Catalog & Place Files — 2026-10-23 (Computer A)

- **ALL_PROMPTS.md & Brief Portability**: All hardcoded `/Users/digonto/...` absolute paths in `outputs/claude-followup-2026-10-21/ALL_PROMPTS.md`, `00_SHARED_BRIEF.txt`, and standalone prompt files `01_` through `26_` converted to repository-relative paths (`outputs/...`).
- **AsurasPath Place Files in `places/`**: Copied and tracked `places/AsurasPath.rbxlx` and `places/AsurasPath.rbxl` directly inside `places/`. Deleted deprecated `places/server.rbxl` to eliminate place-file ambiguity. `tools/build.py` automatically mirrors builds to `places/AsurasPath.rbxlx`.
- **Next**: Run follow-up prompt (e.g. 04/26) on Computer A or B.

## Showcase sorceries — 2026-10-23 (Computer B)

Two cinematic spells from the TikTok VFX reference, built into the existing magic system (not standalone Q/E scripts; Q/E still cast whatever is slotted).
- **Celestial Supernova** (CelestialThunder, 60 Qi, 32 s cd): ~3 s channel — levitate 10 studs into a dimmed void, teal planet + counter-rotating gold/teal rings, rising voxels, implosion; release drops a 24×120 cyan pillar with shockwave discs and spiralling voxels, second pulse = whiteout + cubic-falloff trauma shake, then descent. New server `Column` shape hits the floor under the levitating caster (radius 12, 2 pulses).
- **Blazing Sun Awakening** (CrimsonFlame, 55 Qi, 28 s cd): ~2 s stance (low Dutch camera, trembling shake, hand embers); release = blackout → solarized yellow → 2D manga impact frame (crimson silhouette, radial speed lines) + fire shockwave, blazing-eye macro shot with starbursts/jets, flame gauntlets, heat rings on pulses 2–3 (Aura 14, burn).
- **Unlocks**: Loggia Eaves cache → Supernova; Cloud Reliquary cache → Blazing Sun. `ArsenalInventory.migrate` regrants cache spells, so saves that already claimed those caches get them on next load.
- **Client**: `SkillShowcase` routes cues → `SupernovaShow`/`BlazingSunShow`, built from `SkillKit` (trove cleanup, procedural parts), `SkillCinema` (render step after the camlock: blended shots, Dutch/FOV, noise trauma shake), `ImpactFrame` (grading + manga overlay), `CelestialForms`, `FlameForms`. Timelines scale to the server's release time; camera/grading/levitation only on the caster's client. Honours reduced motion/flashes.
- **Verified**: 373 spell checks, 16 server-effect scenarios (2 new), boss rewards, arsenal codex, ledger, cast visuals, sanguine dispatch, HUD, movement, audiovisual suites pass; all new modules compile. **Not yet seen in Studio** — look, timing, camera feel, levitation physics and performance still need a playtest.

## Current VFX integration — 2026-10-21

Main source/build remains this checkout → `outputs/AsurasPath.rbxlx`. Seven bounded Sanguine client modules adapt the separate VFX demo; four bootstrap hooks, no gameplay-source changes. Original demo sources and pre-integration backups are preserved. Full local verification, 194 detached client-engine checks and 30 focused routing checks passed. Normal visual/device/performance acceptance remains pending; see `docs/PROJECT_VERSIONS.md` and `outputs/vfx-integration-2026-10-21/`.

> **Last Updated**: 2026-10-19, Phase 5 upload and verification pass
> **Status**: Phase 5 presentation systems and free asset imports implemented; final clean-build Studio/GPU inspection and bespoke art replacement remain pending.  
> **Built Target**: `/private/tmp/AsurasPath_Phase5_verified.rbxlx` — current temporary build. Original `outputs/AsurasPath.rbxlx` preserved.

---

## Phase 5 — Audiovisual systems and real uploads (2026-10-19)

- **Presentation**: modular combat feedback preserves hit-stop/trauma/camera and adds .15 s elemental weapon trails, 25–40 deflect embers, circular shockwaves, ricochets, directional blood and floor-aligned fading stains, slam fissures, rotating hand seals and projectile smoke ribbons. Particle slots use authored images; no stock spark/mist/leaf emitter is enabled. Budgets cap voices, bursts, shards, stains and nearby trails.
- **Audio**: twelve CC0/original 48 kHz mono PCM16 masters uploaded and registered. InverseTapered spatial rolloff (120 studs), .95–1.05 pitch variation, cloister/ravine reverb/EQ, movement loops, positional bells/water, ambient wind and boss drone. The drone has original synthesized bowed-string harmonics, not recorded cello. Credits and per-cue provenance are stored with the exports.
- **Atmosphere**: shared profiles cover Sanctuary (17:40, OutdoorAmbient 80/75/70, density .35, haze 1.8, rays .25/.4), cool 15:00 Monastery, all other biomes and charcoal arenas. Only the player's encounter drives Phase 2 crimson lighting; exit/respawn restore the biome. Arena braziers and drifting ash are bounded. Glass/Terrain basin reflectance is .94; no custom GLSL or circular terrain redesign is claimed.
- **Scenery pipeline**: Blender static-mesh optimization cleans loose/degenerate geometry, preserves UV/material seams, caps meshes at 19,500 triangles (repeated stone 2,400), exports exact 1024 Color/Normal/Roughness/Metalness maps and linked GLBs. Eight full-object QA renders exist. Poly Haven scans: stone, stone fire pit, brass diya lantern. CC0 3TD authored ruins: arch, rail coping stone, broken pillar, foundation and temple. The arch is Roman, not a scanned gothic arch; the low rail asset is a coping slab, not a complete balustrade. All source/license records are in `assets/PHASE5_SOURCES.json` and `assets/CREDITS.md`.
- **Uploaded library**: all eight new scenery models imported as Creator: Me and passed complete PBR validation in Studio Edit. Current Rojo library `assets/models/AsuraAssets_Phase5.rbxmx` contains twelve models (four preserved originals plus eight new) and 23 valid MeshParts. Each has four nonempty uploaded maps and saved Automatic RenderFidelity. `assets/PHASE5_UPLOADED.json`, `ASSET_IDS.md` and `PHASE5_IMPORT_QUEUE.json` hold the actual IDs. Original binary library is preserved. Rebuild/reopen after adding MeshParts; live sync cannot populate new MeshIds and can leave incomplete duplicate templates.
- **Media uploads verified**: twelve WAVs, eleven VFX PNGs and six charcoal skybox faces uploaded after the creator approved free uploads. All 29 are registered in `src/shared/PresentationAssets.luau`. Typed ContentProvider preloads returned **Success for all 29** in Studio Edit at 22:26:34. `tools/qa/PreloadPresentationAssets.luau` repeats the check. Published-experience access still needs verification against the eventual live place.
- **Runtime placement**: validated PBR templates replace selected rubble/pillars/idols and dress the Monastery/bridge; simple movement collision proxies remain. A multipart boss-skin loader is ready for actual R15-bound PBR sculpts, including phase variants, but no new boss sculpture has been fabricated or substituted. The existing rigs remain usable.
- **Verification**: eleven existing combat/profile/movement/boss/objective/progression test groups passed. New audiovisual harness passes **40 runtime assertions**, including restricted runtime property access, mounting, collision proxies, audio budgets, cleanup and phase isolation; eight GLB/map/preview exports and audio peak/DC/format checks pass. All **131** source scripts compile; selected 22 presentation modules have no TypeErrors in the Roblox-aware temporary require mirror (five mirror-only unused-variable diagnostics; older dependency errors remain). Rojo builds the full source plus imported text library successfully.
- **Studio findings**: opened `/private/tmp/AsurasPath_Phase5.rbxlx`, confirmed current source sync and ran two local playtests. Server and client reached ready; shrine/crimson leaves displayed. Fixed two real dressing failures: legacy *Map strings require Plugin security (now reads *MapContent.Uri), and runtime RenderFidelity writes are restricted (now authored on saved templates). Regression tests cover both. The clean rebuilt `/private/tmp/AsurasPath_Phase5_verified.rbxlx` is ready; desktop control failed with native-pipe startup errors before reopening/final inspection. Final scenery placement, combat VFX/audio feel, phase transitions and measured draw calls/GPU/device memory remain unverified. Existing core UI warning/old `203785492` asset mismatch also appeared; no live publication occurred.
- **Still required for the full art vision**: appropriate animated crowned-colossus, horned-beast and corrupted-abbot meshes; matching paifang roofs/bell tower/sacred weeping tree/bridge/memorial art; replacement of the remaining blockouts; final Studio visual/acoustic inspection and device performance budgets. The rejected procedural titan remains unused. Full details: `assets/PHASE5.md`.


## Phase 2 — Weapon ecosystem, discovery and Qi sorcery (2026-10-19)

- Arsenal: nine families including Unarmed, with Odachi, Twin Shadow Sai, Chain Scythe, Iron Tessen and Jade Catalyst added to the original four. Three boss variants bring the equipped weapon registry to 12 entries. New authored specs live in `WeaponExpansion.luau`; all use `WeaponSchema` validation and Tempo timing.
- Boss armaments: Shen wields Prayer of the Defiled, his Chimera phase uses Calamity Bone Cleaver, and the Ash Pagoda General in southern Bamboo Pass wields the Heaven-Piercing Guandao. Their arts release draining incense, a magma fissure and a lightning throw/impact teleport. Censer deflects add 25% reflected posture; sai backstabs multiply damage by three. Chain snares respect defense before pulling with LinearVelocity; fan finishers launch projectiles and held guard parries projectiles.
- Magic: `SpellSchema`, `SpellRules`, `MagicService`, `SpellEffects` and `SpellGeometry` implement all eight core spells across four disciplines plus three transmutable signature spells. Cast startup/recovery use Tempo; interruption cancels pending casts. Server checks ownership, Qi, cooldowns, hostility, walls and teleport clearance. Burn stacks, two-second roots, lethal/posture wards and AI phantom decoys are active. Catalyst primary/off-hand focus grants 25% potency and faster startup.
- Qi: base/max 100, starts full, +8 on melee hit, +15 on perfect deflect, passive 2/sec. Blocked melee contacts give no Qi. Spell damage does not refill Qi.
- Discovery: five one-time caches in waterfall alcove, pagoda rafters, mausoleum, Loggia eaves and Sanctuary reliquary grant weapons and spells. Gao's Loggia seal opens transmutation; each remembrance chooses one weapon OR signature spell. Immutable token provenance remains stored while a separate consumed ledger prevents reuse. All major campaign bosses award tokens; defeating Shen awards both Shen and Chimera tokens. Existing cleared encounters receive tokens through migration.
- Persistence: Souls schema is now version 3; older inventories migrate with two starter spells, cache flags, slots and remembrance ledgers. Corrupt version-3 arsenal ledgers fail closed. Combat packet version is 3 and includes all 12 weapon keys. `ArsenalIntent` validates exact bounded payloads and server rate limits.
- Controls/HUD: Q/E or D-Pad Up/Down cast; both diamond HUD cards are touch buttons. B/Select opens the arsenal for spell slots and weapons; Shift dodges, Z interacts, J swaps, R/Start heals, Caps/D-Pad Left sprints. Cyan/gold Qi arc and count sit below stamina, with cooldown sweeps on both spell cards. Client VFX include rings, hand glows, beams, pillars, tendrils, talismans and decoys. New weapons use local geometry and existing stock animation families.
- Verification: 320 checks pass in `tools/test_weapons_and_spells.luau`, covering contracts, payloads, Qi, casts, focus, wards, roots, caches, atomic forging and save/rejoin. `tools/test_weapons_and_spells_runtime.py` passes 14 scenarios using actual server effect modules under spatial/engine shims for piercing, wall blocking, delayed pillars, burn stacks, roots, decoys, Thunderfall impacts, parries and cancellation. Studio visual/device playtesting remains necessary; CLI verification does not certify animation or HUD appearance.

## 1. PROJECT IDENTITY & PILLARS
- **Genre**: Grimdark Wuxia Souls + High-Tempo Action Combat Hybrid.
- **Combat Core**:
  * 1.4× Tempo baseline (`src/simulation/Tempo.luau`).
  * Hybrid Weapons: nine families plus three boss armaments in `src/simulation/WeaponSchema.luau`.
  * Sekiro-style Posture & 100ms Deflect: Posture buildup, Deflect sparks, StanceBreak stun, cinematic Deathblows in `src/simulation/CombatRules.luau`.
  * Blood Rally & Tri-Layer HP: ActiveHP, RecoverableHP (debt restored via aggressive counter-attacks), PermanentDeficit in `src/shared/CombatSettings.luau`.
  * 60 Hz Circular Ring Buffer Lag Compensation with 150ms max rewind in `src/server/LagCompensation.luau`.
- **PvE Story Mode**:
  * Semi-open overworld regions: Desecrated Monastery, Bamboo Pass, Ash Pagoda in `src/shared/WorldDefinitions.luau`.
  * Incense Altar (bonfire) checkpoints, Lost Qi / bloodstain death drops in `src/server/Services/WorldService.luau`.
  * Mob AI and multi-phase Boss engine (Grandmaster Shen / Demonic Chimera) in `src/server/Services/AIService.luau`.
- **PvP Colosseums**:
  * Overworld dueling rings with 1v1 Ranked (normalized stats) and Casual sparring in `src/server/Services/ColosseumService.luau`.
- **Client Presentation**:
  * Third-Person Over-the-Shoulder Camlock (offset: 1.8, 1.4, 10.5) in `src/client/Controllers/CameraController.luau`.
  * Game Feel: Sparks, hit-stop, camera shake, concussive eye trauma blur/sway in `src/client/Controllers/GameFeelController.luau`.
  * Minimalist Souls HUD in `src/client/Controllers/InterfaceController.luau`.

---

## 2. ACTIVE DIRECTORY STRUCTURE & MAP
```text
/Users/digonto/Documents/ChatGPT/Roblox game 2/
├── default.project.json              # Rojo tree (AsurasPath namespaces)
├── README.md                         # Project specification overview
├── PROJECT_STATE.md                  # This living handover journal
├── outputs/
│   └── AsurasPath.rbxlx              # Active compiled place file
├── tools/
│   ├── build.py                      # Rojo place compiler
│   ├── cleanup_legacy.py             # Legacy file archiver
│   ├── test_asura_stage1.luau        # Stage 1 test suite
│   ├── test_asura_stage2.py          # Stage 2 test suite
│   └── test_asura_stage3.luau        # Stage 3 test suite
└── src/
    ├── client/
    │   ├── Bootstrap.client.luau
    │   └── Controllers/
    │       ├── CameraController.luau
    │       ├── ColosseumController.luau
    │       ├── GameFeelController.luau
    │       ├── InputController.luau
    │       ├── InterfaceController.luau
    │       └── WorldStateController.luau
    ├── server/
    │   ├── Bootstrap.server.luau
    │   ├── CharacterService.luau
    │   ├── LagCompensation.luau
    │   ├── PersistenceService.luau
    │   ├── ProfileStore.luau
    │   ├── ShopService.luau
    │   └── Services/
    │       ├── AIService.luau
    │       ├── ColosseumService.luau
    │       └── WorldService.luau
    ├── shared/
    │   ├── AnimationCatalog.luau     (Asset slots & fallbacks)
    │   ├── CombatSettings.luau       (Tri-layer HP, stamina, tempo)
    │   └── WorldDefinitions.luau     (Regions, Altars, Spawns)
    └── simulation/
        ├── CombatRules.luau          (Pure-functional combat resolver)
        ├── InputBuffer.luau          (100ms priority queue)
        ├── MoveSchema.luau           (16-state combat machine)
        ├── Tempo.luau                (1.4× temporal scaler)
        └── WeaponSchema.luau         (Move trees for 4 weapons)
```

---

## 3. ARCHIVED LEGACY CAGEBOUND FILES
All 128 Phase 1–12 Cagebound places and docs have been moved out of this project into:
`~/Documents/Cagebound_Archive/` (safe external archive).

---

## 4. UX / ONBOARDING PASS (2026-10-19)
- **Boot fix**: `SanctuaryService` titan auto-mount line was a Luau parse error (`(model :: any):ScaleTo` after a `local`), so the server never booted and players sat on the loading cover forever.
- **Objective tracker**: pure resolver `src/shared/Objectives.luau` (tested by `tools/test_objectives.py`) + `ObjectiveController` (top-right card, "NEW OBJECTIVE" flash) + `WaypointMarker` (gold ◆ with distance). Route: first rest at Primal Bonfire → Ascension Stairs → each altar in order → fog gate → Colosseum; bloodstain recovery takes priority; hidden in boss fights/duels. Server now mirrors defeated bosses to the read-only `AsuraBosses` attribute.
- **Controls card**: `ControlsCard` shows device-aware bindings (keys come from `InputController:Label`), auto-folds to a `[H] Controls` pill after 25 s; toggle H / D-Pad Left / tap.
- **Responsive HUD**: `HudKit.bindScale` scales Vitals, Loadout, Altar menu, objective card and the touch cluster by viewport height (clamped 0.7–1.35 vs 900 px); death screen and toast use scale widths.
- **Prompt double-fire**: E / ButtonX no longer sends the instant `Interact` intent while a ProximityPrompt is on screen (the prompt's hold owns it); touch USE drives the visible prompt.
- **Loading cover**: rotating gameplay tips; after 20 s without `Workspace.AsuraReady` it says the server failed to start (Studio) / is not responding (live).
- New shared kit `HudKit.luau` (palette, helpers, UI cue sounds). All new modules ≤150 lines.

## 5. VISUAL PASS 1 — SANCTUARY SET PIECES, ENEMY LOOKS, PROLOGUE (2026-10-19)
- **Asset pipeline**: CC0 Poly Haven sources in `assets/source/` (git-ignored) → `tools/blender/process_asset.py` (headless Blender: decimate ≤19.5k tris/MeshPart, 1024 PBR maps, GLB + PNG maps) → `tools/blender/preview_asset.py` (QA render) → Studio 3D Importer upload → exported `assets/models/AsuraAssets.rbxm`, Rojo-mapped to `ServerStorage.AsuraAssets`. IDs in `assets/ASSET_IDS.md`, credits in `assets/CREDITS.md`.
- **Uploaded (Creator: Me)**: Gothic Statue (colossus), Large Iron Gate, Dead Tree Trunk 02, Pine Roots — each MeshPart has a SurfaceAppearance with Color/Normal/Roughness/Metalness.
- **`SanctuaryDressing.luau`**: 48-stud veiled colossus on the dais (faces the plaza), 6 root clusters on the plinth, upright dead sacred tree shedding crimson petals, iron gates swung open at the Ascension portal. All calls go through `Dressing.try` (pcall) so a cosmetic failure never blocks boot. Replaces the old titan auto-mount that overwrote materials (the cause of the black statue).
- **`EnemyAppearance.luau`**: Corrupt Monk (ash skin, rust kasaya, prayer beads, ember eyes) and Cursed Swordsman (iron lamellar, pauldrons, black kasa, tattered cloak, ember eyes). `CharacterService.tint` now skips `AsuraAttire`. Catalog accessories were previewed and rejected (bright, cartoony).
- **`PrologueController.luau`**: 4-line skippable letterboxed prologue for new players (motive: Grandmaster Shen, the Fallen Abbot). Controls card waits until it finishes.
- Colosseum sign BillboardGui now sized in studs (was a screen-sized overlay visible from 140 studs).
- **Still ugly / next**: enemies are R15 block bodies (real meshes need Mixamo/Sketchfab downloads under the user's own login); Sanctuary still ~1,700 primitives + 86 Neon parts; spawn falls and triggers "The clouds return you".


## 5b. VISUAL PASS 2 — DESECRATED MONASTERY MAP (2026-10-19)
- **`MonasteryService.luau`** (+ `MonasteryKit/Fx/Grounds/Ruins/Halls/Landmarks/Atmosphere/Dressing/Survey`, each ≤150 lines) builds `Workspace.Map_DesecratedMonastery` before `WorldService.Start()`, replacing the greybox: gate landing + lacquered gatehouse (iron gates open) → courtyard (cauldron, bell tower ruin, fallen bell, dead tree) → half-roofed prayer halls with defaced idols → stone bridge over a misted terrain ravine → cloister + graveyard with toppled pagoda → south road to Bamboo Pass.
- Shrines carry `AltarAnchor_<id>` parts (rest prompts mount on them). `MonasterySurvey` raycasts every altar/spawn/patrol point and leg 2 s after build; Studio reports 0 walkability issues (3,171 parts).
- Terrain gotcha: smooth terrain surfaces sit 2 studs above a FillBlock's top, so the valley fills to −2.2 under flagstones at +0.2. No Neon/SmoothPlastic; set pieces are pcall-wrapped.

## Phase 1 — Kinetic Movement Engine (2026-10-19)
- **Movement architecture**: `MovementController.luau` is a strict, <200-line client controller with Grounded / Airborne / Sliding / Gliding / BulletJumping states. `MovementMath` handles momentum/slope calculations; `MovementEffects` owns procedural visuals. Registered in the Rojo tree; physics runs in `PreSimulation` and yields to server combat dash grants.
- **Mobility**: native initial jump, one forward/upward double jump per airtime, stationary crouch, +40% momentum slide with friction and slope acceleration, 160 ms stair-contact grace, release-to-cancel slide, and camera-directed 75-stud/s bullet jump from crouch/slide. Holding Jump or Aim glides immediately after a bullet jump, clamps descent to -6, steers with the camera and consumes a cumulative 3.5-second budget per airtime. Grounding replenishes air resources.
- **Controls**: Space / gamepad A = Jump (hold to glide); Shift / Q / gamepad B = Dash; C / Ctrl / L3 = Crouch/Slide; RMB / L2 = Aim Glide. Touch has separate JUMP, DASH, SLIDE and GLIDE buttons. Heavy moved to V; Caps Lock toggles sprint. The concurrent arsenal controls retain J for Swap and Z for Interact; spell slot one moved from Q to 1 so Q remains Dash (HUD/arsenal labels updated).
- **Combat/cleanup**: Dash retains server stamina costs and i-frames; jumps and slides do not grant invulnerability. Hitstun, server rooting, menus, typing, death, focus loss and respawning suspend/reset the appropriate movement and restore posture. No deprecated physics movers are used.
- **Game feel**: spring-smoothed +10 glide FOV, +10 bullet FOV punch/rumble, 0.6-stud slide camera drop and turn lean, procedural launch ring, double-jump somersault/bullet spin, shoulder wind trails and foot dust. Default/new-profile FOV is 70 (glide 80); existing saved FOV preferences are preserved.
- **Automated verification**: `python3 tools/test_movement.py` passes 48 assertions against the real movement, input and effects modules using deterministic Roblox engine fakes. Covers slopes/stair gaps, immediate bullet-to-glide, glide budget/release, every dash binding, touch separation, root/combat cancellation and respawn cleanup. All 88 current source files compile. Existing Stage 1/2/3 combat and objective suites passed before the concurrent combat expansion.
- **Type verification**: new movement modules and changed input/camera/controls scripts pass Roblox-aware Luau type analysis. CLI analysis used a temporary mirror with equivalent relative requires and corrected the downloaded definition of `GetFocusedTextBox` to its nullable runtime return. Pre-existing diagnostics in older dependencies remain; this is not a claim that the entire repository is type-clean.
- **Studio verification still pending**: attempted the full local playtest, but concurrent `WeaponSchema` changes require `WeaponExpansion` before it has replicated into the loaded place, blocking server/client boot. A separate temporary movement-only physics scene was prepared; the computer-use connection failed before it could run. Re-sync the complete combat tree, then check real stair/slope contact, bullet-to-glide transitions and visual feel in Studio.

## 5c. VISUAL PASS 3 — THE VEILED ASCETIC COLOSSUS (2026-10-19, in progress)
- **Target**: a seated, meditating female titan, Elden Ring boss quality: hood-mantle drawn over her eyes, angular blade crown, dark weathered granite, pale roots coiling her body, a dead pale tree arching over her with crimson leaves falling.
- **Procedural attempt rejected by the creator** ("drab, unrefined"): `build_titan.py` + `titan_dressing.py` + `bake_titan.py` (metaball body, cloth-sim robes) cannot reach sculpted quality. Kept only as tooling; its GLB is not to be uploaded.
- **Chosen route: AI image-to-3D sculpt** (Meshy / Tripo / Rodin, creator's own account). Brief and prompts: `assets/VEILED_TITAN_PROMPTS.md`. Creator generates `statue.glb` (+ optional `tree.glb`) into `assets/source/veiled_titan_ai/`.
- **Ingest**: `tools/blender/ingest_sculpt.py` normalises the sculpt (1 m tall, faces -Y), splits it into height slices (default 2 MeshParts ≤19k tris, seams protected), bakes the high-poly detail into 1024 Color/Normal/Roughness, grades colour toward dark granite (`--grade`), places the tree as `Titan_Canopy` with crimson leaf cards (`Titan_Leaves`), writes `veiled_titan.glb` + leaf PNGs + a golden-hour `preview.png`. Tested on stand-in models.
- **No CC0 seated veiled female scan** was downloadable without a login; Smithsonian's best match (Greenough's Washington) is male. No CC0 gothic sentinels/arches found either.
- **Luau (done, parses + Rojo builds)**: new `SanctuaryLeaves.luau` (tumbling crimson-leaf emitter: RotSpeed ±160, Squash flips, drag + wind draft, fades; `Scatter` of fallen leaves — decals once uploaded, flat crimson slivers until then), registered in `default.project.json`. `SanctuaryDressing` mounts `AsuraVeiledTitan` when present (62 studs incl. canopy, rests on the dais, leaves emitted from `Titan_Canopy`, collisions off for canopy/leaves) and skips old Roots/SacredTree; otherwise falls back to the Gothic statue. `SanctuaryService` plaza petals use the leaf emitter; fallen leaves on both basins, four stair treads, dais tiers 2–3.
- **Ingested 2026-10-19**: creator's Meshy models (`assets/source/veiled_titan_ai/statue.glb`, `tree.glb`, 500k tris each, concepts saved beside them) → `ingest_sculpt.py --parts 3 --tree-parts 2 --grade 0.4` → `assets/build/veiled_titan/` (5 MeshParts × 17.9k tris + leaves, 1024 maps reused from the source UVs; lean mode because the 8 GB Mac swapped on a full re-bake; `--bake` keeps the old path).
- **Uploaded 2026-10-19 23:29** (Studio 3D Importer, Creator: Me): `AsuraVeiledTitan` (6 MeshParts, flattened and renamed `Titan_*`) spliced into `assets/models/AsuraAssets_Phase5.rbxmx` (the live Rojo library); leaf images uploaded via a textured-card GLB (Asset Manager image import was blocked by a stuck audio import dialog) and registered in `PresentationAssets.Textures.Leaf/LeafScatter`. IDs in `assets/ASSET_IDS.md`.
- **Layout fix 2026-10-19 (`SanctuaryTitan.luau`)**: first play-test showed the tree 32 studs in front of her (toward the plaza), roots overhanging a 36-stud dais top and leaf cards scattered over 74×85 studs of sky. Now: Titan_Leaves cards dropped; figure scaled to 28 studs and seated 1.2 studs into the dais centre; tree scaled to 1.6× her height (capped at 40 studs wide for the arch opening), turned to the far side of her from the plaza and planted at her back; leaf particles from the crown slice only; warm fill light on her face. Dais tiers enlarged to 36/31/26 and shifted 7 studs toward the arch so the roots rest on stone. Verified in a Studio Run session (figure bottom 607.0 vs dais top 608.1; tree footprint inside the top tier).
- **Re-sited 2026-10-20 (creator: "not centred, not colossal, bonfire has no fire")**: the cramped plaza dais/arch/columns (beside the stair foot) are gone. `SanctuaryColossus.luau` builds a rock terrace (radius 86) flush with and overlapping the back of the Ascension landing, centred on the main axis; she sits on it facing the plaza: figure 100 studs, tree 130 studs behind her, columns + lanterns ring the rim, leaves scattered, three key SpotLights on lap/chest/face so she reads against the dusk haze. Sanctuary region bounds extended north (centre z-60, size 420×340×540). `SanctuaryBonfire.luau`: ash mound, charred-log teepee, coiled sword, built-in `Fire` ×2 + flame/ember/smoke particles + warm light (the old altar's tiny incense wisp is gone). Verified in a Studio Run session: figure centred at x=0, z 745, bottom 618 vs terrace 620; view up the axis from the plaza in `assets/build/veiled_titan/ingame_axis_view.jpg`. test_objectives passes.
- **Next**: player-walk the landing → terrace edge; the gate hides her lower half from the plaza by design (she rises above it).

## 5d. MENU UI POLISH PASS (2026-10-19)
- **Shared kit**: `UiKit.luau` (theme tokens, motion timings, SFX hook table `UiKit.Sfx` = Hover/Click/Error/Open/Close, themed Primary/Secondary/Danger/Ghost buttons with 1.05x hover lift, 0.95x press, stroke glow, gamepad selection = hover, disabled state that plays Error) and `UiWindow.luau` (modal shell: backdrop, CanvasGroup lacquer panel, shadow, title/subtitle/gold rule, close; Scale sizing clamped by UISizeConstraint + UIAspectRatioConstraint; spring open / fade close with a re-open-safe serial).
- **Arsenal rebuilt** (`ArsenalPanel.luau` shell + `ArsenalTabs.luau` cards): tabs Qi Sorcery / Weapons / Transmutation, discipline-coloured accent bars, slot and wield state shown on buttons, forging needs a second "Confirm?" press within 3 s. Same ArsenalIntent packets; `SpellController` now opens and closes it through `Panel.open/close/isOpen`.
- **New Respite menu** (`PauseMenu.luau`): P key or the round "II" seal right of the Controls pill (hidden during boss fights, altar, death, prologue, arsenal). Resume / Settings / Controls. Settings has FOV and camera-sensitivity steppers (Config.Camera limits/steps) that preview live, are saved through ShopIntent `SaveSettings` (keeps `leftHanded`), and revert if you leave without Apply. Gamepad B / Backspace goes back while open. The world never pauses.
- **Altar menu**: buttons use the UiKit juice; the panel springs in from the left with open/close cues.
- **Verification**: all changed files compile; `rojo build` succeeds; luau-lsp strict analysis (require mirror) reports no errors in the new/changed UI files (older dependency diagnostics unchanged); movement suite 48/48. **Not yet seen in Studio**: check that the panel looks right, the hover/press feel is good, and the layout holds on phone, tablet and ultrawide.
- **Next**: swap `UiKit.Sfx` ids for uploaded UI sounds; optionally move the Death screen and Colosseum menus onto `UiWindow`/`UiKit`.

## Phase 4 — The Jade Cataclysm: narrative and RPG progression (2026-10-19)
- **Status**: implemented in source; deterministic tests and temporary Rojo build pass. Real Studio camera, UI, physics and multiplayer playtesting remains pending. Existing saved place/assets are preserved.
- **Persistence**: profile schema **4**, Souls compatibility version **4**. `qiEssence` replaces Fight Cash; migration merges legacy cash and carried essence once, maps Vitality → Vigor and Qi → Endurance, and preserves owned weapons/reinforcement, spell slots, checkpoint/boss flags, cosmetics and durable purchase/result ledgers. Canonical RPG inventory/loadout/attributes/colosseum records synchronize with the existing world and arsenal APIs through `ProfileBridge`. Future schemas fail closed.
- **Attributes and death**: Vigor improves health and Blood Rally; Endurance improves stamina/posture; Strength and Dexterity scale heavy/agile weapon families; Arcane Qi improves the Qi pool and spell damage. Levels cost `floor(150 * N^1.4)`. All unspent and unbanked Qi drops on death into the crimson wraith bloodstain; a second death destroys the previous pool, including when the new pool is empty. Runtime Qi HUD reflects the increased maximum.
- **Forge and mastery**: +0 to +10 reinforcement consumes Qi and Spirit Iron Ore, Starfall Shards or Dragonite Cores; each tier adds 10% to weapon damage/stat scaling. Crimson Fire adds a four-second Strength-scaled burn; Celestial Lightning adds Dexterity-scaled posture and hit stun; Abyssal Void pierces 30% of guard defense and gains Arcane Qi scaling. Mobs award ore and 30 weapon mastery XP; boss kills award 250 mastery XP and first boss victories grant forge materials/gems. Mastery thresholds 0/100/300/700/1500 unlock the rank-five signature deathblow, with increased execution damage, a cinematic camera shot, layered built-in impact audio and a procedural shockwave. Authored custom animation/audio assets remain future polish.
- **Narrative**: `NarrativeCatalog`, `DialogueRules`, `DialogueService`/`DialogueActions` and `DialogueController`/`DialogueView` implement Gao, Lady Lin and the Wandering Hermit. Conversations have server-owned choices/revisions, proximity/life/combat checks, letterboxing, rich-text typewriter subtitles and chimes. Resting at altars opens Lin's Ascension interface with a local spirit portrait; defeating the six campaign sovereigns unlocks her ending dialogue. Gao opens reinforcement, infusion and discovered remembrance recipes. The Hermit sells forge supplies, elemental gems and Last Breath Talismans (invoke from Arsenal → Weapons for a 30-second ward against one fatal blow).
- **Lore and codex**: eight glowing memorials across the Monastery, Bamboo Pass and Celestial Pagoda grant one-time Qi and durable codex flags. Read them with Z / gamepad X; reopen discovered entries with J or the Codex button. Default NPC interaction uses the same prompt controls. Legacy altar/travel and arsenal controls remain available.
- **Colosseum**: Ranked Normalized gives both fighters identical five-attribute values (20), +0 weapons, and no progression infusion/mastery effects; Open Arena retains full builds. Persistent ranks are Unranked → Ash Disciple (<1100) → Iron Vanguard (1100+) → Sword Saint (1400+) → Asura Sovereign (1800+). Existing live ranked release gates remain in force. A raised balcony and staircase overlook the Sanctuary Promenade duel ring.
- **Spectator wagers**: 50–500 Qi per spectator per duel during the 12-second countdown; 1.8× total payout on a win and refunds for draws/cancellations. Fighters, distant players, late/duplicate requests and malformed packets are refused. A separate immutable match journal and per-profile escrow ledger make settlement/reconnect recovery idempotent; unresolved crash journals expire to refunds after 20 minutes. Shutdown settles/refunds wagers before releasing profile leases. Live DataStore delivery remains subject to Studio/cloud integration QA.
- **Verification**: `work/bin/luau/luau tools/test_progression_and_lore.luau` passes **139 checks** (migration/isolation, cost/scaling, all ten upgrade tiers, infusion combat effects, mastery execution, dialogue/codex, death overwrite and wagers). `python3 tools/test_progression_runtime.py` passes **34 checks** against the actual world, dialogue, forge, portrait and wager modules using deterministic engine fakes, including stale revisions, invalid context, duplicate rewards, offline losses and shutdown refunds. Existing Stage 1/2/3, backend, profile integrity, commercial, movement, objective, boss, weapon/spell and review regression suites pass. All **123** current source scripts compile; all 18 new ModuleScripts are strict, ≤150 lines, and registered in `default.project.json`. Rojo validated the full tree into a temporary place; the saved `.rbxlx` was not rewritten.
- **Next Studio checks**: sync the full source tree; test Gao/Lin/Hermit on keyboard, controller and touch; verify eight tablet placements and both portrait cameras; level each attribute and inspect spell/Qi behavior; die/recover/die again; reinforce/infuse and earn rank-five mastery; run two duelists plus a spectator to check normalized/open builds, countdown closure, balcony visibility, payout and reconnect recovery.

## 5e. SAKURA HUD RESTYLE (2026-10-20)
- **Target**: the creator's reference screenshot (sakura/wuxia HUD). Palette is now plum ink, sakura pink, blossom, crimson life bars and gold trim (`SakuraKit.Colors`; `HudKit.Palette`, `UiKit.Theme`, Interface constants and touch buttons follow it).
- **`SakuraKit.luau`**: instance-built five-petal blossoms, ringed medallions with sprigs, diamond caps, segmented stat bars (same `{ Segments, Count }` contract as the old arcs, so `setArc` still drives them) and round blossom-framed buttons. No uploaded images.
- **Layout**: bottom-left plate holds the medallion, `Lv. N`, Essence, HP (diamond caps, value inside), stamina, Qi and posture bars, plus weapon, off-hand and flask. Top-centre `SakuraCompass` has a heading strip with a blossom medallion and sliding N/NE/E… marks. The boss bar moved under it: serif name, crimson gradient bar in a gold-trimmed casing with diamond caps. Top-left `SakuraMinimap` turns with the camera, shows hostiles in crimson, other fighters in blossom and altars as gold diamonds, has the region name, and two rim buttons (≡ Respite, ? Controls; this replaces the old "II" seal). Bottom-right `SpellHud` has round blossom skill buttons with discipline glyphs (雷炎虚符), key badges, a cooldown tick ring and an Arsenal button (器 / B). On touch the cluster lifts above the combat buttons. `SakuraHud` drives the compass, minimap and the screen-space petals, and hides them during the prologue and death screen.
- **Verification**: everything compiles, `rojo build` passes, luau-lsp shows no new errors (the older InterfaceController/dependency diagnostics are unchanged), movement suite 48/48. **Not yet seen in Studio**: check spacing, the CJK glyph fallback font, that the compass direction is right (north = world -Z), and the phone layout.

## 5f. COMBAT READABILITY HUD (2026-10-20)
- Removed all player-visible CJK text (spell glyphs, Arsenal button, boss counter toast, Colosseum sign glyphs, Monastery plaque).
- `MoveIcons` + `IconShapes`: frame-drawn move pictures (slash, heavy, parry, block, dodge, art, heal, lock, arsenal, thunder/flame/void/talisman). Used by SpellHud and the new HUD.
- `CombatHud` owns: `ActionBar` (bottom-centre keybind medallions that light up on use; hidden on touch), `EnemyBars`/`EnemyPlate` (overhead HP + damage trail + posture for hostile non-bosses within 60 studs, plus attack warning ring from `AsuraTelegraph`: turns gold = parry, red ! = perilous/dodge), `CombatCallouts` (damage numbers, PARRY/BLOCKED/GUARD BROKEN/COUNTER/DEATHBLOW pops, guard emblem with posture while blocking), `TargetPlate` (top-centre named HP with numbers for the current foe when no boss bar).
- Lock-on billboard now shows only the reticle; mob telegraphs moved from InterfaceController to EnemyBars (bosses keep the big !).
- Verified: compile, Rojo build, luau-lsp clean on new files, movement test 48/48. NOT verified in Studio; server damage path untouched and unverified live.

## 6. CURRENT MILESTONE & NEXT TASKS
- **Next verification**: complete the Phase 4 Studio checks above after Rojo sync.
- **Completed sanctuary milestone**: the opening **Sanctuary Lobby** ("The Shrine of the Ascendant") includes:
  * Golden Hour sky sanctuary above sea of clouds (`TimeOfDay = "17:35:00"`, `Atmosphere`, `SunRays`).
  * Circular reflective terrace with shallow water ring and Primal Bonfire Altar.
  * Ascension Portal staircase leading to the Story Mode.
  * Blacksmith forge loggia (West) and 1v1 Colosseum balcony (East).
  * Implemented via `src/server/Services/SanctuaryService.luau` and updated `default.project.json`.

---

## 7. AGENT PROTOCOL (HOW CLAUDE MUST OPERATE)
1. At the start of a chat, read this file (`PROJECT_STATE.md`) to establish context.
2. Only write/edit code in `src/`, `tools/`, and `default.project.json`. Do NOT touch binary files (`.rbxlx`, `.zip`, `work/bin/`).
3. Maintain strict Luau typing (`--!strict`).
4. At the end of every task/chat, update this file (`PROJECT_STATE.md`) with the new status, changes made, and next steps.

### 5d. Veiled Titan re-import (2026-10-20)
- Shards were caused by decimating the AI GLBs unwelded (triangle soup). `tools/blender/ingest_original.py` now welds the original GLBs, decimates lightly to 190k tris each, and cuts them into 32 MeshParts of about 11.9k tris (Titan_Figure_01–16, Titan_Canopy_01–16). It keeps the original textures, with no grading.
- Uploaded via the Studio importer and spliced into `AsuraAssets_Phase5.rbxmx` with DoubleSided, Precise fidelity and Box collision. The tree has no collision. The asset IDs are in the rbxmx (`grep rbxassetid` under AsuraVeiledTitan).
- Layout: she is 100 studs tall. The tree is 4.5× her height (about 450 studs), and its hanging roots sink into a terrace of radius about 245. Bounds were extended.
- Not done: ASSET_IDS.md still lists the superseded meshes. No playthrough with a character yet.

## Hands-on assessment — 2026-10-20
- Report: `outputs/playthrough-2026-10-20/PLAYTEST_REPORT.md` (44 prioritized findings, coverage matrix, source-supported follow-ups); nine screenshots and selected runtime evidence are beside it.
- Actual local single-client play: fresh prologue/Sanctuary, Lin dialogue and Vigor upgrade (level 2 / HP 106), normal portal traversal, Monastery courtyard combat (one monk killed), bridge/ravine/exterior exploration, Cloister rest and combat, repeated deaths/retries, Arsenal tabs and empty Codex.
- All six boss encounter starts were visited with assisted test access; later attempts used a temporary camera assist because native mouse capture was unreliable through the control tool. No boss was defeated, no phase-two/reward/ending completion is claimed, and no player health/damage cheats or automatic kills were used. The normal later connecting routes were not fully walked.
- Reproduced before assisted access: Monastery Gate and Cloister rests left the correct active-altar attribute, but death returned the player to the Sanctuary spawn. Exact cause remains undiagnosed.
- Major observed issues: near-black boss lighting; bridge swordsman obstructed by central stone geometry; Cloister altar/portrait occlusion; Z/E interaction inconsistency and E spell overlap; overlapping controls/action bar, duplicate HUD elements; repeated SpatialAudio locked-Parent cleanup exceptions; later environments and boss models still visibly incomplete.
- Source findings needing fixes: ArsenalTabs compares remembrance token objects to boolean true, preventing owned recipes from becoming ready; current six-boss roster lacks matching recipes for five bosses; Lin's promised crossing is dialogue without an implemented ending choice/completion sequence in the inspected flow. These were not verified through earned boss victories.
- No gameplay source or saved place changes made. Local Play session stopped, ending temporary runtime observers/camera helpers. Existing working-tree changes preserved.
- Next: fix checkpoint/recovery loop, combat lighting/collision and input ownership; then validate one complete earned boss-to-forge vertical slice before expanding presentation across the remaining campaign. Human continuous-input boss clears, full collectibles/forge, all travel, multiplayer, device layouts, audio listening and live persistence remain outstanding.

## Claude repair prompt pack — 2026-10-20
- Created `outputs/playthrough-2026-10-20/claude-prompts/`: shared operating brief, 26 sequential work prompts, combined copy/paste bundle, manifest and progress tracker mapping all 44 playtest findings.
- Order: core/UI/rewards/tutorial; bounded boss/character passes; one-region environment passes; ending; earned solo, multiplayer/persistence, device/accessibility and performance/audio acceptance. Individual work prompts are approximately 225–290 words and direct targeted reading/checks. Missing production assets and unverified gameplay remain explicit.
- Preparation only: no gameplay code, assets, saves or Studio state changed by this task. All repair statuses start Planned.

## Repair batch 01 — checkpoint lifecycle (2026-10-20)
- Respawns now stand on a raycast floor at the active altar and are held 1.5 s against LoadCharacter displacement; the Sanctuary catch only applies to bodies that fell from the Sanctuary. One death penalty per life. New `RecoveryRules` module; `tools/test_recovery_lifecycle.luau` (94/94) and a Rojo build pass. Studio respawn acceptance remains pending.

## Repair batch 02 — input map (2026-10-20)
- New `Shared/InputMap` is the single control definition: Z/ButtonX interact for every prompt, E spell 2, J Codex, K Swap. Input, spells, Codex, controls card, action bar, pause key and all 11 server prompts derive from it; Interact fallback reach matches prompts. `tools/test_input_map.luau` 281/281, Rojo build OK. Studio/device acceptance pending.

## Repair batch 03 — combat lighting and audio cleanup (2026-10-20)
- Boss fights now use their arena biome's `Combat:`/`Unbound:` profile with a neutral-fill floor instead of the shared Colosseum night; `ArenaLightPlan` adds overhead fill lanterns covering every arena floor. `SpatialAudio` releases each voice once, never destroying inside `Destroying` (locked-Parent cause reproduced). New `EffectsPreference` thins petals/ash in fights. `tools/test_combat_presentation.luau` 165/165; Studio captures/listening pending.

## Repair batch 04 — HUD layout and transitions (2026-10-20)
- Controls card is a centred overlay in a reserved band (pill beside Codex); CoreGui health/player list off; one source per value (focused foe on TargetPlate, crowd budget/stacking); Twins get separate sigil rows and tags. Vitals show ceiling notch, rally countdown, flask pips, essence vs Qi. One HudVisibility rule hides/restores HUD for prologue/death/dialogue. Blood-red petals, seal crests. `tools/test_hud_layout.luau` 176/176; Studio views pending.

## Repair batch 05 — rest, Lin and leveling (2026-10-20)
- Resting sets checkpoint/refill and opens the altar menu only; Lin is a deliberate "Summon Lady Lin" choice (server-validated; projection kept, in person at her bonfire) and leaving returns to the altar. `PortraitCamera` probes both shoulders with collision fallback; dialogue uses UiKit, says Essence, closes on death/respawn. `LevelPreview` shows derived before/after, cost and Essence left; bounded Ascension scroll. `tools/test_rest_dialogue.luau` 61/61; Studio play pending.

## Repair batch 06 — Arsenal descriptions and Codex progress (2026-10-20)
- New shared `ArsenalFacts` derives spell targeting/effects/cost and weapon style plus a ▲/▼ comparison with the wielded weapon from the real schemas and scaling (`CombatRules.scalingAttribute` extracted, math unchanged). Slots read "Slot 1 [key]" from InputMap. New `CodexView` shows n/8 inscriptions, n/6 sovereigns, instructions and sections; locked lore shows only its region. `tools/test_arsenal_codex.luau` 159/159; Studio views pending.

## Milestone 1 — batches 07–10 (2026-10-20)
- Bridge arch stones no longer spike the deck; Cloister pocket and exit aisle open; floor limited to valley/plateau with a crest veil and ravine return; arrival faces the Gate altar. All six sovereigns have weapon/spell recipes; Ash Pagoda General retired with legacy aliases. Whiff/Evade events and callouts; full-health drinks refused; enemies fold and dissolve. Server-judged ten-step training with Sparring Phantom, stakes card, clean prologue veil. Four new Lune suites pass; Studio pending.



### 5e. Titan + tree composed into one piece (2026-10-21)
- `tools/blender/compose_titan.py` builds her and the tree at final scale in studs (figure 100, tree 450). The trunk base sits 175 behind her; the tree's hanging roots sink below the floor so its root bed lies flat. Root tips under or in front of her plinth are trimmed. Generated bark roots (`Titan_Roots_01`, tileable pale bark with crimson veins) run from the root bed up her plinth, climb her body, and arch from the trunk onto her back.
- `SanctuaryTitan.Mount` now moves and scales the piece as one: it turns it so the tree faces away from the plaza and seats her plinth 2 studs into the terrace. `TreeSpan` (Forward 150, Radius 240) sizes the terrace.
- Verified in a Run session: plinth base at y 618 on the 620 terrace, tree root bed on the same floor. Screenshots: `assets/build/veiled_titan/ingame_composed_*.jpg`. New IDs are in ASSET_IDS.md.

## Milestone 2 — batches 11–14 (2026-10-20)
- No boss skin templates existed and failures were silent; BossSkin now resolves per-actor keys and reports status. Authored welded looks for all bosses (creatures on matching hurtboxes, procedural poses), shared entry handoff (protected lock, skip, deferred first impact), pillar-safe Baize, clear Titan ankles. Player attire rebinds after avatar loads; Lin, Hermit, Gao figures; enemy roles. Two new Lune suites pass; production meshes/animations and Studio views pending.

## Batch 15 — Monastery environment and discovery route (2026-10-20)
- Bridge rebuilt as a wuxia beam bridge with gateway and lions (the "Roman" arch is gone); new route pockets and storytelling props; the west exterior is a secret waterfall path rejoining through the west hall, other dead ground is scree; drum tower and outside ladder for the rafter cache; foes fight inside zones; marker follows doorways and the portal. Offline reachability suite passes; Studio walks pending.

## Milestone 3 — batches 16–21 (2026-10-21)
- **16 Sanctuary.** Imported colossus untouched. New `SanctuaryRoutes`/`SanctuaryApproach`: south pilgrim walk to the Well of Descent (crypt portal, return arrival), cloud shards to the Reliquary isle, eaves cache moved out of the roof ridge onto a ladder lookout, two viewing wings and two terrace daises as reveal points, terrace rim parapet. Offline model checks routes, sightlines, rim and cloud catch; Studio views pending.
- **17 Bamboo Pass.** `BambooPassLayout` + `BambooDressing`: gate clearing (tablet V), ridge stairs to a frosted crest, shrine pocket (altar moved off Baize's wall), Baize's mouth, moon gate, ash descent; optional frost-stone climb to a ridge overlook (tablet VI). Thicket veils, foes re-placed and zone-leashed. Offline walk/jump checks pass; Studio play and bamboo meshes pending.
- **18 Ash Colosseum.** `AshColosseumLayout` + `ColosseumDressing`: ash road, raised antechamber altar pocket, two-half Hall of Champions, facade 18 studs off the arena, low podium and five-tier cavea (camera clear), Victor's gate to the causeway. Fog gate, phases and IDs unchanged; Sanctuary PvP untouched. Offline checks pass; Shen fights in Studio pending.
- **19 Sunken Crypt.** `SunkenCryptLayout` + `CryptDressing`: portal arrival on a descent landing with the return portal behind, incense gallery altar, nave, Titan's hall with 16-stud ambulatory and bone curb, optional pit (fall returns to lip) and balcony. Depths lighting raised from near-black. Cloud catch verified to ignore crypt play offline; Studio pending.
- **20 Celestial Pagoda.** `CelestialPagodaLayout` + `PagodaDressing`: cloud stair into a lotus gorge, west stair, eave gallery, rafter beam and lantern hub, rafter stair to the forecourt altar and Wu's gate, dawn terrace (final tablet VIII); optional rafter-end jumps to the throne loft (tablet VII). Falls land on walkable floors. Offline checks pass; Studio pending.
- **21 Sky Citadel.** `SkyCitadelLayout` + `CitadelDressing`: saddle stair, cloud bridge, Heaven's Stair, Last Bastion altar with a return portal to the bonfire, open summit plateau with a low rim for Wyrm flight and camera. Chasm and summit falls return safely. Campaign chain walks Monastery road → Wyrm gate and back offline; Studio and production art kits pending.

## Milestone 4 — batches 22–26 (2026-10-21)
- **22 Ending.** `EndingRules`/`EndingCredits`/`EndingController`: after six defeated-boss flags Lin offers Release in person (her projection calls you home); Cross/Remain are recorded in `souls.world.story` before a skippable, interrupt-safe crossing scene with record-sourced credits; Postgame Lin replays it; objectives lead home, then free roam with PvP optional; Codex line. Nothing granted, so no duplicates. Seeded runtime checks pass; earned run pending.
- **23 Integration.** `tools/lune_compat.py` runs all 13 Lune-only suites locally (1,547 checks) and a seeded campaign ledger (99) covers joins, bosses, death/bloodstain, forge, 8 tablets, 5 caches, ending and rejoin. Two PvP rings had become unreachable (fixed in 24). No Studio or earned play was possible here; acceptance matrix in PROGRESS.
- **24 Multiplayer/persistence.** Real Colosseum + wager services harness (28, mocks): ranked/open builds, wagers, disconnect, outage, shutdown. Fixed: a leave during match setup broadcast a forfeit. Ash PvP ring re-enclosed by a Proving Court; Gatehouse ring yard cleared of scree (draw-stable). Live DataStore and multi-client still pending.
- **25 Devices.** Touch layout profile in the safe area (6 phone/tablet viewports overlap-free), `DeviceLayout`, 44-pt touch targets, touch counter hints fixed, Respite lists Controls/Codex and is reachable from the Arsenal on controllers, scrolling pages, persisted comfort settings (reduced effects/motion/flashes, text size). Emulated only.
- **26 Audit.** Fixed a per-respawn connection leak (4 → 404 over 400 respawns, now constant); audio cycles drift 0; builder counts recorded. No profiler, listening or captures. Final table: 0 Verified, 40 Implemented — acceptance pending, 4 Blocked on production art.

## Follow-up 01 — verifier and Studio baseline (2026-10-21)
`tools/verify_all.sh`: 14 steps, adds backend/commercial/boss-encounter/audiovisual suites and source compile, builds to a temp place and never overwrites the saved one. Studio via `tools/studio_mcp.py`: the digest matched this checkout, server and client were ready, 0 game-script errors. These are seeded diagnostics, not play. See `outputs/claude-followup-2026-10-21/F01_BASELINE.md`.

## Lobby visual concepts (2026-10-21)
- Inspected the live Sanctuary in Studio and its source layout; captured the current arrival view. Created two reference-guided imagegen concepts in `outputs/lobby-concept-2026-10-21/`: entrance keyframe and elevated layout (both 1672×941), with the original reference, complete prompts and `DESIGN-BRIEF.md`.
- Direction: preserve the veiled ascetic/tree and main bonfire–stair–gateway axis; improve readable lighting, reflective basins, carved stone, coherent tiled cloisters, connected forge/duel approaches and layered terrace rockwork.
- Concept art only; no gameplay sources or saved place changed. Layout illustrations are aspirational, with exact descent placement, asset scale, traversal and performance to resolve during implementation. Next step: select the visual direction and translate it into a modular environment kit.
- Added `outputs/lobby-concept-2026-10-21/CLAUDE-LOBBY-REBUILD-PROMPT.md`: implementation prompt covering existing source ownership, modular Blender assets, persistent Studio/Rojo integration, Sanctuary-specific lighting and screenshot/play verification. Confirmed the local Blender executable is installed. Prompt preparation only; the rebuild has not started.

## Follow-up 02 — recovery loop (2026-10-21)
Studio diagnostic: all 8 altars wake correctly, and reclaim/forfeit work. Fixed: death note losing the spill line, region nil on respawn, and low-FPS camera-shake explosion (froze camera, hid prompts). Regressions were added. Real rejoin is still pending. See `outputs/claude-followup-2026-10-21/F02_RECOVERY.md`.

## Lobby rebuild — Shrine of the Ascendant (2026-10-21/22)
- New Blender kit (`tools/blender/lobby_kit*.py`, `lobby_textures.py`): 34 pieces / 47 MeshParts / 47k tris, 11 generated PBR sets; uploaded via Studio 3D Importer and persisted as `assets/models/AsuraLobbyKit.rbxmx` → `ServerStorage.AsuraLobbyKit` (`tools/assets/extract_lobby_kit.py`), plus 7 `MaterialService.Asura*` variants from the same maps (`register_lobby_kit.py`). IDs: `assets/LOBBY_KIT_UPLOADED.json`, `ASSET_IDS.md`.
- Sanctuary rebuilt by eleven ≤150-line builders (`SanctuaryKit/Rails/Frame/Props/Courtyard/Cloisters/Forge/DuelCourt/Ascent/Terrace/Horizon`); `SanctuaryService` keeps all gameplay. Statue/tree untouched. Stair width 18; forge walk opens onto the eaves ledge; duel court SE landing under the spectator stair; Well pavilion (+4 `WellColumn` route boxes).
- Golden-hour Sanctuary profile (17:30) and original uploaded sunset skybox (`make_sunset_sky.py`, `LOBBY_SKY_UPLOADED.json`), Sanctuary-only via `EnvironmentProfiles.skyFor`.
- Verified in Studio Play on the rebuilt place: boot clean, route walk, rest, Lin, Gao/Arsenal, portal → Monastery (its lighting intact), cloud catch. `verify_all.sh` passes. Before/after screenshots, measurements and the open list: `outputs/lobby-rebuild-2026-10-21/README.md`.
- Next: focused-window and device frame-time check (rail/lantern triangles are the first cut), start a duel, walk reliquary jumps/eaves ladder/crypt round trip, close-range art passes (banners, foliage, forge props).
- 2026-10-22 follow-up: walked the reliquary shards, eaves ladder (fixed: forge rail gap at the ladder) and crypt round trip. Fixed a pre-existing bug that blocked multi-client Studio tests: enemy entity ids started at −1 and collided with local test UserIds (now −1,000,000). The duel hasn't been re-run since the fix. The frame-time probe ran with Studio in the background (15 fps cap), so it gives no valid fps; render CPU was 3–6 ms. Details: `outputs/lobby-rebuild-2026-10-21/README.md`.

## Additional lobby references (2026-10-22)
- Created four imagegen detail references matching the original two concepts: courtyard materials/water, Gao's forge, statue terrace and duel court. Saved under `outputs/lobby-references-2026-10-22/` with an index and complete generation prompts.
- These illustrate the next close-range art pass on the already rebuilt lobby. They are concept art, not current Studio screenshots or measured plans; preserve tested routes and the existing statue/tree when using them. No source, asset library or saved place changes made by this reference task.

- 2026-10-24 F03b (Computer A): input/HUD acceptance pass. Hold-Alt cursor survives focus loss, modals and death; Lin/Bonfire prompt band isolated. Fixed: pad B now closes Lin/Codex, altar gets Backspace/B back, Lin's own arm no longer hides her Speak prompt. Place digest 584676947. Open: hardware/Alt-Tab (24), Twins/lock switching (10). Next: follow-up 04.

- 2026-10-24 F04–06 (Computer A): rest/Lin/leveling, Arsenal/Codex and six-sovereign forging verified in Studio (seeded diagnostic; awards via store). Fixed portrait framing, hat-in-shot, Bonfire travel checkpoint, silent summon refusal, slot font, footer clip, overlay stacking, script-path toasts. Digest 1783028740. Next: follow-up 07; earned rewards → 22.

- 2026-10-25 Batch B (07–09): fixed reach sweep, deathblow KO reward, AI chase/spacing, tutorial Evade/Light judging, handoff/controls/training/toast layout, Alt-labelled skip. 09 lighting partly checked: Titan/Wu arenas dark, Wu floor cast unidentified; audio cycle not run. Next: resume 09 at Sovereign Wu.
- 2026-10-25 Batch B 09 done (seeded Studio): bare duel floors lightened so Titan/Wu arenas read; spell bloom/flash honour Reduced flashes; six arenas readable in combat and phase 2; audio cycles back to baseline, 0 locked-Parent errors. Open: human combat fairness, listening (25), multiplayer (23). Next: prompt 10.
- 2026-10-25 Batch C (10–13): shared boss animation resolver (per look/phase/attack, honest status, imported-track binding); fixed phase-2 skin order, boss lunge/pounce/Twins overlap, Titan kneel height, Wyrm felled-in-flight fall, Gao portrait. Digest 1870254957. Open: production boss/cast art (Blocked), Gao seal prompt, flick lock switching, earned fights.
- 2026-10-25 Batch C follow-up: Transmutation Seal moved 10 studs to Gao's side so "Speak to Master Smith Gao" wins from the front (Studio, real Z holds); seal still opens the Arsenal beside itself. Digest 1334509767.
- 2026-10-28 fps cap pass 2: NVIDIA (global 144, no Studio limit), Roblox cap (now 240), FRM, focus, flags, hooks, power and project all ruled out. Studio idles ~0.5 cores while each frame waits ~40 ms to present. Next: user sets panel to 144 Hz (or NVIDIA vsync Off for Studio), rerun RegionFrameTime.
- 2026-10-28 fps cap: 144 Hz panel didn't change it (Play 24.0, Edit ~12-18 evenly paced), and it isn't the MCP tools. Next: NVIDIA vsync Off for Studio, or Studio on the Intel GPU, then rerun RegionFrameTime.
- 2026-10-28 fps cap: NVIDIA vsync Off + Studio restart changed nothing (Play 24.0, Edit 18 evenly paced). Next: run Studio on the Intel GPU (Windows Graphics settings), re-measure.
- 2026-10-28 fps cap found: the RTX-render/Intel-display hand-off. Studio on the Intel GPU: Edit 220 fps, Play 44-47 (was 18/24). Next: laptop GPU mode set to discrete (Vantage/Legion Space, reboot), Studio back to default GPU, rerun RegionFrameTime.

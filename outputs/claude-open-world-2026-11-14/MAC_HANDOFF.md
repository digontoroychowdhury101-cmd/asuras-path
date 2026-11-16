# Mac handoff — continue Windows work, 17 November 2026

## Current resume point

**Use this handoff for the return to Mac.** It supersedes this file's older version-6 instructions and the preceding Mac-to-Windows resume identity. WINDOWS_HANDOFF.md remains historical evidence of that earlier transfer. Use the newest recorded source and cloud state below.

Windows reached **2d4b1ed**, with runtime source through **78662d6**. The real-mesh forest slice is implemented and captured, but **M2 is not integrated into Roblox**. The quota stopped immediately after the Opus lead's final report, before Fable's slice verdict. A completed task notification or green verifier does not establish art acceptance.

**First useful Mac task:** preserve local work, safely update Git, verify the candidate and connections, then review the seven real-mesh images and diagnose far-tree textures. Continue the canopy/visual fixes and outstanding checks from that state. The lantern upload is solved. Reuse already-uploaded assets rather than uploading them again.

| State | Exact identity | Meaning |
|---|---|---|
| Code branch | ux/onboarding-overhaul; Windows source/evidence HEAD **2d4b1ed827d94e5eff7d62ca8e74551cd153a121** | This delivery adds handoff documents and the verified build above that commit; preserve newer coordinated work |
| New local M2 candidate | places/checkpoints/AsurasPath_OpenWorld_WindowsHandoff_2026-11-17.rbxlx | **281 scripts / 3254714 source bytes / digest 1882323309**, still visually defective |
| Candidate SHA-256 | **5584b95dee2f49797309c22d0028e6ba603a2610822f36f7c1757d19757b295f** | 10,793,680 bytes; adjacent JSON also records identity |
| Shared cloud Development | place **118614906972571**, universe **10777041159**, private, Team Create | Last independently reopened on Windows: **version 9**, **277 / 3173417 / 786797912**, matching M1 source **3465430923161d9621ba50ccef53aebf352a78df** |
| Older places | canonical places/AsurasPath.rbxlx, .rbxl, outputs/AsurasPath.rbxlx and earlier dated recoveries | Preserved baselines/history; a modified date or similar title does not identify current source |

**Candidate and cloud deliberately differ.** Open a COPY of the new candidate under work/mac-resume-2026-11-17/ for temporary tests; require persistedToCloud=false and its expected source digest. Open the existing Development experience from Roblox separately for read-only identity checks, approved uploads or deliberate integration. Require persistedToCloud=true and the exact place/universe IDs. Never run temporary sync-and-restore tests against Team Create.

## What this handoff actually checked

Codex read all **112 user/assistant text records** in the main Windows Claude conversation, including task reports and compaction history, then the final Opus report, current continuation, relevant Windows worker notes, original 285-line world brief, setup/asset records and affected registry/loader mappings. Raw transcripts remain local on Windows; private chat dumps and credentials are not being committed.

Current captures 01, 05 and 07 were independently inspected: tower visible, open sky/ground dominates the forest view, glossy distant foliage is conspicuous, and pavilion/cart geometry is very dark. This is recorded-image inspection, not a fresh Studio run or a Fable acceptance ruling.

Fresh Codex verification at the source HEAD:

- Full **bash tools/verify_all.sh: 14/14, exit 0**; all source scripts compiled and the temporary place built. Biome dressing **19045/0**, slice dressing **1347/0**, weather composition **247/0**. Log: [MAC_2026-11-17_VERIFY_ALL.log](handoff/MAC_2026-11-17_VERIFY_ALL.log).
- The new dated candidate is a byte-identical copy of that temporary verification build. Its independently computed source digest is **281 / 3254714 / 1882323309**, matching the final Windows build.
- Asset restore dry run: **1277 same / 0 add / 0 DIFFERENT**, with archive/manifest/content verification. Log: [MAC_2026-11-17_ASSET_RESTORE.log](handoff/MAC_2026-11-17_ASSET_RESTORE.log). The three extras are already-tracked lantern diagnostic GLB/FBX files; no new raw-asset snapshot is needed.
- Studio MCP returned **no connected instances**. Native process check found no Studio, Blender, Luau or Rojo job before verification. Memory: **16.15 / 26.72 GB committed**, **5.43 GB physical free**. No unsaved Studio scene was recovered/discarded by this handoff. The latest worker had already stopped Play and closed its disposable copy.
- This handoff changes documentation/delivery artifacts only. No gameplay code, cloud DataModel, account/settings, asset permissions or public release changed. No new Studio, multiplayer, audio audition or device result is claimed.

## Windows milestones to retain

| Commit | Delivered change | Evidence and limits |
|---|---|---|
| ecb202e W1 | Dust sprite, steeper summit stairs, recovered weather/stair/QA changes, successful lantern registration | Full verifier 14/14. Build 277 / 3175399 / 1146079001. Later solo local pass covered lobby, shrine, glade, encounter, map and forced rain |
| 09655e5 W2 | Reduced effects respected; soft snow sprite/stronger dust; all-region stair footing; biome test in verifier; named Lune tests no longer silently skipped | Weather 247/0, biome 19045/0. Some impossible stair flights intentionally dropped; route usability still needs engine walking |
| 6d427d3 W3 | Batch of 105 further upload registrations; far landmark silhouettes and client toggle; Shen QA positioning work | Full verifier 14/14; far-toggle 13/0. Automatic/low-quality landmark rendering unproved |
| 7556cbf W4 | Registry generator/validator; four mapped registry modules and merged slice registry | Slice 1344/0. Missing multi-sub-mesh centres fixed next |
| 78662d6 W5 | 186 importer centres; runtime MeshParts cloned from cached uploaded models | Slice 1347/0; build **281 / 3254714 / 1882323309**. Replaces forbidden runtime SurfaceAppearance map writes |
| 2d4b1ed W6 | Seven real-mesh review captures and detailed findings | 60/60 cells, 2597 real MeshParts, zero placeholders; major visual/performance defects remain; M2 held |

Read relevant workers/win-01-... through win-16-... notes when entering a lane. They are chronological: an old BLOCKER/PENDING can precede a later success. Current mappings and the final report outrank intermediate outcomes.

## First blockers and exact next work

### Real-mesh forest and far-tree textures

Seven review images under captures/win/:

1. slice_real_01_glade_arrival.jpg
2. slice_real_02_road_lanterns.jpg
3. slice_real_03_understory.jpg
4. slice_real_04_broken_tower.jpg
5. slice_real_05_pavilion_lane.jpg
6. slice_real_06_terrace_stair.jpg
7. slice_real_07_tower_from_glade.jpg

workers/win-16-slice-captures.md records clear weather around 11:54, eye 5 studs above ground, build of 78662d6. The worker checked script count/bytes but **did not recompute the third digest in that Studio session**. The delivered file now has a full recomputed digest; do not retroactively claim that extra proof for old captures.

Recorded: 60/60 cells, 2597 real MeshParts, no placeholders, slice build **46.0 s**, all terrain **125.5 s**. Tower visible in 01/07. Worker canopy method: 60 azimuths × 4 elevations, 150-stud rays, CanQuery forced on only in the Play copy. Results 01–07: **0%, 18%, 10%, 12%, 12%, 7%, 0%**. This is a worker-created diagnostic, not a previously agreed acceptance metric. The required closed-canopy wilderness is still absent.

All **234 placed far-tree sub-meshes** were reported with failed textures, glossy lime discs; nearest only **156 studs** from arrival. Console: **122** “No asset content representation found while do_not_fallback_to_baseline is set to true.” lines across **24 unique IDs**. Separately: 19 rbxassethash local-file/no-universe warnings, known type mismatch **203785492**, initial PerfBudget Heartbeat **19.1 Hz** warning. Do not conflate these classes or assume a local-universe warning diagnoses the far textures.

Other defects: near-black pavilion roof, dark box by cart, translucent sheet at left of 06, dark shed roof at left of 07. Reproduce in current local source and correct assets/materials/placement without broadly altering protected lobby lighting.

**Next:** Fable reviews consolidated images and directs the visual fixes. Opus assigns bounded one-far-tree diagnosis: compare uploaded near/far models, returned MeshPart TextureID/SurfaceAppearance content, source import and actual available ownership/moderation/read permissions. The far registry has empty SurfaceAppearance maps; the service clones the uploaded template. Inventing map strings in generated Luau cannot repair missing imported content. Establish the cause before re-uploading. If replacement is necessary, register only real returned IDs and regenerate validated modules; do not duplicate unaffected uploads.

Close canopy gaps while preserving tower sightline, route/combat/camera clearance and measured budgets. Raising test budgets or adding expensive trees is not proof. Retake comparable views and record remaining content-load failures. **M2 remains held for the outstanding slice verdict and verified fixes; this handoff does not accept its defects.** W1-alone fallback was for stalled uploads; uploads succeeded, so that fallback is not automatically the next action.

### Runtime model loader and registries

src/server/Services/SliceDressingService.luau loads each registered model once using server InsertService:LoadAsset, caches the detached model, finds MeshParts by MeshId (name fallback), and clones the already-textured template. LoadModel(assetId) is its test seam. SliceDressing.Registry merges SliceKitRegistry, BellwoodKitRegistry, BellwoodFarKitRegistry and HeroKitRegistry, all mapped in default.project.json. tools/assets/kit_registry.py generates modules from manifests and real upload/readback JSON.

Previous ColorMap/ColorMapContent writes in Play failed “lacking capability Plugin”, skipping 44/60 cells. Preserve the clone-based fix and existing interfaces. Final local Studio proved real meshes build; **intended experience-owner loading in a live/private server is unproved**. Verify access and actual model/texture loading through approved narrowly scoped methods before acceptance. Check cache/lifetime behavior through normal Start/Destroy/streaming paths.

### Uploads and audio

Current registries contain **101 models + 5 audio IDs**: first lantern, then **105 further uploads**. This resolves the final report's “105” count.

| Registry under assets/ | Count |
|---|---:|
| SLICE_KIT_UPLOADED.json | 16 models, including lantern **106633407703784** |
| BELLWOOD_KIT_UPLOADED.json | 74: built A 31, built B 16, vegetation 27 |
| BELLWOOD_FAR_KIT_UPLOADED.json | 6 far trees |
| HERO_KIT_UPLOADED.json | 5 hero models |
| OVERWORLD_AUDIO_UPLOADED.json | 5 beds, **Reviewing at upload**, current status unverified |

Audio: Amberfall **129806106031158**; Ashen Stair **93963168737720**; Bellwood day **105210588065430**; Frostmere **89969995114537**; Saltreach R2 **123518992828989**. No audition or game-mix integration yet. Recheck moderation/access, test in intended experience, audition and integrate through existing sound owners with shelter/comfort/crossfade/cleanup. Do not regenerate completed ElevenLabs sources or assume moderation cleared.

Creator approved these task mesh/texture/audio uploads. Local Windows windows refused scope; cloud connection handled **upload calls only**, without DataModel edits/Play/save. Mac permissions/auth do not travel in Git. Use supported user flows for actual missing platform approval; the prompt cannot supply credentials.

Lantern isPublished=true investigation: public details IsForSale=false, IsPublicDomain=false, ProductId=0, creator **3148600636**. Authenticated Asset API read was refused (asset:read not granted). Those fields indicate no sale/free distribution, **not a complete ACL audit**. No settings changed. Later biome packs already exist (Amberfall 45, Saltreach 37, Frostmere 32, Ashen Stair 34) but are not all uploaded/integrated. Reuse them after the slice quality gate.

### Outstanding engine and multiplayer checks

- **Landmarks:** six source silhouettes (five regional plus SummitTemple), OverworldLandmarkFar tag, FarBeyond=700, persistent/no collision/shadow. LandscapeBudget has 15-stud hysteresis and lobby hiding. Automatic/low-quality proof is missing. Builder source assertion can SKIP under plain Luau; green aggregate output is not proof it ran. Complete completed-terrain all-region distance/quality captures. Do not force maximum graphics.
- **Weather/stairs:** W2 source fixes need engine checks of Reduced effects, snow/dust, retained wind/shelter behavior and necessary stair routes after flights were dropped. Shelter is ALREADY detected and passed to composition; mac-13's “no caller” was incorrect.
- **Shen:** best previous run **35 checks / 1 failed**, BOTH-INSIDE only B enrolled. win-10 traced a plausible harness Position-event issue; win-12 corrected both teleports, retries/asserts and diagnostics. Compiles but **unrerun**. The cause is inferred, not proved. Inspect every check and failed count; passed=true means xpcall completed. Occupied refusal/BossFelled re-entry passed. A-dies/B-continues remains weak evidence while A never enrolled.
- **Terrain-priority multiplayer:** compiled, never run. Follow mac-04-multiclient-pending.md, win-05-multiclient.md and current tools/qa harnesses. Distinguish intentional guard-rescue scenarios from unhandled failures.
- **Other acceptance:** live east/west/north-wrap compass turns; small-screen map follow/label overlap; severe-weather combat readability; normal-entry fresh/older profiles; actual roofed caves; lift-map links; repeated effect/audio lifetime counts; audio audition and device workloads. win-06-acceptance.md is an inventory. Its named-test/verifier concern is incomplete: verifier invokes Lune suite discovery; inspect runner before asserting missing coverage.

### Performance and resource rule

Quiet Windows W1: Level21, viewport 1736×824. Clear mean/p95 **60.42/73.87 ms**, rain **66.93/92.77 ms**, encounter **64.20/78.88 ms**; render CPU ~43–44 ms, GPU ~1–1.5 ms; ~3354 MB. Glade/altars/map **18.33/27.69/218.26 s**; terrain 99.6 MB; heartbeat 35.6–53 Hz writing, ~61 afterward. See win-07-solo-pass.md.

Real-mesh slice: 350 frames, view 01, mean **57.2 ms**, p95 **61.1 ms**, max 66.9 ms, ~**3858 MB**. These are **single-machine Studio diagnostics**, not device passes. Earlier concurrent-window FPS is not comparable. Windows 125–218 s and Mac M1 14 s differ in code/workload/warnings; retain their circumstances before comparing.

Binding latest rule: **Fable oversight → one Opus engineering lead → at most TWO active Sonnet/Haiku workers**. **One heavy job machine-wide**: Studio Play, multiplayer, Blender, full verify or build. Second worker can do light reading/source work. Record committed/limit and free physical memory before heavy launch and after teardown. Preserve unsaved work before closing finished instances. Clean only obsolete task-owned polling/local servers; never blanket-kill processes.

This supersedes old 4–6/6–8 parallel preferences. Keep ECC enabled. Windows logs had VirtualAlloc failures, Node out-of-memory, failed process launches and error 1455. Increasing hook timeout alone does not fix memory exhaustion. Retry skipped checks unloaded with original/retry outcomes retained. Measure receiving Mac resources rather than assuming Windows hardware.

## Roles, skills and verified routing

**Fable is the overall lead** in the main chat, providing creative/acceptance direction sparingly. Opus 5.5 is its delegated engineering lead managing daily implementation/review/integration. Sonnet handles bounded implementation; Haiku bounded reading. Do not let Fable absorb routine engineering or silently inherit it for workers.

Latest Windows runtime evidence verifies **17 agents: 1 Opus, 15 Sonnet, 1 Haiku**, every requested tier matched, main session Fable 5.2. [Routing evidence](handoff/MAC_2026-11-17_MODEL_ROUTING.json) records requested/observed models. Old IDs are history, not Mac workers. Start one fresh Opus lead from durable notes, use useful bounded startup tasks to check worker routing, and record actual models/fallbacks. Agent labels or self-reports are insufficient.

Use one ECC task workflow, Ponytail **full**, relevant Matt Pocock spec/ticket/TDD/review/handoff skills, and project-local ro-engineer. Reuse existing approved spec/tickets rather than another plan interview or competing orchestrator. Combine reviews, keep contexts small, assign exclusive files, checkpoint after meaningful edits/exports/results.

## Receiving Mac setup and transfer

1. **Preserve first.** Inspect branch/status/stashes and open Studio scenes. Fetch origin; safely use git pull --ff-only origin ux/onboarding-overhaul. One computer writes the branch. No reset/clean/blanket stage. Prior Mac unrelated ShenHandoff files/stash remain protected. iCloud conflict copies were seen: never clean .git or substitute index 2/3; inspect and prefer a separate nonsynced checkout if needed.
2. Confirm history includes **2d4b1ed and this handoff**, verify candidate SHA, and work on a local copy under work/mac-resume-2026-11-17/. Future source builds go there. Preserve baselines/recoveries. Compare tools/studio_mcp.py --digest with tools/qa/SourceDigest.luau in local Edit. Reconcile newer legitimate work rather than restoring an old checkpoint.
3. Restore missing raw assets WITHOUT merging the data branch:

       git fetch origin codex/overworld-assets-2026-11-16:refs/remotes/origin/codex/overworld-assets-2026-11-16
       git rev-parse origin/codex/overworld-assets-2026-11-16
       python3 tools/assets/overworld_handoff.py restore
       python3 tools/assets/overworld_handoff.py restore --apply

   Immutable data commit **1412139fbb6c9adc519031a5d02063c7a952732c**. Dry-run first; apply creates missing only, preserves differing files and reports conflicts. BUNDLE.json/ASSET_MANIFEST.json pin 1277 files/609 contents, archive **1,231,545,662 bytes**, restored source **2,216,435,383 bytes**. Twenty .blend1 backups excluded. Three lantern diagnostics travel in source Git. Matching files need no restore/regeneration.
4. **Check existing tools before installing.** docs/BUILD.md + tools/toolchain.env pin **Luau 0.742 / Rojo 7.7.1**. Need Python 3, Node (ECC >=18), Git; Windows used Blender **5.2.2**. Put native Mac executables in documented work/bin locations/PATH and chmod as needed; do not run Windows exe files. Local shim needs no separate Lune. Blender uses its bundled Python; uv supports Blender MCP. Reuse existing functioning installs/logins. No remote Mac setup is claimed.
5. **Pinned plugin repositories:**

   | Plugin | Version | Source revision |
   |---|---|---|
   | ecc@ecc | 2.2.3 | affaan-m/ECC — **d2ef2680594f9a17526a6e1a2e18b3d242c5d17b** |
   | ponytail@ponytail | 5.3.3 | DietrichGebert/ponytail — **96608e078b2d5ea607c5c3b8b5a54d1c1fba6846** |
   | Matt Pocock | 1.3.1 | mattpocock/skills — **49dd158d1076134a641b33efb035946536778336** |

   If missing, clone each under separate work/setup/ directories and check out the recorded revision; preserve existing clones. Use supported claude plugin marketplace add <absolute-local-clone>, then install ecc@ecc, ponytail@ponytail and Matt from its pinned marketplace. Matt's local marketplace is mattpocock: **mattpocock-skills@mattpocock**; Windows used the official marketplace. Install ONCE via either source. Discover actual names/read chosen SKILL.md references. Do not duplicate plugin hook entries in settings.
6. **MCP connections:** Studio launcher is python3 tools/run_studiomcp.py; discovers /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP. Missing CLI registration from checkout:

       claude mcp add --scope local --transport stdio roblox-studio -- python3 "$PWD/tools/run_studiomcp.py"

   Verify /mcp and python3 tools/studio_mcp.py --list; config alone is not connection proof. Blender uses mcp-for-blender package/add-on (uvx mcp-for-blender install-addon, enable add-on, supported local stdio registration). Avoid duplicate servers. Reuse ElevenLabs; Hyper3D Rodin/Forge GUI remain optional under original quality rules. Reuse completed Blender/audio assets. Animator plugin is optional; exact asset/version was not independently inventoried.
7. **Not transferred:** logins/keys, .mcp.json/.claude.json, permission approvals, unsaved scenes and old agent processes. Use machine-local supported authentication. Never commit credential stores. Check receiving upload-folder approval only when a genuinely necessary upload is blocked.

## Deliberate cloud integration later

Last cloud M1: **277 / 3173417 / 786797912**, cold-reopened on Windows in win-04-cloud-upload.md. Older “v9 not cold reopened” statements are superseded by that Windows result. Codex did not reopen cloud again during this handoff. Read actual current state before writing and preserve newer coordinated work.

ProtectedDigest.luau **v1** reference: lobby **129 / 1095707166**, AsuraAssets **1443 / 468385596**, MaterialService **13 / 1586257287**. Includes sibling order: run twice/investigate differences. Counts alone are not property proof. Original Windows migration used another algorithm; do not compare incompatible numbers.

After review/fixes, local suites and solo integrated Studio checks meet the gate, use one operator. Inspect exact current source guards before applying only verified mapped changes/additions. Preserve Actor/Worker mappings, lobby/assets/materials and legitimate Studio-only edits. Team Create edits already persist; never upload a temporary variant intending to restore it. Compare complete source/protected fingerprints, save to Roblox through supported tools/UI, cold-reopen and record actual version/source/readback. Missing save capability must be reported, not claimed. Preserve private visibility; no public-release/security-setting/account/monetisation/paid-generation authorization is supplied.

The preceding Fable ruling places multiplayer reruns **after M2**, not as a gate for the old Shen harness failure (Shen code already M1). Preserve that order; isolate any newly demonstrated gameplay/data-safety defect appropriately. Pending slice acceptance is a separate gate. Continue independent local work during dependent provider/cloud restrictions.

## Original scope and remaining acceptance

Read CLAUDE_OPEN_WORLD_PROMPT.md, GEOGRAPHY_PLAN.md, existing spec/tickets and relevant inventories. Approved 8400×8400 geography, X -10000..-1600, Z -9200..-800: Bellwood forest/jungle/bamboo SE; Amberfall golden ravine west; Saltreach dry basin farther west; Frostmere snowfields north; Ashen Stair mountain expedition NW.

Preserve separate Sanctuary lobby/shrine/forge/social/duels, combat/movement/progression, persistent IDs and migration/reward safety. Keep ONE active Shen barrier/domain (GrandmasterShen, Gate_AshColosseum). M-toggle truthful map and top compass/degrees remain required. The first slice does not complete five substantial biomes. Finish routes/discoveries/alternate paths, mountain hardships/runbacks, full dressing, weather/shelter/wind/audio, caves/lifts, progression and evidence through existing architecture.

Endings stay deferred with archived bosses; earned flags survive. Retired source and unrelated SolarForms/PresentationAudit remain creator cleanup decisions, not broad deletion authority. Reference archive under outputs/hero-grand-soul-review-2026-11-09/ is partial: six hours of active play, exhaustive coverage and completed snow traversal were **not established**. Preserve evidence limits while fulfilling the requested original snow region and world direction.

## Before the next limit or transfer

Checkpoint/finish workers, record pending work/active jobs, verify, commit only explicit task paths and push milestones before limits. Fetch/reconcile without force; compare local/remote SHAs. Update continuation, routing, source/build identity, asset IDs, captures, cloud save/reopen and gaps. Repack ignored assets as a **new immutable snapshot only if changed**. Avoid broad handoff scripts that overwrite baseline places/stage unrelated work.

The pre-existing DELEGATION_STATUS.md edit belongs to Fable; preserved and excluded from Codex's commit. The new routing summary delivers complete current-run facts to Mac. Unrelated untracked outputs/mugen-combat-review-2026-11-09/ stays local/excluded. No live Windows agent or automatic quota resumption was started by this handoff. Resume with fresh Mac agents from durable files.

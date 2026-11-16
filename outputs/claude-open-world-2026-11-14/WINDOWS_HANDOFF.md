# Windows handoff — Mac open-world checkpoint, 16 November 2026

**Historical Mac-to-Windows transfer.** For the newer Windows-to-Mac return on 17 November 2026, use
[MAC_HANDOFF.md](MAC_HANDOFF.md) and [handoff/MAC_RESUME_PROMPT.md](handoff/MAC_RESUME_PROMPT.md).
The candidate and upload/acceptance state below predate the later Windows W1–W6 work; keep them as history.

Read this before the older Mac handoff. The creator asked Codex to read Claude's entire open-world continuation chat, preserve and push its work, prepare this Windows handoff, and close every Roblox window after preserving edits. This is a development checkpoint. The world and its art have not passed final acceptance.

## 1. Which version to open

Repository: `https://github.com/digontoroychowdhury101-cmd/asuras-path.git`, branch **`ux/onboarding-overhaul`**. The delivery commit containing this document follows `5fc0f6e`; use the branch's actual remote HEAD rather than an older hash quoted in historical notes.

| Copy | Identity | Purpose |
|---|---|---|
| New source candidate | **277 scripts / 3174231 bytes / digest 1755809200** | M1 plus recovered round-2 source, locally verified; needs Windows Studio validation |
| Shared cloud Development place | **277 / 3173417 / 786797912**, runtime source `3465430` | Last verified M1 cloud content; latest save recorded as **version 9** |
| Older dated local checkpoint | 275 / 3149701 / 1516687798 | Original Windows checkpoint, predates M1 |
| Preserved canonical baseline | 286 / 2859366 / 462022588 | `places/AsurasPath.rbxlx` and `outputs/AsurasPath.rbxlx`; do not overwrite |

The new candidate is **`places/checkpoints/AsurasPath_OpenWorld_MacHandoff_2026-11-16.rbxlx`**. SHA-256:

`1e15bb0cb5855e5213a9855d9fb4da4a0a0b559813f64fbb9082fc637780c465`

The recovery copies under `places/checkpoints/mac-session-2026-11-16/` preserve the exact older open places. They are backups, not the current candidate. In particular, the recovered M1 test place retains older WorldService code and a different rain experiment. Its name does not mean it equals the committed M1 cloud build. See the [recovery manifest](../../places/checkpoints/mac-session-2026-11-16/MANIFEST.json).

Cloud target: **Asura's Path — Development**, place **118614906972571**, universe **10777041159**, private, Team Create. Confirm `persistedToCloud=true` before deliberate integration. Never temporarily sync and restore the old baseline there. Round 2 was **not integrated into the cloud** by this handoff.

## 2. Read first and recover on Windows

Only one computer writes the shared branch at a time. Preserve any Windows working-tree or unsaved Studio changes first. In PowerShell, from the existing checkout:

```powershell
git status --short
git fetch origin
git switch ux/onboarding-overhaul
git pull --ff-only origin ux/onboarding-overhaul
git rev-parse HEAD
git rev-parse origin/ux/onboarding-overhaul
Get-FileHash -Algorithm SHA256 -LiteralPath 'places/checkpoints/AsurasPath_OpenWorld_MacHandoff_2026-11-16.rbxlx'
New-Item -ItemType Directory -Force work/windows-resume | Out-Null
Copy-Item -LiteralPath 'places/checkpoints/AsurasPath_OpenWorld_MacHandoff_2026-11-16.rbxlx' -Destination 'work/windows-resume/AsurasPathTEST.rbxlx'
```

If switching or fast-forwarding fails, inspect the divergence; do not reset, clean, or discard local work. Read, in order: this file, the newest top section of `CONTINUATION.md`, `handoff/WINDOWS_RESUME_PROMPT.md`, `CLAUDE_OPEN_WORLD_PROMPT.md`, `LEDGER.md`, `GEOGRAPHY_PLAN.md`, and the relevant worker notes below. The older `MAC_HANDOFF.md` remains useful for setup and provenance; its version-6/current-terrain paragraphs are historical.

Open the **working copy** with Studio's File > Open from File. Confirm `persistedToCloud=false` and run `tools/qa/SourceDigest.luau` in Edit: expect **277 / 3174231 / 1755809200**. Runtime terrain and dressing appear during Play, not as a finished Edit scene. Keep QA scripts out of the normal source mapping.

Tool pins: Luau **0.742**, Rojo **7.7.1** (`tools/toolchain.env`); Blender **5.2.2 LTS** was used. Python and Git Bash are needed by the current verifier. Keep the Windows tools already configured; `tools/run_studiomcp.py` discovers the installed Studio MCP binary, and `tools/studiomcp_win.cmd` is the Windows wrapper. Inspect `docs/BUILD.md` before builds. Do not use broad `tools/handoff.cmd` staging or a default build that overwrites `outputs/AsurasPath.rbxlx`.

For a fresh Claude setup, the recorded plugin pins are ECC 2.2.3 (`d2ef2680594f9a17526a6e1a2e18b3d242c5d17b`), Ponytail 5.3.3 (`96608e078b2d5ea607c5c3b8b5a54d1c1fba6846`), and Matt Pocock Skills 1.3.1 (`49dd158d1076134a641b33efb035946536778336`). Upstreams and installation procedure are in `MAC_HANDOFF.md` section 3. Mac had Matt 1.3.2 installed, so workers read the pinned 1.3.1 checkout under `work/setup/mattpocock`. Authenticate receiving-machine connectors locally; no credentials or app configuration travel in Git.

## 3. Mesh/audio sources and the Mac additions

The unchanged base snapshot is **`codex/overworld-assets-2026-11-16`**, commit **`1412139fbb6c9adc519031a5d02063c7a952732c`**. It contains 1,277 files / 609 unique contents, approximately 1.23 GB compressed. Never check out or merge it into the code branch. In Git Bash, with `python3` available:

```sh
git fetch origin codex/overworld-assets-2026-11-16:refs/remotes/origin/codex/overworld-assets-2026-11-16
python3 tools/assets/overworld_handoff.py restore
python3 tools/assets/overworld_handoff.py restore --apply
python3 tools/test_overworld_handoff.py
bash tools/verify_all.sh
```

Restore checks all hashes and never overwrites a differing existing file. Inspect any `DIFFERENT` result before continuing. A Windows installation exposing Python as `python` can use that command for the restore commands; the Bash verifier itself calls `python3`.

Codex compared every base-snapshot file on this Mac: **all 1,277 match, none missing or changed**. The only new ignored overworld assets were the three lantern diagnostics below. They are explicitly tracked at their original paths in this delivery, so a normal code pull preserves them without another 1.23 GB snapshot. Their immutable supplement manifest is [handoff/MAC_DIAGNOSTIC_ASSETS.json](handoff/MAC_DIAGNOSTIC_ASSETS.json).

- `assets/source/overworld/upload/diag/Bell_Lantern_Post_A_notextures.glb`
- `assets/source/overworld/upload/diag/Bell_Lantern_Post_B_singleroot.glb`
- `assets/source/overworld/upload/diag/Bell_Lantern_Post_C.fbx`

These are unproven upload experiments, not successful Roblox assets. Keep the original-path upload permission boundary. Do not relocate files to bypass a Studio upload refusal. All five generated audio beds and the completed mesh kits are already in the base snapshot; do not regenerate them merely because a fresh checkout lacks ignored files.

## 4. What Claude actually did, beginning to end

Audit source: local session `e35b1c65-d031-4fc4-bafa-88f8c1f6954f`, starting **15:09 Sydney** and ending at the **16:42** quota-failure notification on 16 November. Codex read the conversation from the initial Windows-resume request through the final failed push request, reconciled worker records and durable notes, and reviewed the pending diff. Raw transcripts remain local because they contain account context and unrelated injected session material.

1. Recovered Windows `358e24f`, restored and hash-verified the 1,277 assets, passed the full verifier, and built a separate TEST place. The earlier Mac lead had exited after roughly two minutes, leaving a Studio-opening note and no source patch. Unrelated `ShenHandoff-2026-11-09/` and the pre-existing stash were preserved.
2. Started a fresh engineering lead, recorded routing, reconciled the incoming dated-checkpoint commit `fbb5894`, and pushed the resume notes as `de50f6f`.
3. Reconciled actual far-tree manifests in `32d448e`. FarDensity changed 0.6 to 0.4: 175 to 117 far trees, 218 trees total including 101 near trees. This fits the local triangle accounting but makes the distance forest sparser; real-mesh visual acceptance is still open. Windows then integrated this into cloud version 6 and pushed `2bbe176`; Mac fast-forwarded without losing its in-flight changes.
4. Built and pushed **M1 `3465430`**: terrain Actor workers, tight voxel writes, fallback and timing fixes, startup settling, corrected Shen walk-in gate bounds, Frostmere/Ashen/hero specifications and registry hooks, and `tools/assets/kit_registry.py` plus verifier coverage. Notes/cloud evidence followed in `98477b7` and `5fc0f6e`.
5. Integrated M1 deliberately into the shared cloud after checking version-6 source guards. A single-client cloud smoke generated the map in 14.6 s. Oversight matched the fresh build to cloud **277 / 3173417 / 786797912**, then used File > Save to Roblox. Latest cloud version recorded: **9**. This was a development save, not a public release.
6. Started six round-2 lanes. Source and notes below landed locally, but the lead and rain/visibility workers hit the quota limit before integration or final review. The user's final “push all changes” request was never executed by Claude.

### Round 2 recovered in this delivery

| Lane | Files / outcome | Remaining work |
|---|---|---|
| Rain | `WeatherController.luau`, weather test: 40×44×40 emitter volume centred 22 studs above the player; rain rate 540, lighter/brighter streaks; expected live cap remains 600 | Worker saved only `rain2_clear_into_wind.jpg`; no completed new-rain visual verdict, FPS/count measurement, or severe-weather/comfort comparison |
| Tower sightline | `SliceDressing.luau`: cone LowFrac .25→.03; test includes shelters and requires ≥90% visibility from both eyes; local geometry reports 100% | Placeholder/static result; recapture real meshes in Studio |
| Stair footing | `BiomeDressing.luau`: stairs face rising ground and sample at the low end; added footing regression | `SummitSteps_Stair_1` and `_2` remain about 7 and 4 studs buried at the high end; no new Studio stair pass |
| Far visibility | Seven `farvis_*_895.jpg` captures; landmark exists on client, Persistent; at 895 studs Level1/Automatic omit temple, Level2 tiny speck, Level3+ draw it | AutoFRMLevel was 1 at ~14.7 FPS; incomplete full distance/quality sweep; do not force maximum graphics as a fix |
| Cloud fingerprint | `tools/qa/ProtectedDigest.luau`, `workers/mac-14-cloud-v9.md` | Did **not** cold-reopen v9; loaded session still reported PlaceVersion 6. Version-list endpoint returned 404. Need independent reopen verification |
| Multiplayer | `ShenMultiClient.server/client.luau`, `TerrainPriorityMultiClient.server.luau`; launch notes appended to mac-04 | Compile-only; never run. Both participants inside Shen simultaneously and BossFelled re-entry remain uncovered |
| Acceptance | `workers/mac-13-acceptance-sweep.md` | Ten acceptance rows all incomplete/partial/pending; see correction below |

The protected digest's new baseline is lobby **129 / 1095707166**, asset library **1443 / 468385596**, materials **13 / 1586257287**. Its method differs from the unrecorded original Windows method. It includes sibling ordering; confirm repeatability and cross-machine ordering before treating it as a portable equality proof. Matching counts alone do not prove unchanged properties.

**Correction to mac-13:** shelter suppression is already connected in `WeatherController.Sample`: `sheltered(position)` raycasts tagged roofs and passes `Sheltered = covered` into `Profiles.compose`. Do not implement a duplicate path based on the reader's incorrect “no caller” finding. Roof/interior coverage, repeated transitions and audio behaviour still require Studio validation. Caves/interiors and lift-map links were deferred to round 3 and were not completed.

### Recorded performance evidence

Claude measured local M1: whole map **13.6–14.0 s**, glade **1.8 s**, all altars/arrivals **2.7 s**, server **50–61 Hz while writing**, terrain memory **97–98 MB**. An initial one-second **6.5–8.6 Hz** load dip remains. These are worker-recorded Studio measurements, not Codex reruns or device claims. The earlier 114-second baseline and these runs differ in code and warning load; retain the workload notes in `mac-11-studio-m1.md` when comparing.

## 5. Preservation and shutdown

At takeover, six Studio instances existed: two empty windows, local TEST and M1 in Play, local T4B in Edit, and cloud Development in Edit. Codex closed the empty windows, stopped both Play sessions, then preserved every open Edit place before graceful shutdown:

- TEST: Save to File As into `AsurasPathTEST_recovered.rbxlx`.
- M1 and T4B: copied their previous saved files, used Save to File on their **local work copies**, then copied the resulting places into `*_recovered.rbxlx`.
- Cloud: Download a Copy into `AsurasPathCloud_M1_recovered.rbxl`. This action also saved the existing cloud content to Roblox successfully at 16:54:26 Sydney (Studio log); no round-2 scripts were applied. No new cloud version number or cold-reopen result is asserted.

All are under `places/checkpoints/mac-session-2026-11-16/`, with SHA-256, XML source digests and candidate differences in `MANIFEST.json`. The binary cloud backup needs Studio to re-check its source digest. On shutdown Studio MCP returned no connected instances, and native process checks confirmed exit. No Roblox player app was in the initial app inventory. Unsaved runtime-only QA state was discarded by stopping Play; generated terrain, teleports, debug weather/cameras and seeded fights are diagnostics, not source edits.

## 6. Verification and exact next actions

**Codex static review:** inspected the pending patch, affected controllers/builders/callers/mappings, worker notes, source-vs-place differences, and asset hashes. No gameplay code was changed beyond preserving Claude's pending patch. Static review identified the shelter-sweep error and incomplete harness/visual claims above.

**Codex local regression:** `bash tools/verify_all.sh` passed **14/14** with a temporary build; log: [handoff/WINDOWS_HANDOFF_VERIFY_ALL.log](handoff/WINDOWS_HANDOFF_VERIFY_ALL.log). All four new QA Luau files compile. Saved canonical baseline files were preserved. New candidate identity: **277 / 3174231 / 1755809200**.

**Studio integration:** Claude's M1 evidence remains recorded in mac-11/mac-12. Codex performed preservation and read-only identity checks, not a new gameplay acceptance pass. Round 2 has no completed integrated Studio pass. **Multiplayer:** pending Windows. **Device profiling, human art acceptance, full audio audition and fresh/old-profile end-to-end acceptance:** pending.

Continue in this order:

1. Verify checkout, restore missing assets, run local checks, open the new **local candidate** and verify its digest. Cold-open the existing cloud separately and identify the latest contents; reconcile any newer coordinated work rather than overwriting it.
2. Finish local rain captures with the same camera/time, into/across wind, comfort setting, particle counts and frame-time measurements. The shared emitter-volume change also affects snow/dust; inspect them. Check lobby/shelter/respawn/streaming cleanup in repeated cycles.
3. Verify new stairs and tower sightline in Studio; fix the two steep summit stair flights with a reproduced test/capture. Complete five-region temple views and low-quality landmark readability evidence.
4. Diagnose the lantern with the original and B/A/C variants, one uploader, max four bounded attempts, one changed variable each. Windows had folder approval previously, but its only accepted operation ended in Unknown Error. Re-check current permissions and existing IDs; register only real successful IDs, then verify one mesh locally before batching kits/audio.
5. Run the other-computer multiplayer checks in mac-04 on **local copies only**. Each new harness's final `passed` field currently means its `xpcall` completed; inspect **`failed` and every check**, not just `passed`. Terrain PLACE_EARLY intentionally exercises a guard rescue that can fail its zero-rescue assertion; do not confuse that with an unhandled runtime error. Simultaneous Shen participants still need a separate scenario.
6. Resume remaining original acceptance: map follow/small-screen label overlap, north-wrap compass and weather combat readability, normal-entry fresh/older-profile progression, real roofed caves/lift links, repeated effect/audio lifetime counts, and device workloads. Creator decisions about deferred endings, retired source files, SolarForms and PresentationAudit remain open.
7. After focused local/Studio checks and full verification, commit/push the milestone, integrate **only verified changed scripts** into the existing private cloud with previous-source guards, compare source and protected collections, save, cold-reopen, record actual version and source commit. Never restore an old baseline into that shared place.

Routing evidence: the active Mac session contains **24 agent records: one Opus lead, 20 Sonnet workers, three Haiku readers**. All assistant model IDs match the requested tier; no fallback was observed. Final routing inventory is appended to `DELEGATION_STATUS.md`. These are historical Claude agents, not agents started by this Codex handoff. If continuing in Claude, use the originally requested hierarchy when available and record actual routing; do not silently substitute unavailable models.

The unrelated `ShenHandoff-2026-11-09/` directory and pre-existing stash remain local and excluded from this task's commit. No iCloud conflict index files were changed. Windows should use its own checkout and pull this delivery; GitHub delivery does not automatically install or open anything there.

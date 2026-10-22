# Asura's Path — current build and verification (21 October 2026)

Rojo project: `default.project.json` (project name `AsurasPath`; namespaces `ReplicatedStorage/AsurasPath`, `ServerScriptService/AsurasPath`, `StarterPlayer/StarterPlayerScripts/AsurasPath`, `ServerStorage/AsuraAssets`). Binaries: official Luau and Rojo 7.7.1 in `work/bin/luau` and `work/bin/rojo` (or on PATH).

| Task | Command | Notes |
|---|---|---|
| Full local verification | `bash tools/verify_all.sh` (or double-click `verify_all.command`) | 14 steps: every regression runner, `lune_compat.py --all` (all Lune suites under the local shim), backend, commercial, boss-encounter and audiovisual checks, `luau-compile` of every `src/` script, then a place build. Builds to `$TMPDIR/AsurasPath_verify.rbxlx` (override with `ASURA_BUILD_OUTPUT`); it never overwrites the saved place. |
| Build the saved place | `python3 tools/build.py` | Writes `outputs/AsurasPath.rbxlx`. This **overwrites** that file — save Studio-only edits elsewhere or copy them into source first. `--output PATH` builds anywhere else. Prints mapped-source count and the real number of distinct Roblox asset IDs referenced. |
| Live sync | `bash tools/start_sync.sh` (or `start_sync.command`) | `rojo serve` on port 34872; connect from Studio's Rojo plugin. |
| Studio probe | `python3 tools/studio_mcp.py --list` / `calls.json` | Stdio client for Studio's bundled `StudioMCP` proxy, for sessions without registered Studio tools. Open a build with `/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio -task EditFile -localPlaceFile PATH` (a `file://` protocol launch was observed to leave Studio idle on its start page). |
| Prove place identity | `python3 tools/studio_mcp.py --digest PLACE.rbxlx`, then run `tools/qa/SourceDigest.luau` in that Studio place (Command Bar or `execute_luau`, Edit) | Equal script count, bytes and digest = the open place holds exactly that build's scripts. |

The Phase 5 asset library `assets/models/AsuraAssets_Phase5.rbxmx` exists and is part of the normal build (`ServerStorage/AsuraAssets`). Do not remove its mapping to make a build pass.

The Shrine lobby kit `assets/models/AsuraLobbyKit.rbxmx` (`ServerStorage/AsuraLobbyKit`) and the `MaterialService.Asura*` variants are part of the build too. To change the kit: edit `tools/blender/lobby_kit*.py`, run Blender on `tools/blender/lobby_kit.py` (and `-- --batch nature`), import the GLB with Studio's 3D Importer, save an XML copy, run `tools/assets/extract_lobby_kit.py COPY.rbxlx` and then `tools/assets/register_lobby_kit.py`. Studio QA: `tools/qa/studio_sync.py` (script-only push), `tools/qa/lobby_capture.py shots` (fixed comparison cameras, during Play).

Evidence boundaries: the verifier is local regression / engine emulation (Lune shim, engine fakes, local mocks). It does not certify Studio physics, appearance, real or earned play, audio, hardware or live DataStore/cloud delivery. A Studio boot reached through the probe is a seeded Studio diagnostic, not real play. The original audit/acceptance ledgers live in `outputs/claude-followup-2026-10-21/` and `outputs/playthrough-2026-10-20/claude-prompts/`.

Legacy Cagebound tools still in `tools/` — `build_device.py`, `build_private_test.py`, `build_benchmark.py`, `build_studio_plugin.py`, `package_phase12.py`, `collect_phase12_evidence.py` — read or write `outputs/Cagebound-Phase12*.rbxlx` files this project no longer builds. `build_qa.py` and `validate_phase12.py` do not exist. Do not use them as current verification.

---

# Historical record — Cagebound Phases 3–12 (does not describe the current build)

The sections below are preserved for history only. File names, namespaces (`Cagebound`), output places, the Phase 12 validation runner, remote counts and DataStore statements are from the earlier Cagebound project and are not current instructions.

## Former Phase 12 summary

For Phase 12, use `python3 tools/build.py`, `python3 tools/build_qa.py 12`, `python3 tools/build_device.py`, `python3 tools/build_private_test.py` and `python3 tools/validate_phase12.py`. The normal build is `outputs/Cagebound-Phase12.rbxlx`; QA, device and isolated private-test variants are separate. The validation runner executes all regression suites, actual-service and actual-UI adapter tests, syntax compilation, pure-module analysis and serialized-place integrity checks. It does not claim Studio, cloud or hardware testing. See `docs/phase12/Private-Integration.md` before using the allowlisted private harness.

`src/server/ProfileStore.luau` and `MatchJournal.luau` are pure injected storage modules. The service-integration test runs the actual services with local engine adapters; it never sends DataStore or purchase requests. Live integration must use a separate private universe. Read `docs/phase12/Backend.md` and `outputs/Phase12-Validation.md` before enabling a release gate.

The historical notes below describe the original tools and earlier phases. Phase 12 has five RemoteEvents and live persistence outside Studio; old claims about no DataStore calls or three remotes do not describe the current build.

## Former local build and maintenance (Phase 3)

### Files

| Local source | Explorer location | Script type |
|---|---|---|
| `src/shared/Config.luau` | `ReplicatedStorage/Cagebound/Config` | ModuleScript |
| `src/shared/ArenaGeometry.luau` | `ReplicatedStorage/Cagebound/Shared/ArenaGeometry` | ModuleScript |
| `src/shared/ConfigValidator.luau` | `ReplicatedStorage/Cagebound/Shared/ConfigValidator` | ModuleScript |
| `src/server/EnvironmentService.luau` | `ServerScriptService/Cagebound/Services/EnvironmentService` | ModuleScript |
| `src/server/ArenaService.luau` | `ServerScriptService/Cagebound/Services/ArenaService` | ModuleScript |
| `src/server/Bootstrap.server.luau` | `ServerScriptService/Cagebound/Bootstrap` | Script |
| `src/client/Bootstrap.client.luau` | `StarterPlayer/StarterPlayerScripts/CageboundClient` | LocalScript |

`tools/RefreshPreview.luau` is a Studio Command Bar utility. It is not a runtime Script. `tools/export_scene.luau` and `tools/test_geometry.luau` run under the local Luau CLI. `tools/build.py` is a local Python build utility.

### Tools and rebuilding

This build used official **Luau 0.742** and **Rojo 7.7.1**, downloaded into `work/bin/luau` and `work/bin/rojo`. Nothing was installed system-wide. On another machine, download compatible binaries from [Luau releases](https://github.com/luau-lang/luau/releases) and [Rojo releases](https://github.com/rojo-rbx/rojo/releases); put them on PATH or in those directories. The source ZIP excludes downloaded binaries.

From the project root, run `python3 tools/build.py`. It executes the real Config/validator/geometry modules with Luau, serializes their output, generates `default.project.json`, then invokes Rojo to produce `outputs/Cagebound-Phase3.rbxlx`. No duplicated Python geometry implementation exists. The final XML step only assigns the editor camera reference.

The build overwrites the generated place and `default.project.json`. Save Studio-only edits under another filename or copy them back into source before rebuilding. Regenerate geometry whenever Config changes; directly running Rojo against an old generated JSON tree can bake an outdated editor preview even though Play rebuilds from the new Config.

Rojo's saved Lighting properties include legacy `Technology=Future` in addition to `LightingStyle=Realistic` and `PrioritizeLightingQuality=true`. This is a serialization compatibility measure: an omitted legacy property caused Studio 0.742 to migrate a generated place from Compatibility to Soft lighting. The corrected file was reopened successfully without that migration prompt. Ordinary runtime code does not assign Technology.

### Validation commands

Run `work/bin/luau/luau tools/test_geometry.luau` for geometry and invalid-configuration tests. Run `work/bin/luau/luau-analyze src/shared/Config.luau src/shared/ArenaGeometry.luau src/shared/ConfigValidator.luau tools/export_scene.luau tools/test_geometry.luau` for the pure modules' strict type check. Run `luau-compile` over each Luau source for syntax compilation.

Standalone Luau does not include Roblox's complete engine type environment. Passing the pure-module analyzer is not a claim that it type-checked Roblox APIs. The runtime modules were exercised in Roblox Studio; use Studio's Script Analysis for engine-aware diagnostics during further edits.

### Runtime ownership and cleanup

ArenaService constructs a new detached model, destroys it on build failure, and replaces only `Workspace/Cagebound/Arena` after construction succeeds. It never clears Workspace, Terrain, or unrelated scripts. EnvironmentService owns three named lighting effects and warns about conflicting extra lighting objects. Repeated calls update named effects rather than accumulating them.

Phase 3 creates three RemoteEvents: InputIntent, ActionIntent and StateSnapshots. CharacterService validates movement/action intent before updating its authoritative state. No DataStore calls exist. See outputs/Phase3-Start-Here.md for the expanded Explorer mapping and outputs/Phase3-Validation.md for test limits.

The arena allocates Instances at startup or an explicit preview refresh only. The static arena has no frame callbacks. Phase 3 adds one server Heartbeat simulation and one client render binding, bounded numeric buffers, and tracked input/network connections; no Instances are created per frame. Cosmetic rigs are created or removed on roster/session changes. Every decorative wire is anchored, noncolliding, nontouching, nonqueryable and does not cast shadows. Eight invisible walls provide consistent cage collision, and seven floor pieces form the mat. The black enclosure has no gameplay collision.

### Preview refresh

Stop Play. Open `tools/RefreshPreview.luau` in a text editor, copy the complete file, and paste it into Studio's Command Bar. The utility rebuilds the owned arena and applies the named settings. It clones the configuration and service modules temporarily to avoid stale `require` caches, then removes the clones. Save the place afterward. This is useful when editing Config inside Studio; normal Play already rebuilds the arena automatically.

### Scope and remaining verification

The source supplies an arena foundation, not final technical art or a network combat controller. Chain-link uses simple cylinders rather than an interwoven production mesh. Concrete is a rough asset-free mat surrogate. Four shadow-casting spotlights and 362 parts need actual mobile/console profiling before any performance guarantee. The Phase 3 calibration mannequins are not finished character assets. The production skinned fighter uses the Phase 0 rig contract; see docs/phase2/Assets.md.

No public game was published and no account, asset, or purchase settings were changed. DataStore, exploit, matchmaking and animation tests become meaningful when those features are implemented.

### Phase 3 checks and source additions

Run `work/bin/luau/luau tools/test_phase2.luau` in addition to the geometry test. Include `src/simulation/MovementRules.luau`, `src/simulation/InputBuffer.luau`, `src/infrastructure/IntentProtocol.luau` and `tools/test_phase2.luau` in the pure-module Luau analysis command. Syntax-compile every file in src/ and every Luau utility in tools/.

The build maps src/simulation to ReplicatedStorage/Cagebound/Simulation, IntentProtocol to ReplicatedStorage/Cagebound/Shared, CalibrationRig to ReplicatedStorage/Cagebound/Presentation, CharacterService to server Services, and src/client/Controllers to StarterPlayerScripts/Cagebound/Controllers. Players.CharacterAutoLoads is false in the saved place and at server startup. Server roots are anchored Parts; there is no default Humanoid movement or physics ownership to trust.

Runtime action protocol: exact top-level keys version, session, seq, action, variant, body, grapple, pressed. Movement packets contain version, session, frames; each frame has seq, x, z, yaw, guard. Yaw is finite and wrapped to ±pi; axes are finite and have combined length at most one. The server applies body turn limits itself. Guard is also included in continuous movement intent so a missed release action cannot leave the remote pose held.

Session GUIDs distinguish actor lifetimes, not secrets or authentication credentials. Player identity comes only from OnServerEvent's Player argument. Client-provided positions, damage, victims, animation markers and time deltas are absent. The current gateway is an input/movement gateway; later combat eligibility must be applied before accepting attacks.

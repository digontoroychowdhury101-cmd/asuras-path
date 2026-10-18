# Current build and validation

For Phase 12, use `python3 tools/build.py`, `python3 tools/build_qa.py 12`, `python3 tools/build_device.py`, `python3 tools/build_private_test.py` and `python3 tools/validate_phase12.py`. The normal build is `outputs/Cagebound-Phase12.rbxlx`; QA, device and isolated private-test variants are separate. The validation runner executes all regression suites, actual-service and actual-UI adapter tests, syntax compilation, pure-module analysis and serialized-place integrity checks. It does not claim Studio, cloud or hardware testing. See `docs/phase12/Private-Integration.md` before using the allowlisted private harness.

`src/server/ProfileStore.luau` and `MatchJournal.luau` are pure injected storage modules. The service-integration test runs the actual services with local engine adapters; it never sends DataStore or purchase requests. Live integration must use a separate private universe. Read `docs/phase12/Backend.md` and `outputs/Phase12-Validation.md` before enabling a release gate.

The historical notes below describe the original tools and earlier phases. Phase 12 has five RemoteEvents and live persistence outside Studio; old claims about no DataStore calls or three remotes do not describe the current build.

# Local build and maintenance

## Files

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

## Tools and rebuilding

This build used official **Luau 0.742** and **Rojo 7.7.1**, downloaded into `work/bin/luau` and `work/bin/rojo`. Nothing was installed system-wide. On another machine, download compatible binaries from [Luau releases](https://github.com/luau-lang/luau/releases) and [Rojo releases](https://github.com/rojo-rbx/rojo/releases); put them on PATH or in those directories. The source ZIP excludes downloaded binaries.

From the project root, run `python3 tools/build.py`. It executes the real Config/validator/geometry modules with Luau, serializes their output, generates `default.project.json`, then invokes Rojo to produce `outputs/Cagebound-Phase3.rbxlx`. No duplicated Python geometry implementation exists. The final XML step only assigns the editor camera reference.

The build overwrites the generated place and `default.project.json`. Save Studio-only edits under another filename or copy them back into source before rebuilding. Regenerate geometry whenever Config changes; directly running Rojo against an old generated JSON tree can bake an outdated editor preview even though Play rebuilds from the new Config.

Rojo's saved Lighting properties include legacy `Technology=Future` in addition to `LightingStyle=Realistic` and `PrioritizeLightingQuality=true`. This is a serialization compatibility measure: an omitted legacy property caused Studio 0.742 to migrate a generated place from Compatibility to Soft lighting. The corrected file was reopened successfully without that migration prompt. Ordinary runtime code does not assign Technology.

## Validation commands

Run `work/bin/luau/luau tools/test_geometry.luau` for geometry and invalid-configuration tests. Run `work/bin/luau/luau-analyze src/shared/Config.luau src/shared/ArenaGeometry.luau src/shared/ConfigValidator.luau tools/export_scene.luau tools/test_geometry.luau` for the pure modules' strict type check. Run `luau-compile` over each Luau source for syntax compilation.

Standalone Luau does not include Roblox's complete engine type environment. Passing the pure-module analyzer is not a claim that it type-checked Roblox APIs. The runtime modules were exercised in Roblox Studio; use Studio's Script Analysis for engine-aware diagnostics during further edits.

## Runtime ownership and cleanup

ArenaService constructs a new detached model, destroys it on build failure, and replaces only `Workspace/Cagebound/Arena` after construction succeeds. It never clears Workspace, Terrain, or unrelated scripts. EnvironmentService owns three named lighting effects and warns about conflicting extra lighting objects. Repeated calls update named effects rather than accumulating them.

Phase 3 creates three RemoteEvents: InputIntent, ActionIntent and StateSnapshots. CharacterService validates movement/action intent before updating its authoritative state. No DataStore calls exist. See outputs/Phase3-Start-Here.md for the expanded Explorer mapping and outputs/Phase3-Validation.md for test limits.

The arena allocates Instances at startup or an explicit preview refresh only. The static arena has no frame callbacks. Phase 3 adds one server Heartbeat simulation and one client render binding, bounded numeric buffers, and tracked input/network connections; no Instances are created per frame. Cosmetic rigs are created or removed on roster/session changes. Every decorative wire is anchored, noncolliding, nontouching, nonqueryable and does not cast shadows. Eight invisible walls provide consistent cage collision, and seven floor pieces form the mat. The black enclosure has no gameplay collision.

## Preview refresh

Stop Play. Open `tools/RefreshPreview.luau` in a text editor, copy the complete file, and paste it into Studio's Command Bar. The utility rebuilds the owned arena and applies the named settings. It clones the configuration and service modules temporarily to avoid stale `require` caches, then removes the clones. Save the place afterward. This is useful when editing Config inside Studio; normal Play already rebuilds the arena automatically.

## Scope and remaining verification

The source supplies an arena foundation, not final technical art or a network combat controller. Chain-link uses simple cylinders rather than an interwoven production mesh. Concrete is a rough asset-free mat surrogate. Four shadow-casting spotlights and 362 parts need actual mobile/console profiling before any performance guarantee. The Phase 3 calibration mannequins are not finished character assets. The production skinned fighter uses the Phase 0 rig contract; see docs/phase2/Assets.md.

No public game was published and no account, asset, or purchase settings were changed. DataStore, exploit, matchmaking and animation tests become meaningful when those features are implemented.

## Phase 3 checks and source additions

Run `work/bin/luau/luau tools/test_phase2.luau` in addition to the geometry test. Include `src/simulation/MovementRules.luau`, `src/simulation/InputBuffer.luau`, `src/infrastructure/IntentProtocol.luau` and `tools/test_phase2.luau` in the pure-module Luau analysis command. Syntax-compile every file in src/ and every Luau utility in tools/.

The build maps src/simulation to ReplicatedStorage/Cagebound/Simulation, IntentProtocol to ReplicatedStorage/Cagebound/Shared, CalibrationRig to ReplicatedStorage/Cagebound/Presentation, CharacterService to server Services, and src/client/Controllers to StarterPlayerScripts/Cagebound/Controllers. Players.CharacterAutoLoads is false in the saved place and at server startup. Server roots are anchored Parts; there is no default Humanoid movement or physics ownership to trust.

Runtime action protocol: exact top-level keys version, session, seq, action, variant, body, grapple, pressed. Movement packets contain version, session, frames; each frame has seq, x, z, yaw, guard. Yaw is finite and wrapped to ±pi; axes are finite and have combined length at most one. The server applies body turn limits itself. Guard is also included in continuous movement intent so a missed release action cannot leave the remote pose held.

Session GUIDs distinguish actor lifetimes, not secrets or authentication credentials. Player identity comes only from OnServerEvent's Player argument. Client-provided positions, damage, victims, animation markers and time deltas are absent. The current gateway is an input/movement gateway; later combat eligibility must be applied before accepting attacks.

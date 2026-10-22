# Follow-up 01 baseline — 21 October 2026

## Source / build identity
- Git HEAD `4dfc507` (2026-10-19 "Phase 5 arena lighting…") plus the preserved uncommitted work tree. All 207 entries of `source-snapshot.json` (default.project.json + 206 `src` files) hash-identical to the audit snapshot. Follow-up 01 changed tools/docs only; no `src/` or `default.project.json` edit.
- Temporary build: `/private/tmp/claude-501/-Users-digonto-Documents/117b0fdf-8d18-4463-a633-3fdaef3f12c3/scratchpad/AsurasPath_F01.rbxlx` (SHA-256 prefix `04fb114a88de04fe`; 206 mapped sources; 227 distinct Roblox asset IDs; Phase 5 library mapped). Script digest: 205 scripts / 1,514,195 bytes / `1227952948`.
- Saved `outputs/AsurasPath.rbxlx` SHA-256 checked before and after the run: unchanged.

## Studio connection (evidence: seeded Studio diagnostic)
- This Claude session has **no Studio MCP server registered** (failing layer: client MCP configuration). The local `StudioMCP` hub on 127.0.0.1:13469 belongs to another app's process. Studio 0.743.506 was running.
- Bypass: `tools/studio_mcp.py` spawns the bundled `StudioMCP` proxy over stdio → handshake + **28 tools** (`list_roblox_studios`, `get_studio_state`, `execute_luau`, `start_stop_play`, `get_console_output`, `user_keyboard_input`, …).
- First harmless read: the existing instance had "Place is not open"; it later showed an unrelated cloud place "VFX (placeId 99240829139422)", which this work never touched.
- `open -a RobloxStudio file.rbxlx` (a `file://` protocol launch) left a new instance idle on the start page. That instance was closed. `RobloxStudio -task EditFile -localPlaceFile <temp build>` opened instance `16a68096…` as `AsurasPath_F01.rbxlx`, Edit mode.
- Identity check: running `tools/qa/SourceDigest.luau` through `execute_luau` (Edit) returned 205 / 1,514,195 / `1227952948` with 13 `AsuraAssets` children. That equals the local digest, so the open place holds exactly this checkout's build.

## Fresh boot + basic interaction (seeded Studio diagnostic; one Play session, not real or earned play)
- Play started. Server: `Phase12Ready=true`, `AsuraReady=true`, 1 player, character present. Client: `AsuraClientReady=true`; GUIs AsuraHUD, AsuraPrologue, AsuraTouchControls, JadeDialogue, SpectatorWagers, AsuraColosseum, AsuraVignette.
- Console: Campaign regions 5 maps / 2,226 parts; Monastery 3,369 parts, 0 walkability issues; server and client "ready" lines. **No game-script errors or warnings.** Non-game output: CorePackages UIBlox "FoundationProvider not found" warnings and `rbxassetid://203785492` asset-type mismatch. That asset is absent from the build; it comes from Studio/CoreGui and also appears in the unrelated instance's log.
- Input: a timed `S` keypress of 1 s moved the character about 22.5 studs at WalkSpeed 22.4, then it stopped (velocity 0).
- Unexplained observation, routed to 08/02: an earlier malformed keyboard call left `W` held for an unbounded time from the prologue spawn (0, 603.1, 920). The character ended at (−79.6, 3.2, −799.3) without an error line. The cause is unestablished: it could be a fall/respawn or the prologue handoff. Boot also logged `[CharacterService] Respawn … displaced to (0, 705.9, 0); restored to (0, 603.1, 920)`.
- Play stopped; Studio returned to Edit. Filtered transcript: `F01_STUDIO_SESSION.txt`.

## Revised runner (local regression / engine emulation)
- `bash tools/verify_all.sh` with `ASURA_BUILD_OUTPUT` set to the temp build: 14 steps, exit 0. It now also runs `test_boss_encounters.luau`, `test_backend.luau`, `test_commercial_systems.luau`, `test_audiovisual.py`, and `luau-compile --null` over all 206 `src` scripts. The build defaults to `$TMPDIR/AsurasPath_verify.rbxlx`. Log: `F01_VERIFY_LOG.txt`.

## Not certified
Physics/appearance quality, human/earned combat, audio listening, hardware, performance and live/cloud services.

# Post-follow-up-26 audit — 25 Oct 2026 (Computer B, macOS)

Audit only. No source, asset, art or feature change in this pass.

## Build identity

| Item | Value |
|---|---|
| Branch | `ux/onboarding-overhaul`, even with `origin` after fetch |
| Audited commit | `2aa500078ffdbad080f22b2124cae589cd3ab422` (`2aa5000`, 2026-10-25 19:21 +1100, F21–26 sign-off). Last commit touching `src/` and `FINAL_ACCEPTANCE.md`. |
| Working tree | Clean except the untracked `outputs/art-direction-2026-10-25/` (see "Concurrent work") |
| Saved place | `places/AsurasPath.rbxlx` = `outputs/AsurasPath.rbxlx`, sha1 `da1b8a8ceadd73362b161c5666132d46a1faaae9` |
| Script digest | **scripts 254 · bytes 1,832,290 · digest 1438804042**. Same in the saved place (`studio_mcp.py --digest`), a fresh verifier build, `python3 tools/build.py` and a Studio Edit read-back. Matches F21–26's final digest. |
| Place build | `python3 tools/build.py`: 262 mapped sources, 489 distinct Roblox asset IDs. Output byte-identical to the committed place, so there is no diff to commit. |
| Toolchain | Rojo 7.7.1, local Luau (arm64) in `work/bin/luau` |

## Checks run in this pass (labelled)

| Check | Result | Evidence type |
|---|---|---|
| `bash tools/verify_all.sh` (temp place output) | SUCCESS, 14/14 steps, exit 0 | local regression / engine emulation |
| `python3 tools/lune_compat.py --all` | 20 suites PASS, 2,191 checks, 0 SHIM GAP | local regression (Lune shim emulation) |
| Invariants in source | Tempo.Scalar 1.4; Deflect 100 ms; Health layers Active/Recoverable/PermanentDeficit; LagCompensation 60 Hz, MAX_REWIND 0.15 s; profile schema v4; weapon registry 12 (`test_boss_rewards`) | source + local regression |
| Studio Edit read-back of the saved place | Digest 1438804042; `ServerStorage.AsuraAssets` holds 13 environment models; **0 `AsuraBoss_*` instances anywhere; no `AsuraBossAnimations` folder** | real Studio (Edit, read-only) |
| Studio Play boot, 1 player, ~20 s | Console clean: regions raised (5 maps, 3,126 parts), Monastery 3,369 parts / 0 walkability issues, "60 Hz authority, 150 ms rewind budget, 3 Colosseum rings; ranked league open (development)", client ready. No errors. | real Studio boot (no gameplay input) |

Not run: earned play, human play, two-client or three-client play, device hardware, listening, private live service. No new visual or play-feel claim is made here.

## Follow-up ledger (26 prompts)

- **Verified:** 01 (baseline/tooling scope only).
- **In progress:** 22 (earned campaign, 0/6 bosses earned) and 25 (performance on player hardware; listening).
- **Implemented — acceptance pending:** 02–21, 23, 24 and 26.

Original batches (FINAL_ACCEPTANCE numbering):
- 15 are implemented with acceptance pending.
- 9 are Blocked on production art: 11–14 and 17–21.
- 2 are in progress: 23 and 25/26.

Prompts 10–13 and 16–20 are "Implemented" in PROGRESS, while the same work appears as original batches 11–14 and 17–21, "Blocked", in FINAL_ACCEPTANCE. The code and Studio work is done; acceptance waits on art. This is two numbering schemes, not a contradiction.

## Findings 1–44: accepted vs pending

| Status | Count | Findings |
|---|---|---|
| **Accepted (Verified)** | 3 | #29 stain card names leg (RP), #30 crypt arrival faces north (RP), #38 rest → menu only, Summon deliberate (SD+RP) |
| Implemented — acceptance pending | 37 | #1–21, #25–28, #31, #33–37, #39–44 |
| Blocked — production art | 4 | #22 region kits, #23 `AsuraBoss_*` models/animations, #24 cast art, #32 Ash kits |

Owner types for pending items: human play (most), earned run (#8–10, #16, #18–19, #28), devices (#12, #33, #39–40), dev work (#35–37).

Audit gaps:
- A1, A2 and A5: closed.
- A3, A4: Blocked on art.
- A6 (`BossMusic_<bossId>` tracks, hardware measurement): open.

## Live boss-model and animation status

- **Models:** no `AsuraBoss_*` template exists in the saved place, in `assets/models/*.rbxmx` or in any registry; this was confirmed in Studio. All 11 phase templates are missing:
  - Shen P1/P2
  - Zhao
  - Bull
  - Baize P1/P2
  - Titan P1/P2
  - Wu P1/P2
  - Wyrm P1/P2

  Each boss renders through the placeholder costume path. F10–13 recorded the live status `AsuraSkinStatus = Fallback:Costume`.
- **Animations:**
  - `BossAnimationRules.Custom` is empty.
  - `AnimationCatalog` has no authored `Custom` id.
  - There is no `AsuraBossAnimations` folder.

  The shared resolver (F10) is live. Humanoid bosses play `Fallback:Stock` (R15 stock idle/tool tracks); creatures (Baize, Titan, Wyrm) use `Fallback:CreatureMotion` procedural motion. F10–13 recorded "0/5–6 authored" per phase.
- **Asset IDs:** none new in this pass. Registered library: 489 distinct IDs referenced by the build. Boss, cast, region-kit and BossMusic IDs do not exist.

## Colosseum / ranked state

- **Rings:** Promenade, Gatehouse Circle, Octagon of Ash. Three were registered at boot in this pass (real Studio boot).
- **Gates:**
  - Live ranked queue is **closed**: `Config.Features.Matchmaking = false` and `Config.Release.RankedIntegrationPassed = false`.
  - Studio opens ranked (`CombatSettings.Colosseum.RankedInDevelopment = true`; the Workspace attribute `AsuraColosseumQA` overrides).
  - Studio persistence is mocked (`Backend.StudioLiveData = false`).
- **Ranked rules (source):**
  - Entry ping is at most 150 ms; a fighter drops at 240 ms.
  - Normalised budget is 60 points above base, capped at 40 per attribute.
  - Forging is ignored in ranked.
  - Match journal and participant inbox handle durability.
- **Evidence:**
  - From Computer A (3-client Studio diagnostic, F23): 25/25 checks covering casual, ranked pairing/normalisation, escrow, refusals, mid-match leave and exactly-once settlement.
  - This pass (local mocks): colosseum runtime 135, backend and commercial suites.
- **Not covered:**
  - Octagon duel lighting.
  - Server shutdown mid-match.
  - Live DataStore.
  - A private test universe. `PrivateBackendValidation`/`PrivateCloudRun` still use the Cagebound namespace and `fightCash`.

## New audit observations (this pass)

1. `places/AsurasPath.rbxl` (binary, 23 Oct) is tracked but stale; only the `.rbxlx` is rebuilt. Opening the wrong file loads an old build.
2. `src/shared/Config.luau` line 1 still carries a relay test marker (`-- [Connection Verified: Computer B is Live]`, f634ab3). It is harmless, but it is noise in the authoritative config.
3. `Config.Project` reports `Phase = 12, SchemaVersion = 12`. `Config.Assets.Pending` lists Cagebound calibration assets (`MDL_Fighter_CBRig_v1_LOD0`, `ANIM_Calibration_*`). The profile schema is v4 (`ProfileSchema.luau`); these are legacy labels that can mislead audits.
4. The PROJECT_STATE "Milestone 4 → 26 Audit" line ("0 Verified, 40 Implemented, 4 Blocked") predates FINAL_ACCEPTANCE (3 / 37 / 4). Use FINAL_ACCEPTANCE.

## Concurrent work (preserved, not committed)

`outputs/art-direction-2026-10-25/` appeared during this audit (19:31–19:32) from another session. It holds `ASURAS_PATH_VISUAL_DIRECTION.md` and `REGION_SILHOUETTE_BOARD.svg`, a concept-only visual direction that states it changes no map, lighting or shipped asset. It was left untouched and uncommitted for its owner.

## Missing production assets / remaining dependencies

- **Artist:** 11 `AsuraBoss_*` phase templates plus 5–6 authored tracks per phase. The contract is in `ASSET_REQUIREMENTS.md` and `F10_13_BOSSES_IDENTITY.md`.
- **Artist:** cast bodies (Lin, Hermit, Gao, player, monk, swordsman).
- **Artist:** region kits for Bamboo, Ash tiers, Crypt vault, Pagoda eaves and Citadel towers.
- **Composer:** `BossMusic_<bossId>` tracks.
- **Human:** earned six-boss campaign, bridge duel, Twins lock switching, listening, device hardware.
- **Owner:** private test experience, harness port to AsurasPath/qiEssence/schema v4, two-account Team Test.

## Prioritised production backlog

1. **Earned six-boss run** on a private test copy at digest 1438804042, by a human, about 6–10 h (handoff in F21_26 §22). It is the only path to E evidence and gates #8–10, #16, #18–19 and #28.
2. **Private live persistence:** create a test experience, port the Private* harness off the Cagebound namespace, then run a two-account Team Test (leases, shutdown, rejoin). This gates turning on `RankedIntegrationPassed`.
3. **Boss production art, one encounter first.** Shen P1/P2 is the tutorial-adjacent humanoid, and the resolver already requests its slots. Deliver the template and tracks, then verify `Template:` / `Authored n/n` in Studio before the other five.
4. **Small dev fixes:**
   - HUD-wide text scale (HUD, objective, Codex, Controls).
   - Clipped Settings Apply button.
   - Titan boss-bar overlap at short viewports.
   - Drop or rebuild the stale `.rbxl`.
   - Clear legacy Config labels.
5. **Device and hardware pass:** phone, tablet and controller, emulator captures at six sizes, and a player-hardware frame-time profile including Twins/Wyrm and the showcase spells.
6. **Audio:** human listening and mix; commission or clear per-boss music.
7. **Region kits** (Bamboo, Ash, Crypt, Pagoda, Citadel), after boss art; the concurrent art-direction proposal is a candidate input.

**Next action:** owner runs backlog item 1 (earned campaign) and starts item 2 in parallel. No art or feature batch was started here.

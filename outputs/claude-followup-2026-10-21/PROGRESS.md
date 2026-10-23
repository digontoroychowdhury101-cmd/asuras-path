# Follow-up progress — created 21 October 2026

This ledger starts with the audit baseline only. No new numbered prompt has been executed. Original implementation and prior regression evidence are preserved in the old ledger. Statuses: Not started; In progress; Implemented — acceptance pending; Verified; Blocked — exact requirement. Evidence must identify build/source identity and whether source/local/emulated/seeded/real play/earned/hardware/private live. A prompt completion is not automatically a finding closure.

## Follow-up execution

| Follow-up | Work | Status | Changed files / evidence type + path / remaining requirement |
|---|---|---|---|
| 01 | Establish a working Studio baseline and trustworthy verifier | Verified (baseline/tooling scope only) | Changed: `docs/BUILD.md`, `tools/build.py`, `tools/verify_all.sh`, new `tools/studio_mcp.py`, `tools/qa/SourceDigest.luau`. Evidence: local regression/engine emulation, `bash tools/verify_all.sh` 14/14 exit 0 → `F01_VERIFY_LOG.txt`, temp build `AsurasPath_F01.rbxlx` (digest 205/1,514,195/1227952948); seeded Studio diagnostic, same digest read in Studio Edit, one Play boot server+client ready, 0 game-script errors, S-key movement → `F01_BASELINE.md`, `F01_STUDIO_SESSION.txt`. Open: no Studio MCP registered in Claude session (use `tools/studio_mcp.py`); held-W relocation observation → 08/02. No game-quality claim. |
| 02 | Close the checkpoint, death and recovery loop | Implemented — acceptance pending | Changed: `InterfaceController.luau` (death note keeps spill), `WorldService.luau` (respawn region from placed root), `CameraController.luau` (sub-stepped shake); tests `test_death_note.luau`, `test_camera_shake.luau`, +3 in `test_recovery_lifecycle.luau` (97). Evidence: seeded Studio diagnostic F02/F02b (digest 1124304554): 8-altar wake table, 7 real enemy deaths, reclaim once, zero-carry death, boss-intro/dialogue respawn, Sanctuary fall + crypt portals → `F02_RECOVERY.md`; local regression `F02_VERIFY_LOG.txt` 14/14. F02c (23 Oct, `places/AsurasPath.rbxlx` digest 761943064, local server+1 client, seeded Studio diagnostic): Cloister rest, 1 monk KO → stain 500 at (42.86, 3.2, −1047.8), wake (60, 3.2, −1018), Essence 0; Exit Client clean. Add Clients rejoins as a new UserId (−2), so same-identity rejoin is impossible locally. `verify_all` 14/14 (temp build, digest 129139939). Open: Blocked — same-UserId rejoin needs Team Test on a separate test experience (steps in `F02_RECOVERY.md`); earned deaths → 22. |
| 03 | Validate input ownership and the desktop combat HUD | Not started | Baseline audit only; use prompt-specific acceptance. |
| 04 | Finish rest, Lin portraits and practical leveling | Not started | Baseline audit only; use prompt-specific acceptance. |
| 05 | Make Arsenal and Codex truthful and readable | Not started | Baseline audit only; use prompt-specific acceptance. |
| 06 | Prove earned boss rewards and exactly-once forging | Not started | Baseline audit only; use prompt-specific acceptance. |
| 07 | Verify attack contact, healing and enemy defeat feedback | Not started | Baseline audit only; use prompt-specific acceptance. |
| 08 | Make the first ten minutes teach the actual game | Not started | Baseline audit only; use prompt-specific acceptance. |
| 09 | Close live combat lighting and sound-lifetime failures | Not started | Baseline audit only; use prompt-specific acceptance. |
| 10 | Finish Shen and Twins, including the real animation dispatcher | Not started | Baseline audit only; use prompt-specific acceptance. |
| 11 | Finish Baize and Titan as readable creature encounters | Not started | Baseline audit only; use prompt-specific acceptance. |
| 12 | Finish Wu and Wyrm presentation and phase behavior | Not started | Baseline audit only; use prompt-specific acceptance. |
| 13 | Finish player, NPC and normal-enemy visual identity | Not started | Baseline audit only; use prompt-specific acceptance. |
| 14 | Walk and finish the Monastery route and navigation | Not started | Baseline audit only; use prompt-specific acceptance. |
| 15 | Validate Sanctuary reveals, terrace and cache routes | Not started | Baseline audit only; use prompt-specific acceptance. |
| 16 | Finish and validate Bamboo Pass | Not started | Baseline audit only; use prompt-specific acceptance. |
| 17 | Finish and validate the Ash Colosseum story region | Not started | Baseline audit only; use prompt-specific acceptance. |
| 18 | Finish and validate Sanctuary Depths and Sunken Crypt | Not started | Baseline audit only; use prompt-specific acceptance. |
| 19 | Finish and validate Celestial Pagoda and final lore | Not started | Baseline audit only; use prompt-specific acceptance. |
| 20 | Finish and validate Sky Citadel and summit return | Not started | Baseline audit only; use prompt-specific acceptance. |
| 21 | Verify the six-sovereign ending and postgame | Not started | Baseline audit only; use prompt-specific acceptance. |
| 22 | Run the earned solo campaign and close integration failures | Not started | Baseline audit only; use prompt-specific acceptance. |
| 23 | Verify real multiplayer and isolated durable persistence | Not started | Baseline audit only; use prompt-specific acceptance. |
| 24 | Close phone, tablet, controller and accessibility acceptance | Not started | Baseline audit only; use prompt-specific acceptance. |
| 25 | Measure performance and listen to the finished audio | Not started | Baseline audit only; use prompt-specific acceptance. |
| 26 | Audit every original batch and every finding before sign-off | Not started | Baseline audit only; use prompt-specific acceptance. |

## Original batch acceptance

| Original | Current independent audit | Follow-up owners | Exact acceptance still open |
|---|---|---|---|
| 01 | Implementation present; Studio diagnostic done (02) | 02, 22 | 02: wake positions at all 8 altars + loss/reclaim/forfeit recorded (seeded Studio diagnostic, `F02_RECOVERY.md`); 3 transition defects fixed. Still open: real save/rejoin at a later checkpoint; earned (non-teleported) loss/recovery → 22. |
| 02 | Implementation present; acceptance pending | 03 | Real keyboard/controller/touch prompt ownership and held inputs. |
| 03 | Implementation present; acceptance pending | 09 | Steady-light six-arena views and real repeated-cycle audio logs/listening. |
| 04 | Implementation present; acceptance pending | 03 | Real HUD state views, crowded labels, transitions and hardware readability. |
| 05 | Implementation present; acceptance pending | 04 | Real three-altar portraits, leveling, return/travel and interruption. |
| 06 | Implementation present; acceptance pending | 05 | Real empty/partial/full Arsenal/Codex and long-text/focus behavior. |
| 07 | Implementation present; acceptance pending | 14 | Real bridge duel, altar clearance, terrain/ladder/veil physics and arrival. |
| 08 | Implementation present; acceptance pending | 06 | Earned boss → Gao → choice → item/use → durable rejoin. |
| 09 | Implementation present; acceptance pending | 07 | Real contact/whiff/feint/heal/dissolve feedback. |
| 10 | Implementation present; acceptance pending | 08 | Fresh-profile play, avatar timing, actual training actions and first discovery. |
| 11 | Partial delivery; production art + acceptance pending | 10 | Production Shen/Twins skins/animation mapping; real entry/phase/retry and target switching. |
| 12 | Partial delivery; production art + acceptance pending | 11 | Production Baize/Titan art/animations; real pillar/pounce/ankle/camera behavior. |
| 13 | Partial delivery; production art + acceptance pending | 12 | Production Wu/Wyrm art/animations; real teleport/flight/landing/defeat. |
| 14 | Partial delivery; production art + acceptance pending | 13 | Production player/NPC/enemy art and actual avatar rebinding/portraits. |
| 15 | Partial delivery; minimap + acceptance pending | 14 | Actual walkthrough/collectibles/terrain plus minimap route layer (still absent). |
| 16 | Implementation present; acceptance pending | 15 | Real shrine/terrace/cache/ladder and natural-camera reveals; numeric model is insufficient. |
| 17 | Partial delivery; production art + acceptance pending | 16 | Bamboo production kit and real route/tablet/altar/mobility checks. |
| 18 | Partial delivery; production art + acceptance pending | 17 | Colosseum production kit and real story/PvP access and Shen clearance. |
| 19 | Partial delivery; production art + acceptance pending | 18 | Crypt production kit, real descent/pit/return and Titan camera checks. |
| 20 | Partial delivery; production art + acceptance pending | 19 | Pagoda production kit, actual rafters/elevation/tablets and Wu clearance. |
| 21 | Partial delivery; production art + acceptance pending | 20 | Citadel production kit, real summit catches/Wyrm clearance/return. |
| 22 | Implementation present; acceptance pending | 21 | Real ending presentation/interruption/rejoin; six earned victories still required. |
| 23 | Local integration present; earned acceptance pending | 22 | Earned full six-boss campaign, collectibles/travel and ending; seeded ledger is insufficient. |
| 24 | Mock integration present; real/live acceptance pending | 23 | Real 2-duelist + spectator sessions and isolated live persistence/failure recovery. |
| 25 | Emulation present; hardware acceptance pending | 24 | Actual captures, phone/tablet/controller hardware and comfort/settings use. |
| 26 | Offline checks present; measurement/listening/audit pending | 01, 25, 26 | 01 done: verifier now includes backend/commercial/boss-encounter/audiovisual + source compile; Studio identity/boot diagnostic in `F01_BASELINE.md`. Still open: measured engine/device performance, real listening/music and complete evidence closure (25, 26). |

## Findings

| Finding | Audit baseline | Work owners (26 audits all) | Evidence / remaining requirement |
|---|---|---|---|
| #1 | Implemented — acceptance pending | 02, 22 | 02: all 8 altars wake at their spawn after rest (7 real enemy deaths at Gate/Cloister, 6 diagnostic respawns), no false cloud-return; Studio seeded diagnostic. Open: real rejoin; earned run (22). |
| #2 | Implemented — acceptance pending | 09, 25 | No new acceptance performed by creating this pack. |
| #3 | Implemented — acceptance pending | 14 | No new acceptance performed by creating this pack. |
| #4 | Implemented — acceptance pending | 04, 14 | No new acceptance performed by creating this pack. |
| #5 | Implemented — acceptance pending | 03, 24 | No new acceptance performed by creating this pack. |
| #6 | Implemented — acceptance pending | 03, 24 | No new acceptance performed by creating this pack. |
| #7 | Implemented — acceptance pending | 09, 25 | No new acceptance performed by creating this pack. |
| #8 | Implemented — acceptance pending | 06, 22 | No new acceptance performed by creating this pack. |
| #9 | Implemented — acceptance pending | 06, 22 | No new acceptance performed by creating this pack. |
| #10 | Implemented — acceptance pending | 21, 22 | No new acceptance performed by creating this pack. |
| #11 | Implemented — acceptance pending | 08 | No new acceptance performed by creating this pack. |
| #12 | Implemented — acceptance pending | 03, 08, 24 | No new acceptance performed by creating this pack. |
| #13 | Implemented — acceptance pending | 08, 11, 24 | No new acceptance performed by creating this pack. |
| #14 | Implemented — acceptance pending | 07 | No new acceptance performed by creating this pack. |
| #15 | Implemented — acceptance pending | 08 | No new acceptance performed by creating this pack. |
| #16 | Implemented — acceptance pending | 10, 11, 12, 22 | No new acceptance performed by creating this pack. |
| #17 | Implemented — acceptance pending | 03, 10 | No new acceptance performed by creating this pack. |
| #18 | Implemented — acceptance pending | 02, 03, 22 | 02: death screen now keeps loss line (fixed cue-order bug), wake altar and reclaim objective shown; boss-intro/dialogue respawn clean; region banner no longer replays on respawn. Open: HUD views (03), earned run (22). |
| #19 | Implemented — acceptance pending | 02, 08, 22 | 02: real deaths drop banked essence into one stain, reclaim exactly once, second death forfeits with 0 loss shown; Studio seeded diagnostic. Open: economy observation in earned play (08, 22). |
| #20 | Implemented — acceptance pending | 07 | No new acceptance performed by creating this pack. |
| #21 | Implemented — acceptance pending | 07, 25 | No new acceptance performed by creating this pack. |
| #22 | Blocked — production art + acceptance | 16, 17, 18, 19, 20, 22 | No new acceptance performed by creating this pack. |
| #23 | Blocked — production art + acceptance | 10, 11, 12, 22, 25 | No new acceptance performed by creating this pack. |
| #24 | Blocked — production art + acceptance | 13, 25 | No new acceptance performed by creating this pack. |
| #25 | Implemented — acceptance pending | 14, 25 | No new acceptance performed by creating this pack. |
| #26 | Implemented — acceptance pending | 14 | No new acceptance performed by creating this pack. |
| #27 | Implemented — acceptance pending | 14, 15, 16, 17, 18, 19, 20, 22 | No new acceptance performed by creating this pack. |
| #28 | Implemented — acceptance pending | 14, 15, 16, 17, 18, 19, 20, 21, 22 | No new acceptance performed by creating this pack. |
| #29 | Implemented — acceptance pending | 14 | No new acceptance performed by creating this pack. |
| #30 | Implemented — acceptance pending | 14 | No new acceptance performed by creating this pack. |
| #31 | Implemented — acceptance pending | 15, 25 | No new acceptance performed by creating this pack. |
| #32 | Blocked — production art + acceptance | 14, 15, 16, 17, 18, 19, 20, 25 | No new acceptance performed by creating this pack. |
| #33 | Implemented — acceptance pending | 03, 24 | No new acceptance performed by creating this pack. |
| #34 | Implemented — acceptance pending | 03, 24 | No new acceptance performed by creating this pack. |
| #35 | Implemented — acceptance pending | 03, 24 | No new acceptance performed by creating this pack. |
| #36 | Implemented — acceptance pending | 03, 09, 24, 25 | No new acceptance performed by creating this pack. |
| #37 | Implemented — acceptance pending | 03, 24 | No new acceptance performed by creating this pack. |
| #38 | Implemented — acceptance pending | 04 | No new acceptance performed by creating this pack. |
| #39 | Implemented — acceptance pending | 04, 24 | No new acceptance performed by creating this pack. |
| #40 | Implemented — acceptance pending | 04, 24 | No new acceptance performed by creating this pack. |
| #41 | Implemented — acceptance pending | 05, 24 | No new acceptance performed by creating this pack. |
| #42 | Implemented — acceptance pending | 05, 21, 24 | No new acceptance performed by creating this pack. |
| #43 | Implemented — acceptance pending | 08, 24 | No new acceptance performed by creating this pack. |
| #44 | Implemented — acceptance pending | 08, 14, 16, 19, 22 | No new acceptance performed by creating this pack. |

## Compact handoffs

Append only the current prompt's decisions, exact check results and remaining dependency. Reuse earlier evidence if its source/build and conditions still apply. Do not paste whole logs or recopy the entire historical journal.

### 01 — 21 Oct 2026
- Decisions: the verifier builds to a temp place by default, so the saved place (which may hold Studio edits) is never overwritten. `build.py` reports the real distinct asset-ID count (227) and accepts `--output`. BUILD.md is current, and the Cagebound material is labelled historical. The Phase 5 library mapping is kept.
- Studio: there is no registered MCP tool in this Claude session. The direct stdio proxy gives 28 tools. A `file://` launch idles at the start page, so use `-task EditFile -localPlaceFile`. An unrelated cloud place "VFX" is open in another instance; do not touch it.
- Routed: the held-W relocation from the prologue spawn (0, 603, 920) to (−79.6, 3.2, −799.3) has an unestablished cause and goes to 08/02. No startup blocker was found, and the bootstraps are unchanged.
- Next: 02. Reuse the `studio_mcp.py` digest check before each Studio claim.
- 13:57 addendum: the user re-ran `verify_all.command`: 14/14 SUCCESS (local regression), 213 mapped sources, 227 asset IDs, saved place unchanged. After the F01 Studio check, source changed at about 13:24 outside this session: 7 new `src/client/Controllers/Sanguine*.luau` mappings and an edited `Bootstrap.client.luau`. The F01 Studio digest therefore describes the earlier build. Re-run the identity check before the next Studio claim.

### 02 — 21 Oct 2026
- Fixed three demonstrated causes; each regression fails on the old code and passes on the new. (1) The death note lost "N essence spilled" when `EssenceLost` arrived before the KO. (2) `onCharacterSpawned` published region nil, because the body is unparented inside CharacterAdded. (3) The explicit-Euler camera shake diverged at 88 ms frames, which froze the camera and hid every line-of-sight prompt.
- Kept: LoadCharacter settle/hold (displacement to y≈105/705 corrected on every respawn), `claimDeath` per-life idempotence, schema.
- Not executable: rejoin in solo Play (mock store resets). Human test listed in `F02_RECOVERY.md`. Observations routed: idle reset monk (07/22), route label during dialogue (04), prompt hold teaching (03/08).
- 23 Oct addendum (F02c, Windows): local Server & Clients (player count 1; default 0) ran the Cloister rest → death → stain → wake sequence. Exit Client then Add Clients joins a **new** UserId, so local Studio cannot prove same-user rejoin. Team Test on a test experience is the exact remaining step. `tools/build.py` now finds `work/bin/rojo/rojo.exe` on Windows.

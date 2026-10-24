# Follow-up progress — created 21 October 2026

This ledger starts with the audit baseline only. No new numbered prompt has been executed. Original implementation and prior regression evidence are preserved in the old ledger. Statuses: Not started; In progress; Implemented — acceptance pending; Verified; Blocked — exact requirement. Evidence must identify build/source identity and whether source/local/emulated/seeded/real play/earned/hardware/private live. A prompt completion is not automatically a finding closure.

## Follow-up execution

| Follow-up | Work | Status | Changed files / evidence type + path / remaining requirement |
|---|---|---|---|
| 01 | Establish a working Studio baseline and trustworthy verifier | Verified (baseline/tooling scope only) | Changed: `docs/BUILD.md`, `tools/build.py`, `tools/verify_all.sh`, new `tools/studio_mcp.py`, `tools/qa/SourceDigest.luau`. Evidence: local regression/engine emulation, `bash tools/verify_all.sh` 14/14 exit 0 → `F01_VERIFY_LOG.txt`, temp build `AsurasPath_F01.rbxlx` (digest 205/1,514,195/1227952948); seeded Studio diagnostic, same digest read in Studio Edit, one Play boot server+client ready, 0 game-script errors, S-key movement → `F01_BASELINE.md`, `F01_STUDIO_SESSION.txt`. Open: no Studio MCP registered in Claude session (use `tools/studio_mcp.py`); held-W relocation observation → 08/02. No game-quality claim. |
| 02 | Close the checkpoint, death and recovery loop | Implemented — acceptance pending | Changed: `InterfaceController.luau` (death note keeps spill), `WorldService.luau` (respawn region from placed root), `CameraController.luau` (sub-stepped shake); tests `test_death_note.luau`, `test_camera_shake.luau`, +3 in `test_recovery_lifecycle.luau` (97). Evidence: seeded Studio diagnostic F02/F02b (digest 1124304554): 8-altar wake table, 7 real enemy deaths, reclaim once, zero-carry death, boss-intro/dialogue respawn, Sanctuary fall + crypt portals → `F02_RECOVERY.md`; local regression `F02_VERIFY_LOG.txt` 14/14. F02c (23 Oct, `places/AsurasPath.rbxlx` digest 761943064, local server+1 client, seeded Studio diagnostic): Cloister rest, 1 monk KO → stain 500 at (42.86, 3.2, −1047.8), wake (60, 3.2, −1018), Essence 0; Exit Client clean. Add Clients rejoins as a new UserId (−2), so same-identity rejoin is impossible locally. `verify_all` 14/14 (temp build, digest 129139939). F02d (23 Oct, source evidence): no re-run. The mock store is in-memory per server and keyed by UserId; the stain and activeAltar persist in `profile.world`, so a local rejoin cannot test this. Added human route B (solo Play twice on a test experience with API access and a temporary `StudioLiveData=true`) to `F02_RECOVERY.md`. Open: Blocked — same-UserId rejoin on a test-experience DataStore (Team Test, or route B) needs a human; earned deaths → 22. |
| 03 | Validate input ownership and the desktop combat HUD | Implemented — acceptance pending | Run 1 (23 Oct, bd737a7): owner-scoped `SetMenu`, Backspace close, Respite blocked over dialogue, Vitals MinScale 0.66, opaque card, glyph removal, respawn camera recentre (11 views, digest 48998423). Run 2 (24 Oct, F03b): changed `InputController` (pad B passes to an open window), `InterfaceController` (altar Backspace/ButtonB back + pad selection), `CastFigures` (non-solid limbs `CanQuery=false`); regressions `test_movement` 59 (+3, fail before), `test_cast_visuals` 48 (+2, fail before); input_map 386, hud_layout 176, death_note 6, rest_dialogue 61, boss_presentation 125, combat_contact 52, monastery_route 59, monastery_discovery 53, progression_runtime 85 (local regression/engine emulation). Studio (seeded Studio diagnostic, `places/AsurasPath.rbxlx` digest 584676947, `F03_INPUT_HUD.md` §F03b): hold-Alt free/relock, lost-release focus return relocks, Alt under Codex/Respite/dialogue and across death leaves no stuck cursor/input and each action fires once, stain E casts only / Z reclaims only; Lin/Bonfire band isolated (same-frame hand-off, single trigger, Z and pad X); H-card recaptured at 1735×823 and 1095×603 (`f03-views/*_F03b.jpg`). Open: Alt+1 swallowed upstream (engine/Studio) and real Windows Alt-Tab → 24; gamepad/touch hardware, real lock switching, Twins duo → 10/24; tags 8–10 px, plate numbers ~6 px → 24; KO-time lock pitch → 07/09; #36 petals → 09. |
| 04 | Finish rest, Lin portraits and practical leveling | Implemented — acceptance pending | Changed: `PortraitCamera` (`aim`, Fov), `DialogueView` (`faceY`, layout constants), `DialogueController` (face band, avatar hidden during portraits, Refused toast), `CameraController` (Portrait.Fov), `RecoveryRules.arrival` + `WorldService.travel` (land within rest reach), `DialogueService` (summon refused while hunted). Regressions: rest_dialogue 63 (+2), progression_runtime 89 (+4), recovery_lifecycle 100 (+3), each fails before. Evidence: seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`, Bonfire/Gate/Cloister portraits (face 0.30 in a 0.19–0.40 band; hat-over-face before/after), rest → summon → leave → altar → travel, death mid-dialogue recovery, Vigor purchase 500→350 / HP 100→106 = preview, refusal "Need 45 more"; verify_all 14/14. Open: other viewports/devices (24), earned play (22). |
| 05 | Make Arsenal and Codex truthful and readable | Implemented — acceptance pending | Changed: `ArsenalTabs` (slot buttons GothamMedium), `ArsenalPanel` (footer fits), `TutorialController` + `ControlsCard` (hidden under open windows). Evidence: seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`, three tabs at start and after forging, forged Thunderfall cast (Qi −45, travel), Codex 0/8·0/6 → 1/8 (real memorial) → 8/8·6/6 (diagnostic) with crossing line; input restored on close. Suites arsenal_codex 169, opening_tutorial 97, hud_layout 176. Open: controller focus on hardware (24); lore secrecy is UI-only (catalog replicated). |
| 06 | Prove earned boss rewards and exactly-once forging | Implemented — acceptance pending | Changed: `LootService` (refusals without script path). Evidence: seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`, diagnostic `RecordBossDefeat` ×2 per sovereign (Essence/tokens/ore once), malformed tokens rejected by store validation, UI Forge→Confirm (rapid ×3 = 1 intent), 24 remote Forge intents = 7 items, siblings refused, storage Release+Load identical, re-award after reload no-op; boss_rewards 131. Open: earned kills → Gao and real player rejoin → 22/23 (Team Test). |
| 07 | Verify attack contact, healing and enemy defeat feedback | Implemented — acceptance pending | 25 Oct (`F07_09_COMBAT_TUTORIAL_AV.md`, digest 1903357088, verify_all SUCCESS): fixed closing-tick reach sweep, deathblow KO credit, AI MoveTo renewal, approach spacing, executed-plate drop, EVADED-only-in-dash (combat_contact 68). Studio seeded diagnostic: six outcomes + cue/server agreement, three heal cases (real R), clean monk/swordsman dissolves, single rewards. Open: real-key feint/deflect fairness (human), last charge, re-capture of plate/EVADED fixes; bridge swordsman ravine → 14. |
| 08 | Make the first ten minutes teach the actual game | Implemented — acceptance pending | 25 Oct (`F07_09_COMBAT_TUTORIAL_AV.md`): fresh-profile real Studio play boot→rest→Gate→training Complete→courtyard→memorial; fixed Evade/Light tutorial judging, skip-folded controls card, handoff banner order, training card/toast placement, Alt-labelled Skip, stakes card fold (opening_tutorial 108, hud_layout 258). Open: human onboarding difficulty (lone monk kills idle player ~4 s), death during replayed opening, rejoin → 23. |
| 09 | Close live combat lighting and sound-lifetime failures | In progress | 25 Oct seeded Studio: Twins/Shen/Baize readable in combat and phase 2, death exit restores region lighting; Titan and Wu arenas dark (bare 0.19 slate floor); live fill test showed an unexplained red/purple floor cast in Wu. Next: identify cast, fix Titan/Wu readability, capture Wyrm/Wu P2, audio-lifetime cycle + locked-Parent scan, mid-cast spell death, #36 petals. |
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
| 02 | Implementation present; acceptance pending | 03 | 03: keyboard ownership, hold-Alt cursor, focus loss, modal/death transitions and the Lin/Bonfire band evidenced (seeded Studio diagnostic, `places/AsurasPath.rbxlx` digest 584676947, `F03_INPUT_HUD.md` §F03b); pad B/altar back fixed. Still open: gamepad/touch hardware and real Alt-Tab (24). |
| 03 | Implementation present; acceptance pending | 09 | Steady-light six-arena views and real repeated-cycle audio logs/listening. |
| 04 | Implementation present; acceptance pending | 03 | 03: 3 desktop states × 2 viewports (23 Oct) + H-card recapture (24 Oct), seeded Studio. Still open: tags/plate numbers → 24, Twins duo/lock switching → 10/24, KO pitch → 07/09, petals → 09. |
| 05 | Implementation present; acceptance pending | 04 | 04: three-altar portraits, leveling, return/travel and death interruption evidenced (seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`); 4 defects fixed. Still open: other viewports/devices (24), earned play (22). |
| 06 | Implementation present; acceptance pending | 05 | 05: Arsenal tabs (start/forged) and Codex 0/partial/full evidenced (seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`); clipping, slot font and overlay stacking fixed. Still open: controller focus on hardware (24). |
| 07 | Implementation present; acceptance pending | 14 | Real bridge duel, altar clearance, terrain/ladder/veil physics and arrival. |
| 08 | Implementation present; acceptance pending | 06 | 06: diagnostic six-sovereign award → Gao → one choice → item/use → storage round trip, exactly once (seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`). Still open: earned victories (22), real player rejoin (23). |
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
| #4 | Implemented — acceptance pending | 04, 14 | F04 (24 Oct, seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`): Cloister portrait face 0.30 in band, no blocker; rest there blocked by hunters (toast) and respawned foes engage at 43–60 studs → 07/22. Open: geometry/clearance in 14, earned play. |
| #5 | Implemented — acceptance pending | 03, 24 | F03 (23–24 Oct, seeded Studio diagnostic, `places/AsurasPath.rbxlx` digest 584676947, `F03_INPUT_HUD.md` §F03b): Z owns every prompt once (Rest, Speak, Recover, overlap band; no `Interact` double), injected ButtonX triggers Rest/Speak once. Open: pad hardware (24). |
| #6 | Implemented — acceptance pending | 03, 24 | F03 (23–24 Oct, seeded Studio diagnostic, `places/AsurasPath.rbxlx` digest 584676947, `F03_INPUT_HUD.md` §F03b): E is spell 2 only, at prompts and at a bloodstain (E held 0.9 s → `Cast 2`, essence unchanged); never rests or reclaims; Alt+E casts once. Open: hardware (24). |
| #7 | Implemented — acceptance pending | 09, 25 | No new acceptance performed by creating this pack. |
| #8 | Implemented — acceptance pending | 06, 22 | F06 (24 Oct, seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`): token objects only — boolean / wrong-boss tokens fail store validation; UI Locked/Forge/Spent = server recipeState. Open: earned kill → Gao (22). |
| #9 | Implemented — acceptance pending | 06, 22 | F06 (24 Oct, seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`): all six sovereigns (+Chimera) forged once, siblings refused, duplicates/re-award/rejoin no-op (diagnostic awards). Open: earned victories (22), real rejoin (23). |
| #10 | Implemented — acceptance pending | 21, 22 | No new acceptance performed by creating this pack. |
| #11 | Implemented — acceptance pending | 08 | No new acceptance performed by creating this pack. |
| #12 | Implemented — acceptance pending | 03, 08, 24 | F03 (23 Oct, seeded Studio, digest 48998423): rally "strike back" and ceiling "max −N · rest restores" are words, not colour only; vitals unchanged since. Open: tags 8–10 px → 24; teaching → 08. |
| #13 | Implemented — acceptance pending | 08, 11, 24 | No new acceptance performed by creating this pack. |
| #14 | Implemented — acceptance pending | 07 | No new acceptance performed by creating this pack. |
| #15 | Implemented — acceptance pending | 08 | No new acceptance performed by creating this pack. |
| #16 | Implemented — acceptance pending | 10, 11, 12, 22 | No new acceptance performed by creating this pack. |
| #17 | Implemented — acceptance pending | 03, 10 | F03: DuoBars code unchanged; the Twins encounter was not exercised in F03 Studio runs. Open: Twins duo identification in Studio/earned play → 10/24. |
| #18 | Implemented — acceptance pending | 02, 03, 22 | 02: death screen now keeps loss line (fixed cue-order bug), wake altar and reclaim objective shown; boss-intro/dialogue respawn clean; region banner no longer replays on respawn. Open: HUD views (03), earned run (22). F03 (23 Oct): respawn camera recentre (`test_camera_shake` 7). F03b (24 Oct, seeded Studio diagnostic, `places/AsurasPath.rbxlx` digest 584676947, `F03_INPUT_HUD.md` §F03b): death with Alt held → respawn 4.1 s, no stuck cursor/input, K/1/move once each; bloodstain E/Z ownership clean. Open: KO-time lock pitch → 07/09; earned run → 22. |
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
| #33 | Implemented — acceptance pending | 03, 24 | F03 (23 Oct): card in reserved band at 1736×824/1096×604. F03b (24 Oct): recaptured with the hold-Alt row at 1735×823 (scale 0.914) and 1095×603 (scale 0.70): fits, clear of action bar/minimap/objective (`f03-views/*_F03b.jpg`, seeded Studio). Open: device sizes → 24. |
| #34 | Implemented — acceptance pending | 03, 24 | F03 (23 Oct, seeded Studio): one target plate under the compass, no overhead duplicates; code unchanged since. Open: real mouse/stick lock switching → 10/24; plate numbers ~6 px → 24. |
| #35 | Implemented — acceptance pending | 03, 24 | F03 (23 Oct, seeded Studio): Vitals MinScale 0.66 (Flask 12.0 px, Essence 14.2 px at 1096×604); unchanged since. Open: rally/ceiling tags 8–10 px, plate numbers ~6 px → 24. |
| #36 | Implemented — acceptance pending | 03, 09, 24, 25 | F03: not assessed — tested areas (shrine, monastery) have no fight-time petals. Open: effect density vs warnings → 09/25. |
| #37 | Implemented — acceptance pending | 03, 24 | F03b (24 Oct, seeded Studio diagnostic, `places/AsurasPath.rbxlx` digest 584676947, `F03_INPUT_HUD.md` §F03b): card text matches InputMap (hold Alt); Backspace and pad B now close every modal incl. the altar and Lin/Codex (B was swallowed by Dash). Alt+1 is engine-reserved while Alt is held → 24. Open: hardware (24). |
| #38 | Implemented — acceptance pending | 04 | F04 (24 Oct, seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`): rest → menu only; Summon deliberate; Leave returns to the altar; travel now sets the checkpoint (Bonfire arrival fixed); summon refusal explained. Open: earned play (22). |
| #39 | Implemented — acceptance pending | 04, 24 | F04 (24 Oct, seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`): face framed above the panel (fixed), player avatar hidden in portraits (fixed), HUD/prompts hidden and restored on leave/death. Open: device layouts (24). |
| #40 | Implemented — acceptance pending | 04, 24 | F04 (24 Oct, seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`): Vigor preview = actual (HP 106, cost 150, 350 left), double click charged once, refusal shows shortfall, list scrolls. Open: phone layout, "+" glyph size (24). |
| #41 | Implemented — acceptance pending | 05, 24 | F05 (24 Oct, seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`): spell/weapon facts match casts and comparisons; slot captions legible (font fixed); footer no longer clipped. Open: device layouts (24). |
| #42 | Implemented — acceptance pending | 05, 21, 24 | F05 (24 Oct, seeded Studio diagnostic, digest 1783028740, `F04_06_PROGRESSION.md`): 0/8·0/6, 1/8 and 8/8·6/6 states truthful, locked entries region-only, crossing line updates. Open: ending/postgame (21), devices (24). |
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

### 03 — 23–24 Oct 2026
- Run 1 (23 Oct, Windows, bd737a7): see `F03_INPUT_HUD.md`. Run 2 (24 Oct, macOS, F03b): reused the HUD views because the HUD modules were unchanged. Re-verified the hold-Alt change (2602f3f) across focus, modal and death transitions, and isolated the Lin/Bonfire band.
- Fixed and regression-tested: pad B was sunk by the Dash action, so "[B] leave" never closed Lin or the Codex (`test_movement` +3). Lin's own arm blocked her Speak prompt's line of sight (`test_cast_visuals` +2; in-engine A/B 6/6). Added an altar Backspace/B back key (verified in Studio).
- Not executable here: OS Alt-Tab on Windows, real pads. Alt+1 is consumed upstream while Alt is held (route to 24).
- Next: 04. Studio left on "Current device", temporary emulator devices deleted.

### 04–06 — 24 Oct 2026
- One Studio pass (macOS, seeded diagnostic) across rest, Lin, leveling, Arsenal, Codex and forging → `F04_06_PROGRESSION.md`, `f04-views/` (19), `F04_06_VERIFY_LOG.txt` (verify_all 14/14).
- Fixed with failing-first regressions: the portrait face hidden by the panel, the player's hat over Lin's face, travel to the Primal Bonfire not resting, and a silent summon refusal while hunted. Fixed and checked in Studio: slot-button font, Arsenal footer clip, tutorial/Controls cards over windows, script path in forge refusals.
- Diagnostic only: boss awards and the full Codex state (store writes). "Rejoin" was a storage Release+Load. Earned kills and a real rejoin go to 22/23.
- Next: 07.

### 07–09 (25 Oct)
- Done: 13 fixes with regressions (see report). Open: 09 lighting fix for Titan/Wu after identifying the Wu floor cast; audio lifetime cycle; human continuous-input checks. Next action: resume 09 at Sovereign Wu.

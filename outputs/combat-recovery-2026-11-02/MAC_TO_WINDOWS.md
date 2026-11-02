# Mac to Windows handoff — combat Stage 3 (2 November 2026)

**Mac implementation complete is not Stage 3 accepted, multiplayer verified or combat fixed.** Evidence here is offline behaviour and seeded single-client Studio diagnostics. Nothing below is ordinary human input, two-client play or human judgment.

## Baseline

| | |
|---|---|
| Implementation commit | `ffb4a4891ff3254ea9464c637928d5abf31a65c9` on `ux/onboarding-overhaul`; the handoff commit directly after it adds only this file and `PROJECT_STATE.md` |
| Build digest | `scripts 272 bytes 2141351 digest 358582538`; matched by `tools/qa/SourceDigest.luau` in Studio on the Mac |
| Check it | `python tools/build.py`, then `python tools/studio_mcp.py --digest places/AsurasPath.rbxlx`. A different digest is not this build; Windows line endings or a newer commit are the first things to check |
| Mac conditions | Studio 0.745, viewport 1271×685, quality Automatic, canonical world, Sanctuary (0, 603, 920), no injected lag |

## Implemented, and what is incomplete

| Requirement | Implemented | Incomplete |
|---|---|---|
| Facing at one instant | `CharacterService.facingAt` | Moving opponents with real clients (W-09) |
| Refused dash | `WorldStateController.Rollback`, `Prediction.dashTravel`, `residualVelocity` | **Real walls, slopes, knockback never run; fake-engine only** (W-07) |
| Dash clip with predicted movement | `Fighter_DashForward/Left/Right`, Backdash; adopt by intent | Each direction's look, and 60 fps timing under real keys (W-02) |
| First visible motion | 60 ms fade removed; 50 ms to 0.25 stud at 60 fps | **A1 FAIL** at ≤1 frame (W-01, decision D1) |
| L1→L4 presentation | `Prediction.followUp`, `restart`; one occurrence per intent | Scheduled real clicks; edge presses within 30 ms of a link wait for the server (W-03) |
| Phase correction, hitstop | `AnimationTiming`, `PlaybackScale`, `FighterAnimations`, `BossAnimations`, `BossCinematics`, `GameFeelController` | Real drift at latency; look of repaid debt (W-04, W-06) |
| Footwork | `FootStep`, `ActorPose` (one Transform writer, pose LOD 8 fighters within 70 studs) | Real slopes, drift, knee clearance, rig scale (W-05) |
| Shared blade | `StrikeTrajectories`, `StrikeTrajectoryData` (generated), `CharacterService.weaponSegment`, `WeaponTrails` | Runtime comparison of drawn and swept blade; 27 moves only (W-06) |
| Weapon coverage | 119 clips, all read back; `ANIMATION_COVERAGE.md` generated | **No clip has been judged by a person** (W-10) |

Not implemented, on purpose: Borrowed Force, motion-matching database, ML runtime, active ragdoll, any loosened window.

## Changed files

- **Runtime, new:** `src/simulation/AnimationTiming.luau`, `src/simulation/FootStep.luau`, `src/shared/StrikeTrajectories.luau`, `src/shared/StrikeTrajectoryData.luau`, `src/shared/AnimationFamilyIds.luau`, `src/client/Controllers/ActorPose.luau`, `src/client/Controllers/PlaybackScale.luau`.
- **Runtime, changed:** `CharacterService`, `LocalPrediction`, `AnimationCatalog`, `WorldStateController`, `FighterAnimations`, `CombatFeedback`, `BossAnimations`, `BossCinematics`, `GameFeelController`, `WeaponTrails`, `Bootstrap.client`, `default.project.json`.
- **Authoring:** `tools/animation/families/` (`families.py`, `publish.py`, `catalog.py`, `timing.luau`), `tools/animation/bake_trajectories.py`, `tools/animation/coverage.py`, `coverage_dump.luau`.
- **QA:** `tools/test_stage3_motion.luau`, `tools/qa/mutation_stage3.py`, `Stage3Equip.server.luau`, `Stage3NoTransition.client.luau`, timing probe foot channel. `tools/combat_anim_coverage.luau` is removed, replaced by `coverage.py`.
- **Assets:** `assets/animations/families/{*.rbxmx,manifest.json,published.json}`: 119 clips by creator Sheashing123 (user 3148600636), the same account as the existing clips.
- **Provenance:** `THIRD_PARTY_NOTICES.md`, `INTEGRATION_MAP.md` (symbol → code → test).

## Runs on the Mac

Logs are in `logs/mac_s3_*`; other evidence is in `mac-stage3/`. All Studio runs are single client, with Studio-injected input (MCP steps at least ~200 ms apart).

| Run | Build | Frames | Result | Missing or failed |
|---|---|---|---|---|
| run1 | earlier | p50 16.66, p95 17.48, p99 20.94 ms | L1 first motion 50.4 ms (0.25 stud); 0.018 stud at 17 ms. Press→ack 36–52 ms. Standing dash body 17 ms, 14 studs in 234 ms | **A1 FAIL.** One click unsent. Seq 7 pose never crossed 0.25 stud (a dodge barely moves the hand; read the foot channel). Seq 10 receipt outside the probe window |
| run2_chains | earlier | throttled from 9.41 s | Found a press past the link going unpredicted (fixed: `restart`) | Later rows at 66 ms frames |
| run3_control | earlier | 15 fps | Transition off: clip pops ≥0.25 stud at first read | Control only |
| run4_final | **final source** | p50 16.71, p95 66.92, p99 68.08 ms (66 ms until ~10.6 s, ~17 after) | L1→L4 Predicted at 200 ms, occurrence ≤0.4 ms, one start per intent. Dash and art at ~60 fps: occurrence ≤0.6 ms, small pose motion ≤18 ms | First click unsent. Seq 5 Expired, no occurrence (legitimate). L1 rows 1–3 at 15 fps. Seq 7 changed pose 1483 ms (hand channel on a dodge) |
| run5_dao_seeded | **final source** | 15 fps | Dao set plays through a seeded equip; forward dash and art clips seen | One click unsent. Only Dao tried. Timing not representative |
| run6_final_foreground | **final source** | 15 fps despite focus 1.0 | Press→ack p50 49 ms | Seq 3, 6 Unpredicted near link edges (occurrence 132, 200 ms at 15 fps). Seq 7 pose missing |

- **Offline:** `bash tools/verify_all.sh` PASS, no skipped suite (`mac-stage3/verify_all.log`). Stage 3 214, Stage 2 111 and 56, contact 68, omni 84, boss presentation 232, cast visuals 48.
- **Test fix to know about:** `test_asura_stage1` asserted the old catalog (19 authored slots, Dao stock). It is updated to 138 and authored Dao, because the catalog changed.
- **Mutations:** 11 of 11 caught (`mac-stage3/mutation_checks.json`). Duplicate cues and root sweep were missed until T-HS-06 and T-CT-13/14 were added.
- **Analyzer:** separate outcome, not a pass. New modules report only missing engine globals and require paths; `WeaponSchema` union errors are in a file this batch did not change.
- **Frame-rate caution:** on the Mac, frame rate did not follow the probe's focus state (runs 3 and 6 focus 1.0 at 15 fps; run 4 unfocused at 60 fps). Read frame times, not focus share.
- **Open observation:** an untraced listener in a throttled session showed repeated `AnimationPlayed` rows and more rows than presses. Traced runs 4–6 do not reproduce it, and the cause is not established. W-03 closes it.
- **Console:** only the `CampaignTerrain` line 120 grid warning at boot, from a file this batch did not touch.
- **Cleanup:** owned Play sessions stopped, Studio closed, probes never saved, no lag or settings left changed.

## Windows queue, in priority order

**Setup for every W case.** Mac worker paused. Pull, then:

```
python tools/build.py
python tools/studio_mcp.py --digest places/AsurasPath.rbxlx
```

Open a copy of the place in Studio and run `tools/qa/SourceDigest.luau` in Edit (digest must match). Record Studio version, GPU mode, quality and frame times (the earlier 24 fps cap came from the RTX/Intel hand-off: see `PROJECT_STATE.md` 2026-10-28). Start Play, then set on the server: `Players:GetPlayers()[1]:SetAttribute("AsuraStage2Seconds", 40)` and `ServerStorage:SetAttribute("AsuraStage2Seconds", 40)`. Then:

```
python tools/qa/qa_inject.py tools/qa/Stage2Timing.server.luau <StudioName>
python tools/qa/qa_inject.py tools/qa/Stage2Timing.client.luau <StudioName>
```

After input, collect and stop Play:

```
python tools/qa/stage2_timing_report.py <StudioName> <case_label> --foreground "<what was in front>"
```

Logs land in `logs/<case_label>_*`; put everything else in `windows-stage3/`. List missing samples, keep outliers.

| ID | Case and scene | Input | Expected | Evidence |
|---|---|---|---|---|
| W-01 | First motion, L1 from idle, Sanctuary. 60 fps and capped 30 fps. Repeat with `tools/qa/Stage3NoTransition.client.luau` injected as a control | 10 real clicks, ≥1.5 s apart | `pose_change_ms` ≤ 1 frame for A1, else state the gap against D1. Do not lower the 0.25-stud threshold. Record `pose_small_ms` too | `win_s3_w01_*` |
| W-02 | Dash animation and movement together. W, A, S, D, neutral, diagonals; flat ground | Real keys + Q | Occurrence same frame as press; foot channel moves within 1 frame of the body; ack does not restart (one start per seq); direction clip matches travel | `win_s3_w02_*`, real-speed video |
| W-03 | L1→L4 chain, scheduled spacing | `powershell -File tools/qa/jian_combo_clicks.ps1 -StudioPid <pid> -X <px> -Y <px>` (0/160/320/520 ms); also 200 and 280 ms | All links Predicted away from edges; one track start per intent. **Check for any double start, the open observation.** Target and achieved spacing both recorded | `win_s3_w03_*` |
| W-04 | Bounded correction, new observer. Second client needed: join after a swing starts, then 100 and 150 ms RTT | Real clicks | Rate stays in [0.75, 1.5]; no seat below 250 ms error; follow-through kept | `win_s3_w04_*` |
| W-05 | Foot drift and rig. Flat, slope, stairs, moving platform if any; strafe, reverse, stance turn, sprint→attack; scaled rig; reduced motion on | Real keys | Planted foot drift below 0.1 stud while locked; no knee flip or floor penetration; lock releases for swing, jump, dash, death, teleport; reduced motion hands feet to clip | `windows-stage3/w05/` video, foot channel |
| W-06 | Blade and contact. Set `Workspace.AsuraDebugReach = true`; Jian L1, L3, Heavy, Running; Dao L1; Guandao L1; TwinDaggers L1; WarFan L1; a scaled body; a boss pulse; a signature attack; a fixed-aim strike | Real clicks against a target | Debug outline matches the visible blade through active frames; spark, trail, reaction and damage share one contact; one hit per pulse identity; hitstop one stop per contact | `windows-stage3/w06/` |
| W-07 | Refused dash in real geometry: wall, corner, rising and falling slope, step, ongoing knockback, timeout, KO, respawn. Force refusal by draining stamina or seeding a state server-side | Real keys | Only the dash's own travel comes off; never through a wall or below ground; knockback continues | `windows-stage3/w07/` |
| W-08 | Root owners. NPC standoff, crowd step-back, ally spacing, attack turn, boss motion, with footwork on | Ordinary fights | One mover per action, no slide or tug; audit in `STATUS.md` Stage 2/3 notes and source | `windows-stage3/w08/` |
| W-09 | Stage 4 two-client matrix per `04_REAL_MULTIPLAYER_VERIFICATION.md`, including facing (moving attacker, front/rear boundary) and grace | One server, two real clients | Per that prompt | `windows-stage3/stage4/` |
| W-10 | Coverage by eye. Every weapon: `ServerStorage:SetAttribute("AsuraStage3Weapon", "<Weapon>")`, then `python tools/qa/qa_inject.py tools/qa/Stage3Equip.server.luau <StudioName>` | Real input, each action in `ANIMATION_COVERAGE.md` | Grip holds, no body clipping, reads as the move. Failures go back to `tools/animation/families/families.py`, then `publish.py`, `catalog.py`, `bake_trajectories.py`, `coverage.py --readback <StudioName>` | Coverage file, `windows-stage3/w10/` |
| W-11 | Full-world performance on the canonical place, 8+ fighters | Ordinary play | p50/p95/p99 and step times; pose budget holds | `windows-stage3/w11/` |
| W-12 | Stage 5 feel acceptance, normal-input duel, PvE transfer | Person playing | Per `05_FEEL_ACCEPTANCE_AND_HANDOFF.md` | Per that prompt |

Run after any change: `bash tools/verify_all.sh` and `python tools/qa/mutation_stage3.py`.

## Outstanding assets

- **Weapon visual gaps, volume unchanged:** Odachi and Cleaver (blade 6 vs reach 13), Heaven-Piercing (7 vs 14), Chain Scythe (15, chain welded rigid), Prayer (12, censer chain welded rigid), Catalyst (about 4 visible vs 8).
- **Six family moves on the generic volume because the clip shows too little:** Dao_L2, Dao_L3, Dao_Art, Dao_Running, Guandao_Art, Guandao_Running.
- **Shared by every weapon, keyed around the Jian grip:** Deflect, Roll, Backdash, Hitstun, Break, Recover. Two-handed weapons lose the left hand from the shaft during these.
- **Unarmed:** two lights strike with the left hand.
- **Mobs and bosses:** own clips, generic blades.

## Decisions waiting (unused proposals)

| ID | Decision | Evidence | Default if undecided |
|---|---|---|---|
| D1 | Inertialization half-life against A1. Shorter reaches 0.25 stud sooner and pops harder | runs 1, 3; `ActorPose.HALFLIFE` 0.045 | Keep; A1 stays FAIL |
| D2 | Approve or revert reduced volume: Jian_Heavy −1.02, Jian_Running −1.30 studs, smaller arcs (Jian Light 11 of 90 cells vs generic 15; Heavy 9 vs 17) | `blade_vs_volume.json`, T-CT coverage line | Keep as baked; flag in feel review. To revert a move, take it out of the bake |
| D3 | Longer models or shorter reach for the weapon gaps above | `ANIMATION_COVERAGE.md` | Volume unchanged, listed open |
| D4 | Stock Animate tracks are no longer frozen by hitstop | Documented limit | Keep |
| D5 | Borrowed Force remains unimplemented | Master prompt | Needs explicit approval |

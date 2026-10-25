# Final acceptance — Asura's Path follow-ups 01–26 (25 Oct 2026)

**Build identity:**
- Final source commit on `ux/onboarding-overhaul` (this file's commit).
- Studio checks ran on saved-place digests 408833177, 1129449138 and 1438804042 (final; `tools/qa/SourceDigest.luau`).
- Consolidated verifier on the final code: `bash tools/verify_all.sh`, **SUCCESS / exit 0** (`F21_26_VERIFY_LOG.txt`,
  temporary place output).

**Evidence keys:**
- S = source
- R = local regression or engine emulation
- SD = seeded Studio diagnostic
- RP = real Studio play (injector keys/clicks)
- MC = 3-client Studio diagnostic
- E = earned continuous-input play
- H = hardware
- L = private live service

No row below holds E, H or L evidence.

**Reports:**
- `F01_BASELINE.md`
- `F02_RECOVERY.md`
- `F03_INPUT_HUD.md`
- `F04_06_PROGRESSION.md`
- `F07_09_COMBAT_TUTORIAL_AV.md`
- `F10_13_BOSSES_IDENTITY.md`
- `F14_20_WORLD_NAV.md`
- `F21_26_GATE_SIGNOFF.md`
- `F23_MULTICLIENT_RESULT.json`

## Verdict

- **Representative private playtesting (human testers on a private, unpublished test copy): GO, with conditions.**
  - Local checks are green.
  - Every region, boss entry, ending branch and the duel/wager flow ran in Studio on a matching build.
  - The demonstrated state bugs in 01–26 are fixed with regressions.
  - The playtest is exactly what supplies the missing E/H/L evidence. Testers must be told that the boss and region
    art are placeholder kits, music is a single drone, the text-size setting covers only dialogue and the ending,
    and progress lives in a test DataStore.
- **Public launch / "all fixed": NO-GO.** Still missing:
  - an earned six-boss campaign (0/6 earned victories);
  - production boss, character and region art (#22, #23, #24, #32 Blocked);
  - any device hardware pass;
  - listening and a real score;
  - measured performance on player hardware;
  - private-live persistence.

Local green tests do not establish player-facing quality or commercial readiness.

## Original batches (26)

| # | Implementation (current) | Best evidence (type, report) | Status | Open requirement · owner |
|---|---|---|---|---|
| 01 | Checkpoint recovery | 8-altar wake, loss/reclaim/forfeit (SD, F02) | Implemented — acceptance pending | Save/rejoin at a later checkpoint via Team Test · human |
| 02 | Input ownership, hold-Alt | Ownership, focus loss, modal transitions (SD, F03) | Implemented — acceptance pending | Controller/touch hardware · human (24) |
| 03 | Arena lighting, lifetimes | Six arenas readable, clean cycles (SD, F07-09) | Implemented — acceptance pending | Listening (25), Octagon duel lighting (23) · human |
| 04 | HUD layout | 3 states × 2 viewports (SD, F03) | Implemented — acceptance pending | Rally/plate tag size, device captures · 24 |
| 05 | Rest/dialogue/leveling | Portraits, leveling, travel, death interrupt (SD, F04) | Implemented — acceptance pending | Other viewports/devices · 24 |
| 06 | Arsenal/Codex | Tabs, Codex states (SD, F05); Codex crossed stage (RP, F21) | Implemented — acceptance pending | Controller focus path · human |
| 07 | Combat contact / bridge | LOS both ends, Cloister clearance (SD, F14); real M1s register (RP, F22) | Implemented — acceptance pending | Human bridge duel from both ends · human |
| 08 | Rewards/forging | Six awards → Gao, exactly once (SD, F06) | Implemented — acceptance pending | Earned victories → forge · E |
| 09 | Enemy outcomes | Six outcomes, heals, dissolves (SD, F07) | Implemented — acceptance pending | Human fairness · human |
| 10 | Opening/tutorial | Fresh profile → training Complete (RP+SD, F08) | Implemented — acceptance pending | Human difficulty, rejoin · human |
| 11 | Shen/Twins | Resolver, 4 fixes, views (SD+RP, F10) | Blocked — production art | `AsuraBoss_*` art/animations · artist (ASSET_REQUIREMENTS) |
| 12 | Baize/Titan | Pounce/kneel fixes, ankle M1 (SD+RP, F11) | Blocked — production art | Same · artist |
| 13 | Wu/Wyrm | Felled-in-flight fix, flight (SD, F12) | Blocked — production art | Same; Wyrm landing vs geometry · artist/human |
| 14 | Cast identity | Gao portrait, attire rebinding (SD, F13) | Blocked — production art | Player/NPC/enemy production art · artist |
| 15 | Monastery route/minimap | Route layer built, tablet I, 2 caches (RP, F14) | Implemented — acceptance pending | Rafters ladder, tablets II–IV · human |
| 16 | Sanctuary routes | Well, shards, Reliquary, ladder (RP, F15) | Implemented — acceptance pending | Dais captures, #31 judgement · human |
| 17 | Bamboo Pass | Road walked (SD, F16) | Blocked — production art | Inscriptions, frost/glide; ruins kit · human/artist |
| 18 | Ash Colosseum | Court route and fill fixed (SD, F17) | Blocked — production art | Shen exit; tier kit · human/artist |
| 19 | Sunken Crypt | Descent/lids/pit catch (RP+SD, F18) | Blocked — production art | Titan chamber with rig; vault kit · artist |
| 20 | Celestial Pagoda | Stair/beam/rafters, VII/VIII once (RP+SD, F19) | Blocked — production art | Rafter-stair re-walk, Wu clearance; eave kit · human/artist |
| 21 | Sky Citadel | Catch-before-destroy fix, bastion walked (SD, F20) | Blocked — production art | Wyrm landing, post-victory return; tower kit · human/artist |
| 22 | Ending/postgame | 5-flag refusal, Release, Remain→Cross, scene, skip, death interrupt fixed, reduced motion, Codex (RP+SD, F21) | Implemented — acceptance pending | Earned six (22); true rejoin (Team Test) · human |
| 23 | Earned campaign | Ledger 99 checks (R); diagnostic milestones (F02–F21) | In progress | Full earned run, 0/6 so far · human |
| 24 | Multiplayer/persistence | 25/25 checks, 2 duelists + spectator (MC, F23); mocks (R) | Implemented — acceptance pending | Private live universe, ported harness, shutdown · owner |
| 25 | Devices/accessibility | Settings UI live (RP, F24); 89/388/258 checks (R) | Implemented — acceptance pending | Emulator captures, hardware, HUD-wide text scale, Apply clipping · human/dev |
| 26 | Performance/audio/audit | 3 scene samples (SD, F25); verifier green (R) | In progress | Player-hardware profiling, boss/cast scenes, listening, BossMusic tracks · human/composer |

## Findings (44)

| # | Status | Evidence (type) | Open · owner |
|---|---|---|---|
| 1 | Implemented — acceptance pending | 8-altar wakes (SD) | Earned later-checkpoint rejoin · human |
| 2 | Implemented — acceptance pending | Arenas readable (SD); scene frame samples (SD) | Player-hardware visuals · human |
| 3 | Implemented — acceptance pending | LOS both ends (SD); real M1s reach server (RP) | Human duel damage both ends · human |
| 4 | Implemented — acceptance pending | Cloister 34/40 free cells (SD) | Human rest under pressure · human |
| 5 | Implemented — acceptance pending | Z owns prompts (SD) | Controller/touch hardware · human |
| 6 | Implemented — acceptance pending | E spell-only (SD) | Hardware · human |
| 7 | Implemented — acceptance pending | Audio baseline cycles (SD); 13/13 sounds loaded (SD) | Listening/mix · human |
| 8 | Implemented — acceptance pending | Token validation (SD, R) | Earned tokens · E |
| 9 | Implemented — acceptance pending | Forged once, siblings refused (SD) | Earned forge · E |
| 10 | Implemented — acceptance pending | Ending branches + death fix (RP+SD, F21) | Earned six-boss ending · E |
| 11 | Implemented — acceptance pending | Training Complete (RP) | Human difficulty · human |
| 12 | Implemented — acceptance pending | Word cues, not colour only (SD) | Device sizes · 24 |
| 13 | Implemented — acceptance pending | Counter hints in boss fights (SD) | Human readability · human |
| 14 | Implemented — acceptance pending | Reach fix, cue agreement (SD) | Human fairness · human |
| 15 | Implemented — acceptance pending | Spacing fix (SD) | Human duel · human |
| 16 | Implemented — acceptance pending | Entry/retry six arenas (SD) | Earned phases/retries · E |
| 17 | Implemented — acceptance pending | Twins bars, X lock (RP) | Mouse/stick switching · human |
| 18 | Implemented — acceptance pending | Death screen order fix (SD) | Earned death flow · E |
| 19 | Implemented — acceptance pending | Stain/reclaim/forfeit (SD) | Earned · E |
| 20 | Implemented — acceptance pending | Heal refusals (RP) | Last-charge case · human |
| 21 | Implemented — acceptance pending | Deathblow reward fix (SD) | Mix/perf · 25 human |
| 22 | Blocked — production art | Structural routes walked (SD/RP) | Region kits · artist |
| 23 | Blocked — production art | Resolver live (SD) | `AsuraBoss_*` assets · artist |
| 24 | Blocked — production art | Attire rebinding (SD) | Character art · artist |
| 25 | Implemented — acceptance pending | Grave path routing (SD) | Visual judgement · human |
| 26 | Implemented — acceptance pending | Gatehouse yard (SD) | Exterior walk · human |
| 27 | Implemented — acceptance pending | Catch/destroy-height, rail fixes (SD/RP) | Remaining region physics walks · human |
| 28 | Implemented — acceptance pending | Minimap route layer; Lin homeward objective (RP+SD) | Earned navigation · E |
| 29 | Verified | Stain card names leg, redraws (RP, F14) | — |
| 30 | Verified | Crypt arrival faces north, real prompt (RP, F18) | — |
| 31 | Implemented — acceptance pending | West wing capture (SD) | Composition judgement · human |
| 32 | Blocked — production art | Ash fill raised (SD) | Kits · artist |
| 33 | Implemented — acceptance pending | Card band at 2 viewports (SD) | Device captures · 24 |
| 34 | Implemented — acceptance pending | Single target plate (SD) | Stick switching · human |
| 35 | Implemented — acceptance pending | Vitals scale (SD) | Rally/ceiling tag size · dev |
| 36 | Implemented — acceptance pending | Reduced effects/motion toggles live (RP); petals (SD) | HUD-wide text scale; density vs warnings · dev/human |
| 37 | Implemented — acceptance pending | Card text matches InputMap (SD) | No remapping UI exists (not advertised) · dev |
| 38 | Verified | Rest → menu only; Summon deliberate (SD+RP, F04) | — |
| 39 | Implemented — acceptance pending | Face framed above panel (SD) | Devices · 24 |
| 40 | Implemented — acceptance pending | Leveling preview = actual (SD) | Devices · 24 |
| 41 | Implemented — acceptance pending | Arsenal facts match (SD) | Controller focus · human |
| 42 | Implemented — acceptance pending | Codex 0/partial/full + crossed stage (SD+RP) | Controller/devices · human |
| 43 | Implemented — acceptance pending | Handoff banner order (SD) | Human onboarding · human |
| 44 | Implemented — acceptance pending | I, VII, VIII read once (RP) | II–VI earned · human |

## Audit gaps A1–A6

| Gap | Disposition |
|---|---|
| A1 BUILD.md / build output | Fixed in 01 (S, F01); build now reports real asset counts ("489 distinct Roblox asset IDs") |
| A2 verifier coverage | Fixed in 01 (R); final run includes backend, commercial, boss, audiovisual and compile, green |
| A3 `AsuraBoss_*` models | Placeholder MeshPart skins only; production art Blocked (#23) |
| A4 animation dispatch | Shared resolver live (10); per-boss production animations Blocked (#23) |
| A5 minimap route geometry | Route layer delivered and walked (14–20, RP/SD) |
| A6 BossMusic / measurement | Still open: no `BossMusic_<bossId>` tracks; 3 Studio scene samples only, on the iGPU |

## Owner actions (short)

1. Run the earned six-boss campaign on a private test copy, logging the build digest (22 handoff in
   `F21_26_GATE_SIGNOFF.md`).
2. Create a private test experience, port the private-live harness (namespace and schema v4), and run a two-account
   Team Test for leases, fencing, shutdown and rejoin (23).
3. Phone, tablet and controller pass, plus Studio emulator captures at six sizes (24); human listening; and
   commissioning or clearing per-boss music (25).
4. Deliver the production art in `ASSET_REQUIREMENTS.md` (#22–#24, #32).
5. Small dev follow-ups:
   - apply the text-size setting across the HUD, Codex and Controls;
   - fix the clipped Settings Apply button.

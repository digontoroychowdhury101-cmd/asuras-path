# Windows acceptance — combat Stage 3 and batch 1 (3 November 2026)

Dispatch: `outputs/post-combat-mac-prompts-2026-11-02/WINDOWS_ALL_FOUR_ACCEPTANCE.md`, with the creator's scope note: verify installed combat and batch 1 first; batches 2–4 are not started and stay NOT RUN.

## Identity

| Item | Value |
|---|---|
| Starting checkpoint | `0aa4453` (digest 1160571320); no newer remote commits; Mac writer paused (no pushes during the session) |
| Mid-session checkpoint | `8130702` (after a power loss; fixes 1–4 below) |
| Final tested sources | this commit; canonical `places/AsurasPath.rbxlx` **scripts 273, bytes 2169470, digest 975213241**, identical to the Studio place the final checks ran on |
| Test places | `places/acceptance_0aa4453.rbxlx` (before), `acceptance_fix1.rbxlx` (digest 523074901), `acceptance_fix2.rbxlx` + the shelter change pushed into the open place, unsaved (= 975213241) |
| Machine | Windows 11 Home build 26300, NVIDIA RTX 4050 Laptop GPU (+ Intel UHD), 1920×1080, Roblox Studio 0.745.0.7451137 |
| Profiles | local mock store only (`Persistence.IsMock`); no live DataStore, no production data, no release flags touched |
| Input | real key/mouse events through Studio MCP and Windows desktop control (production prompt, menu and dialogue paths). Not human play. Seeded QA fixtures are named per row. |

## Acceptance matrix

| Row | Result | Evidence | Conditions | Remaining action |
|---|---|---|---|---|
| Combat Stage 3 | **PENDING** | `w07/0aa4453/`, `w07/fix1/`, `logs/verify_fix2.log`, `logs/mutation_fix2.log` | W-07 refused dash: stamina drained server-side while the client predicts, 1.5 s injected one-way lag (0 s for the wall cases), real Q + direction keys | W-07: flat, stairs up and stairs down **PASS** on fix1 (were FAIL on 0aa4453: 10 studs afloat going up, 10 of 14 studs kept going down). Oblique wall refusal keeps the wall's deflection (body ends 6.8 studs off start): open observation. KO-during-dash NOT RUN in Studio (offline R-02 covers it). Past ~0.5 s one-way delay an *accepted* dash is also rolled back (CONFIRM_TIMEOUT): outside the latency envelope; noted. W-01–W-06, W-08, W-10, W-13 NOT RUN this session |
| Genuine multiplayer | **PENDING** | `two-client/omnipvp_fix2.json` | One server and two real Studio clients (`ExecuteMultiplayerTestAsync(2)`), loopback RTT < 1 ms, seeded placement and cue timing, no human | OmniPvP smoke **12/12 PASS** (first Windows run): hit, 35° whiff, spin exploit refused, cued dodge 2/3 evades, deflect 4/4, air limit. Still to do: W-04 prediction convergence at 100/150 ms RTT, W-06 blade/contact, the W-09 Stage 4 matrix |
| Human feel | **NOT RUN** | `monk/` | Needs a person | Monk lethality analysed; one fairness defect fixed (below). The rest is balance for the creator (see Decisions). Run W-12 with a person |
| Opening / forge | **PENDING** | `cloister/respawn_idle_fix2.json`, `cloister/shelter_journey_fix2.json` | `acceptance_fix2`; seeded Gate/Fought/Read and 1 ore (`tools/qa/OpeningMilestones`, `OpeningSeed`); QA placement only beside Gao and to step out of the altar circle | **PASS** on the return leg: ForgeHome card at the Cloister → kneel → Travel → Bonfire → "Reinforce with Master Smith Gao" → Speak → Reinforce +1 (Essence 500→250, ore 1→0, Jian +1, +2 disabled with the shortage note, milestones Fought,Read,Forged, objective moves on). Death drops 250 to a stain; Travel back and Recover returns it. Two defects fixed (below). NOT RUN: the ordinary fresh-profile walk Sanctuary → Gao with no seeding, training skip/replay on Windows, rejoin |
| Bull / Zhao / duo | **NOT RUN** | — | Batch 2 not started at `0aa4453` | Implement batch 2, then accept |
| Armour | **NOT RUN** | — | Batch 3 not started | Implement batch 3, then accept |
| Route | **NOT RUN** | — | Batch 4 not started | Implement batch 4, then accept |
| Integrated earned loop | **NOT RUN** | — | Blocked by batches 2–4 (no armour, no route) | After batches 2–4: one ordinary-input fresh-profile run |
| Desktop performance | **NOT RUN** | — | — | W-11 / representative sequence on the canonical place after batches 2–4 |
| Physical devices | **NOT RUN** | — | No gamepad or touch hardware used | Gao panel and combat on real gamepad/touch |
| Private live services | **NOT RUN** | — | Not authorised; mock store only | Authorised private DataStore run (rejoin, forge persistence) |

Installed or offline-tested is not runtime accepted. Nothing above certifies human fairness or live durability.

## Defects found and fixed (all repeated after the fix)

1. **Ordinary foes struck inside the 0.25 s reaction floor.** The monk chose a new Heavy while the player was still in heavy hitstun, so it landed 0.14–0.24 s after the player could act (`monk/before_*_0aa4453.json`). Now an ordinary foe's new opener counts its telegraph lead from when the target can first answer (`CombatRules.defendableAt`, `AIService` `Telegraph.plan(..., ready)`). Combo follow-ups stay true links; bosses unchanged. Windows, deflect and tempo untouched. `tools/test_ordinary_foe_fairness.luau` F-01–F-04; Studio `monk/after_*_fix1.json`.
2. **Refused dash floated on stairs and kept a downhill drop (W-07).** The rollback now sweeps the legged travel, follows grade up to 1:1 and settles on the ground (`WorldStateController.Rollback`). `test_stage3_motion` T-RB-11–13; Studio `w07/fix1/`.
3. **Campaign terrain boot error.** The `ReplaceMaterial` region was not voxel-aligned and was refused at boot (`CampaignTerrain`, `ExpandToGrid`). Boot is clean on fix1/fix2.
4. **Foes camped the Cloister respawn.** After killing the player, the monk and swordsman stayed "engaged" with no target, so the death respawn skipped them. They waited at the altar and killed the player on each respawn. `RespawnRegion` now resets foes whose fight was with the player who died, or with no one (F-05). Studio: at each respawn they were back at their posts (~45 and ~70 studs).
5. **The Cloister altar could not be used.** Resting revives the region's foes, and their posts see the altar. They re-engaged within ~4 s, so Travel and rest were refused ("EnemiesNearby") and an idle player died 8 times in ~2 minutes. The ForgeHome instruction "Kneel at the Desecrated Cloister and Travel" was effectively unreachable. Fix: **altar shelter.** After a rest or respawn at an altar, ordinary foes leave the player alone until they step out of the altar circle (radius + 4 studs) or attack, including a spell that lands. Bosses ignore it. It never starts mid-fight, because rest is still refused while hunted. F-06; Studio `cloister/shelter_journey_fix2.json`: 40+ s idle untouched, Travel accepted, stepping out gets a normal fight, the respawn after that death is left alone. **This is a rule addition; the creator approved it on 3 November 2026.**

## Observations (not fixed)

- **Monk lethality under ordinary input**, beyond fix 1. These are balance, not defects, so none was changed silently:
  - (b) new openers 0.1–0.4 s after the monk recovers;
  - (c) blocking drains stamina into a guard break after ~3 s / 8 blocks;
  - (d) posture break leads to a deathblow for 60% max HP (minimum 30), so an ordinary monk can deathblow a Lv1 player;
  - (e) rear hits are 1.5× criticals.
  - Idle Lv1 still falls in ~6 s; guard-only still breaks and is deathblown.
  - The Cloister swordsman killed an idle Lv1 player in ~5 s.
- **Gao's prompts overlap.** At ~6 studs in front of Gao only "Transmute Remembrance" (the seal, 12-stud range) showed. "Speak to Master Smith Gao" appeared only after moving closer (anchor range 10). A player may open the Arsenal instead of the forge.
- **W-07 oblique wall** and **dash confirm timeout**, as in the matrix.

## Decisions for the creator

1. **Altar shelter** (fix 5): **kept** (creator, 3 November 2026). The Cloister posts stay where they are.
2. **Monk pressure:** choose any of a lower ordinary-foe deathblow fraction, a short pause after a string, or lighter posture/stamina pressure. A human W-12 run should decide.
3. **Borrowed Force** stays unimplemented (no approval given).

## Regression

- `bash tools/verify_all.sh`: SUCCESS, 40 suites, including the new `test_ordinary_foe_fairness` 22/22.
- `test_stage3_motion` 284/284; `test_stage2_closure` 57/57; `test_stage2_timing` 111/111.
- `python tools/qa/mutation_stage3.py`: 21/21 mutations caught.
- Logs: `logs/`.

## QA cleanup

- All QA scripts were injected during Play only, or inserted unsaved and removed (OmniPvP; none left, checked). `IncomingReplicationLag` was reset to 0.
- The open Studio place holds the pushed AIService/WorldService sources unsaved; it equals the canonical build.
- New unmapped tools: `tools/qa/DashRefusal.*`, `MonkLethality`, `RespawnCamp`, `OpeningMilestones`. All Studio-only and refused outside Studio; the profile fixtures refuse anything but the mock store.

## Continuation checkpoint

1. Human: W-12 feel and monk fairness; the full ordinary fresh-profile opening (handoff case 1) on this build, including training skip/replay and the Gao prompt overlap.
2. Two clients with latency: W-04 at 100/150 ms, W-06 blade/contact, the W-09 matrix (`outputs/combat-recovery-2026-11-02/MAC_TO_WINDOWS.md`).
3. Remaining Stage 3 W-cases: W-01–W-03, W-05, W-08, W-10, W-13, W-07 KO.
4. Batches 2–4 (`02_IRON_BULL.md`, `03_ARMOUR.md`, `04_ROUTE_EXPANSION.md`) are queued, not started; their acceptance is NOT RUN.

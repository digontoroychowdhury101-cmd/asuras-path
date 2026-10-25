# Follow-ups 21–26 — ending, campaign gate, multi-client, devices, performance, sign-off (25 Oct 2026, Computer A)

Place: `places/AsurasPath.rbxlx`, opened in Studio from each build and proven equal by `tools/qa/SourceDigest.luau`:
digest **408833177** (a5fb173, prompts 21–23 first pass) → **1129449138** (ending shot/Died fixes, prompts 21/24/25
re-checks) → **1438804042** (final source: ending text scale, verified at 130%).
Machine: i5-12450HX, 15.7 GB, Intel UHD (display) + RTX 4050 Laptop; Studio viewport 1736×824, quality Automatic, 1 player
unless stated. Views: `f21-26-views/`. Verifier log: `F21_26_VERIFY_LOG.txt`.

Evidence types: **source**, **local regression**, **seeded Studio diagnostic** (seeded profile flags, placement by
teleport, Studio mock store), **real Studio play** (keys/clicks through the Studio injector), **3-client Studio
diagnostic** (StudioTestService, real local client processes, scripted intents). Nothing here is earned
continuous-input play, hardware, or private live service.

## 21 — Ending and postgame (orig. batch 22; #10, #28, #42)

Seeded profile (isolated Studio mock store); dialogue, choices and skips by real prompt/clicks/keys.

| Case | Result | Type |
|---|---|---|
| Five flags (no Wyrm) → Lin | Greeting, "5/6 souls at rest", no Cross/Remain (`f21_lin_five_flags_greeting`) | real Studio play, seeded |
| Forged Cross at five / via projection | refused by server (existing regression) | local regression |
| Six flags → objective | "Return to Lady Lin · 8m" | seeded Studio |
| Six flags → Lin in person | Release: Cross / Remain / Ascension / Farewell (`f21_lin_six_release`) | real Studio play |
| Remain | banner, objective "Carry their names", HUD restored; story `Released,Remained`, Essence unchanged 500 | real Studio play |
| Remain → walk → later Cross | Lin re-offers; Cross recorded before the scene | real Studio play |
| Cross scene | 3 shots → card → credits → return banner, HUD/input/mouse lock restored, objective "The Asura's Path is walked" | real Studio play |
| Postgame replay + skip | "Walk the crossing again"; 1st key → completion card, 2nd key → ends, overlay removed, LockCenter restored | real Studio play |
| Codex | "6/6 at rest · The crossing is made" (`f21_codex_crossed_stage`) | real Studio play |
| Reduced motion | camera held the beat's final framing (11, 610, 940) for 2 s | real Studio play (setting via Respite UI) |
| Credits | 13 sourced rows + 3 project lines readable at 1736×824 (`f21_credits_1736x824`); text matches `assets/CREDITS.md` (regression; names copied, licences not independently re-verified) | real Studio view + local regression |
| Leave/rejoin after choice | story flags survive release/load (existing regression); a true rejoin needs Team Test (F02) | local regression only |

**Fixed (demonstrated in Studio):**
1. A death mid-scene played the crossing over the death screen; respawn later stopped it. `EndingController` linked
   `Died` only if the Humanoid existed when the character appeared. Now it waits on `ChildAdded`. A new regression
   fails on the old code and passes on the new one. Verified after the rebuild: the scene was active, then death left
   no overlay (`f21_before_scene_over_death` → `f21_after_death_stops_scene`).
2. Shot 3 ("Beyond the jade dawn") sat inside the FusedTreeStatue robe, whose bounds reach z 844
   (`f21_before_shot3_inside_robe`). Shot 2 cropped the figure's head, and shot 1 ended inside a plaza lantern's
   collision box. New framings were prototyped with a client camera, then verified in the scene after the rebuild
   (`f21_after_shot1_end`, `f21_after_shot3_dawn`).
3. The ending lines and credits ignored the Respite text size, and the subtitle had a weak outline on the pale
   statue. Both now scale with the setting, and the subtitle outline is stronger. Verified on build 1438804042 at
   130% (`f21_text130_shot1`, `f21_text130_credits`): larger lines, credits still fit.

Earned acceptance stays with 22. The six flags here were seeded.

## 22 — Earned solo campaign gate (orig. batch 23)

**Not passed.** No earned six-boss run was attempted to completion.

- Real M1 input now reaches the server: a Sparring Phantom took 140 → 127.6 (real clicks, seeded placement).
- A near-end bridge duel attempt killed the idle QA body in about 1.5 s with no hit landed. Difficulty was not
  tuned for injector latency, and the fight is human work.
- The campaign ledger regression passes 99 checks, on seeded state only.

| Milestone | Earned | Diagnostic / offline evidence (build lineage) |
|---|---|---|
| Opening → training | — | 08 real Studio + seeded (`F07_09`) |
| 6 sovereigns, all phases | 0/6 | seeded entries/kills 10–12 (`F10_13`); seeded flags here |
| Earned rewards → forge | — | 06 diagnostic award, exactly once (`F04_06`) |
| Death / stain / reclaim / 2nd death | — | 02 real enemy deaths, seeded placement (`F02`) |
| Save / rejoin mid-campaign | — | regression only; Team Test step in `F02_RECOVERY.md` |
| Altar travel (8) | — | 02/04 seeded Studio |
| 8 inscriptions | 0 earned | I, VII, VIII read (real Z, seeded placement, 14/19) |
| 5 caches | 0 earned | Reliquary, Alcove, Mausoleum claimed (real prompts, 14/15) |
| Reinforce/infuse, mastery/ward/Last Breath | — | 06 seeded; not exercised here |
| Return to Lin → crossing → postgame | — | 21 above (seeded six flags) |

**Owner handoff (human, about 6–10 h):** fresh profile, normal input, opening → six sovereigns → forge → Lin → Cross.
Log build digest, each boss's phases and retries, one later death and reclaim, one save/rejoin (Team Test), and all
altars, inscriptions and caches.

## 23 — Multiplayer and persistence (orig. batch 24)

**3-client Studio diagnostic (`F23_MULTICLIENT_RESULT.json`): 25/25 checks.** Two duelists and one spectator ran on the
Promenade, with production Colosseum, Wager and Action remotes fired by client scripts.

| Area | Result |
|---|---|
| Rings | Promenade, Gatehouse Circle and Octagon of Ash registered |
| Casual challenge/accept | both allocated; Open (not normalised) stats |
| Escrow | spectator stake 100 escrowed before the bell (500 → 400, Pending) |
| Refusals | duelist cannot wager; duplicate wager refused; post-bell wager refused |
| Fight | countdown → Fighting on both clients; client attack → authoritative damage 100 → 92 |
| Isolation | spectator has no duel attribute; Promenade lighting is shared Sanctuary lighting (no duel profile leaks) |
| Mid-match leave | survivor released and restored; spectator's winning stake settled once (580 = 400 + 180) |
| Settlement repeats | two more `Recover` calls pay nothing; exactly 1 settlement notice |
| Ranked | queue open (development); both paired and normalised |
| Leave during setup | remaining fighter released and restored |

**Harness defects found and fixed** (not game bugs):
- Fighters must stand on the threshold band.
- The action `seq` must follow the server's anti-replay gap.
- Promenade duels have no lighting profile of their own.

**Not covered:**
- Octagon of Ash duel lighting.
- Server shutdown during a match.
- Rating/journal inbox after a disconnect. This is mock-tested only: colosseum runtime 135 checks; backend leases,
  fencing and inbox via `test_backend`.

**Private live service: not run.** No allowlisted private test universe is configured, and
`tools/qa/PrivateBackendValidation.luau` / `PrivateCloudRun` still use the Cagebound namespace and `fightCash` fields.

**Owner steps:**
1. Create a separate private test experience.
2. Port the harness to `AsurasPath` / `qiEssence` / schema v4, and set `PrivateValidationUniverse` to its id.
3. Run a Team Test with two accounts: leases, fencing, shutdown delivery, result inbox recovery.

## 24 — Devices and accessibility (orig. batch 25)

| Area | Result | Type |
|---|---|---|
| Respite Settings (keyboard P → Settings) | FOV 70→75 previews live and persists after closing; sensitivity row; Reduced effects/motion/flashes toggles; text 100→115→130% | real Studio play |
| Reduced motion consumer | ending camera holds final framing | real Studio play |
| Text size consumers | **dialogue subtitle only before this pass**; ending now scales too (verified at 130%, build 1438804042); HUD, objective, Codex and Controls ignore it → open | source + Studio |
| Settings layout at 1736×824 | Apply button half-clipped at the bottom of the scroll area (needs a scroll) | real Studio view |
| HUD ≡ button with the mouse locked | not clickable without holding Alt (by design: cursor freed only while held) | real Studio play |
| Alt free cursor vs device switch | `CursorFree` re-checked every frame against held keys, so it can't stick after a gamepad/touch switch; touch never locks | source + `test_movement` |
| Device geometry | 89 device / 388 input-map / 258 HUD checks pass | local regression (emulation) |
| Studio device-emulator captures (6 sizes + small desktop + ultrawide) | **not executed**: the emulator dropdown popup did not respond to the computer-use injector | — |
| Phone / tablet / controller hardware | not available | — |
| Settings persist across rejoin | not testable in solo Play (fresh mock store per session) | — |

## 25 — Performance and audio (orig. batch 26; #2, #7, #21, #23–25, #31, #32, #36)

10 s client samples (RenderStepped), Studio Play, 1 player, build 1129449138. Client and server share one Studio
process, so memory is combined. Client position was confirmed for each row.

| Scene | mean / p50 / p95 / p99 / max (ms) | Memory | Instances |
|---|---|---|---|
| Sanctuary plaza, tree in view | 42.2 / 42.1 / 43.6 / 45.0 / 45.5 | 2980 MB | 78,510 (server 74,317; 11,982 prims) |
| Monastery, monk engaging idle body | 43.0 / 42.6 / 46.2 / 48.0 / 48.3 | 3047 MB | 78,462 |
| Bamboo Pass road | 41.8 / 41.7 / 42.5 / 43.7 / 44.1 | 3099 MB | 78,520 |

- Server heartbeat work was 0.78 ms and physics 1.87 ms, while frames hold at about 42 ms (24 fps) everywhere.
  The cap is not tree-specific; Studio is most likely rendering on the Intel iGPU that drives the display. These
  figures are not a frame-rate claim for players.
- Memory rose by 119 MB over about 25 minutes of deaths, respawns and region visits, while instance count was
  flat. This is not conclusive in Studio (editor memory included). Owner: repeat the comparison in a player build.
- **Not measured:**
  - Twins and Wyrm fights. A server-side root move desynced from the client-owned character, and the gate then
    returned the body home. Samples taken during the desync were discarded.
  - Supernova and Blazing Sun casts.
  - Draw calls and GPU time (MicroProfiler is human-only).
  - Network traffic (0 kbps in a solo session).
- FusedTreeStatue untouched.
- **Audio:**
  - 13 sounds in the session, all loaded, 1 playing.
  - **No `BossMusic_<bossId>` tracks exist**; BossMusic falls back to BossDrone (A6 open).
  - No listening was possible here; hit, deflect, ambience and music listening stays with a human.
  - Supplying a cleared score needs an asset upload, which is publication and out of scope.

## 26 — Sign-off

See `FINAL_ACCEPTANCE.md`.

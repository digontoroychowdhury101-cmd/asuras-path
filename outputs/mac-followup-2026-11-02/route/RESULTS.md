# Route expansion: results (Mac, 5 November 2026)

Build: canonical digest **409185567** (scripts 280, bytes 2236295), `bash tools/verify_all.sh` green, `tools/test_route_foundry.luau` 34 passed. Studio was single-client on the MacBook. Every Windows, human, live-save and hardware gate stays open.

## The problem, measured first
Baseline at walk 22.40 (Ashen ×1.0, Jian), real keys, enemies alive, run past:

| Leg | Time | What is there |
|---|---|---|
| Bridge north head → Bamboo Gate | 9.8 s | Road, no choices |
| Gate → ridge stair foot | 4.7 s | Thin strip, west side was fenced scatter |
| Stair foot → shrine floor | 4.0 s | Crest, shrine stairs |
| **Bridge → shrine** | **18.5 s** | One line, no checkpoint, no shortcut; the only side route is the old Frost stones spur at the crest |
| Shrine → bridge | 20.3 s, 421 studs | Same line back |

**Cause of the compression:** one straight z-axis line with no intermediate spaces, a thin road, and a west thicket (x -200..-44) that was dead fenced scatter. Movement speed was not the cause and was not changed.

## What was built
**The Foundry wing**, in that dead west ground, between the Bamboo Gate and the crest. The old ridge stairs stay where they were, but are barred from the crest side until the player lifts the bar.

| Space | Purpose | Height |
|---|---|---|
| Foundry path, yard | Turn off the road; first fight, slag, moulds, crucible | y 0 |
| Casting hall | Interior beat; cauldron; **The Founders' Ledger** memorial; west door reveal of the stair and tower | y 6 |
| Terrace stair, Bell Landing | Climb and hinge between the two halves | y 6 → 20 |
| Bell Terrace | **Safe pocket: new altar `Altar_BellTerrace`**, the seventh bell, the great tower | y 20 |
| Kiln stair, Founders' Kiln | **Optional branch**, two guards, **one-time cache: 2 Starfall Shard, 3 Spirit Iron** | y 10 |
| Bell Walk, Ringers' Lookout | Timber walk with one guard; crest and mountain open ahead | y 20 → 12 |
| Ridge gate | **Shortcut**: `routeFlags.BambooRidge`, lifted from the crest only, reopens the old stairs for good | crest |

**Links to rewards:** the Kiln's materials are exactly what Iron Oath and upper reinforcement cost at Gao, so the branch feeds Batch 3.

**Preserved:** arena elevations, the Warden's optional role and reward, Baize's mouth, all sovereign and altar ids, every older entrance. `Altar_BellTerrace` is additive and optional: it is not in `Objectives.Route`, so no objective demands it.

**Old saves:** `RouteGates.isOpen` treats the gate as already open once a save has kindled the Bamboo Shrine or Colosseum Antechamber altar, or laid Baize to rest, so nobody past this point is sent backward. `routeFlags` is additive and validated; schema stays v4. Offline coverage only: see below.

## Before and after
Real W key at walk 22.40, enemies alive, no fighting. **Combat time 0 in every row: these are route times, not play times.**

| Walk | Before | After | Label |
|---|---|---|---|
| Bridge → shrine, first time (bar shut) | 18.5 s | **29.0 s, 629 studs** (2 hits) | INPUT, SEEDED start |
| Bridge → shrine, bar lifted | 18.5 s | **18.6 s, 413 studs** (0 hits) | INPUT, SEEDED start and lift position |
| Crest → bridge, bar lifted | 15.4 s out | 16.1 s, 332 studs (3 hits) | INPUT |
| Crest → bridge, back through the wing | n/a | 25.4 s, 562 studs (0 hits) | INPUT |
| Shortcut only: crest → clearing | n/a | 3.2 s | INPUT |
| Terrace → Kiln | n/a | 4.4 s, 95 studs | INPUT, from altar respawn |

A first visit gains 57% more road. With the bar lifted the original route is back to the second, so the shortcut is real.

| Content, bridge to shrine | Before | After |
|---|---|---|
| Purposeful spaces | Road, crest, shrine | + yard, hall, stair, terrace, kiln, walk, lookout |
| Choices | 1 (Frost stones) | + Kiln branch, + shortcut once earned |
| Checkpoints | Shrine only | + Bell Terrace |
| New foes | 0 | 6 (3 Monk, 3 Swordsman), all leashed to zones |
| Rewards | | + one cache, + one memorial (9 inscriptions, was 8) |

**Cost:** wing art is 165 parts; the 196 ms campaign build raises 4103 parts in all, down from 4144, because the cleared scatter was larger than the wing. No new textures or meshes. `StreamingEnabled` stays false.

**Mac timing, not a performance result:** 58.3 fps at the clearing (one 111 ms spike on first load) and 60 fps, worst 21-22 ms, in yard, hall, terrace, deck and kiln. Client memory 4.7-4.85 GB. Studio on the MacBook; the full-world numbers belong to Windows.

## Evidence
**INPUT** real keyboard or mouse in Play. **SEEDED** position set by a script, labelled each time. **Automation:** `rw.py` holds the real W key while a script sets camera yaw toward the next waypoint, so walks prove the route is walkable and timed but say nothing about how easy it is to find. Nothing was saved to a real profile.

| Check | Result | Label |
|---|---|---|
| Rest at Bell Terrace | `AsuraActiveAltar=Altar_BellTerrace`, added to altars, "Altar Kindled", menu with Travel | INPUT |
| Real death and retry | Monks killed the player; respawn (-164, 24.5, -1235) on the terrace, repeatedly | INPUT |
| Cache claim | Ore 0→3, toast "+2 Starfall Shard" | INPUT |
| Second claim | Ore stays 3, including after death and respawn | INPUT |
| Memorial | "1 / 9 Inscriptions" on the Codex panel | INPUT |
| Travel, then the smith | Travel to Primal Bonfire, walk to Gao 3.9 s, panel opens, ore still 3 | INPUT |
| Gate shut | Leaves collide; prompt below "Barred from the far side" | INPUT, SEEDED position |
| Gate lift | Real Z hold; leaves `CanCollide=false`, `AsuraOpenGates=BambooRidge`; lower prompt off | INPUT, SEEDED position |
| Route marker | Shut: clearing "Foundry path · 414m", hall "Hall's west door · 291m", landing "Bell Walk stairs · 209m", kiln "Kiln stair · 291m". Lifted: clearing "Ridge stairs · 204m", crest "Shrine stairs · 108m", hall "Casting hall · 275m" | SEEDED positions, live HUD |
| Fall recovery | Jumped the deck's far rail, landed y 3.4, returned to the landing (-132, 23, -1272), no damage | INPUT |
| Rails | Walking into the deck rail and terrace parapet stops the body | INPUT |
| Enemy pursuit, reset | Kiln monk closed about 10 studs, then both guards returned to their posts once the player left | INPUT, Studio read |
| Camera | Game camera in the hall reads clearly under the fading roof (`hall_game_camera.jpg`). The timed walks used a script-set chase camera, so the stair, Lookout roof and tower base are not proven under the game camera | INPUT |
| Console | No error lines in the output read at the end of the session. The "Respawn displaced to 0, 102.x, 0; restored" line is the existing recovery rule firing at every respawn, in `src/server/CharacterService.luau:682`; it restores correctly | Studio read |

**Bug found and fixed by this test:** the bar silently refused to lift while a monk had the player in hit-stun, because the check required Idle. It now refuses only the KO, respawning and duelling.

Suites: `test_route_foundry` 34, `test_campaign_regions` 421, `test_campaign_build` 27, `test_campaign_ledger` 104, miniboss reward 17, objectives, recovery lifecycle 109, all pass within full verify. Offline `region_walk` proves the shut and lifted paths and fall catches.

Captures in this folder are game views with the HUD on. Most use a fixed QA camera; `hall_game_camera.jpg` and `lift_prompt.jpg` do not. `gate_clearing`, `bell_walk`, `kiln_stair`, `ridge_gate` and `wing_overview` predate the small hall and tower fix, and `baseline_road` is from before the wing.

## Not verified or not good enough yet
- **Rejoin and old saves are not proven live.** Studio's mock store starts fresh on every Play. `routeFlags`, the cache and old-save gate rule are offline tests only. Windows must prove them on a private save, if authorized.
- **Fought-through time is unknown.** Every timed walk ran past enemies. A bot clicking M1 lost to the two Kiln guards, which says nothing about difficulty.
- **The Kiln and hall need human judgment.** A level-1 fresh profile standing still died to the Kiln pair in 3-9 s through hit-stun, and the Hall's swordsman killed it reading the memorial. Level 1 is not who arrives here on an earned save, and monk difficulty was already pending. If it feels unfair, move the guards, do not weaken them.
- **The tower as a far goal is only partly proven.** It reads in the overview and clearly from the landing, but at ground level by the Bamboo Gate the bamboo hides most of it. There the hall roof and the marker do the work. Needs a human eye.
- **Sequence breaks exist and are harmless.** A double jump can clear the gate wings and rails, and a jump from the deck reaches the hall's wall and drops through the decorative roof into the hall. No reward or flag is skipped by either.
- **New meshes were not added.** Studio's import panel needs the user's click and they were asleep, so the wing uses existing kit pieces only.
- **Bloodstain recovery in the wing** was seen (prompt at the Kiln) but not used. Existing systems, existing tests.
- **Older behaviours noticed, not changed:** a claimed cache keeps its prompt, and any cache refuses silently outside Idle (all caches share this); a dialogue open at death stays open after respawn; a foe's health bar stayed on screen at the Sanctuary after a death.
- **`HUMAN_PLAYTEST.md`'s kit may not run as written:** the updated Studio refuses `qa_inject.py`. `tools/qa/qa_place.py` builds a private QA copy instead.
- Two clients, gamepad, touch, phone and real full-world performance were not attempted on this MacBook.

## Continuation for other regions
Measure first, the same way: real-key timed legs, spaces per leg, choices, checkpoints, cause.
1. **Next integration step, before more building:** a fresh-profile opening, equipment and first-boss acceptance playthrough, which times this wing fought through.
2. **Moon gate → Ash road (z -1580..-1680)** reads from the layout as another single line, so it is the likeliest next case. Unmeasured.
3. **Sanctuary Depths, Celestial Pagoda, Sky Citadel:** measure before planning. No evidence yet that they need it.
4. Reuse: `RouteGates` takes more gates, `Layout.door` takes `Gate`, `Altar.Mark` places optional altars. Remaining bosses stay commissioned individually after reinspection.

# Mac follow-up handoff (2026-11-02)

Combat handoff stays historical: `outputs/combat-recovery-2026-11-02/` and `MAC_TO_WINDOWS.md` (W-01..W-13; A1 stays FAILED).

## Mac writer paused (5 November 2026)
All four batches are pushed. **The Mac writer is paused: pull, then run `outputs/post-combat-mac-prompts-2026-11-02/WINDOWS_ALL_FOUR_ACCEPTANCE.md`.** Run order: combat revalidation first (W-cases, `MAC_TO_WINDOWS.md`), then Batch 1, Bull and Zhao, armour, route, then the integrated earned loop.

**Git will not carry** `assets/source/`, `assets/build/`, `*.blend` or `work/`. Batch 4 needs none of them. Batch 2 and 3 masters are only needed to rebuild art, not to play: uploaded ids are in the repo.

**Tooling change.** Studio updated during Batch 3 and refuses `qa_inject.py`. Use `tools/qa/qa_place.py OUTPUT.rbxlx probe...` for a private QA copy. `HUMAN_PLAYTEST.md` does not use `qa_inject.py`, so it is not affected.

**Foundry meshes and playtest fixes (5 Nov):** see `outputs/foundry-kit-2026-11-05/RESULTS.md`.

**Next after acceptance:** a fresh-profile opening, equipment and first-boss playthrough. Later bosses stay out of scope until commissioned individually.

## Batch 4: Route (Mac, 5 November 2026)
Implemented: the Foundry wing between the Bamboo Gate and the crest, Bell Terrace altar, Founders' Kiln cache, Founders' Ledger, barred ridge gate. Digest **409185567**. Details: `route/RESULTS.md`.

**Route to walk, ordinary controls, earned save if possible:**
Bridge north head → Bamboo Gate (z -1120) → **Foundry path** west at (-40, -1178) → yard → stairs (-97, -1207) → hall → west door (-124, -1222) → stair to landing (-132, -1262) → west to **Bell Terrace altar** (-169, -1228) → branch south down (-170, -1292) to **Founders' Kiln** (-170, -1336) → back up → east along **Bell Walk** (y 20) → stairs to crest (-40, -1272) → **Lift the Bar** at the ridge gate from the crest (-1, -1254) → old stairs down → Bamboo Gate → back to the bridge.

**Windows must run, none yet done:**
1. **Both directions, fought through.** Expected unfought: 29.0 s bridge to shrine shut, 18.6 s lifted, 25.4 s back through the wing. Record the fought time; only a human can say if it drags.
2. **Rest at Bell Terrace, die, retry.** Expect respawn at about (-164, 24.5, -1235), flask refilled on rest, Travel lists it.
3. **Kiln cache once.** Expect +2 Starfall Shard, +3 Spirit Iron. A second claim, a respawn, a rejoin and lifting the bar must not pay it again.
4. **Shortcut.** Below, shut: "Barred from the far side", marker "Foundry path". Lift from the crest. Below, lifted: no prompt, marker "Ridge stairs", 3.2 s down.
5. **Old saves, private save, only if authorized.** A save with the Bamboo Shrine or Colosseum Antechamber altar, or Baize at rest: gate already open, all checkpoints valid. A save before them: gate shut, route through the wing. Rejoin after lifting: stays lifted.
6. **Two clients.** The gate stands open while any present player has lifted it, by design. B, who has not, walks through with A; after A leaves it closes for B. Confirm B is not trapped on the crest side (the prompt lifts it) and foes reset cleanly.
7. **Traversal.** Falls off the Bell Walk both sides (expect return to the landing, no damage), both jumps past the gate wings and the hall wall (expect no reward or flag skipped), camera on the stair, under both roofs and against the tower base. Enemy pursuit and reset at the Kiln, hall and walk.
8. **Performance, full world.** Standing at the clearing, hall, terrace and lookout: p50, p95, p99 frame and step, memory, graphics setting. Mac saw 60 fps in Studio only, which is not a result.
9. **Human look and judgment.** Does the wing read as a place with a goal, can the tower be seen when it should, are the Kiln guards and the memorial's nearby swordsman fair, is the bar easy to find from the crest?
10. **Input hardware.** Gamepad and touch on the altar menu, cache and gate prompts.

## Batch 3: Armour (Mac, 5 November 2026)
Implemented: three suits at Gao, ownership, forge, reinforce, compare, wear, migration, real combat effect. Digest **52738962**. Details: `armour/RESULTS.md`.

**Windows must run, none yet done:**
1. **Combat revalidation on this revision.** The earlier combat pass does NOT cover it. Armour touches `CombatRules`, `CharacterService` and contact snapshots. Rerun the W-cases in `MAC_TO_WINDOWS.md`.
2. **Two clients: visible equip.** A wears, swaps, sets aside; B sees the change once, with no leftovers. Expect 14 pieces, limbs hidden.
3. **Equipment during deferred contacts.** Change suit while a hit is in flight. Expect the value frozen at contact.
4. **Normalized and open matches.** Same suits in a normalized duel: no armour effect. Open match: the rules allow what they allow, and report it.
5. **Earned acquisition, no seed.** Cloister altar, 1200 Essence, 3 Spirit Iron, forge Cinnabar. Beat the Twins, forge Iron Oath.
6. **Full input hardware.** Gamepad and touch on the panel, selector first.
7. **Private save durability, only if authorized.** Forge, wear, reinforce, leave, rejoin. Expect the same level and worn suit.
8. **Real slow avatar load** and a body-type spread. Expect one suit on live limbs.
9. **Human look.** Dodge and torso twist in all suits; Iron Oath against intent; head attire next to the suits.

## Batch 2: Iron Bull and Zhao (Mac, 4 November 2026)
Implemented: Bull on the creator's sculpt, 45 clips, boss gait layer, Zhao v2 installed, authored Death playback, won-fight reset fix. Digest **438762895**. Tested: both kill orders, retry, Bull alone (seeded, single client). Pending: every case in `iron-bull/RESULTS.md`, including real-input duels, guard, camera, performance and repeats of shared boss death.

## Checkpoint (Windows, 3 November 2026)
- Windows acceptance of combat Stage 3 and batch 1 ran on this branch. Matrix: `windows-acceptance/RESULTS.md` (final digest 975213241).
- Fixed and re-checked in Studio: monk openers inside the reaction floor, W-07 stairs rollback, terrain boot error, foes camping the Cloister respawn, and the Cloister altar being unusable. **New rule:** an altar shelter after a rest or respawn, ended by leaving the circle or attacking. Creator approved it (3 Nov).
- Batch 1: the Cloister → Travel → Gao → reinforce leg PASSES with real input on seeded earlier milestones. The ordinary fresh-profile walk (case 1 below), rejoin and devices are still pending.
- Not started: `02_IRON_BULL.md` (next), `03_ARMOUR.md`, `04_ROUTE_EXPANSION.md`, final consolidation (in `outputs/post-combat-mac-prompts-2026-11-02/`). Their acceptance is NOT RUN.
- Blockers: none for batch 2. Open decision: monk pressure tuning.

**Resumable checkpoint:** Gao prompt fix, canonical digest **430611340** (scripts 273, bytes 2169893), verifier green.
**Human playtest procedure:** `HUMAN_PLAYTEST.md` (fresh opening, five monk attempts, death recovery, first earned upgrade). Run it before any monk tuning.

## Batch 1 Windows and human cases
1. **Ordinary earned route, fresh profile, no seed.** Kneel at the bonfire, climb the northern stairs, kindle the Gate altar, train or skip, fell a real monk. Expect +45 unbanked and +1 ore toast. Read the Pillars inscription (+100). Travel to the Bonfire, Gao at (-86,603,899), buy +1, attack. Expect a light hit 8.0→8.8 on the phantom. Record time, deaths and whether the monk feels fair.
2. **Death.** Die with Essence, recover the stain; die again before recovering. Expect the first stain returned, then forfeited. Forge levels unchanged.
3. **Reconnect with a real store.** Forge Jian +1, equip Dao, leave, rejoin. Expect Jian +1, Dao +0, Dao in hand. Live DataStore only; label it.
4. **Gamepad and touch.** Gao panel: weapon list, reinforce, equip, close and reopen. Report device vs emulation.
5. **Cross-region return.** Kindle the Cloister, then follow the marker back to Gao (`ForgeHome`). Windows: PASS with real input on seeded earlier milestones (`windows-acceptance/cloister/`). Gao's prompt overlap with the seal is fixed (seal range 4.5; `windows-acceptance/RESULTS.md`, follow-up).

Details: `opening-forge/RESULTS.md`. The larger loop is not complete: armour and first-boss acceptance are missing.

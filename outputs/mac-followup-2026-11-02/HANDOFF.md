# Mac follow-up handoff (2026-11-02)

Combat handoff stays historical: `outputs/combat-recovery-2026-11-02/` and `MAC_TO_WINDOWS.md` (W-01..W-13; A1 stays FAILED).

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

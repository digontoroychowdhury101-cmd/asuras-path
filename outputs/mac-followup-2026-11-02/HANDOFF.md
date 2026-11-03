# Mac follow-up handoff (2026-11-02)

Combat handoff stays historical: `outputs/combat-recovery-2026-11-02/` and `MAC_TO_WINDOWS.md` (W-01..W-13; A1 stays FAILED).

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

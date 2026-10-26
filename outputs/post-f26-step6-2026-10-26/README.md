# Post-F26 step 6 (D1): the Iron Bull's maul and shield, plus three presentation faults (26 Oct 2026, Computer B, Mac only)

**Build identity**
- **Start:** `5a1cfd7`, place digest 557606020.
- **End:** place digest **1556498119** (258 scripts, 1,880,805 bytes). `places/` and `outputs/` hold the same file, and the Studio Edit read-back gives the same digest.

**Concurrent work.** A Codex session was working in this checkout at the same time (GitHub asset reuse: `1d9da20`, `07b9542`). Its `07b9542` committed this batch's source as it stood at 17:40, together with its own work. This batch's final commit adds:
- the rebuilt place (`07b9542`'s place predated the last source edits);
- the brief update;
- the added regression checks;
- this README.

The digest above therefore also includes that session's script changes (GameFeel, SpellVfx, terrain profile).

**Scope limits**
- The 100 ms deflect window is unchanged.
- The 12-weapon player registry is unchanged.
- Zhao keeps the guandao. The Bull's perilous Iron Charge and Colossal Hammer and every existing id are unchanged.
- Human fairness and two-client play: pending, Windows.

**Evidence labels**
- **SD:** seeded Studio diagnostic (placement, KO protection, server-timed intents, one Twin removed without a KO).
- **RI:** real Studio input.
- **LR:** local regression.

## D1: the Bull fights with a maul and a tower shield

**How it is wired**
- New boss-only weapon `IronBullMaul` (`WeaponExpansion.bossSpecs`). `WeaponSchema` builds it with the normal validator.
- It is not in `WeaponKeys` (still 12), profiles, the Arsenal or drops.
- The snapshot wire order is the player registry first, then boss arms (`WireKeys`). Every player weapon keeps its index.
- Hits go through the unchanged `CharacterService` sweep and lag-compensated validation.
- `WeaponModels` leaves boss arms to the costume.
- The costume maul was shortened so its far face matches reach 10 at 1.7 scale.

**Moveset** (full table in the brief, §1): Iron Hook, Shield Ram, Anvil Drop, Ox-Yoke Crush, Rampart Rush, Bell-Breaker.
- Every move is blunt, with a narrower or slower arc than the guandao slot it replaces.
- Every recovery is at least as long as the guandao's.
- Nothing covers the back.

**Animation contract**
- `BossAnimationRules.Melee.IronBull` adds 6 slots, for 11 Bull slots in all.
- The server cues every Bull light swing (`BossSwing`), so each maul move plays its own clip slot. Heavy and art already cue a `Telegraph`.
- Other bosses are untouched: the cue fires only for boss-only arms.

| Check | Result |
|---|---|
| SD + live AI, both Twins, 25 s | Every committed strike record (the arc, reach and lunge the server swept and the client drew) equals the spec on all five moves thrown (L1, L2, L3, Heavy, Art). Startups measured within one 60 Hz tick (+0.016 s). L3, Heavy and Art recoveries 0.500 / 0.600 / 0.617 s, as specced. L1 and L2 chain within their combo window. Twins pairs 17, without a rules-valid answer 0, spread 66–84°. The Bull engages at 5.7. |
| SD punish window (Bull alone, placed 4 studs off at the start of each recovery, one light) | **Behind:** 23/23 connected (armoured: damage, no flinch at poise 0.9). **Front:** 15 connected, 10 guarded. The shared rule lets any fighter raise a guard out of recovery, so the shield covers the front and the back is the punish. |
| SD dash-through + punish | 7 whiffs and 3 armoured hits. After a 14-stud dash the player is mostly out of Jian reach. Human timing and positioning are pending. |
| LR | `test_iron_bull` 49 checks (registry, wire round trip, identity, drawn = validated path, commitment and punish windows, spacing, cue, slots). 7 of them plus a crash fail on the old code. `test_boss_runtime` 35; `test_boss_presentation` 203 (Bull slots 11/11, maul tip vs reach 10). |

## Presentation faults

| Fault | Fix | Evidence |
|---|---|---|
| Perilous banner vs toast | The toast yields: while a perilous banner shows, the toast drops under the banner's text (`InterfaceController.YieldToast`, `HudLayout.toastShift`). The banner always sits just under the lock hint. | SD at **1221×503**, 40 s passive Twins: before, 325/325 overlapping frames, up to 19.5 px into the banner. After, 371/388 frames clear with a 6 px gap. The other 17 fall inside the banner's 0.18 s pop-in (scaled 1.35×), mostly by 1 px, at most 21.5. Capture `c04`. |
| Camera squeeze at the court's north edge | Crane: a probe along the un-craned boom drives a downward pitch of up to 35°, so a wall behind lifts the lens instead of pressing it into the player's back. The player's own body fades if the lens comes within 4 studs. | SD, player 6 studs from the sealed fog gate, Bull locked. Before: lens 4.5 studs from the head, the player's back filling the lower half (`c01`). After: wall 5.4 behind, lens 6.6 out and 2.0 above, looking down 18° at the Bull and the ring (`c02`). |
| Rafters loft roof framing | The drum-tower roof is tagged `AsuraCameraFade`. The client fades it (0.8) while the lens-to-head line crosses its box, with a 1.5-stud margin for a lens under the eave. | SD on the loft: roof LTM 0.80, player visible (`c03_…roof_faded` vs the step 4–5 `c03_…before`). The earlier over-the-roof lens position crosses the box (LR check). |

## Bull weapon mastery: unchanged (checked)

- The Bull's agent Essence is 0 so the encounter's Essence is not paid twice.
- The `Essence <= 0` mastery gate in `WorldService` was written for the Sparring Phantom ("no farming").
- In practice every Twins clear grants exactly one 250 mastery award and one Spirit Iron Ore, whichever Twin falls last (Zhao's KO pays it in either order). That is the same as every other boss.
- Not a missing reward, so nothing changed.

## Checks

- `bash tools/verify_all.sh`: SUCCESS (`VERIFY_LOG.txt`).
- `test_twins_monastery`: 46 checks (+13 for the crane, roof, toast and banner rules from the measured numbers).
- `python3 tools/build.py`: 267 sources, 505 asset IDs.
- The digest read back in Studio Edit matches.

## Remaining gaps

- **Human (Windows):**
  - the Bull's feel and fairness;
  - whether the guard-cancelled front punish reads;
  - the dash-through punish spacing;
  - crane comfort in motion.

  Two-client play is also pending there.
- **Animation:** no Bull clips exist. The 11 slots play the stock stand-in, so the visible swing today is the server-drawn arc plus a stock strike.
- **Not thrown in the seeded runs:** Rampart Rush (needs a sprinting Bull).
- **Rafters roof fade:** proven live with the lens under the eave. The over-the-roof case is covered by the box test only; the injector cannot pitch the camera.
- **Banner/toast:** brief overlap remains during the banner's pop-in.
- **Desktop Space:** Studio stops rendering when its window is on another desktop Space. It was brought back once during this batch.

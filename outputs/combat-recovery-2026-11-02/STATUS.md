# Combat recovery — status

| Stage | State | Date |
|---|---|---|
| 1 Baseline, research, specification | **Done** (specification and offline evidence). Live pipeline measurements are BLOCKED and carried into Stage 4. | 2026-11-02 |
| 2 Timing, input and parry | Not started | — |
| 3 Animation, footwork and contact | Not started | — |
| 4 Real multiplayer verification | Not started | — |
| 5 Feel acceptance and handoff | Not started | — |

## Stage 1 summary

**Highest-impact confirmed defects (static source and offline tables):**
1. **Late presses silently die** (#1). Press time is rewound up to 150 ms, but queue lifetime is counted from that rewound time (100 ms). At about 100 ms one-way, a buffered attack, dodge or parry expires before it can execute, after the client was already told "Buffered".
2. **Nothing the player does starts locally** (#2, #3). Attacks and dashes wait a full round trip plus a snapshot. Animation clocks ignore transit (no sample time in the record), late swings catch up at 2×, and the dash loses distance and spends its i-frames before the body moves.
3. **Parries are not 1:1 and not latency-consistent** (#8, #9). One press deflects every contact in its window. Geometry is rewound but facing and state are present-time. Boss pulses and closing sweeps resolve before that tick's defensive intents. Boss Perilous Thrust has its own literal 0.1 s window.
4. **Most weapons have no swing animation** (#5). 10 of 12 families play no action clip. TwinDaggers borrows Jian clips with different timings.
5. **Hitstop fights the animation clock** (#11). Three systems write `AdjustSpeed`: stale speeds are restored, there are hard re-seats after freezes and gait freezes while roots slide.
6. **Light strings are almost all true combos** (#10). 17/28 links leave no defensive answer even at the slowest continuation.
7. **Studio frame rate measured at about 23 fps** (p50 42 ms) on an unverified session. This must be re-measured with focus on the verified build.

**Implementation choices (to reach running code):** contract-defined intent lifetimes with terminal acks. `ActionSeq`/`SampleTick` in the packed record. Phase-ordered ticks with simultaneous resolution. One-press-one-token parries with a ≤ 100 ms defender grace evaluated at contact time. Local prediction with bounded reconciliation (Orange Duck velocity-bounded adjustment). Joint-offset inertialization (Orange Duck spring decay). IKControl foot locking and stance stepping (ALS and Overgrowth concepts). Baked blade trajectories with clip phase metadata (Epic Fight concept, written independently). Details: `TIMING_CONTRACT.md`, `INTEGRATION_MAP.md`.

**Design direction (creator, added mid-stage):** fast, aggressive wuxia combat, with omnidirectional footwork, precise deflections and flowing counters. `DESIGN_INTENT.md` defines the rhythm (beats, strings with deliberate seams), movement freedom, commitment windows and defensive opportunities, and adds the T-MX moving-exchange cases and target A10 (readable observer windups). It found one new gap against the direction: combo follow-ups can only turn 0–24°, so a string cannot redirect to a flanking foe (T-MX-04 fails by inspection). It also proposes **Borrowed Force (借力)**: deflects bank up to 3 charges, spent on a free-direction riposte, a flank step or a cheaper Art. This is a proposal only, waiting for your approval, and comes after the Stage 2 parry token.

**Not done / open:** live pipeline timings, ordinary-input captures and the OmniPvP run are all BLOCKED because the open Studio place does not match the build and instrumentation does not exist yet. Reference-game inspection NOT RUN. Human judgments open.

## Files
`BASELINE.md`, `DESIGN_INTENT.md`, `DEFECT_LEDGER.md`, `RESEARCH.md`, `INTEGRATION_MAP.md`, `TIMING_CONTRACT.md`, `TEST_MATRIX.md`, `results.json`, `frame_table.md`, `anim_coverage_baseline.md`, `logs/verify_all_baseline.log`. Tools added: `tools/combat_frame_table.luau`, `tools/combat_anim_coverage.luau`.

## Next session (Stage 2)
Start from `TIMING_CONTRACT.md` §2–§6. Implement the InputBuffer `EnqueuedAt`/execute-by limit and terminal acks, `ActionSeq`/`SampleTick` packing, tick phase reordering, the parry token and grace queue, and dash and attack prediction. Write T-IN, T-PA, T-OR and T-TB offline fixtures first and confirm they fail on current code. Replace the `"Deflect = 100,"` assertion. Decide the per-link redirect budget (T-MX-04) and the string seams with before/after `frame_table.md`. Do not implement Borrowed Force without explicit approval.

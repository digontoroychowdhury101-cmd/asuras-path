# Mac work after combat Stage 3A

Prepared 2 November 2026 from the user's `allprompts.rtf`, current source, asset manifests and project history. The document supplied candidate work; its embedded commands were not executed. This package deduplicates that work and supplies subsequent execution prompts.

## What to send next

Finish `outputs/combat-recovery-prompts-2026-11-02/03A_MAC_IMPLEMENTATION.md` and preserve its handoff first. Then send Mac Claude:

> Stage 3A's Mac work is finished. Read and execute `outputs/post-combat-mac-prompts-2026-11-02/01_OPENING_AND_FORGE.md`. Implement the missing opening-journey and smith work, preserve existing completed content, perform feasible Mac runtime checks, and commit/push a complete checkpoint. Stop after that batch. Do not start the other queued prompts automatically.

After reviewing that checkpoint, dispatch the other files individually in this order:

1. `01_OPENING_AND_FORGE.md`: make the existing opening route and reinforcement work as a continuous earned loop.
2. `02_IRON_BULL.md`: finish the first campaign boss pair's missing presentation; preserve Zhao's existing package.
3. `03_ARMOUR.md`: build the currently absent equipment system on the established progression foundation.
4. `04_ROUTE_EXPANSION.md`: add one measured, meaningful Monastery-to-Bamboo expansion after the rewards and destinations it should connect exist.

These numbers identify follow-up batches, not new combat recovery stages. Each prompt stands alone, reads this contract and stops at a usable checkpoint. There is no requirement to finish this entire queue before Windows resumes combat verification. If Windows becomes available sooner, hand over the latest completed batch instead of starting another large task.

## What overlaps or already exists

Review baseline: branch `ux/onboarding-overhaul`, HEAD `8496e13`. Stage 3A was not implemented in this reviewed checkout. The executor must inspect the newer Stage 3A result before deciding what remains.

| Supplied plan | Evidence in reviewed checkout | Next treatment |
|---|---|---|
| Monk, including the duplicate combined cast prompt | Skin, 15 published clips plus authored gaits; `02e06b4`, `6443ae8`; manifests under `assets/animations/opening_cast/monk/` | Preserve. Check opening fights and regressions; repair demonstrated faults. Do not regenerate the character. |
| Cursed Swordsman | Skin, 17 clips and reported bridge checks, `df503ea`; animation manifests and mapped skin | Preserve. Recheck bridge readability after combat changes. |
| Optional early miniboss | Hollow-Bell Warden already has stable definition/spawn/reward, skin and 17 clips, `b2c4951`, `0967769` | Use the Warden. Do not add a second miniboss to satisfy the old conditional instruction. Ordinary-input acceptance remains relevant. |
| Enemy pushing, spacing and groups | Root/MoveTo fix, MobSpacing and shared attack turns, `a902d65`, `497e23b` | Regression checks, including normal-health groups. Seeded wins do not settle human difficulty. |
| Starting Jian | Authored/published starting clips and playback already exist; combat recovery addresses the remaining feel defects | Remaining implementation belongs to Stage 3A/3B. Do not rerun the old Jian authoring project. |
| All player weapon animations | Incomplete at baseline; explicitly covered by Stage 3A | Read its resulting coverage matrix. Carry actual gaps into its handoff rather than create a competing animation project. |
| Both multiplayer prompts | Same outstanding requirement, now covered by combat Stage 3B/4 | One Windows verification task with current harness and two genuine clients. |
| Opening journey/tutorial | Objectives, route guidance and ten-step server-judged training already exist | Improve observed continuity, contextual teaching and recovery in batch 01. Do not rebuild from zero. |
| Gao/weapon reinforcement, standalone and combined RPG prompts | ProgressionRules, ForgeService, ProfileBridge, dialogue UI and compatibility reinforcement routes exist | Trace authoritative routes, close UI/transaction/earned-loop gaps in batch 01. Multiple entry points alone do not prove duplicate charging. |
| Armour, standalone and combined RPG prompts | `ArmorSet` is optional profile data with syntactic validation; no armour ownership/catalogue/equipment-effect system found | Genuine implementation work, batch 03. Attribute-derived poise and move HyperArmor are separate existing combat mechanics. |
| Iron Bull, duplicate prompts | Boss-only maul/shield rules and slots exist; no published Bull animation package found. Earlier report records stock stand-ins | Finish assets/playback in batch 02. Reinspect newer Stage 3A work first. |
| General Zhao | 59 published clips and existing model/rig tooling | Preserve; actual-fight playback review and demonstrated fixes, batch 02. |
| World expansion, duplicate prompts | Monastery zones/branches, Bamboo ridge/overlook, checkpoints, route guidance and substantial art already exist | Measure and extend a missing connection once, batch 04. Do not recreate existing spaces or overwrite the environment-art checkpoint. |
| Baize, Shen, Titan, Wu, Wyrm | Existing encounter implementations and varying presentation foundations; full production completion not established here | Later, one boss at a time in actual campaign priority. Reinspect each before dispatch; the old suggested name order is not a verified campaign order. |
| Both integrated acceptance prompts | Same earned opening/equipment/boss/rejoin acceptance goal | One final integrated acceptance after relevant content is installed; targeted checks happen within every batch. |

The status above is source/history inspection, not a new Studio gameplay sign-off. Character quality, human fairness, full-route acceptance, device performance and live persistence remain distinct claims.

## Shared execution contract

- Re-read current CLAUDE.md, applicable AGENTS.md, PROJECT_STATE.md and current sections of docs/BUILD.md. Inspect HEAD, owned changes, saved/unsaved Studio and Blender state. Synchronize safely using the supported, authorized workflow; preserve unrelated work. No simultaneous writers on the shared branch. Do not bypass an approval rejection.
- Read the completed combat `MAC_TO_WINDOWS.md`, current timing contract and animation coverage. Preserve intent-correlated prediction, contact-time snapshots, current parry semantics, server authority, 1.4x tempo, registry and progression IDs. Old one-use-parry/Borrowed Force proposals are not active instructions.
- Work in the repository. Do not publicly publish, spend money, change account/security settings or enable ranked/live release gates. Use the existing authorized asset-upload workflow where available. Missing optional concept tooling is not a reason to stop code or Blender work.
- Implement each dispatched batch; keep initial inspection focused. Use Claude Design if available for a few useful studies, and existing Blender/Studio tooling for production assets. Prove one import/binding before making an entire package. No finished-content claim from a concept, mesh export or registered ID alone.
- The Mac can run focused single-client Studio checks. Record real conditions and use ordinary movement/interactions where possible. Keep automated real input, seeded diagnostics, human judgment, engine fakes and live services separate. Heavy two-client/performance acceptance remains Windows work. A missing runtime gate stays pending; finish independent implementation and leave exact test steps.
- New tests should cover meaningful behavior, migrations, transactions and regressions. Reuse existing checks. Run the full required verifier at each complete batch handoff, with focused checks during iteration. Rebuild canonical places after source/assets/mapping changes, verify the reviewed Studio build, remove owned QA injections and restore settings. A missing tool or skipped check is not a pass.
- Preserve editable sources, exports, IDs and reproducible tools. Gitignored `.blend`/build files do not transfer through a normal push: identify which required sources are tracked and provide the supported authorized handoff or exact missing transfer. Do not overwrite original masters or silently call a local-only package portable.
- Save concise evidence under `outputs/mac-followup-2026-11-02/<batch>/`; maintain `outputs/mac-followup-2026-11-02/HANDOFF.md`. Record exact source/build identity, tested outcomes, open issues and runnable Windows cases. Keep the combat handoff historical; reference it and identify which later changes require rechecking.
- Update PROJECT_STATE.md by at most 60 words per batch. Stage only the batch's changes; follow the commit/push handoff protocol and report unrelated dirty work rather than discarding it. End at a concrete checkpoint, not an audit or an automatic launch of the next batch.

## Windows scheduling and final acceptance

Reserve the remaining Windows allowance for an actionable combat blocker that actually needs that host. On its reset, run `03B_WINDOWS_VERIFY_AND_COMPLETE.md` against the exact latest completed handoff. That prompt remains responsible for finishing combat Stage 3, genuine Stage 4 multiplayer and available Stage 5 acceptance.

Read `outputs/mac-followup-2026-11-02/HANDOFF.md` as well as the combat handoff. Recheck relevant newly changed systems: forge transactions, outfit replication, armour combat/normalization, Bull/duo playback, traversal and region performance. Combat acceptance does not automatically certify those RPG/content additions. Armour or shared-animation changes made after a Windows pass invalidate the affected parts of that earlier pass and require targeted repeats on the new revision.

For this shared-branch relay, stop the Mac writer and push before Windows syncs/tests. Resume Mac work only after Windows returns a committed handoff. The quota percentages determine which account should do work; they are not evidence that the Mac is incapable of running Studio.

After the opening, equipment, first-boss and route batches, run one ordinary-input fresh-profile acceptance: Sanctuary -> training -> monk/bridge -> checkpoint/discovery -> Gao reinforcement -> earned armour -> intended first boss -> resulting objective, with death/recovery, shortcut, rejoin and save continuation. Preserve seeded diagnostics separately. Windows hardware, human judgments, physical mobile/gamepad and private live durability need their own evidence. Then commission remaining bosses individually; do not start a five-boss production marathon from the old template.

# Mac follow-up 01 — a coherent opening journey and earned weapon upgrade

Combat Stage 3A has reached its Mac implementation handoff. Continue Asura's Path on the Mac by implementing the missing opening-journey and Master Smith Gao work. Finish this batch, test what the Mac can actually verify, commit/push and stop. This is not an instruction to restart combat stages or execute every old prompt.

Read `outputs/post-combat-mac-prompts-2026-11-02/README.md` and apply its shared execution contract. Read the current Stage 3A handoff and inspect anything newer. If that handoff is absent, establish whether Stage 3A is still running before editing its files. Preserve unsaved Studio/Blender work and exclusive branch ownership.

## 1. Inspect existing behavior, then fix the missing links

Start with PROJECT_STATE.md and current implementations of:

- `src/shared/Objectives.luau`, `RouteGuide.luau`, `TutorialRules.luau`, `WorldDefinitions.luau`, `MonasteryZones.luau`, `NarrativeCatalog.luau` and actual campaign gates/connections.
- `src/server/Services/TutorialService.luau`, `WorldService.luau`, `SanctuaryService.luau`, `DialogueActions.luau`; client ObjectiveController, TutorialController, WaypointMarker, DialogueView and relevant inventory panels.
- `src/shared/ProgressionRules.luau`, RPGInventory, RPGProfile and ProfileSchema; server ForgeService, ShopService, ProfileStore, ProfileBridge, PersistenceService and current loadout/stat refresh.

Follow only dependencies needed for this batch. Existing objectives, ten-step training, death/recovery, smith dialogue, reinforcement/material costs and remembrance forging are foundations to improve. Trace actual calls before consolidating anything: the world/profile compatibility path and direct RPG forge path may be legitimate adapters using the same rules. Remove a path only if its caller/behavior is understood and retained.

Use a fresh isolated local test profile with explicit mock/test boundaries; preserve existing saves. Walk the existing opening normally when Studio is available. In a short implementation checklist record the actual first-rest/training/duel/checkpoint/discovery/smith sequence, input conflicts, missing prerequisites and economy. Do not spend the session producing a new general audit.

## 2. Make the opening route explain itself

Implement a continuous sequence through Sanctuary and the opening Monastery that answers: immediate purpose, next reachable destination, useful reward and available improvement.

- Preserve working prologue/skip and first-rest behavior. Teach a small number of actions in context using the current bindings and authoritative success events; retain training replay/skip and veteran-save support. Do not replace existing training with a longer controls wall.
- Connect the first real monk duel, a reachable checkpoint, a useful discovery and the smith. Use existing enemies and Hollow-Bell Warden where appropriate. The Warden remains optional; do not add another miniboss or gate the main journey behind it without an existing requirement.
- Make objectives route through real doors, portals, stairs and intermediate connections. Reuse RouteGuide and current zone data. Account for cross-region smith return rather than drawing a line through geometry. Explain unmet prerequisites and resume the relevant objective after an interruption.
- Teach recoverable health, ceiling injury, healing/rest, posture/deathblow and carried Essence/second-death loss when they matter. Use brief contextual cues, not repeated modal lessons. Match the current combat contract; do not reintroduce outdated parry-token rules.
- If a useful first upgrade is already affordable from defaults, say so accurately; distinguish starting currency from earned rewards. If progression requires earned ore, measure a reachable source and show the player why it matters. Tune only the necessary early reward/cost/teaching gap with documented before/after values. Do not grant hidden QA rewards to make the demonstration pass.
- Handle death/retry, bloodstain priority, returning home, partial training, out-of-order discovery and existing saves. Durable onboarding flags should derive from existing progress where possible; use a backward-compatible migration when needed. A session flag must not masquerade as persisted progress.

Limit map edits to necessary route/camera/interaction fixes. Large world expansion belongs to a later batch.

## 3. Finish Gao's real reinforcement transaction

Give the player a usable owned-weapon selection and a clear current/next-level view, cost, material count and actual stat benefit. Show equipped status and let the player deliberately equip the upgraded result. Keep reinforcement, infusion and remembrance transmutation understandable within the existing UI structure.

- Use the authoritative shared math for previews and server effects, including the correct weapon/scaling attribute and any maximum tier. Avoid a made-up generic damage number that disagrees with the move or equipment.
- Validate weapon ownership, smith proximity, alive/eligible state, duel restrictions, current tier and resources inside the authoritative transaction. Recompute server costs; client quotes are presentation. UI state must recover after success/refusal, close/reopen and loading failures.
- Inspect the existing request/revision/serialization mechanism. A repeated delivery of the same confirmation must not buy an extra tier; two separate deliberate valid confirmations may buy two tiers. Cover stale quotes, rapid clicks, forged/unowned selections, max level and insufficient resources without partial deductions or rollback duplication.
- Use one authoritative profile mutation with existing compatibility synchronization and combat-stat refresh. Switching away/back, resting, death and reconnect must preserve weapon-specific levels and correct stats. Do not independently debit both ForgeService and a world adapter.
- Show useful refusal reasons for resources, location, ownership and maximum tier. Avoid silent disabled buttons as the only explanation. Preserve keyboard, gamepad focus and touch layouts; report actual hardware versus emulation.

## 4. Verify and deliver a usable checkpoint

Add meaningful regression cases for the changed objective/migration/transaction behavior. Reuse `tools/test_objectives.py`, `tools/test_opening_tutorial.luau`, `tools/test_progression_and_lore.luau`, `tools/test_progression_runtime.py`, profile integrity and related review/campaign checks using the documented runner. Run affected combat timing/closure checks if shared eligibility, refresh or combat fields changed, then the required full verifier and canonical build.

In focused Mac Studio play, use ordinary movement and interactions for the opening -> resource acquisition -> smith -> reinforcement -> weapon equip -> actual attack result. Normal combat uses normal health/resources. Record time to first reward and useful upgrade, the route taken, costs and observed before/after stats. If an earned fight cannot be completed autonomously, fix engineering failures, preserve that gap and provide exact human steps; a protected bot win is a diagnostic only.

Separately seed refusal/race/migration fixtures when necessary. Test insufficient Essence/materials, wrong location, max tier, duplicate request, switching weapons, death and reload. Distinguish an actual process/session reload using local storage from a single-session in-memory reset; neither proves live DataStore durability.

Save `outputs/mac-followup-2026-11-02/opening-forge/RESULTS.md` with implemented versus existing behavior, exact build identity, relevant evidence, tests and failures. Update the shared HANDOFF with runnable Windows tests, including the ordinary earned route and any remaining device/live/human gates. Do not mark the larger opening/equipment game loop complete while armour or first-boss acceptance is missing.

Clean owned QA injections, rebuild and verify the final reviewed source. Update PROJECT_STATE in at most 60 words, commit/push only this batch, and stop. Name `02_IRON_BULL.md` as the next queued batch without starting it.

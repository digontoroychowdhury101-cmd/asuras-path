# Mac follow-up 03 — a small, complete armour system

Implement three integrated player armour sets after the opening/forge foundation and Iron Bull checkpoint. Execute this batch only. Read `outputs/post-combat-mac-prompts-2026-11-02/README.md`, its shared contract, latest handoffs and repository rules. Inspect newer work first; skip completed parts with evidence rather than regenerating them.

This is substantial new equipment work, not merely exposing the existing ArmorSet string. It can change combat outcomes, so retain the prior combat baseline and explicitly queue Windows revalidation on this revision. Do not claim an earlier combat pass covers the new equipment effects.

## 1. Extend the existing authority coherently

Inspect ProfileSchema, RPGProfile, RPGInventory, ProfileStore, ProfileBridge, PersistenceService, ProgressionRules, actual inventory/loadout UI, FighterAppearance, CharacterService, CombatRules/contact snapshots, movement ownership and ColosseumService normalization.

The reviewed baseline only stored and syntactically validated optional `equippedLoadout.ArmorSet`; it did not establish an ownership/effect system. Current attribute-derived poise and move HyperArmor are different mechanics. Trace all current paths before choosing new fields and shared rules.

Create one armour catalogue/rules source used by migration, ownership/equip, acquisition, reinforcement, combat calculations and UI. Define bounded numeric tradeoffs for a starter set and two earnable alternatives. Record values and design rationale before wiring them; make conservative choices within the established combat model. The player must still benefit from dodging, deflecting and positioning.

Do not change input latency, baseline parry/i-frame windows, commitment, weapon registry or client hit authority. If using mobility tradeoffs, derive them through the existing movement owner and truthful UI; avoid a hidden responsiveness penalty. Explain how protection, posture/poise and mobility interact with the three-layer health model and any existing caps.

## 2. Complete ownership, economy and save behavior

Provide server-validated acquisition, ownership, equip/unequip and modest reinforcement using the existing economy and forge UI/transactions. Give the player a starter set and two alternatives reachable from existing vendors/exploration/encounters. Preserve optional Warden and sovereign progression/reward IDs. Do not invent a second economy or a mandatory new miniboss.

Show owned/equipped status, real before/after values, upgrade cost/materials and refusal reasons. Derive comparisons from the same rules as the server. Handle max tier, unowned/unknown equipment, insufficient resources, wrong context, stale requests, replay of one confirmation and rapid legitimate requests atomically. Rejected requests consume nothing.

Migrate older profiles without losing currency, weapons, altars, rewards or progress. Validate catalogue membership, ownership and bounded levels; a syntactically valid arbitrary string is insufficient. Give missing/invalid equipment a safe documented default. Preserve future-schema fail-closed behavior and use the existing versioning policy if shape changes require it. Reconcile canonical and compatibility views without dropping new data on save/reload.

Make equip changes safe across idle/combat restrictions, death/respawn and reconnect. Define the allowed equip timing rather than letting an in-flight contact read whichever suit is present at resolution. Carry armour-dependent values consistently through the established contact-time snapshot/deferred-resolution contract. Check melee, bosses, spells/status damage and any existing damage floors/caps for omitted or double application.

Respect ranked normalization and open-duel rules. Normalized modes must not inherit a new advantage through armour, reinforcement or mobility fields excluded by older normalization code. Reapply the correct world equipment after leaving the duel and after respawn.

## 3. Deliver real wearable visuals

Create three original distinguishable dark-wuxia sets with legible roles. Reuse compatible materials/rig tooling from current character work while keeping player equipment identifiable. Use a small concept pass where available and Blender for actual editable clothing/armour pieces; prove one piece's binding/import before exporting all sets.

Fit the actual supported avatar skeleton and scales. Check every critical joint, weapon grip, robe/leg clearance, forward/back/side movement, dash, guard, attack and hit reaction. Coordinate with FighterAppearance's late avatar-load and rebind logic so it does not delete the equipped set, duplicate geometry or attach pieces to replaced limbs. Unequip must remove only owned set geometry. Keep accessories massless/noncolliding and hurtboxes unchanged unless an existing explicit design calls for otherwise.

Use valid permitted IDs and current loader/native library conventions. Verify textures and actual playback after a fresh canonical build. Track editable masters and reproducible exports; distinguish files local to this Mac from transferable sources. Colour swaps, menu icons or procedural stand-ins alone do not satisfy integrated production visuals.

## 4. Verify the full equipment loop

Add behavioral tests for catalogue validation/migration, ownership, atomic purchase/upgrade/refusal, duplicate delivery, stat calculations, contact snapshot consistency and normalized/open-duel rules. Reuse current profile/progression/transaction/appearance/combat suites, including Stage 2 closure/timing where affected. Cover each set at base/max tier and invalid input; avoid tests that merely assert that new constants equal themselves.

In focused Mac Studio checks, acquire/equip/compare/upgrade through ordinary controls and demonstrate the real stat/combat change with known setup. Check death/respawn, late avatar loading, weapon switching, rejoin/reload and appearance cleanup. Seed edge-case fixtures separately. Local storage tests do not prove live DataStore durability, and one client does not prove remote outfit replication.

Run the required full verifier/build, fix reproducible failures, and save `outputs/mac-followup-2026-11-02/armour/RESULTS.md`. Include data migration, formula values, visuals/IDs/sources, per-set integration status, build identity, actual tests and unresolved gates. Update shared HANDOFF with Windows cases for two-client visible equip changes, equipment during deferred contacts, normalized/open matches, earned acquisition, full input hardware and private save durability if authorized.

Clean owned QA, rebuild/verify final source, update PROJECT_STATE in at most 60 words, commit/push this batch and stop. Name `04_ROUTE_EXPANSION.md` as the next queued batch without starting it.

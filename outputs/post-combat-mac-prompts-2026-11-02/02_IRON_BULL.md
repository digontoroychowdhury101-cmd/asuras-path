# Mac follow-up 02 — finish Iron Bull and preserve General Zhao

Continue Asura's Path on the Mac after the opening/forge checkpoint. Execute only this boss-presentation batch and its feasible verification. Read `outputs/post-combat-mac-prompts-2026-11-02/README.md`, its shared contract, the latest combat and opening handoffs and applicable repository rules.

If Windows currently owns the branch for verification, wait for its committed handoff before modifying source/assets. Preserve its fixes. Inspect current installed assets before authoring: Stage 3A or newer work may already have filled a Bull slot.

## 1. Establish the actual installed contract

Read the current BossRoster, BossAttackCatalog, BossArmaments, WeaponExpansion, BossAnimationRules, AnimationCatalog, BossSkin, BossBodies, CostumeSchema, BossAnimations, BossDuo, BossTactics and relevant movement/trajectory data. Consult:

- `outputs/post-f26-step6-2026-10-26/README.md`
- `outputs/post-f26-step4-5-2026-10-26/STEP6_TWINS_ASSET_BRIEF.md`
- `assets/animations/general_zhao/manifest.json` and `published.json`
- Existing Zhao authoring/rig/bake tools and the current source-availability handoff.

Old briefs are historical when newer code/assets disagree. Zhao already has 59 published clips. Preserve his model and animation package; review actual playback and fix demonstrated faults. Do not regenerate him to satisfy an old placeholder brief.

IronBullMaul is an existing boss-only arm with maul/shield semantics. Keep it outside the player registry, inventory and drops. Derive all slots and phase/oath variants from the current encounter; old counts of 11 slots are not a substitute for current coverage inspection.

## 2. Complete the Bull's production body and import proof

Use a few focused concept studies if Claude Design is available, then the existing Blender workflow for the real mesh/material/rig work. Missing concept tooling is not a blocker to production work with the established brief.

Make Bull Zhao's wide, heavy counterpart: iron construction, horned helm, credible face/visor, bronze/amber accents, ox-hide, tower shield and short-hafted maul. Preserve scale, reach, hurtbox relationship and rear punish readability. Reuse compatible technical foundations without cloning Zhao's silhouette.

Resolve shoulder/neck/elbow/hand/knee articulation, maul grip and shield binding before ornament. Author proper meshes, UV/materials and editable sources; preserve existing masters. Prove a representative textured import and pose on the actual final game rig before finishing the whole package. Record pivots, scale and loader contracts. Do not count a Blender turntable as gameplay acceptance.

## 3. Author the active encounter, then integrate

Cover every motion currently exercised: stance/guard, directional locomotion and turns, each maul combo hit, heavy/running/art, shield ram, Iron Charge, Colossal Hammer and its pulses, defense/reactions, posture break/recovery, death and oath/partner-fall transitions. Include attacks inherited after Zhao dies and any required distinct aim/pulse behavior.

Use the completed Stage 3 playback/contact interfaces. Match server anticipation, commitment, impact/pulse times, reach and recovery, with visible shield-facing and back punish. Reuse valid locomotion/reaction foundations only where the final proportions support them. Check foot plants, maul/body penetration, offhand/shield clearance and transitions on the imported model, from gameplay distance.

Authored and procedural motion must have a defined joint owner. Prevent double root movement, late state restart and hitstop/phase-correction conflicts. If current authority and a correct visible motion cannot agree, reproduce and document the defect; do not conceal it with a drawn arc, cosmetic oversized reach or arbitrary damage/timing edits.

Publish through the existing authorized workflow when available, verify permissions and read-back, register assets/native libraries, and reproduce them from a fresh canonical build. Preserve IDs and authoring sources. If upload/import or a necessary local-only master is unavailable, complete independent work, state exact blockers and prepare the missing transfer/Windows action. Unpublished or unplayed clips remain pending.

## 4. Focused Mac checks and Windows handoff

On Mac, verify representative imported pose/scale/materials, slot loading and phase-locked playback in the running game. Test Bull alone and feasible duo diagnostics through both partner-fall orders, including running attacks and oath inheritance. Use seeded setups only for the phases they prove; use normal health/input for ordinary fight observations. Inspect camera clearance, shield feedback, turn ownership, cues, interruptions and retry cleanup. Preserve Zhao's playback and fix only reproduced faults.

Reuse Iron Bull, boss encounter/runtime/presentation, Twins/Monastery and changed animation/geometry tests. Add missing assertions that detect real slot/phase/ownership defects. Run required full verification and canonical build. Capture normal-camera real-speed clips with disclosed conditions; keep human fairness and earned victory open when not actually established.

Save `outputs/mac-followup-2026-11-02/iron-bull/RESULTS.md` and the shared HANDOFF: per-action authored/shared/fallback/missing coverage, assets/sources, build identity, completed checks and runnable Windows cases. Specifically request both kill orders, running/charge/pulse variants, actual player defensive timing, camera comfort, performance and human duel/duo judgments. If shared combat/animation code changed after a Windows pass, identify affected checks requiring repetition.

Clean owned QA, preserve unsaved masters, rebuild/verify reviewed source, update PROJECT_STATE in at most 60 words, commit/push this batch and stop. `03_ARMOUR.md` is the next queued batch; do not start another boss automatically.

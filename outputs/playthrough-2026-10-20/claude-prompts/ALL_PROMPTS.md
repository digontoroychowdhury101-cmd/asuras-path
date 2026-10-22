# Copy-and-paste Claude repair sequence

Send 00 once, then one numbered work block at a time. Stop between prompts so Claude can implement and verify each batch. These prompts target all 44 findings; PROGRESS.md tracks results and remaining dependencies.

## 00 — Shared operating brief

```text
You are fixing Asura's Path in /Users/digonto/Documents/ChatGPT/Roblox game 2. I will send numbered batches sequentially. Implement the current batch; stop after its implementation, focused verification and progress update. The full sequence is authorized within the existing local project. Resolve routine implementation choices yourself.

Read CLAUDE.md, applicable repository instructions, PROJECT_STATE.md and default.project.json at the start of a new chat. Then read outputs/playthrough-2026-10-20/claude-prompts/PROGRESS.md. Reuse this context within the chat. For each batch read only its assigned findings in outputs/playthrough-2026-10-20/PLAYTEST_REPORT.md, relevant evidence and the source dependencies needed to change them. Use rg and targeted reads; avoid repeatedly dumping the report, whole repository or large logs.

The report contains 44 findings: observed failures, source findings and design improvements. It is not a completed campaign test. The tester killed one normal enemy; later boss starts used teleports/camera assistance; no boss clear or ending was established. Verify proposed causes before changing them. Do not reduce boss difficulty to compensate for delayed tool input. Lin's remote projection is intentional.

Preserve existing uncommitted work, profile data, stable IDs/migration compatibility, the 1.4x tempo, 60 Hz server-authoritative combat/rewind architecture, 12-weapon registry, Sakura/wuxia direction and imported shrine centerpiece. Follow the current schema/asset workflow. Edit code directly in src/, tools/ and default.project.json; documentation/progress updates are allowed. Preserve saved .rbxlx/.zip files, work/bin and existing binary assets. Do not publish/deploy as part of these local repair batches.

Use strict Luau, focused new ModuleScripts under 150 lines, task APIs, modern constraints and workspace:Raycast. Register new modules in default.project.json and connect them to the actual runtime. Extend existing systems/components before adding competing versions. Keep changes confined to the batch and necessary shared dependencies; avoid unrelated refactors or new gameplay systems.

For art batches, inspect live asset attachment first and use available approved assets/authoring tools. When essential external meshes/animations are unavailable, complete useful local implementation and record the exact asset/rig/import deliverable still required. A recolored primitive, stub, generated asset name or untested asset manifest does not complete production art. Continue independent work and identify the real missing input.

Verification must match the claim: focused meaningful regressions for state/resource/security logic; compile/build and actual view/play checks for presentation. Reuse passing checks; broaden only for changed dependencies, failures or outstanding risks. Run an available Rojo build when source registration/tree changes. Report unavailable tools/checks honestly. Keep earned play, seeded diagnostics, emulation, mocks and live/hardware tests distinct; clean up temporary helpers.

After each batch update PROGRESS.md with implementation status, checks/evidence and exact remaining dependencies; append at most 80 words to PROJECT_STATE.md. Within a continuing chat, read only relevant tracker rows and recent handoff notes. A finding with multiple assigned batches stays open until all its work is satisfied. Use Implemented/pending acceptance when Studio, art or human play is outstanding. Mark Verified only with appropriate evidence. Preserve earlier progress instead of rewriting it optimistically.

Keep the response brief: what changed, focused check results, and remaining dependencies; finish with two concise manual test steps. No long code dumps, exhaustive logs or a new whole-project audit each turn. Ask only for genuinely missing information or unavailable external action that prevents the next dependent step.

Retain this brief and wait for the first numbered batch. In a later new chat, load the ledger and resume the batch I provide.
```

## 01 — Checkpoint, death and recovery lifecycle

```text
Continue Asura's Path repairs — batch 01/26: Checkpoint, death and recovery lifecycle.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #1, #18, #19 only, plus relevant evidence. Implement this batch now.

Reproduce the later-altar respawn failure before changing it. Trace active-altar selection, respawn hooks/overrides, character admission, region detection and the Sanctuary fall-return safeguard. The observation is correct altar attributes followed by position near (0,603,920); the root cause is still unproven.
Implement reliable respawn at every kindled altar with a safe standing position, correct resource refill, region/objective refresh and boss reset. Preserve bloodstain loss/recovery rules, including second death with zero carried currency, and prevent duplicate loss or rewards during respawn/reconnect.
Separate legitimate Sanctuary fall recovery from ground-region travel and normal respawning. Add a focused lifecycle regression for the actual cause rather than disabling the safeguard globally. This batch owns state correctness; HUD transition polish belongs to batch 04.

Start near these files; follow only necessary dependencies:
- src/server/CharacterService.luau
- src/server/Services/WorldService.luau
- src/server/Services/SanctuaryService.luau
- src/server/Bootstrap.server.luau

Acceptance and focused verification:
Test Monastery Gate and Cloister rest -> enemy death -> correct local respawn; then cover all remaining altars, boss death/reset, legitimate Sanctuary fall, and recover/die-again behavior. Use existing progression/profile tests where relevant. Report exact observed positions and active altars when Studio is available.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 02 — One consistent input and interaction map

```text
Continue Asura's Path repairs — batch 02/26: One consistent input and interaction map.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #5, #6, #37 only, plus relevant evidence. Implement this batch now.

Resolve the Z/E interaction mismatch and E spell overlap through one authoritative binding/interaction definition. Default keyboard scheme: Z interacts, E remains spell slot 2, J opens Codex, and K swaps weapons. Preserve the other established combat/movement keys unless a demonstrated collision requires adjustment.
Apply the same interaction ownership to NPCs, altars, caches, lore, fog gates and bloodstains. A visible prompt must own the matching input without causing duplicate remote intents. Synchronize controller/touch equivalents, displayed prompts, action bar and control references.
Resolve the J Codex/Swap collision. Generate or derive displayed bindings from the shared map, including spells, Arsenal, cursor release and shoulder switching. Retain server proximity/life/combat validation. This batch changes bindings/reference content; controls panel positioning belongs to batch 04.

Start near these files; follow only necessary dependencies:
- src/client/Controllers/InputController.luau
- src/client/Controllers/SpellController.luau
- src/client/Controllers/DialogueController.luau
- src/client/Controllers/ControlsCard.luau
- src/server/Services/LootWorld.luau
- src/server/Services/NarrativeWorld.luau

Acceptance and focused verification:
Exercise each object type just inside/outside interaction range, typing in a text box, overlapping prompts, held input and open menus. Confirm Z recovery never casts a spell, E still casts when allowed, and J/K each perform exactly one action. Validate keyboard/controller/touch mapping conflicts with focused checks.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 03 — Readable combat lighting and stable audio cleanup

```text
Continue Asura's Path repairs — batch 03/26: Readable combat lighting and stable audio cleanup.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #2, #7, #36 only, plus relevant evidence. Implement this batch now.

Fix two presentation blockers together. First, inspect EnvironmentProfiles.resolve and the per-client transition: every first-phase boss currently receives Ash Colosseum night lighting. Give each biome an intentional combat treatment with readable actors, weapons, floor boundaries and sufficient neutral fill across the whole arena. Keep phase-two changes atmospheric without hiding telegraphs. Inspect brazier coverage instead of relying on bright temporary attack effects.
Second, reproduce and fix the repeated locked-Parent exceptions in SpatialAudio.at. Make sound/source cleanup idempotent across Ended, Debris, parent destruction, voice eviction and shutdown; retain bounded cleanup for assets that fail loading.
Reduce decorative petals/ambient effects during active fights so warning cues remain dominant. Expose a small shared effects preference hook for batch 25 rather than building another settings system. Preserve the existing shrine palette and avoid a global fullbright workaround.

Start near these files; follow only necessary dependencies:
- src/shared/EnvironmentProfiles.luau
- src/client/Controllers/EnvironmentController.luau
- src/server/Services/ArenaLighting.luau
- src/client/Controllers/SpatialAudio.luau
- src/client/Controllers/SakuraHud.luau

Acceptance and focused verification:
Capture the six arenas at normal play distance during idle combat lighting and any phase transition accessible to testing. Exercise repeated hits, parries, rest, death and sound/source destruction; verify no cleanup exceptions or growing orphan sources. Compare report screenshots and runtime-evidence.txt. Do not claim an audio listening assessment from logs alone.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 04 — HUD layout, health readability and death transitions

```text
Continue Asura's Path repairs — batch 04/26: HUD layout, health readability and death transitions.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #12, #17, #18, #33, #34, #35, #36 only, plus relevant evidence. Implement this batch now.

Repair the current Sakura HUD without replacing its visual identity. Put the H controls card in a reserved region or proper modal so it cannot overlap the action bar. Remove redundant default Roblox health/player-list elements where they duplicate or cover game information; keep unrelated core functions usable.
Consolidate enemy/target labels, prevent crowded nameplates and show the Twins with separate, stable actor identification and understandable health/posture bars. Make flask count, life, stamina/posture, Qi and carried currency readable; distinguish currency from spell energy using the actual data model.
Show the changing health ceiling/recoverable damage and rally window through shape/animation/short labels, not color alone. Hide irrelevant combat labels, prompts, petals and bars during prologue, death and dialogue, restoring them correctly afterwards. Improve priority among damage numbers, counter text and warnings. Reuse existing UI components; avoid a broad UI-framework rewrite.

Start near these files; follow only necessary dependencies:
- src/client/Controllers/ControlsCard.luau
- src/client/Controllers/CombatHud.luau
- src/client/Controllers/EnemyBars.luau
- src/client/Controllers/EnemyPlate.luau
- src/client/Controllers/TargetPlate.luau
- src/client/Controllers/BossHud.luau
- src/client/Controllers/SakuraHud.luau
- src/client/Controllers/InterfaceController.luau

Acceptance and focused verification:
Inspect default HUD, H opened, two nearby enemies, Twins, reduced health ceiling, low flask count, boss entry, death/respawn and dialogue. Check a small and wide desktop viewport. Verify transitions restore state without stale labels. Avoid changing combat math in this layout batch.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 05 — Rest, Lin dialogue and leveling flow

```text
Continue Asura's Path repairs — batch 05/26: Rest, Lin dialogue and leveling flow.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #4, #38, #39, #40 only, plus relevant evidence. Implement this batch now.

Make rest immediately set the checkpoint/refill resources, followed by a clear altar menu with deliberate Travel and Summon Lin/Ascension choices. Preserve Lin's intentional remote spirit projection; it was not an NPC-proximity exploit. Keep travel accessible after interacting with her.
Give physical NPC and projection conversations an unobstructed portrait shot, collision-aware fallback and consistent modal style using the existing UI kit. Hide unrelated prompts/objectives while appropriate, and reliably restore camera/input on close, death, replacement dialogue and respawn. Coordinate with the geometry repairs in batch 07.
Improve leveling with source-derived before/after benefits, cost and currency remaining. Use readable labels such as Arcane Qi, distinguish currency from spell resource, and keep long attribute lists inside a clear scroll region. Preserve current stat formulas and schema compatibility.

Start near these files; follow only necessary dependencies:
- src/client/Controllers/DialogueController.luau
- src/client/Controllers/DialogueView.luau
- src/client/Controllers/InterfaceController.luau
- src/server/Services/DialogueService.luau
- src/server/Services/DialogueActions.luau
- src/shared/ProgressionRules.luau

Acceptance and focused verification:
At Sanctuary, Gate and Cloister: rest, open/close Lin, level if affordable, return to altar, travel and resume movement. Test portrait clearance from both shoulders and with nearby fire/stone. Validate insufficient currency, exactly-once purchase, displayed derived benefits and closing during death.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 06 — Useful Arsenal descriptions and Codex progress

```text
Continue Asura's Path repairs — batch 06/26: Useful Arsenal descriptions and Codex progress.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #41, #42 only, plus relevant evidence. Implement this batch now.

Improve information in the existing Arsenal and Codex. Spell cards need a short functional description, targeting/range, important effects, Qi cost and cooldown. Weapon cards need playstyle/reach/weight and a useful comparison based on real schemas and equipped state. Use current scaling functions for any numbers; avoid invented or duplicated balance values.
Make slot 1/2 labels unmistakable in the actual font and display the binding chosen in batch 02. Keep touch/controller selection and scrolling usable.
Give Codex a useful empty state, discovered/total inscriptions and sovereign progress, clear sections and a brief discovery instruction. Populate entries only from legitimate discovered flags; keep undiscovered lore appropriately hidden. Inspect empty, partial and complete layouts. Preserve existing narrative writing unless clarity requires a small edit.

Start near these files; follow only necessary dependencies:
- src/client/Controllers/ArsenalTabs.luau
- src/client/Controllers/ArsenalPanel.luau
- src/client/Controllers/DialogueView.luau
- src/client/Controllers/DialogueController.luau
- src/shared/ArsenalCatalog.luau
- src/shared/NarrativeCatalog.luau
- src/simulation/SpellSchema.luau

Acceptance and focused verification:
Inspect both starting spells/weapons, a seeded diagnostic owned item, all three Arsenal tabs, empty/partial/full Codex and long text. Seeded state only proves layout, not earned unlock delivery. Ensure menus neither expose undiscovered rewards as owned nor leave movement/menu state stuck.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 07 — Monastery collision, altar clearance and arrival repairs

```text
Continue Asura's Path repairs — batch 07/26: Monastery collision, altar clearance and arrival repairs.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #3, #4, #26, #27, #29, #30 only, plus relevant evidence. Implement this batch now.

Repair the walked opening route before adding more decoration. Diagnose the bridge swordsman's actual spawn/root height, walkable surface, navigation, collision and melee/spell contact; its marker appeared against a tall central stone obstruction. Fix the demonstrated cause and preserve an appropriate bridge fight.
Create an open approach/standing/exit pocket around Desecrated Cloister's altar and clear space for batch 05's portrait camera. Audit other existing altar anchors for the same issue.
Address the empty walkable exterior and wall/ravine bypasses deliberately: mark intended shortcuts and give them a destination, or constrain unintended access with believable terrain/architecture. Retain the wuxia mobility system.
Make Monastery portal arrival face a safe, readable checkpoint view. Correct Sanctuary objective wording to name the immediate portal destination, then the next route leg. This is a functional route repair, not the larger Monastery art pass in batch 15.

Start near these files; follow only necessary dependencies:
- src/server/Services/MonasteryService.luau
- src/server/Services/MonasteryGrounds.luau
- src/server/Services/MonasteryRuins.luau
- src/server/Services/WorldService.luau
- src/shared/WorldDefinitions.luau
- src/shared/Objectives.luau

Acceptance and focused verification:
Walk both bridge directions and exchange real hits with the swordsman; approach/rest/leave the Cloister from both shoulders. Test jump/double jump/wall and ravine cases, portal arrival, objective copy and nearby altar visibility. Do not treat coordinate checks alone as proof of physical clearance.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 08 — Earned remembrance and complete boss reward pipeline

```text
Continue Asura's Path repairs — batch 08/26: Earned remembrance and complete boss reward pipeline.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #8, #9 only, plus relevant evidence. Implement this batch now.

Fix token ownership through the actual inventory -> synchronization -> Arsenal -> Gao -> forge flow. ArsenalInventory stores remembrance token objects while ArsenalTabs checks == true. Align validation/display with the schema, handle valid migrated data and preserve exactly-once consumption.
Audit the six current bosses: Grandmaster Shen, Venerable Baize, Slumbering Titan, Sovereign Wu, Twin Sentinels and Azure Wyrm. Provide coherent weapon-or-spell transmutation choices for each using existing authored weapon/spell capabilities where suitable. Preserve the 12-weapon registry. Shen's two token awards are intentional in current code; evaluate rather than automatically deleting them.
Resolve obsolete Ash Pagoda General references through compatible IDs/aliases or migration so existing saves retain earned value. Ensure every reward is obtainable, inspectable and usable and that defeat replay/reconnect cannot duplicate it. Keep forge proximity, authoritative eligibility and the existing confirmation step.

Start near these files; follow only necessary dependencies:
- src/simulation/ArsenalInventory.luau
- src/shared/ArsenalCatalog.luau
- src/server/Services/LootService.luau
- src/server/Services/WorldService.luau
- src/client/Controllers/ArsenalTabs.luau

Acceptance and focused verification:
Cover token object/legacy data, unowned/owned/spent display, one successful choice, unavailable second choice, duplicate defeat, duplicate forge request and reconnect. Use focused progression/weapon-spell regressions. Demonstrate one earned boss -> enabled recipe -> forge -> equip path when live play is available; label seeded award tests separately.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 09 — Attack contact, full-health healing and enemy deaths

```text
Continue Asura's Path repairs — batch 09/26: Attack contact, full-health healing and enemy deaths.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #14, #20, #21 only, plus relevant evidence. Implement this batch now.

Make melee outcomes legible. Diagnose actual whiffs/contact before changing damage: check reach, actor spacing, attack animation/VFX alignment and geometry. Distinguish a whiff, deliberate guard-during-startup feint, block, hit and deathblow through coherent feedback. Retain server authority, rewind logic and the existing feint rule; do not lengthen hitboxes just to hide a placement problem.
Prevent an ordinary heal at full currently healable health from consuming a flask, with short clear feedback; retain intentional healing rules for a reduced ceiling and any valid secondary effect. Keep the flask count visible using batch 04.
Replace the killed monk's loose block breakup with a bounded collapse/dissolve presentation consistent with existing assets. Remove labels/reticles promptly and show reward feedback. Corpses/effects should not obstruct navigation or accumulate indefinitely.

Start near these files; follow only necessary dependencies:
- src/server/CharacterService.luau
- src/simulation/CombatRules.luau
- src/client/Controllers/CombatFeedback.luau
- src/client/Controllers/CombatVfx.luau
- src/client/Controllers/CombatCallouts.luau
- src/client/Controllers/EnemyBars.luau

Acceptance and focused verification:
Exercise hits just inside/outside reach, intentional feint, guarded strike and actual hit. Test full-health/partial-health/reduced-ceiling/no-flask healing and exactly-once resource use. Kill several enemies and verify reward/state correctness, prompt label removal and bounded corpse cleanup. Tune damage only if a separately demonstrated defect requires it.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 10 — A playable opening tutorial and clean prologue handoff

```text
Continue Asura's Path repairs — batch 10/26: A playable opening tutorial and clean prologue handoff.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #11, #12, #13, #15, #19, #43, #44 only, plus relevant evidence. Implement this batch now.

Build a short, integrated opening teaching sequence using the real combat/movement systems. Show the character only after a deliberate spawn pose/view is ready; cleanly hand off from skippable prologue to rest and training.
Teach lock-on, light hit, deflect/guard, dodge, heal and deathblow in manageable steps, then Blood Rally/reduced health ceiling, a perilous counter and the actual Air Glide input from batch 02. Establish a readable single duel before the two-monk group, with spacing/aggro that permits learning.
Explain carried currency and recover-before-second-death stakes before the first likely loss. Place one clearly discoverable inscription/cache opportunity on the opening route and teach its reward/Codex update, preserving later optional secrets.
Keep instruction short and input-device aware, offer replay/skip, and make state cleanup safe on death/rejoin. Existing profiles must keep their progress. Use actual success events rather than advancing tutorial steps on button presses alone.

Start near these files; follow only necessary dependencies:
- src/client/Controllers/PrologueController.luau
- src/client/Controllers/InputController.luau
- src/shared/NarrativeCatalog.luau
- src/server/Services/NarrativeWorld.luau
- src/server/Services/WorldService.luau
- src/shared/WorldDefinitions.luau

Acceptance and focused verification:
Run a fresh-profile opening through the first taught duel/discovery, then test skip, replay, death midway and an existing save. Verify no permanently invulnerable trainer/player or locked input leaks into ordinary play. If continuous-input deflect timing cannot be tested, mark that acceptance pending rather than weakening combat to pass automation.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 11 — Shen and Twin Sentinels presentation and fair entry

```text
Continue Asura's Path repairs — batch 11/26: Shen and Twin Sentinels presentation and fair entry.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #16, #17, #23 only, plus relevant evidence. Implement this batch now.

Limit character/encounter work to Grandmaster Shen and the Twin Sentinels. Audit why intended skins are absent or fall back to block bodies; inspect actual template IDs, phase names, bone/bind contracts, validation and attachment. Repair reusable skin/animation plumbing, then make these actors read as distinct wuxia combatants using valid available assets and authored poses/materials.
Give Zhao and Iron Bull clearly different silhouettes, weapons/roles and stable target identification, coordinating with batch 04's separate bars. Preserve the duo's existing mechanical identity; verify target switching and intended separation behavior.
Fix the shared boss-entry handoff where necessary: protection/AI sequencing must cover cinematic loss of control and end when readable player control resumes. Camera and combat states must restore on skip, death, retry and cancellation. Avoid blanket damage reductions based on the assisted playtest.
When a required production model/animation is unavailable, complete the binding/tooling work and record the exact asset deliverable still required; colored primitives do not close the visual finding.

Start near these files; follow only necessary dependencies:
- src/server/Services/BossSkin.luau
- src/server/Services/BossAppearance.luau
- src/server/Services/BossDuo.luau
- src/server/Services/AIService.luau
- src/client/Controllers/BossAnimations.luau
- src/client/Controllers/BossCinematics.luau

Acceptance and focused verification:
Inspect both Shen phases and both Twins at normal camera distance, actual skin attachment/weapon alignment, first attack timing, target switching and entry/retry/cancel. Test shared entry logic against the other bosses as a regression, without redesigning their content in this batch.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 12 — Baize and Titan creature presentation

```text
Continue Asura's Path repairs — batch 12/26: Baize and Titan creature presentation.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #13, #16, #23 only, plus relevant evidence. Implement this batch now.

Apply the validated skin pipeline from batch 11 only to Venerable Baize and Slumbering Titan. Make Baize read as the intended beast and Titan as a colossal ancient rather than scaled block humanoids. Use existing approved models/authoring tools, real rig/bone bindings, materials and readable locomotion/attack poses.
Match visible body/weapon placement to authoritative hurtboxes, reach and ground contact. Check Titan's ankles and camera clearance, Baize's sweep/charge silhouette and any pillar movement. Preserve encounter rules and the 1.4x tempo; do not disguise missing animation with extra particles.
Make phase changes visibly distinct without obscuring Air Glide/evade/deflect cues, using the input teaching from batch 10. Verify large actors do not clip below floors or get stuck on props.
For unavailable external art, finish local integration/validation and provide exact dimensions, rig, phase variants, attachments and import requirements in the ledger; leave the art item explicitly open.

Start near these files; follow only necessary dependencies:
- src/server/Services/BossSkin.luau
- src/server/Services/BossAppearance.luau
- src/server/Services/BossMotion.luau
- src/server/Services/BossTactics.luau
- src/client/Controllers/BossAnimations.luau
- src/shared/BossRoster.luau

Acceptance and focused verification:
Check both actors and both phases in lit arenas, ground/hurtbox alignment, sweeps/gap closers, relevant counters, large-body camera clearance and repeat entry/death. Separate asset-preview checks from real combat acceptance and keep any missing production assets visible in progress.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 13 — Wu and Azure Wyrm presentation

```text
Continue Asura's Path repairs — batch 13/26: Wu and Azure Wyrm presentation.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #16, #23 only, plus relevant evidence. Implement this batch now.

Limit this pass to Sovereign Wu and Azure Wyrm, reusing the repaired asset pipeline. Give Wu a readable oracle/sorcerer identity and Wyrm a convincing creature/dragon silhouette, body and animated wings instead of the observed humanoid with simple wing lines. Use valid available assets and deliberate materials/poses.
Align visual attacks, casting, teleport/aerial motion and landing with server hit areas and hazards. Make bodies and weapons readable before an effect fires; preserve the biome lighting work from batch 03 and keep floor telegraphs clear.
Implement/verify phase appearance and animation changes, entrance restoration and post-defeat cleanup. Preserve current encounter identity and avoid balance changes justified only by delayed tool input.
If the production rig/animations cannot be created or accessed locally, complete the import/binding validation and list the exact missing asset deliverables. Do not mark the creature presentation complete from a source stub or a recolored placeholder.

Start near these files; follow only necessary dependencies:
- src/server/Services/BossSkin.luau
- src/server/Services/BossAppearance.luau
- src/server/Services/BossMotion.luau
- src/server/Services/BossAttackService.luau
- src/server/Services/BossHazards.luau
- src/client/Controllers/BossAnimations.luau

Acceptance and focused verification:
Inspect both phases, normal play-distance silhouettes, Wu casting/teleport, Wyrm flight/landing, attack area alignment, entry/retry/death and cleanup. Record preview, seeded phase and actual-play evidence separately.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 14 — Player, NPC and normal-enemy visual identity

```text
Continue Asura's Path repairs — batch 14/26: Player, NPC and normal-enemy visual identity.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #24 only, plus relevant evidence. Implement this batch now.

Bring the common humanoid cast up to a coherent wuxia presentation while retaining the Sakura UI and existing shrine centerpiece. Improve the player outfit/head/hair/body presentation, Lin, Gao, the Hermit and ordinary enemy types through reusable rigged costume/accessory/material components.
Give each NPC a recognizable silhouette and readable face/portrait subject. Give normal enemies visually meaningful roles and weapon handling. Ensure authored assets actually attach to live spawned characters instead of merely existing in storage.
Keep visual parts non-colliding as appropriate, preserve animation joints, server hurtboxes and gameplay readability, and avoid breaking user-avatar compatibility if currently supported. Reuse approved assets before inventing a new character-generation framework.
Use local authoring/import tooling available in the project. Missing external art needs an exact production brief and working integration contract, with the associated finding still open until real assets appear in Studio.

Start near these files; follow only necessary dependencies:
- src/server/CharacterService.luau
- src/server/Services/NarrativeWorld.luau
- src/server/Services/PresentationService.luau
- src/server/Services/PbrAssets.luau
- src/shared/PresentationAssets.luau

Acceptance and focused verification:
Inspect player spawn/respawn, each NPC portrait, normal-enemy roles and weapon animations under Sanctuary and Monastery lighting. Verify no extra collision, rig breakage or excessive per-character asset cost, and that appropriate fallback behavior is visible and diagnosed.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 15 — Monastery environment and navigable discovery route

```text
Continue Asura's Path repairs — batch 15/26: Monastery environment and navigable discovery route.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #25, #26, #27, #28, #32, #44 only, plus relevant evidence. Implement this batch now.

Complete an authored Monastery pass within the existing route, building on batch 07's collision repairs. Give the gate, courtyard, bridge and Cloister distinct silhouettes, combat pockets, wear, cover and environmental storytelling. Replace mismatched architectural/material treatment with the established wuxia ruin vocabulary, reusing good existing assets.
Develop the intended exterior secret route with a clear destination/reward or finish believable boundaries. Respect wall/double-jump/ravine movement and enemy leashes.
Make wayfinding follow walkable turns, bridges and portal legs through lightweight route targets/landmarks rather than a new global navigation framework. A bloodstain beyond a portal should first guide to the usable portal.
Physically validate the four Monastery inscriptions and three Monastery caches, including the high cache, with legible interaction space and intentional traversal. Keep optional secrets optional; the first taught discovery comes from batch 10.

Start near these files; follow only necessary dependencies:
- src/server/Services/MonasteryService.luau
- src/server/Services/MonasteryDressing.luau
- src/server/Services/MonasteryLandmarks.luau
- src/server/Services/MonasteryRuins.luau
- src/client/Controllers/ObjectiveController.luau
- src/client/Controllers/WaypointMarker.luau
- src/shared/ArsenalCatalog.luau
- src/shared/NarrativeCatalog.luau

Acceptance and focused verification:
Walk Gate -> courtyard -> bridge -> Cloister in both directions, fight in the pockets and retrieve every assigned cache/tablet with normal mobility. Check portal-aware recovery guidance, shortcuts, boundaries, art scale and collision; captures must be from character height.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 16 — Sanctuary framing, terrace and optional routes

```text
Continue Asura's Path repairs — batch 16/26: Sanctuary framing, terrace and optional routes.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #27, #28, #31, #32 only, plus relevant evidence. Implement this batch now.

Refine the existing Sanctuary around the current colossal veiled figure/tree, preserving their imported art, scale and central axis. Add intentional reveal points while walking from plaza through stairs/landing to the terrace; maintain a clear bonfire, gate, forge and Colosseum route.
Audit the enlarged terrace edge, roots, stairs, parapets, camera clearance and fall-return behavior at character height. Keep the statue/tree visually dramatic while ensuring landing/route silhouettes remain readable. Use the material/architecture vocabulary established in batch 15.
Make both Sanctuary caches physically reachable through deliberate traversal, and make the Sunken Crypt portal and return leg understandable. Preserve optional discovery without confusing the main story exit.
Implement composition/layout/collision changes through supported source/configuration; keep existing saved place and imported binary assets intact.

Start near these files; follow only necessary dependencies:
- src/server/Services/SanctuaryService.luau
- src/server/Services/SanctuaryColossus.luau
- src/server/Services/SanctuaryTitan.luau
- src/server/Services/SanctuaryDressing.luau
- src/shared/WorldDefinitions.luau
- src/server/Services/LootWorld.luau

Acceptance and focused verification:
Walk plaza -> stairs -> landing -> terrace edge and back, both cache routes, forge, Colosseum and Crypt portal. Inspect the full composition at natural camera angles, collision/fall return and checkpoint/portal regressions. Do not approve the route solely from an overhead render.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 17 — Build the Bamboo Pass region

```text
Continue Asura's Path repairs — batch 17/26: Build the Bamboo Pass region.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #22, #27, #28, #32, #44 only, plus relevant evidence. Implement this batch now.

Replace Bamboo Pass's flat blockout with one cohesive playable region using the project's established assets and procedural/source workflow. Author a bamboo pass/ridge route from the Monastery exit to Whispering Bamboo Shrine, Baize's arena and the Ash Colosseum connection. Include a readable main path, one purposeful traversal/optional route, safe altar pocket and spaced combat encounters.
Give the region distinct bamboo/frosted-ridge landmarks, terrain elevation, boundary silhouettes and local storytelling. Preserve deliberate wuxia mobility, a readable Baize arena including usable pillars, checkpoint placement and clear portal/route guidance.
Place and physically validate both Bamboo Pass inscriptions with real standing/reading space. Keep the scene within sensible part/light/effect budgets and reuse the shared region/route conventions.
Finish this region's route and presentation only; do not start rebuilding adjacent regions or redesigning Baize's mechanics.

Start near these files; follow only necessary dependencies:
- src/shared/WorldDefinitions.luau
- src/server/Services/WorldService.luau
- src/server/Services/BossArenas.luau
- src/shared/EnvironmentProfiles.luau
- src/shared/NarrativeCatalog.luau

Acceptance and focused verification:
Walk the complete region connection and optional branch, kindle/respawn/travel, read both inscriptions, fight normal enemies and enter/leave/reset Baize. Verify bounds, jumps, nav, camera and idle combat lighting at character height. Leave unavailable imported art explicitly listed rather than calling a blockout finished.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 18 — Build the Ash Colosseum campaign region

```text
Continue Asura's Path repairs — batch 18/26: Build the Ash Colosseum campaign region.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #22, #27, #28, #32 only, plus relevant evidence. Implement this batch now.

Replace the campaign Ash Colosseum approach/arena blockout with a coherent ruined martial colosseum route. This is Grandmaster Shen's story region, distinct from the Sanctuary PvP rings. Connect Bamboo Pass through the antechamber altar to Shen, then onward toward Celestial Pagoda.
Create readable ruins, a clear arena identity, purposeful elevation/boundaries, spaced approach combat and a safe altar/portrait pocket. Maintain sufficient fighting room and camera clearance for both Shen forms. Reuse the project's wuxia architecture/material language and batch 03's readable combat lighting.
Preserve validated fog-gate, phase, reward, checkpoint and region IDs. Make the next route visible after victory and avoid new progression locks that can strand existing saves.
Keep the pass limited to this region and its immediate joins.

Start near these files; follow only necessary dependencies:
- src/shared/WorldDefinitions.luau
- src/server/Services/WorldService.luau
- src/server/Services/BossArenas.luau
- src/shared/EnvironmentProfiles.luau

Acceptance and focused verification:
Walk Bamboo join -> antechamber -> arena -> onward connection, including rest/death/travel and camera clearance. Check Shen's two forms against geometry/hazards and confirm the Sanctuary PvP area is unchanged. Use normal-view captures and distinguish seeded victory access from earned progression.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 19 — Build Sanctuary Depths and the Sunken Crypt

```text
Continue Asura's Path repairs — batch 19/26: Build Sanctuary Depths and the Sunken Crypt.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #22, #27, #28, #32 only, plus relevant evidence. Implement this batch now.

Turn Sanctuary Depths into the Sunken Crypt promised by Titan's encounter. Build a coherent descent/arrival, crypt exploration route, incense checkpoint, Titan chamber and return connection. Give the crypt readable depth, scale, ruins and controlled sightlines without recreating the near-black visibility problem.
Provide enough room and ground support for Titan, legible ankle/weapon combat, safe camera placement, honest boundaries and deliberate optional traversal. Make portal arrival/return and recovery guidance obvious.
Preserve region/checkpoint IDs, defeated flags and existing portal semantics, and reuse shared construction/lighting components. Ensure the Sanctuary safety catch does not intercept legitimate underground-region play.
Limit new content to this region; prioritize an actually walkable complete route over dense repetitive decoration.

Start near these files; follow only necessary dependencies:
- src/shared/WorldDefinitions.luau
- src/server/Services/BossArenas.luau
- src/server/Services/WorldService.luau
- src/server/Services/SanctuaryService.luau
- src/shared/EnvironmentProfiles.luau

Acceptance and focused verification:
Traverse Sanctuary -> Crypt -> altar -> Titan -> return, test death/respawn/travel and a ground-level fall/boundary case. Verify Titan camera/hurtbox clearance and idle lighting. Demonstrate that the Sanctuary catch still recovers real shrine falls without teleporting crypt players away.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 20 — Build Celestial Pagoda and its lore route

```text
Continue Asura's Path repairs — batch 20/26: Build Celestial Pagoda and its lore route.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #22, #27, #28, #32, #44 only, plus relevant evidence. Implement this batch now.

Replace Celestial Pagoda's flat floor with an authored multi-level pagoda/rafters route appropriate to Wu. Connect the Ash Colosseum join, incense altar, Wu's arena and Sky Citadel exit through a readable main ascent with deliberate wuxia traversal and one bounded optional route.
Give rafters/stairs/platforms usable widths, camera clearance, collision and landing affordances. Maintain safe altar/portrait space, readable caster sightlines and enough arena space for Wu's movement. Establish distinct landmarks and materials within the shared art direction.
Physically place and validate both Pagoda inscriptions, including the final lore entry, so they are discoverable and readable through actual movement. Keep route/waypoint guidance aware of elevation and usable connections.
Preserve progression IDs and avoid a new mandatory movement trick that the tutorial has not taught.

Start near these files; follow only necessary dependencies:
- src/shared/WorldDefinitions.luau
- src/server/Services/WorldService.luau
- src/server/Services/BossArenas.luau
- src/shared/NarrativeCatalog.luau
- src/shared/EnvironmentProfiles.luau

Acceptance and focused verification:
Walk the full ascent and optional route, read both tablets, rest/respawn/travel, enter/reset Wu and reach the Sky Citadel join. Test falls, narrow-platform camera, jumps and line-of-sight combat with normal mobility.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 21 — Build Sky Citadel and the final approach

```text
Continue Asura's Path repairs — batch 21/26: Build Sky Citadel and the final approach.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #22, #27, #28, #32 only, plus relevant evidence. Implement this batch now.

Complete Sky Citadel as a recognizable summit/citadel route rather than a flat boss floor. Connect the Pagoda exit, final incense checkpoint and Wyrm arena with a legible ascent, strong skyline/reveal and purposeful ruins/weather.
Support established jump/glide movement with readable landings, honest boundaries and recovery paths. Provide adequate air/ground space, visible floor/hazard boundaries and camera clearance for the actual Wyrm rig and flight/landing from batch 13.
Keep the route clear after victory and support returning to Sanctuary for the ending. Reuse shared geometry/material/lighting conventions and sensible asset budgets. Preserve existing profile, altar and boss IDs.
Finish this region and its immediate joins without expanding the campaign or adding another boss.

Start near these files; follow only necessary dependencies:
- src/shared/WorldDefinitions.luau
- src/server/Services/BossArenas.luau
- src/server/Services/WorldService.luau
- src/shared/EnvironmentProfiles.luau

Acceptance and focused verification:
Walk Pagoda -> checkpoint -> summit arena and return, with rest/respawn/travel, edge/fall cases and Wyrm flight/landing clearance. Inspect the final approach and arena in ordinary lighting without attack effects. Verify victory leaves a navigable return route.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 22 — A real six-sovereign ending and postgame handoff

```text
Continue Asura's Path repairs — batch 22/26: A real six-sovereign ending and postgame handoff.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #10, #28, #42 only, plus relevant evidence. Implement this batch now.

Finish the story promise using the six current server-owned defeated-boss flags. After all six, guide the player through the correct return/travel leg to Lin, show her Release dialogue and offer an explicit meaningful Cross or Remain choice.
Implement a deliberate crossing scene/sequence, completion acknowledgement and concise credits using actual project credit records. Provide a clear continue-playing/postgame return that preserves earned gear, discoveries and progress. Remain should allow continued play and later access to crossing. Keep PvP an optional postgame activity rather than the only apparent conclusion.
Make completion state and rewards, if any, idempotent across repeat interaction, death, disconnect/rejoin and interrupted presentation. Update Codex/quest state consistently and keep the ending's camera/UI cleanup robust.
Use the established narrative/art identity and existing assets; keep the scene bounded instead of adding a new campaign chapter.

Start near these files; follow only necessary dependencies:
- src/shared/NarrativeCatalog.luau
- src/shared/Objectives.luau
- src/server/Services/DialogueService.luau
- src/server/Services/DialogueActions.luau
- src/client/Controllers/DialogueController.luau
- src/client/Controllers/PrologueController.luau

Acceptance and focused verification:
Test five/six flags, both choices, revisit, replay/skip, interrupted scene and rejoin without duplicate rewards or lost progress. A seeded six-flag test validates logic only; keep earned six-boss-to-ending acceptance pending until batch 23 actually establishes it. Verify credit entries against project records.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 23 — Single-player campaign integration and remaining fixes

```text
Continue Asura's Path repairs — batch 23/26: Single-player campaign integration and remaining fixes.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #1, #8, #9, #10, #16, #18, #19, #22, #23, #27, #28, #44 only, plus relevant evidence. Implement this batch now.

Validate the integrated solo game using the repair ledger, not a fresh speculative audit. Build/sync the current source and attempt a normal fresh-profile run from prologue through all six bosses, reward/forge progression, all region joins and ending. Exercise a later-checkpoint death/retry, bloodstain recovery and second death, one reinforcement/infusion, mastery/ward behavior where reachable, every altar travel destination, all eight inscriptions and all five caches.
Fix concrete integration failures within the touched systems and add focused regressions for actual causes. Check save/rejoin after meaningful milestones. Reuse earlier evidence and run the relevant regression suites once; broaden only for changed behavior or failures.
Keep normal play evidence separate from diagnostic seeded flags, teleports, automated phase access and headless engine fakes. Use continuous input for meaningful boss fairness/deflect judgments; do not nerf difficulty to compensate for tool latency.
Do not mark a full campaign clear unless it happened. Record exactly what was reached, failures fixed, and any required human/asset/live-service acceptance still pending.

Start near these files; follow only necessary dependencies:
- outputs/playthrough-2026-10-20/claude-prompts/PROGRESS.md
- tools/test_progression_runtime.py
- tools/test_boss_runtime.py
- tools/test_boss_encounters.luau
- tools/test_progression_and_lore.luau
- tools/test_weapons_and_spells_runtime.py

Acceptance and focused verification:
Produce a compact acceptance matrix with actual results and evidence paths for routes, six bosses/phases, retries, rewards/forge, collectibles, travel, ending and rejoin. No source-only or seeded test may be labeled an earned end-to-end completion. Keep follow-up items concrete and scoped.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 24 — Multiplayer and persistence integration

```text
Continue Asura's Path repairs — batch 24/26: Multiplayer and persistence integration.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read the report's remaining multiplayer/persistence verification section only, plus relevant evidence. Implement this batch now.

Cover the report's untested multiplayer/persistence risks as verification work, not presumed defects. Use the existing backend/profile/Colosseum architecture and local Studio tools when available. Test two duelists plus a spectator: matchmaking, countdown closure, ranked-normalized versus Open builds, spectator wager eligibility/settlement and disconnect recovery.
Exercise durable profile/result/escrow behavior for duplicate delivery, retries, stale sessions, leave/rejoin, unavailable persistence and shutdown. Fix demonstrated failures while preserving migration/schema compatibility, authoritative validation and idempotent settlement.
Use isolated test profiles and fixtures. Preserve real player data and existing release gates. Local mocks/fakes do not prove live DataStore delivery; identify any cloud acceptance that cannot be run in the current environment.
Keep this pass limited to reliability and integration. Do not add monetization, new wager rules or unrelated multiplayer features.

Start near these files; follow only necessary dependencies:
- src/server/Services/ColosseumService.luau
- src/server/Services/WagerService.luau
- src/server/PersistenceService.luau
- src/server/ProfileStore.luau
- tools/test_backend.luau
- tools/test_profile_integrity.luau
- tools/test_commercial_systems.luau

Acceptance and focused verification:
Run focused profile/backend/wager regressions and an actual multi-client session where available. Report normalized/open stats, wager/refund cases and reconnect outcomes with local versus live evidence clearly distinguished. Leave unavailable multi-client/cloud checks explicitly pending.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 25 — Device layouts, controls and accessibility

```text
Continue Asura's Path repairs — batch 25/26: Device layouts, controls and accessibility.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #5, #6, #12, #13, #33, #34, #35, #36, #37, #39, #40, #41, #42, #43 only, plus relevant evidence. Implement this batch now.

Verify and repair the existing interface at small desktop, widescreen/ultrawide, phone and tablet sizes, plus keyboard, touch and controller inputs supported by the available tools. Focus on real clipping, overlaps, safe areas, text scale, scrolling, focus navigation and input collisions across HUD, controls, spells, Arsenal, Codex, leveling, dialogue and ending.
Ensure prompts/tutorial/counter hints display the actual active-device bindings from batch 02. Keep life/rally/perilous cues understandable without color alone. Expose reduced decorative effects/motion/flashes and subtitle/text readability through the existing settings model where appropriate, using batch 03's effects hook.
Verify existing sensitivity/FOV and any existing remapping settings persist/revert correctly. Reuse the current UI kit and settings system rather than introducing competing versions.
Emulation establishes layout coverage only; identify physical-device/controller checks still needed. Fix demonstrated issues without reopening art direction or changing combat timing.

Start near these files; follow only necessary dependencies:
- src/client/Controllers/UiWindow.luau
- src/client/Controllers/PauseMenu.luau
- src/client/Controllers/ControlsCard.luau
- src/client/Controllers/SpellHud.luau
- src/client/Controllers/DialogueView.luau
- src/client/Controllers/SakuraHud.luau
- src/client/Controllers/InputController.luau

Acceptance and focused verification:
Record a compact viewport/input matrix with captures, including long text, low-resource HUD, two enemies, boss bar, open controls, dialogue and ending. Verify focus/close/resume, settings persistence/cancel and effect reductions. Label emulated, hardware-tested and untested cases separately.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

## 26 — Performance, audio listening and final coverage audit

```text
Continue Asura's Path repairs — batch 26/26: Performance, audio listening and final coverage audit.

Apply the shared operating brief (outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt; read once per chat) and current PROGRESS.md. Read report findings #2, #7, #21, #23, #24, #25, #31, #32, #36 only, plus relevant evidence. Implement this batch now.

Measure the completed content on the available machine before optimizing. Sample Sanctuary/colossal tree, a normal fight, a populated later region and large/duo boss combat. Record frame-time/FPS observations, memory, relevant part/mesh/light/effect counts, repeated respawn cleanup and network behavior when measurable. Use comparable conditions; make no unsupported universal performance claim.
Fix demonstrated hotspots or leaks with bounded changes such as reuse, cleanup, culling/LOD or effect/light budgets while preserving the tested art, collision and combat. Recheck SpatialAudio lifecycle after repeated combat/rest/death.
Perform an actual audio listening pass if the environment supplies audio: mix hierarchy, hit/block/parry distinction, music transitions, ambience, positional range and failed/unauthorized asset loads. Logs alone cannot pass listening acceptance.
Finally audit all 44 findings and every batch in PROGRESS.md. Link implementation/test evidence, identify any external asset, human-play, device or live-service dependency, and produce a concise remaining-work list. Close only findings whose assigned work and acceptance are satisfied.

Start near these files; follow only necessary dependencies:
- src/server/Services/PresentationService.luau
- src/server/Services/PbrAssets.luau
- src/client/Controllers/SpatialAudio.luau
- src/client/Controllers/SoundscapeController.luau
- src/client/Controllers/BossMusic.luau
- src/client/Controllers/CombatVfx.luau
- outputs/playthrough-2026-10-20/claude-prompts/PROGRESS.md

Acceptance and focused verification:
Report before/after measurements for any optimization, repeated-session cleanup results and actual audio-listening coverage. Complete the evidence-backed 44-item disposition table: verified, implemented/pending acceptance, or explicitly blocked with the exact missing input. Do not issue a blanket all-fixed verdict while production art or earned-play checks remain open.

Update the repair ledger and PROJECT_STATE.md. State implementation versus verification precisely, then stop at this batch boundary.
```

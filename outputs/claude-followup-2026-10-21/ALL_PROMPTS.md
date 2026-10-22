# Copy-and-paste follow-up sequence

Send the shared brief once, then one numbered block at a time. Do not send this entire file as a single request.

## 00 — Shared brief

```text
You are continuing Asura's Path in /Users/digonto/Documents/ChatGPT/Roblox game 2. I will send one numbered follow-up prompt at a time. Implement necessary fixes, perform focused verification, update the ledger, then stop at that boundary. Do not stop after a plan. Preserve existing uncommitted work, saved places, asset binaries, profiles, stable IDs/migrations, 1.4x tempo and server-authoritative combat.

At a fresh chat read CLAUDE.md, current default.project.json, this pack's AUDIT.md and relevant PROGRESS.md rows once. Read PROJECT_STATE.md's current sections selectively: it contains historical and contradictory instructions. Original references are /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/PLAYTEST_REPORT.md and /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/PROGRESS.md. Those 26 batches all have implementation work, but zero have complete acceptance. Forty findings are implemented/pending; four (#22, #23, #24, #32) retain production-art blockers. Do not resend or blindly redo the original implementation prompts.

My 21 October audit passed 19 existing regression commands (including 17 emulated suites inside one command), 206 source syntax checks and a full temporary Rojo build. Read the saved logs if needed rather than repeatedly running the baseline. These results do not certify Studio physics, appearance, human combat, actual audio, hardware or cloud delivery. Each claim must identify its evidence type: source, local regression, engine emulation, seeded Studio diagnostic, real Studio play, earned continuous-input play, hardware or private live service. Never promote one type into another. A seeded victory is never an earned kill.

Read only the current prompt's report findings, source dependencies and relevant handoff rows. Use rg, direct file edits and bounded output. Do not paste full scripts/logs, reread the entire repository or run repeated broad audits. Keep modern strict Luau and small focused modules, register runtime additions in default.project.json, and extend existing systems before adding competing ones. Add a regression for a demonstrated state/security bug; a cosmetic edit needs visual verification, not tests that mirror its spelling.

Inspect first; retain existing fixes that work. Reproduce concrete failures and fix their causes. Do not weaken difficulty/deflect timing for computer-use latency, disable safeguards broadly, strip asset mappings or reduce tests to obtain green. Use a separate temporary Rojo output for verification. Local repairs and QA are authorized; publication and real-player data changes are outside this sequence. Use isolated QA profiles for destructive lifecycle/transaction tests.

Art must be delivered as real usable models/rigs/animations/textures, not a primitive costume, stub, proposed asset ID or manifest alone. Read ASSET_REQUIREMENTS.md only in relevant art batches. Use available approved assets/authoring tools; if an essential external deliverable or human/device/live test is unavailable, complete independent work and record its exact requirement, without marking it passed or blocking all later independent prompts.

After every prompt update this pack's PROGRESS.md: changed files; focused results; evidence path/type/build; original batch/finding IDs; exact open dependency and next action. Update only matching current rows in the original PROGRESS.md; preserve its historical notes. Append at most 60 words to PROJECT_STATE.md if material progress changed. Status is In progress, Implemented — acceptance pending, Verified, or Blocked — exact requirement. Composite findings close only when every assigned part is evidenced.

Respond in at most 150 words: change/result, verification, remaining dependency and at most two short human test steps. In a fresh chat reload this brief and the next requested prompt; do not replay completed prompts. Retain the brief and wait for my numbered prompt.
```

## 01 — Establish a working Studio baseline and trustworthy verifier

```text
Continue Asura's Path — follow-up 01/26: Establish a working Studio baseline and trustworthy verifier.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 26. Findings: additional verification/tooling. Verify existing work, fix actual gaps, and execute this batch now.

The audit passed 19 regression commands, 206 source compilations and a temporary full-project Rojo build. Preserve that baseline. First prove the current Studio place contains this checkout: identify the place/test mode, call one harmless Studio read, and confirm server/client readiness plus current source. The previous connection check in this chat completed an MCP handshake but returned zero tools; do not assume connection is repaired. If unavailable, record the exact failing layer and finish independent local work without claiming Studio results.
Repair current build instructions in docs/BUILD.md: they still describe Cagebound Phase 12, missing commands and old namespaces. Keep historical material explicitly historical. Correct tools/build.py's misleading hard-coded 'external asset IDs: 0' message using a real count or remove the claim. The Phase 5 asset file now exists and the complete project builds; do not strip its mapping to bypass assets.
Add the existing audiovisual, backend, commercial and boss-encounter checks to the normal verifier where not already covered. Reuse audit logs; run the changed runner once, directing its place build to a temporary output so the user's saved place is preserved. Capture new server/client errors from one fresh boot and one basic interaction; fix only startup/tooling blockers here, route gameplay defects to their owning prompt.
Start files (relative to project root; follow only required dependencies):
- docs/BUILD.md
- tools/build.py
- tools/verify_all.sh
- default.project.json
- src/client/Bootstrap.client.luau
- src/server/Bootstrap.server.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- Existing LOCAL_TEST_LOG.txt and ADDITIONAL_TEST_LOG.txt
- python3 tools/test_audiovisual.py

Acceptance:
Save a concise baseline: exact source/build identity, live tools/readiness or connection blocker, new runtime errors, revised runner result and temporary build path. No game-quality or live-connection pass from a handshake alone.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 02 — Close the checkpoint, death and recovery loop

```text
Continue Asura's Path — follow-up 02/26: Close the checkpoint, death and recovery loop.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 01. Findings: #1, #18, #19. Verify existing work, fix actual gaps, and execute this batch now.

The recovery suite already passes 94 checks. Verify the real LoadCharacter/CharacterAdded timing and Sanctuary fall safeguard before replacing this implementation.
Rest at Gate and Cloister, die to an actual enemy, and observe active altar, physical position, region, replenished resources, boss reset and recovery objective. Cover every remaining altar using a compact position/result table; diagnostic access is acceptable for isolating an altar but is not earned campaign evidence.
Check bloodstain creation, reclaim once, second death with zero carried currency, delayed/duplicate death callbacks and respawn while a boss introduction or dialogue is active. Make death → loss → wake location → recovery goal a clean transition. Verify legitimate Sanctuary falls still recover while ground regions, crypt travel and normal spawning do not trigger the cloud-return toast.
Fix demonstrated causes in the existing recovery path, retaining per-life idempotence and schema compatibility. Include one save/rejoin at a later checkpoint on isolated test data. If engine timing cannot be exercised, retain acceptance pending and supply the exact short human test rather than adding another fake that repeats the rules.
Start files (relative to project root; follow only required dependencies):
- src/server/RecoveryRules.luau
- src/server/CharacterService.luau
- src/server/Services/WorldService.luau
- src/server/Services/SanctuaryService.luau
- src/client/Controllers/HudVisibility.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_recovery_lifecycle.luau
- python3 tools/lune_compat.py tools/test_campaign_ledger.luau

Acceptance:
No unexplained return to Sanctuary, duplicate currency loss or stale encounter/UI state; record actual spawn coordinates and distinguish real deaths from seeded diagnostics.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 03 — Validate input ownership and the desktop combat HUD

```text
Continue Asura's Path — follow-up 03/26: Validate input ownership and the desktop combat HUD.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 02, 04. Findings: #5, #6, #12, #17, #18, #33, #34, #35, #36, #37. Verify existing work, fix actual gaps, and execute this batch now.

Use InputMap as the control contract: Z interacts, E casts slot 2, 1 casts slot 1, J opens Codex, K swaps. Do not revert to stale instructions in PROJECT_STATE. Check prompt ownership just inside/outside range, a held prompt, two overlapping prompts, a focused text box and an open modal. Each action must fire once; reclaiming must never cast Gale Step. Include the controller-equivalent route; hardware closure belongs to prompt 24.
Inspect the current HUD in one small desktop and one wide viewport, grouping checks into three states: ordinary combat with H open; two enemies/Twins with lock switching; reduced HP ceiling followed by death/respawn. Fix genuine controls/action-bar overlap, duplicate CoreGui/target plates, unreadable flask/currency values and stale labels using existing layout/visibility components. Survival information and perilous cues take priority over petals and compass decoration. Rally, recoverable health and lasting deficit must be understandable without color alone.
This prompt owns desktop input/HUD defects, not a UI redesign or combat balance. Prompt 04 owns portraits, 08 teaching, 09 lighting, and 24 full device coverage. Save the views so later prompts reuse them instead of repeating this audit.
Start files (relative to project root; follow only required dependencies):
- src/shared/InputMap.luau
- src/client/Controllers/InputController.luau
- src/client/Controllers/HudLayout.luau
- src/client/Controllers/HudVisibility.luau
- src/client/Controllers/PlateLayout.luau
- src/client/Controllers/DuoBars.luau
- src/client/Controllers/CoreGuiPolicy.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_input_map.luau tools/test_hud_layout.luau

Acceptance:
Provide three state comparisons at two actual Studio viewports, exact binding/ownership outcomes and no stuck input after modal/death transitions.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 04 — Finish rest, Lin portraits and practical leveling

```text
Continue Asura's Path — follow-up 04/26: Finish rest, Lin portraits and practical leveling.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 05. Findings: #4, #38, #39, #40. Verify existing work, fix actual gaps, and execute this batch now.

The rest/dialogue implementation exists; verify it in Studio at Sanctuary, Gate and Cloister. Rest should set/refill the checkpoint and expose Travel and deliberate Summon Lin/Ascension choices. Lin's remote spirit projection is intentional. Closing her should leave the altar actions easy to reach.
Inspect both shoulder views and awkward approach angles. Her face/body must be visible, fire/stone must not fill the portrait, and the player needs safe standing and departure room. Repair portrait selection/fallback and only the necessary local geometry; coordinate any wider Cloister change with prompt 14. Unrelated HUD/prompts should disappear during dialogue and return on close, replacement dialogue, death and respawn without camera/input leaks.
Check a real affordable Vigor purchase plus insufficient-currency refusal: preview and actual HP/derived benefits must agree, currency left must be correct, Arcane Qi distinct from Essence, long attribute lists scroll inside their panel, and repeat activation cannot double-charge. Use the current LevelPreview/ProgressionRules formulas. Keep controller focus paths intact for later hardware testing.
Start files (relative to project root; follow only required dependencies):
- src/client/Controllers/DialogueController.luau
- src/client/Controllers/DialogueView.luau
- src/client/Controllers/PortraitCamera.luau
- src/shared/LevelPreview.luau
- src/server/Services/DialogueService.luau
- src/server/Services/DialogueActions.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_rest_dialogue.luau
- python3 tools/test_progression_runtime.py

Acceptance:
Capture Lin at the three altar settings and verify rest → summon → return → travel; demonstrate one exactly-once level purchase and clean interruption recovery.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 05 — Make Arsenal and Codex truthful and readable

```text
Continue Asura's Path — follow-up 05/26: Make Arsenal and Codex truthful and readable.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 06. Findings: #41, #42. Verify existing work, fix actual gaps, and execute this batch now.

Inspect all three existing Arsenal tabs with the starting loadout, one earned unlock if available, and separately labeled seeded partial/full fixtures. Verify practical spell function, targeting/range, key effects, Qi/cooldown and weapon playstyle/comparisons agree with the active schemas and scaling functions. Slot 1 and Slot 2 must be unmistakable and display current InputMap captions.
Inspect Codex at zero, partial and complete discovery counts, including long text and the story-completion line. Show truthful n/8 inscriptions and n/6 sovereigns, explain discovery in the empty state, and keep locked entries unclaimed/unreadable through the normal UI. Do not claim lore secrecy at the networking level when NarrativeCatalog is replicated.
Fix clipping, misleading data, contrast, focus and menu-close/input restoration through the existing panels. Do not invent balance values, rewrite the lore, or add another inventory framework. Prompt 06 owns reward delivery and forging; prompt 24 owns final phone/controller closure.
Start files (relative to project root; follow only required dependencies):
- src/shared/ArsenalFacts.luau
- src/shared/ArsenalCatalog.luau
- src/client/Controllers/ArsenalPanel.luau
- src/client/Controllers/ArsenalTabs.luau
- src/client/Controllers/CodexView.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_arsenal_codex.luau
- python3 tools/test_progression_runtime.py

Acceptance:
Save a small empty/partial/full view matrix; descriptions match actual behavior, counters are accurate, and menus restore movement/focus correctly.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 06 — Prove earned boss rewards and exactly-once forging

```text
Continue Asura's Path — follow-up 06/26: Prove earned boss rewards and exactly-once forging.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 08. Findings: #8, #9. Verify existing work, fix actual gaps, and execute this batch now.

The token-object ownership and six-sovereign recipes are implemented and the reward suite passes. Inspect the active roster, legacy aliases and server/UI recipeState paths before changing anything. Preserve Shen's intentional Shen plus Chimera tokens and the retired Ash Pagoda General migration to TwinSentinels; do not revive a seventh campaign boss.
Run one genuine boss victory → server award → visible token/Essence → Gao → enabled recipe → confirmation → forged item → equip/use → save/rejoin flow. If earned victory is unavailable, exercise a clearly labeled diagnostic transaction and leave earned acceptance open for prompt 22. Never mark the flow earned after directly writing defeat flags.
For all sovereigns, check the weapon/spell choices, displayed boss identity, already-owned gifts, one-choice consumption, rapid repeated requests, duplicate award delivery and rejoin. Each valid remembrance is a token object; boolean or malformed ownership must not enable a transaction. Confirm UI and server agree about Locked/Owned/Consumed rather than only testing a helper function. Keep stable item/profile IDs and idempotent server transactions.
Start files (relative to project root; follow only required dependencies):
- src/simulation/ArsenalInventory.luau
- src/shared/ArsenalCatalog.luau
- src/shared/BossArmaments.luau
- src/server/ForgeService.luau
- src/server/ProfileStore.luau
- src/client/Controllers/ArsenalTabs.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_boss_rewards.luau
- work/bin/luau/luau tools/test_weapons_and_spells.luau

Acceptance:
Produce the six-boss recipe/result table plus the actual earned or diagnostic transaction evidence; no duplicate award, token spend or lost item across rejoin.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 07 — Verify attack contact, healing and enemy defeat feedback

```text
Continue Asura's Path — follow-up 07/26: Verify attack contact, healing and enemy defeat feedback.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 09. Findings: #14, #20, #21. Verify existing work, fix actual gaps, and execute this batch now.

Use the existing ContactCues, authoritative Whiff/Evade events, healRoom refusal and EnemyDissolve. Demonstrate a light hit, heavy hit, genuine out-of-range whiff, startup feint, block and evade against one normal enemy. Check visual weapon reach versus actual hitboxes, cues/damage numbers and hit confirmation at ordinary camera distance; retain server authority and rewind limits.
At full effective HP, pressing Heal should give clear refusal and preserve charges. Verify injury-reduced ceiling, recoverable damage, available healing room and the last charge; do not equate reduced ceiling with a broken flask. Gourd count must remain readable.
Kill a monk and a swordsman: their labels/lock target should clear promptly, the body should use intentional collapse/dissolve rather than loose block debris, and Essence/reward feedback should occur once. Check a death during effects and repeated enemy respawns for leftover attachments or plates. Fix actual behavior or presentation defects, preserving attack timing and damage unless the resolver is demonstrably wrong. Deflect fairness needs continuous-input play, not delayed tool clicks.
Start files (relative to project root; follow only required dependencies):
- src/shared/ContactCues.luau
- src/simulation/CombatRules.luau
- src/server/CharacterService.luau
- src/server/Services/WorldService.luau
- src/client/Controllers/CombatCallouts.luau
- src/client/Controllers/EnemyDissolve.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_combat_contact.luau
- work/bin/luau/luau tools/test_asura_stage1.luau

Acceptance:
Record the six contact outcomes, three heal cases and clean defeats in Studio; cues agree with real health/posture changes and rewards fire once.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 08 — Make the first ten minutes teach the actual game

```text
Continue Asura's Path — follow-up 08/26: Make the first ten minutes teach the actual game.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 10. Findings: #11, #12, #13, #15, #19, #43, #44. Verify existing work, fix actual gaps, and execute this batch now.

Start with a fresh isolated profile. Observe first boot, avatar appearance loading, prologue play/skip and the first-rest objective. The scene must not reveal an unfinished avatar or competing UI before the intended handoff. Verify replay opening/training through Respite and interruptions by death/respawn.
Walk the current Sparring Phantom sequence using real actions: light, deflect, dodge, lock, heal, deathblow, perilous/mobility counter and Blood Rally as defined in TutorialRules. Ensure server-judged steps cannot advance from an unrelated event, dead target or mere keypress. Practice must remain safe and reward-free. Skipping/rejoining must neither trap an existing save nor force veteran retraining.
Then face the lone introductory monk before the later pair. Read the early memorial and see its Codex/reward update. Explain carried Essence, second-death loss, recoverable health, reduced ceiling, rest and current counter inputs at the moment they matter. Fix observed confusion with short contextual cues, not a longer controls wall. Record the first action, first useful success and first death/confusion point; any claims about ease of deflecting require a human with continuous input.
Start files (relative to project root; follow only required dependencies):
- src/shared/TutorialRules.luau
- src/server/Services/TutorialService.luau
- src/client/Controllers/TutorialController.luau
- src/client/Controllers/PrologueController.luau
- src/shared/WorldDefinitions.luau
- src/shared/NarrativeCatalog.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_opening_tutorial.luau
- python3 tools/test_objectives.py

Acceptance:
A fresh player can reach rest, practice, one real duel and one discovery without a stuck camera/input/objective; distinguish human observations from scripted state tests.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 09 — Close live combat lighting and sound-lifetime failures

```text
Continue Asura's Path — follow-up 09/26: Close live combat lighting and sound-lifetime failures.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 03. Findings: #2, #7, #36. Verify existing work, fix actual gaps, and execute this batch now.

The per-biome combat/Unbound profiles, ArenaLightPlan fill, reduced decorative effects and idempotent SpatialAudio release already pass local tests. Verify them in the actual engine rather than replacing them with fullbright or another audio wrapper.
Capture all six arenas at ordinary play distance in idle combat lighting and accessible phase-two lighting. Actors, weapons, floor edges and telegraphs must be readable without an active bright spell. Check exiting, death, retry and another player's encounter do not leave incorrect lighting on this client. Tame decorative petals/bloom when they compete with warnings, including reduced-flash mode.
Exercise hits, blocks, parries, rest, death, failed sound loads, source-first/sound-first destruction and repeated encounters. Compare voice/source counts to a settled baseline and inspect new client/server output for the original locked-Parent errors. Fix actual leaks/exceptions and retain sound budgets. Save counts/log excerpts and representative before/after views. Logs can prove lifetime behavior but cannot establish how the mix sounds; prompt 25 owns listening and music quality.
Start files (relative to project root; follow only required dependencies):
- src/shared/EnvironmentProfiles.luau
- src/shared/ArenaLightPlan.luau
- src/shared/EffectsPreference.luau
- src/client/Controllers/EnvironmentController.luau
- src/client/Controllers/SpatialAudio.luau
- src/server/Services/ArenaLighting.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_combat_presentation.luau
- python3 tools/test_audiovisual.py

Acceptance:
Readable ordinary-light arena views and real repeated-cycle cleanup evidence, with no recurring locked-Parent exception or unexplained source growth.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 10 — Finish Shen and Twins, including the real animation dispatcher

```text
Continue Asura's Path — follow-up 10/26: Finish Shen and Twins, including the real animation dispatcher.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 11. Findings: #16, #17, #23. Verify existing work, fix actual gaps, and execute this batch now.

Read ASSET_REQUIREMENTS.md. The shipped asset library has no AsuraBoss_* models. Current BossAnimations routes all humanoids through four Shen keys, and AnimationCatalog's 45 slots are stock fallbacks. Owning this shared dispatcher repair here prevents three boss batches from independently rewriting it.
Implement explicit boss/look/phase/attack animation resolution using the existing catalog and boss attack data, with safe fallback and honest missing-asset status. Confirm any imported override attributes are actually authored onto live actors, survive phase changes and are consumed by the resolver. Do not claim that a new registry supplies absent animations. Preserve attack timing/server authority and avoid driving gameplay damage from cosmetic client markers.
For Shen P1/P2 and each Twin, inspect real skin attachment, weapon alignment, silhouette and both idle/action poses in the lit arena. Supply/attach available approved production art; a welded costume is a functional fallback, not completion of finding 23. Validate entry, skip, camera return, first-impact grace, death/retry and phase transition. Zhao and Iron Bull need persistent separate names/bars, recognizable roles, target switching and room to separate. Use continuous-input evidence for fairness; leave a precise asset manifest and human test if those capabilities are missing.
Start files (relative to project root; follow only required dependencies):
- src/client/Controllers/BossAnimations.luau
- src/shared/AnimationCatalog.luau
- src/shared/BossAttackCatalog.luau
- src/server/Services/BossSkin.luau
- src/server/Services/EncounterHandoff.luau
- src/server/Services/BossDuo.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_boss_presentation.luau
- python3 tools/test_boss_runtime.py

Acceptance:
Per-actor/per-attack mapping demonstrably resolves, both Shen phases and Twins render correctly, and introduction/retry evidence is separated from missing art or untested combat.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 11 — Finish Baize and Titan as readable creature encounters

```text
Continue Asura's Path — follow-up 11/26: Finish Baize and Titan as readable creature encounters.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 12. Findings: #13, #16, #23. Verify existing work, fix actual gaps, and execute this batch now.

Reuse prompt 10's animation contract; read only the Baize/Titan rows of ASSET_REQUIREMENTS.md. Inspect AsuraLookKey, AsuraSkinStatus, body scale, actual bound templates, hurt capsules and custom animation availability. Do not rename or recolor a fallback and report production art complete. Use available approved authoring assets/tools to deliver valid models and animations; if unavailable, preserve the fallback and record the exact deliverable still absent.
For Baize, verify grounded paws, creature silhouette, phase change, pillar steering, pounce clearance and readable Air Glide counter inputs in the actual arena. Camera and hitboxes must follow the presented body rather than a hidden humanoid position. For Titan, verify scale, ankle weak-point visibility, melee/camera access, kneel/phase behavior and weapon reach. Inspect at normal play height in steady light.
For both, check handoff skip/restore, first-impact grace, death/reset and defeat cleanup. Procedural CreatureMotion must yield cleanly to valid authored animation without double transforms. Earned-fight fairness and counter usability need continuous input; seeded phase access only validates that phase's presentation. Keep scene geometry changes confined to clearance fixes; regional art is owned by prompts 16 and 18.
Start files (relative to project root; follow only required dependencies):
- src/shared/BossBodies.luau
- src/shared/LooksBeasts.luau
- src/server/Services/BossMotion.luau
- src/server/Services/BossSkin.luau
- src/client/Controllers/CreatureMotion.luau
- src/shared/BossEncounterRules.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_boss_presentation.luau
- python3 tools/test_boss_runtime.py

Acceptance:
Save lit views and attachment/phase/camera results for both bosses; mark production art, continuous-input combat and diagnostic phase checks independently.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 12 — Finish Wu and Wyrm presentation and phase behavior

```text
Continue Asura's Path — follow-up 12/26: Finish Wu and Wyrm presentation and phase behavior.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 13. Findings: #16, #23. Verify existing work, fix actual gaps, and execute this batch now.

Reuse the shared animation resolver from prompt 10. Read the Wu/Wyrm rows of ASSET_REQUIREMENTS.md and inspect live template/override status before changing the rig. Supply valid available production assets; keep absent models/animations explicitly open instead of treating manifest entries or procedural shapes as finished art.
Wu needs readable casting/weapon poses, visible teleport destination, correct phase presentation and safe camera return before an attack can land. Verify teleport clearance and obstruction with the actual Pagoda geometry, without weakening combat timing to hide tool latency.
Wyrm must read as a dragon at normal camera distance: body/tail and hurt volumes aligned, articulated wings, readable flight/landing, accessible ground windows and no double posing when authored tracks take over from CreatureMotion. Defeating it in flight must land/clean it up correctly. Inspect both phases in steady lighting, entry/skip/death/retry and the camera near arena edges.
Fix demonstrated attachment, animation lookup, phase or camera bugs within these encounters. Preserve server damage, roster IDs and boss logic. Seeded access can inspect flight/phase states; it cannot close earned victory or continuous-input counter/fairness acceptance.
Start files (relative to project root; follow only required dependencies):
- src/shared/LooksSovereigns.luau
- src/shared/BossBodies.luau
- src/server/Services/BossMotion.luau
- src/server/Services/BossSkin.luau
- src/client/Controllers/BossAnimations.luau
- src/client/Controllers/CreatureMotion.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_boss_presentation.luau
- python3 tools/test_boss_runtime.py

Acceptance:
Capture Wu casting/teleport and Wyrm idle/flight/landing/defeat plus both phases; list any exact missing rig/animation delivery separately.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 13 — Finish player, NPC and normal-enemy visual identity

```text
Continue Asura's Path — follow-up 13/26: Finish player, NPC and normal-enemy visual identity.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 14. Findings: #24. Verify existing work, fix actual gaps, and execute this batch now.

Audit the actual spawned player, Lin, Hermit, Gao, monk, swordsman and training phantom. Current CastFigures/CostumeKit and player rebinding are useful primitive fallbacks; production face/hair/attire is still missing. Read the cast row of ASSET_REQUIREMENTS.md and use approved assets/authoring capability where available.
Verify the player appearance loader replacing a limb/head does not orphan clothing, duplicate costume pieces or reveal an unintended bald/default body. Check first spawn, delayed avatar load, respawn, limb replacement and equipment changes, including weapon grip/reach and trails. Preserve movement collision and the game's readable wuxia silhouette.
Inspect Lin/Gao/Hermit close-up through the real portrait camera in Sanctuary and Monastery lighting. Faces, hair, apparel and posture should form recognizable characters. Normal enemy roles need distinct silhouettes and weapon handling that remain readable in combat and dissolve cleanly on death. Replace only the demonstrated weak presentation; do not redesign the imported colossal shrine landmark.
If essential character art cannot be delivered, provide exact filenames/template/rig/texture requirements and keep art acceptance blocked. Geometry passing the cast shim does not prove a portrait looks finished.
Start files (relative to project root; follow only required dependencies):
- src/server/FighterAppearance.luau
- src/server/EnemyAppearance.luau
- src/server/Services/CastFigures.luau
- src/shared/LooksCast.luau
- src/server/Services/WeaponModels.luau
- src/client/Controllers/PortraitCamera.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_cast_visuals.luau
- python3 tools/test_progression_runtime.py

Acceptance:
Provide in-engine spawn/respawn and NPC portrait comparisons, no orphan/duplicate attire, and an honest production-art disposition.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 14 — Walk and finish the Monastery route and navigation

```text
Continue Asura's Path — follow-up 14/26: Walk and finish the Monastery route and navigation.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 07, 15. Findings: #3, #4, #25, #26, #27, #28, #29, #30, #32, #44. Verify existing work, fix actual gaps, and execute this batch now.

Combine the two original Monastery batches into one route pass. Walk Sanctuary portal → Gate altar → courtyard → bridge duel → Cloister and back. Arrival must frame/name the actual checkpoint, bridge swordsman must be visible and damageable from both ends, and the Cloister altar needs safe standing/portrait/exit space. Reuse prompt 04's portrait results.
Walk all four Monastery tablets and three caches, including waterfall, rafters and mausoleum with real ladder/jump/terrain physics. Test intended roof/ravine shortcuts, ridge veils, enemy leashes and the restored Gatehouse PvP yard. Empty reachable exterior must lead somewhere intentional or have believable bounds. Improve only weak route readability/combat pockets/material scale found in this pass; do not bury paths with extra decoration.
Close the overlooked navigation gap: SakuraMinimap still draws entity/altar dots without route geometry, while RouteGuide already stages the objective marker. Add a small bounded route/connection layer using existing zone/door data, with elevation/portal-leg cues and a bloodstain route, so the display does not imply walking through walls. Reuse it for later region prompts; avoid a new pathfinding framework or per-frame world scan.
Check directions from a later-checkpoint death and inspect the map/marker at turns and portals. Keep mobility, stable IDs and existing shrine/ruin assets intact.
Start files (relative to project root; follow only required dependencies):
- src/server/Services/MonasteryGrounds.luau
- src/server/Services/MonasterySecrets.luau
- src/server/Services/MonasteryTerrain.luau
- src/shared/MonasteryZones.luau
- src/shared/RouteGuide.luau
- src/client/Controllers/SakuraMinimap.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_monastery_route.luau tools/test_monastery_discovery.luau
- python3 tools/test_objectives.py

Acceptance:
Actual walk/duel/collectible evidence and readable map/marker turns; no geometry-stuck altar or misleading cross-wall/portal guidance. Track any new region-kit deficit as art work.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 15 — Validate Sanctuary reveals, terrace and cache routes

```text
Continue Asura's Path — follow-up 15/26: Validate Sanctuary reveals, terrace and cache routes.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 16. Findings: #27, #28, #31, #32. Verify existing work, fix actual gaps, and execute this batch now.

Walk from spawn/bonfire through the stairs, viewing wings and pilgrim daises at ordinary camera height. Preserve the imported colossus/tree identity, scale and composition while fixing demonstrated player-scale occlusion, footing, camera clipping or visual seams. Do not evaluate the whole reveal from a detached aerial camera.
Walk terrace edges/roots and both Sanctuary cache routes, including the moved ladder/service ledge and cloud shards. Use real jump/glide physics. Check parapets, honest limits, legitimate fall return and arrival/return portal legs. Verify camera and collision around imported meshes and their simple movement proxies.
Inspect route cues/minimap added in prompt 14, the first-rest orientation, portrait pocket and return-to-Lin objective. Ensure the Crypt catch and Sanctuary catch cannot steal each other's players. Any material/texture-scale repairs should reuse the current architecture vocabulary and retain the centerpiece.
Original Sanctuary reachability was checked against a numeric model rather than the actual built place. This prompt must close that evidence gap, not rerun the same model and call it a walk. If Studio is unavailable, document exact unwalked sections and continue only useful local fixes.
Start files (relative to project root; follow only required dependencies):
- src/shared/SanctuaryRoutes.luau
- src/server/Services/SanctuaryApproach.luau
- src/server/Services/SanctuaryService.luau
- src/server/Services/SanctuaryColossus.luau
- src/server/Services/LootWorld.luau
- src/shared/RouteGuide.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/test_campaign_regions.py
- python3 tools/test_campaign_build.py

Acceptance:
Natural-camera reveal captures, a real terrace/cache/ladder traversal and correct Sanctuary/Crypt fall/return behavior; no claim that numeric reachability proves physics.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 16 — Finish and validate Bamboo Pass

```text
Continue Asura's Path — follow-up 16/26: Finish and validate Bamboo Pass.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 17. Findings: #22, #27, #28, #32, #44. Verify existing work, fix actual gaps, and execute this batch now.

Walk Monastery south road → gorge/stairs → Bamboo shrine → Baize approach → Ash join and return. Verify real footing, enemy zones/leashes, readable landmarks, altar kindle/death/respawn/travel and both Bamboo inscriptions. Traverse the optional frost-stone route using the actual movement system; test double-jump/glide against the thicket veils and catch volumes.
The 1,219-part offline build and exact-box reachability pass do not establish a finished bamboo biome. Inspect the scene at character height for repeated slabs, weak silhouettes, poor texture scale and empty boundaries. Place available approved bamboo/ruin meshes through the existing dressing/PBR layer over preserved collision boxes; if essential bamboo kits are absent, create the exact asset handoff and keep production-art acceptance blocked. Recolored primitives alone do not close finding 22 or 32.
Use the shared minimap/RouteGuide layer from prompt 14; directions must name the usable stair/door rather than point across the gorge. Check Baize enter/leave/reset and local camera clearance with the actual rig, reusing prompt 11 evidence. Limit changes to this region and its immediate joins; record concrete defects instead of a broad environment rewrite.
Start files (relative to project root; follow only required dependencies):
- src/shared/BambooPassLayout.luau
- src/server/Services/BambooDressing.luau
- src/server/Services/CampaignBounds.luau
- src/shared/CampaignZones.luau
- src/shared/RouteGuide.luau
- src/shared/NarrativeCatalog.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/test_campaign_regions.py
- python3 tools/test_campaign_build.py

Acceptance:
Walked main/optional routes, two readable tablets, altar retry/travel and ordinary-light region views, with geometry/production-art status separated.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 17 — Finish and validate the Ash Colosseum story region

```text
Continue Asura's Path — follow-up 17/26: Finish and validate the Ash Colosseum story region.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 18. Findings: #22, #27, #28, #32. Verify existing work, fix actual gaps, and execute this batch now.

Walk Bamboo join → antechamber altar → Shen arena → Pagoda join and return. Confirm rest/death/respawn/travel and correct portal/waypoint legs. Check the cavea and arena perimeter against both Shen forms, normal shoulder camera, weapon reach, hazards and handoff locations; reuse prompt 10's boss evidence.
Inspect actual story-region silhouettes, ruined martial architecture, material/texture scale and combat readability. Integrate available approved colosseum tier/arcade art through current dressings without moving authoritative arena floors or covering collision/exit paths. Essential absent kits remain explicitly blocked with a precise deliverable; a box-layout pass is not final environment art.
Preserve the separate Sanctuary/Monastery PvP system. In this region, verify the Proving Court lane and Ring_OctagonOfAsh are physically reachable, unobstructed and not cut off by the story veils. Avoid changing wager/matchmaking rules here.
After an actual or separately labeled diagnostic victory, verify the onward route remains traversable with correct guidance and no stale fog-gate/encounter lock. Keep existing IDs, saves and boss reward behavior. This is a single-region closure pass, not another campaign expansion.
Start files (relative to project root; follow only required dependencies):
- src/shared/AshColosseumLayout.luau
- src/server/Services/ColosseumDressing.luau
- src/server/Services/BossArenas.luau
- src/server/Services/CampaignBounds.luau
- src/shared/RouteGuide.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/test_campaign_regions.py
- python3 tools/test_campaign_build.py

Acceptance:
Walked story and Proving Court connections; both Shen forms have real clearance and a usable exit; final art is distinguished from structural completion.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 18 — Finish and validate Sanctuary Depths and Sunken Crypt

```text
Continue Asura's Path — follow-up 18/26: Finish and validate Sanctuary Depths and Sunken Crypt.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 19. Findings: #22, #27, #28, #32. Verify existing work, fix actual gaps, and execute this batch now.

Walk Sanctuary Well of Descent → crypt arrival → incense altar → Titan chamber → return. Check arrival facing, readable route/portal labels, rest/death/respawn/travel and a real pit/catch case. Legitimate underground play must not activate the Sanctuary cloud-return catch.
Inspect the Crypt at character height in exploration and steady combat lighting. Depth, vaults, sarcophagus/optional traversal, boundaries and landmarks should fulfill the crypt premise while keeping floor edges, Titan's ankles and weapons readable. Use available approved vault/sarcophagus/bone-niche assets over existing collision boxes; retain an explicit production-kit blocker where no valid art can be supplied.
Test actual mobility on the optional lids, enemy leashes, tight corners, ceiling/camera access and Titan's chamber entrance/reset with the real rig. Reuse prompt 11's encounter evidence. Confirm death/bloodstain guidance stages the well/return portal rather than aiming directly across the world separation.
Keep the authoritative arena floor and stable region/checkpoint/portal IDs. Fix demonstrated geometry, lighting or catch bugs in this region and its joins. Do not certify physics from the existing offline grid alone.
Start files (relative to project root; follow only required dependencies):
- src/shared/SunkenCryptLayout.luau
- src/server/Services/CryptDressing.luau
- src/server/Services/CampaignBounds.luau
- src/server/Services/SanctuaryService.luau
- src/shared/EnvironmentProfiles.luau
- src/shared/RouteGuide.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/test_campaign_regions.py
- python3 tools/test_campaign_build.py

Acceptance:
Walked descent, optional branch, altar retry, chamber/return and pit recovery; no false Sanctuary catch and no unreadable underground combat.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 19 — Finish and validate Celestial Pagoda and final lore

```text
Continue Asura's Path — follow-up 19/26: Finish and validate Celestial Pagoda and final lore.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 20. Findings: #22, #27, #28, #32, #44. Verify existing work, fix actual gaps, and execute this batch now.

Walk Ash join → multi-level ascent/rafters → incense altar → Wu arena → Sky join and back. Verify actual stair/rafter widths, ceiling/headroom, single-jump landings, falls/catches, shoulder camera, enemy pathing and line-of-sight combat. Main progress must not require an untaught mobility trick.
Read both Pagoda inscriptions, including the final eighth entry, from real standing positions; confirm Codex/reward updates once. Test the optional loft, rest/death/respawn/travel and guidance on different elevation bands. The minimap/marker should stage the correct stairs and doors, not draw a misleading straight route through floors.
Inspect pagoda silhouette, roof/eave/rafter materials and scale in steady lighting. Integrate approved kits via the existing layout/dressing separation; keep absent eave/tower/rafter art explicitly open rather than declaring a stacked primitive blockout final. Reuse Wu's teleport/phase evidence from prompt 12 and verify local obstruction/camera clearance after any geometry change.
Keep arena y=0 assumptions and existing progression/tablet IDs. Limit work to this region and its immediate joins; document exact remaining art or live-physics cases.
Start files (relative to project root; follow only required dependencies):
- src/shared/CelestialPagodaLayout.luau
- src/server/Services/PagodaDressing.luau
- src/shared/NarrativeCatalog.luau
- src/server/Services/NarrativeWorld.luau
- src/shared/CampaignZones.luau
- src/shared/RouteGuide.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/test_campaign_regions.py
- python3 tools/test_campaign_build.py

Acceptance:
Real ascent/loft/tablet evidence, correct elevation guidance, safe retry/travel and Wu clearance; final lore obtained through movement, not flags.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 20 — Finish and validate Sky Citadel and summit return

```text
Continue Asura's Path — follow-up 20/26: Finish and validate Sky Citadel and summit return.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 21. Findings: #22, #27, #28, #32. Verify existing work, fix actual gaps, and execute this batch now.

Walk Pagoda exit → bastion/checkpoint → summit arena and the post-victory Sanctuary return. Test actual bridges/landings, double-jump/glide limits, chasm/summit catches, rest/death/respawn/travel and clear final-route guidance. The route should remain usable after Wyrm dies and during later visits.
Inspect the summit reveal and region at ordinary camera distance with no bright attack effect. Citadel towers/battlements, weather and ground silhouettes need a coherent visual identity, readable combat boundaries and sensible texture scale. Integrate available approved art with collision proxies preserved; list missing tower/battlement kits explicitly if production delivery is unavailable.
Using prompt 12's real Wyrm rig, verify flight, landing, camera at arena edges and defeated-in-flight cleanup against the built geometry. Recheck bounds and return portal after any clearance fix. A diagnostic victory can inspect the exit but cannot establish earned completion.
Preserve authoritative arena heights, boss/checkpoint IDs and the current campaign scope. Resolve only demonstrated route, geometry, lighting or presentation failures here; the ending and full run belong to prompts 21 and 22.
Start files (relative to project root; follow only required dependencies):
- src/shared/SkyCitadelLayout.luau
- src/server/Services/CitadelDressing.luau
- src/server/Services/CampaignBounds.luau
- src/server/Services/BossMotion.luau
- src/shared/RouteGuide.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/test_campaign_regions.py
- python3 tools/test_campaign_build.py

Acceptance:
Walked summit approach and return, readable floor/edge views and actual Wyrm clearance/landing evidence; honest geometry versus production-art status.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 21 — Verify the six-sovereign ending and postgame

```text
Continue Asura's Path — follow-up 21/26: Verify the six-sovereign ending and postgame.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 22. Findings: #10, #28, #42. Verify existing work, fix actual gaps, and execute this batch now.

The server story flags, Cross/Remain choice, client crossing scene, credits and postgame Codex are implemented. Verify five flags cannot unlock Release, six legitimate flags route back to Lin in person, and the remote projection gives correct homeward guidance. Isolated seeded profiles can test edge cases; earned ending acceptance must wait for prompt 22's genuine six-boss run.
Exercise Remain → continued exploration → later Cross; Cross → completion card → credits → continue playing; replay/skip; death/respawn during the scene; leave/rejoin after the recorded choice; and interrupted presentation. The choice is currently saved before presentation and grants no item: do not invent a new reward to make the test pass.
Inspect actual camera shots and readable credits at normal settings and reduced-motion mode. HUD/input/focus must restore on every exit, gear/discoveries must survive, Codex must show the correct story stage, and PvP should remain optional. Check credit content against assets/CREDITS.md without claiming licenses merely from a copied name.
Fix concrete state/presentation problems through EndingRules/EndingController and current dialogue flow. Do not add another chapter or treat seeded six flags as a completed campaign.
Start files (relative to project root; follow only required dependencies):
- src/shared/EndingRules.luau
- src/shared/EndingCredits.luau
- src/client/Controllers/EndingController.luau
- src/server/Services/DialogueActions.luau
- src/shared/Objectives.luau
- src/client/Controllers/CodexView.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/test_progression_runtime.py
- python3 tools/test_objectives.py

Acceptance:
Both choices and interruption/rejoin pass with real scene views; earned completion remains separately tracked until the genuine campaign run.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 22 — Run the earned solo campaign and close integration failures

```text
Continue Asura's Path — follow-up 22/26: Run the earned solo campaign and close integration failures.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 23. Findings: #1, #8, #9, #10, #16, #18, #19, #22, #23, #27, #28, #44. Verify existing work, fix actual gaps, and execute this batch now.

Use the evidence collected in prompts 02–21. Do not reread/rebuild every system or replay already-proven isolated cases. Attempt a normal fresh-profile campaign with continuous input: opening → all six sovereigns and every phase → earned rewards/forge → return to Lin → crossing/postgame. No defeat flags, invulnerability, kill commands or teleports count as earned progress.
Maintain a compact checkpoint log with build identity and real milestone evidence so a resumed session does not repeat the opening. Record each boss's phase/victory/retry outcome, one later-checkpoint death/stain/reclaim/second death, save/rejoin at meaningful progress, all altar travel destinations, all eight inscriptions and five caches. Reuse actual collectible/route evidence when it belongs to this same build and profile lineage. Include one real reinforce/infuse plus mastery/ward/Last Breath behavior where legitimately reachable.
Fix demonstrated cross-system blockers with the smallest necessary change and a focused regression. Do not nerf damage/deflect windows because computer-use input is delayed. If a human must perform combat, deliver the exact short route/save/test handoff and keep the unplayed sections pending while completing independent integration checks.
Separate earned outcomes, diagnostic fixtures and offline proofs in the final matrix. This is the campaign gate; one normal-enemy kill plus six assisted encounter starts does not pass it.
Start files (relative to project root; follow only required dependencies):
- src/server/Services/WorldService.luau
- src/server/CharacterService.luau
- src/server/ProfileStore.luau
- src/shared/Objectives.luau
- tools/test_campaign_ledger.luau
- tools/test_progression_runtime.py

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_campaign_ledger.luau
- Run only regressions affected by actual integration fixes

Acceptance:
An evidence-linked earned completion matrix or exact reached milestone/blocker; no blanket full-clear claim without all six real victories and the ending.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 23 — Verify real multiplayer and isolated durable persistence

```text
Continue Asura's Path — follow-up 23/26: Verify real multiplayer and isolated durable persistence.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 24. Findings: additional verification/tooling. Verify existing work, fix actual gaps, and execute this batch now.

The real-service mock test passes 28 checks, including the fixed leave-during-setup forfeit. Validate two duelists plus a spectator in an actual local multi-client session. Cover Ranked normalization, Open build stats, countdown/queue cancellation, both reachable rings, target/lighting isolation and leaving during setup versus mid-match.
For the spectator, test eligibility, escrow before the bell, rejection once closed, duelist refusal, win/loss/refund and exactly-once settlement. Verify duplicate requests, disconnect/rejoin, abandoned setup, service outage and shutdown produce the appropriate durable journal/inbox/profile outcomes without double rating, Essence or stakes.
Then use an existing authorized isolated private test universe for genuine DataStore/lease/fencing, result recovery and shutdown delivery. Keep test accounts and stores separate from real player data. If no such live environment is available, prepare the runnable harness and owner steps; leave live delivery pending rather than publishing or pointing destructive tests at production. Local multi-client sessions and mocks cannot establish cloud durability.
Retain current schema migration and release gates; this prompt adds no monetization or wager rules. Save the session topology, test data identities, outcomes and relevant failure/recovery excerpts without dumping account secrets.
Start files (relative to project root; follow only required dependencies):
- src/server/Services/ColosseumService.luau
- src/server/Services/WagerService.luau
- src/server/Services/WagerLedger.luau
- src/server/PersistenceService.luau
- src/server/ProfileStore.luau
- src/server/MatchJournal.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_colosseum_runtime.luau
- work/bin/luau/luau tools/test_backend.luau
- work/bin/luau/luau tools/test_profile_integrity.luau

Acceptance:
A clear mock/local multi-client/private-live matrix; real match, wager, disconnect and durable recovery evidence or a precise external environment requirement.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 24 — Close phone, tablet, controller and accessibility acceptance

```text
Continue Asura's Path — follow-up 24/26: Close phone, tablet, controller and accessibility acceptance.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 25. Findings: #5, #6, #12, #13, #33, #34, #35, #36, #37, #39, #40, #41, #42, #43. Verify existing work, fix actual gaps, and execute this batch now.

Reuse desktop evidence from prompt 03 and modals from 04–05. The current 89-check device test is geometry/emulation with no captures or hardware. Inspect actual Studio phone/tablet safe-area emulation at the existing six sizes plus small desktop and ultrawide; then check physical phone, tablet and controller where available. Label these evidence types separately.
Group coverage into combat HUD/touch holds, modal navigation/scrolling and settings/transitions. Verify thumb movement plus attack/guard/jump/glide, prompt range/hold, binding captions, perilous hints, flask count, two foes/boss bars, Controls, Arsenal/Respite/Codex, long dialogue/leveling and ending. Controller users need a complete open/select/back/close/resume path and sensible focus, not just the correct caption. Test active-device switching during a session.
Check comfort text 100/115/130%, reduced decorative effects/motion/flashes, non-color health/perilous cues, sensitivity/FOV save/cancel/rejoin and readable subtitles. There is currently no functioning remapping UI; do not advertise the legacy boxing keybinds table as working remapping. Fix regressions within the existing DeviceLayout/UI/settings model rather than adding a second framework.
Record concrete clipping, overlap, touch usability and focus outcomes, reusing views where possible. Unavailable hardware remains an exact human test, not a passed case.
Start files (relative to project root; follow only required dependencies):
- src/client/Controllers/DeviceLayout.luau
- src/client/Controllers/HudLayout.luau
- src/client/Controllers/ComfortSettings.luau
- src/client/Controllers/PauseMenu.luau
- src/client/Controllers/InputController.luau
- src/shared/EffectsPreference.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_device_layout.luau tools/test_input_map.luau tools/test_hud_layout.luau

Acceptance:
Compact viewport/input/state matrix with captures and hardware labels; complete touch/controller tasks and persisted/reverted comfort settings, or exact untested cases.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 25 — Measure performance and listen to the finished audio

```text
Continue Asura's Path — follow-up 25/26: Measure performance and listen to the finished audio.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 26. Findings: #2, #7, #21, #23, #24, #25, #31, #32, #36. Verify existing work, fix actual gaps, and execute this batch now.

Use the same build after content fixes. Profile Sanctuary/tree, a normal Monastery fight, populated Bamboo Pass, Twins and Wyrm in comparable camera/graphics/session conditions. Capture actual frame-time distribution/spikes, client/server memory, draw/render/effect/instance counts and network traffic where available. Record machine/device, quality setting, sample duration and player count. Existing box/part counts and a packet-size estimate are not measured FPS, GPU cost or bandwidth.
Repeat combat/rest/death/respawn and region rebuilds, compare settled baselines and inspect SpatialAudio stats. Optimize only demonstrated hotspots/leaks using current budgets, reuse/culling/cleanup and bounded lighting/effect changes, preserving collision, attack cues and authored art. Report measured before/after evidence; do not invent a universal frame-rate claim.
Perform actual audio playback/listening: hit/block/armored-hit/deflect distinction, ambience distance, music entry/phase/exit/retry, clipping, hierarchy and asset-load/access failures. BossMusic currently falls back to one BossDrone and the saved project has no BossMusic_<bossId> tracks. Supply available approved original/cleared music and a useful category mix if needed; a configured name or silent log does not supply a score. If listening or tracks are unavailable, record that exact gap.
Reuse prompt 09 lifetime evidence and 24 hardware conditions. Do not create new gameplay systems or repeatedly rerun the entire regression suite for a cosmetic-only adjustment.
Start files (relative to project root; follow only required dependencies):
- src/client/Controllers/SpatialAudio.luau
- src/client/Controllers/BossMusic.luau
- src/client/Controllers/SoundscapeController.luau
- src/server/Services/PresentationService.luau
- src/server/Services/PbrAssets.luau
- src/shared/PresentationAssets.luau

Focused checks (reuse prior results unless code changed or live evidence is missing):
- python3 tools/lune_compat.py tools/test_session_cleanup.luau
- python3 tools/test_audiovisual.py
- python3 tools/test_campaign_build.py

Acceptance:
Measured scene/cleanup results and a real listening/track-availability matrix. Separate measured results, source estimates, placeholder music and untested devices.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

## 26 — Audit every original batch and every finding before sign-off

```text
Continue Asura's Path — follow-up 26/26: Audit every original batch and every finding before sign-off.

Apply 00_SHARED_BRIEF.txt in /Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21 (read once per chat). Load only this prompt's ledger rows and necessary dependencies. Original batches: 26. Findings: all #1–44 (evidence audit only). Verify existing work, fix actual gaps, and execute this batch now.

Perform an evidence audit, not another unrestricted implementation pass. Read this pack's PROGRESS.md and manifest plus the original 26-row audit. Review all original batches 01–26, every original finding 1–44 and audit gaps A1–A6. Use existing evidence and the changed-file/build identity; do not close items by citing the prompt that requested them.
For each original batch/finding, record current implementation, appropriately typed acceptance evidence, remaining defect/dependency and exact owner. A finding assigned to several prompts stays open until all its required parts pass. Retain partial status for production models/animations/region kits, real physics/presentation, earned six-boss completion, device hardware, listening/performance and live persistence that lack direct evidence. Do not erase the original historical observations or imply that the pack author performed these future tests.
Run the consolidated local verifier once on the final changed code, with temporary place output. Check source registration, asset paths, syntax, remaining new Studio output and meaningful regressions; do not weaken assertions or remove tests to obtain green results. Recheck only affected acceptance after final fixes.
Write FINAL_ACCEPTANCE.md with two concise tables (26 batches; 44 findings), linked evidence, exact open work and a go/no-go assessment for representative private playtesting. Record a small remaining owner-action list. All-fixed/ready-to-launch is forbidden while mandatory acceptance is absent; successful local tests alone cannot establish commercial success. Stop after this sign-off audit rather than starting new features.
Start files (relative to project root; follow only required dependencies):
- outputs/claude-followup-2026-10-21/PROGRESS.md
- outputs/claude-followup-2026-10-21/manifest.json
- outputs/claude-followup-2026-10-21/AUDIT.md
- tools/verify_all.sh
- default.project.json

Focused checks (reuse prior results unless code changed or live evidence is missing):
- Final consolidated verifier once
- Recheck only acceptance affected by final fixes

Acceptance:
Every original batch, all 44 findings and A1–A6 have evidence-backed dispositions; unresolved work stays visible and the readiness verdict matches what was actually tested.

Update the matching ledgers with evidence type and exact remaining work; stop after this batch.
```

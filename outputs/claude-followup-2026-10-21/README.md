# Claude follow-up prompts — 21 October 2026

All 26 previous batches have implementation work, but **none has complete acceptance**. This follow-up pack targets the remaining proof, missing delivery and actual defects; it does not ask Claude to blindly rebuild working systems.

1. Send [00_SHARED_BRIEF.txt](<./00_SHARED_BRIEF.txt>) once at the start of a Claude chat.
2. Send **01**, let Claude finish and update the ledger, then **02** through **26**, one at a time. Do not paste the whole bundle into one turn.
3. If Claude has project filesystem access, you can send: `Read the shared brief and follow-up NN in outputs/claude-followup-2026-10-21, then execute that batch.` The actual numbered filename is listed below.
4. Start a fresh Claude chat when context becomes long; 09, 14, 21 and 24 are useful boundaries. Resend the brief and next prompt only; PROGRESS.md carries the handoff. These are optional breakpoints, not a requirement to reload every document.
5. If an asset/human/device/live check is unavailable, Claude records its exact dependency and finishes independent work. Send the next independent prompt; do not let a missing rig prevent UI/reliability work. Human continuous-input tests still need to happen before a Verified verdict.

[ALL_PROMPTS.md](<./ALL_PROMPTS.md>) contains all copy/paste blocks. [AUDIT.md](<./AUDIT.md>) verifies coverage of every prior batch and all 44 findings. [PROGRESS.md](<./PROGRESS.md>) is the new working ledger. [ASSET_REQUIREMENTS.md](<./ASSET_REQUIREMENTS.md>) defines the missing art handoff. Original prompts/progress are preserved.

The numbered prompts contain **266–361 words each**; the shared brief is read once. Closely related repairs are grouped, boss/region work remains bounded, and the final audit checks evidence rather than reopening every implementation. Prompt 14 combines the two old Monastery passes; prompt 03 combines input/desktop HUD; shared animation dispatch belongs to prompt 10. This limits duplicate investigation while keeping one region or closely related encounter pair per art task.

| Send | Follow-up | Original batches |
|---|---|---|
| 01 | [Establish a working Studio baseline and trustworthy verifier](<./01_studio-baseline.txt>) | 26 |
| 02 | [Close the checkpoint, death and recovery loop](<./02_checkpoint-recovery.txt>) | 01 |
| 03 | [Validate input ownership and the desktop combat HUD](<./03_inputs-and-hud.txt>) | 02, 04 |
| 04 | [Finish rest, Lin portraits and practical leveling](<./04_rest-dialogue-leveling.txt>) | 05 |
| 05 | [Make Arsenal and Codex truthful and readable](<./05_arsenal-codex.txt>) | 06 |
| 06 | [Prove earned boss rewards and exactly-once forging](<./06_rewards-forging.txt>) | 08 |
| 07 | [Verify attack contact, healing and enemy defeat feedback](<./07_combat-contact.txt>) | 09 |
| 08 | [Make the first ten minutes teach the actual game](<./08_opening-tutorial.txt>) | 10 |
| 09 | [Close live combat lighting and sound-lifetime failures](<./09_lighting-audio-lifetime.txt>) | 03 |
| 10 | [Finish Shen and Twins, including the real animation dispatcher](<./10_shen-twins.txt>) | 11 |
| 11 | [Finish Baize and Titan as readable creature encounters](<./11_baize-titan.txt>) | 12 |
| 12 | [Finish Wu and Wyrm presentation and phase behavior](<./12_wu-wyrm.txt>) | 13 |
| 13 | [Finish player, NPC and normal-enemy visual identity](<./13_cast-identity.txt>) | 14 |
| 14 | [Walk and finish the Monastery route and navigation](<./14_monastery-route.txt>) | 07, 15 |
| 15 | [Validate Sanctuary reveals, terrace and cache routes](<./15_sanctuary-route.txt>) | 16 |
| 16 | [Finish and validate Bamboo Pass](<./16_bamboo-pass.txt>) | 17 |
| 17 | [Finish and validate the Ash Colosseum story region](<./17_ash-colosseum.txt>) | 18 |
| 18 | [Finish and validate Sanctuary Depths and Sunken Crypt](<./18_sunken-crypt.txt>) | 19 |
| 19 | [Finish and validate Celestial Pagoda and final lore](<./19_celestial-pagoda.txt>) | 20 |
| 20 | [Finish and validate Sky Citadel and summit return](<./20_sky-citadel.txt>) | 21 |
| 21 | [Verify the six-sovereign ending and postgame](<./21_ending-postgame.txt>) | 22 |
| 22 | [Run the earned solo campaign and close integration failures](<./22_earned-campaign.txt>) | 23 |
| 23 | [Verify real multiplayer and isolated durable persistence](<./23_multiplayer-persistence.txt>) | 24 |
| 24 | [Close phone, tablet, controller and accessibility acceptance](<./24_devices-accessibility.txt>) | 25 |
| 25 | [Measure performance and listen to the finished audio](<./25_performance-audio.txt>) | 26 |
| 26 | [Audit every original batch and every finding before sign-off](<./26_final-coverage.txt>) | 26 |

These prompts are prepared, not executed. Coverage is complete; gameplay/art/live acceptance remains open until evidenced. No claim of launch readiness or commercial success is implied by a green local suite.

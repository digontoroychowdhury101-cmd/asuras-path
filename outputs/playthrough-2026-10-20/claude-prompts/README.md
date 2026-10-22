# Claude repair prompts — Asura's Path

Prepared 20 October 2026 from the hands-on playtest report. This pack contains **one shared brief and 26 bounded work prompts**, plus a tracker mapping **all 44 findings**. No game fixes are made by generating this pack.

## How to use

1. Open [00_OPERATING_BRIEF.txt](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt>) and send its contents to Claude once at the start of a chat.
2. Send the contents of prompt 01, let Claude finish its implementation and checks, then send 02, continuing through 26. Paste one work prompt at a time, not the whole bundle.
3. Claude updates [PROGRESS.md](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/PROGRESS.md>) after each batch. Review its remaining dependencies before the next dependent batch. Independent work can continue while an external asset/check is unavailable.
4. If you start a fresh Claude chat, send the shared brief and the next prompt. The ledger carries progress without repasting earlier conversations. Phase boundaries after 10, 14 and 21 are convenient restart points if context has grown large.

[ALL_PROMPTS.md](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/ALL_PROMPTS.md>) contains every copy-and-paste block in order. Individual text files contain the same work prompts. File hints are starting points, not permission for broad rewrites.

## Order and scope

- 01–10: core reliability, controls, readable presentation, UI, rewards and onboarding.
- 11–14: two bosses at a time, then the shared humanoid cast.
- 15–21: one location per prompt; these are substantive level/art tasks.
- 22: the playable ending.
- 23–26: earned campaign acceptance, multiplayer/persistence, devices/accessibility, performance/audio and final closure.

The number of prompts reflects the size of the content work: five unfinished regions and creature rigs should not be combined into one giant coding request. Each work prompt is concise and asks Claude to read only assigned findings and necessary dependencies. Art that needs unavailable meshes/animations remains explicitly open; these prompts cannot substitute for those assets.

| Send | Prompt | Report findings |
|---|---|---|
| 00 | [Shared operating brief](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/00_OPERATING_BRIEF.txt>) | Workflow and evidence rules |
| 01 | [Checkpoint, death and recovery lifecycle](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/01_checkpoint-death-and-recovery-lifecycle.txt>) | #1, #18, #19 |
| 02 | [One consistent input and interaction map](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/02_one-consistent-input-and-interaction-map.txt>) | #5, #6, #37 |
| 03 | [Readable combat lighting and stable audio cleanup](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/03_readable-combat-lighting-and-stable-audio-cleanup.txt>) | #2, #7, #36 |
| 04 | [HUD layout, health readability and death transitions](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/04_hud-layout-health-readability-and-death-transitions.txt>) | #12, #17, #18, #33, #34, #35, #36 |
| 05 | [Rest, Lin dialogue and leveling flow](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/05_rest-lin-dialogue-and-leveling-flow.txt>) | #4, #38, #39, #40 |
| 06 | [Useful Arsenal descriptions and Codex progress](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/06_useful-arsenal-descriptions-and-codex-progress.txt>) | #41, #42 |
| 07 | [Monastery collision, altar clearance and arrival repairs](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/07_monastery-collision-altar-clearance-and-arrival-repairs.txt>) | #3, #4, #26, #27, #29, #30 |
| 08 | [Earned remembrance and complete boss reward pipeline](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/08_earned-remembrance-and-complete-boss-reward-pipeline.txt>) | #8, #9 |
| 09 | [Attack contact, full-health healing and enemy deaths](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/09_attack-contact-full-health-healing-and-enemy-deaths.txt>) | #14, #20, #21 |
| 10 | [A playable opening tutorial and clean prologue handoff](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/10_a-playable-opening-tutorial-and-clean-prologue-handoff.txt>) | #11, #12, #13, #15, #19, #43, #44 |
| 11 | [Shen and Twin Sentinels presentation and fair entry](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/11_shen-and-twin-sentinels-presentation-and-fair-entry.txt>) | #16, #17, #23 |
| 12 | [Baize and Titan creature presentation](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/12_baize-and-titan-creature-presentation.txt>) | #13, #16, #23 |
| 13 | [Wu and Azure Wyrm presentation](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/13_wu-and-azure-wyrm-presentation.txt>) | #16, #23 |
| 14 | [Player, NPC and normal-enemy visual identity](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/14_player-npc-and-normal-enemy-visual-identity.txt>) | #24 |
| 15 | [Monastery environment and navigable discovery route](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/15_monastery-environment-and-navigable-discovery-route.txt>) | #25, #26, #27, #28, #32, #44 |
| 16 | [Sanctuary framing, terrace and optional routes](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/16_sanctuary-framing-terrace-and-optional-routes.txt>) | #27, #28, #31, #32 |
| 17 | [Build the Bamboo Pass region](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/17_build-the-bamboo-pass-region.txt>) | #22, #27, #28, #32, #44 |
| 18 | [Build the Ash Colosseum campaign region](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/18_build-the-ash-colosseum-campaign-region.txt>) | #22, #27, #28, #32 |
| 19 | [Build Sanctuary Depths and the Sunken Crypt](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/19_build-sanctuary-depths-and-the-sunken-crypt.txt>) | #22, #27, #28, #32 |
| 20 | [Build Celestial Pagoda and its lore route](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/20_build-celestial-pagoda-and-its-lore-route.txt>) | #22, #27, #28, #32, #44 |
| 21 | [Build Sky Citadel and the final approach](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/21_build-sky-citadel-and-the-final-approach.txt>) | #22, #27, #28, #32 |
| 22 | [A real six-sovereign ending and postgame handoff](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/22_a-real-six-sovereign-ending-and-postgame-handoff.txt>) | #10, #28, #42 |
| 23 | [Single-player campaign integration and remaining fixes](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/23_single-player-campaign-integration-and-remaining-fixes.txt>) | #1, #8, #9, #10, #16, #18, #19, #22, #23, #27, #28, #44 |
| 24 | [Multiplayer and persistence integration](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/24_multiplayer-and-persistence-integration.txt>) | Additional multiplayer/persistence acceptance |
| 25 | [Device layouts, controls and accessibility](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/25_device-layouts-controls-and-accessibility.txt>) | #5, #6, #12, #13, #33, #34, #35, #36, #37, #39, #40, #41, #42, #43 |
| 26 | [Performance, audio listening and final coverage audit](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/claude-prompts/26_performance-audio-listening-and-final-coverage-audit.txt>) | #2, #7, #21, #23, #24, #25, #31, #32, #36 |

## Coverage guarantee

Every finding 1–44 is assigned in PROGRESS.md. Findings 22/23 span several location/character batches; finding 4 splits portrait logic and physical clearance. Verification prompts revisit acceptance without authorizing repeated redesign. A full clear, all boss phases/rewards and the ending were not established by the original playtest, so the tracker must preserve that distinction.

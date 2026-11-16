# 09b defects worker progress

Supersedes: nothing (searched workers/ first; no 09b file). Linked from LEDGER.md with the 09 series. Why new: durable log for the 4 defects in test_live_world_mechanics.
Prompt: Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Log
- [d1] PrologueController handoff -> "Gateway Glade" (literal; altar Name in Overworld.lua). test_opening_tutorial string updated to match.
- [d2] TutorialController stakes card: shows once when inside Overworld.Frame, flat distance from phantom HOME > StakesRadius (160, ShowRadius 70), before any altar other than Altar_MonasteryGate is kindled. Skip/complete paths untouched. Stale source-string check in test_opening_tutorial and the DEFECT block in test_live_world_mechanics rewritten to the new intent (old checks asserted removed constants / that the card shows at the landing, contradicting the intent).
- [d3+4] WorldDefinitions relocation: spawn floor at.Y-3 -> at.Y+2. Evidence: Placement.Y is heightAt; Studio voxel surface is heightAt+2 (08-cutover, 09a: phantom ground 62.0 at heightAt 60); root = floor+3 (old spawn() convention) => 65, matches live HRP 65.2 / warden 144.7. Old value spawned the root inside the terrain. AIService toCFrame uses Placement directly (no extra offset). Test assertion unchanged.
- [verify] lune --all 35 PASS (live_world 294/0); plain luau 10/10; tools/test_*.py all pass; luau-compile ok.

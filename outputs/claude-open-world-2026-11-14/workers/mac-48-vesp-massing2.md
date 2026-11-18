# mac-48 Vesperhold massing pass 2 (Sonnet, light lane)

Supersedes: nothing. Linked from CONTINUATION.md "Vesperhold — 2026-11-19". Instruction: lead's mac-48 order (spec: mac-41 "Added targets").

## Plan / files
VesperholdLayout.luau (data: pinnacles P2/P3, crags, viaducts V2/V3, grand stair, spurs, slots), GothicCitadel.luau (rock cores, keep cores, stair steps, span decks, stand-ins for new groups, mirrored cloister ramp, nave door), GothicMarch.luau (lane from Layout), tools/test_vesperhold_massing.luau. Overworld.luau untouched: P2/P3 are rock Part cores because vesperholdWeight support (|x| < 260) is wholly P1.

## Checkpoints
- layout module rewritten (stair, spurs, rocks, spires 71, waterfalls, arch, trees, graves).
- DONE: test_vesperhold_massing 14967/0; 14 Overworld-loading tests pass. Not committed (lead order).

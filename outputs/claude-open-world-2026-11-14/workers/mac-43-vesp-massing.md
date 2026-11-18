# mac-43 Vesperhold massing rework (Sonnet, light lane)

Supersedes: nothing. Linked from CONTINUATION.md "Vesperhold — 2026-11-19". Instruction: lead's mac-43 order (spec: mac-41 plan).

## Plan
1. src/shared/VesperholdLayout.luau: pure data (tiers T0-T3 + crown, walk route, kit slots, viaduct bays/statues, eye, spires).
2. GothicCitadel.luau: add massing from layout (tier cores, arcade-band relief, walk route, vault tags); delete limestone/white palette use, cone turrets, crenels.
3. GothicMarch.luau: tall viaduct on the layout bays, continuous floor, remove red post.
4. Overworld.luau: widen/deepen only the Vesperhold ridge/gorge branch; checksum outside the weight.
5. tools/test_vesperhold_massing.luau.

## Checkpoints
- (start) read spec + sources.
- layout module written; terrain bite added (CHK2 baseline 176934331.5874 on 25-stud grid where weight==0; old-block CHK 59282702.6215 unchanged).
- Citadel rewritten (massing+stand-ins), March viaduct 30-stud bays/red-post field removed/escarpment removed, default.project.json maps VesperholdLayout.
- DONE: test_vesperhold_massing 8012/0; terrain/overworld tests pass (over6 steps 84 vs limit 93); objectives_overworld fails in EndingRules (Vector3 nil, not mine).

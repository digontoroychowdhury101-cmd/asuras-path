# mac-10 biome registries (lane K, source only)

Plan: add Frostmere (32) + Ashen (34) KIT specs to BiomeDressing following D5; Snow/Mountain scatter + SetKits draw from them; pcall-require FrostmereKitRegistry, AshenKitRegistry, HeroKitRegistry; extend tools/test_biome_dressing.luau. No Studio, no uploads, no registry modules, no commit.
Files: src/shared/BiomeDressing.luau, src/server/Services/BiomeDressingService.luau (only if needed), tools/test_biome_dressing.luau, this note.

Checkpoints:
- [step1] manifests read (hero 5, frostmere 32, ashen 34); rows generator in scratchpad; design: KIT rows + LOOKS_FROST/ASH, Slots Snow_Watch_Beacon/Summit_Temple_* -> Frost/Ash heroes, scatter+SetKits swap, old scatter pieces removed (test 'every older slot placed'), HeroKitRegistry fallback in service registryPiece (hero pack subs via Slice.Pieces[slot]).
- [edit] BiomeDressing: 66 kit rows + LOOKS, Slots, scatter/SetKits swapped, old pieces removed, registry loop (Hero,Amberfall,Saltreach,Frostmere,Ashen); service registryPiece hero-pack fallback. Test not yet extended/run.
- [test] test_biome_dressing 19073 passed, 0 failed; Snow plan parts 1005/1500 (was 1270), Mountain 1460/1500 (was 1500); Snow mesh parts 2896<=3000 after Grass spacing 15 / Fern 19; kit use Frost 32/32, Ash 34/34. Next: verify_all.
- [done] verify_all SUCCESS (exit 0). Not done: fixed hero furniture (Snow_Refuge_Hut, Windbreak, Pass_Gate, Mtn_Stair_Run/Retaining_Wall/Refuge_Hall/Pass_Gate) still placeholders; test pins their counts.

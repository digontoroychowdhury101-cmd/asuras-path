# mac-17 Sightline (fault C) + mountain stair sink (lane R2-4, source only, no Studio)

Plan. Files: src/shared/SliceDressing.luau, tools/test_slice_dressing.luau, src/shared/BiomeDressing.luau, tools/test_biome_dressing.luau.
A. Probe tower visibility from eyes 01/07 per blocker (extend section F measure into a scratch probe); move the blocker (vine, shelter, cone rule); raise F threshold to 0.9 for both eyes.
B. Compute exposed height of Mtn_Stair_Run along its length via Overworld.heightAt; fix if bug; add bound test.
Checkpoints follow.
- CHECKPOINT B1 BiomeDressing.luau hero loop: BUG not intended. Stairs climb toward local -Z with underside at the +Z end, but yaw was the path direction A->B (uphill), so the climb ran down the slope: step 0 buried 4-12 studs at the high ground, step 13 stood 16-21 above ground (probe .scratch/probe_r24.luau, 35 Mtn_Stair_Run). Fix: Steps pieces face the rising slope (yaw+180) and sample ground at the +Z low end. After: low-end sink 0.4, treads hug the slope (min exposed top 0.1-0.4 on 29 of 35; steep Summit ramp stairs 1-2 are -7/-4 buried).
- CHECKPOINT B2 test_biome_dressing.luau: per-biome stair check (faces rising slope, low-end sink 0..2); 19077 passed 0 failed. Task A next.
- CHECKPOINT A1 SliceDressing.Cones LowFrac .25 -> .03 (the band the cone guards now starts at the tower foot): probe 74% -> 100% from both eyes (only Set_TowerYard_27 Vine_Hanging blocked f<=.25); lune not yet rerun. Next: check shelter + test threshold.
- CHECKPOINT A2 test_slice_dressing.luau section F: threshold 0.6 -> 0.9 both eyes, Blockout.Shelters added as 10-stud cylinders to the ray list; luau 989/0, 100%/100%. Next lune_compat + verify_all.
- FINAL: lune slice 1013/0, biome 19077/0, verify_all SUCCESS. Probes deleted. Not committed (lane brief).

# mac-99: Bellwood tunnel-exit reveal acceptance capture (2026-11-25, Mac)

This is the bellwood_3 acceptance shot from `LANDMARK-BUILD-SPEC.md`: "the tunnel exit frames the temple on the right third and the gate towers on the left third." It was taken in Studio Play on the build with digest 295/3927822/343383436, with `AsuraCavern` true, QualityLevel 21 (Automatic culls the vault on this Mac, see mac-98) and the character hidden.

## Setup
- **Eye:** (-3650, 158.5, -2375), 4 studs over the passage floor at the exit. The exit is `kitToWorld(Bellwood, Passage[last])` = (-3647, 157, -2376).
- **Bounding boxes:**
  - `Bellwood_ColossalTemple`: centre (-4338, 546, -2234), size 935 x 795 x 648.
  - `Bellwood_GateTowers`: centre (-4018, 173, -2149), size 54 x 51 x 54.
- **Captures** (`captures/mac/bellwood_reveal/`):
  - `mac99_exit_reveal_fov70.jpg`: the player's view at FOV 70.
  - `mac99_exit_reveal_fov32_thirds_attempt.jpg`: a narrower lens solved for the thirds.

## What passes
- The cave reads as underground: there is no sky, and the basalt vault has its strata bands.
- **Light:**
  - amber veins and teal motes;
  - the iris shaft lands on the temple;
  - warm stair lanterns;
  - both guardian lions catch light on their plinths.
- The bare hero tree's crown fills the vault and reads as one silhouette over the tiered temple.
- The causeway leads the eye straight up the stair.

## What fails against bellwood_3 (next steps, in order)
1. **The gate towers are out of scale.** They stand 51 studs tall against a 795-stud temple, and from the exit they are a speck at the temple's left foot. The concept's composition needs them as a tall left-third mass. Proposal: scale the gate towers up to about 4x (to about 200 studs) and move them toward the exit's left. Keep the gate route and `gateFills` collision in step, tests first. Check the walk through the gate afterwards.
2. **The foreground lake is empty.** The concept has lotus pads and flowers, broken colonnade stubs, a sunken wooden wreck and moss rocks in the shallows. Proposal: a small scatter set from CC0 or procedural sources, placed in the shallows between the exit and the temple. It must stay off the causeway.
3. **Floating rock.** A single rock-textured object hangs in the vault at the upper left of the FOV 70 view (screen about 3%, 23%). It is not a BasePart within 1,400 studs of the vault centre, so it is likely a detached terrain blob from the vault fill or a rock-textured effect. Find it and remove or anchor it.
4. **Temple on the centre line.** The causeway points straight at the temple, so the "temple right third" framing only comes from a narrower lens (32). This is a composition choice; leave it unless the creator asks.

The tree root grip is still a stop-and-report item. The procedural method failed twice (v12, v13); it needs a sculpt-and-bake or a CC0 root scan, or a creator decision.

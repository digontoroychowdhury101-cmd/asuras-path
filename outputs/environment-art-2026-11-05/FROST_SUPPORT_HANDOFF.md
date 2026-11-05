# Frost Ridge support and shared build handoff

On Computers B and C, update `ux/onboarding-overhaul` from `origin` and open the checked-in
`places/AsurasPath.rbxlx`. Use `git pull --ff-only` from a clean checkout of that branch. If a machine
has local edits, preserve that checkout and use a separate clean worktree for the verified build.

The canonical XML place and its `outputs/AsurasPath.rbxlx` mirror are byte-identical. The checked-in
binary `places/AsurasPath.rbxl` is rebuilt from the same source. Rojo syncback from the binary
recovered the exact current `BambooDressing.luau` source and calibrated native support model.
The default build refreshes all three artifacts. Verification builds still use a temporary output.

| Artifact | Identity |
| --- | --- |
| Canonical XML SHA-256 | `53f0e974b4f5d5a0e567f5a7037c8fcf19cb621df6d38b53f4e9d20e8279a86f` |
| Binary mirror SHA-256 | `a23b242e88d2e236d8c29785524302ab7ade332808a2f475c1e00966ffb345b6` |
| Open Studio and canonical source | 281 scripts, 2,240,092 source bytes, digest `30630584` |

The three supports now use a purpose-built 14.2-stud limestone mesh, sized to the existing footing
envelopes. The baked UVs keep the cracks and horizontal stone layers readable. Blender round-trip
checks found 384 triangles, one material, three embedded maps and a closed surface. Studio read back
the same dimensions and triangle count. The imported mesh and four Roblox maps loaded successfully.
The editable masters, export and maps are in `assets/build/frost_support_v2`. The authoring and
review scripts, source manifests, real asset IDs and native library are versioned with the build.

The three pairs in `frost-support-before` and `frost-support-after` use the same camera poses,
1271×685 viewport, FOV 70, Bamboo lighting, Detailed tier and ordinary HUD. The parked avatar stayed
at 100 HP in Bamboo. The approach pair stayed at Automatic FRM1. The close and reverse views rose
from FRM1 to FRM4 and FRM6, respectively, so their sharpness and lighting detail also reflect graphics
quality. The old vertical smearing gives way to stone strata at the footings and around the cap joints.

The runtime audit verified all six original colliders, the three landing ray heights of 13.5, 15 and
16.5 studs, and the decorative meshes' disabled collision, query and touch flags. The audit returned
Studio to Edit. All 14 local checks passed. The arena cedar test in `palisade-rejected` still read
nearly black and was removed from the delivered build. The normal jump and return, broader Bamboo
finish, foreground performance, multiplayer, physical mobile and other region acceptance remain open.

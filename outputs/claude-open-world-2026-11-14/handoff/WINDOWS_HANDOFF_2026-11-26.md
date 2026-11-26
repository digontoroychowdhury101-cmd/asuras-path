# Asura’s Path handoff to Claude on Windows (26 Nov 2026, AEDT)

Claude on the Windows PC owns all ongoing development, Git pushes, Blender work, and Roblox Development saves. The Mac is retiring. Start here and read the latest entry in `PROJECT_STATE.md` before using older notes.

## 1. Exact game version, and making the PC's Studio match it
**Git.**
- Branch `ux/onboarding-overhaul`. `498ce7f` contains the last Mac gameplay baseline, the reed source fix, its preview and notes, and the Vesperhold research. Use the latest verified branch head on Windows.
- Inspect local changes and Studio work before switching branches. Run `git fetch origin` and `git pull --rebase origin ux/onboarding-overhaul` from the correct branch after accounting for local edits.

**Windows toolchain.** Install the versions pinned in `tools/toolchain.env`.
- Download the [Luau 0.748 Windows ZIP](https://github.com/luau-lang/luau/releases/download/0.748/luau-windows.zip) and extract the executables into `work/bin/luau/`.
- Download [Rojo 7.7.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) for your Windows architecture and extract `rojo.exe` into `work/bin/rojo/`. Run it with `plugin install` to install the matching Studio plugin if needed.
- Use native Windows Python 3, Git Bash, Blender and Roblox Studio. Confirm Blender MCP lists the active scene and Roblox Studio MCP reports the Development place from the Claude session on this PC. Use the local Rojo plugin on port `34872` for sync.

**Build digest.**
- In Git Bash, run `ASURA_BUILD_OUTPUT=work/verify.rbxlx bash tools/verify_all.sh`, then `python3 tools/studio_mcp.py --digest work/verify.rbxlx`.
- The handoff baseline is **295 scripts, 3,934,626 bytes, digest `1107903586`**. All 14 local stages passed on the Mac with Luau 0.748 and Rojo 7.7.1. Repeat the suite and Play check on Windows.

**Roblox Development place 118614906972571** (universe 10777041159).
- Saved from the Mac at 2026-11-25 13:22Z (Studio log: "Saved new changes").
- Studio Edit printed the same digest from `tools/qa/SourceDigest.luau` just before that save (`AsuraAssets children 24`).
- It was never published.

**On the PC:**
1. If Studio still has an earlier Development session open, preserve any genuine unsaved edits in a separate local copy and close that session before reopening from Roblox.
2. File > Open from Roblox > Asura's Path — Development.
3. In Edit, run `tools/qa/SourceDigest.luau` and compare it with the local build digest. If they differ, establish which source is newer and reconcile any legitimate Studio edits before syncing or saving.
4. Eye check: Play, wait for `workspace:GetAttribute("AsuraCavern")` (about 200 s), then look from the tunnel exit: `CFrame.lookAt((-3650,158.5,-2375), (-4200,300,-2200))`, FOV 70. Compare with `captures/mac/bellwood_colonnade/mac103_exit_reveal_colonnade.jpg`.
5. After Play verification of a new change, use **File → Save to Roblox** on Development. **Never Publish.** Keep the protected `.rbxlx` baselines intact.

### Recovery before erasing the Mac

The checked-in asset IDs are sufficient for the existing game to load. Authoring and registry regeneration also need local source files. In particular, preserve `assets/source/landmarks/bellwood_face/manifest.json` and `assets/source/landmarks/bellwood_colonnade/manifest.json`. Both existed on the Mac and were missing from the `landmark-assets-2026-11-21` branch when checked.

- That asset branch supplies the other three existing Bellwood landmark manifests and `assets/source/landmarks/bellwood_temple_colossal/creator-stair-reference.png`. Restore only missing files. The `codex/overworld-assets-2026-11-16`, `codex/vesperhold-assets-2026-11-19` and `shen-assets-2026-11-09` branches hold earlier asset packs. Use the documented restore tools and keep those branches separate from the code branch.
- Make a private, verified recovery copy with `assets/source/`, `assets/build/`, relevant `work/` files, local Studio and Blender scenes, and `.git` if preserving the existing stash or local-only history. The repo clone does not carry ignored assets, local scenes or the stash. Keep these files outside public GitHub uploads.
- Before clearing the Mac, confirm the PC can read that recovery copy, open the editable scenes you need, find all five landmark manifests and run the Windows checks above. The original Mac-to-PC network copy was unsuccessful, so Windows receipt needs direct confirmation.

## 2. What the Mac did (all tests-first, `verify_all` SUCCESS, saved to Development)
| Pass | Change | Notes |
|---|---|---|
| mac-98 | The Vesperhold "meshes never draw" bug is engine view-distance culling (Automatic quality drops at low fps, in 128-stud chunks). It is not memory or our code, so the residency cut was not done. win-91 verified: shadow tris 8.5M → 3.3M, draws 517 → 207. | `workers/mac-98-vesperhold-dropout.md` |
| mac-99 | Bellwood exit reveal checked against `concepts/bellwood_3`. | `workers/mac-99-bellwood-reveal.md` |
| mac-100 | Gate towers 3x (163 studs), moved left. | `workers/mac-100-bellwood-gate-scale.md` |
| mac-101 | 83 floating ground slivers fixed: air strips now overlap. | `workers/mac-101-bellwood-floating-slivers.md` |
| mac-102 | Lake scatter from uploaded kit pieces (`Basin.Shallows`); `Kit.landmarks()` merges four registries. | `workers/mac-102-bellwood-lake-scatter.md` |
| mac-103 | New Blender kit `bellwood_colonnade.py`. Standing and Toppled are uploaded (127915433158542, 94406393587207, both Approved), registered in `LandmarkKitRegistry`, and placed in the lake at Scale 2.5, framing the temple stair as in the concept. | `workers/mac-103-bellwood-colonnade.md` |

## 3. Work to resume on Windows
- **Lotus and lily-pad kit.** No lotus recipe was in the handoff checkout. Check the current Windows tree and any recovery copy, then finish or create the kit. Use the mac-103 colonnade as an example for pipeline and evidence.
- **Reed_Clump_B.** Commit `498ce7f` carries the heads UV fix in `tools/blender/overworld/bellwood_veg.py`, the updated preview and notes. The remaining work is to verify the bake, re-upload it, read back approved IDs, register it and place it in `Basin.Shallows`.
- **Vesperhold.** The research is in `outputs/research-2026-11-26/vesperhold-60fps-options.md`. Use it for the next measured Windows pass.

## 4. Open items, in order
1. **Bellwood reveal:**
   - lotus and lily cards;
   - re-upload `Reed_Clump_B` heads with fixed UVs (they render candy-striped, so they were left out of the lake);
   - possibly a third colonnade piece toward the stair;
   - make sure the temple's upper tiers and tree stream in before the reveal (slow in Studio Play on the Mac).
2. **Vesperhold 60 fps floor:**
   - frame time is the lever (view distance follows Automatic quality);
   - SLIM / HLOD section shells, then shadow trimming;
   - measure with MicroProfiler with Studio focused, and profile a phone.
3. **Hero tree root grip:** failed twice. Use a new method, or ask the creator.
4. **Bellwood side and rear foundations,** then Amberfall (Cliff Monastery, Broken Ravine Bridge).
5. **Per-region dusk grading,** ground variants on the hills, and walking the hills at player height.

## 5. Landmark kit upload pipeline (as done in mac-103)
1. Blender bake.
2. `vesp_embed.embed(glb, out, maps)`.
3. `glb_split.py`.
4. `upload_batch.py <ledger> landmark=<dir>` with `ASURA_CLOUD_STUDIO` set to the Development window id. Pilot first.
5. `registry_readback.py landmark <ledger> <dir>`. It rewrites the whole JSON from one ledger, so merge only the new pieces into the committed `assets/LANDMARK_KIT_UPLOADED.json`.
6. Add the pack to `kit_registry.py` and to the `test_kit_registry` fixture.
7. Run `kit_registry.py landmark`.
8. Place the pieces in `LandmarkLayout` `Basin.Shallows`. R = scaled half-length; probe `clearance()` in `test_vesperhold_loader` first.

Studio patching: send hunks via `ScriptEditorService:UpdateSourceAsync`, check `#Source` against the file bytes, then run SourceDigest.

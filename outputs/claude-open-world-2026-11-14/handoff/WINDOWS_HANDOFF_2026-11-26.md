# Windows handoff from the Mac (26 Nov 2026, AEDT)

Read this first on the Windows PC. It replaces `MAC_HANDOFF_2026-11-24.md` as the newest cross-machine state.

## 1. Exact game version, and making the PC's Studio match it
**Git.**
- Branch `ux/onboarding-overhaul`, at the mac-103 commit that adds this file or later.
- Run `git fetch origin`, `git checkout ux/onboarding-overhaul` and `git pull --rebase origin ux/onboarding-overhaul`.

**Build digest.**
- `python tools/build.py --output work/latest.rbxlx`, then `python tools/studio_mcp.py --digest work/latest.rbxlx`.
- It must print **scripts 295, bytes 3934626, digest 1107903586**.
- Docs and Blender scripts are not part of the build.

**Roblox Development place 118614906972571** (universe 10777041159).
- Saved from the Mac at 2026-11-25 13:22Z (Studio log: "Saved new changes").
- Studio Edit printed the same digest from `tools/qa/SourceDigest.luau` just before that save (`AsuraAssets children 24`).
- It was never published.

**On the PC:**
1. **If Studio still has Development open from an earlier session, close it WITHOUT saving.** Saving that old copy would overwrite mac-99 to mac-103 in the cloud place.
2. File > Open from Roblox > Asura's Path — Development.
3. In Edit, run `tools/qa/SourceDigest.luau`. It must print the digest above.
   - If it differs, sync the scripts from git (Rojo or `studio_mcp`) until it matches.
   - Then File > Save to Roblox. Never Publish.
4. Eye check: Play, wait for `workspace:GetAttribute("AsuraCavern")` (about 200 s), then look from the tunnel exit: `CFrame.lookAt((-3650,158.5,-2375), (-4200,300,-2200))`, FOV 70. Compare with `captures/mac/bellwood_colonnade/mac103_exit_reveal_colonnade.jpg`.

`assets/source/` (Blender outputs) is gitignored. The game needs only the Approved asset IDs in `assets/*_UPLOADED.json`.

## 2. What the Mac did (all tests-first, `verify_all` SUCCESS, saved to Development)
| Pass | Change | Notes |
|---|---|---|
| mac-98 | The Vesperhold "meshes never draw" bug is engine view-distance culling (Automatic quality drops at low fps, in 128-stud chunks). It is not memory or our code, so the residency cut was not done. win-91 verified: shadow tris 8.5M → 3.3M, draws 517 → 207. | `workers/mac-98-vesperhold-dropout.md` |
| mac-99 | Bellwood exit reveal checked against `concepts/bellwood_3`. | `workers/mac-99-bellwood-reveal.md` |
| mac-100 | Gate towers 3x (163 studs), moved left. | `workers/mac-100-bellwood-gate-scale.md` |
| mac-101 | 83 floating ground slivers fixed: air strips now overlap. | `workers/mac-101-bellwood-floating-slivers.md` |
| mac-102 | Lake scatter from uploaded kit pieces (`Basin.Shallows`); `Kit.landmarks()` merges four registries. | `workers/mac-102-bellwood-lake-scatter.md` |
| mac-103 | New Blender kit `bellwood_colonnade.py`. Standing and Toppled are uploaded (127915433158542, 94406393587207, both Approved), registered in `LandmarkKitRegistry`, and placed in the lake at Scale 2.5, framing the temple stair as in the concept. | `workers/mac-103-bellwood-colonnade.md` |

## 3. Unfinished at hand-off (stopped by the usage limit)
- **Lotus and lily-pad kit** (`tools/blender/landmarks/bellwood_lotus.py`) and the **Reed_Clump_B heads UV fix.**
  - A Mac subagent was building these in Blender. Nothing of it is committed, uploaded or placed.
  - If the script exists on the Mac it is untracked. Redo or finish it, then upload with the pipeline in section 5.
  - `work/vesperhold-claude/heavy.lock` may be left on the Mac; delete it if no Blender job is running.
- **Vesperhold 60 fps research:** a subagent may have written `outputs/research-2026-11-26/vesperhold-60fps-options.md` (uncommitted, Mac only). If it is missing, redo it: how other games handle draw calls, shadow tris, texture memory, SLIM/HLOD, streaming and occlusion.

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

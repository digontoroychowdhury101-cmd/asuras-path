# Claude handoff · Windows · 27 November 2026

## Resume from this checkpoint

- Work in `C:\Users\disha\AsurasPath` on `ux/onboarding-overhaul`. At handoff the HEAD is `b439203` and both tracked changes and new source files are in the working tree. Start with `git status --short`, `git diff --stat`, and the top of [PROJECT_STATE.md](../../../PROJECT_STATE.md). Preserve the pending Shen, UI and Jian files when doing branch maintenance. No staging, commit or push was performed.
- Development v91 is Roblox place `118614906972571`, universe `10777041159`. Edit and the build match at 305 scripts, 4,075,576 bytes, digest `1824603762`. Both Windows single-client and two-client playtests passed. The temporary test scripts were removed before saving.
- Leave `places/AsurasPath.rbxlx` and `outputs/AsurasPath.rbxlx` alone. Build under `work/`. Use the local Rojo server on port `34872` and save to the private Development place after Play verification. Never Publish.
- Follow the project-local ro-engineer and antislop skills. Read the [session summary](../workers/win-108-cinematic-arsenal-and-jian.md) and the [Windows handoff of 26 November](WINDOWS_HANDOFF_2026-11-26.md) for evidence and earlier asset procedures.

## System map

| Area | Where to start | Contract to preserve |
| --- | --- | --- |
| Shen lake | `ShenLakeRules`, `LandmarkLayout`, `Overworld.shenLake()`, `WorldService`, `BossArenas`, `ShenLakeController` | The upper-hall prompt and lake admission remain server-authoritative. The existing Shen boss ID owns progression. Plain-data loaders cannot resolve relative requires, so lake data is lazy. |
| Combat HUD and Respite | `CombatHudStyle`, `InterfaceController`, `HudKit`, `HudLayout`, `UiKit`, `UiWindow`, `PauseMenu` | Keep the established bindings, combat values, modal input, saved comfort preferences and touch control regions. Screen-size calculations are independent of combat. |
| Arsenal and Gao | `ArsenalPanel`, `ArsenalEquipment`, `ArsenalTabs`, `ArmorView`, `PresentationService`, `LootService` | Keep existing inventory and equip actions authoritative. `PresentationService` publishes display clones under `ReplicatedStorage.AsurasPath.ItemInspectionModels`. |
| Camera and staging | `ItemInspection`, `InspectionStage`, `InspectionCues`, `src/client/Vendor` | A shot cancels the last camera tween and uses the current pose. Destroy the item and its marker connections on replacement or close. Preserve the reduced-motion route. |
| Equipped and displayed Jian | `WeaponModels.dressJian`, `CharacterService.attachWeapon`, `assets/models/AsuraWeapon_Jian.rbxmx`, `tools/blender/jian.py` | Keep `AsuraWeapon` as the 4.2-stud hand anchor. Direct MeshPart children retain their surface finishes when avatar colouring runs. Supply the model's Blade, Guard, Grip and Pommel names for camera focus. |

The viewport dependencies are pinned with licences in `src/client/Vendor` and `THIRD_PARTY_NOTICES.md`. TweenService controls shot durations. `spr` controls the selection underline only. The viewport fitter receives the visible part extents. The local cue rig is scoped to the item or transition. Published play reuses the existing Zhao clip markers. Run a native published-animation test if cue timing is changed.

## Jian source and import recovery

1. Open `assets/source/weapons/jian/Jian.blend` on Windows, or run `blender.exe -b -t 4 --python tools/blender/jian.py` under the repo's `work/vesperhold-claude/heavy.lock`. The generator writes the packed scene, GLB, derived maps, manifest and three inspection renders. `ASURA_JIAN_NO_RENDER=1` skips the render pass. The source assets folder is Git-ignored. Add it to the existing private recovery copy if migrating machines.
2. The Blender/glTF export contains one original atlas with four named surface meshes, in stock coordinates. The tip is at Z −2.099 and the pommel ends at Z +2.209. The intended hand centre is near Z +1.70. The blade presents its faces along X. Its edges run along Y. Approved Model asset `126095019171399` came from operation `ebfe5be7-947b-49bb-93f3-d613f4d91e1d`.
3. Use the native asset readback rather than placement in Workspace to recover geometry and map IDs. This upload's importer returned mirrored Z centres with identity rotation. The template uses the GLB part centres and a half-turn around Y. The source GLB and import readback are in `assets/source/weapons/jian/Jian.glb` and `work/codex-inspection-qa/jian-readback.json`. The one-off XML generator is in that same `work/` folder. Existing armour explains the Rojo-compatible model format.
4. Rojo created the MeshParts in the running Edit session with empty MeshIds even though the serialized build carried all four URIs. The saved Development instance was repaired with `MeshPart:ApplyMesh` from the approved asset in Edit, preserving the template CFrame, size and PBR children. A fresh build from the XML contains the URIs. After reconnecting Rojo, verify `AsuraWeapon_Jian.Blade.MeshId` is `rbxassetid://91981030023587` before Play. `WeaponModels` falls back to the original geometry if a template has an empty mesh ID. Use typed instance preloading for checks. Passing raw IDs to `PreloadAsync` gave false failures even while the actual weapon rendered.

## Work remaining

1. **Review the new Arsenal in Development.** Open through the normal binding. Read the Whole view, then Blade, Guard and Grip in rapid succession. Switch to Armour, close during its transition, and reopen. Check pointer, keyboard, gamepad focus and a physical phone if available. Capture comparable desktop and mobile sessions before reporting performance. `outputs/jian-art-2026-11-27/` has Blade and guard renders to compare with Studio.
2. **Check published marker behavior before any release.** Studio confirmed its local Draw and Sheath marks. The existing published clip path and fallback still need direct runtime evidence in the project’s authorized test setup. Preserve its current private Development workflow.
3. **Finish Bellwood acceptance.** Replace the provisional upper-hall relic design after the creator chooses its appearance. Earn Shen's victory through the normal trial and record the final objective and reward together. The seeded Studio workflow and local harness already cover reset and reward idempotence. Follow the Bellwood replacement handoff's order for remaining tree, roots, guardians and foundations.
4. **Resume measured world QA.** The existing Vesperhold and Bellwood backlog is in the prior Windows handoff. Re-establish comparable frame-time measurements on Windows and a phone before making performance claims. Continue terrain and reveal work only after checking the actual current world in Studio.

## Repeat verification

Use the versions in `tools/toolchain.env` and run `bash tools/verify_all.sh` from Git Bash. Set `ASURA_BUILD_OUTPUT` to a path under `work/`. On Windows set `PYTHONUTF8=1`. If Git Bash has no working `python3`, put the existing local Python shim in `work/codex-ui-qa` on PATH. Compute the built XML digest with `tools/studio_mcp.py --digest` and compare with `tools/qa/SourceDigest.luau` in Edit. Check the template MeshIds independently because the digest covers source scripts. Record local, single-client, two-client and hardware evidence separately.

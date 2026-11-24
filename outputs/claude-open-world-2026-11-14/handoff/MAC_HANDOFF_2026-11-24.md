# Mac handoff from the Windows PC (24 Nov 2026)

Read this before running `MAC-LOOP-PROMPT.md`. It records:
- what the PC changed since the Mac's last pass (mac-94);
- where each item in the Mac loop prompt stands;
- the open frame-rate problems, with the plan for each.

## 1. Exact game version
- **Branch:** `ux/onboarding-overhaul`. Commit `7e7fb51` was the PC's last code commit; later commits are documentation only.
- **Check:** after `git pull --rebase`, `python3 tools/build.py --output work/latest.rbxlx`, then `python3 tools/studio_mcp.py --digest work/latest.rbxlx`. It must print **scripts 295, bytes 3927613, digest 335807841**. That is what the PC's `work/verify90.rbxlx` printed at `7e7fb51`; `PROJECT_STATE.md` and the handoff docs are not part of the build. If a later PC commit changes code, its PROJECT_STATE line gives the new digest. Then run `tools/qa/SourceDigest.luau` in Studio (Edit). It must match.
- **Roblox Development place** 118614906972571 is saved at **v53**, carrying every change listed below. It was never published.
- **Audio masters are not in git** (`assets/source/` is gitignored): `assets/source/audio/overworld_win87/` and `overworld_win89/`. Their Roblox ids are all Approved and owned by creator 3148600636, so the game does not need the masters. Hashes are in `assets/OVERWORLD_AUDIO_UPLOADED.json`.

## 2. What the PC did (win-86 to win-90)
| Pass | Change | Evidence |
|---|---|---|
| win-86 | Vesperhold approach cut from 3.6M to 1.3M triangles. Ornament subs (`__Crockets` at radius 2, `__Tracery` at radius 3) fade by detail size, and a fully faded sub gets `Transparency = 1`, so it is really culled (`LandscapeBudget.luau`). Night made readable: moon fill about 100 with +0.42 exposure, Wisps and Spores ambience, `AsuraGlowCap` glowing mushrooms within 160 studs, shadowless qi-aura PointLight on the player at night. | `workers/win-86-vesperhold-perf-night.md`, `captures/win/vesp86/` |
| win-86 | Research: reference-game look, readable darkness, Roblox light and frame budgets. | `workers/win-86-research.md` |
| win-87 | ElevenLabs score: day, night and Vesperhold themes (gain 0.2), plus forest and snow night beds, in `SoundscapeController`. Silent in the lobby and while a boss score plays. | `workers/win-87-audio-terrain.md` |
| win-87b | Rolling hills (`TerrainDef.Hills`): kilometre swells in Bellwood, Saltreach and Frostmere (Frostmere rises only), calm on roads, trails, landmarks, the gorge, the ridge and the world edges. | `captures/win/terrain87/hillshade_before_after.png` |
| win-88 | Vesperhold gate wall: the balustrade and pinnacle crown stand on the wall top (190), not on its face at 170. | `workers/win-88-vesperhold-crown.md`, `captures/win/vesp88/` |
| win-89 | Discovering a POI or landmark shows "PLACE NAME / Discovered" (`WorldMap.newDiscoveries`, `WorldMap.placeName`, `InterfaceController`). An ElevenLabs stinger (`Discovery` cue, 115536619279909, Approved) plays with it. | `captures/win/disc89/` |
| win-90 | Saltreach nights get pale wisps (`Wisps = 0.5`). A test now requires glow life at midnight in every overworld region. | `captures/win/night90/` |

Each pass ran tests first, then `verify_all` (SUCCESS), then a Development save.

## 3. Where each item in MAC-LOOP-PROMPT.md stands
- **First iteration (a) to (c), the Mac matching the PC:** done in mac-83 (digest then 292/3592521/1197901813). Redo (b) with the new numbers in section 1, because the code has changed since.
- **(B) Golden hour:** done in mac-83 (warm back-rim fill, lifted outdoor fill, sun rays ramp while the sun is low). Do not repeat it.
- **(L1) Bellwood:**
  - Done: Fallen Giant's Face and eye tunnel, hidden basin, the Sunken Temple (now the Hollow, v20), gate towers, guardian lions (CC0 scan unchanged, 4 parts of 18k tris or fewer).
  - Open, per `CLAUDE_BELLWOOD_REPLACEMENT_HANDOFF.md` and the mac-94 stop note:
    - the hero tree's **root grip** failed twice (v12, v13), the procedural cling does not read;
    - the side and rear foundations;
    - the bellwood_3 tunnel-exit reveal acceptance capture.
  - The root grip is a stop-and-report item. Try a different method (sculpt then bake, or root meshes from a CC0 scan), or ask the creator.
- **(L2) Amberfall, (L3) Saltreach, (L4) Frostmere, (L5) Ashen Stair:** not started. There are no kit scripts in `tools/blender/landmarks/` beyond the Bellwood ones. Next is Amberfall: Cliff Monastery and Broken Ravine Bridge (`LANDMARK-BUILD-SPEC.md` section 2).
- **(L6) Vesperhold extension and (L7) lore glue:** not started.
- **(C/D/E) Per-region looks:** partly done on the PC:
  - night glow life in every region;
  - region score and beds;
  - rolling hills.
- **(C/D/E) Still open:**
  - per-region dusk grading;
  - ground material variants on the new hills;
  - walking the hills at player height (not yet done on either machine).

## 4. Frame rate (the creator's priority: 60 fps floor, Vesperhold especially, without losing looks)
Research summary (`win-86-research.md`, with Roblox staff guidance):
- Budget 16.67 ms.
- Future-lighting cost is mostly shadow re-rendering near moving things.
- Keep 8 or fewer real lights per view, shadows on 1 or 2 hero lights only.
- Fake the other glows with Neon or emissive maps.
- Use `RenderFidelity` Automatic for engine LOD.
- Let streaming carry the distance, and draw silhouettes with cheap massing or impostors.

### Measured so far (Studio on the PC; frame time is unreliable when the window is unfocused)
| View | Opaque tris before | after | GPU ms before | after |
|---|---|---|---|---|
| Approach (-3220, 700, -6400) | 3.62M | 1.34M | 10.4 | 7.8 |
| Gate (-2930, 672, -6400) | 2.87M | 1.99M | ~10 | ~10 |

### Open problems, in order
1. **Kit meshes that never draw (win-88 finding).** In Studio Play some opaque kit MeshParts are not drawn even though each has `Transparency = 0` and `LocalTransparencyModifier = 0`:
   - the outer top-row arcade bays;
   - the outer 8 of 33 crown balustrades on each side.

   A red `Highlight` drew only the middle ones. Cloning one arcade Stone part made every bay of that mesh draw. `GraphicsMeshParts` showed 44 MB in a 2.9 GB shared Studio process. This points to engine mesh streaming under memory pressure. Where kit is missing, the dark Massing box shows: the creator's "flat slab".

   **First step on the Mac:** reproduce it in a real client (Roblox Player, or a Team Test with one client) at the approach eye. Use `captures/win/vesp88/04-outer-crown-not-drawn-highlight.jpg` as the reference.
   - **If it reproduces:** cut resident mesh memory. Check which kit models are still `ModelStreamingMode.Persistent` (win-86 counted 274 models with 17.2M source triangles). Keep only `Massing` Persistent, let the kit stream as Default, and put a low-cost silhouette in `Massing` for distance.
   - **If it does not reproduce:** note it as Studio-only and move on.
2. **Per-pixel cost at the gate** (about 10 ms GPU with the full-screen PBR facade). Options that keep the look:
   - `CastShadow = false` on the small ornament subs (`__Crockets`, `__Frost`, `__Dress`). Keep it on `__Stone` and `__Tracery`, which carry the readable shadows.
   - Check that every 2048 map is only on subs that fill the screen.

   Measure with `rbx-perf-profiling` (MicroProfiler) with Studio focused before and after. Accept a change only if the side-by-side captures match.
3. **Terrain build cost:** `sampleAt` is about 36% slower after the hills. It runs on the server's background build (budgeted at 6 ms per heartbeat), not the client frame. Watch only.
4. **Real device check:** profile a phone at Vesperhold before calling the 60 fps floor met. Neither machine has done this yet.

## 5. Working notes for the Mac
- Studio QA scripting:
  - **Placing the character:** one `PivotTo` at `Overworld.heightAt + 5`. If terrain is not written yet, the safety return sends the character to an altar, so wait about 35 s after spawn, then place again.
  - **Midnight:** `workspace:SetAttribute("AsuraWorldEpoch", workspace:GetServerTimeNow() - 712.5)`.
  - **Fixed camera:** a client RenderStep bind (`QAView`) with Scriptable camera. To hide the UI for captures, disable every PlayerGui ScreenGui.
- **Audio rule:** `test_audiovisual.py` requires `PresentationAssets.Audio` to hold only Approved ids. Upload, record the row as Reviewing, and wire it only after the readback says Approved. There are 33 cue keys now.
- **Terrain checksum:** the Vesperhold massing checksum guard (`test_vesperhold_massing.luau`) trips whenever lowland terrain changes. Re-baseline it on purpose, with a comment.
- **Constraints:**
  - 8 GB Mac: one heavy job at a time under `work/vesperhold-claude/heavy.lock`, and close Blender before opening Studio.
  - Never stage `outputs/mugen-combat-review-2026-11-09/`.
  - Never modify `places/AsurasPath.rbxlx` or `outputs/AsurasPath.rbxlx`.

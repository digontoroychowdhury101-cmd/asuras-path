# Vesperhold 60 fps: how others solve each frame-time cost (2026-11-26, research only)

Scope: research only. No code was changed. Sources were read on 2026-11-26; Roblox changes often, so each one carries its date. "User report" means a non-staff DevForum post.

**Numbers already in the repo:**
- **mac-98, gate eye (-2930, 672, -6400), QualityLevel 21:** 3.29M shadow tris and 207 shadow draws; 3.33M opaque tris and 170 opaque draws; 516 draws in total.
- **win-86 (Windows Studio):** approach GPU time fell from 10.4 ms to 7.8 ms; the gate stays at about 10 ms.
- **win-68:** the pilgrim road drew 8.9M tris at 65 ms a frame. The silhouette at 1,630 studs took **386 draws** for 0.52M tris.
- **This MacBook:** Studio runs at about 15 fps, and `RenderGPUFrameTime` reads 0. No real client and no phone has been measured yet.

## 1. Shadow-casting triangles
- **(a) Measured:** the shadow pass still costs about as much as the opaque pass: 3.29M tris against 3.33M at the gate. Only `__Stone` and `__Tracery` still cast (win-91).
- **(b) How others handle it:**
  - Roblox's guide says to turn off `CastShadow` on small or distant parts, and that shadows switch off below quality 4 ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve), current docs).
  - Occlusion culling does **not** cull shadow casters ([staff post, Dec 2024, updated Jun 2025](https://devforum.roblox.com/t/occlusion-culling-now-live-in-roblox-client/3300953)). So for the shadow pass, trimming casters is the only lever.
  - The sun casts one shadow draw per cascade for each caster ([user report, Nov 2025 to Jan 2026](https://devforum.roblox.com/t/shadow-draw-calls-are-broken/4045934)).
  - Unreal and Unity likewise keep shadows on hero geometry only and let fine detail rely on contact shading or AO in its maps.
- **(c) Smallest change:** first measure shadow tris by role at the gate. If `Tracery` is a large share, add `sub.Role == "Tracery"` to the win-91 line in `VesperholdKit.place` (`src/server/Services/VesperholdKit.luau`). Update the `small` role check in `tools/test_vesperhold_loader.luau` (lines 197-198) to match. A finer option keeps Tracery shadows only on `Portal*` pieces, the hero gate.
- **(d) Gain and risk:**
  - Gain: the shadow pass loses the Tracery share of 3.29M tris and draws. This is GPU time, and GPU is the Mac's bottleneck (CPU is about 5 ms).
  - Visual risk: lattice shadows disappear from walls under a low sun. In storm or night grading they are faint already.
- **(e) Verify:** at the gate eye with QualityLevel 21, record shadow tris and draws from the Render Stats (Shift+F2) panel before and after. Take a side-by-side capture against `captures/mac/vesp-dropout-2026-11-25/06`.

## 2. Real lights (Future lighting)
- **(a) Measured:** nothing. In code, `Kit.MaxLights = 80`: every Glass and Flame sub gets a shadowless PointLight (range 9-14). `LandscapeBudget.register` range-culls PointLights only under `Sanctuary`, so the Vesperhold kit lights under `Map_Overworld` are never turned off.
- **(b) How others handle it:**
  - Roblox: use fewer lights, limit their range, and turn off `Light.Shadows` ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)).
  - Roblox staff say most of Future's cost is re-rendering light shadows near moving objects ([DevForum, 2025](https://devforum.roblox.com/t/severe-fps-drops-due-to-aggressive-shadow-recalculations-during-object-movementappearance/3875739); summarised by a search, thread not opened).
  - win-86 research: about 8 lights per view, with every other glow faked by Neon or emissive maps. The Neon glass already glows without its light.
- **(c) Smallest change:** in `LandscapeBudget.register` (`src/client/Controllers/LandscapeBudget.luau`), also register PointLights whose part is a Vesperhold kit sub. For example, test `item:FindFirstAncestor("Vesperhold")` next to `root.Name == "Sanctuary"`. The existing 110 / 64-stud range logic and the `LandscapeActiveLights` attribute then apply.
- **(d) Gain and risk:**
  - Gain: unknown. The lights are shadowless, so expect a small CPU saving (LightGrid) and little on the GPU.
  - Visual risk: very low. A range-14 light 110 studs away lights nothing you can see, and the Neon stays lit.
- **(e) Verify:** at the gate and approach, compare `LandscapeActiveLights` with the number of lights. Check the MicroProfiler `computeLightingPerform` and `LightGridCPU` timings before and after, and compare captures.

## 3. Draw calls from many MeshParts (instancing)
- **(a) Measured:** 290 unique MeshIds across 51 pieces. Maps are already shared well: the Stone subs of 30 pieces use 2 ColorMaps, and Frost and Crockets use 1 each.
- **(b) How others handle it:** identical MeshContent with an identical SurfaceAppearance shares one draw call. Uploading the same mesh twice under different ids breaks this ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)). Batching is grouped by spatial cluster ([staff, 2017, may be outdated](https://devforum.roblox.com/t/part-instancing-pre-release-announcement/130333)).
- **(c) Change:** none needed. `AsuraStoneFinish` clones one template per ColorMap, so instancing is kept. To guard it, run the docs' duplicate-MeshId script once in Play.
- **(d) Gain and risk:** none expected.
- **(e) Verify:** draws per view against the count of unique (MeshId, finish) pairs in view.

## 4. Far draw units: SLIM, HLOD, impostors
- **(a) Measured:** 386 draws for the silhouette at 1,630 studs. The four `FAR` groups (Spire, Rose, Lancet, Portal) are Persistent, and win-86 counted 274 Persistent kit models.
- **(b) How others handle it:**
  - **SLIM** ([docs](https://create.roblox.com/docs/workspace/streaming/slim); [announcement, 5 Dec 2025](https://about.roblox.com/newsroom/2025/12/introducing-roblox-slim-scalable-lightweight-interactive-models)):
    - It builds a composited, multi-LOD stand-in in the cloud. The stand-in is drawn when a model streams out, and "when more efficient" even while it is streamed in.
    - Roblox's sample scene went from 2,402 to 1,454 draws, but that number mixes streaming and SLIM.
    - Requirements: StreamingEnabled, a place saved to Roblox, Team Create, and static models only. Runtime property changes break it.
    - There is a [user report of a slowdown in large places](https://devforum.roblox.com/t/slim-scalable-lightweight-interactive-models-causes-major-performance-degradation-in-large-experience-with-updateinstancedclusters2/4070199).
  - **Unreal HLOD** merges many static meshes into one proxy mesh and material at long range ([Epic docs](https://dev.epicgames.com/documentation/en-us/unreal-engine/hierarchical-level-of-detail-in-unreal-engine)).
  - Roblox says to use `Persistent` only "in very rare circumstances" ([Streaming docs](https://create.roblox.com/docs/workspace/streaming)).
- **(c) Smallest step:** a yes/no SLIM pilot before any refactor.
  - Two open questions for this repo:
    - The castle is built at runtime by `GothicCitadel.build`, and SLIM may need a model authored in Studio.
    - `LandscapeBudget` writes `Transparency = 1` to Crockets and Tracery at runtime, which breaks the static rule.
  - The pilot: in Development Edit, place one `Spire` with `VesperholdKit.place`, set `LevelOfDetail = SLIM`, save, and Play.
  - Also try setting `LevelOfDetail` from a server script. If that works, `kitMesh` in `src/server/Services/GothicCitadel.luau` needs one line.
  - If SLIM fails, use the existing authored-HLOD path: a baked far shell per tier, tagged `OverworldLandmarkFar` with `FarBeyond`, which `LandscapeBudget` already swaps. Then drop the kit's Persistent flag.
- **(d) Gain and risk:**
  - Gain: fewer far draws, and fewer distant visible objects, which also helps view distance (section 6).
  - Visual risk: SLIM lowers texture resolution at range and may shift UVs.
- **(e) Verify:** TranscoderStatus, then the LOD tint mode in Studio Visualization Options. Compare draws and tris at the 1,630-stud eye.

## 5. RenderFidelity
- **(a) Measured:** not measured. mac-98 forced Precise and saw no change in the dropout.
- **(b) Roblox docs:** Automatic, the default, renders highest detail under 250 studs, medium from 250 to 500, and lowest beyond 500. Too many Precise meshes is a common problem ([Meshes](https://create.roblox.com/docs/parts/meshes), [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)).
- **(c) Change:** count `RenderFidelity` across kit MeshParts in Play. Act only if some are Precise. `collisionTemplate` already passes `RenderFidelity` to `CreateMeshPartAsync`, but scripts cannot set the property directly.
- **(d) and (e):** only if Precise is found. Then compare far tris.

## 6. "Automatic quality drops view distance" (mac-98)
- **(a) Measured:** at low fps, Automatic quality clips the drawn world along 128-stud chunks. QualityLevel 21 restored it.
- **(b) How others handle it:**
  - Roblox gives no script control. A user report says a counter of visible objects lowers render distance, to as little as 200 studs at level 1 ([Apr 2025, no staff reply](https://devforum.roblox.com/t/improve-or-prioritize-render-distance-at-low-graphics-levels/3596299)).
  - The levers are frame time and fewer visible objects at range (section 4). Fog hides the cut.
- **(c) Change:** none on its own. The win comes from sections 1 and 4.
- **(e) Verify:** in a real client on Automatic at the approach eye, check whether the crown row is fully drawn.

## 7. Occlusion culling
- **(b) How Roblox handles it:** automatic on all platforms since 27 Jan 2025, and terrain has occluded since 23 Jun 2025. Large, simple, opaque geometry occludes best. Small or detailed meshes do not occlude. The Haunt's low-end Android frame time improved by about 33% ([staff post](https://devforum.roblox.com/t/occlusion-culling-now-live-in-roblox-client/3300953)).
- **(c) Change:** none. Keep `Massing` boxes opaque and large: they are the castle's occluders, as mac-98 saw with the arcades. Never make them transparent to hide the "slab".
- **(e) Verify:** Studio wireframe view inside the close (win-68 view 06).

## 8. Fog and atmosphere to hide distance
- **(b) How others handle it:**
  - Atmosphere Density hides distant objects and terrain ([guide](https://create.roblox.com/docs/environment/atmosphere)).
  - Fog does not cull anything; it hides pop-in for nearly free ([user report](https://devforum.roblox.com/t/lighting-realistic-fog-visibility/295818)).
  - The research of 2026-11-25 shows Grand Soul and Elden Ring relying on fog.
- **(c) Change:** only after section 4. Tune the Vesperhold snow profile in `src/shared/EnvironmentProfiles.luau` (`Snow.Density` 0.18) so the far-shell swap point sits inside the haze.
- **(d) Gain and risk:** no frame-time gain. Risk: the skyline reads less clearly.

## 9. SurfaceAppearance texture memory
- **(a) Measured:** the registry holds 244 unique 2048 maps (81 Color, 79 Normal, 79 Roughness, 5 Metalness), most on trees and figures. Persistent FAR models keep their maps resident.
- **(b) Roblox docs:**
  - Memory is set by pixel size, not file size. A 1024 map uses four times the memory of a 512.
  - Uploading the same image twice duplicates it in memory.
  - Reuse maps and tint with `SurfaceAppearance.Color` ([Improve performance](https://create.roblox.com/docs/performance-optimization/improve)).
- **(c) Change:** none that lowers resolution: the creator's 2048 rule stands. Keep sharing tiling maps across pieces, as the architecture already does.
- **(e) Verify:** Developer Console, Memory, `GraphicsTexture` at the approach, on a real client and a phone.

## Ranked shortlist (each small and verifiable)
1. **Per-role shadow tris, then Tracery `CastShadow`.**
   - Measure shadow tris by role at the gate.
   - If Tracery is a large share, extend the win-91 line in `VesperholdKit.place` and the loader test.
   - Accept only if the captures match. It is the largest remaining GPU line, and the diff is one line.
2. **Range-cull the Vesperhold kit PointLights** in `LandscapeBudget.register`.
   - Pass check: `LandscapeActiveLights` stays at or under about 8 at the gate.
   - Check the MicroProfiler before and after.
   - Lowest risk of the three.
3. **SLIM yes/no pilot on one Spire** in the Development place.
   - Confirm SLIM in the TranscoderStatus and LOD tints, then compare draws at 1,630 studs.
   - Find out whether `LevelOfDetail` can be set from a script.
   - The result decides between SLIM and an authored far shell under `OverworldLandmarkFar`.

## Still to measure
- **Real frame times.** Every frame time so far is Studio-only: the Windows window was unfocused and the Mac reads GPU 0. Run a real Roblox Player at the approach and gate eyes, with Automatic quality and the MicroProfiler.
- **The quality level Automatic picks**, and whether the crown clip still happens in a real client.
- **Remaining unknowns:** shadow tris by role, the RenderFidelity spread, `GraphicsTexture` MB, and PointLights in view.
- **A phone at Vesperhold.** The 60 fps floor cannot be called met until one is profiled.

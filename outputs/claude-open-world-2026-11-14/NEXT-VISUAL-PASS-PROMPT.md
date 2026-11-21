# Asura's Path: next open-world visual pass (landmarks + light), 2026-11-21

Paste everything below the line into a fresh Claude Code session, on either machine. It assumes screen takeover, Blender and Studio MCP are available.

---

# TASK: Make the Asura's Path open world look like a AAA key-art screenshot from any angle

You are continuing the open-world art pass on Asura's Path (Roblox, Luau, Rojo). Repo `asuras-path`, branch `ux/onboarding-overhaul`. Work autonomously and don't stop to ask. Stop only for an item listed under "Needs the creator".

## 0. Start of session
1. `git pull --rebase origin ux/onboarding-overhaul`.
2. Read these files:
   - the top of `PROJECT_STATE.md`
   - `outputs/claude-open-world-2026-11-14/workers/win-70-forest-recapture.md` (the win-79 and win-80 sections at the end)
   - `outputs/claude-open-world-2026-11-14/WINDOWS_HANDOFF.md`
   - `docs/BUILD.md`
3. Know what already exists, and reuse it:
   - `EnvironmentProfiles.luau` defines per-region lighting, time of day, the moonlit night, `clouds()` and `ambience()`.
   - `WeatherController` owns the clouds and the ambient particles. `OverworldAmbience` handles pollen, leaves, fireflies, glitter and the lantern lights.
   - `SliceDressingService` places the mesh kits from the registries (`BellwoodKitRegistry`, `SliceKitRegistry` and the four region kits).
   - `VesperholdAtmosphere` provides the castle's local storm.

## 1. Hard rules (never break)
- **Places:**
  - Never edit or save the cloud place.
  - Never modify `places/AsurasPath.rbxlx` or `outputs/AsurasPath.rbxlx`.
  - QA only in a disposable build: `python tools/build.py --output work/<name>.rbxlx`. Open it with `-task EditFile`, close it unsaved, and confirm its hash is unchanged.
- **Heavy jobs:** run one heavy Studio or Blender job at a time. Hold `work/vesperhold-claude/heavy.lock` while one runs.
- **Preserve:** the lobby and lobby lighting, combat, progression, persistent IDs and the single Shen barrier.
- **Luau:** use modern Luau and the `task` library; Schema v4.
- **Art sources:**
  - Allowed: CC0 assets, GPL or MIT generators, art made procedurally in the repo, and the creator's own generated models.
  - Not allowed: Creator Store free models, and anything NC, ND or paid.
  - Record each source in a `SOURCE.md` next to the raw files.
- **Uploads:** upload a pilot first. Record every operation ID and asset ID in a ledger under `outputs/claude-open-world-2026-11-14/workers/`.
- **Commits:**
  - Commit explicit paths only. Never `git add -A`, and never commit `outputs/mugen-combat-review-2026-11-09/`.
  - Append at most 60 words to `PROJECT_STATE.md` per batch, then push.
  - Before ending, `git status` must be clean apart from that review folder.
- **Raw files:** `assets/source/`, `assets/build/` and `*.blend` are gitignored and stay on one machine. Do the whole landmark pipeline on the machine that holds the raw files. Only GLB-derived `.rbxmx` files, registries, ledgers and captures travel through git.

## 2. Priorities (in order; tests first for every code change)

### A. Hero landmarks: the biggest visual win
Every region needs one or two silhouette landmarks visible from far away, like Vesperhold. The creator supplies concept art and high-poly models (ChatGPT images → image-to-3D, or Meshy) in `assets/source/landmarks/<name>/`. For each landmark:
1. **Inspect, then choose a path.** Use Section 4 (the high-poly import procedure). Reuse the existing tools:
   - `tools/blender/ingest_sculpt.py`: splits by height, decimates, unwraps and bakes Color, Normal and Roughness maps at 1024, selected-to-active.
   - `tools/assets/glb_split.py`: keeps each upload under 20 MB.
   - `tools/assets/upload_batch.py`: resume-safe Open Cloud model upload with a ledger.
   - `tools/assets/kit_registry.py`: regenerates the registry Luau.
2. **Grade and weather it to the Vesperhold look.** The look is semi-realistic, weathered and PBR-baked:
   - Stone: desaturated, with roughness 0.7–0.9.
   - Moss and grime gather in the crevices (bake ambient occlusion into the albedo at about 0.35 strength).
   - No glossy AI-generated plastic surfaces.
   - Match the albedo values to the forest bark fix from win-79 (sRGB-corrected, not too bright).
3. **Place it through a registry and `SliceDressingService`, not by hand in Studio.**
   - It is anchored, `CanQuery` on, and `CastShadow` on for the large pieces only.
   - Collision: Box or Hull on the walkable shell. Decorative sub-meshes get `CanCollide=false`.
   - Set the Model's `PrimaryPart`.
   - Give it `ModelStreamingMode=Persistent` only if it must read from more than 1,500 studs; otherwise use Atomic.
4. **Frame it like key art:**
   - Put it on a sightline from the road (rule of thirds).
   - Give it a lit focal point: warm lanterns tagged `AsuraLanternLight` so the night system drives them, plus a glow window or a shrine fire.
   - Give it a foreground frame such as trees, an arch or rocks.
   - Add life near it, such as birds, falling petals or drifting embers, through the existing `OverworldAmbience` kinds or one new kind.
5. **Sunken or flooded structures:**
   - Use Terrain water: dark teal `WaterColor`, `WaterTransparency` about 0.3, `WaterReflectance` about 0.6, `WaterWaveSize` 0.05.
   - Sink the mesh 30–60% below the waterline.
   - Add lily or debris decals and a fog-mist particle sheet just above the water.

### B. Golden hour into the sun (known defect)
Looking west at 17.5 h, the forest understory goes muddy. Fix it in `EnvironmentProfiles`:
- Warm back-rim fill.
- Raise `OutdoorAmbient` a little while the sun is low and in view.
- Add a `SunRaysEffect` ramp (Intensity about 0.08–0.15, Spread about 0.6) that fades to 0 at night.

Write the test first, in `tools/test_weather_composition.luau`. Then take before and after captures at 17.5 h.

### C. Per-region looks at three times of day
Capture noon, dusk and night in Amberfall, Saltreach, Frostmere and Ashen Stair. Fix any region that:
- is black at night,
- has invisible clouds,
- has the wrong particles (for example leaves in a desert), or
- has haze that flattens the silhouettes.

Region identity targets:

| Region | Target look |
|---|---|
| Bellwood | Green-gold shafts of light, deep canopy, fireflies |
| Amberfall | Amber backlight, drifting maple-like leaves, warm haze |
| Saltreach | Bleached white salt glare, heat shimmer, blue shadows |
| Frostmere | Cold blue fill, glitter, crisp long shadows |
| Ashen Stair | Grey-violet ash fall, ember motes, storm deck |
| Vesperhold | Storm and lightning, rose-window glow |

### D. Close-range richness
- **Ground:** `MaterialService` MaterialVariants per region, so ground, rock, sand and snow aren't the default Roblox look. Use procedural or CC0 PBR textures (Poly Haven).
- **Scatter:** rocks, roots, ruins, banners and broken weapons along the roads, at 1 per 8–12 studs near the path and sparse off-path. Use the existing kits first.
- **Decals:** moss, grime, puddles and cracks on flat mesh faces.

### E. Camera polish
- A subtle per-region `ColorCorrectionEffect`: contrast +0.05–0.1 and a saturation tint per region.
- Bloom threshold about 0.95 so only lanterns and windows bloom.
- No `DepthOfField` in normal play; allow it only in cinematic cameras.

## 3. Performance budget (measure; don't guess)
- **How to measure:** with Studio focused (not in the background, where Studio throttles frames), use the `rbx-perf-profiling` or `rbx-scene-analysis` skills at 5 fixed views.
- **Targets:**
  - Frame time ≤ 16.7 ms.
  - Draw calls < 2,500 and visible triangles < 1.5 M.
  - Live particles stay within 420 (`OverworldAmbience.Budget`).
  - No new shadow-casting lights.
- **Landmarks:** each one is ≤ 250k triangles in total, with no MeshPart over 18–20k. Textures are 1024 (Roblox downsamples anything larger).
- **Before committing,** record each landmark's numbers in its ledger.

## 4. High-poly model import procedure (Mesh Splitting / Normal Baking)

Roblox has a hard cap of about 20,000 triangles per MeshPart. Inspect each model and choose **Mesh Splitting** (architectural or mechanical models with distinct parts), **Normal Map Baking with SurfaceAppearance** (sculpted or beveled models with fine detail), or a hybrid. The goal is no visible quality loss and good in-game performance.

### Goal and constraints
1. No single exported mesh exceeds **18,000–20,000 triangles**.
2. Keep the visual fidelity, alignment, materials and textures.
3. Import each model grouped under a single `Model`, with correct origins, collision settings and PBR properties.

### Phase 1: Inspect and decide (Blender)
1. Open the source (`assets/source/landmarks/<name>/`). Turn on **Viewport Overlays → Statistics** and read the total `Tris`.
2. Choose a path:
   - **Path A: Split into sub-meshes.** Choose this when the model is built from distinct elements, such as buildings, gates, bridges or towers. Separate it into logical components, each under 18–20k tris.
   - **Path B: Low-poly + normal-map bake.** Choose this when the triangle count comes from sculpting, subdivision or creases (statues, rubble, roots). Retopologize or smart-decimate a duplicate to under 20k, UV unwrap it, and bake Normal, Roughness and Color onto it. `tools/blender/ingest_sculpt.py` automates this.
   - **Path C: Hybrid.** Split the main assemblies, then bake the detail into any part still over 20k. This is the usual path for big ruins.

### Phase 2: Blender execution
**Splitting:**
1. Select the model and enter Edit Mode (`Tab`).
2. Press `A`, then `P` → **By Loose Parts**. For one continuous mesh, use linked selection `L` along natural seams, then `P` → **Selection**.
3. Back in Object Mode, check in Statistics that each piece is under 18–20k tris.
4. Rename the pieces logically: `<Landmark>_Base`, `_Roof`, `_ColumnsA`, `_Rubble`, …
5. **Alignment:** select every sub-mesh, then `Ctrl+A` → **All Transforms**. Do NOT move the individual origins, so all pieces share one reference point.

**Baking (PBR):**
1. Create the low-poly target (under 20k) with clean UVs.
2. Set Cycles to **Selected to Active**, high-poly → low-poly, with cage and extrusion tuned so there are no ray misses.
3. Bake a tangent-space **Normal** map, plus **Roughness** and **Base Color**. Bake AO and multiply it into the color at about 0.35.
4. Save the maps as 8-bit PNG at 1024×1024 (2048 only for a hero close-up; Roblox downsamples it).

**Export:**
- Export with `-Z Forward`, `Y Up`, Apply Scalings **FBX All**, and Selected Objects + Mesh only. Use FBX for the Studio 3D Importer, or glTF binary (GLB, embedded textures) for the Open Cloud path.
- Real-world scale: 1 Blender metre ≈ 3.57 studs. A doorway is about 2.2 m, so it reads correctly next to a 5-stud character.
- Keep each GLB under 20 MB; otherwise run `python tools/assets/glb_split.py`.

### Phase 3: Roblox Studio import and configuration
1. Use the disposable `work/` copy or the cloud window **for uploads only**; never save the cloud place. Import with **Import 3D**, or upload with `python tools/assets/upload_batch.py <ledger> <prefix>=<dir>` (pilot first, then the rest).
2. In the importer:
   - The tree shows **no red triangle warnings**.
   - Anchored = True.
   - Import.
3. After import:
   - All sub-meshes sit under one `Model`, and `PrimaryPart` is the central base.
   - **SurfaceAppearance** (if baked): add it under each MeshPart and link the uploaded `ColorMap`, `NormalMap` and `RoughnessMap`. Set `AlphaMode` to Overlay only when the model has cutouts.
   - **Collision:** decorative pieces get `CanCollide=false`. Walkable shells use `CollisionFidelity = Box` or `Hull` (`PreciseConvexDecomposition` only on stairs or floors the player walks on).
   - `RenderFidelity = Automatic` (it handles LOD); `DoubleSided` off unless the model has thin cards.
4. Save an XML copy and register it the way the region kits are (`.rbxmx` under `assets/models/` → `kit_registry.py` → the registry Luau), so `SliceDressingService` places it. Add a `default.project.json` mapping if it's a new kit.

### Import checklist
- [ ] It matches the Blender render 1:1 (side-by-side capture saved under `captures/win/<landmark>/`).
- [ ] Every part imported with no 20k/21k failures.
- [ ] Sub-meshes align with no gaps or transform offsets.
- [ ] Collision, PrimaryPart and streaming mode are set.
- [ ] Upload operation IDs and asset IDs are in the ledger.

## 5. Verify, then hand off
1. Run the Lune suites you touched: `python tools/lune_compat.py tools/<suite>.luau`. Then run `bash tools/verify_all.sh` with `ASURA_BUILD_OUTPUT` under `work/`.
2. Take before and after captures from fixed cameras at player height and at a far sightline (over 1,500 studs) for each landmark.
3. Commit explicit paths, append at most 60 words to `PROJECT_STATE.md`, and push. Then report what changed, what's unverified, and the performance numbers.

## Needs the creator (stop and ask only for these)
- Publishing or saving the cloud place (M2).
- Any purchase or paid generation credit.
- A landmark whose source licence is unclear.

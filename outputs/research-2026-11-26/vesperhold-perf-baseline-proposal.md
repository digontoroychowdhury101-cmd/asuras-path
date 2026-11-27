# Vesperhold perf: baseline procedure, one experiment, code-vs-research notes (2026-11-27, Windows, read-only pass)

Sources: `outputs/research-2026-11-26/vesperhold-60fps-options.md`, `outputs/claude-open-world-2026-11-14/workers/mac-98-vesperhold-dropout.md` (the brief's `workers/` path does not exist at the repo root), win-68 and win-86 notes, and `src/` at `f8811d4`. No repo file was changed.

## 1. Repeatable Windows MicroProfiler baseline

### Fixed views
Gate origin is `Overworld.Vesperhold` = (-2800, 650, -6400), yaw -90, so the approach runs along +X. The first three eyes are the ones earlier passes used, so the numbers stay comparable.

| Id | Eye | Target | Source |
|---|---|---|---|
| A approach | (-3220, 700, -6400) | (-2620, 800, -6400) | win-86 eye |
| G gate | (-2930, 672, -6400) | (-2649, 770, -6400) | mac-98 / win-86 eye; target from win-68 view 04 |
| S silhouette | (-4420, 653.8, -6580) | (-2620, 874, -6400) | win-68 view 07 (386 draws) |
| C close (optional) | (-2709, 667, -6490) | (-2712, 766, -6374) | win-68 view 06 (occlusion check) |

Per view, from the Client in Play (execute_luau or the command bar):
1. Stand the character at the eye's XZ: `hrp.CFrame = CFrame.new(x, Overworld.surfaceAt(x, z) + 4, z)`, with `Overworld` from `ReplicatedStorage.AsurasPath.Shared.Overworld`. Weather, ridge fog and streaming all follow the player position, so the camera alone is not enough. A at -3220 is inside the ridge box (weight 1). S at -4420 is outside it (weight 0), so its sky and fog differ by design.
2. `cam.CameraType = Scriptable; cam.CFrame = CFrame.lookAt(eye, target)`. Hide the HUD (`PlayerGui` ScreenGuis `Enabled = false`).
3. Wait 20 s. That covers streaming, terrain writes, LandscapeBudget's 0.4 s refresh settling, and shader warm-up.
4. Run `tools/qa/ViewCost.luau` with `_G.AsuraViewCostSeconds = 10`, three times. It already records frame, CPU and GPU mean/p95, focus loss, SceneAnalysis triangle composition, quality, FRM and memory.
5. Open Render Stats (Shift+F2) and take a `screen_capture`. Transcribe total, shadow, opaque and transparent tris and draws. Scripts cannot read these numbers.
6. Open the MicroProfiler (View > MicroProfiler, or Ctrl+F6), wait about 5 s, pause, then Dump 256 frames.

### Studio settings (record each one in the JSON)
- **Window:** Studio maximised on the primary monitor and focused for the whole capture. Nothing may be clicked or alt-tabbed during a sample. win-86 found an unfocused Studio throttled Present to about 37 ms. Reject any sample where `unfocusedFrames > 0` or `unknownFocusFrames > 0` (ViewCost reports both).
- **Viewport:** keep the same docked layout for every run and record `cam.ViewportSize`. win-68 used 1736 x 824.
- **Graphics quality, pass 1 (comparable):** fixed. On the client, `settings().Rendering.QualityLevel = Enum.QualityLevel.Level21`, the mac-98 setting. Leave `UserGameSettings.SavedQualityLevel` on Automatic. `LandscapeBudget` reads SavedQualityLevel, not the Rendering level, so on desktop it stays on the "Detailed" tier. Record the `LandscapeTier` attribute.
- **Graphics quality, pass 2 (diagnostic):** Automatic. Record the active level if Shift+F2 shows it, and check visually whether the crown row clips (mac-98). Do not use Automatic numbers for A/B comparisons.
- **Frame cap:** if every view reads the same wall time, Studio is capped. Then compare `renderGPU`, as `tools/qa/RegionFrameTime.luau` already notes.
- **Conditions:** weather and lighting are driven by server time, with no override. Record `Lighting.ClockTime`, the player's `AsuraWeather` attribute, and whether a lightning strike landed in the sample (VesperholdAtmosphere flashes every 10-28 s). Run A/B arms interleaved, A B A B A B, in one session, so time-of-day drift cancels.
- **Build:** record the commit SHA, the Studio version and the GPU model.

### Counters per view
- Frame ms (mean, p50, p95), `Stats.RenderCPUFrameTime`, `Stats.RenderGPUFrameTime`.
- Draw calls and tris: total, shadow, opaque and transparent (Shift+F2).
- `LandscapeActiveLights`, `LandscapeHiddenMeshes`, total memory MB, and `GraphicsTexture` MB (Developer Console > Memory).
- MicroProfiler: the GPU wait / Present share; the shadow pass and `computeLightingPerform` / `LightGridCPU`; and the Heartbeat script spike every 0.4 s from `LandscapeBudget.Refresh`. It walks every registered MeshPart, about 3,700 castle subs alone, and nobody has measured it yet.
- Noise floor: the spread across the three repeats of the same arm. A claimed gain must be at least twice that spread.

### Where to save
- **Committed:** `outputs/vesperhold-perf/<YYYY-MM-DD>-win/baseline.json`, one object per view x pass x rep, with the conditions above. Captures go in `captures/win/vesp-perf-<YYYY-MM-DD>/<view>_<arm>_<rep>.jpg`, including the Shift+F2 shots.
- **Not committed:** MicroProfiler HTML dumps (several MB each) go in `work/vesperhold-perf/microprofile/`, which is gitignored. Record each dump's filename and SHA-256 in the JSON, and copy the dumps to the private recovery copy.
- **Real client (stage 2, after the Studio baseline):** join the Development place in the Roblox Player on Automatic. Walk to A and G, dump with Ctrl+F6 and Shift+F2, and save under the same date folder with a `player_` prefix. Single-client and multiplayer results are recorded separately (CLAUDE.md).

## 2. Follow-up experiment: Tracery stops casting shadows

**Hypothesis.** At G, Level21, `__Tracery` subs carry at least 25% of the 3.29M shadow tris. Turning their CastShadow off cuts at least 0.8M shadow tris and at least 0.8 ms median `renderGPU`, and the gate reads the same in a capture.

**Phase 1: client-local probe, no files touched, reversible by restoring or stopping Play.** In Play on the Client, collect every MeshPart under `workspace.Map_Overworld:FindFirstChild("Vesperhold", true)`. Group them by role (`string.match(name, "__(%a+)")`), keeping only parts whose `CastShadow` is true. For each casting role (Stone, Tracery, Pinnacles, Drape, Glass/GlassR, Roof, Iron, statue and tree roles):
1. Set CastShadow false on that role only.
2. Read the shadow tris and draws in Shift+F2.
3. Restore the role.

This gives the per-role attribution table the research says is missing. Then run the full A/B on the Tracery arm alone: baseline vs Tracery-off, interleaved 3x3 at G, plus one pair at A. LandscapeBudget never writes CastShadow on kit parts (it handles only the `AsuraFoliageShadow` tag), so the client writes hold for the whole test.

**Phase 2: only if Phase 1 passes. Two files, one commit, revert the commit to undo.**
- `src/server/Services/VesperholdKit.luau` line 302: add `or sub.Role == "Tracery"`. The finer variant, which keeps the hero gate, is `or (sub.Role == "Tracery" and not name:find("Portal", 1, true))`.
- `tools/test_vesperhold_loader.luau` lines 192 and 197-198: add Tracery to the no-shadow role set and fix the comment "stone and tracery keep theirs".

**Pass** (all three must hold):
- Shadow tris at G fall by at least 25% (at least 0.8M).
- Median `renderGPU` at G falls by at least 0.8 ms, or at least 8%, and p95 is no worse.
- A side-by-side capture against `captures/mac/vesp-dropout-2026-11-25/06` keeps the portal and arcade tracery read. The creator judges this.

**Fail or redirect:** if the Tracery share is under 10%, Tracery is not the lever. Take the largest casting role from the attribution table instead (most likely Pinnacles, see note 1) and repeat Phase 1 for that role. If the A/A spread is larger than half the gain, the result is inconclusive; rerun with the window focused.

## 3. Where the code contradicts the research

1. **More roles cast shadows than "only Stone and Tracery".** `VesperholdKit.place` (line 302) turns shadows off only for `Crockets`, `Frost` and `Dress`. Every other role still casts.
   - That includes `Pinnacles` (18 registry subs, small spiky ornaments), `Drape` (15), the Neon `Glass`/`GlassR` panes (7), `Roof`, `Iron`, `Ivy`, `Twigs`, `Branches`, and the statue and tree roles.
   - The research's claim that Tracery is the only lever beyond Stone is therefore unproven. Attribute shadow tris per role before deciding.
2. **The 900-stud cut toggles Transparency on far more than Crockets and Tracery.** `LandscapeBudget.Refresh` sets `Transparency = 1` on every kit MeshPart without `AsuraKeepFar` once it is beyond 900 studs (lines 139-150).
   - `AsuraKeepFar` goes only on Stone, Roof, Iron and Glass in the FAR groups (`GothicCitadel.luau`, lines 60-61 and 74-79). So most kit meshes flip Transparency at range.
   - This matters for the SLIM pilot, which needs static models (research §4), and for mac-98's warning that 0/1 transparency toggles force re-batches.
   - It also means the 386 draws at S come only from KeepFar subs of Persistent FAR models.
3. **"Vesperhold snow profile, `Snow.Density` 0.18" is not Vesperhold-specific.** `Snow` (`EnvironmentProfiles.luau`, line 203) is a global weather state that adds density in every region.
   - Vesperhold's own haze is the ridge term (lines 400-419: `fog.Density += 0.11 * ridge`, then `+ 0.05 * ridge`). The ridge also thickens the cloud deck to `RidgeDeck` (line 481).
   - Tune those terms, not `Snow`, or other snowfields change too.
4. **The light count is higher than research §2 describes.** Besides up to `Kit.MaxLights = 80` kit lamps, `VesperholdAtmosphere` adds 12 candle-glow PointLights (range 12, picked within 250 studs) and one 60-range burst light per tower.
   - `MaxLights` is one cap shared by every kit using `VesperholdKit.place`, including Bellwood, Slice and Saltreach landmark pieces. Build order decides which pieces get lamps.
   - The Vesperhold registry has no `Flame` role; only Glass and GlassR light.
   - The research's point stands: lights under `Map_Overworld` are never range-culled (`LandscapeBudget`, line 59, checks only `Sanctuary`).
5. **"GPU is the Mac's bottleneck" is inferred, not measured.** The Mac reads `RenderGPUFrameTime` 0 (mac-98). Only Windows can measure GPU time. This is another reason the baseline above runs on Windows with the window focused.
6. **The volumetric cloud deck has not been costed.** At the ridge, Clouds Cover reaches up to 0.98 and Density 0.82 (`EnvironmentProfiles.clouds`). mac-98 turned clouds off only to test the dropout, not frame time.
   - Add a clouds-off control pair at A and G in the baseline. This is a measurement only, with no code change.
7. **Consistent with the research (no action):** Persistent FAR groups (`GothicCitadel.luau`, line 75); kit lights shadowless (`VesperholdKit.luau`, line 198); Tracery and Crockets detail radii of 3 and 2 (`LandscapeBudget.luau`, line 19); streaming at 128 / 1024 with Opportunistic stream-out (`Config.luau`, line 133); Future lighting (`default.project.json`, line 106); loader test lines 197-198 cited correctly.

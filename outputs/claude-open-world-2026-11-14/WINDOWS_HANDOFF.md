# Windows handoff: Mac landmark loop, 22 November 2026 (Bellwood: face, tunnel, basin and temple hall)

**Historical procedures.** Start with the [26 November Windows handoff](handoff/WINDOWS_HANDOFF_2026-11-26.md) for current Windows ownership and next work. This record replaced the 19–21 November handoff (Vesperhold castle run
3b plus the Windows and Codex records). That version is in git history at `97deae7`:
`git show 97deae7:outputs/claude-open-world-2026-11-14/WINDOWS_HANDOFF.md`. Its open Vesperhold items are carried over
in §8. The resume prompt is [handoff/WINDOWS_RESUME_PROMPT.md](handoff/WINDOWS_RESUME_PROMPT.md).

- Branch: `ux/onboarding-overhaul`. The last Mac code commit is `d7ccb63`; use the remote HEAD that contains this file.
- Source assets (gitignored) are on branch `landmark-assets-2026-11-21` (tip `9522423`).

## 0. Read order and precedence
1. `CLAUDE.md`: the repo rules. Its "git add -A" line is overridden: commit explicit paths only (see §6).
2. This file.
3. The top lines of `PROJECT_STATE.md`. The newest line is at the top; the `(Mac)` lines are this run.
4. The spec, which is the contract:
   - `outputs/claude-open-world-2026-11-14/LANDMARK-BUILD-SPEC.md`
   - `concepts/*.webp`. Open and look at them.
   - `NEXT-VISUAL-PASS-PROMPT.md`
   - `outputs/vesperhold/THIRD_PARTY.md` (texture licences)
5. The loop prompt the Mac ran: `MAC-LOOP-PROMPT.md`. Everything in it still applies, except where §1 changes it.
6. **State at this checkpoint: `handoff/CLAUDE_RETURN_HANDOFF.md`** (Sol's hand-back, verified on the Mac). Older still: the mac-91 delta in `handoff/SOL_RESUME_PROMPT.md` §2–§4:
   - Sourcing is widened to CC0/CC-BY/MIT open models and repos.
   - ElevenLabs SFX are approved; 26 were generated.
   - The gate towers are baked.
   - The prompt also has the updated next steps. It is the current entry point for any agent (Claude, Codex or ChatGPT Sol).

## 1. Creator decisions made on 22 November (these override older docs)
- **Save builds to Roblox. The creator chose this explicitly.**
  - Older docs say the cloud place "stays M1 v9" and must never be saved. That no longer holds.
  - The creator wants verified builds saved to the Development place (placeId `118614906972571`, universe `10777041159`), because a cloud-saved place is what lets Studio grant all the MCP and script permissions.
  - Use **File > Save to Roblox / Save to Roblox As**, which creates a saved version. **Never use Publish**; going live is still forbidden.
  - Still never modify `places/AsurasPath.rbxlx` or `outputs/AsurasPath.rbxlx`.
- **No triangle cap.** "There is no 250k cap."
  - Visual quality comes first: sub-meshes under about 18–20k tris, no decimation, 2048 maps.
  - The spec's 250k line is void.
- **The eye tunnel leads down underground**, not straight through. This is done.
- **"Why is it so smooth and lacking detail":** keep pushing surface detail (HIGH-poly bakes, weathering, moss). Clean, flat surfaces get rejected.
- Free sources only: procedural code in the repo, Poly Haven CC0, and the creator's concept art.
  - No Meshy or other paid generation.
  - No Creator Store free models, and no NC, ND or paid assets.

## 2. Where Bellwood stands (spec §1), all in game and verified in Play on the Mac
| Part | State | Where |
|---|---|---|
| Fallen Giant's Face + crown | Uploaded and placed. The face was re-uploaded on 22 Nov with the bore end opened. | `tools/blender/landmarks/bellwood_giant_face.py`, `bellwood_giant_crown.py`. Model IDs: face `131930696366547`, crown `70377213417316` |
| Eye tunnel | Level into the socket, then a bending 35-stud descent over 150 studs. The terrain passage runs on into the basin. It has 2 warm lantern niches, drip and moss-mote emitters, and invisible `AsuraShelter` roofs so rain never falls inside. | `src/server/Services/LandmarkWorld.luau` (`carves`, `packs`, `tunnelFx`, `shelters`, `lantern`) |
| Hidden basin | A 350 × 300 bowl behind the face. Rim: 128 segments of stepped rock/slate/basalt strata with a LeafyGrass cap and grass wedge slopes outside. Lake: 2.5 deep at the shore, 8 deeper from 36 studs in (cut to air first, because water does not replace solid voxels). Road sightline test from 8 road points. | `LandmarkWorld.basin`, `.lake`; numbers in `src/shared/LandmarkLayout.luau` `Basin` |
| Sunken Temple **main hall** | Two-storey hall, 90 × 59 × 59 studs, uploaded (2 parts Approved). It stands in the deep lake, facing the passage exit, on the right of the exit view, with the stair wading in and the deck 0.1 over the water. Collision: Stone precise, Lacquer default, roofs none. 60 fps in Play. | `tools/blender/landmarks/bellwood_temple_hall.py`; `LandmarkLayout.Basin.Temple`, `templeSpot`; `LandmarkWorld.templeFrame`. Model `113452079836448` (part 2 `71016664280110`) |

**Acceptance captures:** `outputs/claude-open-world-2026-11-14/captures/mac/bellwood_face/`. Newest:
- `ingame_temple_hall_from_exit.jpg`
- `ingame_basin_aerial_deep_lake.jpg`
- `ingame_tunnel_sheltered_rain.jpg`

The older ones show the defects that were fixed.

**Cloud Development place:** saved twice on 22 Nov. The last save was the `d7ccb63` build (temple hall included), via Save to
Roblox As > Asura's Path — Development > Overwrite. It was saved, not published.

## 3. Get the exact Mac state on Windows
1. Check local changes first. Then `git fetch origin` and fast-forward `ux/onboarding-overhaul`. Never reset, clean, stash or force-push.
2. **Restore the gitignored landmark sources** (GLBs, 2048 maps, renders and manifests) without switching branches:
   ```
   git fetch origin landmark-assets-2026-11-21
   git checkout origin/landmark-assets-2026-11-21 -- assets/source/landmarks
   git reset -q -- assets/source/landmarks
   ```
   The files stay on disk but out of the index. `tools/assets/kit_registry.py landmark` needs
   `assets/source/landmarks/{bellwood_face,bellwood_temple}/manifest.json` present, or it refuses to write.
3. Run the full check: `ASURA_BUILD_OUTPUT=work/verify.rbxlx bash tools/verify_all.sh`. It must end in `SUCCESS` (it did on the Mac at `d7ccb63`).
   - The two landmark test files are:
     - `tools/test_landmark_layout.luau` (32 checks)
     - `tools/test_vesperhold_loader.luau` (174 checks)
   - Run them with `python3 tools/lune_compat.py tools/<name>.luau`.
   - If a stray `tools/_lune_*.generated N.luau` appears (a sync duplicate), move it out of the repo; never commit it.
4. Install the Windows releases pinned in `tools/toolchain.env` using `docs/BUILD.md`. The verifier supplies the Lune compatibility shim. Blender 5.2.2 LTS built every landmark covered by this handoff.

## 4. What to do next, in order (one kit or one placement step per iteration, verified and pushed)
1. **Sunken Temple, remaining spec pieces** (spec §1, "Sunken Temple"). Build each like `bellwood_temple_hall.py`: a Blender script under `tools/blender/landmarks/`, clay first, then a bake.
   - **The tree:** a giant crimson maple out of the roof ridge, roots strangling the roof tiers, crimson leaf particles (OverworldAmbience Leaves kind).
   - **Twin gate towers** (paifang-pagoda) with a moss stair between them on the **left third of the exit view**. The hall already holds the right third; the reveal shot must match `concepts/bellwood_3_sunken_temple_reveal.webp`.
   - **Hall dressing:** red banners with a gold wheel sigil (our own design, never a copied sigil), a bronze gong inside, hanging vines and moss.
   - **Midground:** a toppled stone colonnade in the water.
   - **Right foreground:** a headless guardian lion on a plinth with red ivy.
   - **On the water:** a boat wreck, lily pads and pink lotus cards.
   - **Water and air settings:** terrain WaterColor about (40, 58, 52), WaterTransparency 0.3, WaterReflectance 0.6, WaveSize 0.05; low mist over the water; SunRays. Change these only inside the basin, or zone them so the lobby lighting is untouched.
   - **Placement:** each piece gets an entry like `Basin.Temple`, with a test first.
2. **Fix the visible defects listed in §7.**
3. Then, in spec order:
   - Amberfall (§2)
   - Saltreach (§3)
   - Frostmere (§4)
   - Ashen Stair (§5)
   - the Vesperhold extension (§6, attached to the existing castle through `VesperholdLayout` / `VesperholdKitRegistry` / `VesperholdKit`; see §8 first)
   - lore glue (§7; waystone shrines make a good quick win between heavy jobs)
4. Between heavy jobs: region C/D/E lighting, ground and grading (NEXT-VISUAL-PASS-PROMPT priorities).
5. Speed up collision cooking: precise decomposition on big meshes makes the landmark appear about 5.5 minutes into Play.

## 5. Procedures (exact, as run on the Mac)
**Tests first.** Add the failing check, then change the code, then run both landmark tests and `verify_all.sh`.

**Disposable Studio build:**
- Run `python3 tools/build.py --output work/latest.rbxlx`, or copy the `work/verify.rbxlx` that `verify_all.sh` wrote.
- Open the file locally in Studio. Check with `list_roblox_studios` that `persistedToCloud` is false before Play.

**Play check and capture:**
- Start Play and wait about 330 s. The landmark needs collision cooking, so `Landmark_Bellwood` appears only after about 5.5 minutes; run the wait in the background.
- On the server (`execute_luau`, datamodel Server):
  - Set the noon light with `workspace:SetAttribute("AsuraWorldEpoch", workspace:GetServerTimeNow() - 1650)`.
  - Anchor the HumanoidRootPart near the subject but out of frame.
  - Read the world points from `LandmarkWorld` / `LandmarkLayout`, e.g. `kitToWorld(bw, bw.Tunnel.Passage[#...])` for the exit and `templeSpot`, and store them as workspace attributes.
- On the client:
  - Disable the ScreenGuis.
  - Bind the camera with `RunService:BindToRenderStep("__cap", Enum.RenderPriority.Last.Value + 10, ...)` (Scriptable, `CFrame.lookAt`).
- Wait about 6 s for the SurfaceAppearance maps to stream in. The first frame shows untextured white roofs; that isn't a defect.
- Screenshot the viewport and save it as a jpg under `captures/mac/<landmark>/`, or `captures/win/...` on Windows.
- Measure fps by counting RenderStepped over 4 s (the hall scene: 60).

**Heavy jobs (Blender bakes):**
- Only ONE machine-wide. Create `work/vesperhold-claude/heavy.lock` before starting and delete it after.
- On the 8 GB Mac, Studio was closed for every bake.
- Command: `Blender -b --python-exit-code 1 -P tools/blender/landmarks/<script>.py -- [out_dir]`
  - Set `HALL_MODE=clay` first and review the clay sheet; then set `HALL_MODE=bake`.
  - Other scripts have their own `*_MODE` env; read each script's header.
- Outputs go to `assets/source/landmarks/<pack>/`: GLB, `maps/`, `renders/` with a `*_sheet.jpg`, and `manifest.json` (foot frame, bbox, collision per role).
- Look at the sheet and the close render before moving on.

**Upload pipeline:**
1. Push the sources to the asset branch. Use a temp index: `GIT_INDEX_FILE=<tmp> git read-tree origin/landmark-assets-2026-11-21`, then `git hash-object -w` and `git update-index --add --cacheinfo` for each file (each under 100 MB), then `git write-tree`, then `git commit-tree -p origin/landmark-assets-2026-11-21`, then `git push origin "<commit>:refs/heads/landmark-assets-2026-11-21"`. In zsh, write `${C}`, not `$C:` (`:r` is a modifier).
2. **Embed and split:**
   - `VESP_EMBED=jpeg python3 -c "import sys; sys.path.insert(0,'tools/blender/vesperhold'); import vesp_embed; vesp_embed.embed(<glb>, work/landmark_upload_<run>/embed/<name>.glb, <pack>/maps)"`
   - then `python3 tools/assets/glb_split.py <embedded.glb> work/landmark_upload_<run>/split`.
   - Every part must be ≤ 20,000,000 bytes.
3. **Cloud window, for upload only:**
   - Launch Studio with `-task EditPlace -placeId 118614906972571 -universeId 10777041159`.
   - Read its studio id from `list_roblox_studios`.
   - Pilot first: copy part 2 to `pilot/`, then run `ASURA_CLOUD_STUDIO=<id> python3 tools/assets/upload_batch.py outputs/claude-open-world-2026-11-14/workers/<run>-landmark-ledger.json landmark=<pilot dir>`.
   - Check the ledger entry is `Approved`, then upload `rest/`.
   - Close the window with File > Close Place. Never save the upload window itself.
4. **Readback REWRITES the whole `assets/LANDMARK_KIT_UPLOADED.json` from one ledger:**
   - Merge the previous ledger's entries into the new ledger first (mac-90's ledger holds face, crown and hall).
   - Point it at a parent dir holding every piece's `*.split.json` one level down, e.g. `all/prev/` + `all/temple/` (it globs `*/*.split.json`).
   - Command: `ASURA_CLOUD_STUDIO=<id> python3 tools/assets/registry_readback.py landmark <ledger> <parent dir> --cache <rb.json>`.
5. `python3 tools/assets/kit_registry.py landmark` regenerates `src/shared/LandmarkKitRegistry.luau`. A new pack must be added to `KITS["landmark"]` in `tools/assets/kit_registry.py`, and the fixture in `tools/test_kit_registry.py` given that pack's manifest.
6. **Placement:**
   - Add a layout entry with the manifest foot frame. Blender (x, y, z) → model (-x, z, y); the model front is +Z.
   - Fidelity roles go in `LandmarkWorld.Fidelity`: a role it doesn't list never collides.

**Saving to Roblox** (after a verified Play check, from the local build in Edit mode):
1. File > Save to Roblox As > "Asura's Path — Development" > select the existing place > Overwrite.
2. Studio says "Applying script changes. Studio will close automatically"; click OK. Then "Successfully saved!", then Close.
3. Studio may then auto-open the cloud place ("Setting up server…"). Cancel that if you need Studio closed.
4. Never press Publish.

## 6. Repo hygiene rules from the loop
- **Commits:**
  - Commit explicit paths only, never `git add -A`.
  - Never commit `outputs/mugen-combat-review-2026-11-09/`, `assets/source/`, `.blend` files, `.mcp.json` / `.claude.json`, or the blender-skills files (no licence).
  - End each commit message with the co-author line the repo uses.
- After every verified step:
  - Append ≤ 60 words tagged `(Mac)` or `(Windows)` at the top of `PROJECT_STATE.md`.
  - Push, then check that `git status` is clean.
- Pre-existing untracked files that are **not ours**, so leave them alone:
  - `.scratch/probe_r24.luau`
  - `ShenHandoff-2026-11-09/`
  - `outputs/vesperhold/AsurasPath-Vesperhold.rbxlx`
  - `outputs/vesperhold/walkthrough.mp4(.json)`
- **Never break:**
  - the lobby, `Workspace.Sanctuary`, `ServerStorage.AsuraLobbyKit` or the lobby lighting
  - combat or progression
  - persistent IDs
  - the single Shen barrier
- Never clear all of Workspace or Terrain. Always use the task library and modern Luau.
- No two-client or multi-server tests on the MacBook. Windows can run them.

## 7. Known defects (fix before calling Bellwood done)
- **Rim strata band too evenly:** from above, the rock/slate/basalt tiers read as regular black stripes. Vary them per segment (tier height, which material, set-back) and add ledge vegetation or a waterfall. See `ingame_basin_aerial_deep_lake.jpg`.
- **Dark vertical streak on the left rim cliff** in the exit view (`ingame_temple_hall_from_exit.jpg`). Probably a strata box edge or a slope wedge seam. Not yet investigated.
- **The reveal isn't the concept shot yet:** the left third (gate towers), the tree, the mist and the water colour are still missing (§4.1).
- **The hall is 90 wide;** the spec says the temple complex is about 120. The towers and colonnade should make up the width.
- **The landmark appears about 5.5 minutes into Play** because of collision cooking (§4.5).

## 8. Vesperhold castle lane, carried over from the 21 Nov handoff (`97deae7` §7–8; read it there for detail)
- **In game:** the approved set is uploaded and registered. That's 38 pieces, all Approved, with the forest retone2 101/101.
  - Ledgers: `uploads/vesperhold_upload_ledger.json` and `uploads/forest_retone2_upload_ledger.json`.
  - Checkpoint: `places/checkpoints/AsurasPath_Vesperhold_2026-11-21.rbxlx`.
- **Held, waiting for the creator's review:** pass 4 (`74d9c6e`), 13 pieces in 19 local parts under `work/vesperhold-claude/win68/split` (on the Windows PC).
  - The pieces: statues, Dead_Pine_Snapped_A/B, Dead_Stump_A/B, Viaduct_Bay, Viaduct_Balustrade_30, Waterfall_Sheet_A/B.
  - Sheets: `outputs/vesperhold/kit-renders-win/F1_statues_v4_win.jpg`, `gate_a_held_pass4.jpg`.
  - After the creator approves: upload with a pilot, read back, then promote the checkpoint (old §4 step 6).
- The Vesperhold extension (spec §6) attaches to this castle. Don't start it before the held set is settled.

## 9. Housekeeping done 22 November
- Moved 15 unreferenced scratch places (78 MB) from `work/` to the Mac Trash (`~/.Trash/asuras-path-places-2026-11-22`). They were old QA, handoff, diag and canopy copies, plus a byte-identical duplicate of `places/checkpoints/AsurasPath_Vesperhold_MacHandoff_2026-11-19.rbxlx`.
- Kept every place a doc or tool references, all tracked checkpoints, and the other Roblox experiences.

# Resume prompt for ChatGPT 6.2 Sol (Codex), 22 November 2026: Asura's Path landmark and audio loop

Paste everything below the line into ChatGPT 6.2 Sol (Codex) at the repo root. It replaces neither `WINDOWS_HANDOFF.md` nor
`AGENTS.md`. It is the entry point that tells you to read them, and adds what changed on the Mac on 22 Nov (mac-91).

---

You are continuing **Asura's Path**, a Roblox action game built entirely by AI agents for a creator who does not write code.
Repo: this folder. Branch: `ux/onboarding-overhaul`. Continue the work; don't start over. Work autonomously. Don't ask
the creator anything unless a stop condition below applies. After each step, write a one-line status.

## 1. Sync and read (in this order, in full)
1. Sync safely.
   - Run `git status` first.
   - Run `git fetch origin`, then fast-forward `ux/onboarding-overhaul`. Never reset, clean, stash or force-push.
   - Preserve untracked files you didn't create: `.scratch/probe_r24.luau`, `ShenHandoff-2026-11-09/`, `outputs/vesperhold/AsurasPath-Vesperhold.rbxlx` and `outputs/vesperhold/walkthrough.mp4*`.
2. Read `AGENTS.md` and `CLAUDE.md`. Their rules bind you too: modern Luau, the task library, commit discipline and the handoff protocol.
3. Read the top of `PROJECT_STATE.md` (the newest lines are first).
4. Read `outputs/claude-open-world-2026-11-14/WINDOWS_HANDOFF.md` in full. It has the state, creator decisions, every exact procedure (§5), the known defects (§7) and the ordered plan (§4).
5. Read the spec in full:
   - `outputs/claude-open-world-2026-11-14/LANDMARK-BUILD-SPEC.md`
   - `NEXT-VISUAL-PASS-PROMPT.md`
   - `outputs/vesperhold/THIRD_PARTY.md`
   - every `concepts/*.webp` image. Look at the images; they are the art target.

## 2. Creator decisions (current; they override older docs)
- **Quality bar:** "this needs to look stunning". Visual quality wins over triangle budget. There is no total tri cap. Keep sub-meshes under 18–20k tris, never decimate, and use 2048 maps.
- **Sourcing, widened 22 Nov:** open-source GitHub repos, free Blender or 3D models and any open model that looks great and fits are all allowed.
  - Accept only licences that allow commercial game use: CC0, CC-BY (with credit in `outputs/vesperhold/THIRD_PARTY.md` and `assets/CREDITS.md`), or MIT/BSD/Apache.
  - Still never: NC, ND, "editorial", paid, unclear licences, Roblox Creator Store free models, or Meshy or other paid 3D-generation credits.
  - Verify the licence on the asset's own page before you download it.
- **Sound:** ElevenLabs sound effects are approved. The creator wants SFX for Vesperhold and every other region and landmark.
- **Roblox:** save verified builds to the Development place (placeId 118614906972571, universe 10777041159) with File > Save to Roblox. **Never Publish.** Never purchase, and never change settings or permissions.
- **Never modify** `places/AsurasPath.rbxlx` or `outputs/AsurasPath.rbxlx`.
- **Never break:** the lobby (`Workspace.Sanctuary`, `ServerStorage.AsuraLobbyKit`, lobby lighting), combat, progression, persistent IDs or the single Shen barrier. Never clear all of Workspace or Terrain.
- **Never invent asset IDs.** IDs only come from upload ledgers and readback.
- **Never commit:**
  - credentials, `.mcp.json`, `.claude.json`;
  - `assets/source/` (gitignored; raw assets go to branch `landmark-assets-2026-11-21`);
  - `.blend` files;
  - `outputs/mugen-combat-review-2026-11-09/`;
  - the blender-skills files.
- Never touch the folders `Codex`, `Obsidian Vault` or `Cagebound_Archive` outside this repo.
- On the MacBook, never run two-client or multi-server Studio tests. Those belong on the Windows PC.

## 3. State at handoff (mac-91, 22 Nov)
- **Bellwood (§2 of the handoff):**
  - Already in the game on Roblox: the Giant's Face and crown, the eye tunnel with rain shelters, the deep basin lake and the Sunken Temple hall (model 113452079836448).
  - The last cloud save is the d7ccb63 build.
- **Gate towers, mac-91:**
  - Builder: `tools/blender/landmarks/bellwood_gate_towers.py`. It makes twin three-tier stone pagoda towers with curved tile roofs, a roofed gate beam, a 28-step moss stair, roots and red prayer ribbons.
  - Clay and bake are done: 70k LOW tris in 7 subs under 18k each, 2048 maps, CC0 Poly Haven bases.
  - The raw GLB, maps and renders are on branch `landmark-assets-2026-11-21` (commit 659168d). A reference sheet is at `outputs/claude-open-world-2026-11-14/captures/mac/bellwood_face/gate_towers_bake_sheet.jpg`.
  - **Not uploaded yet**, so there's no asset ID.
- **Gate placement code is done and tested, but not seen in Studio.**
  - `Basin.Gate` and `Layout.gateSpot` in `src/shared/LandmarkLayout.luau`, with Foot from the manifest.
  - `World.gateFrame` and `World.gateFills` in `src/server/Services/LandmarkWorld.luau`. The fills are a mud footing under the steps and a rock ledge at landing height.
  - Tests: layout 40/0, loader 179/0. verify_all SUCCESS.
  - Until the kit is uploaded and registered, the build only warns that the gate is missing.
  - Open design point: the stair ends on a terrace about 14 above the water, while the rim cap is 45–60 higher. A path or notch up to the forest is still to design.
- **Audio, mac-91:**
  - 26 ElevenLabs SFX (MP3, 44.1 kHz) in `assets/source/audio/{vesperhold,bellwood,regions}/`, also on the asset branch:
    - Vesperhold 13: bells, spire wind, gates, chains, ravens, torches, crypt drips, rain, choir drone, stone door, gargoyle crack.
    - Bellwood basin 8: gong, ribbons, lake, waterfall, tunnel rain, birds, boat, chimes.
    - Regions 5: Frostmere ×2, Amberfall, Saltreach, Ashen Stair.
  - `SFX_LEDGER.json` and `WIRING_PLAN.md` sit beside them. Nobody has listened to them yet.
  - Nothing in `src` reads `OVERWORLD_AUDIO_UPLOADED.json`, so ids must go into `PresentationAssets.Audio`.
  - ffmpeg isn't installed on the Mac.
- **Open models:** `assets/OPEN_MODEL_CANDIDATES.json` holds licence-vetted candidates per Sunken Temple and Vesperhold prop (Haiku scout). There are no good CC0 options for a rowboat, a stone lantern or a maple.

## 4. Ordered next steps
1. **Restore and verify.**
   - Restore the gitignored raw sources from branch `landmark-assets-2026-11-21` (handoff §3.2). That includes `assets/source/landmarks/bellwood_gate/` and `assets/source/audio/`.
   - Run `ASURA_BUILD_OUTPUT=work/verify.rbxlx bash tools/verify_all.sh` and confirm `SUCCESS`.
2. **Upload the gate towers** (handoff §5 upload pipeline):
   1. Run `vesp_embed.embed` with `VESP_EMBED=jpeg`.
   2. Run `glb_split.py`; each part must be ≤ 20 MB.
   3. Open the cloud window: `RobloxStudio -task EditPlace -placeId 118614906972571 -universeId 10777041159`.
   4. Run `upload_batch.py`: the pilot first, then the rest.
   5. Merge into ledger `outputs/claude-open-world-2026-11-14/workers/mac-90-landmark-ledger.json`.
   6. Run `registry_readback.py landmark … --cache`.
   7. Add `"bellwood_gate"` to `KITS["landmark"]` in `tools/assets/kit_registry.py`, and add its manifest to the `tools/test_kit_registry.py` fixture.
   8. Run `kit_registry.py landmark`.
3. **Play-verify the gate** in a disposable build.
   - Check the stair is walkable, the landing meets the ground and nothing floats.
   - Take captures from the tunnel exit and close up at noon (`AsuraWorldEpoch = GetServerTimeNow() - 1650`) and measure fps.
   - Then Save to Roblox, never Publish.
4. **Audio** (26 ElevenLabs MP3s in `assets/source/audio/`, listed in `SFX_LEDGER.json`, with `WIRING_PLAN.md`):
   1. Listen to each sound, or at least check its waveform, for clicks at the loop seam. Re-generate only the bad ones; each generation costs about 17 credits.
   2. Optionally install ffmpeg to loudness-normalise them. Roblox accepts MP3.
   3. Upload them through the same cloud-window audio pipeline that produced `assets/OVERWORLD_AUDIO_UPLOADED.json`, and write a registry from the readback. Moderation starts as "Reviewing"; re-check it before relying on a sound.
   4. Put the ids into `src/shared/PresentationAssets.luau` (`Audio`), tests first.
   5. Wire them per `WIRING_PLAN.md`, using the existing `Audio.play`/`Audio.at` pattern in `SoundscapeController`: region ambiences plus 3D one-shots.
   6. Then add more SFX for the remaining regions and landmarks.
5. **Finish the Sunken Temple**, per concept `bellwood_3`:
   - a crimson maple tree growing out of the hall's roof ridge, with falling-leaf particles;
   - banners with our own gold wheel sigil (our design, not borrowed);
   - the gong and vines;
   - a toppled colonnade;
   - a headless lion on a plinth;
   - a boat wreck, lily pads and lotus;
   - basin-only water colour, mist and SunRays, protecting the lobby lighting.
   Candidates already vetted are in `assets/OPEN_MODEL_CANDIDATES.json`. Several Sketchfab entries rest on search snippets, so re-check each licence on its own page. There's no acceptable CC0 rowboat, stone lantern or maple, so build those procedurally in Blender like `tools/blender/landmarks/bellwood_*.py`.
6. **Fix the handoff §7 defects:** rim strata that read as black stripes, the dark streak on the left cliff, the hall width (90 against a spec of ~120), and the landmark appearing about 5.5 min into Play because of collision cooking.
7. **Then the other landmarks in spec order:** Amberfall, Saltreach, Frostmere, Ashen Stair, the Vesperhold extension and the lore glue. Put region lighting, ground and grading passes between heavy jobs.

## 5. Work rules
- **Tests first.** Run them with `python3 tools/lune_compat.py tools/<test>.luau`. Move any stray `tools/_lune_*.generated N.luau` files out of the repo.
- **One heavy Blender job machine-wide**, under `work/vesperhold-claude/heavy.lock`. Write the lock, run, then delete it. On the 8 GB Mac, close Studio first.
- **Verify every change** in a disposable build (`work/*.rbxlx`) with Play captures and an fps reading. A local test pass is not engine evidence.
- **Commit and push.**
  - Stage explicit paths. Never `git add -A`.
  - Add a ≤ 60-word line at the top of `PROJECT_STATE.md`, tagged `(Sol)`.
  - Push, then confirm `git status` is clean except for the untracked files you were told to preserve.
- **Raw assets** go to branch `landmark-assets-2026-11-21` through a temporary `GIT_INDEX_FILE` (handoff §5). Never merge that branch into the working branch.
- **Stop and report only if:** a step fails twice, publishing or payment would be needed, a licence is unclear, or every landmark is built with no visible defect.

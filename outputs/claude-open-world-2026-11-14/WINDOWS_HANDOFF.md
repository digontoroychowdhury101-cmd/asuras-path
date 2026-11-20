# Windows handoff — Mac run 3b, 19 November 2026 (castle model rebuild, stopped mid-pass)

Replaces the earlier 19 Nov handoff at d1e92fa (in git history). Branch `ux/onboarding-overhaul`; use the remote HEAD
that contains this file. Resume prompt: [handoff/WINDOWS_RESUME_PROMPT.md](handoff/WINDOWS_RESUME_PROMPT.md).
Interruption record from the earlier 429 outage, written by Codex:
[handoff/CLAUDE_RECOVERY_2026-11-19.md](handoff/CLAUDE_RECOVERY_2026-11-19.md).
The shared cloud place has NOT changed: it is still **M1, version 9** (277 / 3173417 / 786797912). No uploads were made
this run, there are no operation IDs, and `assets/VESPERHOLD_KIT_UPLOADED.json` does not exist (the registry is
generated empty).

## 0. Why it stopped
The creator said to stop everything and hand off to Windows (7% weekly usage left). The lead (Opus) and lanes
mac-51/52/53 were stopped mid-pass at about 19:28 Sydney time. Their last script edits are committed (07ede5f) and they
compile, but they were **not re-run** after those edits. No Blender batch job is left running, and the heavy-job lock
was removed.

## 1. Getting the exact Mac state on Windows
1. `git fetch origin` and fast-forward `ux/onboarding-overhaul`. Do not reset or clean.
2. **Gitignored source assets** are pushed to branch `codex/vesperhold-assets-2026-11-19` (tip `c369f3b`, batch commits on
   top of 07ede5f; all 617 files confirmed on the remote with counts matching the Mac). To restore them into the working tree without switching branches:
   `git fetch origin codex/vesperhold-assets-2026-11-19` then
   `git checkout origin/codex/vesperhold-assets-2026-11-19 -- assets/source/vesperhold work/mac-resume-2026-11-18/retone2`
   then `git reset -q -- assets/source/vesperhold work/mac-resume-2026-11-18/retone2`, so the files stay on disk but out
   of the index (the paths are gitignored).
   Contents (617 files, about 1.5 GB, none over 90 MB):
   - `assets/source/vesperhold/candidate-2026-11-19/` — Codex's recovery rebuild and the **newest set**. kit: 31 GLBs
     plus maps, renders and manifest. props: Hooded_Statue_A/B and Pedestal_Statue_Staff (baked, every sub under 16k),
     with sheet `props/renders/F1_statues_v2_baked.jpg`.
   - `assets/source/vesperhold/{kit,props,trees}/` — the first Mac kit (the creator rejected its statues).
   - `assets/source/vesperhold/polyhaven/` — 8 CC0 2K texture sets and 4 scans (provenance in
     `outputs/vesperhold/THIRD_PARTY.md`).
   - `work/mac-resume-2026-11-18/retone2/` — the 101 metal-fixed forest GLBs that need re-uploading.
   - **Not pushed:** `assets/source/vesperhold/upload/` (3.1 GB of old >50 MB packs). Regenerate with
     `tools/blender/overworld/make_upload_pack.py` using `VESP_NORMAL=jpeg` so every GLB is under 50 MB.
3. **Checkpoint place (identical to the Mac):** `places/checkpoints/AsurasPath_Vesperhold_MacHandoff_2026-11-19.rbxlx`,
   SHA-256 `a806d824eac09c0e46edc7cdca83fe500e32eefd6503cb25801948f36cbbb04a` (in the `.sha256` next to it). It was built
   from source 07ede5f with `tools/build.py --output`. It has 313 mapped sources and 1844 asset IDs. It contains the new
   loader and atmosphere code, but **no kit meshes yet** (empty registry → stand-ins). Check the hash on Windows. The
   in-Studio SourceDigest was NOT recorded on the Mac: run `tools/qa/SourceDigest.luau` in the opened copy
   (persistedToCloud=false) and record it here. Do not open it as the cloud place or save it into the cloud.
   **Windows, 2026-11-19 22:20 Sydney (Opus 5.5 lead):** SHA-256 matches. Copy `work/windows-resume-2026-11-19/VespHandoffCopy.rbxlx`
   opened in Studio Edit, persistedToCloud=false; SourceDigest = `scripts 286 bytes 3351900 digest 1396434633 | AsuraAssets
   children 24`, identical to `tools/studio_mcp.py --digest` on the same file. Closed unsaved.
   `bash tools/verify_all.sh` (build to `work/windows-resume-2026-11-19/`): **exit 1**, single failure = the
   outside-terrain checksum in `test_vesperhold_massing.luau` (Windows sum 176934331.6347 vs Mac constant 176934331.5874,
   libm drift over 112,666 samples). Tolerance made relative (1e-8) in 20672bb; massing then 14769/0. Full re-run pending.
   **Windows, 20 November (Codex):** full verifier exit 0, all 14 stages. The layout-size check required syncing the
   existing Hooded_Statue_A stand-in dimensions with the restored baseline manifest. The temporary verification build
   `work/windows-resume-2026-11-19/CodexVesperholdVerify.rbxlx` has 313 mapped sources and 1844 distinct asset IDs.
   Vesperhold massing 14769/0, loader 42/0, and atmosphere 26/0. The original checkpoint digest above is for the earlier
   Studio session.
4. Tools: Blender 5.2.2 was used on the Mac. blender-skills (kevinbadi, pinned `b2f0f816d320b56ae86d52597a35284e0e6cc929`,
   **no licence → never commit its files**) was installed into `~/.claude/skills` from a clone in
   `work/third_party/blender-skills`. On Windows, clone it at that commit if a Claude agent wants it. Codex agents only
   need the committed `tools/blender/vesperhold/*.py` (PolyHaven fetching is in `vesp_polyhaven.py`). Meshy and other
   paid generation is **off** (creator: "No Meshy, free parts only").

## 2. Verified at stop (Mac)
- Commits this run: fe603e1 (statues v2, PolyHaven, embed fix), 62954f2 (mixed checkpoint after the outage, including
  Codex's recovery), 67e35d9 and 0d9013a (mac-54 loader, atmosphere, tests), 07ede5f (stopped lanes' script edits).
- mac-54 suites at 0d9013a: massing 14769/0, slice 1356/0, weather 258/0, loader 42/0, atmosphere 26/0, biome 18928/0,
  kit_registry 15, layout_sizes 2, and all `src/` compiles. `py_compile` of `tools/blender/vesperhold/*.py` passes at
  07ede5f.
- **Not run:** full `bash tools/verify_all.sh` at 07ede5f, any Studio or Play check of the new loader and atmosphere, and
  any Blender run of the 07ede5f script edits.
- Models used: oversight Opus 5.5. Lead `adc6b08` Opus. mac-51/52/53 Opus. mac-54 Sonnet (self-reported
  claude-sonnet-5-5). Codex did the outage recovery in between (its own record).

## 3. Lane state at stop (notes in `workers/`, each has its own detail)
| Lane | Owner files | Done | Left |
|---|---|---|---|
| mac-50 rules | `mac-50-vesp-rebuild-rules.md` | Binding high-poly rules, heavy-job lock (guarded `mkdir "$LOCK" && {…; rm -rf "$LOCK"; }` only) | — |
| mac-51 statues | `vesperhold_figures.py`, `vesp_bake.py` | v2 sculpts and Codex re-bake (A, B, Pedestal). Pass-2 edits applied for the oversight fixes (below) | Re-run the bake, then the fourth veiled statue (`Statue_Veiled_Scan` slot exists, no mesh). Scale A/B to about 22–23 studs total |
| mac-52 gargoyles and trees | `vesperhold_gargoyles.py` (new), `vesperhold_trees.py` | New gargoyle generator. Tree edits | Finish the gargoyle bake and tree runs, then render them. A/B must differ clearly |
| mac-53 architecture | `vesperhold_kit.py`, `vesp_common.py`, `vesperhold_props.py` | Density edits (crockets, wimpergs, viaduct orders kept inside the 15-stud half-width, stained-glass rework) | Re-run the kit, then merge manifests and render spire stack, west front and viaduct |
| mac-54 Luau | `src/server/Services/VesperholdKit.luau`, `VesperholdAtmosphere.luau`, `GothicCitadel/March`, `VesperholdLayout`, `EnvironmentProfiles`, `kit_registry.py`, tests | Loader, collision by sub role, Neon glass/flames, swap-in at stand-in CFrames, atmosphere (storm, eclipse, fog, lightning via the owned `VesperholdFlash` ColorCorrection, crows, candles, mist, 0.17-stud snow), red trail-stake dropped on the ridge, plinth dedupe | Studio/Play check. After statues regenerate, run `vesperhold_layout_sizes.py --write` and then the massing and layout-size tests |

**Oversight fixes still open for the statues** (from my review of `F1_statues_v2_baked.jpg` against `ref_01`):
- A's sleeves are stiff tubes. Make them droop and taper, with folds.
- C/Pedestal has a blank oval chest. Add drapery, a cloak opening and a tabard or mail edge, plus elbow folds.
- Every hood has a visible seam at the crown. Hide it or make it a fold.
- They look like clean clay. Add soot streaks, frost on shoulders and ledges, chipped plinths, a matte finish, and
  albedo of about 0.08–0.2.
- Silhouettes must read slender at 20+ studs on the balustrade.

Keep the deep hood, the capelet, the rope belt, the staff crescent and the quatrefoil pedestal.

## 4. TODO on Windows, in order
1. Restore the assets (§1.2) and check the checkpoint SHA (§1.3). Run `bash tools/verify_all.sh` and record the result.
2. **Finish the art lanes (one Blender job at a time):** re-run the figures bake, the gargoyles, the trees and the kit
   from the 07ede5f scripts. Output goes to `assets/source/vesperhold/candidate-2026-11-19/` (or a new dated candidate
   folder).
3. **Gate (a) contact sheet:** `tools/blender/vesperhold/vesp_contact_sheet.py` covering statues, gargoyles, trees,
   spire stack and west front. Show triangle counts per sub (each under 18–20k, **never decimate**), map resolution
   (2048+) and a no-decimation statement. Judge it against `outputs/vesperhold/reference/ref_01..05.webp` and
   `workers/mac-40-vesperhold-verdict.md`. The creator must see it: their bar is "look really good and match the
   inspiration images … colossal in size and haunting".
4. Upload packs (`make_upload_pack.py`, `VESP_NORMAL=jpeg`, each under 50 MB). Then **one cloud-window upload session**:
   uploads only work from the cloud place window, and its DataModel must never be edited or saved. Upload a pilot piece
   first, then the castle kit, props and trees plus the 101 retone2 forest GLBs. Record every operation ID, read each
   back, write `assets/VESPERHOLD_KIT_UPLOADED.json`, and run `python3 tools/assets/kit_registry.py vesperhold`.
5. Play captures of the 7 views in mac-40 (01 Snow Refuge, 02 pilgrim road, 03 viaduct looking up, 04 gate looking up,
   05 gorge flank, 06 inside the close, 07 silhouette from ≥1500 studs). Also record frame time ×3, MeshParts and tris,
   and console failures. Check the pivot and cladding depth, the flyer yaw sign, Neon glass against SurfaceAppearance,
   and that the red post is gone in view 01. Then the creator reviews.
6. Rebuild the checkpoint with meshes, update §1.3, and commit.
7. Then the forest re-capture (mac-20 gate, Terrain.Decoration grass decision), M2 guarded cloud integration, the
   multiplayer reruns and the rest of the acceptance list in `MAC_HANDOFF.md`.

## 5. Working with T3 (Claude and Codex agents together)
- Use one overall lead for oversight and acceptance (Claude Opus 5.5, high effort; no ultracode). It assigns lanes.
  Claude or Codex agents can implement, and each lane owns disjoint files (§3 table). Two agents never edit the same
  file. Before editing, re-check mtimes and `git status`. If a file changed under you, stop and report.
- There is ONE heavy job machine-wide (Blender batch, Studio, full verify, upload window). Use the guarded lock
  `work/vesperhold-claude/heavy.lock` per mac-50.
- Every lane writes a note in `workers/` (state, files, tests run, model used). Commit explicit paths after each
  verified step and push. Never `git add -A`.
- Record the requested model and the observed model for every agent in `DELEGATION_STATUS.md`.

## 6. Rules that still apply
- Open-source: CC0 (Poly Haven, ambientCG) and GPL/MIT generator tools are OK. Pin and record them in `THIRD_PARTY.md`.
  No NC/ND licences, ripped assets or Creator Store free models. No paid generation.
- The banner sigil must be our own design (the references show a franchise-like tree; do not copy it).
- Never modify `places/AsurasPath.rbxlx` or `outputs/AsurasPath.rbxlx`. Build only with `--output`. Never restore old
  baselines into the cloud.
- Preserve the lobby, lobby lighting, combat, progression, persistent IDs and the single Shen barrier.
- No publishing, settings, permission or account changes, and no purchases.
- Leave untracked creator/Codex files alone: `outputs/vesperhold/AsurasPath-Vesperhold.rbxlx`, `walkthrough.mp4`.
- Multi-client tests run on Windows only.

## 7. Windows run 4 upload record (lead, Opus 5.5, 2026-11-20)
- Route: Studio MCP `open_cloud_invoke` from the cloud place window (place 118614906972571, never edited or saved, closed
  unsaved afterwards). Ledgers with every operation ID, asset ID, sha256 and moderation state:
  `uploads/vesperhold_upload_ledger.json`, `uploads/forest_retone2_upload_ledger.json` (`tools/assets/upload_batch.py`).
- Vesperhold approved set (win-65 verdict): 38 pieces, 67 Model assets, all Approved. 29 pieces exceed the 20,000,000-byte
  Open Cloud file limit, so `tools/assets/glb_split.py` split each into two parts (whole sub-meshes, images copied byte for
  byte, no re-encode); the loader rebuilds them from per-sub `Asset` + `center`. Pilots: Gargoyle_A (94687077564229) and
  Spire_Needle_Tip__p2 (98339191104108), both read back with 2048 maps, black Metal on stone and the expected positions.
- Forest retone2: 101/101 Approved; the SLICE / HERO / BELLWOOD / BELLWOOD_FAR registries now point at them (old IDs kept
  as `replaces`). Far atlases now carry Normal + MR maps by design (mac-26/mac-30), so `kit_registry` accepts them.
- Registries written from a read-only LoadAsset readback (`tools/assets/registry_readback.py`). Vesperhold validates
  with `--vesp-manifests assets/source/vesperhold/candidate-win-2026-11-19` and the 31 held pieces as `--allow-missing`.
- Not uploaded (held): all statues, Dead_Pine_Snapped_A/B, Dead_Stump_A/B, Viaduct_Bay, Viaduct_Balustrade_30,
  Waterfall_Sheet_A/B. Next: §4 step 5 (seven Play views on a local copy), then the checkpoint rebuild with meshes.

## 8. Windows continuation after the quota stop (Codex, 2026-11-20)

- Held pass 4 (`74d9c6e`) is ready for creator review. The 13 pieces are packaged in 19 verified local parts under
  `work/vesperhold-claude/win68/split`. All 86 submeshes are below 18,000 triangles, with 2K maps. See the
  [statue sheet](../vesperhold/kit-renders-win/F1_statues_v4_win.jpg) and
  [held assembly sheet](../vesperhold/kit-renders-win/gate_a_held_pass4.jpg).
- Step 5 is recorded in the [recovery note](workers/win-68-vesperhold-recovery.md). Runtime fixes at `e11d405`
  address the protected collision write, the missing atmosphere mapping, crimson glass and two nonpositive belfry
  slots. The full verifier passed. The [seven views](../vesperhold/kit-renders-win/gate_b_studio_approved_set.jpg)
  and [measurements](../vesperhold/kit-renders-win/gate_b_studio_metrics.json) are from a disposable Studio copy.
- Source build available at `work/vesperhold-claude/win68/AsurasPath_Vesperhold_Approved_Final.rbxlx`,
  digest **287 / 3437403 / 2079555092**, SHA-256
  `fbb1988bca3cf401ac706ff212181c358437aba3382adc9cb28d4ac4099a3031`.
  The creator review precedes the held upload and §4 step 6 checkpoint promotion. The master places and the
  checkpoint in §1.3 retain their original hashes. The last verified cloud checkpoint remains M1 v9.

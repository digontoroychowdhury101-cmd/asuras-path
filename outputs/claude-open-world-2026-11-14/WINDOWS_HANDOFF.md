# Windows handoff — Mac run 3, 19 November 2026

Replaces the 16 Nov Windows handoff (still in git history). Branch `ux/onboarding-overhaul`; use the remote HEAD that
contains this file. Resume prompt: [handoff/WINDOWS_RESUME_PROMPT.md](handoff/WINDOWS_RESUME_PROMPT.md).
Nothing in the shared cloud place changed on the Mac: it is still **M1, version 9** (277 / 3173417 / 786797912).

## 1. Verified at handoff (Mac, 2026-11-19)
- `bash tools/verify_all.sh` **exit 0** (log `work/mac-handoff-2026-11-19/verify_all.log`, Mac only; built to a temp path,
  canonical places untouched). Vesperhold massing suite 14967/0 (lead), slice suite 1356/0, retone `--selfcheck` pass.
- No Studio, no Blender running. No uploads this run, no operation IDs. `assets/VESPERHOLD_KIT_UPLOADED.json` does not exist.
- Models: oversight Opus 5.5 (creator switched from Fable); engineering lead Opus 5.5; 15 Sonnet + 3 Haiku workers, every
  observed model matched its request (DELEGATION_STATUS.md). Creator later allowed up to five workers and Opus workers.

## 2. What exists now
### Vesperhold citadel (Snowfields; creator's top priority)
- Brief/verdict + references: `workers/mac-40-vesperhold-verdict.md`, images `outputs/vesperhold/reference/ref_02..05.webp`
  (ref_01 was chat-only; described in the brief). Target: black gothic cathedral-fortress climbing cliffs in tiers, 30+
  spires, glowing rose window, statue-lined viaducts, grand stair, waterfalls, red eclipse storm sky, fog, withered trees.
  Banner sigil must be OUR OWN (references show a franchise-like white tree; do not copy).
- Plan: `workers/mac-41-vesperhold-plan.md` (tiers T0–T3 + crown, kit groups A–G, what stays Part massing vs mesh).
- Source (committed, NOT yet run in Studio): `src/shared/VesperholdLayout.luau` (tiers, route, kit slots),
  `GothicCitadel.luau`, `GothicMarch.luau`, test `tools/test_vesperhold_massing.luau`. Pass 2 (mac-48): pinnacles P2/P3,
  viaducts V1 ~-9 / V2 +150 / V3 +280, 3 outposts, 71 spires, 61-step grand stair, 4 waterfalls, 2 ruined arches,
  31 dead trees, graveyard. Codex's original pass is e8be23c.
- Blender kit (scripts committed in `tools/blender/vesperhold/`; outputs in gitignored `assets/source/vesperhold/`, Mac only —
  **regenerate on Windows**, ~30 s per group): kit A–E 31 pieces, props F 26 pieces, trees G 10 pieces; every sub-mesh
  <18k tris; Metal map always linked. Preview renders + manifests tracked in `outputs/vesperhold/kit-renders/`.

### Forest slice (Bellwood)
- Not accepted (`workers/mac-20-slice-verdict.md`). Root cause of black trunks/timber and hard leaf shine found: uploaded
  MetalnessMaps are solid 255 (importer ignored metallicFactor 0). Fix tool `tools/assets/retone_glb.py` v2 (non-metal
  MR B=0, lifts) — 101 GLBs need regenerating (`--all`) and RE-UPLOADING. Generator fixed (`slice_kit.py`,
  `hero_silhouettes.py` link a black Metal map) but not yet run in Blender.
- Canopy pass 2 (mac-31 Mac Play): canopy 20.0 / 54.6 / 23.8 / 31.2 / 23.3 / 15.4 / 20.0 %, frame 16.6 ms, captures
  `captures/mac/slice_canopy31_*`. The giant yellow foreground blades in 01/07 are **Terrain.Decoration grass**, not cards.
- Windows' "24 failing far-tree IDs" claim was wrong: far textures are 2 valid Image IDs that load on Mac.

## 3. TODO on Windows, in order (nothing below is done)
1. **Local Studio check of castle massing pass 2.** `python3 tools/build.py --output work/<dir>/x.rbxlx`; open copy,
   persistedToCloud=false, digest check. Walk gate, grand stair, V2, V3 with a real character; record parts, frame time,
   7 early views. Fix any blocked path, fall-through or floating piece.
2. **Kit quality fixes, then regenerate** (oversight review of renders):
   - Stained glass reads as candy confetti: darker crimson/amber panes with visible lead lines, less noise.
   - Hooded statues are blobby (ghost-mask hood, lump hands): slender figure, deep shadowed hood, drapery folds, staff.
     A CC0 scanned statue is allowed if better (record licence).
   - Spire stack too plain/slender: more crockets, pinnacle clusters, lucarnes.
   - Gargoyle A/B near-identical; ruined arch pier plain; waterfall banding at row seams.
   - Reconcile `VesperholdLayout.Piece` sizes with `assets/source/vesperhold/*/manifest.json`.
   - Rebuild with `VESP_NORMAL=jpeg` (or shared atlas) so every GLB < 50 MB (currently kit 1613 MB, 22 over; props 990 MB).
3. **Kit loader:** add vesperhold kits to `tools/assets/kit_registry.py`, generate `VesperholdKitRegistry`, add to
   `SliceDressing.RegistryModules` and `default.project.json`; clone helper replacing VespKitSlot stand-ins (reuse the
   SliceDressingService LoadAsset-once/clone pattern; no runtime SurfaceAppearance map writes); glass/flames → Neon + light;
   tests with LoadModel fakes.
4. **Atmosphere, local to `Overworld.vesperholdWeight` only:** red eclipse, storm cloud, fog banks between tiers and in
   gorge, cold grade, lightning lighting the silhouette, crows, candle glow, small snow (fix huge snow blobs), waterfall
   mist. Remove the stray red post in view 01. Lobby lighting untouchable.
5. **One cloud-window upload session** (uploads only work from the cloud place window; never edit/save its DataModel):
   pilot one piece first, then castle kit/props/trees + 101 retone2 forest GLBs. Record every operation ID, read back,
   register only returned IDs via `kit_registry.py`.
6. **Play captures** of the 7 Vesperhold views (gate in mac-40) + frame time ×3, MeshParts/tris, console failures →
   creator/oversight review.
7. **Forest:** rebuild with re-uploaded maps, re-capture the 7 slice views (mac-20 gate), decide Terrain.Decoration grass
   (off near road/arrivals or shorter + recoloured), report canopy 04–06 < 25% trade-off.
8. Wire `test_vesperhold_massing` into `verify_all.sh`; one Blender run to prove the generator metal fix.
9. Then M2 guarded cloud integration (exact previous-source guards, fingerprints, save, cold reopen, record version),
   multiplayer reruns (Shen simultaneous entry, terrain priority), landmarks at low quality, stair walk, weather comfort,
   audio audition/wiring (5 IDs Reviewing), device profiling, remaining biomes and acceptance list in MAC_HANDOFF.md.

## 4. Rules that still apply
Open-source: creator approved ("if there open-source repos that help make it a lot better please feel free to use those
as well") — CC0 (Poly Haven, ambientCG) and GPL/MIT generator tools OK; pin versions, list in
`outputs/vesperhold/THIRD_PARTY.md`; no NC/ND, ripped assets or Creator Store free models. Never modify `places/` or
`outputs/AsurasPath.rbxlx`; build only with `--output`; never restore old baselines into the cloud; preserve lobby,
combat, progression, IDs, single Shen barrier; explicit `git add` paths only; no publish or settings changes.
Untracked creator/Codex files left alone: `outputs/vesperhold/AsurasPath-Vesperhold.rbxlx` (56 MB), `walkthrough.mp4`.

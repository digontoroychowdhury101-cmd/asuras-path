# Handoff 2026-11-13: Grandmaster Shen, seven seam clips done, all 64 clips published

What is final: the source on `ux/onboarding-overhaul`, the 64 exported clips and their new published ids, and
`places/AsurasPath.rbxlx` built from that source (byte-identical to the place tested in Studio). Details: `REPORT.md` section 16,
`results/studio_published_1113.txt`.

## Which commit

- Branch `ux/onboarding-overhaul` on `origin`. The commit is the one that adds this file:
  `git log -1 --format=%H -- outputs/grandmaster-shen-2026-11-05/repair/windows-pass-2026-11-09/HANDOFF_1113.md`.
  The branch tip is that commit unless something was pushed later; `git log --oneline -3` shows it.

## On the other computer (the Mac, or any other)

1. Look before pulling: `git status`. If `places/AsurasPath.rbxlx` (or any other file) shows local changes, copy it somewhere outside
   the repo first; the pull replaces it. Nothing else of this task needs local files.
2. `git pull --rebase origin ux/onboarding-overhaul`, then `git log -1 --format=%H` and compare with the commit above.
3. Open the validated place: `places/AsurasPath.rbxlx` (Studio: File > Open from File; on a Mac
   `/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio -task EditFile -localPlaceFile "$PWD/places/AsurasPath.rbxlx"`).
   Do not use an older copy and do not open `outputs/AsurasPath.rbxlx` instead (it is the same build, but `places/` is the one to keep).
4. Prove it is this build: in the open place run `tools/qa/SourceDigest.luau` in the Command Bar. It must print
   `scripts 286 bytes 2859366 digest 462022588`. (`python3 tools/studio_mcp.py --digest places/AsurasPath.rbxlx` prints the same from
   the file.) A different number means a different build: rebuild with step 5 and compare again.
5. Optional rebuild from source (same result): `python3 tools/build.py` (Rojo 7.7.1, `tools/toolchain.env`). It rewrites
   `outputs/AsurasPath.rbxlx`, `places/AsurasPath.rbxlx` and `places/AsurasPath.rbxl`; `git status` should then show no change.
6. Smoke check in Studio: Play; Grandmaster Shen's fight (Ash Colosseum) should play his clips with no animation errors in Output. The
   only expected Output warning is `rbxassetid://203785492 ... Asset type does not match` (the Rojo plugin's own sound; editor-only).

### Local checks (no Studio)

- `bash tools/verify_all.sh` (Luau 0.742 at `work/bin/luau/luau` or on PATH; Rojo 7.7.1). On a fresh clone it first needs the generated
  Shen audio manifest, which Git does not carry: `python3 tools/assets/build_shen_audio.py` (writes `assets/build/shen_audio/`).
  Expect "SUCCESS: All local checks passed" and 14 stages.
- The bake tools need numpy and SciPy (`handoff-2026-11-09/ENVIRONMENT.txt`) and the restored `work/shen_import` data
  (`handoff-2026-11-09/ARCHIVE.md`, branch `shen-assets-2026-11-09`). This commit adds three new files there (`xray_p2.npz`,
  `xray2_p2.npz`, `review_idle_p2.npz`); they come with the pull.
- Reproduce a seam clip's bake: `python3 outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/scripts/repro_check.py
  P2_Guandao_L2 outputs/grandmaster-shen-2026-11-05/repair/windows-pass-2026-11-09/bakes/final7/P2_Guandao_L2.pkl` (about 11 minutes
  single-threaded on the Windows PC). `bakes/final7/` holds all seven seam clips' final bakes.
- The five-decimal x-ray without Blender: `scripts/xray_exact.py` on review shot JSON (`shots_fade.py` writes it).

## Studio settings and plugins

- Rojo plugin only if live-syncing (`bash tools/start_sync.sh`); not needed to open the built place.
- Game Settings > Security > Allow HTTP Requests stays off. Nothing here needs it.
- Studio MCP (Assistant > MCP) only for the automated checks; not needed to play.

## Asset permissions

- The 64 Shen animation ids were uploaded by Roblox user 3148600636, the same account as every earlier Shen id. They play in any place
  that account (or its group, if the experience is moved to a group) owns. If the experience is published under a group, the clips
  must be re-published to that group (`tools/animation/opening_cast/publish.py`) and re-registered (`register_shen.py`).
- No other asset was uploaded or changed.

## Not verified, or not carried by Git

- Two clients, phones or other devices, and a live published server: not run (REPORT section 7).
- That the other computer's own bake of a seam clip equals `bakes/final7` (the solver's iterations may round differently on another
  CPU or numpy build): not run there yet. The shipped clips do not depend on it: the exports, ids and place are committed.
- `assets/build/shen_audio/` (generated, see above), `work/bin/luau` (download Luau 0.742), the asset archive branch (restore as
  ARCHIVE.md says) and the Studio content folder are outside the code branch.
- The Windows computer's uncommitted Studio edits of the old place are kept only in a backup on that computer, outside the repo.
- Do not call the computers identical until step 4 prints the digest above on the other one and its smoke check passes.

# Handoff validation — 16 November 2026, Windows

This records a development checkpoint. It does not sign off the open world.

## Source and local regression

- Prior source commit: `b658140cd2068cf62beaedfecdf0109d4d3158a5`, already on origin.
- Late change preserved: `src/shared/Overworld.luau`, 49 insertions / 14 deletions
  from T4's interrupted optimisation. Native annotations, cached region boxes,
  reused region-weight tables and optional pre-culled pads are present. This is
  partial work; no new terrain performance result is claimed.
- `bash tools/verify_all.sh`: exit **0**, all **14 stages** passed, including
  **39 Lune-shim suites**, syntax compilation and a temporary place build.
  Output: [VERIFY_ALL.log](VERIFY_ALL.log).
- Temp place: **275 scripts, 3149701 source bytes, digest 1516687798**. This is the
  current source build, distinct from the intentionally preserved saved baseline.
- Additional terrain test: `work/bin/luau/luau.exe tools/test_overworld_terrain.luau`
  **100 passed / 0 failed**. The order suite uses the Lune shim (472/0 in the full
  verifier); invoking it directly with Luau errors on `@lune/fs`, an unsupported
  runner choice, not a gameplay failure.
- No saved place was rebuilt or changed during this handoff.

## Asset transfer

- Sources: `assets/source/overworld/` and `assets/source/audio/overworld/`.
- Snapshot: **1277 files**, **2216435383 bytes** restored, **609 unique contents**.
  Current `.blend` files, GLBs, maps, upload packs, vignettes and audio are included.
  Twenty `.blend1` automatic backups are omitted and listed in the manifest.
- Joined archive: **1231545662 bytes**, fifteen parts of at most 80 MiB.
- Archive SHA-256:
  `4b475b05a63f8b24720885040cd0a0c3d2e53cc5462b2e63faec4cb475e9fbb8`.
- `tools/assets/overworld_handoff.py restore --archive ... --root ... --apply`:
  restored **1277 missing files** into a fresh isolated directory, with no existing
  files overwritten. Every ZIP object was SHA-256 checked before writing.
- A second hash pass confirmed all **1277 original files** still match the pinned
  snapshot. No source changed while packaging.
- The Git-parts restore path also passed: joined all fifteen blobs, verified their
  hashes and the pinned descriptor, then reported **1277 same / 0 different**.
- Asset commit **1412139fbb6c9adc519031a5d02063c7a952732c** was pushed on
  `codex/overworld-assets-2026-11-16`; `git ls-remote` confirmed the same remote hash.
  It has no shared history with the game branch and is not to be merged.
- `python tools/test_overworld_handoff.py`: **3 passed, 1 skipped**. Tests cover
  corruption before writes, dry run, round trip, preserving differing local work,
  traversal and case-collision rejection. Symlink creation was unavailable on
  Windows without privileges, so that test is explicitly skipped here.
- `.gitattributes` preserves LF for the hashed JSON descriptors across machines.
- Selected handoff text was checked for common embedded credential patterns; none
  were found. Only the two specified source roots are packaged, with no account
  configuration or credentials. The repository and data branch are public.

## Runtime and external services

- **Static review / local tests:** evidence above only; engine behavior is not
  established by the local runners.
- **Studio integration:** no new Play run or temporary sync in this handoff.
  Earlier captures and measurements remain in worker notes. Current script
  baseline checks from the prior Codex turn were read-only.
- **Uploads:** folder approval passed; the lantern request was accepted but its
  processing operation failed with Unknown Error, without an asset ID. No
  successful registry or batch upload is claimed.
- **Multiplayer, device profiling and human art acceptance:** not performed.
- **Mac/computers A and C:** setup instructions and pins supplied; no remote
  installation, pull, authentication or Studio execution performed here.

The pre-existing `outputs/mugen-combat-review-2026-11-09/` is a separate task and
was not staged. The Hero of The Grand Soul reference folder belongs to this
open-world brief and is included so its documented links work on a fresh clone.

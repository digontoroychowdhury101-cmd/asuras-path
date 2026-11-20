# Matching Studio checkpoints on Windows and Mac

## Current — Vesperhold with meshes, 21 November 2026

Use **AsurasPath_Vesperhold_2026-11-21.rbxlx**, copied byte for byte from the 14/14 verification build of source
**b9ad98a**. SHA-256 **a0b75a83688aef25fcba27296ed5c24e432207ea433cbd6d410aaa1a39964bc1**, 11,019,882 bytes.
Expected scripts **287 / 3471464 bytes / digest 2088899630** (file digest and in-Studio SourceDigest agree; AsuraAssets 24).
Vesperhold registry: 51 pieces / 291 sub-meshes, all uploaded and Approved. Adjacent JSON records identity.
Open a local working copy for QA. Not integrated into cloud: the Development place is still M1 **277 / 3173417 / 786797912**
(it reports version 13 after Studio opens; scripts unchanged). Cloud integration needs its own approval.

## Earlier return to Mac — 17 November 2026

Use **AsurasPath_OpenWorld_WindowsHandoff_2026-11-17.rbxlx**, copied from the fresh 14/14 verification build of
source/evidence HEAD **2d4b1ed** (runtime source **78662d6**). SHA-256:
**5584b95dee2f49797309c22d0028e6ba603a2610822f36f7c1757d19757b295f**, 10,793,680 bytes.
Expected scripts **281 / 3254714 bytes / digest 1882323309**. Adjacent JSON records identity.
Use a local working copy for QA. This is the unfinished real-mesh M2 candidate, not an accepted world or current cloud save.

Shared Development cloud is independently **M1 / version 9 / 277 / 3173417 / 786797912**, place **118614906972571**,
universe **10777041159**. M2 was held before Fable's slice verdict; do not overwrite cloud with this candidate until its gate passes.
Read `outputs/claude-open-world-2026-11-14/MAC_HANDOFF.md` and `handoff/MAC_RESUME_PROMPT.md` for exact continuation.

## Earlier checkpoint/migration instructions (historical)

**Newest Mac-to-Windows local candidate:** `AsurasPath_OpenWorld_MacHandoff_2026-11-16.rbxlx`,
**277 scripts / 3174231 bytes / digest 1755809200**, SHA-256
`1e15bb0cb5855e5213a9855d9fb4da4a0a0b559813f64fbb9082fc637780c465`.
Open a working copy for local tests. Last verified cloud content is M1 **277 / 3173417 / 786797912**,
runtime source `3465430`, latest save recorded **v9**. New local source has not been integrated into cloud.
Read `outputs/claude-open-world-2026-11-14/WINDOWS_HANDOFF.md` and the recovery manifest under
`places/checkpoints/mac-session-2026-11-16/`. Older version-6/current-checkpoint statements below are historical.

**Current shared Save to Roblox target:** Asura's Path — Development, place
**118614906972571**, universe **10777041159**. The creator subsequently authorised
moving the dated build below into that existing private cloud place; this is now
complete, including the subsequent Mac far-tree change from `32d448e` (latest
save version 6, 275 scripts / 3151007 bytes / digest 1357214079). Open the game
through Studio's Roblox experiences on both computers and verify those IDs.
Details: `outputs/claude-open-world-2026-11-14/handoff/CLOUD_MIGRATION.md`.

The instructions below also verify the dated **local reference file**, useful for
backups and separate QA. It contains the initial migration source checkpoint,
before the one-module Mac update; do not overwrite newer cloud source with it.

Open **`places/checkpoints/AsurasPath_OpenWorld_2026-11-16.rbxlx`** on both
computers after pulling `ux/onboarding-overhaul`. This is a build of the Windows
handoff source at commit `358e24fa02865c2579e565697d62c8699d017a61`.
It contains today's unfinished open-world code. It is distinct from the older
`places/AsurasPath.rbxlx` and `outputs/AsurasPath.rbxlx`, preserved as baselines.

The dated file is committed once and downloaded through Git, so both computers
can open identical bytes instead of independently rebuilding and comparing dates.
`.gitattributes` disables line-ending conversion for `.rbxlx` files. Git does not
carry a reliable cross-machine file modification timestamp. Studio's Recent list
or a cloud experience's modified date is not proof of the local file's contents.

## Mac: from the repository root

Preserve local edits before updating. If the branch is clean:

```sh
git fetch origin
git switch ux/onboarding-overhaul
git pull --ff-only origin ux/onboarding-overhaul
shasum -a 256 -c places/checkpoints/AsurasPath_OpenWorld_2026-11-16.sha256
/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio -task EditFile -localPlaceFile "$PWD/places/checkpoints/AsurasPath_OpenWorld_2026-11-16.rbxlx"
```

The checksum command must print **OK**. If it fails, preserve the changed file and
investigate; do not replace local Studio work automatically. Opening through
Studio's **File > Open from File** and choosing this exact path also works. Use a
separate working copy for temporary tests, preserving the dated reference file.

## Windows: from the repository root

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath 'places/checkpoints/AsurasPath_OpenWorld_2026-11-16.rbxlx'
```

Expected whole-file SHA-256 on both computers:

`d9be83ac03d7c1ceb61ab99a60601271a68c222401847d478ffbcbacdc644cf6`

After opening, use `tools/qa/SourceDigest.luau` in Studio Edit mode to verify the
loaded scripts: **275 scripts, 3149701 bytes, digest 1516687798**. The source digest
checks scripts; the SHA-256 above checks the entire saved place. A digest of
462022588 identifies the preserved older baseline instead.

## What this checkpoint does and does not establish

The world terrain and dressing are generated at runtime when Play starts; the
Edit viewport alone does not show the completed runtime world. Generation timing,
real-mesh integration and visual acceptance remain unfinished. A matching file
does not mean those gates passed. Raw mesh/audio source files remain on the
separate checksummed asset branch described in
`outputs/claude-open-world-2026-11-14/MAC_HANDOFF.md`.

The dated file itself is a **local reference**. A verified copy was deliberately
saved into the existing private Team Create cloud place as documented above.
Later local edits do not automatically update that cloud place. Use deliberate,
verified milestone transfers while preserving the newest work on both computers.
For later handoffs, build a newly named checkpoint from the agreed code commit,
record its hash and script digest, commit/push it, then pull/open/verify that same
file on the other computer. Preserve each computer's uncommitted Studio work.

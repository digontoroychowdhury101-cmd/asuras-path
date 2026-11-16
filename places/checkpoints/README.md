# The same Studio checkpoint on Windows and Mac

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

This is a **local** test file, not an update to the private Team Create cloud
place. Do not save it over the cloud place as a way to make a date look current.
For later handoffs, build a newly named checkpoint from the agreed code commit,
record its hash and script digest, commit/push it, then pull/open/verify that same
file on the other computer. Preserve each computer's uncommitted Studio work.

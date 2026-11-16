# Asura's Path overworld source snapshot, 16 November 2026

Data-only branch. Do not check it out over the game, merge it, or add the zip parts
to the code branch. It contains original task meshes, materials, Blender scenes,
upload packs and audio sources; no credentials, tool installations or Claude state.

The 1,277 source files have 609 unique contents. Identical content is stored once
inside a ZIP and mapped back to every original project-relative path by
ASSET_MANIFEST.json. Twenty .blend1 automatic backups are excluded; current .blend
files are included. The 15 ZIP parts are each smaller than GitHub's 100 MB limit.

From the game checkout on ux/onboarding-overhaul:

```sh
git fetch origin codex/overworld-assets-2026-11-16:refs/remotes/origin/codex/overworld-assets-2026-11-16
python3 tools/assets/overworld_handoff.py restore
python3 tools/assets/overworld_handoff.py restore --apply
```

The code branch pins BUNDLE.json and ASSET_MANIFEST.json under
outputs/claude-open-world-2026-11-14/handoff/. The restore command checks the branch
descriptor, every part, the joined archive and every file's SHA-256 before writing.
It adds missing files, preserves any differing local file, and returns exit 2 if
such conflicts exist. Nothing is overwritten automatically. Windows can use
`python` instead of `python3`.

Read outputs/claude-open-world-2026-11-14/MAC_HANDOFF.md on the code branch for tools,
plugins, the exact checkpoint status and remaining work. These assets are not yet
accepted in Roblox: the lantern test reached Roblox but returned a terminal
Unknown Error without an asset ID. The saved game place remains the pre-overworld
baseline; build a temporary place from source to see the new world code.

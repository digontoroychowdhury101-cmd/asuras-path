# Mac / computers A and C handoff: open-world replacement (completed 2026-11-16)

Read this first, then `handoff/RESUME_PROMPT.md`, `CONTINUATION.md` and `LEDGER.md`. Claude's 13:22 checkpoint was already pushed as `b658140`. Codex finished the handoff after the usage-limit stop, preserving the late terrain edit and providing the ignored assets on a separate branch. This is an unfinished development checkpoint, not a release or visual acceptance. Assume the receiving computer has nothing installed. No installation on a remote computer is claimed.

## 1. What travels by Git and what does not

| Travels (branch `ux/onboarding-overhaul`) | Does NOT travel |
|---|---|
| All source (`src/`), tests and tools (`tools/`), `default.project.json`, registries under `assets/*.json`, `assets/models/` | The ignored mesh/audio sources travel on **`codex/overworld-assets-2026-11-16`**, restored with the checksummed command below. A normal code pull alone is insufficient |
| This folder: brief, current state, worker notes, captures and kit sheets. Also `outputs/hero-grand-soul-review-2026-11-09/`, which the brief reads | Claude transcripts and agent state. Start a fresh lead from the durable notes rather than relying on a Windows agent ID |
| Spec and tickets: `.scratch/asuras-open-world/` | `.mcp.json` (git-ignored), Studio MCP permissions (set per place, per Studio), scratchpad test copies of the place |
| `places/AsurasPath.rbxlx` exactly as on Windows: still the PRE-overworld baseline on purpose (tests restore to it; script digest 462022588, 286 scripts, 2859366 bytes). Do not rebuild it until final handoff | Roblox login, GitHub login, any keys |
| **Current shared Studio checkpoint:** `places/checkpoints/AsurasPath_OpenWorld_2026-11-16.rbxlx`, built from source commit `358e24f`, with a whole-file SHA-256 and script digest | Unsaved edits in either computer's running Studio; Git does not carry those |

## 2. Install on the Mac

1. Git and GitHub CLI: `brew install git gh`, then `gh auth login`.
2. Clone and switch (if the folder already exists, inspect its changes first; preserve local work):
   - `git clone https://github.com/digontoroychowdhury101-cmd/asuras-path.git`
   - `cd asuras-path && git switch ux/onboarding-overhaul && git pull --ff-only origin ux/onboarding-overhaul`
3. Python 3 (Windows used 3.15.0; earlier Mac work used 3.14.3): `brew install python`. Shen tooling also needs `numpy` and `scipy` in a venv; not needed for the overworld work.
4. Rojo **7.7.1** and Luau **0.742** (pinned in `tools/toolchain.env`). Download the Mac releases from [Rojo](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) and [Luau](https://github.com/luau-lang/luau/releases/tag/0.742). Put `rojo` in `work/bin/rojo/`, and `luau`, `luau-compile`, `luau-analyze` in `work/bin/luau/`; make them executable. `docs/BUILD.md` has the build contract. A separate Lune binary is unnecessary for the local shim suites.
5. Blender 5.2.2 LTS from blender.org. Check headless works: `/Applications/Blender.app/Contents/MacOS/Blender -b --python-expr "import bpy; print(bpy.app.version_string)"`.
6. Roblox Studio, signed in as the creator.
7. `uv` (for the Blender MCP server): `brew install uv`.
8. Claude Code, signed in. Install its CLI too if using the terminal plugin/MCP commands below; verify `claude --version`. Account authentication stays local to each machine.

The curated upstream libraries (`tools/vendor/effekseer`, `tools/vendor/fastnoise-lite`, `assets/github/`) are already carried in Git; their origins and pins are in `assets/GITHUB_REUSE.json`. The headless environment generators run under Blender's bundled Python. Restore the asset snapshot before regenerating anything.

## 3. Recreate the three plugins at the recorded revisions

| Plugin | Version here | Actual source revision |
|---|---|---|
| `ecc@ecc` | 2.2.3 | `affaan-m/ECC`, `d2ef2680594f9a17526a6e1a2e18b3d242c5d17b` |
| `ponytail@ponytail` | 5.3.3 | `DietrichGebert/ponytail`, `96608e078b2d5ea607c5c3b8b5a54d1c1fba6846` |
| Matt Pocock skills | 1.3.1 | `mattpocock/skills`, `49dd158d1076134a641b33efb035946536778336` (Windows installed this through `claude-plugins-official`) |

For a fresh computer, run from the project root:

```sh
mkdir -p work/setup
git clone https://github.com/affaan-m/ECC.git work/setup/ecc
git -C work/setup/ecc checkout --detach d2ef2680594f9a17526a6e1a2e18b3d242c5d17b
git clone https://github.com/DietrichGebert/ponytail.git work/setup/ponytail
git -C work/setup/ponytail checkout --detach 96608e078b2d5ea607c5c3b8b5a54d1c1fba6846
git clone https://github.com/mattpocock/skills.git work/setup/mattpocock
git -C work/setup/mattpocock checkout --detach 49dd158d1076134a641b33efb035946536778336
claude plugin marketplace add ./work/setup/ecc
claude plugin marketplace add ./work/setup/ponytail
claude plugin marketplace add ./work/setup/mattpocock
claude plugin install ecc@ecc
claude plugin install ponytail@ponytail
claude plugin install mattpocock-skills@mattpocock
```

Matt's own pinned marketplace is named `mattpocock`; the skill namespace remains `mattpocock-skills`. This gives the same plugin source as the Windows official-marketplace installation. Install it once, through either source, to avoid duplicate skills. Existing nonempty `work/setup/` clones need inspection rather than replacement. Local-directory marketplace commands are documented by [Claude Code](https://code.claude.com/docs/en/plugin-marketplaces). These setup commands were checked against installed metadata and documentation; they have not been run on a Mac in this task.

This task was started with `/ecc:orch-change-feature` and runs with `/ponytail:ponytail full`. The Matt Pocock skills are read from the plugin's files on disk.

## 4. MCP servers used on Windows

| Name | How it runs here | On the Mac |
|---|---|---|
| `roblox-studio` | repo `.mcp.json` → `cmd /c tools\studiomcp_win.cmd` | From the checkout: `claude mcp add --scope local --transport stdio roblox-studio -- python3 "$PWD/tools/run_studiomcp.py"`. The tracked launcher discovers `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP` |
| `blender` | `uvx blender-mcp` / `uvx mcp-for-blender` and the Blender add-on | `uvx mcp-for-blender install-addon`, enable **Interface: MCP for Blender** in Blender, then `claude mcp add --scope local --transport stdio blender -- uvx mcp-for-blender`. Run one live MCP Blender operator |
| `hyper3d` | HTTP `https://api.hyper3d.com/api/mcp` | Optional for this checkpoint; no existing world asset requires it. Reconnect through the receiving account if needed |

The Blender package's current upstream name is `mcp-for-blender`; `blender-mcp` is a compatibility wrapper. See its [maintainer's setup guide](https://github.com/ahujasid/mcp-for-blender#quickstart). Studio has a separate creator-side MCP connection/permission step. Verify tools with `/mcp` and `python3 tools/studio_mcp.py --list`; a config entry does not prove connection. The local stdio syntax is documented by [Claude Code](https://code.claude.com/docs/en/mcp).

ElevenLabs, Forge GUI and any other Claude account connectors need connection on the receiving account; their login state is not in Git. The existing audio files are in the snapshot, so continuation does not need to regenerate or buy them. The creator-reported Studio Animator plugin is installed through Roblox's own plugin management on the receiving computer; its exact asset/version was not independently inventoried here. Headless Blender generation works without that plugin. Forge GUI remains optional under the original visual-quality rule. Never copy keys, tokens, `.claude.json`, `.mcp.json` or app credential stores through Git.

## 5. Roblox and Studio state

- Cloud place made by the creator on 2026-11-16 so MCP permissions could be set: "Asura's Path — Development", universe 10777041159, root place 118614906972571, PRIVATE. Team Create is ON there, so any edit in Edit mode writes to the cloud copy.
- Rule: the cloud place is for approved uploads ONLY (no script edits, inserts, saves, publishes or settings changes). All sync-and-restore tests, Play runs and captures happen in a separate LOCAL copy of the place (copy `places/AsurasPath.rbxlx` to a scratch folder and open that; confirm it is not cloud-saved before every write).
- MCP upload permission is per place and per Studio. On the Mac the creator must open the cloud place and approve `…/asuras-path/assets/source/overworld` (and the audio pack folder) in Assistant Settings → MCP Permissions. Claude must not change that setting.
- Upload authorisation from the creator: this task's meshes and textures, and the five overworld audio beds, to the creator's own account. One upload owner, registry checked before every upload, no duplicates, nothing public, nothing that costs Robux.
- Upload status at 13:15: the directory approval works (POST returned 200), but the one test, `Bell_Lantern_Post.glb`, ended with operation `b921007b-9ee0-472f-88e7-3442c56770e7` done=true, error "Unknown Error", no asset ID. Nothing is uploaded and no registry exists yet. Details in `workers/20a-upload.md` ("Codex retry"). Next step is diagnosis, one change at a time (request fields, mesh-only GLB, texture size, 3D Importer on the local copy).

## 6. How to continue on the Mac

1. Check `git status --short`; preserve existing work. Pull `ux/onboarding-overhaul` with `--ff-only`, then read the top of `PROJECT_STATE.md`. Compare `git rev-parse HEAD` with the source machine before work starts.
2. Fetch and restore the asset snapshot (about **1.23 GB** download, plus local Git/cache and about 2.1 GB of restored files):

   ```sh
   git fetch origin codex/overworld-assets-2026-11-16:refs/remotes/origin/codex/overworld-assets-2026-11-16
   python3 tools/assets/overworld_handoff.py restore
   python3 tools/assets/overworld_handoff.py restore --apply
   ```

   The default is a dry run. It verifies every part, archive, manifest and content hash. `--apply` writes missing files only; differing files are preserved and produce exit 2. Inspect those conflicts before starting. Do not check out or merge the asset branch. `handoff/BUNDLE.json` and `handoff/ASSET_MANIFEST.json` pin the snapshot. The full SHA-256 restore was tested into a new directory on Windows; Mac execution remains unverified.

   Expected asset-branch commit: `1412139fbb6c9adc519031a5d02063c7a952732c`. Check with `git rev-parse origin/codex/overworld-assets-2026-11-16`.
3. Read, in order: `CLAUDE_OPEN_WORLD_PROMPT.md` (the creator's brief), the **Codex handoff completion** section at the top of `CONTINUATION.md`, `LEDGER.md`, `GEOGRAPHY_PLAN.md`, `DELEGATION_STATUS.md`. Historical round-8 stops lower in the files are superseded by the top checkpoint.
4. Run `python3 tools/test_overworld_handoff.py` and `bash tools/verify_all.sh`. To open the **same saved file on both computers**, use `places/checkpoints/AsurasPath_OpenWorld_2026-11-16.rbxlx`; verify it with `shasum -a 256 -c places/checkpoints/AsurasPath_OpenWorld_2026-11-16.sha256` from the repo root. Follow `places/checkpoints/README.md` for the exact open command. This dated checkpoint's fingerprint is **275 scripts, 3149701 bytes, digest 1516687798**. Copy it to `work/handoff-local/` for temporary edits, or build there from newer agreed source with `python3 tools/build.py --output work/handoff-local/AsurasPathTEST.rbxlx`. The older baseline's fingerprint differs by design. Check `persistedToCloud=false` before writes. Runtime terrain appears during Play; the saved file is an unfinished development build, not visual acceptance.
5. Start Claude Code and use `handoff/RESUME_PROMPT.md`. Hierarchy: Fable 5.2 oversight only → one Opus 5.5 lead → Sonnet workers and Haiku readers, four to six lanes, one operator per live Studio window and live Blender, headless Blender for extra mesh lanes. Check actual model routing before expensive work; model labels in prose do not prove delegation.
6. Only one computer writes the shared branch at a time. Before handoff, stop/finish workers, verify, commit explicit task paths, fetch and reconcile remote changes, push, and compare local/remote commit IDs. Repack changed ignored sources as a **new immutable snapshot** with updated pins. `tools/handoff.sh` and `.cmd` rebuild saved places and stage broad folders; use explicit commands for this checkpoint so the baseline and unrelated work remain preserved.

## 7. Exact unfinished work at the completed handoff

- **Assets are now preserved:** 1,277 files / 609 unique contents, including current Blender scenes, GLBs, maps, upload packs, vignettes and audio. Twenty `.blend1` automatic backups are omitted and listed in the manifest; current `.blend` files are included. Restore these before regeneration. `tools/blender/overworld/` carries the generators.
- **T4 terrain optimisation is partial:** the late `Overworld.luau` changes add native annotations, cached region boxes, reused weight tables and an optional pre-culled pad list. Full local verification passes. No new Studio performance measurement exists. Continue `workers/24a-terrain-heartbeat.md`; tight voxel boxes / parallel compute were planned, not completed. Avoid presenting compute-only benchmarks as engine results.
- **Server frame rate while terrain is written fails** (20.9 Hz average, drops to 2–7 Hz). Targets set: 45 Hz or more, glade ready in 20 s, altars in 90 s, whole map in 10 minutes, memory 185 MB or less (memory passes at 178.8 MB). The 45-minute time-sliced version was rejected.
- **Forest slice not signed off.** D6 now places 276 trees (101 near / 175 far), with 74% tower height clear in the static test. Six far-tree GLBs and comparison renders exist. These are local numerical/render results, not real-mesh Studio acceptance. Review `workers/22b-slice-kit-placement.md` and `25a-tree-far.md`, reconcile estimated far specs with the actual manifests, and capture the latest build in Studio.
- **Not yet verified in Studio:** rain and haze fixes, Shen walk-out fix, five summit views, slice captures on the latest build.
- **Creator decisions pending for the final report:** endings deferred with the archived bosses; 12 retired builder source files left on disk; `SolarForms` and `PresentationAudit` are unused but still mapped.
- **Validation at this checkpoint:** full `bash tools/verify_all.sh` passed all 14 stages (including 39 Lune-shim suites); current temp build fingerprint 1516687798. The handoff tool's corruption, path and conflict checks passed; the symlink test was skipped on Windows because creating a symlink required privileges. See `handoff/VALIDATION.md`. No new Studio, multiplayer, device or human visual acceptance was performed by Codex.

## 8. Rules that still bind on any computer

Never invent an asset ID. Never clear all Workspace or Terrain. Lobby (`Workspace.Sanctuary`, `ServerStorage.AsuraLobbyKit`) preserved. Player progress and persistent IDs preserved. No Luau deprecated APIs (see repo `CLAUDE.md`). Do not read or touch `Codex`, `Obsidian Vault` or `Cagebound_Archive`. Do not put credentials in the repo.

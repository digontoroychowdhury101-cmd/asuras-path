# Mac handoff: open-world replacement (written 2026-11-16 13:25 Sydney, Windows computer)

Read this first on the Mac, then `CONTINUATION.md` and `LEDGER.md` in this folder (the lead keeps those current; this file is the fixed setup guide). Assume the Mac has nothing installed.

## 1. What travels by Git and what does not

| Travels (branch `ux/onboarding-overhaul`) | Does NOT travel |
|---|---|
| All source (`src/`), tests and tools (`tools/`), `default.project.json`, registries under `assets/*.json`, `assets/models/` | `assets/source/` (git-ignored by house rule): every new mesh kit (GLB), `.blend` files, vignettes, audio sources and the upload packs under `assets/source/overworld/` and `assets/source/audio/overworld/`. NOT YET TRANSFERRED; see section 7 |
| This folder: brief, `CONTINUATION.md`, `LEDGER.md`, `DELEGATION_STATUS.md`, `GEOGRAPHY_PLAN.md`, worker notes, captures, kit sheets | Claude transcripts and agent state. The Opus lead running on Windows cannot be resumed on the Mac; start a fresh lead from `CONTINUATION.md` (section 6) |
| Spec and tickets: `.scratch/asuras-open-world/` | `.mcp.json` (git-ignored), Studio MCP permissions (set per place, per Studio), scratchpad test copies of the place |
| `places/AsurasPath.rbxlx` exactly as on Windows: still the PRE-overworld baseline on purpose (tests restore to it; script digest 462022588, 286 scripts, 2859366 bytes). Do not rebuild it until final handoff | Roblox login, GitHub login, any keys |

## 2. Install on the Mac

1. Git and GitHub CLI: `brew install git gh`, then `gh auth login`.
2. Clone and switch:
   - `git clone https://github.com/digontoroychowdhury101-cmd/asuras-path.git`
   - `cd asuras-path && git checkout ux/onboarding-overhaul && git pull --rebase origin ux/onboarding-overhaul`
3. Python 3 (Windows used 3.15.0; earlier Mac work used 3.14.3): `brew install python`. Shen tooling also needs `numpy` and `scipy` in a venv; not needed for the overworld work.
4. Rojo 7.7.1 and Luau 0.742 (pinned in `tools/toolchain.env`). Download from https://github.com/rojo-rbx/rojo/releases and https://github.com/luau-lang/luau/releases, put the binaries in `work/bin/rojo` and `work/bin/luau` (or on PATH). `docs/BUILD.md` has the details. Lune is NOT needed: `python3 tools/lune_compat.py --all` runs the Lune suites under a local shim.
5. Blender 5.2.2 LTS from blender.org. Check headless works: `/Applications/Blender.app/Contents/MacOS/Blender -b --python-expr "import bpy; print(bpy.app.version_string)"`.
6. Roblox Studio, signed in as the creator.
7. `uv` (for the Blender MCP server): `brew install uv`.
8. Claude Code (desktop app or CLI), signed in.

## 3. Claude Code plugins used on Windows (install all three)

| Plugin | Version here | Source |
|---|---|---|
| `ecc@ecc` | 2.2.3 | marketplace `ecc`, git `https://github.com/affaan-m/ECC.git` |
| `ponytail@ponytail` | 5.3.3 | marketplace `ponytail`, GitHub `DietrichGebert/ponytail` |
| `mattpocock-skills@claude-plugins-official` | 1.3.1 | marketplace `claude-plugins-official`, GitHub `anthropics/claude-plugins-official` |

In Claude Code: `/plugin marketplace add affaan-m/ECC`, `/plugin marketplace add DietrichGebert/ponytail`, `/plugin marketplace add anthropics/claude-plugins-official`, then `/plugin install ecc@ecc`, `/plugin install ponytail@ponytail`, `/plugin install mattpocock-skills@claude-plugins-official`. If the command form differs in your version, open `/plugin` and add the same three sources by hand. Not verified on the Mac.

This task was started with `/ecc:orch-change-feature` and runs with `/ponytail:ponytail full`. The Matt Pocock skills are read from the plugin's files on disk.

## 4. MCP servers used on Windows

| Name | How it runs here | On the Mac |
|---|---|---|
| `roblox-studio` | repo `.mcp.json` (git-ignored) → `cmd /c tools\studiomcp_win.cmd` | Create `.mcp.json` in the repo root with a `roblox-studio` stdio server that launches Studio's bundled StudioMCP proxy. `tools/run_studiomcp.py` and `tools/studio_mcp.py` are the repo's clients; `docs/BUILD.md` ("Studio probe") gives the Mac launch line. NOT verified on the Mac in this task |
| `blender` | `uvx blender-mcp` (Claude Code) and `uvx mcp-for-blender` (desktop app); Blender must be open with its MCP add-on enabled | Same commands; install the add-on in Blender |
| `hyper3d` | http `https://api.hyper3d.com/api/mcp` | Not needed. It spends credits and is not used by this task |

Never copy keys or tokens between computers through Git. None are needed for the work so far.

## 5. Roblox and Studio state

- Cloud place made by the creator on 2026-11-16 so MCP permissions could be set: "Asura's Path — Development", universe 10777041159, root place 118614906972571, PRIVATE. Team Create is ON there, so any edit in Edit mode writes to the cloud copy.
- Rule: the cloud place is for approved uploads ONLY (no script edits, inserts, saves, publishes or settings changes). All sync-and-restore tests, Play runs and captures happen in a separate LOCAL copy of the place (copy `places/AsurasPath.rbxlx` to a scratch folder and open that; confirm it is not cloud-saved before every write).
- MCP upload permission is per place and per Studio. On the Mac the creator must open the cloud place and approve `…/asuras-path/assets/source/overworld` (and the audio pack folder) in Assistant Settings → MCP Permissions. Claude must not change that setting.
- Upload authorisation from the creator: this task's meshes and textures, and the five overworld audio beds, to the creator's own account. One upload owner, registry checked before every upload, no duplicates, nothing public, nothing that costs Robux.
- Upload status at 13:15: the directory approval works (POST returned 200), but the one test, `Bell_Lantern_Post.glb`, ended with operation `b921007b-9ee0-472f-88e7-3442c56770e7` done=true, error "Unknown Error", no asset ID. Nothing is uploaded and no registry exists yet. Details in `workers/20a-upload.md` ("Codex retry"). Next step is diagnosis, one change at a time (request fields, mesh-only GLB, texture size, 3D Importer on the local copy).

## 6. How to continue on the Mac

1. `git pull --rebase origin ux/onboarding-overhaul`, then read the top of `PROJECT_STATE.md`.
2. Read, in order: `CLAUDE_OPEN_WORLD_PROMPT.md` (the creator's brief), `CONTINUATION.md` (current round, each lane's resume point), `LEDGER.md` (decisions and rulings), `GEOGRAPHY_PLAN.md`, `DELEGATION_STATUS.md`.
3. Check the baseline: `python3 tools/lune_compat.py --all` and `bash tools/verify_all.sh` (builds to a temp file; never overwrites the saved place).
4. Start Claude Code in the repo and give it: "Read outputs/claude-open-world-2026-11-14/MAC_HANDOFF.md and CONTINUATION.md and continue the open-world replacement from the recorded state, following the brief's delegation rules." Hierarchy: Fable 5.2 oversight only → one Opus 5.5 lead (fresh, started from `CONTINUATION.md`) → Sonnet workers and Haiku readers, four to six lanes at once, one operator per live tool (per Studio window, per live Blender), headless Blender for extra mesh lanes.
5. Only one computer works at a time. Before leaving a computer: suites green, commit, `git pull --rebase`, push, `git status` clean.

## 7. Open items at handoff (13:25, 16 Nov)

- **Mesh kits not on GitHub.** `assets/source/overworld/` holds the kits (Bellwood 95 pieces, Amberfall 45, Saltreach 37, Frostmere 32, Ashen Stair 34, hero models, vignettes, upload packs) and is git-ignored. The house pattern for this is a separate assets branch with zip parts under 100 MB and a SHA-256 manifest (see `outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/ARCHIVE.md` and its `scripts/restore_untracked.py`). That has NOT been done for the overworld kits yet. Every kit is rebuilt by its script under `tools/blender/overworld/`, which IS in Git, so the Mac can regenerate them headless if the archive is not made.
- **Server frame rate while terrain is written fails** (20.9 Hz average, drops to 2–7 Hz). Targets set: 45 Hz or more, glade ready in 20 s, altars in 90 s, whole map in 10 minutes, memory 185 MB or less (memory passes at 178.8 MB). The 45-minute time-sliced version was rejected.
- **Forest slice not signed off.** Built pieces approved. Trees go back for lighter near and distant variants, distinct silhouettes, at least 250 trees in the slice, clear sightline from the glade to the ruined bell tower.
- **Not yet verified in Studio:** rain and haze fixes, Shen walk-out fix, five summit views, slice captures on the latest build.
- **Creator decisions pending for the final report:** endings deferred with the archived bosses; 12 retired builder source files left on disk; `SolarForms` and `PresentationAudit` are unused but still mapped.
- **Checkpoint commits may be mid-round.** The commit message says whether the suites were green. The last fully green state recorded by the lead before this checkpoint: lune 39/39, Python 14/14, temp build digest 1543764707.

## 8. Rules that still bind on any computer

Never invent an asset ID. Never clear all Workspace or Terrain. Lobby (`Workspace.Sanctuary`, `ServerStorage.AsuraLobbyKit`) preserved. Player progress and persistent IDs preserved. No Luau deprecated APIs (see repo `CLAUDE.md`). Do not read or touch `Codex`, `Obsidian Vault` or `Cagebound_Archive`. Do not put credentials in the repo.

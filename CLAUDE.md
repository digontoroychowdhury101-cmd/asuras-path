# Claude Vibe-Coding Rules & Instructions: AsurasPath

## User Context
The creator is entirely vibe-coding this Roblox game and does not write code manually. 

## Efficiency & Token-Saving Rules (CRITICAL)
1. **Direct File Updates**: When using the Filesystem MCP plugin, read and write files directly in `src/`. Avoid dumping hundreds of lines of code into the chat.
2. **Surgical Edits**: If outputting code in chat, NEVER reprint an entire 200+ line script. Provide only the specific function, block, or modified lines with precise placement instructions.
3. **Concise Explanations**: Provide test steps and instructions in 2 short bullet points. Avoid technical lectures or syntax breakdowns unless explicitly requested.
4. **Never Read Binaries**: Never open or inspect `.rbxl`, `.rbxlx`, `.glb`, `.obj`, or images with text-reading tools. Refer to `PROJECT_STATE.md`, `default.project.json`, and `docs/BUILD.md` instead.
5. **Scope Boundary**: Confine all edits strictly to this repository. Do NOT read, index, or touch external folders (`Codex`, `Obsidian Vault`, `Cagebound_Archive`).

## Project Layout & Architecture
- `src/`: All Luau source code (Server, Client, Shared, Simulation).
- `places/AsurasPath.rbxlx`: Authoritative Roblox Studio place file (mirrored to `outputs/AsurasPath.rbxlx`).
- `assets/`: Uploaded models (`assets/models/*.rbxmx`), JSON registries, and raw 3D sources (`assets/source/`).
- `tools/`: Automation tools (`start_sync.command`, `auto_pull.command`, Python build scripts).
- `default.project.json`: Rojo configuration mapping `src/` and `assets/models/` into Studio.

## Multi-Machine Relay & Git Protocol (CRITICAL)
- Active branch: `ux/onboarding-overhaul` (all pushes/pulls target this branch).
- **Zero-Stash Rule**: Commit your completed work and preserve unrelated changes and untracked files.
- **Before Concluding Any Turn/Batch**:
  1. If code, assets, or `default.project.json` changed, run `ASURA_BUILD_OUTPUT=work/verify.rbxlx bash tools/verify_all.sh` to keep the saved places intact.
  2. Add at most 60 words at the top of `PROJECT_STATE.md` stating what was completed and what comes next.
  3. Stage explicit paths, commit, and push to `origin ux/onboarding-overhaul`.
  4. Confirm `git status` shows only preserved user files or unrelated work.
- **When Starting Any Session**:
  1. Run `git status`, fetch `origin`, and fast-forward `ux/onboarding-overhaul`.
  2. Inspect the top of `PROJECT_STATE.md` to see what the other computer finished.
  3. Read the latest creator direction and completed work in `outputs/claude-open-world-2026-11-14/handoff/CLAUDE_RETURN_HANDOFF.md`, then read `outputs/claude-open-world-2026-11-14/WINDOWS_HANDOFF.md` for the project procedures and backlog.
- Handoff scripts: `./tools/handoff.sh` (Mac) or `tools\handoff.cmd` (Windows) automate this entire flow.

## Standing creator decisions (every machine, every agent; updated 22 Nov 2026)
- **Current state and next work:** `outputs/claude-open-world-2026-11-14/handoff/CLAUDE_RETURN_HANDOFF.md`. Its claims were verified on the Mac on 22 Nov (see its verification note). Procedures and the older backlog are in `outputs/claude-open-world-2026-11-14/WINDOWS_HANDOFF.md`.
- **Always save to Roblox.** After Play verification, use File > Save to Roblox (As) to the Development place 118614906972571 (universe 10777041159). A saved place is what lets Studio grant the MCP and script permissions. **Never Publish.**
- **Quality bar: "stunning".**
  - There is no total triangle cap.
  - Keep upload sub-meshes under 18–20k tris, never decimate, and use 2048 maps.
- **Sourcing.**
  - Allowed: CC0, CC-BY (credit in `outputs/vesperhold/THIRD_PARTY.md` and `assets/CREDITS.md`) and MIT-style open models or repos, plus ElevenLabs SFX.
  - Never allowed: NC, ND, paid or unclear licences, or Creator Store models.
  - Meshy: not available. The creator has no Pro account, so there is no API key (22 Nov 2026). Build hero props procedurally in Blender or from verified CC0/CC-BY/MIT sources. Never spend Meshy credits.
  - Verify each licence on the asset's own page before downloading.
- **Anti-slop craft rules (creator, 22 Nov 2026).** Use antislop when making anything in the project, including models, world art, UI, in-game text, docs and code comments. Mode is "during": apply it while building, without asking. The vendored MIT copy and a guide to which skill fits which job are in `.agents/skills/antislop/` (start with `SOURCE.md`).
- **Bellwood temple.**
  - `assets/source/landmarks/bellwood_temple_colossal/creator-stair-reference.png` is the target, recreated closely. It overrides older temple art direction.
  - The bare hero tree comes first.
  - Guardian lions (creator, 22 Nov): their faces looked bad, so both heads are intentionally destroyed, with no faces. Show crisp old fractures, fallen head fragments and rubble on well-carved bodies, and give each lion a different break.
  - Current Bellwood work order: `outputs/claude-open-world-2026-11-14/handoff/CLAUDE_BELLWOOD_REPLACEMENT_HANDOFF.md`. Finish the art (tree, root grip, both guardians, side and rear foundations) before building the Roblox replacement.
  - The creator wants Vesperhold-scale landmarks and larger arenas.
- **Hard limits.**
  - Never modify `places/AsurasPath.rbxlx` or `outputs/AsurasPath.rbxlx`.
  - Never break the lobby, combat, progression, persistent IDs or the Shen barrier.
  - Stage explicit paths only.
  - Run one heavy Blender job at a time, under `work/vesperhold-claude/heavy.lock`.
  - No multi-client tests on the MacBook.

## Modern Luau Standards
- Always use the `task` library (`task.wait()`, `task.spawn()`, `task.delay()`). NEVER use deprecated `wait()`, `spawn()`, or `delay()`.
- Use modern physics constraints (`LinearVelocity`, `VectorForce`, `AlignOrientation`) instead of deprecated BodyMovers (`BodyVelocity`, `BodyGyro`).
- Use `workspace:Raycast()` with `RaycastParams` instead of deprecated `FindPartOnRay`.
- Keep ModuleScripts modular and clean.
- Follow Schema version 4 with attributes: Vigor, Endurance, Strength, Dexterity, ArcaneQi.

## Agent skills

### Ro-Engineer

For Roblox/Luau implementation and review and whenever the user mentions ro-engineer, load `/ro-engineer:ro-engineer` from the Claude Code plugin at v1.0.2 or newer. If that plugin is unavailable or older, read the project copy at `.agents/skills/ro-engineer/SKILL.md`.

### Issue tracker

Issues live in GitHub Issues (`gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five labels: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` + `docs/adr/` (created lazily). See `docs/agents/domain.md`.

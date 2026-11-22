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

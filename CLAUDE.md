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
- **Zero-Stash Rule**: NEVER conclude a task or session with uncommitted changes in the working directory.
- **Before Concluding Any Turn/Batch**:
  1. If code, assets, or `default.project.json` changed, run `python3 tools/build.py` to ensure `places/AsurasPath.rbxlx` is updated.
  2. Append at most 60 words to `PROJECT_STATE.md` stating what was completed and what comes next.
  3. Commit and push: `git add -A && git commit -m "feat/fix: summary" && git push origin ux/onboarding-overhaul`
  4. Confirm `git status` is clean so the other computer pulls complete, unbroken work.
- **When Starting Any Session**:
  1. Run `git pull --rebase origin ux/onboarding-overhaul`.
  2. Inspect the top of `PROJECT_STATE.md` to see what the other computer finished.
- Handoff scripts: `./tools/handoff.sh` (Mac) or `tools\handoff.cmd` (Windows) automate this entire flow.

## Modern Luau Standards
- Always use the `task` library (`task.wait()`, `task.spawn()`, `task.delay()`). NEVER use deprecated `wait()`, `spawn()`, or `delay()`.
- Use modern physics constraints (`LinearVelocity`, `VectorForce`, `AlignOrientation`) instead of deprecated BodyMovers (`BodyVelocity`, `BodyGyro`).
- Use `workspace:Raycast()` with `RaycastParams` instead of deprecated `FindPartOnRay`.
- Keep ModuleScripts modular and clean.
- Follow Schema version 4 with attributes: Vigor, Endurance, Strength, Dexterity, ArcaneQi.

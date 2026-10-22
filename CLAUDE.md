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
- `places/server.rbxl`: Authoritative Roblox Studio place file (mirrored to `~/Documents/Roblox/server.rbxl`).
- `assets/`: Uploaded models (`assets/models/*.rbxmx`), JSON registries, and raw 3D sources (`assets/source/`).
- `tools/`: Automation tools (`start_sync.command`, `auto_pull.command`, Python build scripts).
- `default.project.json`: Rojo configuration mapping `src/` and `assets/models/` into Studio.

## Multi-Machine Relay & Git Protocol
- Active branch: `ux/onboarding-overhaul` (all pushes/pulls target this branch).
- When finishing a task/prompt, automatically stage and push:
  `git add . && git commit -m "feat/fix: concise summary" && git push origin ux/onboarding-overhaul`
- Rojo (`start_sync.command`) and Auto-Pull (`auto_pull.command`) run locally to live-sync Studio.

## Modern Luau Standards
- Always use the `task` library (`task.wait()`, `task.spawn()`, `task.delay()`). NEVER use deprecated `wait()`, `spawn()`, or `delay()`.
- Use modern physics constraints (`LinearVelocity`, `VectorForce`, `AlignOrientation`) instead of deprecated BodyMovers (`BodyVelocity`, `BodyGyro`).
- Use `workspace:Raycast()` with `RaycastParams` instead of deprecated `FindPartOnRay`.
- Keep ModuleScripts modular, clean, and under 150 lines.
- Follow Schema version 4 with attributes: Vigor, Endurance, Strength, Dexterity, ArcaneQi.

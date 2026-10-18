# Claude Vibe-Coding Rules & Instructions: AsurasPath

## User Context
The creator is entirely vibe-coding this Roblox game and does not write code manually. 

## Efficiency & Token-Saving Rules (CRITICAL)
1. **Direct File Updates**: When using the Filesystem MCP plugin, read and write files directly in `src/`. Avoid dumping hundreds of lines of code into the chat.
2. **Surgical Edits**: If outputting code in chat, NEVER reprint an entire 200+ line script. Provide only the specific function, block, or modified lines with precise placement instructions.
3. **Concise Explanations**: Provide test steps and instructions in 2 short bullet points. Avoid technical lectures or syntax breakdowns unless explicitly requested.

## Modern Luau Standards
- Always use the `task` library (`task.wait()`, `task.spawn()`, `task.delay()`). NEVER use deprecated `wait()`, `spawn()`, or `delay()`.
- Use modern physics constraints (`LinearVelocity`, `VectorForce`, `AlignOrientation`) instead of deprecated BodyMovers (`BodyVelocity`, `BodyGyro`).
- Use `workspace:Raycast()` with `RaycastParams` instead of deprecated `FindPartOnRay`.
- Keep ModuleScripts modular, clean, and under 150 lines.

## Rojo Sync Workflow
- Project configuration: `default.project.json`
- Source code lives in `src/`
- Rojo syncs `src/` directly to Roblox Studio in real time.

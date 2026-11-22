# Asura’s Path coding workflow

Use the project-local ro-engineer skill at `.agents/skills/ro-engineer/SKILL.md` for Roblox/Luau implementation and review and whenever the user mentions ro-engineer. Use v1.0.2 or newer and read only the references relevant to the task. Preserve existing module interfaces, server authority, and project architecture; new frameworks require a demonstrated need.

Before editing, inspect affected callers, source mappings, and the current working tree. Preserve unrelated work in progress. Never stage or commit another task’s edits.

Use `docs/BUILD.md` for current build instructions and `tools/toolchain.env` for pinned tool versions. CI and full local verification use `bash tools/verify_all.sh`; use focused checks while iterating. Verification builds go to a temporary path so saved Studio places are preserved.

For combat and VFX reviews, inspect resource ownership, respawn/streaming teardown, delayed callbacks, playback ownership, and repeated encounter cleanup. Report concrete failure scenarios and file locations. Do not change code for a speculative leak without tracing its lifetime.

Report static review, local regression, Studio integration, multiplayer, and device profiling evidence separately. A local test pass does not establish engine behavior, combat feel, or performance. Use comparable recorded workloads for performance claims.

## Standing creator decisions (every machine, every agent; updated 22 Nov 2026)
- **Current state and next work:** `outputs/claude-open-world-2026-11-14/handoff/CLAUDE_RETURN_HANDOFF.md`. Its claims were verified on the Mac on 22 Nov (see its verification note). Procedures and the older backlog are in `outputs/claude-open-world-2026-11-14/WINDOWS_HANDOFF.md`.
- **Always save to Roblox.** After Play verification, use File > Save to Roblox (As) to the Development place 118614906972571 (universe 10777041159). A saved place is what lets Studio grant the MCP and script permissions. **Never Publish.**
- **Quality bar: "stunning".**
  - There is no total triangle cap.
  - Keep upload sub-meshes under 18–20k tris, never decimate, and use 2048 maps.
- **Sourcing.**
  - Allowed: CC0, CC-BY (credit in `outputs/vesperhold/THIRD_PARTY.md` and `assets/CREDITS.md`) and MIT-style open models or repos, plus ElevenLabs SFX.
  - Never allowed: NC, ND, paid or unclear licences, Creator Store models, or Meshy credits.
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

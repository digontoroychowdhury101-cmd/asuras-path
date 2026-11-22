# Asura’s Path coding workflow

Use the project-local ro-engineer skill at `.agents/skills/ro-engineer/SKILL.md` for Roblox/Luau implementation and review and whenever the user mentions ro-engineer. Use v1.0.2 or newer and read only the references relevant to the task. Preserve existing module interfaces, server authority, and project architecture; new frameworks require a demonstrated need.

Before editing, inspect affected callers, source mappings, and the current working tree. Preserve unrelated work in progress. Never stage or commit another task’s edits.

Use `docs/BUILD.md` for current build instructions and `tools/toolchain.env` for pinned tool versions. CI and full local verification use `bash tools/verify_all.sh`; use focused checks while iterating. Verification builds go to a temporary path so saved Studio places are preserved.

For combat and VFX reviews, inspect resource ownership, respawn/streaming teardown, delayed callbacks, playback ownership, and repeated encounter cleanup. Report concrete failure scenarios and file locations. Do not change code for a speculative leak without tracing its lifetime.

Report static review, local regression, Studio integration, multiplayer, and device profiling evidence separately. A local test pass does not establish engine behavior, combat feel, or performance. Use comparable recorded workloads for performance claims.

Current handoff (22 Nov 2026): start with `outputs/claude-open-world-2026-11-14/handoff/SOL_RESUME_PROMPT.md`, then `outputs/claude-open-world-2026-11-14/WINDOWS_HANDOFF.md` in full.

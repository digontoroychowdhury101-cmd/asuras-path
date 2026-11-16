# Skills inventory (task 0)

Read-only map of skill files used by the open-world work. Paths are exact.

## mattpocock-skills 1.3.1

Root: `C:/Users/disha/.claude/plugins/cache/claude-plugins-official/mattpocock-skills/1.3.1/skills/`

Note: the skills are not directly under `skills/`. They sit in category folders: `engineering/`, `productivity/`, `misc/`, `in-progress/`, `deprecated/`.

| Skill | SKILL.md exists | Exact path |
|---|---|---|
| to-spec | yes | `.../skills/engineering/to-spec/SKILL.md` |
| to-tickets | yes | `.../skills/engineering/to-tickets/SKILL.md` |
| implement-spec | yes | `.../skills/engineering/implement-spec/SKILL.md` |
| handoff | yes | `.../skills/productivity/handoff/SKILL.md` |
| tdd | yes | `.../skills/engineering/tdd/SKILL.md` |
| codebase-design | yes | `.../skills/engineering/codebase-design/SKILL.md` |
| code-review | yes | `.../skills/engineering/code-review/SKILL.md` |

Procedures (summarised from the files read):

**to-spec** (`engineering/to-spec`, disable-model-invocation: true)
- No interview. Synthesise the current conversation and codebase into a spec.
- Explore the repo if not already done. Use the domain glossary vocabulary and respect ADRs.
- Sketch test seams, preferring existing seams and the highest possible one. Check them with the user.
- Write the spec with the template: Problem Statement, Solution, User Stories (numbered, extensive), Implementation Decisions (no file paths or snippets, unless a prototype snippet encodes a decision better than prose), Testing Decisions, Out of Scope, Further Notes.
- Publish to the project issue tracker with the `ready-for-agent` triage label.
- Tracker and label vocabulary come from `/setup-matt-pocock-skills`. If missing, the user must run that first.

**to-tickets** (`engineering/to-tickets`, disable-model-invocation: true)
- Input: a plan, spec, or the conversation. A reference (spec path or issue) is fetched if passed as an argument.
- Draft tracer-bullet vertical slices. Each cuts a complete path through all layers, is demoable alone, and fits one context window. Prefactor first.
- Wide mechanical refactors are the exception: use expand, migrate in batches, then contract.
- Give each ticket blocking edges. Show the list to the user and iterate until approved.
- Local tracker: one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from 01 in dependency order. Each file has What to build, Blocked by, Status (ready-for-agent), and acceptance checkboxes.
- Real tracker (GitHub, etc.): one issue per ticket, blockers first, native blocking links where available, `ready-for-agent` label. Do not close or modify the parent issue.
- Work the frontier: any ticket whose blockers are all done.

**implement-spec** (`engineering/implement-spec`, disable-model-invocation: true)
- Input: a spec with tickets from to-spec and to-tickets. Treat the tickets as a task graph, not a list.
- Create one integration branch for the whole spec.
- Optional exploration subagent writes notes outside the repo.
- One implementer subagent per ticket, each in its own worktree and branch. Each one checks it is based on the integration branch, calls the Skill tool with `tdd`, and merges the integration tip before reporting done.
- A merger subagent merges each finished ticket into the integration branch. Recompute the frontier and launch more implementers.
- When all tickets are done, run the `code-review` skill on the integration branch. Fix findings in one implementer subagent.
- Mark the draft PR ready, or close tickets per tracker. Report the integration branch. Clean up worktrees.

**handoff** (`productivity/handoff`, disable-model-invocation: true)
- Writes a handoff document to the OS temp directory (`%TEMP%` on Windows), not the workspace.
- Includes a "suggested skills" section naming Skill tool calls for the next agent.
- Reference specs, plans, ADRs, issues and commits by path or URL instead of duplicating them.
- Redact secrets and personal data.
- If arguments are passed, tailor the doc to that next-session focus.

**tdd, codebase-design, code-review**: SKILL.md files exist (paths above). Procedures not summarised, per the task scope.

Other mattpocock skills present in the same tree (for reference, not asked): `engineering/` contains ask-matt, diagnosing-bugs, domain-modeling, grill-with-docs, implement, improve-codebase-architecture, pr, prototype, research, retro, setup-matt-pocock-skills, triage, wayfinder, wizard. `productivity/` contains grill-me, grilling, teach, to-questionnaire, wait-what, writing-for-agents.

## ponytail 5.3.3

Root: `C:/Users/disha/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/`

Skill names (each has a SKILL.md):
- ponytail
- ponytail-audit
- ponytail-debt
- ponytail-gain
- ponytail-help
- ponytail-review

## ro-engineer (repo)

Path: `C:/Users/disha/Documents/asuras-path/.agents/skills/ro-engineer/SKILL.md` (exists).

Reference files in `references/`:
cleanup-lifecycle.md, client-server-boundaries.md, composition.md, ecs.md, game-loops.md, live-ops-events.md, luau-modern.md, luau-types.md, market-references.md, networking-remotes.md, object-pooling.md, oop-patterns.md, pattern-selection.md, performance.md, player-incentives.md, progression-economy.md, retention-psychology.md, sharp-edges.md, state-management.md, system-design.md, testing.md, tool-modes.md

Other folders: `workflows/` (code-review, design-game-loop, design-system, economy-audit, implement, performance-audit, plan, retention-audit), `templates/`, `scripts/`, `docs/`, `tests/`.

## UNCERTAIN
- The task named the mattpocock path as `skills/<name>/SKILL.md`. The real layout uses category folders, so the paths above are the ones that exist.
- Only the four procedures listed above were read in full. Other skill bodies were not opened.

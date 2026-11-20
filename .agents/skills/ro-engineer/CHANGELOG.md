# Changelog

## v1.0.2 (2026-11-13)

Light update: guardrails for agents that create or insert assets through the
Roblox Studio MCP server.

- Add `references/asset-compliance.md`: content, IP, and script-security checks
  for MCP mesh/material/model/animation generation, store inserts, image
  uploads, and saves; safe prompting for generators; blood/gore risk guide.
- Preview mode by default (multi-angle captures, per-asset or batch approval,
  including assets made by other skills); opt-in Autopilot with at most two
  self-corrections, quarantine, and an end-of-run report.
- Hard stops in every mode: image uploads, scripted store inserts, DO NOT
  UPLOAD findings, unknown-rights content, cloud-place saves, destructive edits.
- Stage in `ServerStorage/_AssetStaging`; quarantine in `_AssetQuarantine`.
- Route asset work to the new reference from `SKILL.md`.


## v1.0.1 (2026-11-01)

v1.0.0 included unnecessary generic programming explanations, repeated rules,
and overly rigid planning/template requirements. This release corrects that
overreach while retaining useful Roblox security, lifecycle, and design detail.

- Make routing progressive, project-aware, and proportional to the task.
- Replace generic architecture tutorials/count thresholds with fit, integration
  cost, ownership, and profiling criteria; remove the compulsory class template.
- Preserve server validation, durable/idempotent receipts, persistence and
  teardown safeguards; correct iteration, task timing, streaming cleanup,
  connection-inspection, and performance assumptions.
- Detect Studio/ROTEX/repository/offline capabilities without fixed tool names;
  distinguish generated, statically checked, type-checked, and runtime-tested work.
- Document Claude/Codex/ChatGPT installation boundaries and verified platform
  specifications; add optional OpenAI display metadata and a portable plugin wrapper.
- Build validated standalone/plugin archives from one source with portable ZIP
  paths, hashes, reference checks, and packaging regression tests.
- Keep game-design references optional, label historical market notes as
  unverified, and provide a benchmark plan without claiming unmeasured gains.
- Add a v1.0.1 banner and direct installation/download guidance for supported
  ChatGPT environments; ignore generated `promo/**/png/` folders.


## v1.0.0 (2026-10-30)

First release of ro-engineer.

- `SKILL.md` router with tool detection (`studio`, `rotex`, `offline`), a
  routing table and always-on core rules.
- 21 references: modern Luau, Luau types, pattern selection, composition,
  OOP, ECS, object pooling, state management, system design, client/server
  boundaries, networking, cleanup, performance, testing, sharp edges, game
  loops (base-and-collect building blocks), market references (dated
  snapshot), player incentives, retention psychology, progression and
  economy, live ops.
- 8 workflows: plan, design-game-loop, design-system, implement, code review,
  performance audit, retention audit, economy audit.
- 4 templates: plan, game loop, design doc, module.
- Claude Code plugin and marketplace manifests, plus a claude.ai upload zip.

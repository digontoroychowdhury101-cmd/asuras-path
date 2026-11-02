# Asura's Path — combat recovery prompts for Opus 5.5

Prepared 2 November 2026. This package requests implementation, repository research and integration, followed by genuine multiplayer verification. Creating these prompts does not implement or verify the fixes.

## Mac first, Windows second (updated after Stage 2 closure)

Use these two replacement dispatch prompts for the remaining work:

1. **`03A_MAC_IMPLEMENTATION.md`** — send to Mac Claude first. Combines original Stage 3, the six-point follow-up and closure carryovers. Implements/validates what is feasible, then writes `MAC_TO_WINDOWS.md`. It deliberately stops before final multiplayer acceptance.
2. **`03B_WINDOWS_VERIFY_AND_COMPLETE.md`** — send to Windows Claude after the Mac handoff is committed/pushed and the Mac worker is paused. Finishes Stage 3 runtime work, then executes Stage 4 and available Stage 5 checks.

These prompts refer to the master and original stage files in the repository; Claude should read those files directly. You do not need to paste all the older prompts again. Their explicit scope overrides the master's instruction to execute every stage in one session. Do not run both workers against the branch simultaneously. Sync the handoff before switching machines.

## How to use

Paste `MASTER_PROMPT.md` into Opus first. It is a self-contained instruction to execute all five stages in order. For smaller sessions, also paste the corresponding numbered stage file, one stage at a time. Every stage inherits the master contract; do not send a numbered file alone without providing the master.

1. `01_BASELINE_AND_RESEARCH.md` — establish evidence, inspect the harness, verify external sources and select concrete adaptations.
2. `02_TIMING_INPUT_AND_PARRY.md` — implement the shared timeline, input lifetime, prediction/reconciliation and parry correctness.
3. `03_ANIMATION_FOOTWORK_AND_CONTACT.md` — integrate movement/animation techniques and complete visible combat coverage.
4. `04_REAL_MULTIPLAYER_VERIFICATION.md` — repair and extend the harness; verify two real clients under measured conditions.
5. `05_FEEL_ACCEPTANCE_AND_HANDOFF.md` — ordinary-input acceptance, regression, clean production build and honest handoff.

The stage prompts are execution batches, not requests to stop at a plan. If a stage has an external blocker, document it, finish independent authorized work, and do not claim dependent acceptance. Human gameplay judgments must remain human judgments.

The previous audit used local commit `497e23b`. Re-inspect current source: findings can become stale. Previous approval review rejected an automatic `git pull --rebase`; this package does not authorize bypassing that rejection or resolving it through another command. Follow the current host permissions and explicit user authorization for any later sync.

## Recommended dispatch

For one sustained session: send the master and say, “Execute all five linked stages. Do the implementation and verification; do not stop after analysis.”

For separate sessions: send the master plus Stage 1; after its artifacts exist, send the master plus Stage 2, and so on. The state and evidence files prescribed below let each session continue without relying on chat history.

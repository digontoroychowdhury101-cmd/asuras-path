# Earned campaign evidence ledger (follow-up 22)

Opened 25 Oct 2026. It is filled **one play session at a time**, from actual progression only.

**Current total: 0 / 6 sovereigns earned.** No earned session has been played yet.

## What counts as earned

- **Profile:** a fresh profile, or one carried over from an earlier *earned* session on the same persistent store.
- **Input:** normal human input: keyboard and mouse, controller, or touch.
- **No QA tools:** no QA probe, no playtest panel (`AsuraPlaytestSeeded` must never appear), no command-bar edits, no seeded flags, teleports, heals, weapons or KO protection.
- **Difficulty:** untouched. No change to numbers between sessions without a new build digest being logged.

**Not earned, ever:**
- diagnostic awards (F04–06);
- seeded six flags (F21);
- the campaign ledger regression's 99 seeded checks;
- anything done with `tools/qa/HumanPlaytest.*` or `OmniCombatProbe`.

## Persistence (read before session 1)

Plain Studio Play uses an **in-memory mock store** (`Config.Backend.StudioLiveData = false`). Each Play starts a fresh profile, so you have two ways to play.

**A. One sitting.** The session lasts exactly one Play, with no Stop. Progress ends when you press Stop.
- It works today.
- It can bank only what fits in one sitting, for example opening → Twin Sentinels.

**B. Persistent (needed for the full 6–10 h run).** Play on a separate private test experience with Studio API access, plus a temporary, uncommitted `StudioLiveData = true`. This is route B in `F02_RECOVERY.md` and backlog item 2 in `POST_F26_AUDIT.md`. Sessions then carry over with the same account.

## Per-session record (copy this block for each session)

```
### Session N — <date>, <computer>, <route A or B>
Build digest at start: (Claude reads it from Studio; must be logged)
Profile: fresh / continued from session N-1
Input device:
Played: <start time> – <end time>
Reached: (region / altar / last objective text)
Sovereigns attempted (phase reached, tries, result):
Earned this session: (boss names, or none)
Altars kindled / inscriptions read / caches opened:
Deaths, stains reclaimed:
Stopped at: (exact place + objective text on screen)
What blocked progress: (bug, difficulty, confusion, time)
Exact next action:
Recording / notes file:
```

## Sessions

### Session 0: setup check, 25 Oct 2026, Computer B (macOS). Not a play session.

| Field | Value |
|---|---|
| Build | `56a61a9`, digest 1219538751 (Studio Edit read-back) |
| What happened | Claude booted a fresh profile in Studio Play to confirm the starting state. No progression was attempted. The same Play was then used for seeded combat diagnostics, so it is **not earned**. |
| Fresh state seen | Sanctuary (0, 603, 920), Lv 1, 500 Essence, Jian, flask ×3, objective "Kneel at the Primal Bonfire", training card 1/10 at the Monastery Gate |
| Earned | none |
| Stopped at | n/a |
| What blocks progress | The mock store resets on every Stop, so a full campaign needs route B. Route A works for single-sitting sessions. |

**Exact next action (owner):**
1. Start **Session 1, route A**: Studio → Play → do **not** load the playtest panel.
2. Play the opening, the training, the Monastery and the Twin Sentinels in one sitting.
3. Before pressing Stop, tell Claude "log the session". Claude reads the digest and live progress (read-only) and fills the block above.

In parallel, set up route B so that later sessions persist.

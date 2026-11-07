# AR01 + Grandmaster Shen: integration handoff

Environment completion (this branch) and combined encounter acceptance are **separate gates**. This branch claims only the first, and only as far as RESULTS.md's evidence goes.

## Inputs
- **Environment:** `codex/windows-arenas`, at the AR01 commit. It is based on `84c4a7f`.
- **Shen:** a stable checkpoint that Mac commits and pushes to `ux/onboarding-overhaul` after its current debugging session. Use that commit, never an uncommitted working copy.

## Steps (on whichever machine holds the Shen checkpoint)
1. Pull both branches:

   ```bash
   git fetch origin ux/onboarding-overhaul codex/windows-arenas
   ```

2. Make a scratch integration branch from the Shen checkpoint and merge the environment work into it. Do not merge into the relay branch until step 6 passes.

   ```bash
   git switch -c integrate/ar01-shen origin/ux/onboarding-overhaul
   ```

   ```bash
   git merge --no-ff origin/codex/windows-arenas
   ```

3. Files most likely to conflict, if Mac touched them:

   | File | AR01 owns | Shen owns |
   |---|---|---|
   | `src/shared/WorldDefinitions.luau` | Ash region and arena box | Boss stats |
   | `src/shared/EnvironmentProfiles.luau` | Ash grades | Unbound/phase look |
   | `src/server/Services/ArenaLighting.luau`<br>`src/shared/ArenaLightPlan.luau` | Ash lights and fill spacing | — |
   | `default.project.json` | `AsuraCovenantKit` entry | Shen asset entries |
   | `PROJECT_STATE.md` | Keep both lines | Keep both lines |

4. Build and run the regression, including the test that was skipped on Windows:

   ```bash
   python3 tools/build.py --output /tmp/AsurasPath_integrate.rbxlx
   ```

   ```bash
   bash tools/verify_all.sh
   ```

   `test_shen_integration.py` must pass with the Mac audio manifest present.
5. In Studio, open the temp build in a Roblox-saved or scratch window, not the relay's saved place. Then:
   - Re-run the probe: `tools/qa/AR01ShenProbe.luau`, with `HOLD_SECONDS` set to 20, installed in Play on the Server datamodel.
   - Compare against `shen_probe_seeded.json`:
     - worst clamp at most 2 studs;
     - corners reached;
     - phase 2 reached;
     - Skyfall lands inside;
     - spawn gap 45.
   - Re-run `tools/arenas/ar01_captures.py` and compare with `after/`.
6. Combined acceptance (human; pending; never inferred from step 4 or 5):
   - A real fight from the gate on normal input, not seeded.
   - Camera in all four corners and against the side band.
   - PrayerBeads and BloodWave at r90 on the larger floor. Corners are about 153 studs from centre, so decide whether escaping to a corner is acceptable.
   - Skyfall near the edges.
   - Victor exit after a win; reset after a death.
   - Two clients, then phone, tablet and controller.
7. Only after step 6, merge `integrate/ar01-shen` into `ux/onboarding-overhaul` through the normal relay handoff.

## Known open items carried into the merge
- The creator chose to keep the Ash night (2026-11-07). The Shen fight's lighting is unchanged, and the far horizon is not visible at night.
- Mid-fight exit keeps the fight sealed by existing design. A Victor exit is only possible after a win.
- H01 has a labelled pending slot.

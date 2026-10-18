# Asura's Path local play test

Run: 17 October 2026, 23:55 AEDT  
Roblox Studio: 0.743.0.7431133  
Result: local startup and basic controls smoke test passed after fixing a loading-screen blocker.

## Fix made

The loading cover still waited for the retired `AsurasPathFrontEnd/ThreeSections` menu. The current client builds `AsuraHUD`, so the cover never dismissed despite both bootstraps reporting ready. Updated `src/loading/Loading.client.luau` to wait for the current HUD, client readiness, and character root; replaced the cage-era loading tagline. Rebuilt `outputs/AsurasPath.rbxlx` and confirmed the cover clears in a fresh Studio session.

## Verified

- All six local suites passed: Asura stages 1, 2 and 3; backend; profile integrity; commercial systems.
- All 34 active Luau source files compiled before the fix; the changed loading script compiled again after the fix.
- The place build completed with all 34 mapped sources present.
- Server and client bootstrap ready messages appeared in the actual Studio session.
- Player spawned in the Shrine of the Ascendant; the current HUD displayed health, stamina, weapon loadout, gourd charges, and essence.
- Live diagnostics confirmed client ready, loading cover removed, and HUD present (`true true true`).
- Movement changed the player's position; the temporary observer measured 8.46 studs of net displacement over its sampling window.
- Input produced replicated `Startup`, `Recovery`, `Deflecting`, `Blocking`, and `Dashing` states.
- Weapon swapping changed the HUD between Jian Sword and Iron Fist.
- The Primal Bonfire prompt opened the altar menu; Rest produced the Altar Kindled banner.
- No `CreatorError` entries were present in the play-session log at the final check. Studio did emit internal UI/avatar asset warnings.

## Test boundaries

This was a single-player local smoke test with Studio mock persistence. Opponent damage, timed deflect success, boss phases, death/bloodstain recovery, multiplayer duels, network impairment, cloud persistence, purchases, and mobile/gamepad play were not exercised in Studio during this run. Passing pure-module tests is separate from these engine-level scenarios.

## Artifacts

- Rebuilt place: `outputs/AsurasPath.rbxlx`.
- Running Studio copy: `/private/tmp/AsurasPath-Playtest.rbxlx` (same rebuilt place; separate from the project output).
- Selected game diagnostics: `outputs/AsurasPath-Playtest-Evidence.log`.
- Source Studio log: `0.743.0.7431133_20261017T125028Z_Studio_8d344_last.log`.

The temporary combat-state observer disconnects automatically after 45 seconds. It was entered only in the local Studio client and was not added to project source. The play session was left running.

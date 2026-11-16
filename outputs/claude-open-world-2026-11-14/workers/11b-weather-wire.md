# 11b weather wiring + Shen arena light (lane 3b, source only)

Supersedes: nothing (no 11b file existed). Linked from LEDGER.md by the lead. Why new: durable log for lane 3b. Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Log
- [done] EnvironmentController: `new(state, weather)`; composed profile branch (Key "Weather", 2.4 s on entry then 0.4 s, midnight ClockTime wrap snaps instead of tweening backwards); `Weather:Profile(boss)` is nil in fights/lobby/domain so the keyed arena/boss path is untouched; sky logic extracted to applySky.
- [done] FoliageWind: `new(weather)`; `push()` is the only GlobalWind write: weather.Wind if present else baked lobby BaseWind, x0.1 if reduced; re-pushed every 0.5 s refresh.
- [done] SoundscapeController: `new(state, movement, weather)`; Wind.ambience(weather.Wind) when present, else the old lobby 0.12/0.22; volume tracked each 0.15 s tick.
- [skipped] BossCloth: Shen's domain is the only cloth user and weather.Wind is nil there (domain + fight), so ClothSim.DefaultWind stays. No code change.
- [done] ArenaLighting: cause + fix below. tools/test_weather_composition.luau: 113 checks pass.
- [done] verification: lune_compat --all all PASS; tools/test_*.py pass (test_campaign_regions flaked once on another lane's temp file, 421 on rerun); luau-compile --null clean on 4 edited files; scratch build l3b.rbxlx OK.

## Arena light cause + fix
Baseline fb51a42: ArenaLightPlan.FloorY = 0 and the old Ash Colosseum arena was Center (0,20,-1960), floor 0, so braziers (Y 0.35) and fills (Y 18) lit it. Plan and Profiles are unchanged since, but Overworld.apply moved Shen's Arena to Center (-7200,1600,-8255) (floor 1580). Plan.braziers/fills still emit Y 0..18, so all 4 braziers + fill lanterns were built about 1560 studs under the mountain: nothing lit the cavity (matches 10b: 193 lights, none on the floor). Fix (ArenaLighting only): lift every light and fire pit by `arena.Center.Y - 20`; legacy Y 20 arenas lift 0. Fill brightness/range (0.9/60) and the combat profile (ambient lum >= Floor, glare caps) unchanged.

## WIRING FOR LEAD (Bootstrap.client.luau, I did not edit)
- `local soundscape = Soundscape.new(state, movement, weather)` (line ~104; `weather` must be created before it)
- `local foliageWind = FoliageWind.new(weather)` (line ~124)
- Environment.new(state, weather) as already wired.
- Create `weather` before Soundscape/FoliageWind lines (currently Soundscape is built at ~104).

## STUDIO MUST VERIFY
Shen arena floor lit at player height (braziers visible on floor, fills even, no glare blow-out); rain slant matches grass bend; dawn/dusk/midnight transition has no ClockTime flash at wrap; leaving overworld into the domain/lobby restores the keyed look and baked wind; wind ambience loudness varies with weather; reduced motion still calms grass.

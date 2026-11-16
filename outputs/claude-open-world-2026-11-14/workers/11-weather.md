# 11 weather, time, composition (lane 3, source only)

Supersedes: nothing (searched repo for Wind/Weather files: only FoliageWind.luau, a plant scheduler). Linked from LEDGER.md by the lead. Why new: durable per-step log for ticket 11. Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Design (decided before editing)
- Wind: new shared `Wind.luau`, ONE source. Overworld prevailing wind is FROM east-south-east (bearing 112.5 deg), so it blows toward WNW (X<0, Z<0); consistent with the rain shadow (Forest windward on the east, Ravine/Basin in the lee). Lobby's `Config.Workspace.GlobalWind` {6,0,2} (blows toward ESE) is passed through untouched.
- Composition: pure `Profiles.compose` in EnvironmentProfiles (no engine deps, no requires): priority boss > shelter > weather > time > biome, comfort scales effects; glare caps and fill floors enforced last.
- Clock: server publishes Workspace attribute `AsuraWorldEpoch` (server time) in `Environment.Apply`; clients derive hour and weather from it (no remotes, late joiners agree). Server never advances Lighting.ClockTime (lobby unchanged).
- Weather: deterministic per-region slots (integer hash), blended by `Overworld.blendAt` weights so margins have no snap.
- Client `WeatherController`: samples position, owns only precipitation FX (one tagged part+emitter, created lazily, destroyed when inactive) and exposes `:Profile()`/`.Wind` for the single Lighting owner (EnvironmentController) and FoliageWind (sole GlobalWind writer).
- Server stops writing Workspace.GlobalWind (baked in the place via project.json); it only warns on mismatch, so FoliageWind is the sole writer.

## Log
- [start] read ticket, LEDGER C1/C2, EnvironmentService/Profiles/Overworld, nav-env, test_audiovisual. Next: Wind.luau, then Profiles.compose.
- [done] src/shared/Wind.luau (Prevailing ESE from 112.5, Toward, sample/drift/ambience). Next: Profiles.compose in EnvironmentProfiles.
- [done] EnvironmentProfiles: Clock/Night/Glare/Weather/Climate, hourAt, weatherMix/weatherBlend, compose (boss>shelter>weather>time>biome; glare+fill guard). Next: EnvironmentService, WeatherController, tests.
- [done] EnvironmentService: no GlobalWind write (warn only), AsuraWorldEpoch attribute in Apply, Clock(), Stop(). Next: WeatherController, tests.
- [done] src/client/Controllers/WeatherController.luau (Sample/Profile/Reset/Counts/Update/Destroy; FX tag AsuraWeatherFx, shelter tag AsuraShelter). Next: tests/test_weather_composition.luau.
- [done] tools/test_weather_composition.luau written; running next.
- [done] test_weather_composition.luau: 100 checks pass (wind, compose priority, glare cap/fill floors, per-biome weather, 6 margins, controller lifecycle, server clock). Next: full suites, compile, scratch build.
- [done] verification: lune_compat --all all PASS (incl. test_weather_composition 100), tools/test_*.py all pass (test_campaign_regions flaked once on another lane's temp files, passes alone: 421), test_audiovisual.py 45, luau-compile --null clean on all 5 files, scratch build OK (l3.rbxlx, Wind/WeatherController unmapped until lead wires).

## WIRING FOR LEAD (I did not touch these files)
default.project.json
- Shared (next to "Overworld"): `"Wind": { "$path": "src/shared/Wind.luau" }`
- Controllers (next to "EnvironmentController"): `"WeatherController": { "$path": "src/client/Controllers/WeatherController.luau" }`
Bootstrap.client.luau
- `local Weather = require(controllers:WaitForChild("WeatherController", timeout) :: ModuleScript)`; before Environment.new: `local weather = Weather.new(state)`; `Environment.new(state, weather)`; per frame `weather:Update(frame)` before `environment:Update(frame)`; on teardown `weather:Destroy()`.
EnvironmentController (single Lighting owner): store `self.Weather = weather`; in Update after `key` is computed, before `if key == self.Key then return end`:
  local composed = if self.Weather then self.Weather:Profile(if boss ~= "" and alive then { Phase = self.Phase, Arena = arena } else nil) else nil
  if composed then self.Key = "Weather"; cancel tweens; tween every name/values of `composed` over 0.4 s (same loop as now); restore the default sky (skyFor nil); return end
FoliageWind (sole GlobalWind writer): take `weather`; in comfort() use `local w = weather and weather.Wind; local base = if w then Vector3.new(w.X, w.Y, w.Z) else self.BaseWind`, call comfort() when w changes (e.g. in Refresh every 0.5 s).
SoundscapeController / BossCloth: volume `Wind.ambience(weather.Wind or Wind.sample(false, Config.Workspace.GlobalWind))` and cloth vector from `weather.Wind`.
Roofs/cave ceilings must carry CollectionService tag `AsuraShelter` (WeatherController raycasts 60 studs up against tagged parts).

## STUDIO MUST VERIFY (lane 1)
Rain/snow/dust emitter look, slant with the ESE wind, rate and cost; dawn, dusk, midnight player-height captures (glare, fill, no black-out); lobby capture pair unchanged; shelter tag roofs actually suppress rain; fade at region margins; comfort/reduced motion; wind direction against terrain lee; weather off in a fight.

## Wind direction call (confirm)
ESE read meteorologically: wind FROM 112.5 deg, blowing WNW (matches the rain shadow). The lobby's {6,0,2} blows toward ESE, i.e. opposite. If the creator meant "blowing toward ESE", flip Wind.Prevailing.FromDegrees to 292.5.

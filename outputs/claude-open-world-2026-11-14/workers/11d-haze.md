# 11d - far-view haze (C3 fault F), source lane, no Studio

Files: src/shared/EnvironmentProfiles.luau, tools/test_weather_composition.luau. WeatherController.luau needed no change (it never writes Lighting or fog).

## Values (clear noon, Density / Haze / Offset 0.35; Color; Decay)
- Forest 0.05 / 0.4; (176,190,204); (92,106,122)
- GoldenRavine 0.05 / 0.5; (192,192,198); (110,110,118)
- AridBasin 0.035 / 0.4; (200,204,208); (118,120,124)
- Snowfields 0.05 / 0.4; (206,218,234); (120,134,158)
- MountainAscent 0.04 / 0.4; (176,184,198); (98,106,122)
Was 0.18-0.34 / 1.2-1.9, Offset 0.1, green-teal Color and dark-green Decay (= ambient). Lobby, combat and Unbound profiles untouched; glare cap, fill floors, Horizon (dawn/dusk) and margin blending untouched. Fog: Lighting.Fog* is never written by the client or composed profile; Atmosphere owns distance.

## Contrast estimate
exp(-d * Density * (1 + Haze/2) / 379), S fitted so the old Bellwood air gives 0.35 at 600 studs. New: 0.37-0.51 at 6,000; 0.25-0.40 at ~8,360 (glade to temple); 0.91-0.94 at 600 (depth cue kept). Threshold 0.3 at 6,000 (0.2 at the longest sight line). Model is an estimate: Studio is the arbiter.

## Tests (section 10 of test_weather_composition.luau, 239 pass)
Density <= 0.06, Haze <= 0.6, far contrast >= 0.3, near cue 0.8-0.95, Offset >= 0.3, blue-grey not teal, no fog fields, weather thicker than Clear in every region, lobby and combat atmospheres unchanged. lune_compat --all: no failures; luau-compile --null OK.

## Studio must capture (C4, summit temple from each region, Clear, noon and 14.5 h)
Offset direction (0.35) is the one assumption: confirm silhouettes get darker against the sky, not lighter. If not, set Offset back to ~0.1.
- Forest: Altar_MonasteryGate glade (-2200,63,-1400); Altar_BellTerrace (-3000,143,-2000); Altar_BambooShrine (-2600,223,-3600)
- GoldenRavine: Altar_RavineOverlook (-5550,303,-3150); ChainLift (-5950,293,-3180)
- AridBasin: Altar_BasinCistern (-8100,43,-2300); DuneRuin (-9500,53,-1400); CanyonNarrows (-9000,153,-4000)
- Snowfields: Altar_SnowRefuge (-3400,623,-6400); WhitePass (-5500,903,-6800); WatchpostRuins (-3500,823,-7300)
- MountainAscent: Altar_MountainRefuge (-7750,1003,-6500); CliffGalleries (-8300,823,-6400); ThousandSteps landmark (-7400,1300,-7300)
Target: SummitTemple (-7200,1650,-8100). Also one rain frame per region to confirm weather still thickens.

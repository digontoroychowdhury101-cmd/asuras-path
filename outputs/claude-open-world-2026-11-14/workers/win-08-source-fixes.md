# win-08 source fixes (Sonnet, light lane: luau/lune_compat only)
Plan: 1 weather honours Effects.reduced() (Reduced effects) + test; 2 snow soft sprite + dust tune + tests; 3 stair footing test for every region/flight then fix BiomeDressing; 4 verify_all.sh adds test_biome_dressing, lune_compat no longer silent-skips non-@lune tests.
Files: src/client/Controllers/WeatherController.luau, tools/test_weather_composition.luau, src/shared/BiomeDressing.luau, tools/test_biome_dressing.luau, tools/verify_all.sh, tools/lune_compat.py, this note.
- T1 done: weather Comfort = reducedMotion() or reduced() (EffectsPreference.reduced); +2 checks; lune 246 pass expected
- T2 done: Snow Texture smoke_main, Size .45->.6 Alpha .1->.15; Dust Size 2.2->2.8 Alpha .7->.55 (old comfort/translucency checks unchanged, still valid); +1 check; lune 247/0
- T3 test extended (stairs both ends, all regions): failed Ravine/Basin/Mtn (floats up to 19.5, buried to 22). Fix: BiomeDressing STAIR_FAMILY (shallower/steeper kit variants Ravine x3, Basin x2, Mtn_Stair_Low) + builder picks member that meets ground at high end (-1..+2) else drops the flight
- T3 done: Ravine hero min 70->55 (flights on flat/sheer ground dropped, intentional); Basin_Cistern_Stair base rise 1->0.4 + Mid 0.6
- T4 done: verify_all.sh runs test_biome_dressing (step 10); lune_compat now runs any test named on the CLI (was filtered out silently when no @lune), errors if none. FINAL: weather lune 244->247/0; biome luau+lune 19091->19045/0 (fewer stair parts); slice luau 989/0; luau-compile both ok. Not committed.

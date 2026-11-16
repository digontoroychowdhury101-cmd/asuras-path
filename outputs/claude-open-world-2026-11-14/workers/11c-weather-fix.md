# 11c weather fix (lane 5, source only)

Defects from workers/10e-studio.md: rain streaks invisible; dawn at 6.3 read like full day.

## src/shared/EnvironmentProfiles.luau
- New `Profiles.Horizon` (Fill 0.2, Sun 0.3, Exposure 0.12, Density 0.07, Haze 0.8), driven by the existing `dusk` factor (peaks at sunrise/sunset, continuous in sun height).
- `applyTime`: ambient/outdoor x(1-0.2 dusk), Brightness x(1-0.3 dusk), exposure -0.12 dusk, ShadowSoftness x(1-0.4 dusk), warmer ColorShift/fog colour/Decay/tint, fog density +0.07 dusk, haze +0.8 dusk. guard() unchanged (fill floors 44/72, glare caps).
- Forest numbers: noon brightness 2.0; 6.3 -> 1.39 (0.70x); 19.5 -> 1.30 (0.65x). Ambient/outdoor lum 6.3 about 0.74x noon; 19.5 about 0.58x noon (floors hold).

## src/client/Controllers/WeatherController.luau
- Rain: streak (VelocityParallel, Size 1.4 = Fall*0.02, Squash 2, Alpha 0.4, light blue-grey 170,190,215, LightEmission 0.15), Rate 420. Snow Size 0.45, Rate 110. Dust Alpha 0.7, Rate 100. Emit area 70x70.
- Budget 600 live particles (Rate*Life*intensity summed, scaled down when exceeded). Full: rain 462, snow 550, dust 400. Comfort x0.35: 162/192/140.
- Exposed `Controller.Kinds`, `Controller.Budget` for the test.

## tools/test_weather_composition.luau
- Section 9: particle size/rate/budget per comfort level, brightness <=0.8x and ambient <=0.85x noon at 6.3 and 19.5 for every region, floors + glare cap, warm/thicker dawn fog, smooth cycle, lobby profile unchanged. 159/0 pass; lune_compat --all 0 FAIL.

## Not verified
- luau-compile not installed here (lune load parses the files instead).
- Studio: Squash sign/stretch, streak look at player height, dawn 6.3 / dusk 19.5 captures, ShadowSoftness applied by EnvironmentController.

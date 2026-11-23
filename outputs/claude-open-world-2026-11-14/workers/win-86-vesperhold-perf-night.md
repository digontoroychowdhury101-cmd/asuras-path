# win-86: Vesperhold frame cost and night readability (Windows, 24 Nov 2026)

Creator notes: Vesperhold "incredibly laggy", 60 fps floor; night "just too dark"; wants fireflies and bioluminescence. Research: `win-86-research.md`.

## Vesperhold cost

Studio frame time is not usable on this PC: the unfocused window throttles Present (~37 ms). The figures below use `Stats.RenderGPUFrameTime` and the triangle counts from `RenderBreakdown.Opaque`.

| View (eye) | Opaque tris before | after | GPU ms before | after |
|---|---|---|---|---|
| Approach (-3220, 700, -6400) | 3.62M | 1.34M | 10.4 | 7.8 |
| Gate (-2930, 672, -6400) | 2.87M | 1.99M | ~10 | ~10 |

Cause:
- The kit's `__Crockets` and `__Tracery` subs were fading by their bounds. Those bounds span a whole spire or bay, so the subs never left the frame; they were 2.5M of the 3.7M approach triangles.
- `LocalTransparencyModifier = 1` only hides a mesh; the renderer still draws it.

Fix (`LandscapeBudget.luau`):
- Ornament subs now fade by their detail size: crockets at a radius of 2, tracery at 3.
- A fully faded mesh is set to `Transparency = 1`, which really drops it from the frame. It is restored when it comes back into range and on Destroy.
- Captures `win/vesp86` 04 and 05 match visually (the storm haze hides both ornament sets past that range).

Still open:
- At the gate the GPU cost is per-pixel PBR shading of the full-screen facade.
- 274 Persistent kit models keep 17.2M source triangles in client memory.
- The dark Massing box shows behind the meshes.
- Real phone profiling.

## Night
- **Moon fill:** raised to about 100 with +0.42 exposure. It stays under the dimmest noon sky fill (`EnvironmentProfiles`).
- **New ambience kinds:** Wisps (cold spirit lights over snow and the Ashen Stair) and Spores (teal bioluminescent specks rising off the Bellwood floor, which rain washes out). Both have LightEmission 1 and stay inside the particle budget.
- **Glowing mushrooms:** `Mushroom_*__Caps` dressing carries a GlowSpores emitter tagged `AsuraGlowCap`. It is lit after dusk within 160 studs of the camera only.
- **Qi aura:** one shadowless PointLight on the player root at night (range 26, brightness 0.85). At 1.1 it bleached a trunk in capture 09.
- **Captures `win/vesp86`:** 06 is the glade at midnight, 07 the canopy before the aura, 09 the canopy after it.

Verification:
- Lune: landscape_far 28, weather_composition 471, overworld_ambience 28 and slice_dressing 1380, all passing.
- verify_all exits 0.
- Development saved, v46.

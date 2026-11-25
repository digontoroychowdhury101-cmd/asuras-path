# mac-94: Vesperhold kit-mesh dropout, cause found (2026-11-25, Mac)

## Verdict

The dropout reported in win-88 does not come from mesh memory or from our code. It is engine view-distance culling. With graphics quality on Automatic and a low frame rate, Roblox drops the quality level, which shortens how far parts are drawn. The cut follows spatial chunks, so a straight row of identical pieces is clipped partway along.

The handoff proposed removing Persistent residency from 274 kit models. That would not fix this, and it was not done.

## Evidence (Studio Play, build digest 295/3927822/343383436, camera at (-3140, 700, -6400) looking +X)

1. **LTM is not the cause.** All 33 crown `Balustrade_20` pieces at y 840 have `LocalTransparencyModifier` 0 on Stone, Frost and Pinnacles. Crockets and Tracery are 1 by design (detail fade). The landscape tier was Detailed.
2. **Massing occludes the arcades** when the kit behind it is culled. With Massing hidden, the open arcade tiers appear (`captures/mac/vesp-dropout-2026-11-25/01` vs `02`).
3. **The crown was isolated** by hiding every other Vesperhold part. Only the middle span drew (`03`). The drawn edges sit on a 128-stud grid (Z -6656 to -6272), which marks a chunk boundary and rules out per-part distance.
4. **Ruled out:**
   - RenderFidelity Precise: no change.
   - Forcing a re-batch: no change.
   - Pulling 673 other kit models: only 38 MB freed, and the crown drew less.
   - A fresh clone placed in plain `workspace`: not drawn.
   - Plain neon test cubes at 400+ studs: not drawn (`04`).
   - Clouds off: no change.
5. **Confirmed.** Setting `settings().Rendering.QualityLevel = Level21` made every cube and the far terrain draw at once (`05`).

Studio on this MacBook runs at about 15 fps, so Automatic quality sits low. A real client that drops below its frame budget does the same.

## What fixes it

- **Frame time is the lever.** Every millisecond saved keeps Automatic quality, and so draw distance, higher. This is the 60 fps priority.
- **Fewer, larger draw units at range** (SLIM per section, or a hand-made HLOD shell). Chunk culling then removes whole sections cleanly, not mid-row. Research brief, 2026-11-25:
  - SLIM needs StreamingEnabled and a saved place, and works only on static models.
  - Toggling transparency between 0 and 1 forces costly re-batches, so LTM culling should stay small.
- Do not raise residency (Persistent) to fight this. It costs memory and does not change view distance.

## win-91 ornament shadows at the gate eye (-2930, 672, -6400), QualityLevel 21

| | Shadow tris | Shadow draws | Frame tris | Draw calls |
|---|---|---|---|---|
| win-91 (ornaments cast no shadow) | 3.29M | 207 | 6.68M | 516 |
| Ornaments casting (1,668 parts) | 8.50M | 517 | 11.88M | 826 |

- Opaque geometry is unchanged at 3.33M tris / 170 draws.
- On this Mac, `RenderGPUFrameTime` reads 0, and CPU frame time stayed about 5 ms both ways.
- The gate view still reads cleanly: gilded portal tracery, crockets and arcade tracery (`06`).
- Saved to Development 118614906972571 via Save to Roblox As > Overwrite. Never Publish.

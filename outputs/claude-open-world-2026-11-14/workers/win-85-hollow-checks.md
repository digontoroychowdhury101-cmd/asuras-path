# win-85: Bellwood Hollow fixes and checks (Windows, 2026-11-24)

Follows win-84. The creator asked for three fixes (the hall back wall, stair brightness and white textures on load) and for the remaining checks.

## Hall back wall: fixed
- **Cause.** `Bellwood_ColossalTemple__Soffit04_01_Part01` is a closed box, 212 × 85 × 303 studs, at the rear of the hall. Its hall-facing side ignores light from either side; a 6× test light 23 studs away and a light behind it both left it black. Giving it the lacquer surface changed nothing, so the problem is the mesh, not its paint. The real rear colonnade, with lattice screens and doors, stood hidden behind it (captures 01 and 02).
- **Fix.**
  - `Kit.place` takes `Omit` (a list of sub keys).
  - `LandmarkLayout` Basin.ColossalTemple omits that sub and adds two accents at the colonnade: (±30, 130, -128), range 50, brightness 2.6. The basin now holds 12 of its 12 budgeted lights.
  - The loader test pins the omit against the real registry, so a re-upload that renames the sub fails loudly.
  - Capture 03 is the built result.
- **Art follow-up (Mac).** Drop or re-normal that soffit box in the temple recipe, then remove the `Omit`.

## Stair brightness: explained, no code change
- **What it isn't.** All of these left the built stair unchanged:
  - the preview grade (ambient 175/182/186, exposure 0.45);
  - Brightness 1.8;
  - the preview's exact 18 client lights;
  - switching off every non-stair light (so it isn't light culling);
  - the original importer surface with metalness cleared (identical maps to the finish).
- **The cause.** With the stone surface removed, the same lights wash the treads white (capture 05), so the lights reach the treads. The stair stone colour map itself is dark.
- **Why the preview looked brighter.** Win-84's preview 04 was taken just after that session removed, re-added and edited the tread surfaces, so the textures were re-streaming. Capture 06 shows the same smooth warm treads during this Play's first seconds, before the stone texture arrives (07).
- **To brighten it:** lighten the stair stone albedo (Masonry05 and DarkStone05 colour maps) in the Mac recipe and re-upload. More light or grade does not change it.

## White textures on load: shorter, not gone
- **Change.** EnvironmentController preloads every Hollow temple and gate-tower map (`Layout.hollowMaps`, 702 maps) once the player is within `Cavern.Preload` = 1500 studs of the basin centre.
- **Result.** Held at 1,200 studs while the basin built, 672 of 702 maps finished downloading before arrival. On arrival the crown and upper tiers still showed white (capture 06), and everything was textured by about 15 s (capture 07). It was about 30 s before.
- **What remains.** The rest is the engine binding textures on first sight, which a download preload cannot remove.
- **Open.** 30 maps report Failure from PreloadAsync (Moss05, Crown52, Roots03, CrownShoots51 among them). Check whether they render live.

## Checks
- **Switchback (route 378–396).** On a fresh placement, the server MoveTo walk covered 18 points in 7 s with no stalls.
- **Frame time** (Studio Play, server in the same process, unfocused window):

  | View | HollowLights on (p50 / p95) | Off (p50 / p95) |
  |---|---|---|
  | Stair, 1736×824 | 47.1 / 54.1 ms | 46.1 / 49.1 ms |
  | Hollow, 1736×824 | 48.1 / 51.8 ms | 45.3 / 49.5 ms |
  | Stair, Galaxy A06 705×338 | 42.3 / 44.2 ms | 41.9 / 44.0 ms |
  | Hollow, Galaxy A06 705×338 | 44.0 / 46.9 ms | 42.8 / 44.9 ms |

  - Resolution barely matters, so the scene is CPU-bound here. HollowLights cost 1–3 ms, so cutting motes, veins or lights would not help phones.
  - The simulator changes the resolution, not the GPU, so these are not device numbers.
  - Memory: 3,332 MB, of which 1,132 MB is graphics.
- **Two clients.** Not run. This PC had 3.6 GB free with Studio in Edit, and a server plus two clients needs about 9 GB.
- **Console.**
  - One `OverworldService:722` script timeout at startup. It happened while the QA hold kept teleporting the player onto unwritten terrain at a heartbeat of 3.9 Hz; this batch didn't touch that code.
  - The `203785492` asset-type warning was already there before this batch.
- **verify_all.** It passed after `test_audiovisual` learned to load `LandmarkLayout`, which EnvironmentController now requires.
- **Studio.**
  - The Development place matches the build: 295 scripts, 3,915,188 bytes, digest 1670475327.
  - Saved as version 41. Never published.

## Captures (`captures/win/hollow85/`)
01 hall before · 02 soffit hidden, test lights · 03 hall built · 04 stair built · 05 stair untextured test · 06 arrival with preload, 0 s · 07 arrival, 15 s

# win-86: reference research for the world's look, loop and frame budget (Windows, 2026-11-24)

Creator direction, 24 Nov: hold 60 fps minimum (Vesperhold is "incredibly laggy"), add big elevation changes, fix darkness with glowing life (fireflies, bioluminescent plants), study the look and loop of "hero of the grand soul" and similar games, and make music and SFX with ElevenLabs. Two Sonnet agents did the web research. Their sources are cited inline. Lines marked *(judgement)* are starting values to tune in Studio, not documented limits.

## The reference game
"Hero of the grand soul" is most likely **Hero of The Grand Soul** on Roblox (roblox.com/games/5131623903, by Denvov Creations). It is a PvE soulslike "inspired by Elden Ring", set in the open world of Emora and told in chapters (7+). No art-direction source or gameplay video could be read, so the look notes below come from its comparables: Elden Ring, Ghost of Tsushima, Black Myth: Wukong, Genshin Impact and Deepwoken. **Question for the creator:** which two or three things about it do you want carried over?

## What the comparables do that we lack
- **Elevation over area.** Elden Ring's DLC added "a better sense of verticality" because the wide, flat base map felt thin (GamingBolt, PC Gamer). Distant structures pull the player between points of interest (Vice).
- **Guidance through the world, not the HUD.** Ghost of Tsushima uses guiding wind, foxes and golden birds. "Everything needed to move", and the wind is a cheap single-vector system (GDC 2021).
- **Each region has its own palette.** Liyue is warm Geo gold. Limgrave is gold and green mist. Caelid is red. Black Myth grades each chapter differently.
- **Small rewards are dense.** Genshin places a chest, puzzle or shrine about every minute of travel.

## Readable darkness
- **Value structure.** Keep a dark background, a mid-value play plane, and the brightest values on the path, goals and threats. Shadows go cool, highlights go warm.
- **Coloured fog.** Far terrain should be lighter and bluer than the midground, never black. Distance fog is "really, really key" to readability (Sable, GDC 2022).
- **Rim and moon light.** A cool directional light outlines silhouettes without lifting the shadow floor.
- **Emissive life as the light source.** Fireflies, glowing fungi, braziers and grace-style beacons concentrate brightness in small saturated spots.

## Roblox settings to start from
- **Lighting.**
  - Night Ambient about (30, 45, 80), ExposureCompensation +0.3 to +0.8 before raising ambient.
  - Atmosphere Density 0.3 to 0.4, Haze 1 to 2, with a teal colour.
  - Bloom 0.4 / 32 / threshold 1.8.
  - ColorCorrection contrast and saturation +0.1. *(judgement)*
  - Ambient lights enclosed spaces. OutdoorAmbient does not (Creator Docs, Lighting).
- **Real lights.** At most about 8 PointLights per view, shadows on 1 or 2 hero lights only, range of 20 or less, culled beyond about 80 studs. Future lighting's main cost is re-rendering shadows near moving objects (Roblox staff, DevForum). Fake every other glow with Neon or emissive maps.
- **Fireflies.** ParticleEmitter with LightEmission 1, LightInfluence 0, Rate 1 to 3, Lifetime 4 to 8 s, Size 0.15 to 0.4. Keep under 300 live particles per view. Set properties once, then toggle the emitter by distance. *(judgement)*
- **Terrain.** WriteVoxels at resolution 4 in 128 × 128-stud chunks, yielding every 1 or 2 chunks (about 4 ms). Carve path splines first and keep route slopes under 45°. *(judgement)*
- **Frame budget.** 16.67 ms per frame.
  - Baseline device: under 1,000 draw calls and 1M triangles in busy views.
  - Old phones: about 500 draw calls and 500k triangles (Creator Docs, Design for performance; DevForum).
  - A 1024 texture uses 4× the memory of a 512. Persistent models should be rare (Creator Docs, Streaming).

## How these map onto the work
1. Vesperhold lag. win-68 measured 8.8M rendered triangles and 65 ms frames on the pilgrim road. The castle body is `ModelStreamingMode.Persistent`, so all of its kit meshes (17.2M source triangles) stay on every client. Profile this first.
2. Elevation: raise the macro relief between regions, and carve routes before the noise.
3. Night: add fireflies and bioluminescent flora as the main fill, plus a cool rim moon and lighter teal far fog, all within the light budget.
4. Audio: a calm and combat pair of themes per region, with ambience loops and a discovery stinger (ElevenLabs).

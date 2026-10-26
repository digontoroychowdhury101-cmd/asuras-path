# Campaign terrain from GitHub sources — 26 October 2026

Bamboo Pass, Ash Colosseum, Celestial Pagoda and Sky Citadel were flat parts floating in a void. Now:

- **Natural boxes become smooth Terrain** (`CampaignTerrain.convert`): Grass, Rock, Snow, Ash and Basalt
  boxes 4+ studs thick are filled with voxels inset 0.6 studs under the top and 0.5 inside the sides;
  the original part stays as an invisible collider, so walkable surfaces and the reachability suite are unchanged.
- **Four PBR MaterialVariants from >1,000-star repos** (see `assets/CREDITS.md`) override terrain
  LeafyGrass/Rock/Ground/Basalt, which also re-skins the Monastery hills. The lobby uses only Water terrain.
- **Valley walls** (`CampaignTerrain.backdrop`): ridged-noise mountains outside each region's east/west
  bounds (8 studs past the bounds, beyond the Veils), tapering into saddles at region ends.
- **Built parts** (paths, stone, crypt, tile, timber, lacquer) now use the lobby's PBR variants.

Studio check (single client, Edit-injected sources, then `build.py`): screenshots in this folder. Footing probe and route walks: `FOOTING_WALK.md`.
Region build time rose to ~0.8 s at server start. Not done: human playtest, device FPS, Ash/Citadel lighting
(both are intentionally dark night profiles), Sunken Crypt (underground, no natural kinds).

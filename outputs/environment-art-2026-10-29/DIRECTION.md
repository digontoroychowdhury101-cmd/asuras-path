# Bamboo Pass benchmark — working direction

Extend [The Six Broken Vows](../art-direction-2026-10-25/ASURAS_PATH_VISUAL_DIRECTION.md): living vertical bamboo around a hard, weathered mountain route. Moss, old leaves and exposed roots connect stems to ground. Pale karst and frost identify elevation. Jade is restrained; crimson remains exceptional in Sanctuary.

## Composition contract

- Entry: a dense, irregular bamboo curtain frames the existing gate and readable path. Near culms establish scale; overlapping crowns make a continuous middle distance; karst breaks the skyline.
- Trail: vegetation grows in clumps with gaps between patches. Keep low near foliage out of the camera boom, signs and attack space. The route keeps its existing floor elevations.
- Crest: release the canopy to reveal the shrine and Baize approach. Frost gathers on exposed ledges and rocks; avoid flat white plates.
- Shrine: a quiet pocket of weathered timber, stone, moss and warm ritual light. Foliage frames the shelter without covering the altar.
- Arena and exit: the combat plane stays open. Bamboo/rock masses beyond the arena surround give depth; the moon gate remains legible from both directions.

## Small reference set

References guide original modeling and composition; no photographed or protected art is imported into the game.

| Reference | Design use |
|---|---|
| [Southern Sichuan Bamboo Sea — SCIO/Xinhua](https://english.scio.gov.cn/m/chinavoices/2025-12/05/content_118211927.html) | Real bamboo grove scale and layered canopy. |
| [Bamboo Sea Resort trail photograph](https://www.tripadvisor.com/Attraction_Review-g1409092-d1824623-Reviews-Bamboo_Sea_Resort-Jiang_an_County_Sichuan.html) | Path-edge moss, narrow clear route and dense vertical framing. Reference only; third-party photograph. |
| [South China Karst — UNESCO gallery](https://whc.unesco.org/en/list/1248/gallery/) | Uneven tower groups, vegetated lower slopes and atmospheric separation. Reference only; credited photographers retain rights. |

## Asset priorities after running baseline

1. Reuse and inspect the three uploaded bamboo culms. Build five deliberately different clump silhouettes (upright, broad fan, leaning, young, broken edge) only where their player-distance appearance supports it. Author improved geometry in a separate Blender collection/version if necessary.
2. Reuse uploaded Detail_Fern, scanned rocks and erosion pieces for near-ground transitions. Add original litter, root and shoot units if missing. Avoid giving deep shaded bamboo a uniform grass lawn.
3. Prototype one rooted foliage wind system using the shared spatial wind field, bounded nearby registrations, client-only movement, distance update rates and reduced-motion handling. Prove motion on a small slice before broad distribution.
4. Replace conspicuous primitive gate/shrine/moon-ring dressing using the existing original lobby/Han modules where appropriate. Preserve their documented separate art licenses.
5. Address terrain outlines and fixed snow plates after inspecting all eight baseline views. Preserve navigation geometry and boss floor height.

## Technical references checked 29 October 2026

- [Roblox model requirements](https://create.roblox.com/docs/parts/models): 20,000 triangles per mesh dependency. Export target remains ≤18,000 evaluated triangles per mesh; full asset totals are recorded separately.
- [Terrain grass animation](https://create.roblox.com/docs/parts/terrain#grass-animation): animated blades use Grass and Decoration, with motion controlled by GlobalWind. Imported meshes need their own supported animation.
- [Rodin balance API](https://docs.hyper3d.ai/en/api-specification/check-balance): read-only check returned 0 credits. No paid workload submitted.

This sheet is a working implementation guide, not visual acceptance. The screenshot-grounded defect list follows the running baseline.

# Han architecture kits — 26 October 2026 (Computer A)

The Celestial Pagoda's box towers, floating roof ring and unsupported rafters are replaced by real models.

## GitHub screening (repositories with 500+ stars)

25 broad searches plus direct tree scans. Only data files were fetched (COLLADA XML, glTF binaries,
PNG/JPEG, licence text) by pinned commit and Git blob hash; nothing from a repository was executed.

| Repository | Stars | Licence | Decision |
|---|---:|---|---|
| [0ad/0ad](https://github.com/0ad/0ad) | 2,827 | art CC BY-SA 3.0 | **Used** (owner approved the share-alike terms): 13 Han meshes + textures. The only 500+ star source of East Asian architecture found. |
| [HungryProton/scatter](https://github.com/HungryProton/scatter) | 3,017 | MIT | **Used**: pine, two boulders. |
| [TokisanGames/Terrain3D](https://github.com/TokisanGames/Terrain3D) | 4,435 | MIT | **Used**: three crag rocks. |
| [KhronosGroupArchives/glTF-Sample-Models](https://github.com/KhronosGroupArchives/glTF-Sample-Models) | 3,611 | per model | Test models, nothing on theme. |
| [mrdoob/three.js](https://github.com/mrdoob/three.js) | 116,960 | MIT code, mixed models | No ancient East Asian models (LittlestTokyo is modern, CC BY). |
| [Miziziziz/Retro3DGraphicsCollection](https://github.com/Miziziziz/Retro3DGraphicsCollection) | 2,272 | per pack | No model files in the tree (zipped packs). |
| [veloren/veloren](https://github.com/veloren/veloren) | 7,649 | GPL-3.0 | Voxel style; does not fit. |
| [KenneyNL starter kits](https://github.com/KenneyNL) | 1,006–1,495 | MIT | Modern city / platformer pieces. |
| [sparklinlabs/superpowers-asset-packs](https://github.com/sparklinlabs/superpowers-asset-packs) | 1,274 | CC0 | Already used; no fitting architecture. |
| BabylonJS/Assets, ToxSam/cc0-models-Polygonal-Mind | 166, 9 | CC BY / CC0 | Below the 500-star threshold. |

## Delivered

- **AsuraHanHD** (`tools/blender/han_hd.py`, original geometry from the lobby kit vocabulary and lobby PBR
  sets): HanPagodaHD 151,352 triangles in 25 MeshParts, HanGateHD 25,412 in 7; every MeshPart is one
  material and at most 18,000 triangles (cap enforced by splitting). Five storeys with lathed columns,
  dougong bracket sets, lattice windows, studded door, balconies, tiled curved eaves, corner bells and a
  nine-ring bronze spire; paifang with drum stones, plaque and three roofs.
- **AsuraHanKit** (`tools/blender/han_kit.py`, `tools/assets/dae_to_obj.py`): 19 pieces / 21,175 triangles —
  0 A.D. pagoda, temple, shrine, towers, walls, gate, house, bixie, pedestal, lantern, cauldron; scatter pine
  and boulders; Terrain3D crags. 0 A.D. specular -> roughness; its player-colour mask baked as crimson.
- Studio 3D Importer (Creator: Me) uploaded both; `tools/assets/extract_han_kits.py` verified 52 MeshParts with
  uploaded meshes and complete SurfaceAppearances and wrote `assets/models/AsuraHan*.rbxmx` (Rojo-mapped to
  ServerStorage). IDs: `assets/HAN_KITS_UPLOADED.json`.
- Pagoda region: four HanPagodaHD on terrain rock pillars, HanGateHD over the cloud stair, bixie guardians,
  lanterns, pines and crags; lobby-kit columns/brackets dress the hall columns and Han watchtowers dress the
  gate towers (layout boxes kept as invisible colliders); rock massifs under the gorge, forecourt, hall and
  dawn terrace. Floating roof ring and 300-stud rafters removed; the great bell got posts.

## Verification (seeded Studio diagnostic, single client)

Studio digest matched the build; console clean; all kit models spawned (no fallback). Terrain under Wu's arena:
highest surface −2.0, 0 cells at or above the arena floor. Footing probe unchanged for every walked floor.
Screenshots: `pagoda_gate.jpg`, `pagoda_aerial.jpg`, `pagoda_close.jpg`; Blender sheets in `assets/build/han_hd/`
and `assets/build/han_kit/`. Not checked: device frame rate with four 151k-triangle pagodas (Roblox instances
identical meshes and LODs them, but this is unmeasured), human play, other regions (kit not yet placed there).

## Bamboo Pass and Sky Citadel — 28 October 2026

A Studio probe (every visible part > 6 studs with nothing within 4 studs under its base) found real
floating primitives only in the Citadel: six box towers with roofs, four glass cloud-sea sheets, the
First Gate Landing and Last Bastion slabs, both stairs and the bridge piers / dragon's perch undersides.
Bamboo Pass had none (only sunk-in bases and bamboo canopies were flagged).

- **Sky Citadel**: one rock peak of CampaignTerrain massifs under the saddle head and stair ridge,
  Heaven's Stair spine, landing, bastion, summit and perch (all tops under the platforms they carry;
  the bridge chasm stays open), pillars under the bridge piers. Han great/wall towers on pillars replace
  the box towers; two HanPagodaHD flank the bastion; HanGateHD at the saddle head; Han watchtowers dress
  the gate towers (boxes kept as invisible colliders); bixies and lanterns at the Wyrm's gate; the
  glass cloud sheets became mist.
- **Bamboo Pass**: two full-scale HanPagodaHD on the valley walls, each on a level rock terrace; shrine
  lanterns and incense cauldron; bixies at Baize's arena mouth; pines and crags on the frost ridge.
- **Pagoda**: corner pagodas, gate and bixies now face the path (they had faced away).

Placement heights come from `CampaignTerrain.backdropHeight` and the layout boxes, because terrain filled
in the same frame has no collision yet. Seating check: every pillar/terrace base is 0–2 studs into rock;
the worst Bamboo plinth corner is 0.6 above the slope. Footing probe unchanged in every region.
Screenshots: `regions/`. Not checked: device frame rate, human play.

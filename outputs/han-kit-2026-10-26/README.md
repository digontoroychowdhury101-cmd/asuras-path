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

## Frame time — 28 October 2026 (Computer A, Windows laptop on AC, Studio foreground)

`tools/qa/RegionFrameTime.luau` (Client, during Play): three fixed cameras per region, 240 frames each,
then the same cameras with every kit model hidden on the client. Raw output: `frame_time_2026-10-28.txt`.

- Wall-clock frames were exactly 41.7 ms (24 fps) in every view, kits shown or hidden: Studio on this
  machine is frame-capped (UserGameSettings.FramerateCap is not script-readable; check Studio Settings ->
  Rendering and any GPU-driver frame limit), so wall time cannot show the models' cost here.
- GPU time per frame (`Stats.RenderGPUFrameTime`): 7.4–13.2 ms everywhere; worst is the Sky Citadel bastion
  view with both HD pagodas close (13.2 ms), still under the 16.7 ms a 60 fps frame allows on this GPU.
- Kits shown vs hidden differed by -3 to +3 ms with no consistent sign (idle-clocked GPU under the cap), so the
  kits' GPU cost is below this method's ~2–3 ms resolution. CPU render cost is not separable under the cap.
- Not measured: phones/tablets, an uncapped run, multiplayer.

### The 24 fps cap — investigation (28 October 2026)

It is a time-based limiter on this machine, not load and not vsync:
- Hiding 11,567 of 11,998 workspace parts on the client left Play at 24.0 fps (renderCPU stays 40.7 ms = waiting).
- Studio held window focus for 25/26 and 71/71 samples during runs and Play stayed at 24.0 fps.
- The panel runs at 60 Hz (Intel UHD scan-out, RTX 4050 renders; `nvidia-smi` lists both Studio processes),
  and 60 Hz vsync can only give 60/30/20/15, never 24.
- Ruled out: Roblox `FramerateCap` = -1 in GlobalBasicSettings (player and Studio), no ClientAppSettings FFlags,
  FrameRateManager Automatic, Process Lasso (no Roblox rules; cannot cap fps), AC power on a high-performance plan.
- Remaining: the NVIDIA driver profile (a built-in `robloxstudiobeta` profile exists; its values are encoded) — check
  NVIDIA App > Graphics > Global and Program settings > Roblox Studio > Max Frame Rate — or Studio-internal throttling.

### The 24 fps cap — second pass (28 October 2026, 22:30)

Now ruled out by direct reads or live tests:
- NVIDIA: the driver database (read-only, via `nvapi64`) has a global Max Frame Rate of 144. The Roblox Studio
  profile has no limiter, only its Optimus GPU choice.
- Roblox: in-game Maximum Frame Rate was Default (60). It is now set to 240 and Play still ran at 24.
  Frame Rate Manager Off and quality level 1 both left about 20.5 fps.
- Studio was the active window, and its render throttle had been released since 22:29 local time.
- No frame-rate flags at 24, no local flag overrides, and no recording running.
- The only third-party DLLs in Studio are Nahimic (audio) and Defender; there are no overlay hooks.
- No power throttling; the Windows timer runs at 1 ms.
- The project: nothing in `src/`, `default.project.json` or the place sets a frame rate. Working on the Mac first doesn't matter here.

What the measurements show:
- Heartbeat (client and server) runs at 24, matching rendering. The whole Studio frame loop is paced.
- Studio uses 0.56 CPU cores; the NVIDIA 3D engine is about 10% busy and Intel DWM about 12%.
- renderCPU of about 40 ms is spent waiting while showing each frame, not computing.

Display: 60 Hz now, and the panel supports 144 Hz (Settings > Display > Advanced display). The
NVIDIA-render / Intel-scan-out path plus Studio's several panel swapchains is the remaining suspect.
- Next test, done by the user: set 144 Hz, then rerun `tools/qa/RegionFrameTime.luau`. If Play rises toward 58 fps,
  frame display through the Intel path is the cap.
- If not, set NVIDIA App > Program settings > Roblox Studio > Vertical sync to Off.

### The 24 fps cap — 144 Hz test (28 October 2026, 22:50)

- The display is now 144 Hz (Windows composites at 144.0 Hz). Play still runs at exactly 24.0 fps, with Heartbeat at 24.4.
  Refresh rate is ruled out.
- Edit mode, looking at sky: frames are evenly spaced at 55.5 ms (18 fps); the 3–4 s average is 10–12 fps.
- With every Studio connection closed (the second Studio window and StudioMCP), Edit still runs at 11.9 fps, Heartbeat 18.5.
  The result was read from Studio's log. The measuring tools are not the cause.
- Left to test (both are system settings, so the user changes them):
  - NVIDIA App > Program settings > Roblox Studio > Vertical sync Off.
  - Windows Graphics settings > Roblox Studio > Power saving (Intel), to remove the NVIDIA-to-Intel frame hand-off.

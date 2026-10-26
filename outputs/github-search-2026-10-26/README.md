# GitHub search, imports and Studio delivery — 26 October 2026

This pass screened **149 candidates** from **24 broad GitHub searches plus targeted follow-ups**.
146 candidate URLs resolved; 135 repositories had more than 1,000 stars when checked. There are
83 project-specific decisions, including exclusions. The remaining hits are discovery-only metadata,
not recommendations. This is a broad, finite survey rather than a claim to have searched all GitHub.

- Machine-readable evidence: `assets/GITHUB_RESEARCH.json`.
- Sortable catalogue: `repositories.csv` in this folder.
- Earlier source integration: `docs/GITHUB_REUSE.md`.

## Delivered work

| Repository | Checked stars | Delivered result |
|---|---:|---|
| [FastNoiseLite](https://github.com/Auburn/FastNoiseLite) | 3,534 | Monastery upper-cliff height bake, already integrated. |
| [Effekseer](https://github.com/effekseer/Effekseer) | 1,812 | Easing port; seven uploaded texture variants verified. Five are active in parries, Celestial beams and Blazing Sun. |
| [Godot demo projects](https://github.com/godotengine/godot-demo-projects) | 9,709 | Two CC0 physical impacts uploaded, verified and used for unarmed/heavy contacts and shockwaves. |
| [Superpowers asset packs](https://github.com/sparklinlabs/superpowers-asset-packs) | 1,274 | Nine CC0 animation-source files downloaded; eight CC0 fantasy sounds uploaded and verified. Two whooshes are active on missed swings; five cues are an audition bank, and the long ambience is pending Roblox requester approval. |
| [glTF Transform](https://github.com/donmccurdy/glTF-Transform) | 1,994 | Pinned MIT offline GLB pipeline with material/texture round-trip checks. |
| [meshoptimizer](https://github.com/zeux/meshoptimizer) | 8,629 | Pinned MIT mesh-index optimization and optional LOD generation. |

All imported files have source commits, Git blob identities and SHA-256 records. CC0 records and
full MIT notices are preserved alongside the imports. Code, assets, model weights and datasets were
considered separately; a repository's code license is not permission to copy unrelated game art.

## Direct Studio delivery

`ReplicatedStorage.AsurasPath.GithubAssets` is a browsable library of **16 playable templates**: seven Decals
and nine Sounds. It is mapped from `assets/models/AsuraGithubMedia.rbxmx`, so rebuilding/reopening the
project retains it. Sounds do not autoplay. `tools/assets/build_github_library.py` regenerates the
library from `assets/GITHUB_UPLOADED.json`.

Studio MCP updated the selected GitHub presentation modules directly in Edit mode. All seven image
variants and nine registered sounds passed loading checks. The long forest ambience initially returned
preload success but failed live sound loading with requester-approval errors, so it is quarantined
in the manifest and omitted from the registry and library. This verifies asset
loading in the connected Studio session, not published-experience permissions, listening quality,
visual mix or a hardware performance claim.

The two impact sounds are active on physical contacts. The short Superpowers whooshes replace the
long ambient-wind sample on missed swings. Celestial line spells now use the verified horizontal
lightning strip. Existing owned audio and texture slots remain available.

Creator Hub evidence: `audio-upload.png` and `audio-library-upload.png` in this folder. Uploads were
made to the existing Sheashing123 account with the user's authorization; no permissions changed.

## Animation sources

The CC0 Superpowers pack contains these authored animation sources:

| Source | Sampled duration |
|---|---:|
| Bind pose | Static |
| Fight pose | 2.042 s |
| Idle | 2.042 s |
| Jump | 1.250 s |
| Projection | 0.792 s |
| Punch | 0.917 s |
| Roll | 0.750 s |
| Run | 0.667 s |
| Walk | 1.000 s |

The original Collada files are under `assets/github/superpowers/3d-character/character/animation/`.
`animation-source-audit.json` records their channels, joints, source axis and sampled times.
They **still require R15 retargeting, format conversion, authored-track upload and visual checks**.
They are not represented as uploaded Roblox animations or enabled boss tracks.

## Geometry pipeline

`tools/assets/mesh_pipeline/` uses glTF Transform 4.5.1 and meshoptimizer 1.3.0, pinned by the lockfile.
Its default pass preserves triangle count and bounds. Simplification is explicit, writes a new file,
locks borders and checks material/skin/animation counts and embedded texture payloads.
It does not introduce Draco, meshopt-compressed buffers, quantization or KTX textures.

| Guardian lion variant | Triangles | Vertices | Bytes |
|---|---:|---:|---:|
| Existing source | 17,819 | 16,656 | 2,187,788 |
| Lossless prepared copy | 17,819 | 16,656 | 2,187,760 |
| LOD1 | 8,907 | 10,286 | 1,930,448 |

The lossless copy's byte saving is negligible; its purpose is validated layout preparation.
LOD1 removes about half the triangles and reduces source bytes by about 12%. It remains a candidate
asset in `assets/github/optimized/`; it has not replaced the uploaded production lion. Blender
comparison views are stored here. Rendering and triangle counts do not establish in-game FPS gains.

## Strongest next candidates

| Area | Repositories and checked stars | Concrete project use / remaining work |
|---|---|---|
| Environment kits | [Infinigen](https://github.com/princeton-vl/infinigen) 7,360; [building_tools](https://github.com/ranjian0/building_tools) 1,511 | Generate bounded rock/vegetation and monastery architecture kits offline; art direction and export QA still needed. |
| Materials | [Material Maker](https://github.com/RodZill4/material-maker) 6,022 | Bake moss, eroded stone, timber and magical masks into Roblox-supported maps. Check sample-material terms separately. |
| Animation tooling | [ozz-animation](https://github.com/guillaumeblanc/ozz-animation) 2,976; [Assimp](https://github.com/assimp/assimp) 13,283 | Sampling/conversion/optimization support for a dedicated R15 retargeting pipeline; native runtimes cannot run in Luau. |
| Terrain authoring | [Terrain3D](https://github.com/TokisanGames/Terrain3D) 4,431; [heightmap plugin](https://github.com/Zylann/godot_heightmap_plugin) 2,284; [TerraForge3D](https://github.com/Jaysmito101/TerraForge3D) 1,252 | Export heightfields/material masks; preserve the existing authored traversable routes. |
| Camera/routes | [Path-Creator](https://github.com/SebLague/Path-Creator) 2,099; [ProceduralToolkit](https://github.com/Syomus/ProceduralToolkit) 2,909 | Selective spline and geometry ports; Unity runtime components do not import directly. |
| Campaign maps | [mewo2/terrain](https://github.com/mewo2/terrain) 3,043; [DungeonTemplateLibrary](https://github.com/AsPJT/DungeonTemplateLibrary) 1,464 | Fantasy overview maps and optional crypt-layout authoring. |
| Navigation QA | [Recast](https://github.com/recastnavigation/recastnavigation) 7,983; [EasyStar](https://github.com/prettymuchbryce/easystarjs) 1,932 | Offline route-validation ideas; do not replace Roblox's runtime pathfinding without a measured need. |
| Source tooling | [StyLua](https://github.com/JohnnyMorganz/StyLua) 2,322; [Rojo](https://github.com/rojo-rbx/rojo) 1,821; [Luau](https://github.com/luau-lang/luau) 6,029 | Formatting and existing build/compiler improvements. No mass reformat was performed. |
| 3D generation | [TRELLIS.2](https://github.com/microsoft/TRELLIS.2) 12,459 | Already used by the project's existing reconstruction pipeline; retain reference-image rights records. |

## Exclusions that matter

- AI4AnimationPy's verified license is CC-BY-NC-4.0; no code or datasets were imported.
- HY-Motion uses a restricted Tencent community license; no weights were downloaded or run.
- Spine requires editor licensing; it was not treated as freely reusable open source.
- Genshin asset dumps were excluded: a repository license does not grant the game's art rights.
- Knit, Roact, React Lua, Wally, Lune, Selene and luau-lsp were below the user's star threshold at
  this check. They were not added as new reuse candidates.
- Client unlockers, exploit collections, unrelated robotics tools and unrelated search hits were
  excluded or retained as discovery-only records. Popularity alone was not treated as project fit.

## Reproduce

```sh
python3 tools/assets/fetch_github_assets.py --manifest assets/GITHUB_SUPERPOWERS.json
python3 tools/assets/prepare_github_media.py --manifest assets/GITHUB_SUPERPOWERS.json --output assets/github/superpowers/ready
python3 tools/assets/build_github_library.py
python3 tools/test_github_reuse.py
bash tools/verify_all.sh
python3 tools/build.py
```

Media preparation requires Pillow and NumPy; standard project verification does not. See the mesh
pipeline README for its separate package install and optimization commands. Do not put a generated
model into production until its Studio import, appearance and actual device performance are checked.

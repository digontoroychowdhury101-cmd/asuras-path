# Vesperhold third-party sources

## Tooling: blender-skills (not redistributed)
- Repo: https://github.com/kevinbadi/blender-skills, pinned commit **b2f0f816d320b56ae86d52597a35284e0e6cc929**,
  cloned at `work/third_party/blender-skills` (gitignored), installed as user skills in `~/.claude/skills/` (16 skills).
- **No licence file in the repo.** Used locally as a tool only; none of its files are committed to this repository.
- Used: `polyhaven-texture-apply` (search + download + apply, 8 textures), `polyhaven-material-swap` (stone candidate
  renders, `outputs/vesperhold/polyhaven-swap/`). Not used: `image-to-3d`, `multi-image-to-3d` (Meshy; creator: "No Meshy,
  free parts only"; no credits spent).
- Transport (2026-11-19, lead): the skills speak the ahujasid blender-mcp socket protocol (`{"type","params"}` JSON on
  127.0.0.1:9876). This Mac's addon `~/Library/Application Support/Blender/5.2/scripts/addons/blender_mcp.py` is
  "MCP for Blender" v1.8 by Siddharth Ahuja (same lineage). Blender 5.2.2 was started in GUI mode with the addon server on
  9876 and `scene.blendermcp_use_polyhaven = True` (the server does not run under `-b`). Evidence: the skill's
  `download_polyhaven_asset` and `set_texture` calls succeeded for all 8 textures. One mismatch: the skill's `--search`
  sends `categories`, the v1.8 addon expects `category`/`query` ("unexpected keyword argument 'categories'"); searches were
  sent with `query` over the same socket instead. Models: the addon only offers `.blend` for Poly Haven models.

## CC0 assets from Poly Haven (https://polyhaven.com, licence CC0 1.0, no attribution required)
Downloaded 2026-11-19 at 2k (2048 x 2048 JPEG maps; models 2k .blend re-exported to GLB) into
`assets/source/vesperhold/polyhaven/` (gitignored; preserved on the asset snapshot branch). Re-fetch: same IDs at 2k.

| Asset ID | Type | Used as | Maps | Authors (Poly Haven) |
|---|---|---|---|---|
| castle_wall_slates | texture | Vesp_Soot (main black ashlar) | Diffuse, nor_gl, Rough, Displacement | Poly Haven |
| medieval_blocks_03 | texture | Vesp_Charcoal (tracery, pinnacles, dressings) | Diffuse, nor_gl, Rough, Displacement | Poly Haven |
| rock_04 | texture | Vesp_Weathered (statues, figures) | Diffuse, nor_gl, Rough, Displacement | Poly Haven |
| roof_slates_02 | texture | Vesp_Slate (roofs, spire cladding) | Diffuse, nor_gl, Rough, Displacement | Poly Haven |
| metal_plate_02 | texture | Vesp_Iron | Diffuse, nor_gl, Rough, Metal, Displacement | Poly Haven |
| bark_willow_02 | texture | Vesp_DeadBark (withered trees) | Diffuse, nor_gl, Rough, Displacement | Poly Haven |
| snow_02 | texture | Vesp_Frost (ledge frost) | Diffuse, nor_gl, Rough, Displacement | Poly Haven |
| dark_rock | texture | Vesp_Rock (crags, plinth rock, rubble) | Diffuse, nor_gl, Rough, Displacement | Poly Haven |
| gothic_statue | model, 27,739 tris | candidate niche/graveyard statue | 2k | Benny Weimer |
| dead_tree_trunk | model, 101,802 tris | fallen log source | 2k | Rob Tuytel |
| dead_tree_trunk_02 | model, 83,128 tris | fallen log source | 2k | Jenelle van Heerden, Rico Cilliers |
| tree_stump_01 | model, 41,046 tris | stump source | 2k | Rob Tuytel |

Tone mapping to the castle palette: `tools/blender/vesperhold/vesp_polyhaven.py` (desaturate, value targets from mac-40,
grime runs, matte roughness lift). Set `VESP_PROCEDURAL=1` to fall back to the old procedural maps.

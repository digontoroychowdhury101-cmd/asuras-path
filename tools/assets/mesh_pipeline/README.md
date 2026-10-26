# Offline Roblox mesh preparation

Uses [glTF Transform](https://github.com/donmccurdy/glTF-Transform) 4.5.1 and
[meshoptimizer](https://github.com/zeux/meshoptimizer) 1.3.0, both MIT. Notices are in `licenses/`.
Dependencies are pinned in `package.json` and `pnpm-lock.yaml`; `node_modules` is ignored.

```sh
pnpm install --dir tools/assets/mesh_pipeline --ignore-scripts
node tools/assets/mesh_pipeline/optimize.mjs INPUT.glb NEW-output.glb
node tools/assets/mesh_pipeline/optimize.mjs INPUT.glb NEW-lod.glb --ratio=0.5 --error=0.005
```

The default preserves triangle count and local position bounds, welds identical attribute tuples,
deduplicates accessors/textures and reorders indices for vertex-cache locality. Materials, skins,
animation counts and embedded texture bytes are checked across the write/read round trip.
The tool refuses existing output files. Simplification is opt-in and lossy; borders are locked.
Output stays an ordinary GLB: no Draco, meshopt compression, quantization or KTX textures are added.

Verified on the project's original `assets/models/Asuraguardianlion.glb`:

| Variant | Triangles | Vertices | Bytes |
|---|---:|---:|---:|
| Source | 17,819 | 16,656 | 2,187,788 |
| Lossless preparation | 17,819 | 16,656 | 2,187,760 |
| LOD1, ratio 0.5 / error 0.005 | 8,907 | 10,286 | 1,930,448 |

The LOD copy and report are in `assets/github/optimized/`. The production uploaded lion is unchanged.
Blender previews are in `outputs/github-search-2026-10-26/`; visual approval and a Studio 3D import are
still needed before assigning the LOD to production scenery. Triangle and byte reductions do not
establish a measured frame-rate improvement.

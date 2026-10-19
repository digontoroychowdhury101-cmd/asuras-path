# Uploaded Roblox asset IDs

Uploaded 2026-10-19 via Studio 3D Importer (Creator: Me) from `assets/build/*.glb`.
The Rojo-owned copy lives in `assets/models/AsuraAssets.rbxm` (mapped to `ServerStorage.AsuraAssets`).

| Model | MeshPart | MeshId | SurfaceAppearance (Color / Normal / Roughness / Metalness) |
|---|---|---|---|
| AsuraColossusStatue | Plane | 129686277632150 | 102568692017145 / 84210454203890 / 140528737295050 / 131789440418621 |
| AsuraIronGate | iron_gate_01_right_door | 83019889922001 | 97374784142437 / 127669019703202 / 115257626046759 / 130890861230712 |
| AsuraDeadTrunk | fallen_log_5m_PROXY.002 | 72082952604136 | 103278282137922 / 121334908599331 / 100711174339712 / 125819066547895 |
| AsuraRoots | fgt_02_rep.001 | 101981203948515 | 128208407391331 / 132647085814431 / 116611612863005 / 80998998366059 |
| AsuraRoots | fgt_01.001 | 128332031002584 | 139842784818646 / 75759511497970 / 122359992555222 / 88730331781199 |

Native import sizes are in metres-as-studs (statue ~1.7 studs); `SanctuaryService` scales each on mount.

## Pending upload — Veiled Ascetic

Once the AI sculpt is ingested (`assets/VEILED_TITAN_PROMPTS.md`), import `assets/build/veiled_titan/veiled_titan.glb` with the 3D Importer, rename the Model to
**`AsuraVeiledTitan`**, put it in `ServerStorage.AsuraAssets` and re-export `assets/models/AsuraAssets.rbxm`.
`SanctuaryDressing` picks it up automatically (falls back to `AsuraColossusStatue` until then).

| MeshPart | MeshId | SurfaceAppearance (Color / Normal / Roughness / Metalness) |
|---|---|---|
| Titan_Figure_1 | _pending_ | _pending_ |
| Titan_Figure_2 | _pending_ | _pending_ |
| Titan_Canopy | _pending_ | _pending_ |
| Titan_Leaves | _pending_ | _pending_ (alpha: Color only) |

| Decal | File | AssetId → paste into `SanctuaryLeaves.luau` |
|---|---|---|
| Crimson leaf (particle) | `assets/build/veiled_titan/leaves/crimson_leaf.png` | `LEAF_TEXTURE` = _pending_ |
| Fallen-leaf scatter | `assets/build/veiled_titan/leaves/leaf_scatter.png` | `SCATTER_TEXTURE` = _pending_ |

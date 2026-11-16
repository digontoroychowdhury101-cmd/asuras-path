# win-15: real mesh templates via InsertService:LoadAsset
- kit_registry.py: every sub entry now has `Asset = "rbxassetid://N"` (the piece's modelAssets.assetId; required, validated, never invented). Regenerated Slice (31 subs), Bellwood (161), BellwoodFar (12), Hero (18).
- SliceDressingService: meshTemplate loads the model once per asset (pcall, cached, warn once, never parented), clones the MeshPart matching MeshId (fallback name). No SurfaceAppearance/MeshId writes. Hook: Service.LoadModel(assetId) replaces MakeMesh.
- Tests: test_kit_registry 12 OK; test_slice_dressing 1347 passed (lune_compat), 1320 plain Luau.
- Risk: LoadAsset in live servers needs assets owned by the experience owner/creator; unverified in Studio (light lane).

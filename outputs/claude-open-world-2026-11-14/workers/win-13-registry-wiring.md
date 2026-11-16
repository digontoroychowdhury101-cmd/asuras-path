# win-13 registry wiring
Files: tools/assets/kit_registry.py, tools/test_kit_registry.py, src/shared/{Slice,Bellwood,BellwoodFar,Hero}KitRegistry.luau (generated), src/shared/SliceDressing.luau, tools/test_slice_dressing.luau.
Validator: extra MetalnessMap allowed (valid ID); map IDs may repeat (Roblox dedupes images); MeshId stays valid + unique; a piece with every map empty (far trees, no SurfaceAppearance) is accepted; otherwise every manifest-listed map is required and any other unlisted map is refused.
Tests: test_kit_registry 11 pass (4 new); test_slice_dressing 1344 pass under lune_compat (1320 plain Luau).
Generated: slice 16 pieces/31 subs, bellwood 74/161, bellwood_far 6/12, hero 5/18. All compile.
SliceDressing: Registry = merge of the four modules (pcall-require, absent = skipped). Service unchanged (already generic).
GAP: no registry entry has `center` (importer centres not recorded). The service builds a piece only if every sub has a centre or the piece has ONE sub; 36 of 101 single-sub pieces resolve (Size/2 up), multi-sub ones (trees, pavilion, tower, gate) stay placeholders until `center` is added to assets/*_UPLOADED.json by a Studio read-back.
Lead: map the four modules next to SliceDressing in default.project.json.

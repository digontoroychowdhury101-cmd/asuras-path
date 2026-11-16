# mac-08 kit registry generator (lane R, source/tools only)

Plan: (1) tools/assets/kit_registry.py: validate assets/<KIT>_UPLOADED.json against the pack upload_manifest.json, write src/shared/<Module>.luau; `--check` validates only. (2) tools/test_kit_registry.py with temp-dir fixtures (fake IDs only in the test). No registry file with IDs is created; no src/ edits; verify_all not edited (lists tests by hand).

Files: NEW tools/assets/kit_registry.py, NEW tools/test_kit_registry.py, this note.

Checkpoints:
- [ ] kit_registry.py written
- [ ] tests pass

- [x] tools/assets/kit_registry.py written (kits: slice, bellwood_veg/built_a/built_b, bellwood_far, hero, amberfall, saltreach, frostmere, ashen)
- [x] tools/test_kit_registry.py: 7 tests pass (valid write + luau-compile --null, check-only, missing sub, bad ID, duplicate/unknown sub, Far keys, missing map). Real `slice --check` correctly fails: no JSON yet.

## Shape
JSON: `{"pieces":{Piece:{Piece__Sub:{MeshId,ColorMap,NormalMap,RoughnessMap[,MetalnessMap],center?[x,y,z],operations?{field:opId}}}}}`; IDs `rbxassetid://N` (6-20 digits). Maps required = those the manifest material declares (far = ColorMap only); undeclared maps refused. MeshId unique per sub; a map ID may repeat only within one material+kind. `operations` validated, not emitted.
Module: `return { ["Piece"] = { ["Piece__Sub"] = { MeshId=..., maps..., center={x,y,z} } } }` at src/shared/<Module>.luau (siblings of consumers).

# mac-54 Vesperhold loader + atmosphere (worker, Sonnet) - running log
Status 2026-11-19: A, D done and green on massing/slice/biome/kit_registry. B in loader. C and E in progress (see bottom).
Done so far (uncommitted):
- tools/assets/kit_registry.py: "vesperhold" kit (kit/props/trees manifests, one assets/VESPERHOLD_KIT_UPLOADED.json, absent = empty module); 3 new python tests.
- src/shared/VesperholdKitRegistry.luau (empty, generated), default.project.json entries, SliceDressing.RegistryModules += VesperholdKitRegistry.
- src/server/Services/VesperholdKit.luau: has/resolve/place (LoadAsset once, clone, per-axis scale, PrimaryPart core sub, collision per sub role, Neon+PointLight for Glass/Flame).
- GothicCitadel/GothicMarch: kit mesh replaces stand-in (and Viaduct_Bay arches, Part snag -> Thorn_Twisted) when registry has the piece; stand-ins remain the fallback.
- VesperholdLayout.Piece = manifest sizes (w=x,h=z,d=y), hardcoded divisors now read Piece.
- BiomeDressing: Snow_Trail_Stake (red-brown 14-stud timber pole, colour 150,62,42) dropped where vesperholdWeight>0: this is the stray red post of view 01.

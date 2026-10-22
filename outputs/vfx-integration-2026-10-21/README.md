# VFX integration evidence — 21 October 2026

The working build is `../AsurasPath.rbxlx`. Read `../../docs/PROJECT_VERSIONS.md` for the version explanation, integration boundary, remaining visual acceptance and rollback.

- `source-export/`: exact original three VFX sources and provenance hashes; none runs in the main game.
- `backups/`: exact pre-integration client bootstrap, Rojo project and saved main place.
- `existing-build-inventory.json`: script counts and hashes of historical local builds.
- `local-regressions.log`: successful consolidated verifier before the final lookup/routing refinements; affected files were checked again afterward.
- `engine-check-results.json`: 194 passed checks in a real Studio client on detached instances with fake entity/UI state. No live player/profile was altered.
- `engine-check-initial-failure.json`: initial snapshot-family lookup failure, fixed before the 194-check pass.
- `engine-check-code.luau`: refreshed diagnostic fixture, including final ownership guards; requires a Studio Client context. Its final two ownership assertions await a new connected session. Do not install this fixture as a normal game script.
- `integration-manifest.json`: source/build identity, exact code scope and evidence limits.

Final owner routing is additionally tested by `python3 tools/lune_compat.py tools/test_sanguine_dispatch.luau` (30 passed). Normal visible gameplay, sustained performance and device QA remain open. The F01 screen capture was unusable for appearance approval. The cloud VFX experience and all historical builds were preserved; nothing was published.

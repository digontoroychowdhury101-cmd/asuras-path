# mac-14 lane R2-1: protected property digest (read-only cloud)
Plan: 1 read notes (done); 2 cloud identity + SourceDigest; 3 write tools/qa/ProtectedDigest.luau; 4 run in cloud window; 5 report.
- step1 CLOUD_MIGRATION.md/json + mac-12 read. No method for the Windows property digests (129/308331669, 1443/442941466, 13/306913035) anywhere in repo/git notes ("hierarchy/class, selected geometry/material/texture properties and attributes", hash unspecified). Cannot be reproduced by design; new baseline will be recorded.
- step2 cloud: PlaceVersion 6 (as loaded), Edit true, persistedToCloud true (list_roblox_studios), digest 277/3173417/786797912 OK. Open Cloud versions GET /universes/v1/.../versions -> 404 (not available); latest-9 not re-confirmed by API.
- step3 wrote tools/qa/ProtectedDigest.luau (v1 method, documented in header)
- step4 cloud run (read-only, Edit): AsuraLobbyKit instances 129 digest 1095707166; AsuraAssets 1443 / 468385596; MaterialService 13 / 1586257287. Counts match Windows; hashes differ (Windows method unrecorded) -> new v1 baseline. Not committed (per brief).

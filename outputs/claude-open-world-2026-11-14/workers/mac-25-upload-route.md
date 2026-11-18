# mac-25 upload route (read-only reader, Haiku)
Supersedes: nothing. Linked from CONTINUATION.md "Mac resume — 2026-11-18". New because it is this lane's note. Reading order: lead's mac-25 brief.

1. Tool and window
- Working upload route: cloud place window (win-04, placeId 118614906972571, universe 10777041159, Edit, persistedToCloud=true). Attempt: "POST 200, operation a18c4491-d60d-4a82-aa02-e47f77770fff" (win-04-cloud-upload.md:10). Request fields recorded: "model/gltf-binary, Model, creator 3148600636, asset:read asset:write" (same line).
- Exact tool or endpoint name: NOT RECORDED in these notes. No line names the MCP tool, the URL, or AssetService:CreateAssetAsync for the GLB path. The animation tools use CreateAssetAsync, but those are Animation assets, not GLB.
- Local window refusal (win-09-uploads.md:7, local window 475bdaf0, persistedToCloud=false): "Could not acquire an Open Cloud access token: Scope 'asset:read' has not been granted. Ask the creator to grant the required scope in the Assistant MCP Permissions settings, then retry." Refused before any operation was created. Nothing uploaded, no registry written.

2. Read-back and recording
- Asset ID is read from the operation result. win-04:10: "first poll done=true, assetId 106633407703784, revisionId 1, moderation Approved, state Active, isPublished true."
- Registry written by hand or by the lead, then checked by tools/assets/kit_registry.py. Shape (kit_registry.py:3): assets/<KIT>_UPLOADED.json = {"modelAssets": {Piece: {assetId}}, "pieces": {Piece: {Piece__Sub: {MeshId, ColorMap, NormalMap, RoughnessMap[, MetalnessMap], center?, operations?}}}}.
- CLI (kit_registry.py:106-111): `python3 tools/assets/kit_registry.py <kit> [--check] [--allow-missing PIECE|PIECE__SUB] [--root]`. --check validates only. Without it, the Luau registry module is written.
- Local check: win-04:11 loaded the model with InsertService:LoadAsset in Edit on a local copy. Sub-mesh IDs were then recorded in assets/SLICE_KIT_UPLOADED.json (win-04:12).
- tools/assets/register_uploads.py is a different path (PHASE5_UPLOADED.json, ASSET_IDS.md). Not the bellwood route.

3. Operation polling and moderation
- Operation IDs are kept as "operation" lines in each worker note (win-09, win-11). A piece with an operation line but no registry entry counts as uploaded and needs only a LoadAsset readback (win-09-uploads.md:5). Do not re-upload.
- Moderation states seen: Approved (lantern, win-04:10); Reviewing for five audio clips (win-11-uploads.md:112-116).
- Poll endpoint and retry/backoff: NOT RECORDED. win-04 says an earlier Codex op b921007b failed "Unknown Error" on the same file and the retry succeeded, so the failure was treated as transient.

4. Constraints recorded
- Creator id 3148600636 (win-04:10). Note: this same id appears in tools/qa/PrivateCrossJob.server.luau:118 as the private-test owner.
- Rule "never DataModel edits in the cloud window": NOT RECORDED as such. Closest: mac-12-cloud-m1.md:14 "step4 no save tool (not invoked)", and mac-14-cloud-v9.md:4 is read-only, "Not committed (per brief)".
- Scope rule: asset:read and asset:write are both required (win-04:10, win-09:7).
- Model file must be read from upload/<group>/ originals (win-11:2). bellwood_far/UPLOAD.md:14 says IDs come from MeshPart/SurfaceAppearance properties in Studio, never guessed.

Not done: no Studio, build or upload run; no binaries read; PROJECT_STATE.md not appended (outside the one-file edit allowance).

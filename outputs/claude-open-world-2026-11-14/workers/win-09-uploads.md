# win-09 uploads (Sonnet, sole uploader)
Window 475bdaf0-28d7-46f7-8540-7a6f78369526 (AsurasPathTEST_upload2.rbxlx, persistedToCloud=false). Memory committed at start 17.37 GB.
Plan (order): slice (15, lantern already done) -> bellwood_built_a (31) -> built_b (16) -> veg (27) -> far (6) -> hero (5) -> audio (5). Total 105.
Registries: slice -> assets/SLICE_KIT_UPLOADED.json; built_a/b/veg -> assets/BELLWOOD_KIT_UPLOADED.json; far -> assets/BELLWOOD_FAR_KIT_UPLOADED.json; hero -> assets/HERO_KIT_UPLOADED.json; audio -> assets/OVERWORLD_AUDIO_UPLOADED.json.
Resume rule: a piece with an operation line below but no registry entry = uploaded, needs LoadAsset readback only; never re-upload.
## Checkpoints (piece | operationId | assetId)
- [STOP] First upload (Bell_Stair_Segment, slice, local window 475bdaf0) refused client-side before sending, no operation/asset created. Exact text: Could not acquire an Open Cloud access token: Scope 'asset:read' has not been granted. Ask the creator to grant the required scope in the Assistant MCP Permissions settings, then retry. Nothing uploaded, no registry written. Window closed unsaved. Lead decides (cloud window worked for win-04; creator may need to grant asset:read/asset:write in Assistant MCP Permissions for local windows).

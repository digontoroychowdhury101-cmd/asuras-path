# win-67: Vesperhold held pieces (snapped pines, stumps, viaduct bay + balustrade, waterfalls)

Worker: win-67 (self-reported Opus 5.5, claude-opus-5-5). Branch ux/onboarding-overhaul at 5b1c5b9.
Fix list from workers/win-65-gate-a-verdict.md. Rules: mac-50 (never decimate, subs < 18,000, 2048 maps, black Metal, GLB < 50 MB,
CC0 Poly Haven only, one heavy job machine-wide with the mkdir lock and free RAM >= 2.0 GB).

## Files changed (owned)
- tools/blender/vesperhold/vesperhold_trees.py: `torn_fibres`, new `dead_pine(seed, H, crown, brk_f, tear_az)`, new `dead_stump`;
  Dead_Stump_A/B moved from SCANS (tree_stump_01 scan) to generated SPECS; per-spec bark `frost`. Oaks, thorns and logs untouched.
- tools/blender/vesperhold/vesperhold_kit.py: `viaduct_bay`, `viaduct_balustrade` only.
- tools/blender/vesperhold/vesperhold_props.py: `waterfall`, `spray_card`, `K_sst` only.
- tools/blender/vesperhold/vesp_common.py: `gen_water` only.

## Blender runs

| Run | Pieces | Result |
|---|---|---|
| `kit_test2` | Viaduct bay and balustrade | Both exported and the E1 preview rendered. Final scratch files recovered into the Windows candidate. |
| `trees_bake1` | Two snapped pines and two stumps | Existing guarded job completed after the chat stopped. It merged all four manifests and rendered the pine and stump sheets. |
| `props_test2` | Two waterfalls | Preview generated before the last water texture edit. Codex exported both again from current source and fresh water maps. |
| `win68` | Eight held pieces plus five statues | Embedded PBR and split packs checked under the shared lock. Assembly renders and follow-up are in the [recovery record](win-68-vesperhold-recovery.md). |

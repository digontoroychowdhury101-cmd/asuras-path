# mac-06 SummitTemple far visibility (lane V, source only)
Plan: read builder/streaming/atmosphere/cullers, check terrain LOS offline, fix or write Studio probe. No source files edited.
Checkpoints
- Builder: OverworldService.luau:167-186 (parts, ROOF 72,54,46 Slate) + :189-205 (Persistent Model under region Folder). Nothing hides it.
- Cullers: grep of src finds no distance culler/LocalTransparencyModifier on landmarks. LandscapeBudget.luau:33-39 registers only MeshParts under Sanctuary/Map_*; temple is Parts under Overworld. Ruled out.
- Streaming: default.project.json:16-19 StreamingEnabled, TargetRadius 1024; model is Persistent (OverworldService.luau:195). Client has the 16 parts (mac-02), so streaming is ruled out.
- Terrain LOS (tools-style luau run of Overworld.heightAt, 400 samples, eye +5 over ground): min clearance 6..12 studs, only at the viewer end, from all five viewpoints, to roof 1626 / finial 1675. Terrain does not occlude.
- Atmosphere (EnvironmentProfiles.luau:57-67, thin air Density 0.035-0.05, Haze 0.4, Offset 0.35): calibrated contrast at 894 studs ~0.9, at 6435 ~0.36. Cannot extinguish a 92x100 dark roof at 894. FogStart/End (Config.luau:145) are legacy and ignored when an Atmosphere exists.
Conclusion: no source-level cause. Best hypotheses (ranked) and Studio probe below.

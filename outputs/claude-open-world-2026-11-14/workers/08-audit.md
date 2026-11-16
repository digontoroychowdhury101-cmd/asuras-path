# 08 test-assertion audit (read-only; baseline fb51a42; tests NOT executed)

## Task 1: classification per file
- test_arsenal_codex.luau: (a) locked-hint text now "The Bellwood" + Souls[2] "an unexplored region" (Codex hints still checked).
- test_asura_stage3.luau: regions/regionAt re-expressed (a) for Forest/MountainAscent/AridBasin; RecordDeath region/coords (a). **(c)** removed `assert(monks > 0 and swordsmen > 0, "both mob archetypes are placed")` (CorruptWanderingMonk / CursedSwordsman spawn placement; mob roster placement). Replaced by warden+phantom spawn existence only; the two archetypes are no longer spawned in the overworld, so only the archetype definitions remain untested for placement.
- test_boss_encounters.luau: Shen path unchanged (a). **(c, scoped)** for the 5 other bosses the gate/inside/outside/arena-region checks (`gate.Boss == id`, `World.contains(boss.Arena, gate.Inside...)`, `not World.contains(... Outside ...)`, `regionAt(arena center)==boss.Region`) are replaced by "no gate, region exists". Fog-gate flow is still asserted for Shen (+ test_boss_runtime). Intended by cutover (bosses archived), but archived-boss gate geometry is no longer validated anywhere.
- test_boss_runtime.py: (a) positions derived from gate.Placement/Inside instead of hard-coded (0,3,-1880); same assertions (seal, ally inclusion, perimeter, KO release).
- test_campaign_build.py, test_campaign_regions.py: (b) now run in legacy_world copy (archived builders). Not preserved mechanics per se.
- test_colosseum_runtime.luau: (a) only adds Overworld to the fake shared tree (needed by the new require). No assertion changed.
- test_miniboss_reward.luau: (a) warden spawn now asserted at Overworld.Minibosses site in Forest. **(c, minor)** removed `Zones.Spawns.DM_Warden_Graves == "Graves"` and `Zones.contains(graves, ...)`: the old-zone leash of the warden. Leash no longer exists live (AIService:961 guard), no replacement asserts the warden stays near home.
- test_progression_runtime.py: (a) lore Y from catalog (`Pillars.Y or 3`).
- test_review_regressions.luau: (a) fall-catcher cases moved to Altar_MonasteryGate spawn + (-2200,60,-1400) and "overworld is safe" (-8300,280,-4700). Removed Crypt entrance/arena positions (520,3,988),(520,3,880), Altar_SanctuaryDepths and (0,3,-900): all retired content (SanctuaryDepths region gone). Treated as (a); the "Shrine fall still recovered"/"Shrine ground safe"/settling cases are kept.
- test_input_map.luau: (a) only additions (Map=M binding, labels). Nothing removed.
- test_objectives.py: (b) default name runs with Overworld.Active=false inlined; live objectives are covered by new test_objectives_overworld.luau (name argument).
- test_campaign_ledger.luau, test_monastery_discovery.luau, test_monastery_route.luau: edits are only the Overworld stub in the fake shared tree (a); BUT lune_compat.LEGACY routes all three to the Active=false copy => (b) for caches/lore ledger, Codex, discovery/loot placement, route/objectives.
- lune_compat.py: (b) LEGACY set = ledger, discovery, route, **opening_tutorial, recovery_lifecycle, route_foundry** (the last three have no source edit; redirect is silent).
- legacy_world.py: new; copies src+tools, flips `Overworld.Active = true` -> false; asserts the line exists. Sound mechanism.
- test_cutover.luau: new; covers regions, altars, fog gate (1), bosses Inactive, 2 spawns, ring pads, bootstrap source greps, arenas skip, POIs, EnvironmentProfiles. Ring_SanctuaryPromenade only checked as an `Id = "..."` string present in ColosseumService (no behavioural duel check).

## Hidden-regression concerns (preserved mechanics only run on archived world)
1. test_recovery_lifecycle (death / bloodstain / unbanked essence; WorldService onCharacterSpawned wake-region; Recovery.sanctuaryFall) now runs ONLY with Active=false. It hard-codes Region "DesecratedMonastery" and Altar_MonasteryGate. Live equivalent: test_asura_stage3 covers store RecordDeath/RecoverBloodstain with "Forest" and test_review_regressions the fall catcher, but the real WorldService wake-region handler and respawn-at-later-altar flow have no live-world run.
2. test_opening_tutorial (tutorial, sparring phantom non-lethal, opening handoff text naming "Monastery Gate") legacy-only; phantom/Gate now live in Forest.
3. test_campaign_ledger / test_monastery_discovery / test_monastery_route (lore, caches, Codex ledger, route flags, objectives) legacy-only. Live coverage partial: test_progression_runtime lore read, test_overworld_data/persistence_migration (cache mentions), test_objectives_overworld. Real LootWorld/Codex against overworld definitions: only test_cutover discoverability.
4. test_route_foundry (route gates/forging unlocks; asserts kiln "in Bamboo Pass") legacy-only; BambooPass no longer exists live, so RouteGates/forge gating on live regions is untested.
Recommendation: a live-world smoke of recovery_lifecycle wake path + RouteGates for the retained altars.

## Task 2: leftovers (Active=true)
- AIService.luau:962 `if World.Regions.DesecratedMonastery then` : harmless; nil under Active so no zone leash; correct guard.
- AIService.luau:1273 `or "DesecratedMonastery"` : harmless no-op. Only for hand-placed tagged models outside every region; value goes to agent.Region, whose sole consumer (WorldService:1014 via GetAgent) reads Kind/Essence/Definition, never Region. Dead label; optional cleanup.
- ColosseumService.luau:182 Region="DesecratedMonastery" (Ring_GatehouseCircle): harmless; the new block (188-197) overwrites Region/Center from Overworld.Rings when Active.
- PresentationService.luau:12 map list: harmless; FindFirstChild miss is skipped. Gap (not bug): Map_Overworld gets no Dressing.Build.
- PresentationDressing.luau:25: harmless, branch never matches (root.Name Map_DesecratedMonastery absent).
- SoundscapeController.luau:37-41: harmless no-op; bell/water ambience for the old monastery never plays; region is never that id. Audio loss only (Forest has Wind only).
- Extra (not requested): MonasteryKit.luau:45 `World.Regions.DesecratedMonastery.Altars` would throw if Kit.keepClear is called; only caller is MonasteryHalls (archived), so latent only.

## Task 3: lobby ring identity
- Ring_SanctuaryPromenade definition (ColosseumService 157-166): byte-identical to baseline. The diff to ColosseumService is +1 require and an Active-only loop that touches only ids present in Overworld.Rings (Gatehouse, Octagon); Promenade is absent from that table.
- SanctuaryRingFinish, SanctuaryDuelCourt, Courtyard, Terrace, Kit and all other Sanctuary* builders: unchanged vs fb51a42 (git diff clean).
- NOT byte-identical: SanctuaryService.luau (+29/-5): root Folder->Model with Persistent streaming, builder param types Folder->Model, portal gated on Overworld.Ready("Glade") with a 20s bounded wait. Duel/promenade code in it is untouched, but the lobby container class changed (verify FindFirstChild/IsA("Folder") consumers in Studio).

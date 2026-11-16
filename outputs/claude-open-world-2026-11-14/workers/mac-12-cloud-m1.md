# mac-12 cloud lane C1: integrate git 3465430 into shared cloud place
Plan: 1 identity+digest 275/3151007/1357214079 + fingerprints (read-only); 2 guarded per-script updates (7 modified, Compute mapped-new, Worker Actor+Script new) hash-guarded; 3 digest 277/3173417/786797912 + fingerprints; 4 save_place; 5 smoke only if no edit needed; 6 append CLOUD_MIGRATION.md/.json.
- step0 plan written
- step1 identity OK PlaceId 118614906972571 Game 10777041159 Edit; digest 275/3151007/1357214079 OK; own fingerprints (descendant count/hash, recorded algorithm not in repo; counts match 129/1443/13 incl root): lobby 128/1483680705 assets 1442/107357800 mat 12/1023564582
- write1 ServerScriptService.AsurasPath.Services.PerfBudget ModuleScript: pre-hash 1752256388 == 32d448e guard OK, multi_edit applied, post-hash 1091137712/5451 == 3465430 OK (hash = byte rolling h*31 mod 2147483647)
- write2 Services.WorldService pre 1372183095 OK -> post 1496298799/47901 == 3465430 OK
- write3 Services.BiomeDressingService pre 292900521 OK -> post 248330566/22813 == 3465430 OK
- write4 Shared.Overworld pre 20290351 OK -> post 57609903/75604 == 3465430 OK
- write5 Services.OverworldTerrainCompute ModuleScript asserted absent, created; hash 743214818/6889 OK
- write6 Services.OverworldTerrainWorker Actor asserted absent, created; Worker Script (RunContext Legacy, same as build) hash 624260810/1838 OK
- write7 Services.OverworldTerrain pre 1887307777 OK -> post 1599485215/28937 == 3465430 OK (36 hunk edits)
- write8 Shared.BiomeDressing pre 602356933 OK -> post 2064210207/102199 == 3465430 OK (23 hunk edits)
- step3 FULL digest 277/3173417/786797912 == expected; fingerprints unchanged (lobby 128/1483680705, assets 1442/107357800, mat 12/1023564582), Edit mode. Next: save
- step4 no save tool (not invoked); step5 smoke PASS 4356 tiles 14.6 s, digest after Play 277/3173417/786797912; step6 docs updated

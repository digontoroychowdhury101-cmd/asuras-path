# C00 asset intake and scale survey

7 November 2026, Windows, branch `codex/windows-arenas` from `84c4a7f`. Studio evidence comes from a temporary build (`%TEMP%\claude\arenas\AR_baseline.rbxlx`). Its script digest matched the source build (286 scripts, 2,412,315 bytes, digest 576634848). No saved place was opened or written.

## Tools found on this machine

| Tool | State |
|---|---|
| Roblox Studio MCP | Connected after Studio updated itself to `version-67c8b1dedbb74fed`. The bundled proxy lists 35 tools. `execute_luau`, `screen_capture` and `start_stop_play` were used. |
| Blender MCP | **Not connected.** The add-on reported "Could not connect to Blender". Blender 5.2 is installed at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` and can run from the command line. |
| Local build | Python 3.15 with Pillow 13, Luau 0.742 and Rojo 7.7.1 (`work/bin`). `tools/build.py --output` builds to a temporary path. |

## Boss models: separate statuses

"Created" is the creator's statement from 6 November. I did not count it as proof of import or runtime.

| Boss | Template in `assets/models` / built place | Rigged | In-game verified | Source/export on this Windows machine |
|---|---|---|---|---|
| Grandmaster Shen P1/P2 | Imported: `AsuraBoss_GrandmasterShen_P1/_P2` (42/43 MeshParts) | Yes: 123/125 bones, skinned | Single client, 6 Nov (Shen RESULTS). Two-client test and profiling still pending | Master `.blend` and game GLBs are **not here**. They are ignored by git and live on the Mac (`assets/source/bosses/grandmaster_shen/`, `assets/build/grandmaster_shen/`) |
| General Zhao (Twins) | Imported: `AsuraBoss_GeneralZhao` | Motor rig (0 bones) | Seeded single client, 4 Nov (PROJECT_STATE) | `assets/source/bosses/general_zhao/v2_design/` (blend, GLB, FBX) |
| Iron Bull (Twins) | Imported: `AsuraBoss_IronBull` | Motor rig | Seeded single client, 4 Nov | Not found here |
| Venerable Baize | **Not imported**: no `AsuraBoss_*` template | n/a | No (falls back to a costume) | **Not found** |
| Slumbering Titan | **Not imported** | n/a | No | **Not found** |
| Sovereign Wu | **Not imported** | n/a | No | **Not found** |
| Azure Wyrm | **Not imported** | n/a | No | **Not found** |

Searched: the repository, `assets/**`, `%USERPROFILE%\Downloads` and the Desktop, for glb/fbx/obj/rbxm/rbxmx/zip/blend files matching the boss or H-asset names. **Dependency:** the creator needs to put the Baize, Titan, Wu and Wyrm exports (and the Shen master, if Windows is to edit him) on this machine or in the repository.

## H-assets (all nine created, per the creator)

| ID | Asset | Found here | Blocks |
|---|---|---|---|
| H01 | Shattered Votive Idol | No | DM-03 idol mesh (AR01 votive figures use a labelled slot) |
| H02 | Throne of the Starless Oracle | No | CP-01, AR05 focal |
| H03 | Petrified Root Buttress | No | SD-01/AR04 roots (AR03 optional) |
| H04 | Mourning Gate Relief | No | DM-08 relief |
| H05 | Storm-Eroded Memorial Crown | No | Optional (AR06) |
| H06 / H07 / H08 | Lady Lin / Master Smith Gao / The Hermit | No | AP-02 (references for these: `references/mannequin_*.jpg`) |
| H09 | Ossuary Skull (fallback) | No | Optional |

None of these blocks AR00 or AR01. AR01 lists H01 as optional only.

## Library pieces to reuse (exact names; full sizes in `asset-libraries.json`)

- **Bell:** `AsuraFoundryKit.Foundry_Bell` (6.95×9.67×6.95), `Foundry_BellMould`. Do not commission a second bell.
- **Cauldron:** `AsuraHanKit.HanCauldron` (1.43 cube, scales up), `AsuraFoundryKit.Foundry_Crucible`.
- **Lanterns:** `AsuraLobbyKit.Lantern_Stone`, `Lantern_Hanging`; `AsuraHanKit.HanLantern`; `AsuraAssets.AsuraBrassLantern`.
- **Lobby/shrine architecture (complete kit already exists):** `AsuraLobbyKit` Roof_Hall/Square/Gallery/GalleryEnd, Column_Lacquer/Base, Bracket_Set, Beam_Architrave, Rail_*, Dais_Bonfire, Paving_Medallion, Gate_Plaque, Stele_Dragon/Broken, Pool_Rim/Corner, Banner_Cloth.
- **Ruins:** `AsuraAssets.AsuraRuinArch` (13.25×8.96×6.21), `AsuraRuinPillar`, `AsuraTempleRuin`, `AsuraFoundationRuin`; `AsuraLobbyKit.Ruin_Pillar`, `Ruin_Gate`.
- **Statues:** `AsuraAssets.AsuraColossusStatue`, `FusedTreeStatue` (345×409×331, the Sanctuary colossus), `AsuraGuardianLion(+Mirror).GuardianCarving`, `AsuraHanKit.HanBixie/HanBixiePedestal`.
- **Rock and skyline:** `AsuraLobbyKit` Cliff_Ledge/Shelf/Spur, Karst_Spire (170 tall), Rock_Outcrop, Cloud_A/B/C; `AsuraBambooKit.Karst_A/B/C` (~107 tall); `AsuraSanctuaryVista` Vista_Ridge/Needle/Crown/Waterfall; `AsuraHanKit` CragA/B/C, Boulder*.
- **Han buildings:** `AsuraHanKit` HanPagoda, HanTemple, HanGreatTower, HanWallTower/Gate/Long, HanDefenseTower, HanHouse, HanShrine; `AsuraHanHD.HanGateHD`, `HanPagodaHD`.
- **Foundry:** KilnStack, SlagHeap, HallWall. **Bamboo/ground:** AsuraBambooKit, AsuraLivingBamboo, AsuraBambooBreakage, Frost steps/support, AsuraSanctuaryDetail.

## Measurements (current source and Studio)

| Item | Value | Evidence |
|---|---|---|
| Player rig | R15, HipHeight 2, root 2×2×1 sitting 3 above the ground. Head top 4.92 above the feet; 5.47 tall with accessories | Studio Play, server (`player-measure.json`) |
| Movement | Walk 22.4 (live Humanoid), sprint 33.6, dash 14 studs in 0.22 s, roll 11 in 0.36 s | CombatSettings.Movement and the live Humanoid |
| Camera | FOV 70. Follow offset (1.8, 1.4, 10.5), boom limited to 8–16, pitch −70°..55°, probe radius 0.6 | CameraController.luau:24-36 |
| Lock-on | Acquires at 60 studs, breaks at 80 | CameraController.luau:29-30 |
| Shen P1 ×1.3 | Bounds 4.79 × 7.65 × 7.49 including the guandao. Weapon alone 3.17 × 5.36 × 6.49. Root 3.9 above the feet (authored RootHeight 3 × 1.3) | Template clone + ScaleTo (`edit-measure.json`) |
| Shen P2 ×1.3 | Bounds 5.31 × 7.67 × 6.88; weapon 3.69 × 4.65 × 5.99 | same |
| Shen reach | Blade tip 6.8 rig studs, so 8.84 at ×1.3. Guandao standoff 7.875. Attack radii: FlowingJian 18 (×4, lunge), PrayerBeads 90 (7 beads, 34 studs/s), BloodWave 90 (38 studs/s, height 7), Skyfall 28 (aerial), CrimsonEmbrace 12 (lunge), AbbotSweep 16. Gap closer starts at 36 studs with a lunge | BossRoster, BossAttackCatalog |
| Shen hurt geometry | Duelist archetype: humanoid injury regions on the scaled rig, no capsule override. Visual bounds above are **not** hurtboxes | BossBodies (capsules only for Beast/Dragon) |
| Zhao ×1.2 / Bull ×1.7 | 4.03×9.07×13.13 (glaive 13.13 long) / 7.35×10.07×4.85 | Template clone |
| Baize ×1.5 / Wyrm ×2.2 | Authoritative capsules only (Beast reach 3.6, Dragon 5.8 at ×1). No visual model is present to measure | BossBodies |
| Arena boxes | Shen 120×130 at (0, −1960). The other five are 180×180 | WorldDefinitions/BossRoster |
| Motion | BossMotion keeps the boss 12 studs inside the arena box. Aerial height 28, Wu retreat 35, Baize pillars at ±60/±50 | BossMotion.luau:14-16, BossBodies |

**Provisional:** Shen's attack-pose sweep envelopes come from the committed clip data and contact table only. Mac's current, uncommitted Shen rig and clip corrections may change them. I recorded the committed version (`84c4a7f`) and treat them as provisional. I made no wing or tail measurements because the Wyrm and Baize models are absent.

## Rendering, lighting and replication

- `Workspace.StreamingEnabled = false`. No culling or streaming system is involved; every instance replicates. `FallenPartsDestroyHeight` is −400.
- Authored Lighting: ClockTime 17.4, Brightness 2.2, fog 120–1600, plus the effects CB_Atmosphere, Bloom, ColorCorrection, DepthOfField and SunRays.
- Each client blends to the profiles in `EnvironmentProfiles`. **Ash exploration** is night (clock 0.15), mist rgb(84,74,80), density 0.42, haze 2.8. **Combat:AshColosseum** raises the fill and thins the mist (0.30/1.8). **Unbound:AshColosseum** (phase 2) applies a crimson shift with the luminance kept, contrast 0.24. Arena lantern fill is rgb(246,226,210) and braziers rgb(255,150,76) (ArenaLighting).

## Cast references for H06–H08

`references/mannequin_front.jpg` and `mannequin_side.jpg`: the project's R15 rig (untextured, 5.18 studs) beside Shen P1 at ×1.3, with 1-stud height ticks, near-orthographic. Attach them to the three cast image prompts. Ordinary adults should stand 5.0–5.5 studs tall.

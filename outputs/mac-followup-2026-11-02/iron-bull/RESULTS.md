# Iron Bull and General Zhao in game: results (Mac, 4 November 2026)

Build: canonical digest **438762895** (scripts 274, bytes 2185152), `bash tools/verify_all.sh` green. Studio was single-client, seeded where marked. Windows and human gates below are **not run**.

## What changed
- **Bull's model is the creator's sculpt** (`Iron-Bull-PBR.glb`), split without decimation: 39 MeshParts, 504,480 triangles, biggest piece 18,313. Template `AsuraBoss_IronBull`.
- **Zhao now uses our v2 model.** Until this batch `AsuraBoss_GeneralZhao` was never imported, so every earlier fight showed the costume fallback. v2 is installed unchanged: 19 MeshParts, 22,090 triangles, guandao tip 9.25 studs. His 59 clips are untouched. The creator caught this mid-batch; I had noted it as optional, which was wrong.
- **45 Bull clips** authored on the sculpt's own rig, published with keyframe read-back.
- **Boss gait layer**: walk, run, strafe, backward and guard follow real root speed at Movement priority and stand down for attacks and reactions.

## Faults found and fixed in live play
| Fault | Effect | Fix |
|---|---|---|
| A dead Humanoid's Animator stops stepping | Authored Death froze on frame 0 and the body folded mid-attack | Actors with a Death clip stay nominally alive (`AsuraAuthoredDeath`); fighter KO stays the authority; the clip owns the body, no double root motion |
| The last Twin left the client's sync list at `BossDefeated` | The final fall never played | `BossFallen` keeps it synced for 6 s |
| `WorldService` read "nobody alive" as "boss gone" | **A won fight could reset instead of ending** when the killing blow landed outside the sim step | `AI.IsBossPresent`: a corpse counts as present until the KO event lands. Applies to every boss |

## Coverage per action
Status `Authored 13/13` for both Twins, read from the running game.
| Action | Bull | Evidence |
|---|---|---|
| Idle, Oath_Idle | authored | live |
| L1, L2, L3, Heavy, Running, Art, and Oath variants | authored | live, phase-locked (clip error = sample lateness + about 0.03 s) |
| IronCharge | authored, no Oath variant (plain clip is used) | live |
| ColossalHammer and its pulses | authored, no Oath variant (plain clip is used) | live |
| LightningSpear, ThunderQuickstep, with Oath | authored | live |
| Transform | authored | live, both kill orders |
| RunForward, WalkForward, StrafeL/R | authored | RunForward, WalkForward and strafes seen live |
| WalkBackward | authored | unit test; not confirmed on Bull live |
| GuardLoop, GuardHit, DeflectRecoil | authored | unit test only; **the AI never guarded during these runs** |
| HitLight F/B/L/R, HitHeavy F/B | authored | HitLightFront seen on Zhao; Bull's not confirmed live |
| PostureBreak | authored | live, seeded area hits |
| StaggerLoop/Recover, DeathblowVictim | authored | not exercised live |
| Death | authored | live: as first kill and as final kill |
| Turn clips | missing | the game plays none for either Twin; the root turns under Idle |

Shared: none of Bull's clips are shared with Zhao. Stock fallback: none. Zhao keeps his own 59. `IronBullMaul` stays outside the player registry, inventory and drops.

## Live results (seeded unless noted)
- Zhao falls first: Death plays, Bull gets `BossEnrage`, Transform, then Oath clips; Bull falls, Death holds, `BossDefeated`. PASS.
- Bull falls first: mirror of the above with Zhao under the oath. PASS.
- Player death and retry: `BossReset`, re-entry, both skins and helper bones rebuilt, 13/13. PASS.
- Bull alone (Zhao seeded out): phase-locked chain, gait closes distance at about 14 studs/s. PASS.
- Input was seeded (protection, sustain, area kills). No real-input duel was played.

## Honest gaps
- **Maul reach.** The sculpt's short haft leaves the maul 2.46 studs from the hand at scale 1 (costume maul: 5.7). Studs at contact against server reach: L1 8.39/9.5, L2 6.98/7.0, L3 9.12/10, Heavy 8.7/10.5, Running 7.38/8, Art 8.22/9.5. I did not enlarge the maul or change reach. Decide after human play.
- **Attack pressure.** Against a protected, stationary player each Twin chains almost without pause. Not retuned; judge in human play.
- **Camera.** At 7 studs Bull fills the normal camera behind the player. Comfort is a Windows gate.
- **Textures.** Sources are 2048, but Roblox-loaded maps measure 1024x1024 on Bull. Reported, not worked around.
- **Zhao v2 detail.** It is the 22k game mesh from the review, with the review's own listed defects (face at close range, stiff grip). The 885k master could become a sub-20k split like Bull's; not done.
- **Validator notes on published clips:** `Art` planted foot slide 1.00 rig/s; `Death` 0.28 below ground (shield and maul in the final bow).
- **Dark joint socks** at raised shoulder and thigh are visible on Bull in preview sheets. Fixing needs a re-import.
- **Video not captured.** `CAPTURE_FAILED: macOS screen recording permission unavailable`. Security settings left alone. Stills only: `02_duo_zhao_v2_and_bull_normal_lighting.jpg`, `03_zhao_v2_guandao_L3_pose_in_game.jpg`, the second a frozen pose with the AI held.

## Windows and human cases (all pending)
1. **Duel, Zhao first; duel, Bull first**, real input, ordinary camera, real-speed video. Expect Death, Transform, Oath clips and `BossDefeated`.
2. **Final blow by spell/area and by melee.** Expect victory and loot, never `BossReset`. Repeat on one non-Twin boss, since the fix is shared.
3. **Running, charge and pulse attacks.** Iron Charge, Colossal Hammer pulses, Lightning Spear: contact agrees with the swing.
4. **Player defense timing** against each Bull attack: parry, block, dodge. Log misreads against `AsurasStrike` data.
5. **Guard and deathblow.** Force Bull to guard and take a deathblow, which were not seen live here.
6. **Camera comfort** at Bull's standoff, and **performance** with both Twins on hardware (504k + 22k triangles).
7. **Human judgment:** duel feel, duo feel, Bull's maul reach, Zhao v2's look next to the sculpt.

Shared code changed after the Windows pass; repeat: boss death on the Cloister and Shen bosses, fog gate release, `EnemyDissolve` on ordinary enemies, `test_boss_runtime`.

## Sources Git will not carry
Local only (gitignored). Rebuilding needs these on the Mac:
- `assets/source/bosses/iron_bull/Iron-Bull-PBR.glb`, `assets/build/opening_cast/bull/Bull_v1_Game.glb`, `work/opening_cast_bake/bull/`, `work/bull_import/labels.npy`, `work/bull_import/samples.npz`
- `assets/source/bosses/general_zhao/v2_design/`, `assets/build/opening_cast/zhao/AsuraBoss_GeneralZhao.glb`, `work/opening_cast_bake/zhao/pieces.json`

Reproduce: `tools/blender/bull_import/` (split), `tools/blender/zhao_v2/export_skin.py` (export), then Studio import, `bind_skin.py`, `check_skin.py`, `extract_skin.py`. Clips: `export.py bull`, `publish.py`, `register_bull.py`. Tracked templates in `assets/models/` already hold the uploaded ids, so Windows needs none of this to play.

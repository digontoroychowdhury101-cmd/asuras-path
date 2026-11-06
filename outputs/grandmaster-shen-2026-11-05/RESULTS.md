# Grandmaster Shen: integration results

Status: **He is in the game.** Both skinned forms are imported, uploaded and bound (`ServerStorage.AsuraAssets.AsuraBoss_GrandmasterShen_P1/P2`), all 64 clips and all 16 sound layers are published, and a single-client Studio fight ran both phases, the transition, defeat, death, reset and retry on the real templates. Still open: the two-client test (other computer) and device profiling.

## Evidence

| Category | State |
|---|---|
| Static review | Both GLBs confirm a guandao in both phases. Callers traced before contracts changed. |
| Local regression | `bash tools/verify_all.sh` passed, building only to a temp path. New: `tools/test_shen_integration.py` (data contracts), `tools/test_shen_presentation.luau` (the real effects module on engine fakes: timing, cancel, reset, departure). Updated for the loadout: `test_boss_runtime.py`, `test_asura_stage3.luau`, `test_boss_presentation.luau`. |
| Blender render | All 46 clips pass the validator (reach, floor, hand contact, weapon through body, foot slide, loop seams). That proves contact and reach, not quality, so motion was judged from rendered sequences of the real skinned GLB with the real `ClothSim` code. `shen_motion_preview_blender.mp4` and `sheets/` show motion only: no VFX or sound, Blender lighting, not Studio. |
| Studio integration | **Done, single client (2026-11-06).** Fight in a throwaway build with an unmapped probe (`tools/qa/ShenProbe.server.luau`). Skin status `Template:AsuraBoss_GrandmasterShen_P1` → `_P2` at the phase change; 42/123 and 43/125 MeshParts/bones; 122 bones driven per frame. Clips seen live: P1 all specials (Flowing Jian, Hesitant Moon, Wheel of Heaven, Prayer Beads, Abbot Sweep, Feint, Flourish, Heavy, Art, L1-L3, turns); P2 Blood Wave, Crimson Embrace, Skyfall, Phantom Drift, Rending Arc, Feint, Flourish, Heavy, Art, L1-L3, turns. Defeat removed him; player death fired `BossReset`; retry brought back one P1 skin. No script errors. Stills in `studio_evidence/`. |
| Multiplayer | **Pending, other computer.** |
| Device profiling | **Not done.** 86 chunks across both forms, plus about 120 bone writes a frame and the simulation per boss. Legal per-mesh sizes prove nothing about frame time. |
| Audio | **Uploaded, 16/16** (Creator: Me, 0 Robux), ids in `PresentationAssets.Audio` and `assets/opening_cast/GrandmasterShen_audio.uploaded.json`. Each id loaded in Studio with the WAV's exact length; `ShenSteelAir` heard playing in the fight. Not judged by ear. |

## Decisions to review

- **Weapon:** P1 is now Guandao, P2 stays Guandao. Move id `FlowingJian` is kept; display name is "Flowing Glaive". No move list in the HUD shows display names yet, so `DisplayName` is currently catalogue data.
- **Scale 1.3** (was 1). The sculpt's blade tip is 6.8 rig studs; at 1.3 it reaches the Guandao's standoff of 7.875. This makes him visibly larger. P2 `ReachBonus` 2.5 removed, because the visible weapon does not grow, so **phase 2's melee reach is 2.5 studs shorter than before.**
- **Crimson Embrace gains a Lunge.** Without it the claw (about 4 studs) was far short of the 12 stud grab. This changes how the move plays. Nothing attaches to a player.
- **Prayer Beads start** centred on his hand and fanned across the aim (`Fan`, `Rise`), not the old offset. Damage, count and speed unchanged; Wu's barrage unchanged.
- **Reveal at 0.9 s:** the P2 body now swaps at the shared handoff pose rather than at t=0. Protection, duration, camera skip and the shockwave's timing are unchanged. Other bosses have no `Reveal` and behave as before.
- **Known mismatch kept:** Abbot's Sweep hits to 16 studs but the blade reaches about 8. The crescent effect runs out to 16 so the danger reads; gameplay radius left alone.

## Cloth and movement (rebuilt after your review)

You rejected the first version: rigid robes on hinges and key-pose motion. His body, robes, sleeves, mantles, hair, beard and beads are now one skinned model on one skeleton, and every free garment point is a bone driven by a live wind simulation on each client.

- **Model:** 15 limb bones plus cloth lattices (P1 110 cloth bones, 126 total; P2 104, 120 total). At most 4 influences per vertex. Weapon and P2's floating beads stay rigid in `Shen_P<n>_Props.glb`.
- **Cloth:** `src/shared/ClothSim.luau` (wind, gusts, flutter, gravity, body collision). `src/client/Controllers/BossCloth.luau` runs it, cosmetic only, tied to the tag `AsuraSkinnedBoss`, so a phase swap, reset, respawn, streaming or destruction ends it with the skin. Graphics tier and reduced effects set the rate, never whether the body moves.
- **Body:** gaits rewritten (hips lead, heel-to-toe, weight shift), idles re-authored, an overlap and unrest layer on all clips. The weapon hand is excluded so contacts stay on the server's impacts. Locomotion rates are unchanged.
- **Known flaw:** in the walk, the baggy black trouser can break through the ivory under-robe at the raised knee, seen up close from the front quarter. The under-robe's lattice is too sparse to wrap the knee, and there is little room left under the 128-bone limit. At combat distance it reads as a small dark patch.
- **Not proved:** shared bones across many MeshParts on one Roblox skeleton, bone count per mesh, `Model:ScaleTo` on bones, and bone write cost. All need a Studio pilot before anything else below is trusted.

## Fidelity

No decimation or remesh. UVs, normals and 2048 maps are preserved.

| Form | Source tris | Added under-layer | Added fissure copies | Skinned chunks | Rigid props | Largest chunk |
|---|---:|---:|---:|---:|---:|---:|
| P1 | 500,000 | 1,032 | 0 | 39 | 3 | 17,792 |
| P2 | 500,000 | 1,032 | 1,742 | 38 | 6 | 17,992 |

Local repair: 1,032 under-layer triangles per form (core at waist and pelvis, thigh tube in the robe's cloth colour) close gaps the sculpt never modelled.

Reveal alignment at the handoff, rig studs: fist 0.00, ankles 0.06, pelvis 0.08, blade tip 0.17. Contact table: `contact_alignment.json`.

## Files

- **Master:** `assets/source/bosses/grandmaster_shen/GrandmasterShen_Master.blend`. Untouched `Source_P*`, armature `Rig_P*`, skinned `Export_P*` with vertex groups, packed textures, 46 labelled Actions plus `ClothReview_*` Actions of the simulated shots, `Build_Info` text with versions and commands. Blender 5.2.2. Not in git (`assets/source` is ignored): copy it across machines by hand.
- **Game chunks:** `assets/build/grandmaster_shen/Shen_P{1,2}_Game.glb` (skinned) and `Shen_P{1,2}_Props.glb` (rigid), also ignored. Per-chunk manifests in this folder.
- **Clips:** `assets/animations/opening_cast/shen/` with `manifest.json` (durations, contacts, validation, upload status).
- **Tools:** `tools/blender/shen_import/` (`skin_rig.py` weights and lattices, `review.py` renders, `check_stretch.py`), `tools/animation/opening_cast/cloth_bake.py`, `tools/animation/opening_cast/shen_lib.py`, `shen_clips.py`, `shen_fx_points.py`, `register_shen.py`, `tools/assets/build_shen_audio.py`.
- **Game:** `src/client/Controllers/ShenPresentation.luau`, `BossCloth.luau`, `src/shared/ShenPresentationData.luau`, `ClothSim.luau`, `ShenClothData.luau` (generated) are new. Edited: `BossAnimations`, `InterfaceController`, `AIService`, `BossAttackService`, `BossHazards`, `BossSkin`, `PbrAssets`, `BossAnimationRules`, `BossArmaments`, `BossAttackCatalog`, `BossRigs`, `BossRoster`, `LooksDuelists`, `WorldDefinitions`, `default.project.json`; `bind_skin.py`, `extract_skin.py`, `export.py`.
- `places/AsurasPath.rbxlx` shows as modified. I did not touch it; it was saved by Studio. Leave it out of any commit unless you meant to change it.

## Attachments (created by `bind_skin.py`)

| Name | Piece | Used for |
|---|---|---|
| BladeTip, BladeBase | `Shen<n>_Weapon_1` | Edge trail, blade sounds |
| BeadHand | LeftHand limb (`AsuraFxLimb`) | Bead crescent, claw accent |
| ChestCore | UpperTorso limb (`AsuraFxLimb`) | Transition burst, breath and roar |

## Effects and ownership

`ShenPresentation` owns every sound, trail, bead, wave and scheduled event per actor. Events sit in a list it runs, with no `task.delay`, so cancelling is clearing the list. A cancelling state ends windups, trails and charge sounds. Released beads and the running wave finish on a bounded life. Reset, departure and defeat clear everything. Telegraph rings stay generic on every tier, and the wave's leading edge exists on the lowest tier. `Comfort.flash` scales every glow. No camera effects were added.

Timing and cleanup pass on engine fakes; how any of it looks is unverified until Studio.

## Sound

16 original layers in `assets/build/shen_audio/` (ignored by git; `python3 tools/assets/build_shen_audio.py` reproduces them). They are uploaded (2026-11-06) and play in place of the stand-ins below. No ID was invented.

| Event | Original layer | Owned stand-in | Attach | Onset | Vol | Pitch | Rolloff | Pri | Stop |
|---|---|---|---|---:|---:|---:|---:|---:|---|
| FlowingJian_Thrust | ShenSteelAir | GithubWhooshLight | BladeTip | -0.20 | 0.62 | 1.00 | 110 | 3 | cancel |
| FlowingJian_Contact | ShenBronzeContact | GithubSwordLight | BladeTip | +0.00 | 0.50 | 1.00 | 110 | 2 | ring |
| PrayerBeads_Gather | ShenBeadClick | GithubSecret | BeadHand | -0.95 | 0.42 | 1.00 | 80 | 2 | cancel |
| PrayerBeads_Gather | ShenBeadClick | GithubSecret | BeadHand | -0.60 | 0.42 | 1.12 | 80 | 1 | cancel |
| PrayerBeads_Gather | ShenBeadClick | GithubSecret | BeadHand | -0.32 | 0.46 | 1.24 | 80 | 1 | cancel |
| PrayerBeads_Gather | ShenTensionRise | NovaCharge | BeadHand | -1.00 | 0.36 | 1.00 | 100 | 3 | cancel |
| PrayerBeads_Launch | ShenBeadLaunch | GithubWhooshHeavy | BeadHand | +0.00 | 0.62 | 1.15 | 130 | 3 | ring |
| PrayerBeads_Launch | ShenJadeChime | Bell | BeadHand | +0.00 | 0.20 | 1.50 | 90 | 1 | ring |
| PrayerBeads_Impact | ShenBeadClick | Clash | Root | +0.00 | 0.42 | 1.30 | 90 | 2 | ring |
| AbbotSweep | ShenClothRustle | Wind | ChestCore | -0.72 | 0.30 | 1.00 | 70 | 1 | cancel |
| AbbotSweep | ShenLowSweep | GithubWhooshHeavy | BladeTip | -0.16 | 0.72 | 0.82 | 130 | 3 | cancel |
| AbbotSweep | ShenBronzeContact | GithubSwordHeavy | BladeTip | +0.02 | 0.48 | 0.90 | 110 | 2 | ring |
| BloodWave_Windup | ShenScrape | Stone | BladeTip | -0.80 | 0.52 | 0.80 | 110 | 2 | cancel |
| BloodWave_Windup | ShenGrowlExhale | GithubMonsterGrowl | ChestCore | -0.50 | 0.58 | 0.85 | 130 | 3 | cancel |
| BloodWave_Release | ShenBowedMetal | NovaVoid | Root | +0.00 | 0.72 | 0.80 | 190 | 3 | ring |
| GuandaoSkyfall_Rise | ShenAirTear | GithubWind | Root | -1.10 | 0.55 | 1.00 | 170 | 3 | cancel |
| GuandaoSkyfall_Land | ShenLandImpact | Blunt | Root | +0.00 | 0.95 | 0.72 | 200 | 3 | ring |
| GuandaoSkyfall_Land | ShenBowedMetal | NovaVoid | Root | +0.02 | 0.40 | 0.70 | 170 | 1 | ring |
| CrimsonEmbrace | ShenBreathIntake | Wind | ChestCore | -0.95 | 0.50 | 0.70 | 90 | 2 | cancel |
| CrimsonEmbrace | ShenGrowlExhale | GithubMonsterGrowl | BeadHand | -0.10 | 0.50 | 1.10 | 120 | 3 | cancel |
| Melee_P1 | ShenSteelAir | GithubWhooshLight | BladeTip | -0.12 | 0.50 | 1.00 | 100 | 2 | cancel |
| Melee_P2 | ShenSteelAir | GithubWhooshHeavy | BladeTip | -0.12 | 0.55 | 0.82 | 110 | 2 | cancel |
| Transition_Falter | ShenClothRustle | Wind | ChestCore | +0.00 | 0.42 | 0.90 | 110 | 1 | cancel |
| Transition_Falter | ShenFalter | GithubMonsterGrowl | ChestCore | +0.10 | 0.32 | 1.20 | 120 | 2 | cancel |
| Transition_Inhale | ShenBreathIntake | Wind | ChestCore | +0.40 | 0.60 | 0.60 | 150 | 3 | cancel |
| Transition_Roar | ShenRoar | GithubMonsterGrowl | ChestCore | +0.90 | 1.00 | 0.72 | 240 | 3 | ring |
| Transition_Roar | ShenBowedMetal | NovaVoid | Root | +0.90 | 0.42 | 0.62 | 200 | 1 | ring |

Sourcing briefs, if the synthesized layers do not hold up by ear:
- **ShenRoar / ShenGrowlExhale:** an original or licensed aged male vocal, inhale into a guttural roar, 1.6 s, dry, no music. These are the most likely to sound synthetic.
- **ShenBeadClick:** close recording of old wooden prayer beads, single clicks, dry.
- **`SoundService.BossMusic_GrandmasterShen`:** not authored; the existing placeholder plays. Needs one looping track, restrained bowed bronze and low percussion, that can carry both phases.

## Studio import (done 2026-11-06)

- **Pilot result:** the importer gives all chunks of a form **one** shared skeleton under the template's `RootPart` (P1 123 bones, P2 125), so one set of bone writes moves every chunk. That skeleton sits **180° about Y** from the rig's authored space. `BossCloth` assumed they matched and drove every bone to its mirror image; in the first play he was visibly torn apart. Fixed in `BossCloth.run`: each frame reads the root bone's offset from the HumanoidRootPart and applies it to limb and cloth targets. After the fix he renders whole and moves correctly (stills).
- **Tools changed by the pilot:** `bind_skin.py` moves each props import onto the body's pivot, hides the skeleton's `RootPart` and drops Studio's editor-only `InitialPoses`. `check_skin.py` counts the shared skeleton's bones. `extract_skin.py` accepts the `Glaive` helper bone.
- **Bind:** 85 parts, worst centre error 0.0000 studs. Capture place: `import/shen_import_capture.rbxlx`.
- **Fresh-upload note:** for a while after upload, Studio logs "Asset content representation is being generated" for some new mesh ids. That is Roblox processing; it clears on its own.
- **Not done:** two-client test (other computer, per house rule); device profiling (Studio client here: 60 Hz physics, 0.7 ms heartbeat, 5.4 GB Studio memory, not a device figure).

## Editing Shen's motion on any computer

The inputs the clip tools need are committed (`work/shen_import/samples_p1/p2.npz`, `cloth_p1/p2.json`, `work/opening_cast_bake/shen1/shen2/pieces.json`). The cloth bake also uses that computer's own `work/bin/luau/luau`, which the test suite already needs.

1. `git pull`, then edit `tools/animation/opening_cast/shen_clips.py` (moves) or `shen_lib.py` (shared pose, grip, gait helpers).
2. `python3 tools/animation/opening_cast/export.py shen GrandmasterShen_P1_Idle ...` re-bakes only the named clips; it prints OK or FIX per clip. Omit names to rebuild all 64.
3. With Studio open in Edit mode and signed in as Sheashing123: `python3 tools/animation/opening_cast/publish.py shen <STUDIO_ID> <clips>`, then `python3 tools/animation/opening_cast/register_shen.py`.
4. `python3 tools/build.py`, commit and push. Only one computer should publish Shen clips at a time, since `published.json` and the registry are shared.

## Movement reel (2026-11-06)

Recorded in Studio play (single client) with the real skin, `BossCloth` and lighting. `reel/shen_reel_part1_phase1.mp4` (3:50) covers a 25 s live fight, then every phase 1 clip. `reel/shen_reel_part2_phase2.mp4` (4:03) covers the phase change, a live phase 2 fight, then every phase 2 clip. Loops orbit at 1x; one-shots play at 1x from the front, then at 0.5x from the side. A caption names each clip and shows open validator flags. 1080p master (not in git): `work/reels/shen_reel_full_1080p.mp4`.

What the reel shows (times are within each part):
- **Phase change (part 2, 0:00-0:05):** the swap is instant (Strike to phase 2 idle in about 1 s). He then renders white and see-through for about 3 s. During the session Studio kept logging "Asset content representation is being generated" for three mesh ids, so his new meshes may still be processing. Caveat: the AI was held and the damage was seeded, so the transform performance may have been skipped by the setup.
- **P1 Death (part 1, 3:38-3:49):** he sinks to one knee and stays up; he never falls. P2 Death (part 2, 3:49-4:00) collapses fully.
- **Grip:** walk and run carry the glaive one-handed, trailing at his side (part 1, 0:50-1:00 and 1:28-1:35). Several 0.5x hit reactions are one-handed too.
- **Run (part 1, 1:28-1:35):** reads as a quick walk: upright, no forward lean, legs hidden by the robe.
- **Flourish (part 1, 2:11-2:19):** the blade passes through his head, as the validator says. FlowingJian (2:25-2:37) swings the glaive vertically across his face.
- **Light attacks:** L1 and L2 are 0.40 and 0.42 s with little windup, which may be hard to read and parry.
- **Phase 2 readability:** the arena's red phase 2 lighting leaves him very dark, so hair-only black and the face cannot be judged from this footage.
- **Working as asked:** the cloth follows the body in the clips and in the live fights, the orbs float around his head, and the P2 idle hovers.

Remake: build the probe place (`tools/qa/ShenProbe.server.luau`); in play mode spawn and hold him; paste `tools/qa/shen_reel.luau` into the MCP Client datamodel; drive `live` / `catalogue` from there and the hold/damage ops from the Server datamodel. The MCP thread cannot fire remotes, so the server steps are sent separately. To record, give Terminal Screen Recording permission and launch the capture tool through Terminal. On this Mac, binaries started by Claude's shell are refused.

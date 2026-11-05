# Foundry mesh kit and playtest fixes: results (Mac, 5 November 2026)

Single-client Studio on the MacBook. `bash tools/verify_all.sh` passes on this build. Every Windows, multiplayer, hardware, live-save and human gate stays open.

## Meshes now in the wing
Six original pieces, authored in `tools/blender/foundry_kit.py`, each with 2048 PBR maps (colour, normal, roughness, metalness):

| Piece | Triangles | Where |
|---|---|---|
| `Foundry_Bell` | 16,648 | Seventh bell on the Bell Terrace (replaces the primitive bell) |
| `Foundry_KilnStack` | 4,729 | Founders' Kiln, with fire and flue embers |
| `Foundry_Crucible` | 8,640 | Yard and casting hall, with fires |
| `Foundry_BellMould` | about 4,700 | Two split clay moulds in the yard and hall |
| `Foundry_SlagHeap` | 2,756 | Yard |
| `Foundry_HallWall` | 1,844 | Timber-framed brick bays around the hall |

- IDs: `assets/FOUNDRY_KIT_UPLOADED.json`. Library: `assets/models/AsuraFoundryKit.rbxmx`, written by `tools/build_foundry_library.py`, mapped to ServerStorage.
- Colliders stay in `BambooPassLayout`. The meshes are decorative: no collision, query or touch.
- Stone lanterns in the wing replace the orange and black stubs (`Decor.lantern`, lobby `Lantern_Stone`).
- Three art passes were needed, judged in game:
  - v1: culled kiln and strap faces, washed-out colour.
  - v2: correct faces, but bright new-looking brick and rust like splashed paint.
  - v3 (kiln, crucible, slag, mould, hall wall): smoke-dulled brick, dark iron with dull oxide.
- The bell stayed at v2. The v1 assets and the five replaced v2 assets are unused on Roblox and can be archived. Nothing was deleted.

**To change a piece:** bake it, upload the GLB through Open Cloud from the private place "Asura Asset Import QA" (`77104076321648`), read the new IDs with `InsertService:LoadAsset`, update the JSON, then run the library script.

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/foundry_kit.py -- bake assets/build/foundry_kit_v1 Foundry_Crucible
```

```bash
python3 tools/build_foundry_library.py
```

## Fixes, and how each was checked
Real keys, game build, enemies alive, unless the row says otherwise.

| Fix | Result | Evidence |
|---|---|---|
| Cache claim refused during hit-stun | Claimed with walk speed 0 straight after a hit; "+2 Starfall Shard" shown | INPUT |
| Claimed cache kept offering its prompt | Prompt off after the claim and after respawn | INPUT, client read |
| Foe plate stuck across death and respawn | No plate on the death screen or after respawn | INPUT, client read |
| Dialogue left open when hit | Closed on 20 damage | Seeded: `tools/qa/FighterHurtProbe.server.luau` lowered authoritative HP, because no foe swings at the bonfire |
| Dialogue left open at death | Closed on knockout | Seeded: same probe, using the game's own `Rules.knockOut` |
| Death screen left a top strip uncovered | Frame now 685 tall from y -58 in a 627-tall HUD (`death_screen_full.jpg`). Same rule applied to the portal veil and window backdrops, which were not viewed | INPUT, client read |
| Kiln guards always drew together | Short notice radius and facing away from the stair. Monk closed first, swordsman moved about 4 studs in the same time. One sample | INPUT |
| Black and white casting pit plinth | Now Stone | Capture |

## Route after the new colliders
| Walk | Result |
|---|---|
| Road → yard → hall → landing | Clear, 7.9 s, 172 studs, no hits |
| Landing → terrace → Kiln stair → cache | Clear, 4.2 s, 90 studs |
| Crest → frost stones → Frost Ridge (W + Space held) | Landed on the ridge first try |
| Ridge → drop → shrine → crest → Bell Walk → landing | Clear, 14.5 s total, one hit |
| Shrine → Baize's mouth → arena floor to z -1470 | Clear until the boss killed the character. The moon gate was not reached, and no exit was walked |

**Game camera:** hall floor and terrace stair read clearly (`hall_game_camera.jpg`, `terrace_stair_game_camera.jpg`). The hall roof eave intrudes at the stair's right edge but does not hide the player. Standing against a column pulls the camera in until the character's hat fills the view, which is ordinary occlusion. The Lookout roof was not checked under the game camera.

**Tower from the gate:** its top shows small over the hall roof (`gate_view_of_tower.jpg`). No bamboo was cleared. Whether it reads as a goal still needs a human eye.

## Not verified
- **Kiln lethality.** A level-1 character standing still took six hits and died 2.6 s after the first one (`100→89→60→49→23→9→0`). No change made. It needs a human fight on an earned save.
- **Fought-through time** for the wing is still unknown.
- **Windows, two clients, phones, live saves, rejoin:** not run here.
- **Frame rate with the new meshes** was not measured on this build.
- **Normal mouse-steered play.** Walks used a script-set chase camera; the game camera was checked standing still.

## Also carried over
- Codex's art build (`2eb5d6e`) checked out: its hashes matched its handoff and the verifier passed on that build. Its open items are above, except sustained desktop timing, phones and other regions, which remain open.
- `docs/ci-full-verifier.patch` still needs applying from a token with `workflow` scope.

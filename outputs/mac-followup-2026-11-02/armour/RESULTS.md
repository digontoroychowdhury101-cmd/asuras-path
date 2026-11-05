# Armour: results (Mac, 5 November 2026)

Build: canonical digest **52738962** (scripts 277, bytes 2207133), `bash tools/verify_all.sh` green, `tools/test_armor.luau` 87 passed. Studio was single-client. Every Windows, human and live-save gate below is **not run**.

## What a player gets
Three suits at Master Smith Gao, on his panel: compare, forge, reinforce, wear, set aside. The three suit buttons render first because a choice below the fold is one nobody makes.

| Set | Class | Acquire | Protection | Posture | Speed | +5 |
|---|---|---|---|---|---|---|
| Ashen Pilgrim | Light | Starter | 0% | +0 | ×1.00 | 3%, +10 |
| Cinnabar Guard | Medium | 1200 Essence + 3 Spirit Iron; Desecrated Cloister altar kindled | 10% | +15 | ×0.97 | 16%, +30 |
| Iron Oath | Heavy | 3600 Essence + 2 Starfall Shard; Twin Sentinels laid to rest | 18% | +30 | ×0.92 | 24%, +50 |

Levels 0..5. Reinforcing costs `floor(Base*(level+1)^1.4)` Essence (Base 120/280/480) plus Spirit Iron `level+1` below +3, Starfall Shard `level-2` from there. Protection is capped at 30%. Levels do not change a suit's look.

**Why these numbers.** Heavy gives up 8% move speed for 18% less health loss, which keeps dodge timing as the better defence: dashes, windows and frames read no armour. Posture is the main reason to wear plate, since it buys blocks before a break. Each set has a real cost, so none strictly replaces another.

**How it meets the three health layers.** Protection scales a hit's health loss at contact, and the value is frozen in `ContactSnapshot.DefenderProtection`, so changing suit cannot reach an attack already in flight. It covers strikes, chip, spells and boss attacks, and tests confirm the three layers stay consistent under it. Burn, bleed, deathblow and external damage ignore it. Posture raises `PostureCapacity`; speed is a plain factor in the movement owner.

**Equip timing.** Only at Gao, Idle or resting and outside a duel, checked again inside the server transaction. New values apply at once through `Service.ApplyArmor`. Ranked (`rankedStats`) clears RPG stats, so armour counts for nothing there: duel normalization is preserved. The two-client case is still unrun.

**Migration.** Schema stays v4; `inventory.Armor` and `equippedLoadout.ArmorSet` are additive. An old save loads owning Ashen Pilgrim and wearing it. An unknown or unowned id resolves safely (`ArmorRules.resolve`). Covered by tests, not by a real old DataStore save.

## Visuals and sources
The suit is the body while worn: one rigid MeshPart per limb, bound like a boss skin; the blocky limbs go invisible. Hurtboxes, collision and joints are untouched, pieces are massless and answer no query, and head attire stays.

| Set | Game triangles | Largest piece | Master | Parts | Reference |
|---|---|---|---|---|---|
| Cinnabar Guard | 38,056 | 8,452 | 250,618 | 14 | Creator's sheet |
| Ashen Pilgrim | 34,128 | 4,976 | 87,036 | 14 | Creator's sheet |
| Iron Oath | 44,230 | 8,496 | 233,042 | 14 | **Lineup only: its sheet was never supplied** |

- Four 2048 PBR atlases per set; every texture imported, bind error 0.0000. IDs: `assets/opening_cast/AsuraArmor_*.uploaded.json`.
- Reproduce: `tools/blender/armour/` (`build.py`, `bake.py`, `render.sh`), then `tools/assets/extract_skin.py`.
- **Git will not carry** `assets/source/armour/{cinnabar,ashen,ironoath}/` (blend, atlases, GLB, manifest). Rebuild them with the Blender tools or copy them across.
- Turnarounds and Studio captures: `renders/`.

**Creator's report: Ashen ribbon and jade stuck out from the body.** Fixed on Ashen and Iron Oath: they now lie on the cloth and ride the thigh they cover. Cinnabar measured fine (tail about .03 proud of the apron, jade touching it) and was left alone.

## Evidence
Labels: **INPUT** real keyboard or mouse in Play. **SEEDED** position, funds, unlocks or suits set by a QA script. Nothing was saved to a real profile.

| Check | Result | Label |
|---|---|---|
| Fresh profile spawns in Ashen | folder AshenPilgrim, 14 parts | INPUT |
| Panel refusals | Record unchanged; "Kindle the Desecrated Cloister altar first." / "Lay the Twin Sentinels to rest first." / "Needs 1536 more Essence." | INPUT panel, SEEDED position |
| Forge Cinnabar | 6000→4800, 3 ore, debited once; Wear applies at once | INPUT panel, SEEDED funds and unlock |
| Reinforce +1..+5 | Costs 280/738/1303/1950/2665; protection 11.2..16.0; posture 118..130; "Gao can reinforce this no further." | INPUT panel, SEEDED funds |
| Forge and wear Iron Oath | prot .18, speed .92, posture 130, walk 20.61 | INPUT panel, SEEDED |
| Set aside | None, prot 0, walk 22.40, wanderer restored (16 limbs, 36 attire) | INPUT panel |
| **Real monk hits** | Bare 3.60/4.50/5.40/7.20. Iron Oath 2.95/3.69/4.43 (×0.82). Cinnabar +5 3.02/3.78/4.54/6.05 (×0.84) | Real enemy, SEEDED suit and position |
| Movement and attacks in suit | Walk, strafe, back, dodge, 3 M1, V, F hold reached `Blocking`; weld drift .0001; no console errors | INPUT (Cinnabar) |
| Weapon switch | Dao/Jian repeatedly: one weapon, 14 pieces, 0 bad welds; speed follows weapon (21.29 / 21.73) | SEEDED `ForceWeapon`, not the K key: a fresh profile owns one weapon, and K did nothing |
| Limb replaced under suit | RightHand, LeftUpperArm, UpperTorso via `ReplaceBodyPartR15`: 1 folder, 14 pieces, 0 bad welds | SEEDED |
| Late avatar | `ApplyDescription` on a worn rig: suit intact, drift .0001, hurtbox sizes reported | SEEDED. **Not** a real slow `CharacterAppearanceLoaded`; on the Windows list |
| Death and respawn | Suit and stats return; repeat wears keep 1 folder, 14 pieces, 1 weapon | INPUT and SEEDED |
| Hurtboxes | Torso sizes and collide/query flags unchanged in suit | Studio read |

## Not verified or not good enough yet
- **Rejoin or reload is not tested in Studio.** Studio uses the mock store (`IsMock`), so Stop and Play starts fresh. Save shape is covered by `test_armor` and `test_progression_runtime` only.
- **Earned acquisition was never walked.** Unlocks and funds were seeded.
- **Dodge and torso-twist were run live only, never frozen and inspected.** Studio updated mid-batch and now refuses pose holds from the tool. Guard, heavy and running were inspected, on Cinnabar and Iron Oath where captured. Ashen has side and turnaround views only.
- **Head attire is older, lower-resolution work** and looks rougher than the suits. The weapon is still the primitive Jian. Both are outside this batch; both are for the creator's eye.
- Human judgement is pending on all three suits. Iron Oath especially, since it has no sheet of its own.

## Tooling change
Studio updated during this batch (`-isInstallerLaunch`, 5 Nov). Its MCP thread can no longer parent a Script into ServerScriptService, nor invoke one. So `qa_inject.py` fails here. `tools/qa/qa_place.py` builds a private copy with the probe inside, and `ArmorProbe.server.luau` now runs a fixed sequence and prints `[ArmorQA]` lines. The canonical place carries no probe. **The older seed helpers in `HUMAN_PLAYTEST.md` may be affected: check before relying on them.**

## Windows cases
See `../HANDOFF.md`, section "Batch 3". They include a fresh Windows combat revalidation on this revision.

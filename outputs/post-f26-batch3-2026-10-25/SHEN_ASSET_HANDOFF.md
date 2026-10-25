# Grandmaster Shen P1/P2: production asset handoff

**Status: Blocked — production art.** This is an input contract only. Nothing listed here exists yet:
- no `AsuraBoss_GrandmasterShen_*` template;
- no Shen animation id;
- no Shen music or SFX id.

Studio confirms this (25 Oct, digest 1219538751): 0 `AsuraBoss_*` instances, and no `AsuraBossAnimations` folder.

Shen renders today through the CostumeKit primitive look (`AsuraSkinStatus = Fallback:Costume`) and stock R15 stand-ins (`Fallback:Stock`). Both stay as the visible fallback until real assets pass the checks in §8.

**Sources:**
- loader: `BossSkin`, `CostumeKit`, `PbrAssets.validate`;
- contract: `CostumeSchema`, `LooksDuelists.shen`;
- roster and moves: `WorldDefinitions.Bosses.GrandmasterShen`, `BossRoster`, `BossArmaments`, `BossAttackCatalog`;
- animation: `BossAnimationRules`, `BossAppearance`, client `BossAnimations`;
- cues: `BossEffects`, `BossMusic`, `GameFeelController`, `PresentationAssets`;
- earlier contract: `claude-followup-2026-10-21/ASSET_REQUIREMENTS.md`.

## 0. Loader changes made in this batch (so the contract is deliverable)

Two gaps would have broken a correct delivery. Both are fixed, with failing-first regressions (`test_boss_presentation` 197 → 201).

1. **Hands and feet would vanish.**
   - Problem: `BossSkin` hides *every* rig limb once a template binds, but only required 6 limbs to be covered. A template without hands or forearms would have shown a body with invisible hands.
   - Fix: `CostumeSchema.RequiredBones.Humanoid` now lists all 15 R15 limbs.
2. **The weapon would double.**
   - Problem: the costume's primitive Jian or glaive (`AsuraRole=Weapon`) always stayed visible, so a template carrying its own weapon meshes would have drawn two blades.
   - Fix: a template whose MeshParts include `AsuraRole=Weapon` now owns the weapon (`AsuraBossSkin.OwnsWeapon`), and the costume weapon hides. A later phase whose template has no weapon shows the costume weapon again. `CostumeKit.phase` respects the same rule.

**Studio evidence** (macOS, build digest 1661908618, Studio = build):

- **Seeded Shen entry with no template.** Status reads `Fallback:Costume (no AsuraBoss_GrandmasterShen_P1 or AsuraBoss_GrandmasterShen)` and `Fallback:Stock 0/5 authored (first missing GrandmasterShen_P1_Idle)`. The costume Jian is visible. Capture: `views/shen01_…`. This shows no regression.
- **Seeded stand-in template, deliberately not art.** 15 limb pieces plus a weapon piece were cloned from an existing PBR statue mesh, placed in `AsuraAssets` at runtime and never saved.
  - Result: `Template:AsuraBoss_GrandmasterShen_P1`, `OwnsWeapon true`; the costume JianBlade and the rig torso are hidden.
  - Capture: `views/shen02_…`. It proves the live loader path only; it is not a costume.

## 1. What gets delivered

| # | Deliverable | Name / destination | Owner |
|---|---|---|---|
| 1 | Phase 1 template (Disciplined Master, Jian) | Model `AsuraBoss_GrandmasterShen_P1` → `assets/models/AsuraBoss_GrandmasterShen_P1.rbxmx` | 3D artist |
| 2 | Phase 2 template (Demonic Chimera, Guandao) | Model `AsuraBoss_GrandmasterShen_P2` → `assets/models/AsuraBoss_GrandmasterShen_P2.rbxmx` | 3D artist |
| 3 | 11 animation clips (5 P1 + 6 P2), plus up to 6 optional | Animation objects in Folder `AsuraBossAnimations` → `assets/models/AsuraBossAnimations.rbxmx` | animator |
| 4 | Boss music | Sound `SoundService.BossMusic_GrandmasterShen` (one looping track) | composer |
| 5 | Attack SFX set | Owned Sound ids; the hook is **not in code yet** (see §6) | sound designer + dev |
| 6 | Uploaded ids | `assets/BOSS_SHEN_UPLOADED.json`, written only from real upload receipts | owner |

**Rojo mapping.** The three `.rbxmx` files map as **children of the existing `ServerStorage.AsuraAssets` node** in `default.project.json`, for example:

```json
"AsuraAssets": { "$path": "assets/models/AsuraAssets_Phase5.rbxmx",
  "AsuraBoss_GrandmasterShen_P1": { "$path": "assets/models/AsuraBoss_GrandmasterShen_P1.rbxmx" } }
```

This was checked this batch: Rojo 7.7.1 merged a test model as a direct child of `AsuraAssets` beside the 13 Phase 5 models. The test was not committed.

**Uploads.** Every mesh, image, animation and sound is uploaded by the account or group that owns the experience; the earlier uploads used `Sheashing123`. Do not register an id that has not been uploaded and checked in Studio.

## 2. Scale, rig and binding contract

**Rig and scale**
- **Rig:** standard R15 humanoid. Shen has no `Scale` in the roster, so `BossAppearance.apply` uses 1.
- **Author at scale 1.** The R15 body is about 5.4 studs from foot sole to head top: feet 3.0 below the root, head top 2.4 above. `BossSkin` calls `model:ScaleTo(actor:GetScale())`; never bake a scale in. The template Model's scale must be 1.
- **Rest pose:** the default R15 rest pose (arms straight down). Each MeshPart is **rigid**: `BossSkin` welds it to one limb with a `WeldConstraint`. There is no skinned deformation, so the mesh is split per limb (§3).

**Per-MeshPart requirements**

| Requirement | Value | Checked by |
|---|---|---|
| Class | `MeshPart`, with an uploaded `MeshId` | `BossTemplateCheck` |
| `AsuraBone` attribute | one of the 15 R15 limb names | `BossSkin` (refuses otherwise) |
| `AsuraBind` Attachment | limb centre in the part's space; written by STAMP mode | `BossSkin` |
| `SurfaceAppearance` | Color, Normal, Roughness and Metalness maps all set | `PbrAssets.validate` (refuses otherwise) |
| `AsuraRole = "Weapon"` | weapon pieces only; they bind to `RightHand` | `BossSkin` weapon ownership |
| Collision | none needed; `BossSkin` sets CanCollide, CanQuery and CanTouch off and Massless | — |

**Coverage.** The 15 limbs are Head, UpperTorso, LowerTorso, Left/Right UpperArm, LowerArm, Hand, UpperLeg, LowerLeg and Foot. Every one must be covered, or the template is refused with `Invalid:… missing <limb>`.

**Binding**
- Formula: `part.CFrame = limb.CFrame * AsuraBind.CFrame:Inverse()`.
- Authoring: pose the parts over a default R15 rig in Edit, then run `tools/qa/BossTemplateCheck.luau` in STAMP mode. It writes `AsuraBind = part.CFrame:ToObjectSpace(limb.CFrame)` for every part.

**Weapon tip reach**
- The tip must land where the server's strike reaches, so the drawn arc matches the blade.
- Distances from the RightHand centre at scale 1:
  - **Jian ≈ 6.75 studs** (server reach 7.5);
  - **Guandao ≈ 12.7 studs** (reach 11 + Shen's ReachBonus 2.5).
- These equal today's costume blades. The validator allows ±0.6.
- The blade extends along the hand's −Z (forward) axis, as the costume does.
- The guandao is held only by the right hand: there is no IK. Clips must place the left hand on the haft visually.

**Seams and clearance**
- Overlap neighbouring rigid parts by about 0.1 stud.
- Flare sleeves and cuffs over the elbows and wrists.
- Robe skirts on the LowerTorso need 0.3 studs of clearance behind the legs at the widest hip swing in the clips. Front robe flaps ride the UpperLegs, as the costume's `RobeFlap` does.
- Beard and mane are rigid to the Head and must clear the chest at full Neck/Waist bend.

**Emission**
- `PbrAssets` validates only the four PBR maps; there is no Neon on skin meshes.
- For glow (P2 blood sigil, ember eyes, glaive edge), place `PointLight` / `ParticleEmitter` / `Beam` children inside the template. `BossSkin` clones them with the template.
- Particle textures must also be owned uploads.

## 3. Model components and triangle-splitting plan

**Budgets**
- At most **22k triangles per phase** in total, and at most **10k per MeshPart** (Roblox caps meshes at 20k).
- Textures: per phase, one 1024² PBR set for body and cloth, plus one 1024² set for head and hair. The weapon gets a 512² set.
- Atlases are shared across that phase's parts, so each image is uploaded once.

### Phase 1: Disciplined Master (ivory robe, indigo mantle, jade, Jian)

| MeshPart | AsuraBone | Contents | Tris |
|---|---|---|---|
| P1_Head | Head | face, ears, brows, moustache | 3,000 |
| P1_Hair | Head | white hair cap, topknot bun, back hair | 1,800 |
| P1_Beard | Head | long white beard (rigid; clears chest) | 1,000 |
| P1_Hairpin | Head | jade hairpin through the bun | 200 |
| P1_UpperTorso | UpperTorso | inner ivory robe, crossed indigo collar, shoulder mantle with gold trim, coat back | 3,000 |
| P1_LowerTorso | LowerTorso | indigo sash, jade buckle, sash tail | 1,200 |
| P1_RobeBack | LowerTorso | rear ivory skirt panel, slight back tilt | 800 |
| P1_UpperArm_L / _R | Left/RightUpperArm | wide ivory sleeve | 800 each |
| P1_LowerArm_L / _R | Left/RightLowerArm | sleeve flare + indigo cuff | 1,000 each |
| P1_Hand_L / _R | Left/RightHand | hands (right hand closed for the grip) | 600 each |
| P1_UpperLeg_L / _R | Left/RightUpperLeg | indigo trouser + front ivory robe flap | 900 each |
| P1_LowerLeg_L / _R | Left/RightLowerLeg | puttee wraps | 500 each |
| P1_Foot_L / _R | Left/RightFoot | cloth shoes | 400 each |
| P1_Weapon_JianGrip | RightHand, Role Weapon | wrapped wooden grip, pommel | 300 |
| P1_Weapon_JianGuard | RightHand, Role Weapon | gold cross-guard | 300 |
| P1_Weapon_JianBlade | RightHand, Role Weapon | straight double-edged steel blade (tip ≈ 6.75 from hand) | 300 |
| P1_Weapon_JianTassel | RightHand, Role Weapon | crimson tassel at the pommel | 200 |

Phase 1 total: about 20.5k.

### Phase 2: Demonic Chimera (torn void robe, crimson horns, mane, Guandao)

| MeshPart | AsuraBone | Contents | Tris |
|---|---|---|---|
| P2_Head | Head | corrupted face, ember-eye sockets | 3,000 |
| P2_Mane | Head | wild pale mane swept back | 2,000 |
| P2_Horns | Head | two crimson horns, swept back and out | 800 |
| P2_Beard | Head | torn beard | 1,000 |
| P2_UpperTorso | UpperTorso | void robe, torn crimson mantle, blood-sigil inset, three spine plates | 3,500 |
| P2_LowerTorso | LowerTorso | sash + rear robe shreds | 1,500 |
| P2_UpperArm_L / _R | Left/RightUpperArm | torn sleeve / exposed arm | 700 each |
| P2_LowerArm_L / _R | Left/RightLowerArm | shredded void sleeve | 900 each |
| P2_Hand_L / _R | Left/RightHand | claw wraps, long nails | 800 each |
| P2_UpperLeg_L / _R | Left/RightUpperLeg | shred flaps | 900 each |
| P2_LowerLeg_L / _R | Left/RightLowerLeg | wraps | 500 each |
| P2_Foot_L / _R | Left/RightFoot | shoes | 400 each |
| P2_Weapon_GlaiveHaft | RightHand, Role Weapon | dark lacquered haft, about 11 studs | 400 |
| P2_Weapon_GlaiveRing | RightHand, Role Weapon | gold collar ring | 300 |
| P2_Weapon_GlaiveBlade | RightHand, Role Weapon | crescent guandao head (tip ≈ 12.7 from hand) | 800 |
| P2_Weapon_GlaiveEdge | RightHand, Role Weapon | thin edge strip, optional PointLight/Beam for the crimson glow | 200 |

Phase 2 total: about 21.9k.

**Palette** (from the current look, so the silhouette change still reads):

| Colour | Hex |
|---|---|
| ivory | #E2DCCC |
| indigo | #2C3456 |
| jade | #60C8A0 |
| gold | #C4A054 |
| hair white | #E8E6E2 |
| steel | #B2B8BE |
| crimson | #D21824 |
| void | #2E1014 |
| torn red | #5A1216 |
| P1 skin | #C4A080 |
| P2 skin | #965C56 |

**Pipeline**
1. Concept sheets (§7) → Rodin.
2. Blender:
   - retopologise and decimate to budget;
   - UV, then bake PBR at 1024;
   - split along the R15 limb boundaries above;
   - pose segments rigidly to the R15 rest pose.
3. Export one FBX per phase, with each part a separate object named as in the tables.
4. Studio 3D Importer: import as MeshParts, set the attributes, upload the maps.

## 4. Animation clips and attack-to-clip mapping

**General rules**
- Clips are R15 KeyframeSequences on the standard Motor6Ds: Root, Waist, Neck, Left/Right Shoulder, Elbow and Wrist, Left/Right Hip, Knee and Ankle.
- **No root motion.** The server moves the HumanoidRootPart (`BossMotion` lunge and aerial).
- Clips are cosmetic. **Contact frames must sit exactly on the server's impact time**, because nothing reads markers.
- The client starts each clip when the cue arrives and plays it at speed 1.
- Priority comes from the slot: Idle loops at Idle priority, attacks play at Action, Transform at Action4.
- A slot is filled by an Animation object named exactly as the key, in `AsuraAssets.AsuraBossAnimations`. `BossAppearance.bindAnimations` copies every `GrandmasterShen_*` id onto the actor at spawn.

**Counter names.** These come from `BossEncounterRules.classify` and are printed on the warning:

| Attack kind | Counter |
|---|---|
| Thrust | Deflect |
| Barrage | Evade |
| Sweep | Double Jump |
| Shockwave / Leap | Air Glide |
| Grab | Slide Dash |

### Required slots (status reaches `Authored 5/5` for P1 and `Authored 6/6` for P2)

| Slot key | Trigger | Server timing to match | Counter | Clip brief |
|---|---|---|---|---|
| `GrandmasterShen_P1_Idle` | idle loop | loop | — | composed jian guard: left palm forward, blade low, slow breath |
| `GrandmasterShen_P1_Strike` | fallback for every ordinary Jian move that telegraphs (Heavy, Running, Art) and any move without its own clip | contact ≈ 0.20 s, total 0.7 s | — | one clean forward cut then a return to guard; generic, because it serves several moves |
| `GrandmasterShen_P1_FlowingJian` | PerilousThrust, 4 pulses, Lunge | first impact 0.80 s after the cue; each later pulse re-sends the cue at the strike and lands 0.65 s later. The client **restarts the clip each pulse**. | Deflect | single lunging thrust: **contact at 0.65 s**, then hold extended to 0.90 s (so the first 0.80 s impact still falls inside the hold); total 1.0 s |
| `GrandmasterShen_P1_PrayerBeads` | Barrage, 7 beads at speed 34 | release at 1.10 s | Evade | draws the prayer-bead string, swings it overhead, flings at 1.10 s; total 1.6 s |
| `GrandmasterShen_P1_AbbotSweep` | PerilousSweep, radius 16 | contact 1.00 s | Double Jump | deep crouch, low shin-height 360° sweep landing at 1.00 s; total 1.5 s |
| `GrandmasterShen_P2_Idle` | idle loop | loop | — | feral wide stance, glaive trailing, shoulders heaving |
| `GrandmasterShen_P2_Strike` | fallback for ordinary Guandao moves | contact ≈ 0.25 s, total 0.9 s | — | two-handed horizontal reap and return |
| `GrandmasterShen_P2_Transform` | BossPhase cue, at the start of the 2.8 s transition | eruption at **1.80 s** (unblockable 32-stud shockwave); clip 2.8 s | — | doubles over, convulses, horns and mane erupt at 1.8, rises into the P2 stance by 2.8. **The P2 template is already bound at 0 s** (the phase publishes before the set change), so animate the P2 body. |
| `GrandmasterShen_P2_BloodWave` | Shockwave, speed 38, height 7, Blood | slam at 1.10 s | Air Glide | glaive raised overhead, slams the ground at 1.10; total 1.7 s |
| `GrandmasterShen_P2_GuandaoSkyfall` | Leap, Aerial, speed 45, radius 28 | landing at 1.50 s | Air Glide | coil, leap pose, downward cleave; impact pose at 1.50; root stays in place (server flies it); total 2.1 s |
| `GrandmasterShen_P2_CrimsonEmbrace` | PerilousGrab, radius 12 | grab at 1.20 s | Slide Dash | arms spread, lunge, claws close at 1.20, recoil; there is no paired victim animation; total 1.8 s |

### Optional slots

The resolver honours these keys, but `AsuraAnimationStatus` does not count them. If missing, they fall back to `_Strike`.

| Slot key | Move (from `WeaponSchema`) |
|---|---|
| `GrandmasterShen_P1_Jian_Heavy` | Falling Star Thrust: 26 startup frames at 60 Hz × tempo |
| `GrandmasterShen_P1_Jian_Running` | Swallow Skims Water |
| `GrandmasterShen_P1_Jian_Art` | Seven Star Flurry |
| `GrandmasterShen_P2_Guandao_Heavy` | Green Dragon Reaping |
| `GrandmasterShen_P2_Guandao_Running` | Charging Dragon Thrust |
| `GrandmasterShen_P2_Guandao_Art` | Crescent Moon Cyclone |

Light attacks send no telegraph cue, so no clip plays for them. That is current behaviour, not part of this delivery.

## 5. VFX cues: what exists, and what the art may add

| Cue | Exists today (code, no asset) | Production addition |
|---|---|---|
| Perilous telegraph | ring sized to the attack's radius (`BossEffects.ring`): crimson, Blood red for BloodWave; billboard "▲ PERILOUS — <counter>" | none needed |
| Prayer-bead projectiles | violet neon sparks (`BossProjectile`) | optional bead mesh/texture; **needs a dev hook** |
| BloodWave / Skyfall hazard | expanding rings (`BossHazard`) | optional crack decal or particle sheet; **needs a dev hook** |
| Phase change | one translucent bloom sized to the body; Colosseum skybox shifts to the ashen set | template-embedded emitters on P2 (sigil glow, ember eyes, glaive edge) ship with the template |
| Weapon arc | the server-validated strike arc (`AsuraStrike` → `WeaponTrails`) | none; the blade tip must match §2 |

## 6. SFX and music cues

| Cue | Status |
|---|---|
| Contact sounds (block, deflect, hit) | exist through `GameFeelController`: Clash, ParryBass, Flesh, Blunt, Stone |
| `BossMusic_GrandmasterShen` | hook exists: an authored Sound in SoundService replaces the `BossDrone` placeholder. Deliver one loop. Intensity is published as an attribute only; there are no stems. |
| Per-attack SFX | **no hook exists yet.** No boss-attack sound plays today. A small dev change in `BossEffects.cue` would play `PresentationAssets.Audio["Shen_<MoveId>"]` on the Telegraph and impact. Add a key only with an owned uploaded id. |

**Per-attack SFX to commission:**
- Shen_FlowingJian: thrust whistle, ×4.
- Shen_PrayerBeads: bead rattle, then whip.
- Shen_AbbotSweep: low whoosh.
- Shen_Transform: choked chant into a roar at 1.8 s.
- Shen_BloodWave: wet slam, then a rolling wave.
- Shen_GuandaoSkyfall: leap gust, then a landing crack.
- Shen_CrimsonEmbrace: lunge, then a claw snap.

## 7. 2D concept sheets to request from ChatGPT (before Rodin)

**Rules for every sheet** (they keep the image usable by Rodin and match §2–3):
- one character only, full body, centred;
- **plain flat mid-grey background (#808080)**, even shadowless studio light;
- no floor, no motion blur, no glow, no particles, no text other than view labels;
- orthographic views at identical scale, 2048 px tall;
- **A-pose**: arms 30° down from horizontal, hands open except where stated, feet shoulder-width;
- clear gaps between arms and torso and between the legs;
- hair and beard as solid sculpted clumps, not loose strands;
- **no weapon in hand** on body sheets.

Paste each prompt as written.

**Sheet 1: Phase 1 body turnaround**
> Character turnaround sheet for a 3D model, orthographic front, left side, back and three-quarter views at identical scale, full body, A-pose with arms 30 degrees down and hands open, feet shoulder-width, plain flat mid-grey background, even shadowless lighting, no weapon. Subject: Grandmaster Shen, an elderly wuxia abbot and sword master, disciplined and upright, lean build. Long white beard in solid sculpted clumps, white moustache and brows, white hair in a topknot bun pierced by a jade hairpin. Ivory inner robe with wide sleeves flaring at the forearm and indigo cuffs, crossed indigo collar, indigo shoulder mantle with thin gold trim, indigo sash with a square jade buckle and one hanging sash tail, ivory robe panels front and back falling to mid-shin and clearly separated from the legs, indigo trousers, puttee wraps, dark cloth shoes. Palette: ivory #E2DCCC, indigo #2C3456, jade #60C8A0, gold #C4A054, hair #E8E6E2, skin #C4A080. Grounded, realistic cloth weight, Southern Chinese martial-monastery costume, no fantasy armour, no glowing parts, no text.

**Sheet 2: Phase 2 body turnaround (same pose and scale as sheet 1)**
> Character turnaround sheet for a 3D model, orthographic front, left side, back and three-quarter views at identical scale to a 5.4-unit-tall human, full body, A-pose with arms 30 degrees down, clawed hands open, plain flat mid-grey background, even shadowless lighting, no weapon, no glow effects. Subject: the same elderly abbot transformed into the Demonic Chimera. Gaunt corrupted body with dusky skin #965C56. Wild pale mane swept back from the head in solid clumps, torn beard, two crimson horns #D21824 sweeping back and outward from the temples, small ember-red eyes painted as flat colour. Robe turned void-black #2E1014 and torn, crimson-red tattered mantle #5A1216 hanging from the shoulders, a diamond-shaped blood sigil on the chest painted as flat crimson, three dark slate spine plates down the upper back, shredded sleeves over the forearms, crimson cloth wraps on the hands with long dark nails, ragged robe shreds behind the legs, clearly separated from the legs. Same silhouette proportions as the phase 1 abbot, so the change reads at a distance. No text.

**Sheet 3: Weapons (two weapons, separate pieces labelled)**
> Orthographic weapon design sheet on a plain flat mid-grey background, even shadowless lighting, side, top and front views at identical scale, each weapon shown assembled and also exploded into its separate pieces with simple labels. Weapon A: a Chinese jian straight sword, total length 6.9 units: wrapped dark wooden grip 1 unit with a round pommel, a short gold cross-guard 0.9 units wide, a straight double-edged steel blade 5.6 units long with a central ridge, and a crimson silk tassel hanging from the pommel. Pieces: grip, guard, blade, tassel. Weapon B: a guandao polearm, total length about 14.5 units: a dark red-black lacquered haft 11 units, a gold collar ring where blade meets haft, and a broad crescent glaive blade 3.4 units long with a thin crimson edge strip and a small back spike. Pieces: haft, ring, blade, edge strip. Realistic forged steel, lacquer and wood; no glow, no particles.

**Sheet 4: Head close-ups, both phases (texture reference)**
> Orthographic head close-up sheet on a plain flat mid-grey background, even shadowless lighting, front, side and back views of the same elderly wuxia abbot's head at identical scale in two rows. Row 1, phase 1: calm stern face, long white beard and moustache in sculpted clumps, white brows, white hair in a topknot bun with a jade hairpin. Row 2, phase 2: the same face corrupted, gaunt, small ember-red eyes painted as flat colour, wild pale mane swept back, torn beard, two crimson horns sweeping back from the temples. No glow, no text except the row labels.

**Sheet 5: Material swatches (for baking and texture painting)**
> A flat material swatch board on mid-grey, eleven labelled square swatches with close-up surface detail under even light: ivory heavy cotton robe #E2DCCC, indigo dyed silk mantle #2C3456, thin gold embroidered trim #C4A054, polished jade #60C8A0, white hair clump #E8E6E2, forged steel blade #B2B8BE, crimson silk tassel #D21824, void-black torn cloth #2E1014, dried-blood red tattered cloth #5A1216, dark red-black lacquered wood, weathered elderly skin #C4A080.

Bring sheets 1, 2 and 3 to Rodin: one body per phase, plus the weapons as separate generations. Sheets 4 and 5 guide the texture bake.

## 8. Studio validation (after delivery, in this order)

1. **Template check (Edit).** Put the template in Workspace over a default R15 rig.
   - Set `MODE = "STAMP"` in `tools/qa/BossTemplateCheck.luau`, run it, then set `MODE = "VALIDATE"` and run it again.
   - Required: **0 failed** for both `NAME`s: 15-limb coverage, AsuraBind, four PBR maps, uploaded MeshIds, scale 1, height 4.6–7.5, weapon tip within ±0.6.
   - Verified this batch on a synthetic template: STAMP wrote 16 binds; VALIDATE passed coverage, scale, weapon tagging and a tip of 6.75. It correctly failed the missing meshes and maps.
2. **Save and build.**
   - Save each template and the animations folder to `assets/models/*.rbxmx`, and add the child mappings (§1).
   - Run `python3 tools/build.py` and `bash tools/verify_all.sh`. The place digest changes; log it.
3. **Play, Shen P1** (seeded entry for the check; the earned run is separate):
   - `AsuraSkinStatus = Template:AsuraBoss_GrandmasterShen_P1`;
   - `AsuraBossSkin.OwnsWeapon = true`, and no costume Jian visible;
   - `AsuraAnimationStatus = Authored 5/5`;
   - `AsuraAnimationPlaying` shows `GrandmasterShen_P1_<Move>|Override` for each perilous move;
   - the blade tip meets the drawn strike arc;
   - capture front, three-quarter and back views from the game camera.
4. **Phase change:**
   - Transform plays;
   - status reads `Template:AsuraBoss_GrandmasterShen_P2` and `Authored 6/6`;
   - the glaive is the template's, not doubled;
   - the ember and sigil emitters render;
   - capture the change mid-clip.
5. **Retry:** death → retry respawns P1 with P1 statuses, and the camera returns to the player.
6. **Fairness:**
   - FlowingJian's held thrust lines up with all four deflect windows (100 ms, unchanged);
   - AbbotSweep reads as low;
   - Skyfall lands on the ring.
7. **Performance:** frame time in Shen's arena with both phases (device hardware pass, backlog item 5).

Until steps 1–6 pass, Shen stays **Blocked — production art**, and the fallback costume and stock tracks are not to be called finished.

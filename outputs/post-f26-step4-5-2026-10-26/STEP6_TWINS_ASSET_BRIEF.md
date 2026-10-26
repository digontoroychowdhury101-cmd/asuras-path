# Step 6 brief: General Zhao, the Iron Bull and the Twins' court

**Status: input contract only.** Nothing below exists yet. There is no `AsuraBoss_GeneralZhao` or `AsuraBoss_IronBull` template, no Twins animation id and no arena prop mesh. In Studio on 26 Oct (build digest 557606020) both bosses report `Fallback:Costume (no AsuraBoss_<Look>_P1 or AsuraBoss_<Look>)`.

The loader, binding, PBR, budget and upload rules are the same as Shen's: see `../post-f26-batch3-2026-10-25/SHEN_ASSET_HANDOFF.md` §1–§3 and §8. This brief only gives what differs for the Twins.

**Updated 26 Oct (step 6 batch): D1 is resolved.** The Bull now fights with his own boss-only `IronBullMaul` (maul and tower shield). §1, §3, §4 and §7 carry the Bull's new numbers; evidence is in `../post-f26-step6-2026-10-26/README.md`.

**Sources:** `BossRoster` (Twins), `BossAttackCatalog` (Zhao, Bull), `WeaponSchema` (Guandao) and `WeaponExpansion.bossSpecs` (IronBullMaul), `LooksDuelists.zhao/bull` (today's costume), `BossAnimationRules` (slots), `BossArenas`, and this batch's README.

## 1. Gameplay numbers the art must match

All numbers are world studs in the live game. Author meshes at scale 1; `BossSkin` scales the template.

| | General Zhao | The Iron Bull |
|---|---|---|
| Role | Fast lightning duelist: thrusts and dashes, attacks every 3.2 s | Slow iron anchor: guards (0.95), attacks every 4 s, no flinch (poise 0.9) |
| Scale | 1.2 → body ≈ 6.5 tall (plumes extra) | 1.7 → body ≈ 9.2 tall (horns extra) |
| HP / posture | 1000 / 240 | 1600 / 460 |
| Sigil (HUD bar and body) | ◆ azure | ▲ amber |
| Server melee | Guandao moveset | **IronBullMaul** (boss-only maul and tower shield, below); not in the 12-weapon player registry |
| Weapon tip from RightHand centre, at scale 1 | **9.2 ± 0.5** (reach 11 / 1.2). Today's costume blade ends at 9.4. | maul head far face **5.7 ± 0.4** along the hand's −Z (maul reach 10 / 1.7 from the root axis). The costume maul was shortened to match (haft 5.2, head at −4.9). |
| Perilous 1 | **Lightning Spear**: thrust, 3 pulses 0.7 s apart, a 5-stud-wide line up to 30 studs, lunges in. Counter: deflect. | **Iron Charge**: shield charge, a 5-wide line up to 50 studs, 1.5 s windup, lunges. Counter: evade (a timed deflect or guard also works). |
| Perilous 2 | **Thunder Quickstep**: charge line up to 35 studs, 1.0 s windup. Zhao has no shield, so it reads as a glaive-levelled thunder dash. | **Colossal Hammer**: ground shockwave ring out to 65 studs at 26 studs/s, 7 studs high, 1.8 s windup. Counter: jump or glide. |
| After the partner falls | Oath of the Fallen: full heal, Lightning+Iron tint, adds the Bull's two perilous attacks | Oath of the Fallen: adds Zhao's two perilous attacks |

**Zhao's melee moves** (seconds at the 1.4 tempo; clips must hit these frames):

| Move id | Name | Startup | Active | Recovery | Reach | Arc |
|---|---|---|---|---|---|---|
| Guandao_L1 | Crescent Reap | 0.150 | 0.067 | 0.183 | 10.5 | 120° sweep |
| Guandao_L2 | Returning Tide | 0.150 | 0.067 | 0.200 | 10.5 | 120° back-sweep |
| Guandao_L3 | Heaven-Splitting Cleave | 0.183 | 0.067 | 0.267 | 11.0 | 30° overhead |
| Guandao_Heavy | Green Dragon Reaping | 0.383 | 0.067 | 0.383 | 12.0 | 160° |
| Guandao_Running | Charging Dragon Thrust | 0.217 | 0.067 | 0.317 | 12.5 | 15° thrust, lunge 8 |
| Guandao_Art | Crescent Moon Cyclone | 0.317 | 0.183 | 0.400 | 11.5 | 360° spin |

**The Bull's melee moves (`IronBullMaul`).** Reach is measured from the root and does not scale with the 1.7 body. An arc of 40° or less is validated and drawn as a straight line; wider arcs are a fan swept left to right. "Measured" is the seeded Studio fight: the server state times, and the committed strike record the client draws.

| Move id | Name | Motion the clip must show | Startup | Active | Recovery | Reach | Arc | Lunge | Measured startup / record |
|---|---|---|---|---|---|---|---|---|---|
| IronBullMaul_L1 | Iron Hook | maul hook, right to left, shield held in | 0.217 | 0.067 | 0.283 | 9.5 | 100° fan | 1.5 | 0.233 / 100° 9.5 1.5 |
| IronBullMaul_L2 | Shield Ram | tower shield punched straight out | 0.167 | 0.067 | 0.267 | 7.0 | 36° line | 3.0 | 0.183 / 36° 7.0 3.0 |
| IronBullMaul_L3 | Anvil Drop | maul raised overhead, dropped vertically (finisher) | 0.317 | 0.067 | **0.500** | 10.0 | 24° line | 2.5 | 0.333 / 24° 10.0 2.5 |
| IronBullMaul_Heavy | Ox-Yoke Crush | shield up, maul crashes down diagonally; hyper armour | 0.517 | 0.083 | **0.600** | 10.5 | 70° fan | 2.0 | 0.533 / 70° 10.5 2.0 |
| IronBullMaul_Running | Rampart Rush | shield-first rush | 0.283 | 0.083 | 0.433 | 8.0 | 40° line | 7.0 | not thrown in the runs |
| IronBullMaul_Art | Bell-Breaker | wide front sweep, both hands; the back stays open; hyper armour | 0.433 | 0.117 | **0.617** | 9.5 | 200° fan | 1.0 | 0.450 / 200° 9.5 1.0 |

**Measured timing.** Measured startups run one 60 Hz tick (+0.016 s) over spec. That is the server's step, not a drift.

**Recovery.** Every recovery is at least as long as the guandao slot it replaces. L1 and L2 chain into the next hit inside their combo window.

**Punish.** Lights placed at the Bull's back at the start of recovery landed every time (23/23, armoured: damage without flinch). From the front, 10 of 25 were guarded, because the shared rule lets any fighter raise a guard out of recovery. So the shield closes the front, and the back is the punish.

**Damage.** Per hit: L1 15, L2 8, L3 22, Heavy 32, Rush 16, Art 30. Posture: 20, 26, 30, 46, 34, 50. All blunt.

**Fight geometry** (Studio, after this batch):
- Zhao engages 6.3 studs from the player's root and the Bull 5.7 (0.6 × the first light's reach); Studio spread 66–84° with the maul.
- The two stand at least 7.25 apart, typically 60–90° apart around the player.
- The camera sits 8–16 studs behind the player at shoulder height. A Twin standing between the lens and the player is drawn at 0.6 transparency (`CameraClearance`).

## 2. Silhouettes (must read in grayscale, at 40 studs and at 6 studs)

**Zhao is vertical and linear.**
- Lacquered lamellar general with a tall twin pheasant-plume helm and two back pennant poles.
- A long red-hafted guandao with a steel crescent blade and an azure lightning edge.
- Narrow waist, long coat panels, an azure ◆ on the chest and helm.
- Read: three tall verticals above the head, plus one long horizontal line (the glaive).

**The Bull is wide and massive.**
- Iron-plated giant with a bull helm, swept bone horns (span ≈ 3.4 at scale 1), huge round pauldrons and an ox-hide cape.
- A tower shield on the left forearm: 3.2 × 4.6 at scale 1, so 5.4 × 7.8 in game, with a bronze rim and an amber ▲ sigil.
- A short-hafted iron maul in the right hand.
- Read: a horizontal block with horns. The shield covers the left half of the torso from the front.

**Never share these:** Zhao must not carry a shield or horns, and the Bull must not carry plumes or a long polearm. Both are hostile red-trimmed but different hues: Zhao is azure and lacquer red, the Bull is iron, bronze and amber.

## 3. Rig and limb separation (one rigid MeshPart per limb, as in the Shen contract)

### Zhao: `AsuraBoss_GeneralZhao` (≤ 22k triangles)

- **Head:** head, moustache and goatee; helm bowl and brim; neckguard; plume pair (rigid, clears the back pennants); azure crest.
- **UpperTorso:** lamellar rows, chest ◆, pauldron pair, pennant poles and flags (rigid, swept back).
- **LowerTorso:** gold belt, coat back and hem.
- **Upper legs:** coat front flaps and tassets.
- **Lower arms:** bracers. **Lower legs:** greaves.
- **Weapon** (`AsuraRole=Weapon`, binds to RightHand): haft, blade, lightning edge and tassel. Tip 9.2 along the hand's −Z.

### Bull: `AsuraBoss_IronBull` (≤ 22k triangles)

- **Head:** bull helm, amber visor slit, horn pair.
- **UpperTorso:** breastplate, plate bands, pauldrons, ox-hide cape (rigid; 0.3 clearance behind the legs).
- **LowerTorso:** iron belt, front tasset.
- **Arms:** arm plates and gauntlets.
- **Shield:** on **LeftLowerArm** (`AsuraBone=LeftLowerArm`, **not** `AsuraRole=Weapon`; weapon parts bind only to RightHand).
- **Legs:** thigh plates, greaves, sabatons.
- **Weapon** (`AsuraRole=Weapon`): maul haft (≈ 5.2 long, 0.36 thick), iron head 1.3 × 1.3 × 1.6, bronze band. Far face 5.7 from the hand. Shield face 3.2 × 4.6 × 0.45 (bronze rim 3.45 × 4.85), its front plane about 1.2 ahead of the forearm, so the Shield Ram reads as reaching 7 studs once lunged.

**Both templates**
- Phase-less names (single phase).
- Glow comes from `PointLight` or `ParticleEmitter` children, not Neon meshes.
- 1024² PBR body set, 512² weapon set, owned uploads only.

## 4. Animation slots (published Animation objects in `AsuraBossAnimations`)

**Per look** (`BossAnimationRules.slots`):
- `GeneralZhao_P1_` + `Idle`, `Strike`, `Transform`, `LightningSpear`, `ThunderQuickstep`
- `IronBull_P1_` + `Idle`, `Strike`, `Transform`, `IronCharge`, `ColossalHammer`, then one clip per maul move: `IronBullMaul_L1`, `_L2`, `_L3`, `_Heavy`, `_Running`, `_Art` (`BossAnimationRules.Melee`)

That is 5 + 11 clips. The server now cues every Bull swing (`BossSwing` for lights, `Telegraph` for the rest), so each slot plays on its own swing; with nothing authored, the stock strike stands in.

| Clip | Timing rule |
|---|---|
| `Transform` | The Oath. 1.1 s camera shot; first impact no sooner than 2.35 s after it starts. |
| Perilous clips | Windup equals the catalog windup: 0.8, 1.0, 1.5, 1.8 s. Lightning Spear needs three thrusts 0.7 s apart. The Hammer lands on the ground at impact. |
| Zhao melee | Guandao swings: no per-move boss slot yet (Zhao plays `Strike` on heavies and arts only). |
| Bull melee | One clip per maul move. The windup equals the move's startup, the impact frame is the first active frame, and recovery runs as long as listed in §1. The weapon must sweep the arc the server draws: a hook left to right for L1, a straight ram for L2, a vertical drop for L3. |

The Bull's shield must stay in front during `Idle`/`Strike` and lead the `IronCharge`. Zhao's left hand rests on the haft by animation; there is no IK.

**Not finished:** stock R15 tracks currently stand in (`Fallback:Stock`). They are placeholders, not delivered animation.

## 5. Decisions needed before modelling

- **D1. Bull melee: resolved (option b).** The Bull uses the boss-only `IronBullMaul` moveset in §1, through the same server combat and hit validation as every fighter. Model and clips follow §1, §3 and §4.
- **D2. Scale.** Keep 1.2 / 1.7. Changing scale moves hurtboxes, the flank gap and the camera numbers above.

## 6. Arena props that matter to the fight

**What exists today**
- The court is a flat 180 × 180 slate floor (tone 118/110/100) at x 210–390, z −1020…−840.
- A ForceField perimeter.
- A 26 × 24 fog aperture on the north wall at (300, −840).
- Bosses stay 12 studs inside the walls.

**Deliver separately, one object per Rodin job**

1. **North gate frame.** A timber and stone gate around the 26-wide aperture, no deeper than 3 studs into the court. Studio: the camera crushes against the north berm when the player fights at the gate (`views/g01_…`).
2. **Perimeter.** A low broken parapet (≤ 3 tall) or cliff face in place of the ForceField walls. It must be collidable at its footprint, with no overhangs into the court.
3. **Two empty sentinel plinths.** Lore anchors **outside** the court, flanking the approach at (284, −832) and (316, −832), clear of the 26-wide aperture. They are seen from the plateau on the walk in and are never in the fight.
4. **Floor inlays.** Flush (0 height) ◆ and ▲ inlays. Nothing that changes footing or reads as a hazard.

**Rules for all props**
- Nothing taller than 3 studs inside the court: lunges, shockwaves (7 high) and the 8–16 stud camera need open air.
- No prop between the gate and the centre: that is the entry sightline.
- Props are world geometry (`WorldGeometry` group) so the camera probe meets them.

## 7. Sheet prompts

### ChatGPT 2D sheets (one sheet per object)

Every sheet is orthographic front, side, back and three-quarter, on a neutral grey background, with a scale bar in studs. Each body sheet adds:
- a grayscale silhouette strip;
- the R15 limb-split overlay (§3);
- the tip-distance callout (§1).

1. **Zhao body.** "General Zhao of the Twin Sentinels, wuxia lacquered-lamellar general, tall twin pheasant plumes and two back pennants, azure ◆ chest sigil, coat panels, at scale 1 about 5.4 studs tall; R15 rest pose, arms down; no weapon." Plus a combat-distance strip: the figure at 6, 12, 20 and 40 studs from a 10-stud-behind third-person camera.
2. **Zhao guandao.** Red haft, steel crescent blade, azure lightning edge, tassel. Grip at the origin, tip 9.2 along −Z. Front, side and edge-on.
3. **Bull body.** "The Iron Bull, giant iron-plated sentinel, bull helm with amber visor slit, swept bone horns, round pauldrons, ox-hide cape; R15 rest pose; no shield or maul." Plus the same distance strip at 1.7 × size, and a pair view beside Zhao at 7 studs apart.
4. **Bull tower shield.** 3.2 × 4.6 × 0.45, bronze rim, amber ▲. Strap side shown; mounts on the left forearm.
5. **Bull maul.** Iron head 1.3 × 1.3 × 1.6, haft about 5.2, bronze band. Far face 5.7 from the grip. Add a motion strip: Iron Hook (side sweep), Anvil Drop (overhead), Ox-Yoke Crush (diagonal behind the raised shield), Bell-Breaker (wide front sweep), each from above with the arc and reach of §1 drawn on the floor.
6. **Bull shield actions.** Shield Ram and Rampart Rush key poses: the shield face square to the target and 7 / 8 studs of reach marked from the root.
7. **Gate frame**, 8. **parapet module**, 9. **sentinel plinth**: one sheet each, sizes from §6.

### Rodin

Each sheet goes in as its own job, giving one object per mesh. After generation:
- split the body meshes per §3 in Blender;
- upload under the experience owner.

Validate in Studio with `tools/qa/BossTemplateCheck.luau`, then a seeded Twins entry. Pass condition:
- `AsuraSkinStatus = Template:AsuraBoss_GeneralZhao` / `…IronBull`;
- `OwnsWeapon true`;
- a camera sample with `tools/qa/TwinsCamera.client.luau`.

Then record the result with captures.

# Step 6 brief: General Zhao, the Iron Bull and the Twins' court

**Status: input contract only.** Nothing below exists yet. There is no `AsuraBoss_GeneralZhao` or `AsuraBoss_IronBull` template, no Twins animation id and no arena prop mesh. In Studio on 26 Oct (build digest 557606020) both bosses report `Fallback:Costume (no AsuraBoss_<Look>_P1 or AsuraBoss_<Look>)`.

The loader, binding, PBR, budget and upload rules are the same as Shen's: see `../post-f26-batch3-2026-10-25/SHEN_ASSET_HANDOFF.md` §1–§3 and §8. This brief only gives what differs for the Twins.

**Sources:** `BossRoster` (Twins), `BossAttackCatalog` (Zhao, Bull), `WeaponSchema` (Guandao), `LooksDuelists.zhao/bull` (today's costume), `BossAnimationRules` (slots), `BossArenas`, and this batch's README.

## 1. Gameplay numbers the art must match

All numbers are world studs in the live game. Author meshes at scale 1; `BossSkin` scales the template.

| | General Zhao | The Iron Bull |
|---|---|---|
| Role | Fast lightning duelist: thrusts and dashes, attacks every 3.2 s | Slow iron anchor: guards (0.95), attacks every 4 s, no flinch (poise 0.9) |
| Scale | 1.2 → body ≈ 6.5 tall (plumes extra) | 1.7 → body ≈ 9.2 tall (horns extra) |
| HP / posture | 1000 / 240 | 1600 / 460 |
| Sigil (HUD bar and body) | ◆ azure | ▲ amber |
| Server melee | Guandao moveset | Guandao moveset as well (see §5, decision D1) |
| Weapon tip from RightHand centre, at scale 1 | **9.2 ± 0.5** (reach 11 / 1.2). Today's costume blade ends at 9.4. | maul head far face **6.5 ± 0.4** (reach 11 / 1.7). Today's costume ends at 6.4. |
| Perilous 1 | **Lightning Spear**: thrust, 3 pulses 0.7 s apart, a 5-stud-wide line up to 30 studs, lunges in. Counter: deflect. | **Iron Charge**: shield charge, a 5-wide line up to 50 studs, 1.5 s windup, lunges. Counter: evade (a timed deflect or guard also works). |
| Perilous 2 | **Thunder Quickstep**: charge line up to 35 studs, 1.0 s windup. Zhao has no shield, so it reads as a glaive-levelled thunder dash. | **Colossal Hammer**: ground shockwave ring out to 65 studs at 26 studs/s, 7 studs high, 1.8 s windup. Counter: jump or glide. |
| After the partner falls | Oath of the Fallen: full heal, Lightning+Iron tint, adds the Bull's two perilous attacks | Oath of the Fallen: adds Zhao's two perilous attacks |

**Melee moves**, the same for both today (seconds at the 1.4 tempo; clips must hit these frames):

| Move id | Name | Startup | Active | Recovery | Reach | Arc |
|---|---|---|---|---|---|---|
| Guandao_L1 | Crescent Reap | 0.150 | 0.067 | 0.183 | 10.5 | 120° sweep |
| Guandao_L2 | Returning Tide | 0.150 | 0.067 | 0.200 | 10.5 | 120° back-sweep |
| Guandao_L3 | Heaven-Splitting Cleave | 0.183 | 0.067 | 0.267 | 11.0 | 30° overhead |
| Guandao_Heavy | Green Dragon Reaping | 0.383 | 0.067 | 0.383 | 12.0 | 160° |
| Guandao_Running | Charging Dragon Thrust | 0.217 | 0.067 | 0.317 | 12.5 | 15° thrust, lunge 8 |
| Guandao_Art | Crescent Moon Cyclone | 0.317 | 0.183 | 0.400 | 11.5 | 360° spin |

**Fight geometry** (Studio, after this batch):
- Each Twin engages 6.3 studs from the player's root.
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
- **Weapon** (`AsuraRole=Weapon`): maul haft, head and band. Far face 6.5 from the hand.

**Both templates**
- Phase-less names (single phase).
- Glow comes from `PointLight` or `ParticleEmitter` children, not Neon meshes.
- 1024² PBR body set, 512² weapon set, owned uploads only.

## 4. Animation slots (published Animation objects in `AsuraBossAnimations`)

**Per look** (`BossAnimationRules.slots`):
- `GeneralZhao_P1_` + `Idle`, `Strike`, `Transform`, `LightningSpear`, `ThunderQuickstep`
- `IronBull_P1_` + `Idle`, `Strike`, `Transform`, `IronCharge`, `ColossalHammer`

That is 5 + 5 clips.

| Clip | Timing rule |
|---|---|
| `Transform` | The Oath. 1.1 s camera shot; first impact no sooner than 2.35 s after it starts. |
| Perilous clips | Windup equals the catalog windup: 0.8, 1.0, 1.5, 1.8 s. Lightning Spear needs three thrusts 0.7 s apart. The Hammer lands on the ground at impact. |
| Melee | Plays the six Guandao move animations (`Guandao.CrescentReap` …) from the weapon catalog. For the Bull these are glaive motions on a maul: see D1. |

The Bull's shield must stay in front during `Idle`/`Strike` and lead the `IronCharge`. Zhao's left hand rests on the haft by animation; there is no IK.

**Not finished:** stock R15 tracks currently stand in (`Fallback:Stock`). They are placeholders, not delivered animation.

## 5. Decisions needed before modelling

- **D1. Bull melee.** Today the server swings a guandao for the Bull: 120° sweeps at 10.5–12 studs. A maul and shield fighter needs either:
  - (a) maul clips timed to the six Guandao moves, keeping the reach the art is sized to here; or
  - (b) a dev step adding a Bull moveset (shorter arcs, shield bash), then new clip timings.

  Pick before animation. The model in §3 fits both.
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
5. **Bull maul.** Iron head 1.3 × 1.3 × 1.6, haft about 6, bronze band. Far face 6.5 from the grip.
6. **Gate frame**, 7. **parapet module**, 8. **sentinel plinth**: one sheet each, sizes from §6.

### Rodin

Each sheet goes in as its own job, giving one object per mesh. After generation:
- split the body meshes per §3 in Blender;
- upload under the experience owner.

Validate in Studio with `tools/qa/BossTemplateCheck.luau`, then a seeded Twins entry. Pass condition:
- `AsuraSkinStatus = Template:AsuraBoss_GeneralZhao` / `…IronBull`;
- `OwnsWeapon true`;
- a camera sample with `tools/qa/TwinsCamera.client.luau`.

Then record the result with captures.

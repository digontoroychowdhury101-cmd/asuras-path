# Batch C (10–13): boss animation dispatcher, six sovereigns, cast identity — 25 October 2026

Original batches 11–14. Findings #13 #16 #17 #23 #24.

## Build and evidence
- Start HEAD `f05c720` (digest 591768240). End: `places/AsurasPath.rbxlx` rebuilt, Studio Edit place synced and read back: **scripts 253, bytes 1,817,788, digest 1870254957** (Studio = build). Temporary Edit-mode probe scripts (`QAProbeB10*`) were removed before the digest read.
- Local regression / engine emulation: `bash tools/verify_all.sh` SUCCESS → `F10_13_VERIFY_LOG.txt`. Focused: boss_presentation 197 (+72), boss_runtime 30 (+5), rest_dialogue 67 (+4), cast_visuals 48, progression_runtime 89, combat_contact 68.
- Studio evidence is **seeded Studio diagnostic** unless marked: server pivots into each arena, KO protection, HP seeded for phase 2, `ApplyArea` from the player for kills, a client render-step camera for close views. **Real Studio play** items are marked (keys/clicks through the injector). Nothing is earned continuous-input play; the seeded Wyrm kill is not an earned victory. Viewport 1221×503. Views in `f10-13-views/`.

## Defects found and fixed (each regression fails on the old code)
| # | Defect (reproduced in Studio) | Fix | Check |
|---|---|---|---|
| 1 | Boss animation was Shen-only: every humanoid boss (Zhao, Bull, Wu, Titan) played Shen's four placeholder keys, attack ids were ignored, overrides were Shen-named only and nothing reported what was a stand-in | New `BossAnimationRules` (shared): `<Look>_P<n>_<Action>` → `<Look>_<Action>` → Strike fallbacks; actor override attribute, then authored `Custom`, then stock-by-kind (humanoid) or `Procedural` (creature). `BossAnimations` requests per actor/phase/attack (telegraph `move`/`kind`), re-resolves on phase change. `BossAppearance` binds imported `AsuraAssets.AsuraBossAnimations` Animation objects per look at spawn and writes `AsuraAnimationStatus`. `CreatureMotion` releases its welds while an authored track owns them (`AsuraAuthoredMotion`). No gameplay reads tracks/markers. | presentation +66 (resolver, status, binding, client dispatcher with fakes); Studio below |
| 2 | Phase-2 skin resolved `_P1`: the phase index was published only after the 2.8 s transition, but the skin rebinds on the set change at its start | `BossAppearance.phase` publishes `AsuraBossPhase` before `AsuraAnimationSet` | presentation +2; Studio: Shen P2 status names `AsuraBoss_GrandmasterShen_P2` |
| 3 | Shen's Flowing Jian lunge ended inside the player (0.2 studs) and climbed onto them (dy 4) | `BossMotion.approach`: Lunge/Aerial end a body short of the mark on the boss's side; hits still use the marked origin/aim (timing/damage unchanged) | runtime +1; Studio min 3.0 studs, dy 0.2 |
| 4 | The Twins stacked into one body (0.6–0.9 studs apart while chasing) | `Bodies.flank` + `AIService.closeIn`: a Twin swings round the target clear of its living partner | presentation +4; Studio 30 s: 0/100 then 105/200 samples < 5 → steady 4.9–6.8, never overlapping |
| 5 | Baize's Meteor Pounce landed exactly on the player (0.0) and stood on them | Pillar flights land a body short of the mark on the perch side | runtime +1; Studio landings 9.7 studs |
| 6 | After a kneel the Titan's HipHeight was reset to a constant 6 (scaled stand 6.58): feet sank 0.58 into the floor | `BossTactics` restores the stored standing height | runtime +2; Studio before/kneel/after 6.58/0.00/6.58, feet 0.00 |
| 7 | A Wyrm killed in flight was set on the floor, then `Motion.cancel` restored its pre-flight unanchored root and it fell through the arena (y −26) while dissolving | a KO'd body keeps settleCorpse's anchor | runtime +1; Studio killed at y 20.3 → pinned at 7.0, dissolved, removed 3.8 s, 0 leftovers |
| 8 | Gao's portrait looked straight down on his topknot (camera y 611): dialogue only searched `JadeCataclysm`, so his own body blocked every shot | `PortraitCamera.speaker` resolves `AsuraNPC`-tagged models; Gao is tagged | rest_dialogue +4; Studio: shoulder shot, face at 0.30 of height (real key hold) |

## 10 — dispatcher, Shen, Twins
- Live dispatcher (client attribute log): Shen requested `GrandmasterShen_P1_FlowingJian`, `_PrayerBeads`, `_P1_Jian_Heavy` (Strike fallback) and `_P1_Idle`, all `Stock`; Zhao `GeneralZhao_P1_LightningSpear`, Bull `IronBull_P1_ColossalHammer`/`_IronCharge`; Wu `SovereignWu_P1_StarlessSingularity`; creatures `…|Procedural`.
- Overrides consumed: look-wide `AsuraBossAnimation_GrandmasterShen_Idle/_Strike` (real stock ids, interface test only) set during phase 2 → client played them as `Override`; status `Fallback:Stock 5/6 authored (first missing GrandmasterShen_P2_Transform)`; removed afterwards.
- Shen P1 (grey robe, Jian) and P2 (horns, guandao, red cloth, "Demonic Chimera") render; death → retry respawns a fresh P1 (900/900) with P1 statuses; camera returns to the player (Scriptable controller, 11 studs).
- Twins: two named bars (◆ General Zhao, ▲ The Iron Bull) with the lock hint; **real X key** locked Zhao (row stroke 2 px); on Zhao's KO the row reads FALLEN, the Bull swears "Oath of the Fallen" and the lock clears. Mouse-flick switching could not be driven: the injector's absolute moves send no look delta under the locked cursor → human.

## 11 — Baize, Titan
- Baize: `AsuraRig=Creature`, scale 1.5, hull 3.3×2.25×7.5; paws 0.29 above the floor when standing; perch on a frost pillar 0.2 above its top; phase 2 tint/spines; status `Fallback:CreatureMotion 0/n`. Walking spacing (1.3–2.5 studs from the player) comes from claw reach and was left unchanged.
- Titan: scale 3, extents 13.5×21.1×6.3, feet on the floor; kneel → head deathblow height → rises to 6.58. **Real M1 clicks** from 5 studs at the ankles landed two light hits (1590 → 1574). At 1221×503 the boss bar hides the Titan's upper body at 26–34 studs → 24.

## 12 — Wu, Wyrm
- Wu: four teleports, each 17–35 studs, landing with no colliding part in a 3×5×3 box, floor beneath, 12 studs inside the arena wall; P1/P2 casting looks render.
- Wyrm: flight to y 64, landings 8.4–8.8 studs from the player after fix 3; killed in flight → fix 7. Silhouette reads as a blue winged quadruped at 30 studs.

## 13 — player, NPCs, enemies
- Player (seeded): one `AsuraAttire` (36 pieces), 0 detached, late Accessory+Shirt stripped, head replaced while alive (RequiresNeck off) → re-dressed on the live head, 0 loose parts; weapon grip 0.16 from the hand, blade 4.2.
- Portraits (real key hold): Gao after fix 8; Hermit face at 0.30, 7.3 studs; Lin covered in F04.
- **Open — Gao prompt conflict:** the Transmutation Seal (`LootWorld`, `Loggia.X+5`) stands 7 studs in front of Gao, where a player stops to talk; both prompts use Z with OnePerButton, so from the front "Transmute Remembrance" always wins and Gao's dialogue only opens from his side. Moving the seal is a layout decision; not changed.
- Enemy silhouettes and dissolves: not re-captured here; 07's seeded monk/swordsman deaths stand.

## Art status (Blocked — production art)
`ServerStorage.AsuraAssets` has 13 environment templates and **no** `AsuraBoss_*` or cast templates; every boss reports `Fallback:Costume (no AsuraBoss_<Look>_P<n> …)` and `Fallback:Stock`/`Fallback:CreatureMotion 0/5–6 authored`. Nothing was fabricated. Required delivery (unchanged contract, now consumed by the resolver):
- Models: `AsuraBoss_GrandmasterShen_P1/_P2`, `AsuraBoss_GeneralZhao`, `AsuraBoss_IronBull`, `AsuraBoss_VenerableBaize_P1/_P2`, `AsuraBoss_SlumberingTitan_P1/_P2`, `AsuraBoss_SovereignWu_P1/_P2`, `AsuraBoss_AzureWyrm_P1/_P2` — MeshParts with uploaded mesh + SurfaceAppearance owned by the experience owner, `AsuraBone` per R15 limb (creatures: `HumanoidRootPart`), aligned `AsuraBind` Attachments, authored at scale 1 (BossSkin applies `GetScale`: Shen 1, Zhao 1.2, Bull 1.7, Baize 1.5, Titan 3, Wu 1.2, Wyrm 2.2), weapon left as `AsuraRole=Weapon`.
- Animations: published Animation ids as `Animation` objects in `ServerStorage.AsuraAssets.AsuraBossAnimations` named by slot (`<Look>_[P<n>_]<Idle|Strike|Transform|MoveId>`; slot lists from `BossAnimationRules.slots`, 5–6 per phase), or ids in `BossAnimationRules.Custom`. Creature tracks need joints that the creature skin carries.
- Cast: portrait-quality Lin/Hermit/Gao/player/monk/swordsman bodies through `CastFigures`/`FighterAppearance`/`EnemyAppearance` (current figures are primitive pieces).
- Still required after delivery: Studio view of each skin per phase, `AsuraSkinStatus = Template:…`, `AsuraAnimationStatus = Authored n/n`, no double transform on creatures.

## Remaining (exact)
- Production art above (#23, #24).
- Human: flick/stick lock switching between the Twins; Twins flanking fairness; earned fights of all six (22).
- Gao: decide whether the Transmutation Seal moves off Gao's front or the dialogue becomes the only Z prompt there.
- 24: boss bar hides the Titan's upper body and the perilous warning overlaps the duo bars at 1221×503.
- Not exercised in Studio: entry skip key and first-impact grace (local regression only).

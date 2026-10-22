# Concrete asset delivery still required

This is an input contract, not proof that the assets exist. The current Phase 5 library exists and builds; the audit found 13 imported templates / 56 complete PBR MeshParts in the existing audiovisual check, but no `AsuraBoss_*` models. The imported shrine centerpiece is not a boss rig. Use existing approved authoring/import tools when they can supply actual files. Missing art must stay open; do not fabricate uploaded IDs or replace a missing rig with a renamed primitive and call it finished.

Boss models belong in `ServerStorage.AsuraAssets` through the current saved-library/Rojo pipeline. Use `CostumeSchema.templates` and `BossSkin` as the actual contract: phase-specific `AsuraBoss_<LookKey>_P<n>`, then base look key, then documented legacy fallback. MeshParts need valid uploaded mesh/SurfaceAppearance content, an `AsuraBone` attribute and aligned `AsuraBind` Attachment for the supported rig. Validate coverage, scale, weapon separation and the live actor's `AsuraSkinStatus`. Do not hide the fallback before a valid replacement is bound.

| Owner | Models | Required delivery |
|---|---|---|
| 10 | `AsuraBoss_GrandmasterShen_P1`, `_P2`; `AsuraBoss_GeneralZhao`; `AsuraBoss_IronBull` | Disciplined master/demonic phase; distinct narrow Zhao and broad shielded Bull; per-attack humanoid animation and phase transform; exact look/attack lookup on live actors. |
| 11 | `AsuraBoss_VenerableBaize_P1`, `_P2`; `AsuraBoss_SlumberingTitan_P1`, `_P2` | Creature root binding within BossBodies.Beast; grounded paws/pounce; Titan ankle/kneel and weapon/camera access; valid rig joints and phase tracks. |
| 12 | `AsuraBoss_SovereignWu_P1`, `_P2`; `AsuraBoss_AzureWyrm_P1`, `_P2` | Wu cast/teleport; Dragon capsule-aligned body/tail, articulated wings, flight/landing/defeat; valid joint names and phase tracks. |
| 13 | Player, Lin, Hermit, Gao, monk/swordsman | Portrait-quality hair/face/apparel with supported avatar rebinding, weapon grip, collision and cleanup. Exact template names must follow the current cast loader; verify rather than invent names. |
| 16–20 | Bamboo clumps; colosseum tiers/arcades; crypt vault/sarcophagus/niches; pagoda eaves/towers/rafters; citadel towers/battlements | Region-specific MeshPart kits with consistent studs/texture scale, mapped PBR, current dressing integration and preserved collision boxes. |
| 25 | `BossMusic_<bossId>` for actual current roster IDs if bespoke tracks are delivered | Real playable approved/original audio, live asset access, correct transition/mix/lifetime. Current shared BossDrone is a placeholder; names/IDs alone are not tracks. |

The old handoff's nominal actor scales are Shen 1, Zhao 1.2, Bull 1.7, Baize 1.5, Titan 3, Wu 1.2, Wyrm 2.2. Reconfirm actual `CostumeSchema`, `BossBodies`, roster and `Model:GetScale()` before authoring; do not bake the scale twice. Creature joint/pose ownership must avoid double transforms when Motor6D animation replaces procedural CreatureMotion. Keep the held weapon separate where BossSkin expects it.

Animation dispatcher gap: `BossAnimations` currently requests only `Shen_Phase1_Idle`, `Shen_Phase1_SwordCombo`, `Shen_Phase2_Transform`, `Shen_Phase2_GlaiveCombo`. `AnimationCatalog` currently has 45 custom-empty slots. `AsuraBossAnimation_<key>` is only an override interface; a real imported track must be assigned to the actor and actually requested. Prompt 10 owns the shared resolver; prompts 11–12 supply their content/integration. Cosmetic animation must not become client-authoritative damage.

For an unavailable deliverable, record: exact model/animation/cue, source/license or original author, local file, rig/bind/scale contract, import/ownership requirement, loader destination, available fallback, and the engine view/play evidence still required. Do not request an entire asset library when only one encounter is blocked.

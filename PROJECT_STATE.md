# ASURA'S PATH (修羅之道) — LIVING PROJECT STATE & HANDOVER JOURNAL

> **Last Updated**: 2026-10-19 01:05  
> **Status**: UX/onboarding overhaul on branch `ux/onboarding-overhaul` (Studio-verified via Rojo sync).  
> **Built Target**: `outputs/AsurasPath.rbxlx` — NOT rebuilt this pass (still holds the pre-fix SanctuaryService parse error); rebuild with `tools/build.py` once Studio's open copy is saved/closed.

---

## 1. PROJECT IDENTITY & PILLARS
- **Genre**: Grimdark Wuxia Souls + High-Tempo Action Combat Hybrid.
- **Combat Core**:
  * 1.4× Tempo baseline (`src/simulation/Tempo.luau`).
  * Hybrid Weapons: Unarmed Fists, Jian (Sword), Dao (Sabre), Guandao (Glaive) in `src/simulation/WeaponSchema.luau`.
  * Sekiro-style Posture & 100ms Deflect: Posture buildup, Deflect sparks, StanceBreak stun, cinematic Deathblows in `src/simulation/CombatRules.luau`.
  * Blood Rally & Tri-Layer HP: ActiveHP, RecoverableHP (debt restored via aggressive counter-attacks), PermanentDeficit in `src/shared/CombatSettings.luau`.
  * 60 Hz Circular Ring Buffer Lag Compensation with 150ms max rewind in `src/server/LagCompensation.luau`.
- **PvE Story Mode**:
  * Semi-open overworld regions: Desecrated Monastery, Bamboo Pass, Ash Pagoda in `src/shared/WorldDefinitions.luau`.
  * Incense Altar (bonfire) checkpoints, Lost Qi / bloodstain death drops in `src/server/Services/WorldService.luau`.
  * Mob AI and multi-phase Boss engine (Grandmaster Shen / Demonic Chimera) in `src/server/Services/AIService.luau`.
- **PvP Colosseums**:
  * Overworld dueling rings with 1v1 Ranked (normalized stats) and Casual sparring in `src/server/Services/ColosseumService.luau`.
- **Client Presentation**:
  * Third-Person Over-the-Shoulder Camlock (offset: 1.8, 1.4, 10.5) in `src/client/Controllers/CameraController.luau`.
  * Game Feel: Sparks, hit-stop, camera shake, concussive eye trauma blur/sway in `src/client/Controllers/GameFeelController.luau`.
  * Minimalist Souls HUD in `src/client/Controllers/InterfaceController.luau`.

---

## 2. ACTIVE DIRECTORY STRUCTURE & MAP
```text
/Users/digonto/Documents/ChatGPT/Roblox game 2/
├── default.project.json              # Rojo tree (AsurasPath namespaces)
├── README.md                         # Project specification overview
├── PROJECT_STATE.md                  # This living handover journal
├── outputs/
│   └── AsurasPath.rbxlx              # Active compiled place file
├── tools/
│   ├── build.py                      # Rojo place compiler
│   ├── cleanup_legacy.py             # Legacy file archiver
│   ├── test_asura_stage1.luau        # Stage 1 test suite
│   ├── test_asura_stage2.py          # Stage 2 test suite
│   └── test_asura_stage3.luau        # Stage 3 test suite
└── src/
    ├── client/
    │   ├── Bootstrap.client.luau
    │   └── Controllers/
    │       ├── CameraController.luau
    │       ├── ColosseumController.luau
    │       ├── GameFeelController.luau
    │       ├── InputController.luau
    │       ├── InterfaceController.luau
    │       └── WorldStateController.luau
    ├── server/
    │   ├── Bootstrap.server.luau
    │   ├── CharacterService.luau
    │   ├── LagCompensation.luau
    │   ├── PersistenceService.luau
    │   ├── ProfileStore.luau
    │   ├── ShopService.luau
    │   └── Services/
    │       ├── AIService.luau
    │       ├── ColosseumService.luau
    │       └── WorldService.luau
    ├── shared/
    │   ├── AnimationCatalog.luau     (Asset slots & fallbacks)
    │   ├── CombatSettings.luau       (Tri-layer HP, stamina, tempo)
    │   └── WorldDefinitions.luau     (Regions, Altars, Spawns)
    └── simulation/
        ├── CombatRules.luau          (Pure-functional combat resolver)
        ├── InputBuffer.luau          (100ms priority queue)
        ├── MoveSchema.luau           (16-state combat machine)
        ├── Tempo.luau                (1.4× temporal scaler)
        └── WeaponSchema.luau         (Move trees for 4 weapons)
```

---

## 3. ARCHIVED LEGACY CAGEBOUND FILES
All 128 Phase 1–12 Cagebound places and docs have been moved out of this project into:
`~/Documents/Cagebound_Archive/` (safe external archive).

---

## 4. UX / ONBOARDING PASS (2026-10-19)
- **Boot fix**: `SanctuaryService` titan auto-mount line was a Luau parse error (`(model :: any):ScaleTo` after a `local`), so the server never booted and players sat on the loading cover forever.
- **Objective tracker**: pure resolver `src/shared/Objectives.luau` (tested by `tools/test_objectives.py`) + `ObjectiveController` (top-right card, "NEW OBJECTIVE" flash) + `WaypointMarker` (gold ◆ with distance). Route: first rest at Primal Bonfire → Ascension Stairs → each altar in order → fog gate → Colosseum; bloodstain recovery takes priority; hidden in boss fights/duels. Server now mirrors defeated bosses to the read-only `AsuraBosses` attribute.
- **Controls card**: `ControlsCard` shows device-aware bindings (keys come from `InputController:Label`), auto-folds to a `[H] Controls` pill after 25 s; toggle H / D-Pad Left / tap.
- **Responsive HUD**: `HudKit.bindScale` scales Vitals, Loadout, Altar menu, objective card and the touch cluster by viewport height (clamped 0.7–1.35 vs 900 px); death screen and toast use scale widths.
- **Prompt double-fire**: E / ButtonX no longer sends the instant `Interact` intent while a ProximityPrompt is on screen (the prompt's hold owns it); touch USE drives the visible prompt.
- **Loading cover**: rotating gameplay tips; after 20 s without `Workspace.AsuraReady` it says the server failed to start (Studio) / is not responding (live).
- New shared kit `HudKit.luau` (palette, helpers, UI cue sounds). All new modules ≤150 lines.

## 5. VISUAL PASS 1 — SANCTUARY SET PIECES, ENEMY LOOKS, PROLOGUE (2026-10-19)
- **Asset pipeline**: CC0 Poly Haven sources in `assets/source/` (git-ignored) → `tools/blender/process_asset.py` (headless Blender: decimate ≤19.5k tris/MeshPart, 1024 PBR maps, GLB + PNG maps) → `tools/blender/preview_asset.py` (QA render) → Studio 3D Importer upload → exported `assets/models/AsuraAssets.rbxm`, Rojo-mapped to `ServerStorage.AsuraAssets`. IDs in `assets/ASSET_IDS.md`, credits in `assets/CREDITS.md`.
- **Uploaded (Creator: Me)**: Gothic Statue (colossus), Large Iron Gate, Dead Tree Trunk 02, Pine Roots — each MeshPart has a SurfaceAppearance with Color/Normal/Roughness/Metalness.
- **`SanctuaryDressing.luau`**: 48-stud veiled colossus on the dais (faces the plaza), 6 root clusters on the plinth, upright dead sacred tree shedding crimson petals, iron gates swung open at the Ascension portal. All calls go through `Dressing.try` (pcall) so a cosmetic failure never blocks boot. Replaces the old titan auto-mount that overwrote materials (the cause of the black statue).
- **`EnemyAppearance.luau`**: Corrupt Monk (ash skin, rust kasaya, prayer beads, ember eyes) and Cursed Swordsman (iron lamellar, pauldrons, black kasa, tattered cloak, ember eyes). `CharacterService.tint` now skips `AsuraAttire`. Catalog accessories were previewed and rejected (bright, cartoony).
- **`PrologueController.luau`**: 4-line skippable letterboxed prologue for new players (motive: Grandmaster Shen, the Fallen Abbot). Controls card waits until it finishes.
- Colosseum sign BillboardGui now sized in studs (was a screen-sized overlay visible from 140 studs).
- **Still ugly / next**: Desecrated Monastery is a flat greybox plane (no map); enemies are R15 block bodies (real meshes need Mixamo/Sketchfab downloads under the user's own login); Sanctuary still ~1,700 primitives + 86 Neon parts; spawn falls and triggers "The clouds return you".

## 6. CURRENT MILESTONE & NEXT TASKS
- **Next Task (Stage 6)**: Build the opening **Sanctuary Lobby** ("The Shrine of the Ascendant") based on the reference concept art:
  * Golden Hour sky sanctuary above sea of clouds (`TimeOfDay = "17:35:00"`, `Atmosphere`, `SunRays`).
  * Circular reflective terrace with shallow water ring and Primal Bonfire Altar.
  * Ascension Portal staircase leading to the Story Mode.
  * Blacksmith forge loggia (West) and 1v1 Colosseum balcony (East).
  * Implemented via `src/server/Services/SanctuaryService.luau` and updated `default.project.json`.

---

## 7. AGENT PROTOCOL (HOW CLAUDE MUST OPERATE)
1. At the start of a chat, read this file (`PROJECT_STATE.md`) to establish context.
2. Only write/edit code in `src/`, `tools/`, and `default.project.json`. Do NOT touch binary files (`.rbxlx`, `.zip`, `work/bin/`).
3. Maintain strict Luau typing (`--!strict`).
4. At the end of every task/chat, update this file (`PROJECT_STATE.md`) with the new status, changes made, and next steps.

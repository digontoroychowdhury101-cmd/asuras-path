# ASURA'S PATH (修羅之道) — LIVING PROJECT STATE & HANDOVER JOURNAL

> **Last Updated**: 2026-10-17 23:45  
> **Status**: Stage 5 Complete + Cleaned & Rebranded. Ready for Stage 6 (Sanctuary Lobby).  
> **Built Target**: `outputs/AsurasPath.rbxlx` (Rojo 32 mapped sources, tests passing).

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

## 4. CURRENT MILESTONE & NEXT TASKS
- **Next Task (Stage 6)**: Build the opening **Sanctuary Lobby** ("The Shrine of the Ascendant") based on the reference concept art:
  * Golden Hour sky sanctuary above sea of clouds (`TimeOfDay = "17:35:00"`, `Atmosphere`, `SunRays`).
  * Circular reflective terrace with shallow water ring and Primal Bonfire Altar.
  * Ascension Portal staircase leading to the Story Mode.
  * Blacksmith forge loggia (West) and 1v1 Colosseum balcony (East).
  * Implemented via `src/server/Services/SanctuaryService.luau` and updated `default.project.json`.

---

## 5. AGENT PROTOCOL (HOW CLAUDE MUST OPERATE)
1. At the start of a chat, read this file (`PROJECT_STATE.md`) to establish context.
2. Only write/edit code in `src/`, `tools/`, and `default.project.json`. Do NOT touch binary files (`.rbxlx`, `.zip`, `work/bin/`).
3. Maintain strict Luau typing (`--!strict`).
4. At the end of every task/chat, update this file (`PROJECT_STATE.md`) with the new status, changes made, and next steps.

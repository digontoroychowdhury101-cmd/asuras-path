
## 10d Shen fog-gate refusals
- Baseline fb51a42 WorldService:861-862: one sealed fight per gate (ArenaOccupied), BossFelled per player permanent; simultaneous entrants/arena occupants join at seal (startFight 826-838). Kept.
- Gate prompt (WorldService ~1217) now sets AsuraResult "!<reason>"; REASONS gained ArenaOccupied, BossFelled (InterfaceController).
- test_boss_encounters: source checks each traverseGate refusal has REASONS text (runs under lune_compat).
- Studio: confirm toasts for 2nd player and post-victory re-entry.

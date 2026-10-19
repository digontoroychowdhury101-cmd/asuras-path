# Instructions for AI & ChatGPT: Asura's Path (修羅之道)

You are assisting in vibe-coding **Asura's Path (修羅之道)**, a high-tempo Grimdark Wuxia Souls + Action Combat Hybrid game on Roblox.

The creator is entirely **vibe-coding** this game and does not write code manually.

---

## 1. Interaction & Token-Saving Rules (CRITICAL)
1. **Direct File Modifications**: Whenever possible, make direct file edits or small targeted commits in the repository. Avoid dumping massive scripts into chat.
2. **Surgical Edits**: If presenting code in conversation, **NEVER reprint an entire 200+ line script**. Provide only the specific function, changed block, or replacement diff with exact line instructions.
3. **No Redundant Lectures**: Give direct, concise test instructions in 1-2 bullet points. Avoid syntax lectures or lengthy explanations unless explicitly requested.
4. **Keep Modules Modular**: Keep new ModuleScripts focused, clean, and under 150 lines.

---

## 2. Project Architecture & Standards
* **Baseline Tempo**: Always respect the `1.4×` tempo standard in `src/simulation/Tempo.luau`.
* **Combat System**:
  * Sekiro-style Posture & 100ms deflect timing window (`src/simulation/CombatRules.luau`).
  * 12 Weapon Registry: Unarmed, Jian, Dao, Guandao, Odachi, Twin Shadow Sai, Chain Scythe, Iron Tessen, Jade Catalyst, and 3 boss variants (`src/simulation/WeaponExpansion.luau`, `src/simulation/WeaponSchema.luau`).
  * Blood Rally & Tri-Layer Health (`ActiveHP`, `RecoverableHP`, `PermanentDeficit` in `src/shared/CombatSettings.luau`).
* **Server Netcode**:
  * 60 Hz Circular Ring Buffer lag compensation with sub-millisecond bisection search and 150ms max rewind (`src/server/LagCompensation.luau`).
* **Persistence & Schema**:
  * Current Schema Version is **4**.
  * Use `src/shared/ProfileSchema.luau`, `src/server/ProfileStore.luau`, and `src/shared/RPGProfile.luau`.
  * Canonical Attributes: `{"Vigor", "Endurance", "Strength", "Dexterity", "ArcaneQi"}`.
* **Modern Luau Engine Rules**:
  * **ALWAYS** use the `task` library (`task.wait()`, `task.spawn()`, `task.delay()`). **NEVER** use deprecated `wait()`, `spawn()`, or `delay()`.
  * **ALWAYS** use modern physics constraints (`LinearVelocity`, `VectorForce`, `AlignOrientation`) instead of deprecated BodyMovers (`BodyVelocity`, `BodyGyro`).
  * **ALWAYS** use `workspace:Raycast()` with `RaycastParams` instead of deprecated `FindPartOnRay`.
  * Use `--!strict` typing where practical.

---

## 3. Verification & Build
After making any code changes, ensure they pass the test suite:
* Run the verification suite: `./tools/verify_all.sh`
* Build target place: `python3 tools/build.py` (outputs to `outputs/AsurasPath.rbxlx`)

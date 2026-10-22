# Follow-up 02: checkpoint, death and recovery (21 October 2026)

## Builds and identity
- **F02** (pre-fix; includes the concurrent `Sanguine*` VFX work): 212 scripts / 1,533,070 bytes, digest `1636370940`. The Studio Edit read matched the local build.
- **F02b** (fixes below): 212 / 1,533,988, digest `1124304554`. The Studio Edit read matched. Temp builds are under the session scratchpad; the saved `outputs/AsurasPath.rbxlx` hash was unchanged.
- Studio access: `tools/studio_mcp.py` drove solo Play on a local file, so persistence is the in-memory Studio mock (isolated, no real data).
- The server console runs in a separate module cache, so evidence comes from replicated attributes, instances, cue remote traffic and real injected inputs (Z hold, W/S).

## Evidence types
- **Real death:** a live enemy did the damage and the player was idle. Placement next to the enemy was diagnostic teleport, which makes this seeded Studio diagnostic evidence, **not earned play**.
- **Diagnostic respawn:** the character was destroyed with no KO and no penalty, used only to isolate an altar's respawn point.
- **Rest:** the real `Rest` ProximityPrompt (0.4 s hold) triggered by an injected Z hold. Diagnostic teleport placed the player at the altar.

## Altar table (Studio, seeded diagnostic)
| Altar | Rest cue / active altar | Respawn method | Wake position (actual) | Region after | Flasks | Cloud-return |
|---|---|---|---|---|---|---|
| Monastery Gate | AltarRest ✓ | real death ×4 (Corrupt Monk ×3, Twin Sentinels ×1) | (0, 3.2, −728) | DesecratedMonastery | 3/3 | none |
| Desecrated Cloister | AltarRest ✓ | real death ×3 (Corrupt Monk) | (60, 3.2, −1018) | DesecratedMonastery | 3/3 | none |
| Whispering Bamboo Shrine | ✓ | diagnostic | (−29, 3.2, −1333) | BambooPass | 3/3 | none |
| Colosseum Antechamber | ✓ | diagnostic | (0, 6, −1743.1) | AshColosseum | 3/3 | none |
| Sanctuary Depths Incense | ✓ | diagnostic | (455, 18, 1038) | SanctuaryDepths | 3/3 | none |
| Celestial Pagoda | ✓ | diagnostic | (−38, 3, −2268) | CelestialPagoda | 3/3 | none |
| Sky Citadel | ✓ | diagnostic | (−32.7, 3, −2690) | SkyCitadel | 3/3 | none |
| Primal Bonfire | ✓ | diagnostic | (0, 603.1, 920) | Sanctuary | 3/3 | none |

Every respawn logged `[CharacterService] Respawn … displaced to (0, ~105/705, 0); restored to <altar spawn>`. In Studio, LoadCharacter does move the new body after CharacterAdded, and the existing settle/hold safeguard corrects it. That safeguard is kept.

## Loss and recovery (real deaths, F02 build)
- Death 1 at Gate with 500 banked: `EssenceLost 500`, Essence 0, a 500 stain at the death site, Deaths=1. Objective: "Reclaim your lost essence · Return to your bloodstain before you fall again" (52 m).
- Reclaim: Essence 0 → 500, stain removed, a second Z did nothing (exactly once).
- Death 2 at Cloister: a new 500 stain; wake at Cloister.
- Death 3 without reclaim (0 carried): the old stain was forfeited, `EssenceLost 0`, no new stain, Essence stayed 0, and the objective advanced.
- Repeated on F02b with the same results. One `EssenceLost` and +1 Deaths per death; no duplicate loss observed.
- Duplicate or delayed KO injection is not possible from the console (separate module cache). It is covered by `claimDeath` in the recovery suite (local regression).

## Defects found and fixed (each demonstrated in Studio and given a failing-then-passing regression)
1. **Death screen dropped the loss line.** The server's `EssenceLost` cue reached the client before the KO event, and `ShowDeath` rewrote the note with `DeathNote(0)`. The F02 Cloister death showed only "You will wake at Desecrated Cloister". Fix: `InterfaceController` keeps the current death's spilled amount (`DeathSpilled`, reset on `HideDeath`). F02b showed "500 essence spilled — reclaim it from your bloodstain / You will wake at Monastery Gate". Regression: `tools/test_death_note.luau` runs the real methods in both arrival orders.
2. **Region cleared on every respawn.** `onCharacterSpawned` runs inside CharacterAdded before the engine parents the body. `GetEntity` (live bodies only) therefore returned nil and `AsuraRegion` was set to nil for about 0.3 s. That replayed the region banner and objective evaluation on every respawn; the server trace showed the root already at (60, 3.2, −1018) while the region read nil. Fix: `WorldService` reads the placed root from `Characters.Entities()`. F02b produced no nil region on respawn. Regression: 3 checks added to `tools/test_recovery_lifecycle.luau` (now 97).
3. **Camera exploded at low frame rate.** The Studio client measured 7 FPS (median 88 ms). The shake oscillator took one explicit step per frame, which is unstable above about 33 ms. A hit impulse grew to 1e35, the camera froze far away, and every line-of-sight prompt disappeared (altar Rest, crypt portals). Fix: sub-step it like the camera springs (`stepShake`). F02b showed the camera at 10.9 studs after deaths, falls and portals, and the portal prompts showed and triggered. Regression: `tools/test_camera_shake.luau` (88 ms frames, a 0.5 s hitch). Real low-end device FPS → prompt 24/25.

## Transitions (F02b)
- **Respawn during the Twin Sentinels intro:** `BossIntro`/`FogGateSealed`, then `BossParticipantLeft` + `BossReset`. Both bosses despawned, the boss bar hid, music stopped, wake at Gate, and re-entry produced a fresh intro. The reset cue's `banner` field is not shown by the client.
- **A real Twin Sentinels KO after re-entry:** the boss reset; wake at Gate.
- **Dialogue (Lin summoned through the altar-menu packet):** both a diagnostic respawn and a real KO closed the dialogue; the HUD returned (134 labels) and the camera returned behind the player.
- **Sanctuary:** a real walk-off fall from (260, 640, 700) to y 483.6 was caught: `SanctuaryCatch`, bonfire at (0, 603, 920), with the toast cue.
- **Crypt portals:** the real Z prompts worked both ways ((520, 33, 1062) Depths ↔ (0, 603, 984) Sanctuary) with no catch.
- **Seven ground-altar respawns:** no catch.
- **Console:** 0 game-script errors (`F02b`). Boss skins report `Fallback:Costume` (art gap A3, prompts 10–12).

## Not done / remaining
- **Save/rejoin at a later checkpoint:** not executable in solo Play. The mock store lives in server memory and is destroyed when Play stops, and the console cannot reach module state. Store-level rejoin is covered by the recovery suite (local regression, seeded). Needs: a local server with one client in Studio (Test → Clients and Servers), rest at Cloister, close that client, join again on the same server, and confirm the wake at (60, 3.2, −1018) with a stain or essence that is neither duplicated nor lost.
- **Earned (non-teleported) campaign deaths** → prompt 22.
- **Observations routed elsewhere:**
  - A Corrupt Monk that had just been reset by a rest did not engage an adjacent idle player for 76 s; a retry engaged within 9 s (prompt 07/22).
  - The "Gatehouse · 47 m" route label stays visible during Lin's dialogue (prompt 04).
  - The altar prompt needs a 0.4 s hold, so a Z tap does nothing (prompt 03/08 teaching).

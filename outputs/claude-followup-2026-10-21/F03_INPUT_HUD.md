# Follow-up 03: input ownership and the desktop combat HUD (23 October 2026, Windows, Computer B)

Original batches 02, 04. Findings #5, #6, #12, #17, #18, #33, #34, #35, #36, #37.

## Build and evidence
- Studio ran in the authoritative `places/AsurasPath.rbxlx`. Changed scripts were patched into the open place in Edit mode. The final digest is `48998423` (236 scripts, 1,689,944 bytes), identical across Studio, `outputs/` and `places/`.
- Evidence type: **seeded Studio diagnostic**. Placement used diagnostic teleports; the damage and deaths came from real Corrupt Wandering Monk hits on an idle player. This is not earned play.
- Inputs were injected by the Studio MCP. Each intent was logged on the server at the `ActionIntent`, `ArsenalIntent` and `DialogueIntent` remotes, and prompt events were logged on the client.
- Saved views are in `f03-views/` (11 images).

## Binding and ownership outcomes (InputMap contract)
| Case | Input | Outcome |
|---|---|---|
| Inside the Bonfire Rest prompt (3.55 studs) | Z hold 0.7 s | Prompt `Triggered` once, result Rest, **0** `Interact` intents (no double rest) |
| Edge of the prompt (8.71 studs; the prompt only shows within ~7.3 although its range is 9) | Z hold | One `Interact` intent, server Rest via its 2-stud slack; once |
| Prompt visible | E / 1 / K / J | `Cast slot=2` (Gale Step), `Cast slot=1`, `Swap`, `Codex`, each once; E never rests or reclaims |
| Altar menu open | E, 1, K | nothing sent |
| Codex open | E, K, 1, Z | nothing sent |
| Focused TextBox | E, K, 1, Z, J | nothing sent (injected keys produce no text, so this proves focus ownership, not typing) |
| Codex → Respite (P) → close (P) | K, E | **before the fix:** the shared `MenuOpen` flag was cleared and keys reached the game under the dialogue. **After the fix:** nothing sent |
| Codex open | Backspace | `Close` once; then K sends `Swap` and E sends `Cast` |
| After death and respawn | K, 1, W | `Swap` once, `Cast` once, character moves; no stuck input |
| Controller route | D-Up | `Cast slot=1`. D-Right Swap did not fire because injected D-pad events arrive as keyboard input. This harness limit is **not** evidence about real gamepads; prompt 24 owns that |

Overlapping prompts: Lin's Speak prompt (12) and the Bonfire Rest prompt (9) are 20 studs apart, so a 1-stud overlap band exists. It was not isolated in Studio. Routing is covered by `routeInteract` (newest prompt wins; local regression, `test_input_map` 370).

## Defects found and fixed
1. **Menu ownership leak (state):** opening Respite over Lin's dialogue or the Codex, then closing it, ran `SetMenu(Altar or Arsenal)`, which set the flag to false. Combat and spell keys then reached the game while the dialogue was still open. `InputController.SetMenu(open, owner)` now keeps a set of owners, and every window passes its own name. Regression: `test_movement.luau` (fails before, 52/52 after). Studio-verified (table above).
2. **Wrong close label:** the Codex and dialogue said "[Esc] leave", but Roblox reserves Escape (the event arrives processed) and `GuiService.MenuIsOpen` toggled instead. Backspace now closes them, as it does Respite, and the hint says "[Backspace] leave".
3. **Stacked modals:** Respite opened over the Codex, and two translucent panels overlapped. Respite is now blocked while a dialogue is open.
4. **Unreadable glyphs:** "✦" (currency) and "↺" (rally) rendered as blank boxes in their fonts. They were removed from the HUD, the Lin status line and the Ascension header.
5. **Small survival values (#35):** at 1096×604 the vitals and loadout plates scaled to 0.546, so Flask was ~9.8 px and Essence ~10.9 px. Added `HudLayout.Regions.Vitals.MinScale = 0.66` (desktop floor, modelled in `Layout.rect` and checked by the 6-viewport overlap suite). Measured after the fix: Flask 12.0 px, Essence 14.2 px (small); 15.7 / 18.6 px (wide).
6. **Controls card bleed:** the 25%-transparent card let the "What Death Takes" teaching text show through. It is now near-opaque (0.04).
7. **Respawn stared at the sky (#18, state):** a lock held over the KO'd body set the pitch to about +48° (lookY 0.75–0.78). Nothing reset it, so every respawn looked up at the sky until the mouse moved. `CameraController.followRoot` now recentres pitch and yaw behind each new body. Regression: `test_camera_shake.luau` +2 (fails before, 7/7 after). Studio: lookY −0.21 and camera 11 studs behind after respawn.

## HUD state views (1736×824 wide, 1096×604 small)
- **S1, combat with H open:** the card sits in the centre band, clear of the action bar, minimap and objective. It lists spells, Arsenal, Codex J, Swap K, cursor and shoulder (#33, #37). The card opens by default at session start and auto-hides after 25 s, so the first H press closes it.
- **S2, two monks with lock-on:** one target plate under the compass, no overhead duplicates, and the Lock On slot is highlighted (#34). **Lock switching was not demonstrated:** the mouse is locked to centre, so injected moves produce no flick delta, and no regression covers `SwitchTarget`.
- **S3, reduced ceiling then death:** "RALLY 3.0s · strike back" and "▼ max −26 · rest restores" are text, not colour only (#12). Respawn at the Primal Bonfire: HUD clean, lock cleared, objective "Reclaim your lost essence". The death screen itself was not captured (the 4 s KO window); the F02 death note stands.

## Remaining (exact)
- The rally and ceiling tags are 8–10 px tall. They need about 320 px beside a 300 px health bar, so enlarging them needs a vitals re-layout. This is device readability → prompt 24.
- The target-plate "85 / 85" is about 6 px at 1096×604 → prompt 24.
- Real mouse or stick lock switching, gamepad Swap/Interact on hardware, the Twin Sentinels duo and overlapping-prompt hands-on play → human continuous input (prompts 10 and 24).
- During the KO the locked camera still swings upward toward the killer, before respawn → prompt 07 or 09 camera pass.
- Monks sometimes don't engage an adjacent idle player (already routed to prompt 07).
- Petal and effect density versus warnings (#36) was not assessed here (the monastery has no petals) → prompt 09.

---

# F03b — acceptance pass (24 October 2026, macOS, Computer A)

## Build and evidence
- Start: HEAD `7a70633`, saved place digest `31317871`, which matched the open Studio place. Changes since bd737a7 in scope: `InputController`/`InputMap` (fix 2602f3f, hold-Alt cursor) and the controls-card Alt text. The HUD modules (`HudLayout`, `HudVisibility`, `PlateLayout`, `DuoBars`, `CoreGuiPolicy`) are unchanged, so the S1–S3 views above still apply; only the H-card views were recaptured.
- End: rebuilt `places/AsurasPath.rbxlx` digest **584676947** (252 scripts). The changed scripts were pushed to the open place with `tools/qa/studio_sync.py`, and a dry run then reported 0 differing scripts.
- Evidence type: **seeded Studio diagnostic** (teleports, `MoveTo` walks, one scripted `TakeDamage` death through `applyExternalDamage`). Keys came from the Studio MCP injector. Focus changes were real Studio window-focus events from desktop clicks on the command bar and viewport, not an OS-level Alt-Tab. Server logs: `ActionIntent`, `ArsenalIntent`, `DialogueIntent` and prompt `Triggered`. Client logs: `MouseBehavior` changes and prompt shown/hidden.

## Alt cursor (hold-to-free) and ownership rows
| Case | Input | Outcome |
|---|---|---|
| Alt held | LeftAlt down | `MouseBehavior` Default, icon on, `IsKeyDown` true; mouse look is gated off (`gameplay=false`) |
| Alt released | LeftAlt up | LockCenter, icon off, the same frame |
| Alt held + K / E / 2 | — | `Swap` ×1, `Cast slot=2` ×1, 2 reaches CAS; each once |
| Alt held + 1 | — | **Nothing is sent.** Alt+1 (Left or Right Alt) arrives at `InputBegan` already processed, and CAS never receives `Begin`, even at priority 10000. 1 alone casts. This is an engine/Studio reservation, not game code → prompt 24 (Windows/hardware check) |
| Alt down, then focus leaves (command bar) | — | `Ended LeftAlt` then `WindowFocusReleased` → LockCenter |
| Alt pressed while unfocused, focus returns with Alt still down (no release) | — | `WindowFocused` → LockCenter with `IsKeyDown(LeftAlt)` still true: **the cursor does not stay free**. A fresh hold frees it again |
| Codex: Alt held, J, then K/E/2/Z | — | `Codex` ×1, Rest prompt hidden, nothing else sent; Alt release keeps the cursor with the menu; Backspace → `Close` → LockCenter; then K, 1, E → `Swap`, `Cast 1`, `Cast 2`, once each |
| Respite: Alt held, P, then K/E/Z | — | nothing sent; release Alt → still Default; P closes → LockCenter; K → `Swap` ×1 |
| Lin dialogue: Z (Speak), Alt held, K/E, P ×2 | — | `Triggered Speak` ×1, no `Interact` intent; K/E sent nothing; Respite stayed blocked; Backspace → `Close`, K → `Swap` ×1, 1 → `Cast 1` ×1 |
| Codex → P/P under Alt → Alt up → K/E | — | nothing leaked while the Codex was open; Backspace → `Close` then K → `Swap` ×1 (owner-scoped `SetMenu` holds with the Alt change) |
| Death with Alt held | `TakeDamage` | respawn after 4.1 s at the Primal Bonfire; cursor free only because Alt is still held; Alt up → LockCenter; K → `Swap` ×1, 1 → `Cast 1` ×1, S moved 16.4 studs |
| Bloodstain: E held 0.9 s | — | `Cast slot=2` ×1, essence stays 0 (**reclaiming never casts Gale Step and E never reclaims**) |
| Bloodstain: Z held 0.9 s | — | `Triggered Recover Essence` ×1, essence 0 → 500, no Cast, no `Interact` intent |

## Lin Speak / Bonfire Rest band (closes the first run's open item)
- Measured: Rest r9 (no LOS) at (0, 601.2, 900) and Lin's Speak r12 (LOS) at (8, 604.8, 918), 20.0 studs apart. Both prompts use `OnePerButton`.
- Walking toward Lin, with the camera behind the player: Rest hides and Speak shows **in the same frame** at dBon 9.06 / dLin 10.97. Walking back, the reverse happens at dBon 8.95 / dLin 11.09. Inside the theoretical overlap (dLin 11.1–12, dBon ≤ 9) only Rest is shown. There is never a double prompt.
- Z at dBon 8.42 / dLin 11.62 (inside both ranges): `Triggered Rest` ×1, result Rest, no Speak, no `Interact` intent. Pad route: injected ButtonX → `Triggered Rest` ×1 / `Triggered Speak` ×1 in the same zones.
- When the camera has swung beside Lin and faces the player, Speak appears only once her torso is on-screen (about 9.7 studs). In between, nothing is shown, and Z becomes the server `Interact`, which rests at the bonfire (altar radius 9 + slack 2). With LOS disabled the result is identical, so this is engine view-culling, not a defect.
- **Defect fixed (state, regression):** Lin's own arm hid her Speak prompt. Her non-colliding limbs still answered queries, so the line-of-sight ray to the torso stopped on `LeftUpperArm`. In-engine A/B at 3 spots × 2 (torso on-screen, 8.7–10 studs): old limbs → hidden 6/6; fixed → shown 6/6. `CastFigures.statue` now gives non-solid limbs `CanQuery=false` (like the attire). Walls, torso and legs still block. Regression: `test_cast_visuals` +2 (fails before, 48/48 after).

## Other defects fixed
1. **B did not close Lin's dialogue or the Codex (state, regression):** `AsuraKineticMovement` (priority 3000) binds ButtonB as Dash and always sank it. The dialogue/Codex back handler ignores processed input, so the "[B] leave" hint was dead. An open window now receives B unprocessed; outside menus B is still Dash. Regression: `test_movement` +3 (fails before, 59/59 after). Studio: ButtonX Speak → ButtonB → `Close`; J → ButtonB → `Close`; B with no window open → `Dash` ×1.
2. **Altar had no back key:** Backspace closed every other modal except the altar (only the Leave button or walking 15 studs away closed it), and nothing was selected for a controller. Backspace/ButtonB are now bound only while the altar is open: sub-page → Main → close. The first button is selected when a gamepad is enabled. Studio: Ascension → Backspace → Main → Backspace → closed, binding released, LockCenter; K/1 once each; ButtonX rest → ButtonB closes. This is an input route, so it was verified in Studio rather than with a spelling test.

## H-card views (Alt row text changed)
- `f03-views/wide1736x824_S1_H_alt_hold_F03b.jpg`: viewport 1735×823 (Studio custom device, deleted afterwards), card scale 0.914, Alt row 187×17 px, fits.
- `f03-views/small1096x604_S1_H_alt_hold_F03b.jpg`: viewport 1095×603, card scale 0.70, Alt row 147/151 px wide, 13 px tall (neighbouring rows 12–14 px), fits. In both views the card is clear of the action bar, minimap, objective and vitals. These are shrine views, not combat; combat S1 is unchanged from 23 Oct.

## Remaining (exact)
- Alt+1 is swallowed upstream while Alt is held (Mac Studio, injected input). Check on Windows hardware → prompt 24.
- Focus loss was a Studio window-focus event, not an OS Alt-Tab on Windows. Real Alt-Tab with a held Alt → prompt 24.
- Pad evidence is injected (ButtonX/B arrive as keyboard-type input that triggers the prompt and CAS by KeyCode). Gamepad hardware, real mouse/stick lock switching and the Twins duo → 10/24.
- Still open from the first run: rally/ceiling tags 8–10 px and target-plate numbers ~6 px → 24; KO-time lock pitch → 07/09; #36 petals → 09.

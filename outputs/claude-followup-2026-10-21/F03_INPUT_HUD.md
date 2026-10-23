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

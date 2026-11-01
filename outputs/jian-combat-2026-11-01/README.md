# Jian combat animation — evidence (2026-11-01, Windows)

## What changed
- **Root cause:** the player had no attack-animation playback at all. The `AnimationCatalog` Jian slots were never loaded by any client code; only Roblox's Animate script ran. This was a missing playback path as well as missing clips, not a priority or binding fault.
- `src/client/Controllers/FighterAnimations.luau` (driven from `GameFeelController`) plays catalog slots from each fighter's replicated combat state:
  - **Layers:** ready stance or arms-only carry underneath; on top, attacks, guard, deflect, dodges, hit reactions, posture break and recovery.
  - **Timing:** attacks are phase-locked to the server's move clock and never award damage.
  - **Scope:** the local character plus server-owned non-boss R15 NPCs.
- **19 clips**, authored procedurally on the shared R15 template rig (Zhao's `rig.py` FK/IK and writer), reviewed in Blender, published via Studio *Save to Roblox* and verified pose-for-pose by load-back. Sources are in `tools/animation/jian/`; outputs and IDs are in `assets/animations/jian/` (`published.json`, `manifest.json`).
- **Masked clips:** Guard, GuardImpact and Deflect are upper-body only; Move is arms-only. Unkeyed joints are written as Weight-0 container poses, which Studio was measured to leave to the walk.

## Tests actually run
| Evidence | Kind |
|---|---|
| `export.py` validation: reach, ground, foot slide, blade-in-body, hand kinks, slash L→R / thrust-forward against StrikeGeometry. 19/19 clean | offline |
| Real `CombatRules` chain L1→L2→L3 | offline Luau |
| Studio Play, real inputs: L1 phase lock (server Startup 0.067 s ↔ track 0.07–0.10 s), Heavy windup→contact, Seven Star Art, guard hold, parry, neutral dash = Backstep, directional dash = Dodge, carry while sprinting | Studio play, local client+server |
| Sparring Phantom exchange: Hitstun light/heavy, Deflect, Blockstun→GuardImpact→Guard, posture break, deathblow (controller silent), respawn | Studio play, server-side placement (seeded) |
| All 19 published IDs load back identical to the local copies (keyframes, poses, weights, loop, priority) | Studio Edit |
| `tools/verify_all.sh` 14/14 | local regression |

## Follow-up run (same day)
| Evidence | Kind |
|---|---|
| Real OS clicks at 0/160/320/520 ms (`tools/qa/jian_combo_clicks.ps1` + `JianComboWatch.client.luau`): server chained Jian_L1→L2→L3→L4; the controller switched to each published clip seated on the server clock (L2 0.12 s at its active frames vs 0.10 s startup; L4 0.16 s vs 0.133 s) | Studio solo play, real input |
| Real clicks into the Sparring Phantom: L1–L3 met its guard (Blockstun each hit, posture 7→15→23, HP 140→137 chip), damage server-side | Studio solo play, real input, server-side placement (seeded) |
| Local server + 2 clients: Player2's client sees Player1's published ready stance loop and Jian_Heavy on Player1's character (Animator replication works) | Studio local multiplayer |

Found while testing:
- **Windup arrives late for observers.** Player2 first saw Player1's Heavy already 0.36 s in, near contact. This run exaggerated it: Studio throttles background windows (server at 2 Hz unfocused, 44 Hz focused; clients about 15 fps). Still, replication latency means opponents may miss part of a windup on a real network.
- **Presses stay "Buffered" after a forced reposition.** After a server-side teleport of the player, attack presses can stay buffered for seconds. That's a test-setup artifact, not normal play.
- **No clean NPC hit reaction yet.** The phantom guarded or armoured through every attempt, so no unblocked hit landed on an NPC. The reaction clips were verified on the player through the same code path.

## Not verified (before the follow-up run)
- **L2–L4 played from real presses.** In Studio, client and server share one process at about 20 fps, and automated presses arrived about 0.3 s apart. That is too slow for the 0.1 s combo window, so these hits were reviewed in Blender and validated offline only.
- **Second client's view.** No other client was available. By design, a player's tracks replicate through its Animator.
- **Hits landing on an enemy.** The phantom kept the player in hitstun, so this wasn't observed.
- **Live persistence, mobile and video capture.** Not covered; these are stills only.

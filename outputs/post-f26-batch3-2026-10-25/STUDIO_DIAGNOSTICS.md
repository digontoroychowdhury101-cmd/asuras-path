# Claude's Studio diagnostics for the 20-minute playtest (25 Oct 2026, Computer B, macOS)

These are **not human observations** and do not accept anything. They give the human playtest numbers
to compare against. One Studio Play session, one client, keyboard/mouse.

## Build identity

The place opened in Studio Edit reads back **255 scripts, 1,853,137 bytes, digest 1219538751**. That
matches `python3 tools/studio_mcp.py --digest places/AsurasPath.rbxlx` for HEAD `56a61a9`.
- `ServerStorage.AsuraAssets` holds 13 children.
- There are 0 `AsuraBoss_*` instances anywhere and no `AsuraBossAnimations` folder.

The QA kit (`tools/qa/HumanPlaytest.*`, `OmniCombatProbe`) was inserted during Play only, never saved.

These diagnostics ran on 1219538751. Later in the batch, the boss-skin loader changed (Shen handoff), and the new place digest is 1661908618. That change touches only `BossSkin`, `CostumeKit.phase` and `CostumeSchema.RequiredBones`, not combat. The human should log 1661908618.

## Evidence labels

| Label | Meaning |
|---|---|
| **RI** | real Studio input: injected keyboard or mouse through the game's own InputController |
| **ST** | server-timed: player intents pushed through the real `CharacterService.PushIntent` path |
| **SD** | seeded: placement, heals and KO protection from the QA probe/kit |
| **AI** | live game AI |

## Kit check (RI + SD)

- **Prologue:** a fresh Studio profile boots at the Sanctuary (0, 603, 920): Lv 1, 500 Essence, Jian, flask ×3, objective "Kneel at the Primal Bonfire". Any key skips the prologue.
- **Panel:** a real Alt + left click on "2 Monk courtyard" teleported the player 16 studs in front of the nearest living monk. The Studio log printed `[Playtest] … station Monk`.
- **Stations:** the four stations resolved as:

  | Station | Position | Weapon |
  |---|---|---|
  | Yard | (3.7, 3.1, −721.1) | Jian |
  | Monk | (−7.7, 3.2, −767.2) | Jian |
  | Bridge | (0.0, 2.8, −926) | Jian forced |
  | Twins gate | (300, 3, −822) | Jian |

- **After death:** the panel survives a respawn (ResetOnSpawn off).
- **Sealed arena:** once inside the sealed Twins arena, a teleport out is pulled back inside, so the human guide says so.
- **Fix during setup:** the first station lookup used the internal kind ids. It now uses the live model names ("Corrupt Wandering Monk", "Cursed Swordsman", "Sparring Phantom").
- **Layout:** in Studio's small play viewport the panel's last line touches the "[H] Controls" hint. The header folds the panel away.
- **Input focus:** right after a server-side probe call, injected keys sometimes did not register until a mouse click in the viewport. The guide therefore tells the tester to click the world after using the panel. This did not reproduce as a game input fault.

## D1. Monk pressure and hitstun (SD + AI, passive body)

**Run 1** (KO-protected, no input):
- A monk L1 landed at t0 for 5.4 damage. The player was in Hitstun about **0.28 s**.
- The monk's Unarmed_Heavy windup began **0.067 s before** the player could act, while the player was still in hitstun.
- The heavy landed 0.30 s after its windup began. That leaves **0.23 s of actionable time** to dash or guard.
- Over 6 s: 11 hits, then StanceBreak, then Deathblow. The Unarmed_Art's later hits are 0.2 s apart and deal 0 damage once posture is gone.

**Run 2** (placed 3.6 studs from the monk):
- 13 hits took the passive body from 100 to 1 Active HP in 4.6 s.
- The monk's L1 → L2 landed **0.20 s apart**, a true string with no gap to act.

Player Lights pushed during hitstun (ST) were dropped: the first two were lost. The third came out after recovery, and the monk **blocked** it.

**Question for the human:** is a 0.23 s window after one punch enough at human reaction speed? Typical visual reaction is about 0.2–0.25 s.

## D2. Blood Rally (ST + AI)

The settings are window 3.0 s and return ratio 0.85 (`CombatSettings.Health.Rally`).
- After the monk hit: Active 94.6, Recoverable 3.2, rally window 2.98 s left.
- The player's third Light was blocked for 0.80 chip damage. It still produced `Rally 0.68` (0.85 × 0.80), so a **blocked** counter-hit also rallies a little.
- The monk rallied 0.80 off the player in the same exchange. The rule is symmetric.

**Question for the human:** is the pale-bar return visible and worth chasing?

## D3. Dash displacement (RI, Sanctuary plaza, no foes)

The input was D held + Q. The server granted 14 studs; the `Dashing` state lasted **0.233 s**.

Server-side planar travel from the state's start:

| Time after start | Travel (studs) |
|---|---|
| 0.083 s | 1.10 |
| 0.183 s | 3.65 |
| 0.233 s (Dashing state ends) | **4.95**, 35% of the grant |
| 0.333 s | 9.95 |
| 0.433 s | 16.7 (includes walking with D held) |

- The server body (the pose that hits are rewound against) is still within about 5 studs of the start when the i-frames end.
- The rest of the travel arrives about 0.1–0.2 s later.
- In practice, dodges are carried by i-frames. Moving out of a swing's reach with the dash alone does not count until about 0.2 s after the press.

This confirms open item 6 of `OMNI_COMBAT.md` with numbers. It was **not changed**: no human fault has been shown yet.

## D4. Twin Sentinels (SD + AI, passive body, heals every 1.5 s)

- **Opening:** within 6 s of walking into the gate, the passive body was stance-broken and deathblowed (KO-protected).
- **20 s totals:** 29 hits landed, 20 whiffs, 2 evades, 3 stance breaks, 2 deathblows, 3 bleed procs.
- **Synchronised swings:** Zhao and the Bull committed swings **33–50 ms apart** in 4 consecutive pairs. Their yaws were 2.61 and −2.78 rad, about 50° apart: two sides of the player.
- **Arcs:** 120° at 10.5 studs, 160° at 12, 30° at 11.
- **Why it matters:** a deflect needs the defender to face the attacker, so a guard turned to one twin cannot cover the other. In a synchronised pair, a dodge (i-frames) is the only clean answer.
- **Camera (`views/hp06_twins_engaged_bull_occludes.jpg`):** at close range the Iron Bull's body fills the left half of the frame while the perilous ring is on screen.
- **Not exercised:** target switching by mouse flick. The injector cannot send look deltas under a locked cursor, as in F10 and OMNI.

**Question for the human:** are synchronised double swings readable and fair, or do they need a stagger (for example, one twin waits for the other's recovery)?

## D5. Jian vs Cursed Swordsman

Not re-measured here: the session's arena seal prevented a clean bridge sample. OMNI_COMBAT §4 still stands:
- an aimed Jian light 35° beside the body whiffs;
- 2/2 Evade and 9/9 DeflectSpark against the swordsman.

The human route covers spacing feel.

## Captures (`views/`)

| File | Shows |
|---|---|
| `hp01_fresh_start_panel_v1.jpg` | first panel layout over the Controls card (glyph later fixed) |
| `hp02_monk_station_after_click.jpg` | real Alt-click arrival at the monk |
| `hp03_bridge_station.jpg` | bridge arrival, swordsman engaging |
| `hp04_panel_compact_after_death.jpg` | final compact panel; it survives a death |
| `hp06_twins_engaged_bull_occludes.jpg` | Twins fight, Bull filling the frame |

## Not run

- Human continuous input.
- Two-client PvP: Windows only (`tools/qa/OmniPvP.*`).
- Gamepad and touch hardware.
- Deflect window retuning: the 100 ms baseline is kept.

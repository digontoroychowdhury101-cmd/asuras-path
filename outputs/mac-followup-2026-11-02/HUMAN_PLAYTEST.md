# Human playtest — opening loop (Windows, 3 November 2026)

About 45 minutes. Play the game normally. Do not use QA scripts, seeds or the command bar. The notes you take are the evidence.

## Setup

1. Pull `ux/onboarding-overhaul` and open `places/AsurasPath.rbxlx` in Roblox Studio. This checkpoint's script digest is 430611340.
2. Press **Play** (F5), one player. Studio uses a local in-memory store, so **every Play starts a fresh profile** and nothing is saved. Do not turn on `StudioLiveData`.
3. Optional but useful: record the screen with Win+Alt+R (Xbox Game Bar).
4. Press **H** in game to see the controls card. It is built from the same `InputMap` as below.

| Action | Key | Action | Key |
|---|---|---|---|
| Light attack | Left mouse | Interact (rest, recover, read, speak) | **Z** (hold) |
| Heavy attack / deathblow | V | Drink from the gourd | R |
| Guard (tap on impact to deflect) | F | Lock on | X or middle mouse |
| Dash (stamina, brief i-frames) | Shift or Q | Weapon art | G |
| Jump / double jump | Space | Spells | 1, E |
| Slide (hold; + Space = bullet jump) | C or Ctrl | Arsenal / Codex | B / J |
| Glide (hold in air) | Right mouse | Swap weapon | K |
| Sprint toggle | Caps Lock | Free the cursor | hold Alt |
| Camera shoulder | T | Leave a dialogue | Backspace |

## 1. Fresh-profile opening

Follow the **objective card** (top right) and its marker. Do not look up positions.

1. Kneel at the Primal Bonfire (hold Z) and choose **Leave**.
2. Climb the Ascension Stairs north through the gate to the Desecrated Monastery. Kneel at the **Monastery Gate** altar.
3. Training with the **Sparring Phantom**: do a few steps, then use **Skip** on its card. Note whether skipping is clear and whether anything asks you to train again.
4. Fell the **monk in the courtyard** (section 2 covers the five attempts). Expect toasts for Essence (+45) and Spirit Iron Ore (+1).
5. Read the glowing inscription on the landing (hold Z): **+100 Essence**, and it appears in the Codex (J).
6. Cross the ravine bridge past the swordsman and kneel at the **Desecrated Cloister**.

**Record:** time per step; every moment you didn't know where to go or what the card meant; prompts that showed the wrong action; places you got stuck or fell; frame hitches.

## 2. Five attempts against the introductory monk

The courtyard monk (the first "Fell the monk" target) at normal health. Play the way you would normally fight. Don't stand still or only block to "test" it: those deaths tell us nothing about tuning.

After each attempt, write one line: **won/lost · time · your HP left (or 0) · what ended it** (light string, heavy, deathblow after a posture break, a hit from behind) · **did you see the windup in time? · did deflect (tap F) feel on time?**

If you die you wake at the last altar you rested at, and the monk resets. Walk back and try again. Five attempts in total, wins included.

Afterwards, answer these in one word each:
- Fair, too hard or too easy?
- Did hits ever land before you could react?
- Was the gap between its strings readable?

## 3. Checkpoint and death recovery

1. Carry some Essence (the counter is at the bottom left) and die once. Expect "YOU FELL", then waking at your last rested altar. A **bloodstain** marks where you fell.
2. Walk to it and hold Z (**Recover Essence**). Check the counter returns to the amount you dropped.
3. Die, then die again before recovering. Expected by design: the first stain is lost and only the newest remains.
4. Rest at the **Cloister** and stand still for 20 s. The monk and swordsman should stay at their posts (the altar shelter). Then walk out toward them: they should fight you normally. If they kill you, you wake at the Cloister and they go back to their posts.

**Record:** any recovery that returned the wrong amount, a stain you couldn't reach, foes waiting on your respawn, or Travel refused while nothing was attacking you.

## 4. Return to Gao and the first earned upgrade

1. The card reads **"Earn what Gao asks"** until you hold **250 Essence and 1 Spirit Iron Ore**. Each monk pays 45 and the swordsman 80, plus the inscription's 100.
2. When it changes to **"Return to Master Smith Gao"**, kneel at the Cloister altar, choose **Travel → Primal Bonfire**, then walk west to his forge.
3. Approach Gao **from the front and from each side**. The prompt should be **"Speak to Master Smith Gao"** every time. The stone seal about 10 studs south of him shows "Transmute Remembrance" only when you stand right beside it.
4. Hold Z, then **Reinforce or infuse my weapon → Reinforce to +1**. Check that Essence drops by 250, ore drops by 1, and the Jian shows +1. Your other weapons should keep their own levels.
5. Leave (Backspace), walk away, come back and speak again: the panel should reopen normally.
6. Back in the Monastery, hit a foe and note the light hit. The panel promised 8.0 → 8.8.

**Record:** how long it took to afford +1, any wrong prompt, any unclear panel text, and whether the upgrade felt noticeable.

## What this does not cover (still failed or unverified)

These remain explicit; a good playtest does not close them.
- **A1 (first motion within one frame): FAILED.**
- **Combat Stage 3:**
  - W-01–W-06, W-08, W-10, W-11 and W-13 NOT RUN.
  - W-07: the oblique-wall rollback and the KO-during-dash case are open.
  - Accepted dashes roll back beyond ~0.5 s one-way delay.
- **Multiplayer:** only a loopback two-client smoke check (12/12). W-04, W-06 and W-09 under real latency are NOT RUN.
- **Feel and fairness (W-12):** pending this playtest. Monk pressure is undecided; tune only from section 2's normal play, never from idle or guard-only deaths.
- **Other systems:** rejoin and live DataStore, gamepad/touch hardware and desktop performance are NOT RUN. Batches 2–4 (Iron Bull, armour, route) are not started.
- **Known minor issue:** the seal opens the Arsenal on the last-used tab, not Transmutation.

Send the notes (or the recording) back. They become the W-12 / human-feel evidence in `windows-acceptance/RESULTS.md`.

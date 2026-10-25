# 20-minute combat playtest (Mac, Studio, one player)

Build: `places/AsurasPath.rbxlx`, script digest **1661908618** (post-F26 omnidirectional combat + boss-skin loader fix).
This is a **seeded** test: the panel teleports you and refills health. Nothing you do here counts as
earned campaign progress. Your notes go in `HUMAN_OBSERVATIONS.md`; mine are kept apart in
`STUDIO_DIAGNOSTICS.md`.

## Before you start (2 minutes)

1. Open `places/AsurasPath.rbxlx` in Roblox Studio and press **Play** (the normal Play button).
2. When the black intro text appears, press any key to skip it.
3. Load the station panel. Either tell Claude **"load the playtest panel"**, or run this in Terminal from the project folder:

```bash
python3 tools/qa/human_playtest.py
```

4. A dark panel appears top-left, headed **PLAYTEST [-] not earned play**.
5. If you can, record the screen (press Cmd+Shift+5, then Record Entire Screen). A recording lets me fix exactly what you saw.

**Using the panel**
- **Hold Alt** to get a mouse cursor, click a button, then let go of Alt.
- Click once in the game world afterwards, so your keys go back to the game.
- Click the red header to fold the panel away while you fight.
- Press **M** whenever something feels wrong. It writes a numbered, timed mark into Studio's Output window, so we can find that moment later. Then just say "mark 3 felt unfair" in your notes.
- **Heal me** refills health, stamina and posture. **Use fists** and **Use Jian** switch weapons.
- Pressing Stop removes the panel. After each new Play, load it again.

**Controls (keyboard + mouse)**

| Key | Action |
|---|---|
| WASD | move (relative to the camera) |
| Mouse | look |
| M1 (left click) | light attack |
| V | heavy attack |
| F | hold to block; tap just as a hit lands to deflect |
| Q or Left Shift | dash (a brief moment where nothing can hit you) |
| Space / Space twice | jump / double jump |
| X | lock on; flick the mouse left/right to switch target |
| R | drink from the gourd (heal) |
| G | weapon art |
| H | show/hide the controls card |

## The route (about 20 minutes)

### 1. Training yard: warm-up (3 min) — button **1**
- The training card on the right teaches lock-on, strike, guard, deflect, dodge, Blood Rally, heal and a perilous attack. Do as many steps as you like.
- If you'd rather skip it, hold Alt and click **Skip training** twice.
- **Watch for:** does the deflect (tap F as the hit lands) feel learnable after 5–10 tries?

### 2. Monk courtyard: pressure and hitstun (4 min) — button **2**
- Walk up to the monk and let it start attacking.
- **Round A:** let one punch land, then try to get out at once, with a dash (Q) or a block (F).
- **Round B:** fight normally: block, deflect, dodge, hit back.
- **Watch for:**
  - After the first punch lands, do you ever get a real chance to act before the next one?
  - Do long strings of hits feel fair or inescapable?

### 3. Bridge swordsman with the Jian (5 min) — button **3**
This station gives you the Jian.
- **Spacing:** stand just outside the swordsman's reach and circle left or right. Step in, poke (M1), step out.
- **True whiffs:** when you see its windup, sidestep late (as late as you dare). Does its swing visibly miss? Does yours miss when it sidesteps?
- **Block / deflect / dodge, then punish:** try each one against its swings, then hit back straight away.
- **Blood Rally:** take a hit on purpose and watch the pale part of your health bar. Hit back within about 3 seconds. Does the pale part come back as health?
- **Dash distance:** dash sideways out of a swing. Does your character actually travel out of the way, or does the dash feel short or late?

### 4. Twin Sentinels: camera and wide arcs (6 min) — button **4**
- You arrive outside the fog gate. Walk forward (south) through it to start the fight.
- **Important:** once inside, the panel can't take you out. You leave by winning or falling. After falling you wake at an altar; use the panel again.
- **Camera:** lock on (X) and switch between Zhao and the Bull by flicking the mouse. Does the switch go where you meant it to?
  - Do you ever lose sight of one of them?
  - Does the Iron Bull's body ever fill the screen?
- **Wide arcs:** both carry long glaives with wide sweeps. Do hits from the one you are *not* facing feel fair, readable and avoidable?
- **Watch for:** does dodging (Q) feel like the only answer when both swing at once?

### 5. Spare minutes
Go back to whichever station felt worst and repeat it.

## Afterwards (3 minutes)
- Fill in `HUMAN_OBSERVATIONS.md` (just ratings and a line or two). Or tell Claude your answers out loud; I'll copy them in.
- Then press Stop. Before you stop, copy the Output window lines that start with `[Playtest]` (they hold your M marks), or let Claude read them.
- Give me the recording if you made one. I will fix only faults you actually saw, then rerun focused checks. The 100 ms deflect window stays as it is unless your play shows a specific timing fault.

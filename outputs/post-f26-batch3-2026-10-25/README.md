# Post-F26 batch 3 (Mac only), 25 Oct 2026, Computer B

- **Start:** `56a61a9`, place digest 1219538751.
- **End:** place digest **1661908618** (255 scripts). `places/` and `outputs/` hold the same file, and Studio Edit read-back matches.
- **Not done in this batch:** PvP was not accepted, ranked play was not opened, Aerial Duel was not started, and the 100 ms deflect window is unchanged.

| File | What it is |
|---|---|
| `HUMAN_PLAYTEST.md` | 20-minute route, controls and how to load the station panel |
| `HUMAN_OBSERVATIONS.md` | blank sheet; **human only** |
| `STUDIO_DIAGNOSTICS.md` | Claude's numbers, kept separate from human notes |
| `SHEN_ASSET_HANDOFF.md` | Shen P1/P2 models, weapons, binds, clips, VFX/SFX, concept-sheet prompts, Studio validation |
| `../claude-followup-2026-10-21/EARNED_CAMPAIGN_LEDGER.md` | earned campaign ledger, 0/6, session 0 setup only |
| `views/` | Studio captures (game camera) |
| `VERIFY_LOG.txt` | `verify_all.sh` SUCCESS, 14/14 steps |

## Code changes

| Change | Detail |
|---|---|
| `CostumeSchema.RequiredBones.Humanoid` | all 15 R15 limbs. A skin hides every limb, so missing hands or feet would have vanished. |
| `BossSkin` + `CostumeKit.phase` | a template with `AsuraRole=Weapon` meshes owns the weapon; the costume weapon hides, and comes back when a later phase's template has none |
| `test_boss_presentation` | +4 checks, 197 → 201; 6 checks fail on the old code |
| QA tools only (unmapped, not in the place) | `tools/qa/HumanPlaytest.server/.client.luau`, `tools/qa/human_playtest.py`, `tools/qa/BossTemplateCheck.luau`, `OmniCombatProbe` (`health`, `dashTrack`) |

**Checks:**
- `bash tools/verify_all.sh`: SUCCESS.
- `python3 tools/lune_compat.py --all`: 21 suites, 2,280 checks, 0 failed.
- `python3 tools/build.py`: 263 sources, 489 asset IDs.

## Human actions (owner)

1. **Play the 20-minute route.** Use `HUMAN_PLAYTEST.md`. Record the screen if you can, and fill in `HUMAN_OBSERVATIONS.md`. Claude then fixes only the faults you saw.
2. **Earned session 1.** Play route A in one sitting with no panel, then say "log the session" before Stop.
3. **Persistence for the full campaign.** Set up a private test experience with Studio API access; this is route B in `F02_RECOVERY.md`.
4. **Shen concept sheets.** Take the five prompts in `SHEN_ASSET_HANDOFF.md` §7 to ChatGPT, then sheets 1–3 to Rodin. Deliver models, clips and sounds per §1–6. Upload them under the experience owner.
5. **Shen music.** Commission or clear `BossMusic_GrandmasterShen`. Per-attack SFX also need a small dev hook first (§6).

## Windows-only tests (Wednesday night, other computer)

1. **Two-client grounded PvP.** Run `tools/qa/OmniPvP.server.luau` + `.client.luau`:
   - a hit, and a whiff 35° off;
   - the spin exploit refused;
   - cued dodge and deflect;
   - air limits.

   This is the gate for PvP acceptance. Do not mark it accepted from Mac evidence.
2. **Human PvP fairness** with two people: tracking at 240°/s, the 0.15 s commit lead, circling vs thrust and sweep.
3. **Controller and touch.** Lock-switch flick (stick and swipe), and dash and deflect timing on a pad.

## Open fairness questions (need human play before any tuning)

- **Monk:** 0.23 s to act between a punch and the next heavy.
- **Twin Sentinels:** synchronised swings 33–50 ms apart from two sides, and the Bull's body filling the camera at close range.
- **Dash:** the server body has moved 35% of the dash by the time the i-frames end.

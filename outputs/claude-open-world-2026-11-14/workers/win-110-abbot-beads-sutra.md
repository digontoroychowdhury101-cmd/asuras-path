# win-110: The Fallen Abbot's beads and the Sutra of Mending (Windows, 28 Nov 2026)

## Creator decisions
- Shen's relic is the Abbot's prayer beads. Taking them teaches a spell the player keeps.
- Spell: Sutra of Mending, a chanted heal for you and nearby allies. It takes a normal spell slot from the Spells tab.

## Art
- Generator: `tools/blender/landmarks/bellwood_beads.py` (bellwood_lotus helpers). Outputs go to `assets/source/landmarks/bellwood_beads/` (gitignored source).
- One 2048 atlas, `Vesp_Bellwood_Beads__Relic`, split into aged bronze, jade, silk and lacquer quadrants.
- `Bellwood_AbbotTray` (Lacquer, 14,380 tris): a lacquer tray with a piped silk cushion, 3.1 × 2.2 studs.
- `Bellwood_AbbotBeads`: Beads (15,552 tris) and Cord (12,300 tris).
  - 54 bronze beads in two coils with a jade head bead at the front.
  - A bronze counter bead and a silk tassel of 26 strands hanging over the rim.
- Embedded and split to `assets/build/bellwood_beads/upload/` (one part each, about 8 MB).

## Spell
- `SpellSchema` SutraOfMending (SpiritTalismans, 40 Qi, Self, radius 12):
  - four pulses 0.75 s apart, each restoring 8% max HP × potency;
  - 26 s cooldown;
  - half pace while chanting, and a stagger breaks it.
- `SpellEffects` heals the caster and non-hostile players in the same duel. The `SpellPulse` cue carries `healed` ids.
- Grant: `takeRelic` queues `ProfileStore.UnlockSpell`.
  - A first take returns `SutraLearned`, and Shen wakes as before.
  - A player who already felled Shen and lacks the Sutra gets `BeadsTaken`; the lake stays asleep.
  - Otherwise the take is refused with `BossFelled`.
- Client:
  - `SutraShow` shows jade light in the hands and a loop of beads circling the chest.
  - A 54-bead ground ring follows the caster.
  - Each pulse sends out a jade wave and a highlight on everyone it healed.
  - `SkillAudio` Sutra score uses owned Shen bead, chime and bowed-metal stand-ins.
  - `build_skill_audio.py` adds MendClick, MendHum, MendBloom and MendPulse. They are not rendered yet: scipy is missing on Windows.
- Altar: `LandmarkWorld.shenRelic` places the tray and beads when the registry has them, and keeps the placeholder sheath otherwise. The beads model is named `Relic`, so `showRelic` hides it while Shen is awake.

## Results
- verify_all: SUCCESS (61 PASS).
- Tests:
  - weapons and spells: 404 checks;
  - runtime: 19 scenarios;
  - boss runtime, including the grant and victor checks;
  - Stage 3: UnlockSpell;
  - Arsenal codex: 182/0.

## Upload and Studio (same day)
- Uploads:
  - `Bellwood_AbbotTray`: 76308932482157, Approved.
  - `Bellwood_AbbotBeads`: 97855661579037, Approved.
  - Ledger: `uploads/win_beads_landmark_ledger.json`.
- Registry:
  - Readback added 46 lines to `LANDMARK_KIT_UPLOADED.json` and removed none.
  - `bellwood_beads` was added to the `landmark` packs. `test_kit_registry`: 21 OK.
- `default.project.json` now maps `SutraShow`. Without it, Rojo and the build left the module out even though verify_all passed.
- Studio Play, single client (Development):
  - The colossal temple takes about 5–7 minutes to load in Studio. This was already true before win-110.
  - The altar showed the tray and beads. `RelicYaw` is now `math.pi`, so the jade head bead and tassel face the hall entrance. The lamp moved 7 studs above the plinth.
  - Holding Z gave `SutraLearned`. The toast showed, Shen began Summoning, and the beads hid.
  - Qi Sorcery listed the Sutra (Self and allies within 12 studs, 40 Qi, 26 s, 8% × 4). It slotted into slot 2.
  - E cast it: Qi 100 → 63, and the 26 s cooldown started. The hand glow, the circling mala, the 54-bead ground ring, pulse waves and the self highlight all appeared.
  - The first pass flooded the hall floor green. The glowing jade is now mixed darker, with floor light 0.6 and range 12.
  - Studio profiles are in memory, so a new Play starts without the Sutra.
- Not run in Studio:
  - two-client ally heal;
  - stagger interrupt;
  - an HP restore below max.
  These are covered by the runtime harness (19 scenarios), not by a live client.
- verify_all: SUCCESS. Digest 306/4089023/1985442455 matches Studio. Saved Development v96. Not published.

## Open
- Two-client Studio check of the ally heal and a stagger mid-chant.
- Render and upload the four synthesized Mend cues (needs scipy on Windows).

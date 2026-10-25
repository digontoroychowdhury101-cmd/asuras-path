# Batch B (07–09): combat contact, first ten minutes, combat lighting/audio — 25 October 2026

Original batches 09, 10, 03. Findings #2 #7 #11 #12 #13 #14 #15 #19 #20 #21 #36 #43 #44.

## Build and evidence
- Start HEAD `d006eb6` (digest 1783028740). End: rebuilt `places/AsurasPath.rbxlx` digest **1903357088** (252 scripts, 1,801,954 bytes). Studio scripts were kept in step with `tools/qa/studio_sync.py` during play; the temporary Play-only probe scripts were never saved and were removed from the Edit place.
- Local regression / engine emulation: `bash tools/verify_all.sh` SUCCESS → `F07_09_VERIFY_LOG.txt`. Focused: combat_contact 68 (+16), opening_tutorial 108 (+11), hud_layout 258 (+17), combat_presentation 161, objectives, audiovisual, stage1, boss_presentation 125, boss_runtime.
- Studio evidence types are labelled per item: **real Studio play** (keys/clicks through the injector, ~1 s tool latency) and **seeded Studio diagnostic** (server pivots, pushed intents, a server-tick reactor timing deflect/dodge to published telegraphs, seeded HP/KO protection). Nothing here is earned continuous-input play. Viewport 1221×503.

## Defects found and fixed (each with a regression that fails on the old code unless noted)
| # | Defect (reproduced in Studio) | Fix | Check |
|---|---|---|---|
| 1 | Every attack fell short of its authored reach: the tick that closes the active window ran Combat.step first, so full extension was never swept (Jian thrust at 7.8 studs whiffed every time, cue "MISSED") (#14) | `CharacterService.sweepClosingWindows` sweeps the closing tick before the step; timing/damage/rewind unchanged | contact +4 (real resolve/Lag/Combat in tick order); Studio: same swing hits at 8.43 |
| 2 | Killing deathblows paid nothing: the KO was emitted with source 0, and WorldService credits the KO's source (#21 rewards) | `CombatRules` KO names the stored executioner | contact +3; Studio: monk deathblow → KO credited, Essence 500→545 once |
| 3 | AI chase stalled: `Humanoid:MoveTo` times out after 8 s and the same point was never re-issued (phantom idled at 8.4 studs) | `CharacterService.MoveTo` renews every 4 s | contact +3; Studio: phantom closes in |
| 4 | Enemies steered to the player's root climbed onto their head (phantom 4.1 studs up, every swing passed beneath) (#15) | `BossBodies.closeIn` + `AIService` approach a point 0.6×reach short | contact +4; Studio: holds at 3.4–3.7 studs |
| 5 | Tutorial Dodge/Perilous advanced from any invulnerability (Studio logged the player "evading" while a deathblow victim) | Evade teaches only during a dash | tutorial +3 |
| 6 | Tutorial "Land a light attack with M1" advanced from spells, heavies, arts and burn ticks (spell path source-confirmed; spell press not landed in Studio) | Light counts only Light/RunningAttack moves | tutorial +2 |
| 7 | The key that skips the prologue (Space/click) folded the default-open Controls card before it ever showed (#43) | only an on-screen card folds | tutorial +1 |
| 8 | The Controls card's backdrop covered the handoff line "Kneel at the bonfire…" (#43) | prologue publishes `HandoffUntil`; card waits 4 s | tutorial +2; Studio timeline: veil 8.0 s → banner alone → card 12.0 s |
| 9 | Training card covered the Codex button and Controls pill | reserved `HudLayout.Training` region (right column) | layout +17 over 8 viewports; Studio view |
| 10 | Toast "At your lowered ceiling · gourd kept · rest restores…" ran under the training card | toast bounded to the centre band and wrapped (`HudLayout.Toast`) | layout; not re-captured |
| 11 | Skip training / stakes "Understood" unclickable with the captured cursor; stakes card overlapped the action bar | Skip names "hold [Alt] to click"; stakes card folds on combat and sits at 0.72 | tutorial +2; Studio: Alt+click ×2 → `Skipped`, ring protection lifted |
| 12 | Centre "EVADED" shown while the player lay helpless after a deathblow | callout requires own Dashing state | source check; not re-captured |
| 13 | Plate/lock stayed 1.65 s at 0 HP during a killing deathblow | `IsAlive` treats an executed 0-HP victim as dead | source check; not re-captured |

## 07 contact, heal, defeat (seeded Studio diagnostic unless noted)
- Six outcomes vs the lone monk, cues logged on the client and matched to server events: out-of-range whiff (+2.8 and +1.4 → "OUT OF REACH +x"), light hit (8, 85→77), heavy hit (20, 82→62), monk blocks heavy (2 chip), player block (0.2 chip), player evade (Evade while Dashing), feint (tryFeint at +50 ms: Startup→Idle, 4 stamina, Feint event). Ten damage popups matched server values exactly (real play). Real-key feint not achieved: tool delivered F 266 ms after V (window 0.15 s; client sees Startup at +81 ms) → human.
- Heal (real R): full HP → "Health is full · gourd kept (3 left)"; wounded 60 → 100, gourd 3→2; lowered ceiling 80/100 → refusal, gourd kept, HUD "max −20 · rest restores". Last charge not exercised.
- Deaths: monk (deathblow) and swordsman (damage): AsuraDissolve set, no loose parts at any sample, fade ~2.1 s, model removed ~4 s, Essence/Unbanked once (+45, +80). Swordsman plate cleared 0.86 s after KO. After deaths/respawns: 0 wisps, 0 ash, 0 orphan damage billboards, 1 live audio source.
- Observed, routed: the bridge swordsman dashed into the ravine (y −6.8) and sat in Return mode, unreachable → 14 (#3). Unlocked camera hides a foe directly ahead behind the avatar → 24.

## 08 first ten minutes (real Studio play; training steps after Light via seeded reactor)
- Fresh profile: black veil, no unfinished avatar; prologue play and Space-skip; handoff banner then controls card; bonfire rest (0.4 s hold), portal, Gate kindled, Training 1→10 Complete; each step advanced only on its own server event (blocks before Guard ignored, guard-break taught nothing, deathblow-victim Evade taught nothing); practice paid no Essence; Skip persisted; stakes card at the courtyard; memorial I → Codex 1/8, +100 once; Respite Replay opening plays.
- First action: lock-on. First success: light hit after fix 1. First death/confusion: lone monk killed an idle player in ~4.4 s (10 consecutive hits) while the stakes paragraph was up; the phantom's combo/perilous loop at the 1 HP floor and its follow to the Gate altar (rest refused) make training hard without continuous input → human test, no tuning from tool play.

## 09 lighting/audio (seeded Studio diagnostic; continued 25 Oct, digest 591768240)
Additional fixes:
| # | Defect | Fix | Check |
|---|---|---|---|
| 14 | Bare Titan and Wu duel floors (slate 49,45,43) rendered black at the dusk sun; dark costumes (the player, Wu) vanished on them (#2) | `BossArenas.FloorColor` mid stone (118,110,100); lights unchanged, no fullbright | presentation +2 (luminance band); Studio before/after views |
| 15 | Spell bloom and flash sphere ignored Reduced flashes (bloom stayed 1.0) (#36) | `VoidStage.bloom` and `SkillFx.flash` pass through `EffectsPreference.flash` | presentation +2; Studio Blazing Sun: full bloom 1.00/sphere T 0.05/light 8 → reduced 0.35/0.67/2.8 |

| Arena | Combat light (ordinary distance) | Phase 2 | Exit by death → region profile restored |
|---|---|---|---|
| Twin Sentinels | readable | n/a (1 phase) | yes (exact values) |
| Grandmaster Shen | readable; walk-in entry dark only during the 2.4 s profile blend, readable once settled | readable (Unbound red) | yes |
| Venerable Baize | readable | readable, darker | yes |
| Slumbering Titan | readable after fix 14 (was near-black) | readable after fix 14 | yes |
| Sovereign Wu | readable after fix 14 (was near-black) | readable | yes |
| Azure Wyrm | readable | readable | yes |
- The red/purple floor cast in Wu's arena is Wu's own Gravity/Ritual hazard disc (BossEffects, camera-parented Neon, CanQuery off) — an intended telegraph, not a defect.
- Petals: exploring 14/14 at 0.30 transparency; combat 4/14 at 0.72; combat with Reduced effects (saved through Respite > Settings > Apply) 0/14.
- Audio lifetime (client counts; baseline 9 world sounds / 0 sources): two combat cycles (hits, counter-hits, blocks, deflects, rally, death) peaked at 11 sources and returned to 9/0 after death and respawn; rest added none. In-engine SpatialAudio paths: 10 source-first and 10 sound-first destructions → 0 voices/0 sources; unloadable asset leaked nothing; 40-cue burst capped at 32 (budget) and fully released after 13 s. Client and server error/locked-Parent log scan across all cycles: **0**.
- Mid-cast death: Celestial Supernova (AsuraSkillGrade, AsuraSkillBloom, SkillVoid present) and Blazing Sun (grade, bloom, skill overlay present) — all removed at the death sample, the death cue's source released within ~1 s, 0 errors.
- Observations → 24: on a 1221x503 window the centre perilous warning overlaps the boss bars, and Respite's Settings > Apply and "Replay opening" sit below the panel's visible area (scroll required). Logs prove lifetime only; how the mix sounds is 25.

## Remaining (exact)
- 07/08: earned continuous-input deflect/feint/duel fairness and onboarding difficulty (human); last-charge heal; death during the replayed opening; visual re-capture of fixes 10, 12, 13.
- 09: another player's encounter on this client and two-player lighting → 23; listening/mix quality → 25; short-window layout notes → 24.

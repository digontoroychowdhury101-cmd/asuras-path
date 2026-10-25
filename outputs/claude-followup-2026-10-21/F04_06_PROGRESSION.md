# Follow-ups 04–06: rest, Lin portraits, leveling, Arsenal, Codex, boss rewards and forging (24 October 2026, macOS, Computer A)

Original batches 05 (rest/Lin/leveling), 06 (Arsenal/Codex) and 08 (boss rewards/forging). Findings #4, #8, #9, #38, #39, #40, #41, #42.

## Build and evidence
- Start: HEAD `3cde4b5`, which matched the place file and Studio. End: rebuilt `places/AsurasPath.rbxlx` digest **1783028740** (252 scripts, 1,796,301 bytes). The open Studio place matched it exactly after the temporary QA harness was removed.
- Evidence type: **seeded Studio diagnostic** (solo Play, in-memory Studio mock store). Placement used server pivots. Rest, Summon, Leave, Travel, Ascension, the Codex, the Arsenal and Gao's forge were driven by real prompts and UI clicks through the Studio injector.
- **Diagnostic, not earned:** boss victories were recorded by calling the live store's `RecordBossDefeat` (the same call `WorldService.endFight` makes), and the full Codex state came from writing `LoreEntries`. The only real-interaction lore entry is memorial I. "Rejoin" is a storage round trip (`Release` then `Load`: Migrate + Validate on the same mock record), not a player rejoin. Enemies that blocked a rest were removed with scripted damage.
- The QA harness was a Play-only server script in the open place (never saved) and was deleted before the digest check.
- Local regression and engine emulation: `bash tools/verify_all.sh` 14/14 SUCCESS → `F04_06_VERIFY_LOG.txt`. Focused suites: rest_dialogue 63, arsenal_codex 169, boss_rewards 131, progression_runtime 89, weapons_and_spells 374, recovery_lifecycle 100, movement 59, opening_tutorial 97, hud_layout 176, review regressions 21.
- Views: `f04-views/` (19 images, 1221×503 Studio viewport).

## Defects found and fixed
| # | Defect (reproduced) | Fix | Regression / verification |
|---|---|---|---|
| 1 | The portrait put Lin's head at the screen centre, but the panel spans 40–90 % of a short screen, so only her eyes showed above her name | `Portrait.aim` pitches the shot so the face sits midway between the top bar and the panel. `DialogueView.faceY` computes that band from the layout constants, because the just-enabled panel's `AbsolutePosition` read 0 and sent the head to 5 % | `test_rest_dialogue` +2 (fails before). Studio: head 0.30, crown 0.22, chin 0.36, inside a 0.19–0.40 band at all three altars |
| 2 | From behind the Gate altar, the player's straw hat covered half of Lin's face. The costume has `CanQuery=false`, so no probe can see it | The local avatar is hidden (`LocalTransparencyModifier`) while a portrait is framed, and restored on close, the Codex view, a replacement view and death | `test_progression_runtime` +3 (fails before). Studio: avatar hidden 57/57 → restored 0/57 on Leave; respawn mid-dialogue leaves nothing hidden |
| 3 | Travel to the Primal Bonfire landed on its spawn 20.1 studs out, refused to rest (`!TooFar`), and left the old checkpoint active. It was the only altar outside reach | `RecoveryRules.arrival` lands within resting reach, facing the altar, so `restAt` succeeds | `test_recovery_lifecycle` +3 (fails before). Studio: Gate → Bonfire arrived 8 studs out, result Rest, checkpoint and profile updated, gourd 3/3, altar menu at the destination |
| 4 | At the Cloister, the rest respawned a monk (43 studs) and a swordsman (60) that engaged at once, and "Summon Lady Lin" then did nothing and said nothing | The server answers `Refused` ("Lady Lin cannot answer while foes hunt you"), the client shows a toast, and the altar menu stays | `test_progression_runtime` +1 (fails before). Studio toast seen |
| 5 | The Arsenal's slot buttons drew "✓ Slot 1 [1]" with an old-style 1 that read as "ı" | The slot buttons use GothamMedium (the ControlsCard key face) | Studio view |
| 6 | The tutorial TRAINING card and the Controls card drew beside or over the open Arsenal | The tutorial card hides while any window owns input; the Controls card is hidden (not closed) under a window, and H does not reopen it there | Studio: card visible → B → hidden; Arsenal alone |
| 7 | The Weapons tab footer was clipped mid-sentence; its Jade Catalyst sentence never showed | The redundant sentence was removed (the Catalyst card lists "spells ×1.25 · faster casting") | Studio: fits, 238×28 in a 239×36 label |
| 8 | Forge refusals showed "ServerScriptService.AsurasPath.Services.LootService:52: Remembrance unavailable" | Assert prefixes are stripped, as DialogueService already does | Studio toast: "Remembrance unavailable" |
| 9 | (Prompt 03 code) The altar's new Backspace back key | — | Studio: dialogue → altar → closed with Backspace ×2 |

## Rest, Lin and leveling (#4, #38, #39, #40)
| Altar | Rest | Summon | Portrait (face band) | Leave | Notes |
|---|---|---|---|---|---|
| Primal Bonfire (in person) | Rest | dialogue | 0.30 (crown 0.22, chin 0.37), no blocker | back to the altar menu, prompts hidden while it is open | before/after views |
| Monastery Gate (projection), front | Rest, kindled | dialogue | 0.30, clean | altar → Backspace closes, no spirit clone left | |
| Monastery Gate, behind the altar | Rest | dialogue | 0.30; hat over the face before fix 2, clear after | avatar restored | before/after views |
| Desecrated Cloister (projection) | `!EnemiesNearby` toast until cleared | refused with a toast while hunted; dialogue once clear | 0.30, readable; the incense burner sits behind her hair | — | death mid-dialogue → respawn 7.4 s at the Cloister, LockCenter, prompts back, FOV 70, no clone |
- Travel: listed both kindled altars ("(here)" marked) and moved the checkpoint after fix 3.
- Leveling (Vigor at the Bonfire): the preview said Max HP 100 → 106, cost 150, 350 left. A rapid double click sent two `LevelUp` intents. Result: one level, Essence 500 → 350, Vigor 11, Humanoid MaxHealth 106 (matches the preview). The second click was refused (level 3 costs 395 > 350) with Essence unchanged, and the panel then showed "Need 45 more Essence (350 / 395)" with all "+" dimmed. The attribute list scrolls (canvas 296 in a 184 viewport). Arcane Qi is a separate attribute row ("Max Qi 100 → 103").

## Arsenal and Codex (#41, #42)
- Qi Sorcery tab, starting loadout: Thunderclap Palm "Cone 65° · 8 studs · 18 Qi · 6s cooldown · 0.08s cast; 16 damage · 32 posture · interrupts (0.4s stagger)" and Gale Step "dash 18 studs · 20 Qi · 7s". Slots show "Slot 1 [1]" / "Slot 2 [E]" from InputMap.
- After forging: Thunderfall was put in slot 1 through the UI and cast with 1. Qi 100 → 60 after 2.5 s (45 cost plus regeneration), and it carried the player 29 studs toward the aim point. The Weapons tab rebased every comparison on the newly wielded Prayer of the Defiled.
- Codex matrix: **0/8 · 0/6** (instruction text fits, locked rows show only their region); **1/8** after reading memorial I (real prompt; +100 Essence; entry text fits; "7 inscriptions remain"); **8/8 · 6/6** (diagnostic; six sovereigns "at rest"; crossing line "Lady Lin waits beside the Primal Bonfire"). Closing restores input (K → Swap). NarrativeCatalog is replicated, so lore is hidden in the normal UI only, not at network level.

## Six-sovereign recipe and result table (#8, #9) — diagnostic awards, UI and remote forging
| Token (boss) | Boss Essence | First award | Duplicate award | Forged (one choice) | Sibling request | After the storage round trip |
|---|---|---|---|---|---|---|
| Grandmaster Shen | 4000 | +4000, +2 tokens (Shen + Chimera), ore +8 | no change | Prayer of the Defiled (UI Forge → Confirm, rapid ×3 → 1 intent) | Abbot's Dirge shows Spent | owned, token kept, spent |
| Demonic Chimera (Shen's 2nd token) | — | with Shen | — | Fissure Slam (remote ×3 burst → 1 forge) | Calamity Bone Cleaver refused | same |
| Venerable Baize | 4400 | +4400, +1, ore +8 | no change | Iron Tessen (WarFan) | Wind-Cutting Slash refused ("Remembrance unavailable") | same |
| The Slumbering Titan | 6400 | +6400, +1 | no change | Grave Tendrils | Colossal Odachi refused | same |
| Sovereign Wu | 5000 | +5000, +1 | no change | Jade Spell Staff (Catalyst) | Blackflame Surge not forged | same |
| Twin Sentinels (General Zhao) | 4000 | +4000, +1 | no change | Thunderfall | Heaven-Piercing Guandao refused | same |
| Azure Wyrm | 6400 | +6400, +1 | no change | Chain Scythe | Dragon's Maw refused | same |
- Totals: Essence 500 → 30,700, recorded once. 24 Forge intents produced exactly 7 forged items. A re-award after the reload changed nothing. A forge away from Gao: "Visit Master Smith Gao in the Loggia".
- Malformed tokens: writing `remembrances.GrandmasterShen = true` or a token naming the wrong boss failed store validation ("Invalid arsenal inventory"), and nothing persisted. UI states (Locked → Forge → Confirm? → Spent) matched the server's `recipeState`.
- Storage round trip (`Release` + `Load`): weapons, spells, tokens, spent flags, bosses, lore 8, ore 48, mainhand and slots identical.

## Observations (not changed here)
- Requests dropped by the 5-token intent budget or the per-player `busy` guard get no reply. That is safe (never a duplicate), but a burst click can go silent → 24 (feedback polish).
- Display names differ between surfaces: recipe "Azure Chain Scythe" vs weapon "Chain Scythe"; the boss bar and gate say "General Zhao" while the forge and objective say "(The) Twin Sentinels".
- The Ascension "+" glyph is tiny on its pink button → 24 readability.
- Enemies respawned by a Cloister rest engage at once (43–60 studs) → 07/22 (altar safety and aggro).
- The diagnostic store write does not refresh the HUD Essence attribute until the next WorldService publish; the real victory path publishes.

## Remaining (exact)
- Earned boss victories (real kills → token → Gao) and a real player rejoin → 22 / 23 (Team Test).
- Portraits were checked at 1221×503 only. The band is analytic in viewport size; other viewports and devices → 24.
- Controller focus paths in the Arsenal, altar and forge on hardware → 24.

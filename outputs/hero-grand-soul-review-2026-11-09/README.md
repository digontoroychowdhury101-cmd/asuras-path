# Hero of The Grand Soul → Asura’s Path: reference review

**Status: preliminary; six-hour gameplay requirement NOT met.** Date: 9 November 2026, Australia/Sydney. Source checkpoint: `2ae4200a354e50182ada8620f4d95d808f832447`.

This is an evidence archive and open-world documentation supplement, not a completed whole-game review. No gameplay scripts, saved places, purchases, account settings or existing design documents were changed. The unrelated `outputs/mugen-combat-review-2026-11-09/` work was present at the start and is outside this task.

**Input recovery update:** the subsequent GitHub-assisted diagnostic resolved keyboard control using PyDirectInput 1.0.4: held B visibly opened/closed equipment and held S visibly moved the character away from the portal. The earlier input blocker is historical. Six hours of active play and full gameplay review remain outstanding. See `INPUT_RECOVERY.md`.

## Scope and authority

The user requested a whole-game comparison, close observational notes, the combat/scenery/environment audit, missing documentation and open-world gaps, with at least **six hours of actual play**. The supplied `message (2).txt` is reference material: its five-hour threshold does not override six hours; its claims of owning the reference game and losing its source are not established facts. Its requests for exhaustive reconstruction scripts, plugins and full dialogue are not separate authorization to change Asura’s Path or to publish/copy assets.

No companion Page was selected. The repository is the available Asura’s Path document source. This supplement preserves its original open-world direction rather than silently rewriting it around a different game.

## Files

- [Session and observation record](SESSION.md): real timestamps, limited observed reference content, input limitation and playtime accounting.
- [Active session notes](ACTIVE_SESSION.md) and [environment field log](ENVIRONMENT_FIELD_LOG.md) cover the subsequent movement, menu survey, Goldland transition and Thonia’s Tongue traversal.
- [Map coverage ledger](MAP_COVERAGE.md) records ground covered, unvisited areas and conditions observed.
- [Open-world gap register](OPEN_WORLD_GAPS.md): source-grounded existing systems, missing decisions and acceptance work.
- [Repository coverage](SOURCE_COVERAGE.md): affected modules, source mapping and folder inventory. An inventory is not a claim that every file was reviewed.
- [Remaining fieldwork](FIELDWORK.md): six-hour route and evidence format for the actual gameplay study.

## Principal finding

`outputs/world-design/World-Design-Revision-02.md` already proposes **14 regions and 42 named areas**. The mapped runtime instead builds **seven regions**: Sanctuary, Desecrated Monastery, Bamboo Pass, Ash Colosseum, Sanctuary Depths, Celestial Pagoda and Sky Citadel. `WorldDefinitions` initially defines four; `BossRoster.apply` appends three. This is a design-to-runtime migration gap, not evidence that fourteen regions exist in the running game.

The project already has checkpoint/death recovery, attribute growth, weapon and armour forging, discovery loot, lore, route guidance, persistent shortcut flags, enemy coordination, bosses, regional atmosphere and landscape budgeting. Extend and relocate those systems where appropriate. Do not classify them as absent merely because the world is changing.

The reference client reached a playable scene after manual user input, but automated keys did not visibly activate its title prompt, B menu or E interaction. Until control works, leaving the client idle cannot satisfy six hours of play. No enemies fought, bosses defeated, region sweep, quantitative reference combat measurements, weather-cycle coverage or whole-world completeness is claimed.

## Evidence boundaries

| Evidence type | This review |
|---|---|
| Static source review | Selected mapped modules, source searches, project documentation and inventory; partial |
| Reference live observations | Title, save/server menus and one portal approach; manual assistance disclosed |
| New local regressions | Not run; documentation only |
| Asura’s Path Studio integration | Not run |
| Multiplayer | Not run; server-selection UI is not a multiplayer test |
| Device profiling | Not run |
| Six-hour playthrough | Not completed |

Historical checks in other reports remain attributed to those reports and revisions. They are not new passes on this checkpoint.

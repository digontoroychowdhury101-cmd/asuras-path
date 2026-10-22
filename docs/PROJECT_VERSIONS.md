# One working Asura's Path project

Use `/Users/digonto/Documents/ChatGPT/Roblox game 2` as the working source. Build with `python3 tools/build.py` and open `outputs/AsurasPath.rbxlx`. The source, current Rojo tree and asset library belong together; an old place opened from Recents does not automatically contain current source.

The similarly named Studio cards are saved development snapshots, not features waiting to be merged. Inspection on 21 October found 34 scripts in the early Test/Playtest builds, 35 in the Courtyard builds, 130 in the Phase 5 snapshots, and 205 in the pre-VFX main build. The current main build includes seven additional visual modules. Reintroducing all the old scripts would bring obsolete copies of the same game back into the project.

| Studio item | Role | What to use |
|---|---|---|
| AsurasPath / current `outputs/AsurasPath.rbxlx` | Main game built from this source checkout | Continue development here. |
| AsurasPath-Test / Playtest | Early 17 October test snapshots | Retain as recovery history; do not merge their scripts. |
| AsurasPath-Courtyard / Courtyard-v2 | 18 October scene iterations | Retain as history; current source already contains later world work. |
| AsurasPath_Phase5 / verified | 19 October audiovisual snapshots | Retain as history; the current asset library and source are newer. |
| VFX (place 99240829139422; universe 10771730783) | Separate cloud demo containing Sanguine visual and gameplay scripts | Keep as an authoring/reference sandbox. Selected visual motifs are now adapted into the main game. |
| F01 / verifier / audit files | Temporary QA outputs | Test evidence, not the development source or a new release. |

Keep one main game and a separate VFX authoring sandbox. Reusable assets/modules can live in the main source/asset library without copying the demo's entire place. Recents merely records files/experiences opened; retaining a recovery file does not require treating it as an active version. No cloud experience or historical file was deleted, merged wholesale or published during this integration.

## VFX integration boundary

Seven small `Sanguine*` client modules adapt the demo's layered weapon crescents, crimson/cobalt parry, contact sparks, dodge silhouettes, spell energy, ground impact and phase/defeat motifs. They observe existing authoritative events, cues and active attack snapshots. Actual move reach comes from WeaponSchema. The existing GameFeel, spell effects, trails, feedback, warnings and boss controllers remain in place.

Four client-bootstrap lines load/create/update/destroy the visual controller; the Rojo tree registers its modules. Server, simulation, networking and shared gameplay files are unchanged. There are no imported demo key bindings, movement forces, damage, boss AI, arena builder, alternate HUD, camera shake, post-processing or global lighting override. Boss defeat draws separate effects and never resizes/recolors the real boss. Existing hazard telegraphs retain their timing and footprint.

The layer has 8 simultaneous groups, 192 total decorative parts, 32 parts per group and a 120-particles/second token refill with a 60-token burst capacity. Reduced effects lowers group/part/burst counts; reduced flashes dims the added geometry. Every decorative part is anchored, non-colliding, non-touching and non-querying. Effects are local, expire through one controller update and clear on relevant local lifecycle transitions. Foreign player rest/travel/reset does not clear local effects. A rendering failure disables this layer and preserves existing effects.

## Verification and rollback

The consolidated local verifier passed; all 213 source scripts compiled and the complete main place builds. The detached Studio client fixture passed 194 engine checks, including all 12 weapon families, actor/camera/lighting/health invariants, deduplication, bounds, cleanup and teardown. A subsequent ownership-isolation refinement passed 30 focused tests against the actual dispatcher; it was syntax-checked and rebuilt after Studio disconnected. It is included in future `lune_compat.py --all` runs.

These checks use test state/adapters, not an earned campaign run. A short diagnostic rendering attempt was made in the existing F01 client session; screen capture returned HUD over a black scene and was not usable for appearance approval. Normal integrated gameplay appearance, sustained frame-time performance and device visual review remain pending. No perfect/no-regression guarantee is claimed from these checks.

To disable the added visuals while retaining existing effects, set the Workspace attribute `AsuraSanguineVFXEnabled` to `false` in the test place. To persist that choice across fresh builds, add the attribute in the Rojo tree or remove the four Sanguine bootstrap lines. No gameplay migration is needed. Full pre-integration bootstrap/project copies and the saved place are in `outputs/vfx-integration-2026-10-21/backups/`. Preserve later unrelated edits when using a backup.

The original three VFX sources, hashes, build inventory, regression log, engine fixture/results and integration manifest are preserved in `outputs/vfx-integration-2026-10-21/`. The raw exported demo scripts are evidence only and are not registered in the game.

1. Open the current main build, play at a readable normal camera angle, and verify ordinary swings, parry, dash, spells and a phase/defeat diagnostic with comfort settings on/off.
2. Compare enabled/disabled runs, then check rest/death/travel, no new output errors, cleanup and frame time on desktop and the target mobile device before publishing.

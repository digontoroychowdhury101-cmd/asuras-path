# ASURA'S PATH (修羅之道) — LIVING PROJECT STATE & HANDOVER JOURNAL

> **Last Updated**: 2026-10-19 19:30
> **Status**: UX/onboarding overhaul on branch `ux/onboarding-overhaul` (Studio-verified via Rojo sync).  
> **Built Target**: `outputs/AsurasPath.rbxlx` — rebuilt 2026-10-19 with `tools/build.py` (includes the Desecrated Monastery map).

---


## Phase 2 — Weapon ecosystem, discovery and Qi sorcery (2026-10-19)

- Arsenal: nine families including Unarmed, with Odachi, Twin Shadow Sai, Chain Scythe, Iron Tessen and Jade Catalyst added to the original four. Three boss variants bring the equipped weapon registry to 12 entries. New authored specs live in `WeaponExpansion.luau`; all use `WeaponSchema` validation and Tempo timing.
- Boss armaments: Shen wields Prayer of the Defiled, his Chimera phase uses Calamity Bone Cleaver, and the Ash Pagoda General in southern Bamboo Pass wields the Heaven-Piercing Guandao. Their arts release draining incense, a magma fissure and a lightning throw/impact teleport. Censer deflects add 25% reflected posture; sai backstabs multiply damage by three. Chain snares respect defense before pulling with LinearVelocity; fan finishers launch projectiles and held guard parries projectiles.
- Magic: `SpellSchema`, `SpellRules`, `MagicService`, `SpellEffects` and `SpellGeometry` implement all eight core spells across four disciplines plus three transmutable signature spells. Cast startup/recovery use Tempo; interruption cancels pending casts. Server checks ownership, Qi, cooldowns, hostility, walls and teleport clearance. Burn stacks, two-second roots, lethal/posture wards and AI phantom decoys are active. Catalyst primary/off-hand focus grants 25% potency and faster startup.
- Qi: base/max 100, starts full, +8 on melee hit, +15 on perfect deflect, passive 2/sec. Blocked melee contacts give no Qi. Spell damage does not refill Qi.
- Discovery: five one-time caches in waterfall alcove, pagoda rafters, mausoleum, Loggia eaves and Sanctuary reliquary grant weapons and spells. Gao's Loggia seal opens transmutation; each remembrance chooses one weapon OR signature spell. Immutable token provenance remains stored while a separate consumed ledger prevents reuse. All major campaign bosses award tokens; defeating Shen awards both Shen and Chimera tokens. Existing cleared encounters receive tokens through migration.
- Persistence: Souls schema is now version 3; older inventories migrate with two starter spells, cache flags, slots and remembrance ledgers. Corrupt version-3 arsenal ledgers fail closed. Combat packet version is 3 and includes all 12 weapon keys. `ArsenalIntent` validates exact bounded payloads and server rate limits.
- Controls/HUD: Q/E or D-Pad Up/Down cast; both diamond HUD cards are touch buttons. B/Select opens the arsenal for spell slots and weapons; Shift dodges, Z interacts, J swaps, R/Start heals, Caps/D-Pad Left sprints. Cyan/gold Qi arc and count sit below stamina, with cooldown sweeps on both spell cards. Client VFX include rings, hand glows, beams, pillars, tendrils, talismans and decoys. New weapons use local geometry and existing stock animation families.
- Verification: 320 checks pass in `tools/test_weapons_and_spells.luau`, covering contracts, payloads, Qi, casts, focus, wards, roots, caches, atomic forging and save/rejoin. `tools/test_weapons_and_spells_runtime.py` passes 14 scenarios using actual server effect modules under spatial/engine shims for piercing, wall blocking, delayed pillars, burn stacks, roots, decoys, Thunderfall impacts, parries and cancellation. Studio visual/device playtesting remains necessary; CLI verification does not certify animation or HUD appearance.

## 1. PROJECT IDENTITY & PILLARS
- **Genre**: Grimdark Wuxia Souls + High-Tempo Action Combat Hybrid.
- **Combat Core**:
  * 1.4× Tempo baseline (`src/simulation/Tempo.luau`).
  * Hybrid Weapons: nine families plus three boss armaments in `src/simulation/WeaponSchema.luau`.
  * Sekiro-style Posture & 100ms Deflect: Posture buildup, Deflect sparks, StanceBreak stun, cinematic Deathblows in `src/simulation/CombatRules.luau`.
  * Blood Rally & Tri-Layer HP: ActiveHP, RecoverableHP (debt restored via aggressive counter-attacks), PermanentDeficit in `src/shared/CombatSettings.luau`.
  * 60 Hz Circular Ring Buffer Lag Compensation with 150ms max rewind in `src/server/LagCompensation.luau`.
- **PvE Story Mode**:
  * Semi-open overworld regions: Desecrated Monastery, Bamboo Pass, Ash Pagoda in `src/shared/WorldDefinitions.luau`.
  * Incense Altar (bonfire) checkpoints, Lost Qi / bloodstain death drops in `src/server/Services/WorldService.luau`.
  * Mob AI and multi-phase Boss engine (Grandmaster Shen / Demonic Chimera) in `src/server/Services/AIService.luau`.
- **PvP Colosseums**:
  * Overworld dueling rings with 1v1 Ranked (normalized stats) and Casual sparring in `src/server/Services/ColosseumService.luau`.
- **Client Presentation**:
  * Third-Person Over-the-Shoulder Camlock (offset: 1.8, 1.4, 10.5) in `src/client/Controllers/CameraController.luau`.
  * Game Feel: Sparks, hit-stop, camera shake, concussive eye trauma blur/sway in `src/client/Controllers/GameFeelController.luau`.
  * Minimalist Souls HUD in `src/client/Controllers/InterfaceController.luau`.

---

## 2. ACTIVE DIRECTORY STRUCTURE & MAP
```text
/Users/digonto/Documents/ChatGPT/Roblox game 2/
├── default.project.json              # Rojo tree (AsurasPath namespaces)
├── README.md                         # Project specification overview
├── PROJECT_STATE.md                  # This living handover journal
├── outputs/
│   └── AsurasPath.rbxlx              # Active compiled place file
├── tools/
│   ├── build.py                      # Rojo place compiler
│   ├── cleanup_legacy.py             # Legacy file archiver
│   ├── test_asura_stage1.luau        # Stage 1 test suite
│   ├── test_asura_stage2.py          # Stage 2 test suite
│   └── test_asura_stage3.luau        # Stage 3 test suite
└── src/
    ├── client/
    │   ├── Bootstrap.client.luau
    │   └── Controllers/
    │       ├── CameraController.luau
    │       ├── ColosseumController.luau
    │       ├── GameFeelController.luau
    │       ├── InputController.luau
    │       ├── InterfaceController.luau
    │       └── WorldStateController.luau
    ├── server/
    │   ├── Bootstrap.server.luau
    │   ├── CharacterService.luau
    │   ├── LagCompensation.luau
    │   ├── PersistenceService.luau
    │   ├── ProfileStore.luau
    │   ├── ShopService.luau
    │   └── Services/
    │       ├── AIService.luau
    │       ├── ColosseumService.luau
    │       └── WorldService.luau
    ├── shared/
    │   ├── AnimationCatalog.luau     (Asset slots & fallbacks)
    │   ├── CombatSettings.luau       (Tri-layer HP, stamina, tempo)
    │   └── WorldDefinitions.luau     (Regions, Altars, Spawns)
    └── simulation/
        ├── CombatRules.luau          (Pure-functional combat resolver)
        ├── InputBuffer.luau          (100ms priority queue)
        ├── MoveSchema.luau           (16-state combat machine)
        ├── Tempo.luau                (1.4× temporal scaler)
        └── WeaponSchema.luau         (Move trees for 4 weapons)
```

---

## 3. ARCHIVED LEGACY CAGEBOUND FILES
All 128 Phase 1–12 Cagebound places and docs have been moved out of this project into:
`~/Documents/Cagebound_Archive/` (safe external archive).

---

## 4. UX / ONBOARDING PASS (2026-10-19)
- **Boot fix**: `SanctuaryService` titan auto-mount line was a Luau parse error (`(model :: any):ScaleTo` after a `local`), so the server never booted and players sat on the loading cover forever.
- **Objective tracker**: pure resolver `src/shared/Objectives.luau` (tested by `tools/test_objectives.py`) + `ObjectiveController` (top-right card, "NEW OBJECTIVE" flash) + `WaypointMarker` (gold ◆ with distance). Route: first rest at Primal Bonfire → Ascension Stairs → each altar in order → fog gate → Colosseum; bloodstain recovery takes priority; hidden in boss fights/duels. Server now mirrors defeated bosses to the read-only `AsuraBosses` attribute.
- **Controls card**: `ControlsCard` shows device-aware bindings (keys come from `InputController:Label`), auto-folds to a `[H] Controls` pill after 25 s; toggle H / D-Pad Left / tap.
- **Responsive HUD**: `HudKit.bindScale` scales Vitals, Loadout, Altar menu, objective card and the touch cluster by viewport height (clamped 0.7–1.35 vs 900 px); death screen and toast use scale widths.
- **Prompt double-fire**: E / ButtonX no longer sends the instant `Interact` intent while a ProximityPrompt is on screen (the prompt's hold owns it); touch USE drives the visible prompt.
- **Loading cover**: rotating gameplay tips; after 20 s without `Workspace.AsuraReady` it says the server failed to start (Studio) / is not responding (live).
- New shared kit `HudKit.luau` (palette, helpers, UI cue sounds). All new modules ≤150 lines.

## 5. VISUAL PASS 1 — SANCTUARY SET PIECES, ENEMY LOOKS, PROLOGUE (2026-10-19)
- **Asset pipeline**: CC0 Poly Haven sources in `assets/source/` (git-ignored) → `tools/blender/process_asset.py` (headless Blender: decimate ≤19.5k tris/MeshPart, 1024 PBR maps, GLB + PNG maps) → `tools/blender/preview_asset.py` (QA render) → Studio 3D Importer upload → exported `assets/models/AsuraAssets.rbxm`, Rojo-mapped to `ServerStorage.AsuraAssets`. IDs in `assets/ASSET_IDS.md`, credits in `assets/CREDITS.md`.
- **Uploaded (Creator: Me)**: Gothic Statue (colossus), Large Iron Gate, Dead Tree Trunk 02, Pine Roots — each MeshPart has a SurfaceAppearance with Color/Normal/Roughness/Metalness.
- **`SanctuaryDressing.luau`**: 48-stud veiled colossus on the dais (faces the plaza), 6 root clusters on the plinth, upright dead sacred tree shedding crimson petals, iron gates swung open at the Ascension portal. All calls go through `Dressing.try` (pcall) so a cosmetic failure never blocks boot. Replaces the old titan auto-mount that overwrote materials (the cause of the black statue).
- **`EnemyAppearance.luau`**: Corrupt Monk (ash skin, rust kasaya, prayer beads, ember eyes) and Cursed Swordsman (iron lamellar, pauldrons, black kasa, tattered cloak, ember eyes). `CharacterService.tint` now skips `AsuraAttire`. Catalog accessories were previewed and rejected (bright, cartoony).
- **`PrologueController.luau`**: 4-line skippable letterboxed prologue for new players (motive: Grandmaster Shen, the Fallen Abbot). Controls card waits until it finishes.
- Colosseum sign BillboardGui now sized in studs (was a screen-sized overlay visible from 140 studs).
- **Still ugly / next**: enemies are R15 block bodies (real meshes need Mixamo/Sketchfab downloads under the user's own login); Sanctuary still ~1,700 primitives + 86 Neon parts; spawn falls and triggers "The clouds return you".


## 5b. VISUAL PASS 2 — DESECRATED MONASTERY MAP (2026-10-19)
- **`MonasteryService.luau`** (+ `MonasteryKit/Fx/Grounds/Ruins/Halls/Landmarks/Atmosphere/Dressing/Survey`, each ≤150 lines) builds `Workspace.Map_DesecratedMonastery` before `WorldService.Start()`, replacing the greybox: gate landing + lacquered gatehouse (iron gates open) → courtyard (cauldron, bell tower ruin, fallen bell, dead tree) → half-roofed prayer halls with defaced idols → stone bridge over a misted terrain ravine → cloister + graveyard with toppled pagoda → south road to Bamboo Pass.
- Shrines carry `AltarAnchor_<id>` parts (rest prompts mount on them). `MonasterySurvey` raycasts every altar/spawn/patrol point and leg 2 s after build; Studio reports 0 walkability issues (3,171 parts).
- Terrain gotcha: smooth terrain surfaces sit 2 studs above a FillBlock's top, so the valley fills to −2.2 under flagstones at +0.2. No Neon/SmoothPlastic; set pieces are pcall-wrapped.

## Phase 1 — Kinetic Movement Engine (2026-10-19)
- **Movement architecture**: `MovementController.luau` is a strict, <200-line client controller with Grounded / Airborne / Sliding / Gliding / BulletJumping states. `MovementMath` handles momentum/slope calculations; `MovementEffects` owns procedural visuals. Registered in the Rojo tree; physics runs in `PreSimulation` and yields to server combat dash grants.
- **Mobility**: native initial jump, one forward/upward double jump per airtime, stationary crouch, +40% momentum slide with friction and slope acceleration, 160 ms stair-contact grace, release-to-cancel slide, and camera-directed 75-stud/s bullet jump from crouch/slide. Holding Jump or Aim glides immediately after a bullet jump, clamps descent to -6, steers with the camera and consumes a cumulative 3.5-second budget per airtime. Grounding replenishes air resources.
- **Controls**: Space / gamepad A = Jump (hold to glide); Shift / Q / gamepad B = Dash; C / Ctrl / L3 = Crouch/Slide; RMB / L2 = Aim Glide. Touch has separate JUMP, DASH, SLIDE and GLIDE buttons. Heavy moved to V; Caps Lock toggles sprint. The concurrent arsenal controls retain J for Swap and Z for Interact; spell slot one moved from Q to 1 so Q remains Dash (HUD/arsenal labels updated).
- **Combat/cleanup**: Dash retains server stamina costs and i-frames; jumps and slides do not grant invulnerability. Hitstun, server rooting, menus, typing, death, focus loss and respawning suspend/reset the appropriate movement and restore posture. No deprecated physics movers are used.
- **Game feel**: spring-smoothed +10 glide FOV, +10 bullet FOV punch/rumble, 0.6-stud slide camera drop and turn lean, procedural launch ring, double-jump somersault/bullet spin, shoulder wind trails and foot dust. Default/new-profile FOV is 70 (glide 80); existing saved FOV preferences are preserved.
- **Automated verification**: `python3 tools/test_movement.py` passes 48 assertions against the real movement, input and effects modules using deterministic Roblox engine fakes. Covers slopes/stair gaps, immediate bullet-to-glide, glide budget/release, every dash binding, touch separation, root/combat cancellation and respawn cleanup. All 88 current source files compile. Existing Stage 1/2/3 combat and objective suites passed before the concurrent combat expansion.
- **Type verification**: new movement modules and changed input/camera/controls scripts pass Roblox-aware Luau type analysis. CLI analysis used a temporary mirror with equivalent relative requires and corrected the downloaded definition of `GetFocusedTextBox` to its nullable runtime return. Pre-existing diagnostics in older dependencies remain; this is not a claim that the entire repository is type-clean.
- **Studio verification still pending**: attempted the full local playtest, but concurrent `WeaponSchema` changes require `WeaponExpansion` before it has replicated into the loaded place, blocking server/client boot. A separate temporary movement-only physics scene was prepared; the computer-use connection failed before it could run. Re-sync the complete combat tree, then check real stair/slope contact, bullet-to-glide transitions and visual feel in Studio.

## 5c. VISUAL PASS 3 — THE VEILED ASCETIC COLOSSUS (2026-10-19, in progress)
- **Target**: a seated, meditating female titan, Elden Ring boss quality: hood-mantle drawn over her eyes, angular blade crown, dark weathered granite, pale roots coiling her body, a dead pale tree arching over her with crimson leaves falling.
- **Procedural attempt rejected by the creator** ("drab, unrefined"): `build_titan.py` + `titan_dressing.py` + `bake_titan.py` (metaball body, cloth-sim robes) cannot reach sculpted quality. Kept only as tooling; its GLB is not to be uploaded.
- **Chosen route: AI image-to-3D sculpt** (Meshy / Tripo / Rodin, creator's own account). Brief and prompts: `assets/VEILED_TITAN_PROMPTS.md`. Creator generates `statue.glb` (+ optional `tree.glb`) into `assets/source/veiled_titan_ai/`.
- **Ingest**: `tools/blender/ingest_sculpt.py` normalises the sculpt (1 m tall, faces -Y), splits it into height slices (default 2 MeshParts ≤19k tris, seams protected), bakes the high-poly detail into 1024 Color/Normal/Roughness, grades colour toward dark granite (`--grade`), places the tree as `Titan_Canopy` with crimson leaf cards (`Titan_Leaves`), writes `veiled_titan.glb` + leaf PNGs + a golden-hour `preview.png`. Tested on stand-in models.
- **No CC0 seated veiled female scan** was downloadable without a login; Smithsonian's best match (Greenough's Washington) is male. No CC0 gothic sentinels/arches found either.
- **Luau (done, parses + Rojo builds)**: new `SanctuaryLeaves.luau` (tumbling crimson-leaf emitter: RotSpeed ±160, Squash flips, drag + wind draft, fades; `Scatter` of fallen leaves — decals once uploaded, flat crimson slivers until then), registered in `default.project.json`. `SanctuaryDressing` mounts `AsuraVeiledTitan` when present (62 studs incl. canopy, rests on the dais, leaves emitted from `Titan_Canopy`, collisions off for canopy/leaves) and skips old Roots/SacredTree; otherwise falls back to the Gothic statue. `SanctuaryService` plaza petals use the leaf emitter; fallen leaves on both basins, four stair treads, dais tiers 2–3.
- **Next**: creator generates the sculpt → run ingest → review preview → Studio 3D Importer upload as `AsuraVeiledTitan` + the two leaf decals → paste ids into `SanctuaryLeaves.LEAF_TEXTURE` / `SCATTER_TEXTURE` and `assets/ASSET_IDS.md`. Not yet verified in Studio.

## 5d. MENU UI POLISH PASS (2026-10-19)
- **Shared kit**: `UiKit.luau` (theme tokens, motion timings, SFX hook table `UiKit.Sfx` = Hover/Click/Error/Open/Close, themed Primary/Secondary/Danger/Ghost buttons with 1.05x hover lift, 0.95x press, stroke glow, gamepad selection = hover, disabled state that plays Error) and `UiWindow.luau` (modal shell: backdrop, CanvasGroup lacquer panel, shadow, title/subtitle/gold rule, close; Scale sizing clamped by UISizeConstraint + UIAspectRatioConstraint; spring open / fade close with a re-open-safe serial).
- **Arsenal rebuilt** (`ArsenalPanel.luau` shell + `ArsenalTabs.luau` cards): tabs Qi Sorcery / Weapons / Transmutation, discipline-coloured accent bars, slot and wield state shown on buttons, forging needs a second "Confirm?" press within 3 s. Same ArsenalIntent packets; `SpellController` now opens and closes it through `Panel.open/close/isOpen`.
- **New Respite menu** (`PauseMenu.luau`): P key or the round "II" seal right of the Controls pill (hidden during boss fights, altar, death, prologue, arsenal). Resume / Settings / Controls. Settings has FOV and camera-sensitivity steppers (Config.Camera limits/steps) that preview live, are saved through ShopIntent `SaveSettings` (keeps `leftHanded`), and revert if you leave without Apply. Gamepad B / Backspace goes back while open. The world never pauses.
- **Altar menu**: buttons use the UiKit juice; the panel springs in from the left with open/close cues.
- **Verification**: all changed files compile; `rojo build` succeeds; luau-lsp strict analysis (require mirror) reports no errors in the new/changed UI files (older dependency diagnostics unchanged); movement suite 48/48. **Not yet seen in Studio**: check that the panel looks right, the hover/press feel is good, and the layout holds on phone, tablet and ultrawide.
- **Next**: swap `UiKit.Sfx` ids for uploaded UI sounds; optionally move the Death screen and Colosseum menus onto `UiWindow`/`UiKit`.

## 6. CURRENT MILESTONE & NEXT TASKS
- **Next Task (Stage 6)**: Build the opening **Sanctuary Lobby** ("The Shrine of the Ascendant") based on the reference concept art:
  * Golden Hour sky sanctuary above sea of clouds (`TimeOfDay = "17:35:00"`, `Atmosphere`, `SunRays`).
  * Circular reflective terrace with shallow water ring and Primal Bonfire Altar.
  * Ascension Portal staircase leading to the Story Mode.
  * Blacksmith forge loggia (West) and 1v1 Colosseum balcony (East).
  * Implemented via `src/server/Services/SanctuaryService.luau` and updated `default.project.json`.

---

## 7. AGENT PROTOCOL (HOW CLAUDE MUST OPERATE)
1. At the start of a chat, read this file (`PROJECT_STATE.md`) to establish context.
2. Only write/edit code in `src/`, `tools/`, and `default.project.json`. Do NOT touch binary files (`.rbxlx`, `.zip`, `work/bin/`).
3. Maintain strict Luau typing (`--!strict`).
4. At the end of every task/chat, update this file (`PROJECT_STATE.md`) with the new status, changes made, and next steps.

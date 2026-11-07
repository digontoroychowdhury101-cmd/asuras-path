# AR01: The Ashen Covenant (Grandmaster Shen arena)

**Environment pass done; visual acceptance and the combined Shen encounter are not.**

The Shen arena now uses AR00's chosen footprint: **240×190 centred at (0, −1990)**, up from 120×130 (×2.92 area). It is dressed with a new 12-piece authored kit that is baked with PBR and uploaded. The kit covers B07 seat fronts, arcades, facade, gates and cenotaph; B09 ash banks; and B10 weapons, reeds and votives. Decoration is non-colliding. The layout boxes it dresses stay as the colliders. No attack radius, boss stat or timing was changed.

- **Branch:** `codex/windows-arenas`.
- **Base:** `84c4a7f` (shared relay head when the branch was cut). It holds the committed Shen version used for every boss measurement here.
- **Mac's work:** uncommitted Shen work was not present and was not used.

## What changed in the game

| Area | Change |
|---|---|
| Footprint | `WorldDefinitions`: the Ash region bounds and Shen arena (240×190 at z −1990) are enlarged; spawn is at (0, 3, −1955). The fog gate is unchanged. `AshColosseumLayout`: five seating tiers start 16 studs beyond the floor edge. The Hall facade, gate passage, podium, Victor jamb and south retaining wall are re-fitted to the new bowl. |
| Floor | `BossArenas`: the Ash arena floor is Ground with the existing `AsuraGravel` variant, ash-pale (160, 158, 155). |
| Dressing | `ColosseumDressing` was rewritten for the new bowl. It places:<br>• seat fronts around the cavea, 11 bays per side;<br>• broken and whole crown arcades;<br>• 8 facade bays per side;<br>• a low, dark ChampionGate entry arcade, and the VictorGate on the south axis;<br>• ash banks, reeds, buried weapon fragments and votive rows;<br>• six small ember braziers;<br>• a far `CovenantHorizon` group: the split cenotaph, a five-bay ruined bridge and six cloud masses. |
| Grade | `EnvironmentProfiles` (Ash exploration and combat): the old mauve/orange cast is replaced with a cold grey grade. The clock, the fill floor and the night skybox are unchanged. |
| Light | `ArenaLighting`: Ash brazier lights are dimmed to 0.4× (ember accents instead of orange pools). `ArenaLightPlan`: fill spacing is 80 → 66, so the larger Shen floor gets a 4×3 fill grid and passes the existing 0.85 coverage rule. Arenas of 180 studs keep 3×3. |
| Pending hero slot | `H01_PendingHeroSlot`, an invisible marker carrying the `AsuraPendingAsset` attribute, is placed at (−24, 5.5, −2094). H01 (Shattered Votive Idol) was not supplied (see C00). |

The full file list is in [CHANGED_FILES.md](CHANGED_FILES.md). Asset IDs and sources are in [ASSET_MANIFEST.md](ASSET_MANIFEST.md).

## Evidence, by kind

### Static review (files only)
- Kit geometry, triangle counts (1,232–7,448 per piece; all under the 18–20k sub-mesh cap) and bake maps: `kit/bake_manifest.json`.
- Blender preview renders of every piece: `kit/covenant_kit_front.jpg` and `kit/covenant_kit_side.jpg`.
- Collision: every kit clone is placed through `Decor.han` (CanCollide, CanQuery and CanTouch false). `Decor.dressBoxes` only hides the dressed layout boxes; they keep their collision.

### Local regression (engine emulation; says nothing about appearance or feel)
- `test_campaign_regions`: **442 passed, 0 failed**. The new AR01 block covers:
  - area ≥ 2.5× baseline, and the gate on the north face;
  - inside and outside points, the trigger and the spawn gap (30–60);
  - clearance from foes, the hall and court zones, and the region;
  - the Victor gate lying south of the floor and walkable to the south join;
  - a 16-stud side camera band free of geometry;
  - the whole floor walkable.
- `test_combat_presentation`: **165 passed**. It now includes the fill budget scaled by area.
- `verify_all` steps 1–14 (via `work/verify_rest.sh`, built to a temp path): **all passed**, including 43 suite lines.
  - `test_shen_integration.py` was **skipped**: it needs the Mac-only `assets/build/shen_audio/manifest.json`. It is recorded as pending, not as passed.

### Studio (seeded mock profile in a temporary unsaved place; not earned play)
- **Places:**
  - Built from this branch to `work/AR01_after_art.rbxlx`, opened in Studio window `c33e27fe`. The source digest matched, and all 12 kit pieces loaded from Roblox.
  - The final brazier source was patched into that window before capturing.
  - The baseline place was built from `84c4a7f`.
- **Before/after captures:** `before/` and `after/` hold 10 fixed views each, plus a `contact.jpg` sheet per set. Cameras are listed below. The player stands in the Hall with every boss marked defeated (`tools/qa/AR01CaptureSetup.luau`, `tools/arenas/ar01_captures.py`).
- **Shen probe** (`tools/qa/AR01ShenProbe.luau` → `shen_probe_seeded.json`):
  - The player was invulnerable and teleported, so this was not real input.
  - The fight starts on entering through the gate. The spawn gap is 45 studs.
  - Shen pursued to all four corners (inset 6); closest approach was 8.1–8.7 studs, which matches the clamp geometry.
  - BossMotion's 12-stud clamp held within **1.79 studs worst-case** (228 of 662 samples were more than 0.5 past it). Shen stayed at least about 10 studs inside the floor.
  - Phase 2 was reached by setting HP to 40%.
  - BloodWave was cast. One Skyfall landed at (−3, −1988), inside the clamp. Edge Skyfall was not observed in this run.
  - PrayerBeads was telegraphed 5 times at 8.6–146 studs. The 146 case followed a corner teleport.
  - Leaving mid-fight via the outside point keeps the fight sealed: the player is returned inside and Shen stays. This is existing WorldService behaviour; reset-on-exit was not observed.
- **Geometry note:** at r90, PrayerBeads and BloodWave no longer reach the whole 240×190 floor; the corners sit about 153 studs from the centre. The radii were deliberately left unchanged, as the brief requires. Whether that is acceptable is a combat/design call for the combined encounter.

### Human, multiplayer, device
**Not performed.** No human play, no two-client session and no phone, tablet or controller run. None is claimed.

## Visual state (from the after captures; not an acceptance)

**Better:**
- The floor reads ash-grey instead of tan.
- The entrance is a low, dark roofed arcade that frames the floor (`ar01_entrance`, `a11_facade_diagnostic`).
- Seat fronts and crown arcades ring the bowl.
- The Victor gate is legible on the south axis from the entrance and centre.
- The brazier pools now sit as small warm accents at the corners.

**Not there yet:**
1. **The far horizon is invisible at night.** The cenotaph, bridge and clouds load (confirmed in Studio: 12 objects in `CovenantHorizon`), but they lie 450–700 studs out. At clock 0.15, Atmosphere renders them into a black sky. Paler haze, density and glare tests (`work/atmo`) and a self-lit glow card made no visible difference. Only a twilight clock gives a pale sky (`options/far_dawn_6_4_experiment.jpg`, a live experiment and not shipped). That would change the established "night stays night" Ash look and the Shen fight's lighting. **The creator chose to keep night** (see below).
2. The seat fronts and ash banks show cool blue-white specks under the cold fill, which look busy at the floor edge. This needs a material pass after the creator sees it.
3. The cavea reads as a low ring at play height. "Immense" may need taller crown pieces once the horizon question is settled.

## Cameras (eye → look; FOV 70; HUD hidden)

| View | Eye | Look |
|---|---|---|
| a06_arena | (0, 6, −1897) | (0, 8, −1990) |
| a11_facade_diagnostic | (0, 10, −1855) | (0, 14, −1877) |
| qh_a03_champions_n | (0, 6, −1784) | (−26, 6, −1810) |
| ar01_entrance | (0, 7, −1866) | (0, 9, −1990) |
| ar01_centre | (20, 7, −1985) | (−100, 12, −2010) |
| ar01_corner | (−110, 7, −2075) | (0, 10, −1960) |
| ar01_return | (0, 7, −2078) | (0, 12, −1895) |
| ar01_far_horizon | (0, 9, −1905) | (−70, 34, −2400) |
| ar01_cavea_east | (60, 9, −1960) | (150, 20, −1990) |
| ar01_top_down | (0, 330, −1985) | (0, 0, −1986) |

The three audit views keep their 5 November eye and look. The `before/` corner, return and cavea views fall outside the old 120×130 floor, so they show rubble; this is expected.

## Dependencies and pending items
- **H01** Shattered Votive Idol: not supplied; a labelled slot is placed. Optional.
- **Mac Shen checkpoint:** animation and VFX acceptance, the audio manifest needed by `test_shen_integration.py`, and the combined encounter. See [INTEGRATION_HANDOFF.md](INTEGRATION_HANDOFF.md).
- **AR05/AR06:**
  - The cenotaph at (−210, −2560) sits beyond AR00's Shen scenic envelope (z −2300), near Wu's planned south side. Re-check it when AR05 lands.
  - Baize, Titan, Wu and Wyrm models were not supplied (C00); they do not affect AR01.
- `StreamingEnabled` was not changed. Nothing was published. No paid generation was used.

## Creator decision (2026-11-07)
**Keep night.** The Ash region stays at clock 0.15 under the ashen night sky, so the Shen fight's lighting is unchanged. The far horizon is therefore not part of the night read.

The `CovenantHorizon` group (cenotaph, bridge and clouds) stays placed. It is cheap (about 13 objects, all non-colliding) and ready if the sky ever changes. It is recorded as invisible at night rather than presented as a delivered horizon. The twilight frame in `options/` is kept for reference only.

## Next action
1. Do the material pass on the blue-white specks at the floor edge.
2. Consider taller crown pieces so the bowl reads as immense at play height.
3. Run the combined encounter steps in the handoff once Mac has a stable Shen checkpoint.

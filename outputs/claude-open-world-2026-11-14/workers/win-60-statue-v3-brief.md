# win-60 statue pass 3 brief (lead, Opus 5.5, 2026-11-19 23:25 Sydney)

Creator, after seeing pass 2 (`outputs/vesperhold/kit-renders-win/F1_statues_win.jpg`): "statues should look like this", with two
images now saved as `outputs/vesperhold/reference/ref_06_statue_mourner.webp` and `ref_07_statue_wraith.webp`. They override the
statue look in mac-40/mac-50 (architecture keeps the soot-black palette). Rules in mac-50 still bind: no decimation, every sub
< 18,000 tris, 2048+ baked PBR, black Metal on non-metal, Poly Haven CC0 only, no Meshy, paid or AI generation.

## What the references show
- **ref_07 wraith:** faceless hood (a black void), huge layered drapery hanging in tattered strips: ragged dripping hems, holes,
  frayed edges and several overlapping layers (hood, mantle, robe). Both hands crossed on the pommel of a downward sword. It
  stands on a weathered block wrapped in ivy and moss.
- **ref_06 mourner:** a veiled woman with her face turned up, tear or water streaks from the eyes, wavy hair under the veil,
  a rose brooch at the shoulder, a heavy draped shawl. One arm cradles a bundle of withered roses; the other hand rests on a
  gothic tomb with tracery panels. Ivy grows over the tomb.
- **Stone (both):** pale-to-mid grey (albedo about 0.25-0.45) with near-black grime packed into every crevice, crusty pale
  lichen, moss in the folds, pitting, drip streaks. The contrast between pale ridges and black cavities is what makes the
  folds read. This replaces the 0.08-0.2 soot target for statues only.

## Pieces
1. `Statue_Wraith`: rebuild of Pedestal_Statue_Staff (same pose: hands on the sword pommel) in the ref_07 style, on a
   weathered ivy block. Keep the quatrefoil pedestal as an option.
2. `Statue_Mourner` (new): the ref_06 figure with its tomb, for the graveyard slots. Face: try a Poly Haven CC0 scan (for
   example a marble bust) placed into the veil and tilted upward. Record it in `outputs/vesperhold/THIRD_PARTY.md`. If none fits,
   sculpt the face and keep it mostly in veil shadow.
3. `Hooded_Statue_A` / `Hooded_Statue_B`: same ragged layered drapery and stone treatment. B keeps the staff and crescent.
   A keeps hands joined (no trumpet cuffs).
4. `Statue_Veiled_Scan`: retone to the new stone; smaller or rectangular plinth.
Heights stay about 22-23 studs (the mourner can be about 18 plus the tomb).

## Suggested method (free tools only)
- Drape the garments with Blender cloth simulation, run headless. Use 2-4 layered sheets per figure over a collision body,
  pinned at the crown and shoulders.
- Tear the hems and cut holes with noise and Voronoi masks, then give the cloth thickness.
- Build the shipped mesh at its own target density. The bake source is that mesh subdivided and displaced (weave, crust,
  pitting). Never decimate.
- Ivy and roses are separate role subs (`__Ivy`, `__Roses`) built from real leaf geometry, each under the cap.
- Bake cavity grime, lichen, moss and streaks into Color and Roughness; drapery and crust detail into the Normal map.
- Judge every render against ref_06 and ref_07 at the same scale, plus the far foggy view.

Output: `assets/source/vesperhold/candidate-win-2026-11-19/props`. Sheet: `outputs/vesperhold/kit-renders-win/F1_statues_v3_win.jpg`.

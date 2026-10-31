# General Zhao v2 — design review (not finished, not uploaded)

v1 (`../GeneralZhao_Master.blend`, `../v1_greybox/`, `../export/`, `../previews/`) is untouched. v2 is rebuilt from
scratch in Blender by script; no TRELLIS/Rodin geometry is used.

## Files
- Source: `GeneralZhao_v2.blend` (collections `ZhaoV2_Master`, `ZhaoV2_Game`, each with a Guandao child)
- Build scripts: `tools/blender/zhao_v2/` — `build.py` (geometry), `bake.py` (bake, export, manifest), `review.py` (renders)
- Game export: `export/GeneralZhao_v2_Game.glb` / `.fbx`; guandao alone: `export/Zhao_Guandao_v2.glb`
- Textures: `textures/game/ZhaoBodyV2_{Color,Rough,Metal,Normal}_1024.png`, `ZhaoWeaponV2_*_512.png`; 2048/1024 masters in `textures/master/`
- Measured values: `manifest.json`; renders: `review/`

## Measured (bake.py, scale 1)
| | value | target |
|---|---|---|
| Game triangles | 22,090 | ~22,000 |
| Largest game piece | 4,536 (UpperTorso) | < 10,000 |
| R15 limbs covered | 15 / 15 | 15 |
| Guandao tip, farthest vertex from RightHand centre | 9.242 | 9.2 ± 0.5 |
| Guandao tip, BossTemplateCheck 8-corner method | 9.246 | 9.2 ± 0.5 |
| Body / weapon textures | 1024² / 512² | 1024² / 512² |
| Master triangles (cage, before Subdivision ×1) | 224,462 | — |
| Height: sole / helm top / plume top (Roblox Y) | −3.0 / 2.36 / 4.56 | — |

Game per piece: Head 4,476 · Plumes 1,232 · UpperTorso 4,536 · Pennants 832 · LowerTorso 1,648 · R/L UpperArm 620/912 ·
LowerArms 608 each · Hands 648 each · R/L UpperLeg 924/956 · LowerLegs 722 each · Feet 360 each · Haft 840 · Blade 438.

## Improvements over v1
1. Silhouette built for distance: tall twin pheasant plumes and two back pennants give three verticals above the
   helm; narrow cinched waist under a broad lamellar chest; no horns, shield or bulk, so he never reads as the Iron Bull.
2. Real armour construction: individual laced lamellae in overlapping rows, riveted yoke, domed pauldron shells over
   flaring lames, splinted greaves, knee cops, vambraces, tassets on an iron rail.
3. A face: sculpted brow ridge, deep-set eyes with irises and lids, hollow cheeks, down-turned mouth, scar through the
   left brow, salt-and-pepper brows, drooping moustache and goatee built from individual strands.
4. Hands that hold the weapon: jointed fingers wrapped around the haft, armoured backs, knuckle guards.
5. Guandao is its own asset with a crescent blade, spine spur, dragon-mouth collar, tassel, cord grips and butt spike;
   the tip is measured, not assumed.
6. The failed oath is carried on the body: cracked oath tablet at the hip, oath cord on the left arm, torn pennants,
   frayed coat hems, worn lacquer showing iron at edges.
7. Colour discipline: dark lacquer red and weathered iron, azure only in small accents; lightning exists only as
   attack VFX in the renders, not baked into the model.
8. Limbs and cloth separated for motion: rear coat panels split and clear of the legs; thigh panels ride on the
   upper legs; every piece pivots at its R15 limb centre.

## Remaining defects (honest)
- Face is still stylised and slightly mannequin-smooth at close range (no skin micro-detail sculpt; skin shading is procedural).
- Game face at close range: the shared 1024² atlas gives the face few texels, so the bake smears on the cheek and
  shows a UV seam beside the nose; strand hair collapses to solid shapes. Fine at combat distance, poor in a close cutscene.
- Rest pose is stiff; hands and fingers are rigid meshes, so the left hand cannot re-grip the haft in animation.
- Pauldrons belong to the UpperArm pieces, so a high raise is likely to open a gap at the shoulder yoke; not yet
  inspected up close in the overhead pose.
- Thigh panels ride the upper legs and may clip the coat on very high knee lifts; not visible in the three test poses.
- The inside of the standing collar shows a pale, unlit band around the neck wrap.
- Blade steel is clean but plain after removing the blotchy etch; the forged grain is too faint.
- At 40 studs in the rainy arena the dark lacquer sinks into the night; only the plumes (and lightning, when
  attacking) carry. The arena likely needs a cold rim light on him.
- Arm geometry sits slightly inward of the R15 arm centres to keep the waist-to-shoulder taper; check against
  the costume welds in Studio.
- Game mesh is close to the 22k budget; the head (4.5k) takes most of it because of the helm and guards.
- Pennant flags are thin single-sided-looking planes at close range.
- Lightning is render-only VFX; no in-game effect was built.
- Untested in Studio: not imported, not uploaded, no BossTemplateCheck run in-engine, no animation.
- v1 had no separate concept/Rodin mesh in the repo to borrow from; v2 reference was the brief and v1 only.

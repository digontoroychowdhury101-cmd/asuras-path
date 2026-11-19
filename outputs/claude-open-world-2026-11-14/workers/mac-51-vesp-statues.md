# mac-51: Vesperhold hooded statues v2 (hand-modelled, baked)

Worker: mac-51 (observed model: Opus 5.5, claude-opus-5-5). Branch ux/onboarding-overhaul. Not committed: the rules say the lead commits.

## What was built
- Hooded_Statue_A: a 14-stud monk on a 5x2x5 plinth. Head bowed, sleeves joined with the hands hidden, rope belt with a knot and two tasselled cords, pooled hem, void face, capelet.
- Hooded_Statue_B: a staff-bearer turned -12 deg. Right hand grips the staff, which is taller than the figure (top at 16.6 + plinth). The staff head is an iron ring with a spike and a verdigris crescent. Left arm hangs in a long sleeve.
- Pedestal_Statue_Staff: a 16-stud cloaked figure with both hands on the pommel of a downward sword. It stands on a 6x6x7 stepped gothic pedestal (lancet panels, quatrefoils, corner colonnettes, moulded cornice). 23.3 studs in total.

Method: parametric numpy surfaces evaluated twice in Blender 5.2 headless:
- high: 2.1-3.3M tris; crisp folds, shell thickness, rolled lips; voxel-remeshed and chipped plinth.
- low: the shipped mesh.

The low mesh gets weighted normals and a Smart UV unwrap (pack, no overlap). Then each part is baked selected-to-active at 2048: AO prepass plus Color, tangent Normal, Roughness and Metal. Parts over the tri limit are split spatially with `split_cap`. There is no decimation anywhere.

Base layer: the code tries `vesp_polyhaven.maps("Vesp_Weathered")` first. That module is absent, so it fell back to the gen_weathered `Vesp_Weathered_*` maps; the hook stays in place. Frost is baked into the maps as dust on up-facing surfaces, so there is no separate `__Frost` sub.

## Files
- tools/blender/vesperhold/vesp_bake.py: new shared bake module (usage is in the docstring; mac-52 imports it).
- tools/blender/vesperhold/vesperhold_figures.py: new. It builds, bakes, exports, renders and merges the manifest. Run it with:
  `Blender -b --python-exit-code 1 -P tools/blender/vesperhold/vesperhold_figures.py`
  - env `VESP_ONLY=A,B,P`
  - env `VESP_FIG_MODE=bake|clay`
- tools/blender/vesperhold/vesperhold_props.py: only two changes. I added `import vesperhold_figures` and removed the three statue tuples from PLAN. The import keeps their manifest entries when props runs. The old hs_a/hs_b/pedestal_statue functions are untouched and now unused.
- Outputs in assets/source/vesperhold/props/:
  - `{Hooded_Statue_A,Hooded_Statue_B,Pedestal_Statue_Staff}.glb`
  - `maps/Vesp_<Piece>__<Role>_{Color,Normal,Roughness,Metal}.png`
  - manifest.json entries (each has `no_decimation: true`, `map_resolution: 2048`, `high_poly_tris`, `base_layer`)

## Tris (low, shipped; every sub < 18000; no decimation used; maps 2048 for every role)
| Piece | Sub-meshes (tris) | Total | High-poly bake source |
|---|---|---|---|
| Hooded_Statue_A | Robe 17164, Robe_2 17164, Hood 9312, Hood_2 9312, Arms 10584, Plinth 216 | 63,752 | 2,115,148 |
| Hooded_Statue_B | Robe 17164, Robe_2 17164, Hood 9312, Hood_2 9312, Arms 16304, Plinth 216, Staff 4424 | 73,876 | 2,324,284 |
| Pedestal_Statue_Staff | Robe 15472, Robe_2 15472, Hood 11856, Hood_2 11856, Hood_3 11858, Arms 11012, Arms_2 11012, Plinth 13848, Sword 2642 | 104,028 | 3,299,388 |

The Plinth on A and B is 216 tris: a simple bevelled box whose chips are baked into the normal map.

Embedded GLBs (vesp_embed, VESP_NORMAL=jpeg): A 6.83 MB, B 7.46 MB, P 10.38 MB, all under 50 MB. The pack checks pass for all three: sub tris match the manifest, every sub is < 18000, size matches, and min_y is 0.

## Renders
- Per view: assets/source/vesperhold/props/renders/<Piece>_baked_{q34,side,close}.png. The lighting is dim overcast plus a warm rim, with a 5-stud grey mannequin.
- Sheets:
  - outputs/vesperhold/kit-renders-v2/F1_statues_v2.jpg (all three)
  - F1_statues_v2_A.jpg, F1_statues_v2_B.jpg, F1_statues_v2_P.jpg

Look iterations:
- Clay passes, three times: boxy capelet changed to a domed one; hood opening turned forward; pumpkin hood ribs and the pleated-skirt robe toned down; trumpet cuffs fixed.
- Baked passes, three times: cage stealing between parts; lichen camouflage; salt-speckle frost; pale staff and sword; quilted torso; a stair-step in the A muff and a fin from the tucked sleeve.

## Blender runs (heavy lock taken each time; memory_pressure free %, before -> after)
| Run | Before -> after |
|---|---|
| bake smoke test | 40 -> 45 |
| clay A | 58 -> 53 |
| clay all | 56 -> 51 |
| clay iter 3 | 66 -> 59 |
| trial bake A at 1024 | 61 -> 60 |
| full 2048 run 1 | 36 -> 63 |
| full 2048 run 2 | 70 -> 69 |
| A rerun | 69 -> 66 |
| props-hook verify | 68 -> 71 |
| pack check (PIL only) | 72 -> 72 |

Bake speed: about 25-33 s per role at 2048; the AO prepass takes 18-38 s.

## Weak points left
- The sleeves still read a little tubular and inflated, most on A's muff.
- The capelet hem is a hard ledge.
- The hands are simplified: P's fingers read as stacked rings close up.
- The hood folds are subtle, and the staff shaft is plain.
- The base layer is procedural (gen_weathered), not Poly Haven.
- There is no separate `__Frost` sub; frost is baked into the maps.

## For the lead
1. **Pre-existing:** `make_upload_pack.py props` (VESP_NORMAL=jpeg) crashes in `vesp_embed._encode` with "OSError: broken data stream / Suspension not allowed here". This is Pillow on Python 3.14 failing on `optimize=True` JPEG saves. It fails on other props' materials only: Vesp_Weathered, Wax, Water, Verdigris, Soot, Iron and others, used by Masonry_Chunk_A/B, Ruined_Arch, Waterfall_Sheet_A/B and more. All 14 statue materials encode fine. So the vesperhold upload_manifest is stale and still lists the old statues at 53/81 MB. A likely one-line fix in vesp_embed (shared file, not my lane, so I left it): `ImageFile.MAXBLOCK = 1 << 26`, or drop `optimize=True`.
2. **Pre-existing:** a props run with `VESP_ONLY` rewrites manifest.json and drops every piece it did not build. My three are now protected by the import hook; the others are not.
3. While probing, I imported make_upload_pack. It has no `__main__` guard, so it ran once in full. The slice and hero packs were rewritten the same way a normal run would; the vesperhold pack crashed as in point 1.
4. The commit rule conflicts. CLAUDE.md and user memory say commit every turn; the mac-50 rules say workers never commit. I followed the lane rules and did not commit.

# Veiled Ascetic: AI 3D generation brief

Generate **two** models: the statue (with the roots carved in) and the tree. Download each as
**GLB with PBR textures** into `assets/source/veiled_titan_ai/` as `statue.glb` and `tree.glb`.
Then run the ingest command at the bottom. Leaves, particles and Roblox limits are handled for you.

## Best route: image → 3D

If you have the concept art, crop it to just the titan (one figure, centred) and use **Image to 3D**.
It is far more faithful than text. Otherwise generate a concept image first (Meshy/Tripo both
have text-to-image) using the statue prompt, pick the best one, then use Image to 3D on it.

## Settings

| Service | Mode | Settings |
|---|---|---|
| Meshy | Image to 3D / Text to 3D (Meshy-5 or newest) | Art style **Realistic**, **PBR on**, symmetry **off**, polycount **max**, no remesh (keep high-poly) |
| Tripo | Image to 3D (newest model) | **HD texture / PBR**, Quad off, face limit **max** |
| Rodin (Hyper3D) | Gen-2 Image/Text | Quality **High**, Material **PBR**, mesh **Raw** (keep detail) |

Ask for the highest polycount. The ingest step compresses the detail into normal maps, and more
source detail there means a better result in Roblox.

## Prompt 1: statue (`statue.glb`)

> Colossal ancient stone statue of a seated goddess in meditation, cross-legged, hands resting
> together in her lap, slender female figure, serene and sorrowful. A heavy hooded mantle drawn low
> over her eyes so only her lips and chin are visible. A tall angular crown of thin spiked blades
> rising from the hood. Flowing robes with deep sculpted folds pooling over her knees and onto a
> round stone plinth. Thick gnarled pale white tree roots coiling tightly around her waist,
> shoulders and arms, gripping the stone. Weathered dark grey granite, cracks, chipped edges, moss
> in the crevices. Dark fantasy, Elden Ring style, ornate gothic carving, highly detailed sculpt,
> single object, full body, front view.

**Negative:** cartoon, toy, plastic, low poly, smooth, blurry, multiple figures, wings, modern
clothing, open eyes, bright colours.

## Prompt 2: tree (`tree.glb`)

> Dead sacred tree with pale white alabaster bark, thick gnarled twisting trunk leaning forward,
> wide umbrella crown of bare twisted branches spreading outward, roots flaring at the base,
> realistic, highly detailed bark, no leaves, single object.

The crimson leaves are added by the ingest script on the branch tips, plus the falling-leaf
particles in game.

## Ingest

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/ingest_sculpt.py -- assets/source/veiled_titan_ai/statue.glb assets/build/veiled_titan --tree assets/source/veiled_titan_ai/tree.glb
```

If she faces the wrong way in the preview, add `--yaw 90` (or 180 / -90) and run it again.
Output: `assets/build/veiled_titan/veiled_titan.glb` + `preview.png`, ready for the Studio 3D Importer
as `AsuraVeiledTitan` (see `ASSET_IDS.md`).

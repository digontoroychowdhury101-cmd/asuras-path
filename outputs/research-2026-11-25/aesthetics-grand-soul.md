# Aesthetics research: "Hero of the Grand Soul" and comparable games

Date: 2026-11-25. Purpose: reproducible look techniques for Asura's Path (Roblox). Techniques and principles only; no assets are to be copied.

## 0. Evidence quality (read first)

- Little first-party art commentary exists for the main subject. Almost everything about its look below comes from its own store thumbnails (seven images pulled from the Roblox thumbnails API and measured by me) plus the official description. Hex values are sampled from those images (median-cut clusters), so they include the title overlay, blur and thumbnail compression. Treat them as ranges, not specs.
- Where a technique is my own inference or general craft knowledge rather than a cited statement, it is marked [inference].
- Two web pages titled "Hero of the Grand Soul Roblox" (publisher-collective and pabau domains) are SEO filler about "roleplay and resilience". They are unrelated to the game. Ignore them.
- Black Myth: Wukong, Where Winds Meet and Sekiro had no fetchable art breakdowns (Epic and Unreal pages returned 403; 80.lv has no art content). Those sections rely on short sourced facts plus [inference].

## 1. Which game it is

Chosen: **Hero of The Grand Soul** (Roblox, group Denvov Creations).
- Roblox API: universe 1783358098, root place 5131623903, created 2020-06-03, last updated 2026-11-21, ~760k visits, ~37k favourites, max 15 players, genre RPG / Action RPG. Page: https://www.roblox.com/games/5131623903/Hero-of-The-Grand-Soul
- Official description: "A PvE Soulslike RPG inspired by Elden Ring", 50+ hours, chapter 7 part 1. (Source: https://games.roblox.com/v1/games?universeIds=1783358098)
- Found via the Roblox omni-search API (https://apis.roblox.com/search-api/omni-search?searchQuery=Hero%20of%20the%20Grand%20Soul) after web search failed. Exact-name match, so no guess was needed.

Rejected near-matches: Grand Soul Saga / Grand Soul Story (pixel-art JRPG, itch/Steam), Hero Soul: I Want to be a Hero (2D pixel ARPG), Soul Cultivation and other Roblox cultivation games (genuinely xianxia but unrelated to the name).

Important framing for the creator: this game is Elden Ring / dark-fantasy, not wuxia. What it proves for us is that a Roblox PvE soulslike with a restrained, atmospheric grade, heavy fog and a strong focal landmark reads as "premium". The wuxia layer (see section 3) has to come from other references.

## 2. Hero of the Grand Soul: extracted look

Measured from the seven store images (ids 100760713264220, 94317796551624, 100307661007359, 110657862523249, 106136075324759, 73605557811988, 14391875539).

Colour and grading
- Each biome has one dominant hue and a different grade, rather than one global look:
  - Wasteland / dusk-gold: clusters #a47d4f, #b99262, #5a3f24, highlights #fadaa8. Median luminance ~143/255, shadows lifted (p5 ~42): hazy, low-contrast, amber fog over dry grass and a distant crenellated wall.
  - Misty crag forest: highlights #f7eed9 / #fff9de, shadows #33251c, #504138. Very bright overexposed sun-bloom with pale peach fog; sandstone spires and dark conifers fading into cream.
  - Moonlit snow forest: #0a1226, #233558, #364a6c, highlights #9ab4c9. Cold blue-navy, a hard backlit moon glow with god-ray streaks, floating snow motes, pale frost grass.
  - Night plain: #152f74 / #1b357b, near-black foreground silhouettes (p5 luminance 0). Saturated cobalt sky with star dots; the ground is pure silhouette.
  - Boss/menu cards: near-black (#170d08, #31180d) with one orange glow (#ae6b16 / #ffb020 like) on the emblem.
- Rule: one hue family per area, lightness carries the structure, one small contrasting accent (cyan beacon on a tower, orange glow, red eye) as the focal point.

Lighting and atmosphere
- Strong backlighting toward the camera in nearly every shot: sun or moon low in frame, bloom and shafts. [inference: Roblox SunRays, Bloom and Atmosphere Glare produce this.]
- Dense atmospheric haze with clear depth layering: crag silhouettes in the distance get progressively lighter and lower-contrast (aerial perspective).
- Floating particles in every biome (embers/dust, snow, spores) to make air visible.
- Ground-level warmth against sky coolness is not used; instead the whole frame is tinted, which is the cheap Roblox way (ColorCorrection tint plus Atmosphere colour).

Materials and silhouette
- Thumbnails show stylised-realistic terrain: tall layered grass cards in a single ochre tone, cracked slab stone floor with dark crevices, bare-branch trees against fog. Texture is detailed up close and flattened to silhouette at distance by the fog.
- Landmarks are tall, narrow, asymmetric: rock needle stacks, a castle with crenellations, a keep with a vertical cyan light shaft. The tall vertical accent, repeated at several depths, creates scale.

UI and typography
- Logo: chiselled, cracked-stone serif "HERO" with a beveled silver-blue fill (cold zones) or yellow-red fill with a dark outline (fire/boss zone), small spaced serif caps "OF THE GRAND SOUL" below. Boss card uses a thin copper frame rectangle inset from the screen edge with line-art creature face in glowing orange. A red-outlined cut-out character on a dark background is used for the combat key art.
- Takeaway: two-tier type (huge display + small caps serif), per-zone colour, thin inset frames.

Combat, camera and audio
- Not documented in any source I could reach. Elden Ring inspiration implies third-person over-the-shoulder, lock-on, stamina, roll/dodge, red telegraph on bosses. [inference] Do not treat as measured.

What makes it look good (summary): restricted palette per zone; aggressive haze plus backlight; one vertical focal accent; low ambient light with bright emissive pops; strong typography. It looks good despite being Roblox because fog hides everything that Roblox can't do (distant detail, fine shadow).

## 3. Comparable games

### 3.1 Elden Ring (FromSoftware) - the reference the subject is copying
Sourced:
- Atmosphere (skybox and volumetric fog) was built with dedicated artist tools giving a painterly sky; CEDEC 2022 talk by Hidenori Sato and Erika Ninomiya (coverage: https://www.gamer.ne.jp/news/202208240067/, 403 to my fetcher; only the search snippet was read).
- CEDEC 2025 environment talk (https://cgworld.jp/article/202508-cedec-eldenring.html), fetched and read:
  - Reduce repeated shapes; if repeated, vary orientation/scale and align with the direction toward the destination.
  - Add straight lines (e.g., linear light placed deep in the scene) against curve-only layouts; the line marks the destination.
  - S-shaped paths; asymmetric placement.
  - Light the destination brighter than its surroundings.
  - Keep hue changes small; build contrast by value (brightness).
  - Landmark lit differently from the scene (a distant cloud bank lit differently).
  - Suppress emissive effects on boss-area props so they do not hurt combat visibility.
  - Where the near field must be simple, fill distant layers with content; a giant veil as a landmark; hand-placed glowing blue flowers as a contrast accent against muted dusk/purple.
  - Spend quality on "viewpoints", the camera positions where transitions happen.
- Boss fog gates were made golden (lore-tied): https://gamerant.com/fromsoftware-games-fog-walls-dark-souls-elden-ring-bloodborne/
- The Erdtree is a bright gold beacon over a bleak land: https://kqed.org (KQED, "Elden Ring: how I learned to stop worrying...", search hit only).
- Why it holds up against higher-fidelity games (Akiman): https://automaton-media.com/en/news/this-is-what-it-means-to-be-good-at-art-capcom-veteran-akiman-on-why-elden-rings-environments-stand-out-even-among-higher-fidelity-aaas/ (imagination stimulated by incomplete detail; not fetched).
Not sourced (typical, [inference]): dusk-gold key light ~#e8c27a, shadow fill cool desaturated blue-grey ~#4a5566, fog ~#b9a98f daytime; muted green terrain; low-poly distant geometry hidden by fog.

### 3.2 Black Myth: Wukong (Game Science, UE5)
Sourced: moved from UE4 to UE5 for Nanite and Lumen; used Virtual Heightfield Mesh for dynamic snow (https://www.unrealengine.com/developer-interviews/black-myth-wukong-wows-with-ue5-early-access-visuals, snippet via search, page 403); lighting praised, art direction drawn from Chinese mythology (https://gamingtrend.com/feature/reviews/black-myth-wukong-review-monkeys-eating-good).
[inference] Look: photoscanned real Chinese temples and rock (the 21jingji piece, https://m.21jingji.com/article/20240908/herald/ef6d0bc54aa528204297d7bd0ec91d88.html, discusses real-world scene capture; details not read), warm timber and gold-leaf accents against cold stone, heavy mist, staff-trail VFX with spirit-colour accents per boss, moderate screen shake with short hit-stop. The Roblox translation is warm-wood/cool-stone value split and mist, not photoscans.

### 3.3 Where Winds Meet (NetEase, wuxia open world)
Sourced: in-house engine, ~12 x 12 km target map, Five Dynasties setting, martial arts consultant Stephen Tung Wai, mocap-driven combat (https://80.lv/articles/how-netease-built-an-authentic-wuxia-open-world-in-where-winds-meet); art draws on old paintings and murals, UI uses ink-wash motifs and traditional patterns (https://www.techradar.com/gaming/where-winds-meet-interview, https://wccftech.com/where-winds-meet-final-test-qa-everstone-unveils-its-living-world-wuxia-action-rpg-offering-single-player-and-mmo-like-features/amp/).
Takeaways: landscape-painting composition (layered ridges, mist bands between them), ink-wash UI language, movement (lightness skills) that makes verticality part of the combat spectacle. Palette specifics unsourced.

### 3.4 Sekiro: Shadows Die Twice (FromSoftware)
Sourced: Miyazaki said the team focused on more vivid colour; critics liken it to antique Japanese silk-scroll painting and note the serene Sengoku beauty set against spreading sickness (https://www.redbull.com/us-en/sekiro-shadows-die-twice-interview; https://www.thegamer.com/sekiro-shadows-die-twice-worst-best-things/).
[inference] Recipe: saturated autumn red/orange foliage and a pale fog against desaturated timber and stone; red blood/spark accents; posture-break spark and deflect flashes as the key combat VFX; flat, graphic skies.

### 3.5 Roblox peers
- Deepwoken / Lumen world: praised for "moody and atmospheric" dark fantasy, not flashy, blocky Roblox style (https://www.pocketgamer.com/roblox/best-looking-games). Lesson: atmosphere over geometry.
- Mist (Kung Fu Panda / Pandaria-inspired showcase): "breathtaking visuals"; closest tonal reference for an Eastern fantasy on Roblox. No technique details published.
- Beyond the Dark: "wonderful lighting" (same article). Needs a capable GPU: a warning on cost.
- Not documented: any shader-level work. Third-party Roblox shaders (RoShade etc.) are player-side and cannot be relied on.

## 4. Cross-game technique table (what is actually shared)

| Area | Shared rule | Confidence |
|---|---|---|
| Palette | One hue family per region; contrast by value not hue; one small accent colour | Sourced (Elden Ring talk) + measured (Grand Soul) |
| Lighting | Low, backlit sun/moon; destination lit brighter; landmark lit differently from surroundings | Sourced + measured |
| Atmosphere | Dense layered fog with aerial perspective; visible particles | Measured + inference |
| Silhouette | Tall asymmetric vertical landmark readable at long range; vary repeats | Sourced |
| Combat readability | No emissive clutter in boss arenas; gold/red telegraph | Sourced (Elden Ring) |
| UI | Display serif + small caps, thin frames, per-zone tint; ink motifs for wuxia | Measured (Grand Soul), sourced (WWM) |
| Detail budget | Put detail at viewpoints; fill distance with silhouettes | Sourced |

## 5. How we would apply it in Roblox

Context from the repo: Vesperhold (snowfields, tiered gothic citadel), the Hollow and Bellwood temple already have per-area grading, warm accent lights and night motes (PROJECT_STATE.md). The art-direction doc (outputs/visual-audit-2026-11-05/production/ART_DIRECTION.md) already asks for foreground/midground/distant landmark layering and no crushed blacks. This section only maps new techniques onto engine features. Numbers are starting points to test in Studio, not verified values. Cost notes assume 60 fps on a mid phone as the floor.

### 5.1 Per-region grade (palette rule)
- Feature: Lighting (Ambient, OutdoorAmbient, ColorShift_Top/Bottom), Atmosphere.Color/Decay, one ColorCorrectionEffect per region swapped by a tween (0.5-1 s) at region entry.
- Starting points: Bellwood dusk-gold: Atmosphere.Color #c9a46a, Decay #6b4a2a, ColorCorrection TintColor #ffe9c4, Saturation -0.1, Contrast 0.1. Vesperhold snow: Atmosphere.Color #8fa6c4, Decay #2a3a58, Tint #dbe8ff, Saturation -0.2. Hollow: keep existing teal cave grade.
- Keep p5 luminance above ~15/255 outside caves (Hero's darkest scenes are the exception, and art-direction doc already forbids crushed blacks).
- Cost: ColorCorrection is a cheap full-screen pass; only one active at a time.

### 5.2 Backlit low sun with haze (lighting rule)
- Feature: Lighting.Technology = Future (needed for Light shadows and accurate point lights); ClockTime 17.0-17.8 or 5.5-6.5 for the gold zones, moon-high for night; GeographicLatitude to put the sun low/forward of the typical approach. Atmosphere Density 0.35-0.5, Offset 0.1-0.25, Glare 0.4-1, Haze 1.5-3 for the Hero-like creamy bloom; Bloom Intensity 0.4-0.8, Size 24-40, Threshold 0.9-1; SunRays Intensity 0.05-0.15, Spread 0.6-1.
- Camera should usually face the light on landmark approaches (author the path so the reveal is backlit).
- Cost: Future lighting is the heavy item; limit shadow-casting lights to a few near the player (already done for Vesperhold ornament subs). Bloom and SunRays are low-moderate; disable SunRays on low-end mobile quality levels.

### 5.3 Aerial perspective and layered distance
- Feature: Atmosphere (global) plus authored ridge/spire silhouettes at 3 depths, each a flat-lit simple MeshPart with fog-friendly colour (lighter and lower contrast with distance). No per-object blur needed.
- Use ParticleEmitters for fog banks (large, soft, Transparency 0.85-0.95, LightInfluence 1) in valleys only, drifting 1-2 studs/s; cap emitters near the camera.
- DepthOfField: only for menus/cutscenes (it is a full-screen pass).
- Cost: fog is nearly free; huge transparent particles cost fill rate, so keep them few and low rate (<= 2-4/s each).

### 5.4 Vertical focal accents
- A single tall narrow structure (spire, pagoda, bell tower, cyan or gold light shaft) per region, visible from the approach road, lit differently from surroundings: Neon/emissive part + Beam or a tall transparent ParticleEmitter, plus a PointLight with Range ~16-24 (Future).
- Per Elden Ring talk: asymmetry, S-curved approach, one straight light line deep in the scene as the destination marker.
- Cost: one light and a Beam per landmark is trivial; do not stack many shadow-casting lights.

### 5.5 Materials
- Hero of the Grand Soul reads as stylised-realistic with tonal terrain. Ours is already PBR via SurfaceAppearance (2048 maps, no decimation, per memory notes). Keep value structure simple: broad stable surfaces, dark protected recesses, edge wear only on corners (cheaper to read than noise).
- Fog-friendly albedo: avoid pure white and pure black; the art doc's stone families already follow this.
- MeshPart: use RenderFidelity Automatic and `CollisionFidelity` Box/Hull for non-walkable ornament; preserve the existing detail-size fade for ornament subs (win-86). No decimation or tri cap (creator rule).
- Cost: texture memory is the mobile limit; budget by streaming/preload, not by geometry.

### 5.5b Wuxia-specific layer (what Grand Soul lacks)
- Ink-wash/paper UI: warm off-white (#efe6d2) panels with ink-black (#1b1a18) type and vermilion (#b8302a) seal accents; thin inset frame in the Grand Soul style; serif display for titles plus small-caps subtitle.
- Mist bands between ridges as in landscape painting, 2-3 distinct fog layers using Atmosphere plus emitters.
- Cloth and hair must deform (memory rule): do not substitute emissive trails for cloth motion.

### 5.6 Combat VFX
- Weapon trails: Trail objects on two attachments per blade, Lifetime 0.15-0.25, WidthScale taper, LightEmission 0.5-1, colour gradient from bright core to transparent accent. Cost: low; cap at ~2 per character.
- Impact frames: 2-3 frame hit-stop (freeze attacker/target animation speed to 0 briefly), a 1-frame white or inverted ColorCorrection flash (Brightness spike 0.3 for 0.05 s) and a radial ParticleEmitter burst (Burst of 8-16, Lifetime 0.2). Cost: negligible.
- Screen shake: camera offset noise 0.1-0.3 studs, 0.1-0.2 s, scaled by hit weight; give an option to disable.
- Telegraphs: red/gold ground decals or Beams with a clear 0.5-1 s wind-up; keep emissive off boss-arena props (Elden Ring talk).
- Highlight: use for lock-on or telegraph outline on one target only (documented concurrent limits apply; verify the current number in the Roblox docs before relying on many).
- Cost: particles are cheap individually; the risk is overdraw from large additive sprites in multi-player fights, so cap per-effect particle counts and use shared textures.

### 5.7 Camera
- Third-person, FOV 60-70 for combat (wider only in exploration, 70-75); lock-on framing keeps the boss in the upper third with the landmark behind it. Prove every arena at default FOV and player height (art doc contract). Hero's FOV is not documented.

### 5.8 UI
- ScreenGui with UIStroke, UIGradient and a single custom display font plus a serif small-caps subtitle (Roblox font set limits apply; a custom face needs an uploaded Font asset). Region title banners already exist ("Discovered", win-89); give each region a tinted frame matching its grade. Cost: static ImageLabels are cheap; avoid per-frame tweens on many elements on mobile.

### 5.9 Audio mood
- Not documented for the subject. Existing ElevenLabs themes and night beds cover it; follow the Elden Ring pattern of a quiet bed with music only at landmarks/bosses. [inference]

## 6. Priority list (cheapest, biggest win first)
1. Per-region Atmosphere + ColorCorrection tween with one hue family each, low backlit sun on approach paths.
2. One distinctive vertical accent per region, lit unlike its surroundings.
3. Two to three silhouette layers with fog between them on every approach.
4. Region title cards with per-region tinted frames and a two-tier type system.
5. Impact package: hit-stop, flash, burst, light shake; red/gold telegraphs; no emissive clutter in arenas.

## 7. Sources
- https://www.roblox.com/games/5131623903/Hero-of-The-Grand-Soul and https://games.roblox.com/v1/games?universeIds=1783358098
- https://apis.roblox.com/search-api/omni-search (name lookup)
- https://thumbnails.roblox.com/v1/assets (store images measured)
- https://cgworld.jp/article/202508-cedec-eldenring.html
- https://www.gamer.ne.jp/news/202208240067/ (search snippet only)
- https://gamerant.com/fromsoftware-games-fog-walls-dark-souls-elden-ring-bloodborne/
- https://automaton-media.com/en/news/this-is-what-it-means-to-be-good-at-art-capcom-veteran-akiman-on-why-elden-rings-environments-stand-out-even-among-higher-fidelity-aaas/
- https://www.unrealengine.com/developer-interviews/black-myth-wukong-wows-with-ue5-early-access-visuals (snippet only)
- https://gamingtrend.com/feature/reviews/black-myth-wukong-review-monkeys-eating-good
- https://80.lv/articles/how-netease-built-an-authentic-wuxia-open-world-in-where-winds-meet
- https://www.techradar.com/gaming/where-winds-meet-interview
- https://www.redbull.com/us-en/sekiro-shadows-die-twice-interview
- https://www.thegamer.com/sekiro-shadows-die-twice-worst-best-things/
- https://www.pocketgamer.com/roblox/best-looking-games
- https://create.roblox.com/docs/reference/engine/classes/Atmosphere (property list only)
- Project: PROJECT_STATE.md; outputs/visual-audit-2026-11-05/production/ART_DIRECTION.md

## 8. Gaps to close next
- Watch gameplay video of Hero of the Grand Soul to measure combat VFX, camera FOV and UI in motion; I could not view video.
- Read the Elden Ring CEDEC 2022 atmosphere article via a browser; my fetcher got 403.
- Verify all numeric Roblox settings in Studio against our own scenes; none here were run.

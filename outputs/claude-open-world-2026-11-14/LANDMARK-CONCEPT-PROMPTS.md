# Landmark concepts to generate (ChatGPT image → image-to-3D), 2026-11-21

## How to get models that convert well
Image-to-3D tools make one clean object per image. A whole castle in one picture comes out as mush. So for each landmark, ask ChatGPT for three things:
1. **A key-art shot** for mood and placement. This is reference only and is not converted.
2. **A kit sheet:** each large piece (tower, wall section, arch, stair, statue, rubble pile) as its own isolated image.
3. **A turnaround of each piece:** front, side, back and three-quarter views.

Then send each piece image to the 3D generator separately (Meshy, Rodin and so on) and drop the GLBs plus images into `assets/source/landmarks/<name>/`.

**Template to paste into ChatGPT (fill the brackets):**
> Concept art for a Roblox dark-fantasy xianxia game, semi-realistic weathered PBR style matching a ruined gothic-meets-Chinese castle. Subject: [PIECE] from [LANDMARK]. Single isolated object, centered, full object visible, three-quarter view from slightly above, plain neutral grey background, soft even studio lighting, no fog, no characters, no text, no cropping. Materials: [e.g. mossy grey granite, oxidised bronze, faded red lacquer]. Show scale with a faint 1.8 m human silhouette at the side. Then give the same object as an orthographic turnaround (front, side, back) on one sheet.

## The list (★ = build first)

### Bellwood (forest)
- ★ **Sunken half-destroyed temple:** a tiered stone temple sunk 40% into a forest lake and tilted 10°. Its roof is split by a giant tree growing through it, and the water is full of lily pads. Pieces: tilted main hall, broken roof tiers, a toppled column row, a half-submerged stair, a guardian lion statue with its head off, a floating debris raft.
- **Root-strangled gate:** a paifang-style stone archway split down the middle by tree roots, with prayer ribbons hanging from it.
- **Fallen giant's face:** a colossal moss-covered stone face lying on its side, half-buried in the earth, with one eye socket as a cave.

### Amberfall (golden ravine)
- ★ **Cliff monastery:** a tiered pagoda bolted to a ravine wall, with timber balconies over the drop, rope bridges and hanging bronze bells. Pieces: pagoda tiers, balcony module, rope bridge span, bell cluster.
- **Broken stone bridge:** a huge arched bridge across the ravine with its centre span collapsed, and chains and banners hanging from the gap.

### Saltreach (arid basin)
- ★ **Buried salt palace:** only the domes, spires and one archway of a palace show above salt-crusted sand. Pieces: cracked dome, spire, half-buried arch, salt-encrusted statue hand rising from the ground.
- **Colossal sword in the earth:** a blade three storeys tall, driven into the basin, with cracked ground and wind-worn shrines around its base.
- **Canyon tomb facade:** a temple front carved into a sandstone cliff, with weathered guardian reliefs.

### Frostmere (snowfields)
- ★ **Frozen waterfall shrine:** a bell tower locked inside a frozen waterfall, with a small shrine at its foot and icicle curtains. Pieces: ice-locked tower, shrine, icicle curtain module.
- **Ice-bound dragon skeleton:** a serpentine skeleton arching out of a frozen lake (three or four separate sections).
- **Snow-buried observatory:** a cracked bronze armillary sphere on a stone platform, with half its roof gone.

### Ashen Stair (mountain ascent)
- ★ **Thousand-step broken stair:** a monumental stair up the mountain, with collapsed sections, ash drifts and burnt pine stumps. Pieces: stair module, broken-gap module, guardian pillar pair.
- **Chained floating rocks:** shattered mountain fragments hanging in the air, held by huge rusted chains anchored to sealing pillars (this fits the Asura-seal lore).
- **Peak fortress gate:** a burnt fortress gate with one door torn off and ember-lit cracks.

### Vesperhold (extends the castle)
- **Roofless cathedral nave:** gothic arches open to the sky, with a broken rose window and snow on the pews.
- **Gargoyle bridge:** a stone bridge lined with gargoyles that leads to the castle, with one section fallen.
- **Mausoleum and graveyard:** a gothic crypt with leaning headstones and iron fences.

### Anywhere (lore glue)
- **Asura colossus fragments:** a giant broken statue scattered across one region, with a hand, a head, a sword arm and a torso as separate pieces.
- **Sealing pillars:** tall carved pillars with talismans and chains, used as visual waypoints and checkpoints.
- **Waystone shrines:** small lantern shrines to put at every road fork. The night system lights them automatically.

## Order to send to me (Claude)
1. The sunken temple (it tests water, tilt and baking).
2. The Ashen Stair steps (modular).
3. The buried salt palace.
4. The frozen waterfall shrine.
5. The cliff monastery.

Do one landmark at a time. Each one is a full pass: import, placement, lighting, captures and performance.

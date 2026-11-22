# SFX wiring plan (no src edited)

Existing pattern: `Audio.play(key, parent, vol, looped)` / `Audio.at(key, pos, vol, looped)` in `src/client/Controllers/SpatialAudio.luau` resolve a key via `SoundService.AsuraAudio/<key>` or `PresentationAssets.Audio[key]`. Regions are driven by `SoundscapeController.luau` (`World.regionAt`, 0.15 s tick, `ridgeCues` table for Vesperhold). Pipeline: upload mp3 via the cloud-window uploader, then record ids in `assets/OVERWORLD_AUDIO_UPLOADED.json` (note: nothing in src currently reads that file; ids must be copied into `PresentationAssets.Audio`). Check moderationState before use.

Note: `Audio.LIFETIME = 12` s bounds voices; looped sounds must use the `looped` arg path (as the existing Water loop does) and be stopped by the controller.

## Vesperhold (SoundscapeController, region Snowfields with `Overworld.vesperholdWeight > 0`)
| Key | Use | Where | Vol | RollOff min/max |
|---|---|---|---|---|
| VesperBellGreat | one-shot, replaces/adds to `ridgeCues.Bell` (Delay ~41 s) | `Audio.at` at ridge bell pos | 0.45 | 85 / 710 |
| VesperBellDistant | one-shot outside weight edge, Delay ~60 s | 3D, far ridge pos | 0.3 | 120 / 900 |
| VesperWindSpires | loop, 2D ambience via `self.Ambient` swap while inside weight>0.3, gain by `Wind.ambience` | SoundService | 0.25-0.4 | n/a |
| VesperRain | loop 2D, only when Weather.Raining and in weight>0 | SoundService | 0.3 | n/a |
| VesperChoir | loop 2D, fade in with `insideKeep` (Cloister zone), tween 3 s | SoundService | 0.18 | n/a |
| VesperTorch | loop 3D, one per torch cluster (max 4 nearest, pooled) | torch Attachment | 0.3 | 6 / 45 |
| VesperCryptDrips | loop 3D at crypt/undercroft entrance, else 2D inside | crypt part | 0.35 | 8 / 60 |
| VesperGateCreak / VesperGateSlam | one-shot on gate open/close event | gate hinge part | 0.6 / 0.8 | 20 / 220 |
| VesperChain | one-shot random 20-40 s near hanging chains, or on gate move | chain part | 0.35 | 10 / 90 |
| VesperRaven | already a ridge cue (`VesperRaven`, Delay 29): swap asset | existing | 0.31 | 14 / 205 |
| VesperStoneDoor | one-shot on door puzzle/boss-door server event | door part | 0.6 | 20 / 250 |
| VesperGargoyle | one-shot on gargoyle activation/break | gargoyle part | 0.6 | 15 / 160 |
Loops need `Audio.zone("Cloister")` reverb (already set by `insideKeep`).

## Bellwood basin / Sunken Temple (add a Bellwood branch in SoundscapeController keyed on region + position in the basin box from LANDMARK-BUILD-SPEC.md)
| Key | Use | Where | Vol | RollOff min/max |
|---|---|---|---|---|
| BasinBirdsInsects | loop 2D ambience replacing Wind when inside basin | SoundService | 0.3 | n/a |
| BasinRainTunnel | loop 3D/2D inside the eye tunnel, fade by tunnel-interior test | tunnel mid part | 0.4 | 10 / 70 |
| BasinWaterfall | loop 3D at waterfall base | waterfall part | 0.5 | 25 / 220 |
| BasinLake | loop 3D, repositioned to nearest lake-edge point (like `Water`) | shore point | 0.3 | 8 / 80 |
| BasinRibbons | loop 3D at ribbon clusters | ribbon pole | 0.2 | 5 / 35 |
| BasinChimes | loop 3D at temple eaves | eave part | 0.2 | 5 / 40 |
| BasinGong | one-shot on gong interact/ritual event, server fires remote | gong part | 0.7 | 30 / 350 |
| BasinBoat | one-shot on boat board / rock, random while mounted | boat part | 0.35 | 5 / 40 |

## Other regions (region switch already stops/starts `self.Ambient`; add a per-region loop key beside `Wind`)
- FrostmereBlizzard loop 2D 0.3 (Frostmere); FrostmereIceCrack one-shot random 25-50 s at lake pos, 0.4, 20/200.
- AmberfallRoar loop 3D at falls, 0.5, 30/260.
- SaltreachSurf loop 3D along shoreline nearest point, 0.4, 20/200.
- AshenStairWind loop 2D 0.3 (Ashen Stair).

## Prereqs
1. Upload all 26 mp3 (cloud window), add ids to the registry JSON and `PresentationAssets.Audio`.
2. Loops: verify seamlessness; crossfade in code (two Sounds, tween) if a click is audible.
3. No ffmpeg on this machine: no OGG/loudnorm done; balance via the Vol column.

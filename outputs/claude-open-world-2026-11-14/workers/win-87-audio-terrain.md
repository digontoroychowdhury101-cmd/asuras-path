# win-87: ElevenLabs score and rolling hills (Windows, 24 Nov 2026)

## Audio
ElevenLabs flow `FOHQ0udFunvmy6nqHJRP` used 5,600 credits:
- three instrumental themes (Music v2.5, 120 s): day (guqin and dizi), night (xiao, erhu and celesta) and the Vesperhold ridge (low strings, choir and bell);
- two 30 s looping beds (SFX v3): Bellwood night insects and Frostmere snow night.

All five were uploaded through Open Cloud by creator 3148600636, read back as Approved, and wired into `PresentationAssets`. The masters are in `assets/source/audio/overworld_win87/` (gitignored); hashes are in `assets/OVERWORLD_AUDIO_UPLOADED.json`.

`SoundscapeController`:
- one quiet theme (gain 0.2) across the five overworld regions:
  - Vesperhold on the ridge;
  - otherwise night or day by the lantern level;
  - silent in the lobby and while a boss score plays.
- forest day and night beds under the wind; snow night bed in Frostmere away from the ridge.

Play check: each one loads and plays in its place.

## Terrain
Creator: "elevation changes throughout instead of just flat terrain".

`TerrainDef.Hills` adds kilometre swells (760 and 260 stud octaves) per region: Forest 95, Saltreach 95 and Frostmere 90, which rolls upward only. Amberfall keeps its chasm and the Ashen Stair its massif.

The swells calm over:
- the salt pan and the frozen lake;
- the Vesperhold ridge;
- the Bellwood temple basin and the authored slice;
- the glade-to-summit lane;
- the divide crest and the Headwater gorge;
- the chasm;
- road banks and straight trails;
- the world-edge cliffs.

| Region | Swell p05..p95 before | after | Median 50-stud rise before | after |
|---|---|---|---|---|
| Saltreach | 13 | 84 | 9.4 | 13.9 |
| Frostmere | 22 | 78 | 10.6 | 14.4 |
| Bellwood | 45 | 94 | 9.9 | 13.6 |

Taller swells (amps of 125 or more) broke the 4-stud step budget on road banks and the band floors, so 75 is the new guard. `edgeInset` jumps at its fast-path thresholds, so the hill fade uses the raw frame distance.

Other changes:
- Saltreach pine base density raised from 0.5 to 0.6, to keep it above 20 pines.
- The Vesperhold massing checksum was re-baselined (the lowlands moved on purpose).
- `sampleAt` costs about 36% more on the CLI. That is the server's background terrain build, not the client frame.

Captures:
- `captures/win/terrain87/hillshade_before_after.png`: a whole-world hillshade, old vs new.
- Studio Play capture at the Bellwood: hills rise around the glade.

Verification: all 17 terrain-dependent suites pass and verify_all exits 0. Development saved, v49.

# GitHub reuse for Asura's Path — 26 October 2026

Star counts were read from GitHub's repository API on this date. Only repositories with **more
than 1,000 stars** supplied imported work. Code and media licenses were checked separately.

| Repository | Stars | License for selected work | Delivered use |
|---|---:|---|---|
| [Auburn/FastNoiseLite](https://github.com/Auburn/FastNoiseLite) | 3,534 | MIT | Vendored upstream JavaScript library; baked 48 OpenSimplex2S / ridged noise samples into the existing Monastery upper cliffs. |
| [effekseer/Effekseer](https://github.com/effekseer/Effekseer) | 1,812 | MIT for code; explicit CC0 for selected samples | Ported `MathUtl.Easing` into the combat ember envelope; uploaded seven AndrewFM texture variants; five are wired into parry, thunder and Blazing Sun effects. |
| [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) | 9,709 | Selected WAVs each explicitly CC0 | Uploaded two physical impact sounds, verified both in Studio and connected them to combat. |

## Included in the game build

`src/shared/MonasteryRidgeProfile.luau` is an offline bake from the pinned FastNoiseLite source.
`MonasteryTerrain` uses it for the existing upper cliff balls. Heights remain in the original
18–38 stud range, and the old random draws are still consumed so the rest of the seeded dressing
stays in place. Floors, road cuts, ravine cuts and the Twins approach retain their authored parameters.

`src/shared/EffectEasing.luau` adapts Effekseer's start/end-speed cubic. `CombatVfx` samples the curve
into one shared NumberSequence for combat embers. No per-frame scheduler, particle count or lifetime
was added. Blood retains its existing envelope. Full MIT notices travel with the port, original
source and ending credits.

## Roblox texture integration and prepared audio

`assets/github/ready/preview.jpg` shows the prepared texture shapes. The source images in
`assets/github/effekseer/` are preserved; `ready/` contains white RGBA masks suitable for tinting.
`GithubThunder` is rotated into a horizontal beam strip; `GithubShockwave` is an unwrapped ring strip, requiring
wrapped UVs or a ribbon/beam rather than a square billboard. These are textures, not whole portable
Effekseer effects. Roblox cannot directly execute Effekseer's native effect files.

The eight prepared files are:

- `GithubThunder.png`, `GithubWind.png`, `GithubSpark.png`, `GithubShockwave.png`, `GithubSmoke.png`, `GithubFlame.png`.
- `GithubHeavyImpact.wav` (FFeller) and `GithubLightImpact.wav` (dorian.mastin). Peaks are -6 dBFS, with DC removal and 5 ms end fades.

**Six textures were uploaded through Studio and registered with real Roblox IDs.** Five are active:
wind and wrapped shockwave for parries, flame/smoke for Blazing Sun and the horizontal strip for Celestial lightning. Spark and vertical thunder
masks are registered as reserves. The wind overlay observes reduced effects/motion and
leaves with the bounded parry burst. All seven images passed typed Studio preloading, including the
rotated lightning variant. Their IDs are recorded in `assets/GITHUB_UPLOADED.json`. Rendering and
visual mix still need a normal Studio playtest.

**Ten sounds were uploaded; nine remain registered after live verification.** Two physical impacts
and two Superpowers whooshes are active; five other fantasy cues are an audition library. The long
forest ambience is excluded from the registry because Roblox rejected live requester approval. The user
approved audio uploads. No account permissions were changed. The browsable source-mapped Studio
library is `ReplicatedStorage.AsurasPath.GithubAssets` (seven Decals and nine Sounds).

Exact repository commits, Git blob / LFS identities, SHA-256 checksums and local preparation details
are in `assets/GITHUB_REUSE.json` and `assets/GITHUB_CODE_SOURCES.json`. License evidence is beside
the raw assets; `assets/CREDITS.md` distinguishes integrated code from staged media.

## Other repositories screened

| Repository | Stars | Decision |
|---|---:|---|
| [SebLague/Procedural-Landmass-Generation](https://github.com/SebLague/Procedural-Landmass-Generation) | 1,250 | MIT Unity terrain tutorial. Kept as a lead; FastNoiseLite fits our existing terrain builder without importing a Unity map system. |
| [guillaumeblanc/ozz-animation](https://github.com/guillaumeblanc/ozz-animation) | 2,976 | MIT skeletal animation tooling. Native C++ runtime; does not supply Roblox-ready R15 combat tracks. No animation replacement claimed. |
| [increpare/bfxr](https://github.com/increpare/bfxr) | 1,026 | Apache-2.0 legacy ActionScript SFX authoring tool, superseded upstream by Bfxr2. Selected actual physical impact samples instead. |
| [EsotericSoftware/spine-runtimes](https://github.com/EsotericSoftware/spine-runtimes) | 5,331 | Excluded: license requires Spine Editor licensing; popularity does not make it freely reusable open source. |
| [Quenty/NevermoreEngine](https://github.com/Quenty/NevermoreEngine) | 624 | Excluded by the requested star threshold. |

## Reproduce and verify

Run from the repository root:

```sh
node tools/assets/build_github_terrain.mjs
python3 tools/assets/fetch_github_assets.py
python3 tools/assets/prepare_github_media.py  # Python with Pillow and NumPy
python3 tools/test_github_reuse.py
bash tools/verify_all.sh
python3 tools/build.py
```

The fetcher downloads only the curated files and verifies both Git pointers and real LFS payloads;
it never clones or runs downloaded game scripts. `test_github_reuse.py` uses standard-library Python
and the existing local Luau binary, so verification does not need Pillow or NumPy. The full verifier
includes the new checks. Source compilation and engine-fake tests do not certify Studio rendering,
the terrain voxel surface, listening quality, frame rate or human play.


Expanded search: see `outputs/github-search-2026-10-26/README.md`, `repositories.csv` and `assets/GITHUB_RESEARCH.json` for 149 candidates, 135 above the requested star threshold, and the source/compatibility decisions.

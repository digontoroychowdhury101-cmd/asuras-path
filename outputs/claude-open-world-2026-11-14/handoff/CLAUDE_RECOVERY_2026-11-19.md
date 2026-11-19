# Claude rebuild recovery, 19 November 2026

This records the interruption at 15:35 Sydney time. The local branch and its cached tracking ref both pointed to `fe603e172d2eef2e574b7bd0943a3b9a50c609f6`. The earlier Windows handoff at `d1e92fa` predates this rebuild. Sources were the actual Claude Code session `f4f8557f-7bda-450d-918e-b53abaf207be`, its five worker transcripts, the commits, the working diff and the local asset manifests.

## Creator decisions

The creator preferred the updated Codex place to its survey but rejected its art as insufficiently haunted, colossal and detailed. They provided four more reference images, asked for withered trees, permitted up to five workers including Opus workers, and requested a Windows handoff for a T3 session using Claude and ChatGPT. After reviewing the first Blender kit, they specifically rejected the statues and requested a new pass using blender-skills. They chose free tools and CC0 Poly Haven assets, zero Meshy credits, and a byte-identical checkpoint place for Windows. The shared place was reserved for asset uploads and remained at M1 version 9 in the last verified record.

The adapted high-poly pipeline keeps the silhouette by splitting submeshes below 18,000 triangles. It requires applied transforms, shared foot-centre origins, 2K or higher PBR maps, weighted normals where appropriate and black metalness on nonmetals. The approved handoff filename is `places/checkpoints/AsurasPath_Vesperhold_MacHandoff_2026-11-19.rbxlx`, accompanied by a SHA-256 and Studio source digest. See [the rebuild rules](../workers/mac-50-vesp-rebuild-rules.md), [the reference brief](../workers/mac-40-vesperhold-verdict.md) and [third-party provenance](../../vesperhold/THIRD_PARTY.md).

## Interrupted lanes

Five-hour API limits stopped the engineering lead and all four art/integration workers between 15:31 and 15:35. Claude reported HTTP 429 and a 19:00 Sydney reset. The older 03:10 reset in the original screenshot belonged to a previous limit.

| Lane and transcript suffix | Recoverable at interruption | Outstanding |
|---|---|---|
| Lead, Opus, `adc6b08fadd65250b` | Pinned blender-skills, acquired eight CC0 2K texture sets and four scans, added material adaptation and the JPEG embed fix, committed the first statue package in `fe603e1`. | Integration, updated Windows build and visual acceptance. |
| mac-51, Opus, `a4a810e127fed2ab9` | Three new high-poly sculpts, bake tools, 2K maps, embedded GLBs and [review sheets](../../vesperhold/kit-renders-v2/). | Second pass never started. Re-bake with the CC0 stone base, refine sleeves, hands, hood and staff, add the fourth veiled scan, compare four figures at the same scale. |
| mac-52, Opus, `a6edf9542872002e8` | Inspected gargoyle, tree and CC0 inputs. | No saved implementation or revised render was found. Previous gargoyles and trees remained available. |
| mac-53, Opus, `ac3f07365c1aa3c09` | Two edits in `vesperhold_kit.py` changing material tiling and the stained-glass generator. | No rebuilt architecture, full UV/frost pass, merged manifest or new review sheet was established. |
| mac-54, Sonnet, `afa2070ecc339bf50` | Uncommitted registry, Rojo mappings, kit loader, slot placement, size reconciliation, ridge trail-stake exclusion and partial tests. | Registry empty, engine placement untested, atmosphere unfinished. The three Luau smoke passes in its transcript preceded the implementation. |

## Files and verification

The ignored Mac source directories held 31 architecture, 26 prop and 10 tree GLBs. All three replacement statues had embedded images. Direct GLB inspection gave 63,752, 73,896 and 105,028 triangles for A, B and the pedestal figure, respectively, with every individual submesh at or below 17,164. Their actual upload files measured 6.83, 7.46 and 10.38 MiB. The props upload manifest was older than those three files. The source manifest still identified a procedural stone base on all three. At inspection, 22 kit files and three prop files in the old upload folder were at least 50,000,000 bytes.

Generated GLBs, raw maps and CC0 downloads under `assets/source/` are gitignored. The local tracking ref for the 16 November asset branch listed no Vesperhold directory. A clean Windows checkout could recover the committed scripts and review sheets alone. The recovery needs either an independently verified asset package or a reproducible rebuild with the same downloads. No Vesperhold uploaded-asset registry, operation IDs or named Windows checkpoint were found. The existing untracked Studio place and walkthrough belong to the earlier Codex build. The previous full-verifier pass and captures apply to their recorded earlier revisions. Verification of the new loader, seven-view Studio acceptance, profiling and Windows multiplayer testing remained open at the interruption.

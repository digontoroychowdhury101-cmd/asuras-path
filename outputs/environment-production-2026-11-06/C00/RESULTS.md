# C00: survey and asset intake (results)

**Done.** All 36 findings are reconciled. The boss and H-asset files are inventoried, the libraries listed by exact name, the rig, camera and lighting measured, and the cast references exported. No game source, asset or saved place changed. This batch adds documents and probes only.

## Outcome

- **Routing:** [ROUTING_LEDGER.md](ROUTING_LEDGER.md) / `.csv`, built by `build_ledger.py`. Status counts:
  - open: 24
  - open with a pending hero asset: 2
  - open and partly superseded by arena work: 2
  - superseded by an arena redesign: 4 (plus 1 that also waits on an asset)
  - awaiting a supplied asset: 2
  - partly fixed and awaiting assets: 1 (AP-01: Shen, Zhao and Bull integrated; four bosses still have no files)

  Since audit commit `a29f8cf`, only Shen-related source has changed. No finding is "already fixed" in source apart from Shen's part of AP-01.
- **Intake and measurements:** [ASSET_INTAKE.md](ASSET_INTAKE.md). Raw data: `edit-measure.json` (templates, bosses, lighting, StarterPlayer), `player-measure.json`, `asset-libraries.json`.
- **Cast references:** `references/mannequin_front.jpg`, `references/mannequin_side.jpg`.

## Evidence by category

| Category | Result |
|---|---|
| Static review | Source traced for arena/fog/camera/motion/lighting callers (see AR00 manifest). Git diff since the audit per finding. |
| Local regression | Not needed: no game code changed in C00. The verifier runs at the AR01 checkpoint. |
| Studio integration | Seeded measurements in a temporary build with a matching digest. Edit-mode template clones were destroyed afterwards. One Play session was started and stopped, and lighting/camera overrides were restored. |
| Normal-input human acceptance | Not applicable; none performed. |
| Multiplayer / device profiling | Not performed. |

## Changed files

- `outputs/environment-production-2026-11-06/C00/*` (this folder)
- `tools/qa/run_luau_file.py`, `tools/qa/C00MeasureEdit.luau`, `tools/qa/C00MeasurePlayer.luau`, `tools/qa/C00Libraries.luau` (read-only QA probes, not mapped into the game)

## Remaining dependencies

1. Baize, Titan, Wu and Wyrm model exports: not on this machine and not imported. Needed for AR03–AR06 clearance, not for AR01.
2. All nine H-asset exports: not found. Only H01 matters to AR01, and it is optional.
3. The Shen master `.blend` and game GLBs live on the Mac. AR01 uses the committed templates only.
4. Final Shen attack-pose envelopes depend on Mac's ongoing clip work. Clearance values derived from them stay provisional.

## Next action

AR00: spatial manifest, top-down site plan and two measured prototypes for each arena, then AR01.

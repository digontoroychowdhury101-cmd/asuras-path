# Boss inputs (prompt pack and source GLBs)

Data-only branch. It has no history shared with the game branch and is never merged into it.

- `prompt-pack/`: the boss integration prompt pack (2026-11-05). It holds the numbered briefs 01-06, `CONCEPT-ART.md`,
  `asset-audit.json` and `references/` (concept PNGs and their source briefs).
- `glb/`: the nine supplied source sculpts, byte-identical to `asset-audit.json` (SHA-256 checked 2026-11-09).
- `MANIFEST.sha256`: SHA-256 of every file above.

To restore, run this from the game repo on `ux/onboarding-overhaul`:

    git fetch origin boss-inputs-2026-11-05:refs/remotes/origin/boss-inputs-2026-11-05
    python tools/assets/fetch_boss_inputs.py --apply

That writes the files to `work/boss_inputs/` (gitignored) and checks each against the manifest.
It never overwrites a file that differs.

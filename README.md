# Shen handoff assets (2026-11-09)

The Grandmaster Shen files Git does not otherwise carry: the source and Master assets, the prepared Game/Props GLBs, `work/shen_import` and
the current frame JSON. They are in one zip, split into parts under GitHub's 100 MB file limit. This branch holds nothing else; do not
check it out over your work.

Restore from the `ux/onboarding-overhaul` checkout (dry run first; nothing is overwritten):

    git fetch origin shen-assets-2026-11-09
    python outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/scripts/restore_untracked.py --from-branch origin/shen-assets-2026-11-09
    python outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/scripts/restore_untracked.py --from-branch origin/shen-assets-2026-11-09 --apply

Whole zip SHA-256: see `shen-untracked-2026-11-09.zip.sha256`. Per-file SHA-256: `ARCHIVE_MANIFEST.sha256`. Packed from code commit bffea2d.
Full guide: `outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/ARCHIVE.md` on `ux/onboarding-overhaul`.

# Continue on Windows from the Mac, 22 November 2026 (landmark loop, Bellwood)

Continue Asura's Path; don't start over. These steps work for a Claude or Codex agent. They replace the 19 Nov run 3b
prompt (in git history at `97deae7`).

1. Sync safely.
   - Check local work first.
   - Run `git fetch origin` and fast-forward `ux/onboarding-overhaul`. No reset, clean, stash or force-push.
2. Read `outputs/claude-open-world-2026-11-14/WINDOWS_HANDOFF.md` in full. It holds the current state, the creator decisions from 22 Nov, every procedure and the ordered next steps.
3. Read the spec in full:
   - `LANDMARK-BUILD-SPEC.md`
   - the `concepts/*.webp` images (look at them)
   - `NEXT-VISUAL-PASS-PROMPT.md`
   - `outputs/vesperhold/THIRD_PARTY.md`
4. Restore the gitignored landmark sources from branch `landmark-assets-2026-11-21` (handoff §3.2). Then run `ASURA_BUILD_OUTPUT=work/verify.rbxlx bash tools/verify_all.sh` and confirm `SUCCESS`.
5. Do handoff §4 in order. Next up is the rest of the Sunken Temple: the tree, the gate towers on the left third, dressing, the colonnade, the lion, the water pieces, and the water and mist settings. Then fix the §7 defects, then move on to Amberfall.
6. Work rules:
   - Tests first.
   - One heavy Blender job machine-wide (`work/vesperhold-claude/heavy.lock`).
   - Verify in a disposable build with Play captures and fps.
   - Commit explicit paths, push, and add a ≤ 60-word `(Windows)` line to `PROJECT_STATE.md`.
   - Save verified builds to the Roblox Development place with File > Save to Roblox. Never Publish. The creator decided this on 22 Nov; it overrides the old "cloud stays M1 v9" rule.

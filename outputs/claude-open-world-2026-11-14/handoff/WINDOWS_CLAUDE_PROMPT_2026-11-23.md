# Windows Claude prompt: Bellwood Hollow (2026-11-23, from the Mac)

Paste everything below the line into Claude Code on the Windows computer, opened in the `asuras-path` repo. For the Bellwood Hollow work, this supersedes `WINDOWS_RESUME_PROMPT.md`.

---

You are continuing Asura's Path on the Windows computer. The Mac finished the Bellwood v20 colossal temple and roofed its basin as "the Hollow", an underground cave. Your jobs are the checks the Mac cannot do: multiplayer, device profiling, and judging the cave's look on hardware that draws the whole vault. Fix what fails, then save and push. Do not ask the creator questions you can answer from the repo. Give a one-line status after each step.

## 0. Start the session

1. Run `git status`, `git fetch origin`, then fast-forward `ux/onboarding-overhaul` (`git merge --ff-only origin/ux/onboarding-overhaul`). Expect the commit "Bellwood v20 temple in the basin, roofed as the Hollow cave" (d73f70a) and the handoff commit after it.
2. Read `CLAUDE.md` and `AGENTS.md`. Every rule there applies; the key ones are listed at the end of this prompt.
3. Read the top lines of `PROJECT_STATE.md`.
4. Read `outputs/claude-open-world-2026-11-14/handoff/CODEX_BELLWOOD_V20_HANDOFF.md` and `CLAUDE_RETURN_HANDOFF.md`.

## 1. Confirm Studio matches git

- The Mac saved the build to Roblox (File > Save to Roblox As, never Publish): Development place **118614906972571**, universe **10777041159**, "Asura's Path — Development". It was built from the `src/` at d73f70a. Later commits changed only docs.
- In Studio, use File > Open from Roblox and open that place. Then run `ASURA_BUILD_OUTPUT=work/verify.rbxlx bash tools/verify_all.sh` (Git Bash). It must pass. Use `tools\handoff.cmd` for the git relay if you prefer.
- If you change any `src/` file, the cloud place no longer matches. Rebuild, Play-verify and save it again (step 6).

## 2. What changed (so you know what to test)

- **Where it is.** Walking through the eye of the broken-head statue leads down the tunnel into the Bellwood basin, near world (-4178, 184, -2298). That basin is now the Hollow.
- **The vault.** `LandmarkWorld.cavernShell` springs a basalt vault (rock skin outside) from the basin rim. It closes at Apex 1160 over the temple crown and is about 14,198 terrain fills. `cavernExit` cuts a doorway at every route point inside the wall. Settings are in `LandmarkLayout` `Basin.Cavern`. The server takes about 245 s in Play to build the basin, then sets `workspace` attribute `AsuraCavern = true`.
- **The lights.** `LandmarkWorld.cavernLights` builds model `HollowLights` (~1,326 parts):
  - amber neon "kintsugi" veins that fork across the vault
  - an iris eye at the apex, with a beam of light down onto the temple
  - 36 stalactites with teal or amber tips
  - 64 teal glowstones in the shallows
  - 18 PointLights in total
  - a mote emitter (Rate 140)
- **The cave grade.** `EnvironmentProfiles.compose` takes a `Cavern` weight. It sets:
  - the clock to noon at every hour, easing the short way round at the doorway
  - teal-grey ambient (150, 158, 162), diffuse 1, exposure 0.3
  - a warm key over teal shadows
  - colour-correction contrast 0.04, so dark basalt does not crush to black
  - thin teal haze (density 0.25, offset 1), and no sun rays

  `WeatherController` feeds the weight (no rain, no cloud deck inside) and exposes `self.Cavern`.
- **Shadows and sky.** `EnvironmentController.setCave` turns `Lighting.GlobalShadows` off and swaps in a black sky (`rbxasset://textures/blackBkg_square.png`). Both are restored on the way out. This matters: with shadows on, the vault shadowed every surface and the cave rendered pitch black at any ambient level. `SoundscapeController` adds Cave reverb.
- **Walking.** The 128-tread temple stair now collides as eight smooth invisible ramps (`StairRamp0..7`), not per-tread boxes. Per-tread boxes made the walk hitch (speed 22 → 9). Temple pieces carry `AsuraKeepFar`, so `LandscapeBudget` no longer unloads them; unloading is what made things look like they were floating.
- **Tests.** `tools/test_vesperhold_loader.luau` (217) and `tools/test_weather_composition.luau` (443) cover all of the above. Run them with `python3 tools/lune_compat.py tools/<test>.luau`.

## 3. Mac Play results (single client), to compare against

- Route probe: 523 points, 0 missing ground, 0 sudden rises.
- Client walk: 523/523 in 148 s, no swimming. It had 8 stalls on the gate-side switchback (route points ~380–395, near world (-3743, 181, -1956)) on the first visit only. A re-walk of that stretch had 0 stalls, so the Mac read it as streaming.
- About 15 fps in the Hollow, the same with and without `HollowLights`; Studio on that MacBook is the limit.
- **Not judged on the Mac:** the overall look. Studio there culls terrain beyond ~930 studs, so most of the vault is not drawn and the space overhead reads as black. One capture with the vault drawn looked right: blue-lit stone, gold veins, the tree and temple clear. The temple facade from the far shore stayed dim.

## 4. Your checks on Windows

1. **Look (creator's priority).** The creator said the basin "should not have a sky since it is underground" and was "too dark, add good lighting, be ambitious".
   - Play, walk in through the doorway and capture these views:
     - the causeway
     - the stair approach with both guardian lions
     - straight up at the iris and veins
     - the far shore looking at the temple
     - inside the temple hall
     - the exit doorway looking out
   - Confirm that no sky or sun shows anywhere inside, and that the temple, stair and lions read clearly.
   - If it is still too dark, raise the `Cavern` block in `EnvironmentProfiles` (ambient toward ~(175, 182, 186), exposure toward 0.45) or add warm fill along the stair flanks in `cavernLights` (PointLight range is capped at 60). Update `test_weather_composition` to match.
   - Apply the antislop rules in `.agents/skills/antislop/`.
2. **Multiplayer (Windows only).** Test with 2 clients (Studio Test > Clients and Servers). For each:
   - The cave grade, shadows-off and black sky apply only to a player inside. A player outside the basin keeps the normal sky and shadows.
   - Walking out through the doorway restores sky and shadows.
   - Rain stops inside.
   - Both players see the same vault and lights.
   - Shen's barrier, the lobby, combat and progression still work.
3. **Device profiling (Windows only).**
   - Measure frame time inside the Hollow and on the stair, on this PC and with the Studio device emulator (a phone profile).
   - Record memory, and draw cost with `HollowLights` toggled.
   - If phones struggle, reduce mote Rate, vein forks or the lit-stalactite count in `LandmarkLayout`/`cavernLights`. Keep the look.
4. **Gate switchback.** Walk route points ~380–395 on a fresh join. If the stall repeats, find and fix the snag.
5. **Optional polish.** Make an original dark cave skybox (procedural, or CC0 — never Creator Store) and upload it. Then replace `CAVE_SKY` in `EnvironmentController`; it is marked with a `shortcut:` comment.

## 5. Bellwood art backlog (after the checks)

Follow `CLAUDE_BELLWOOD_REPLACEMENT_HANDOFF.md` and `CODEX_BELLWOOD_V20_HANDOFF.md` for anything still open: guardian tint comparison, root support and the tree.

## 6. Finish every batch

1. Run `ASURA_BUILD_OUTPUT=work/verify.rbxlx bash tools/verify_all.sh` and fix any failure.
2. Play-verify the change.
3. If `src/` or assets changed, use File > Save to Roblox As > Asura's Path — Development > Overwrite place 118614906972571. Studio may say it is applying script changes and will close; that is normal. **Never Publish.**
4. Add at most 60 words at the top of `PROJECT_STATE.md` with a `(Windows)` tag.
5. Stage explicit paths only, commit with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, and push `origin ux/onboarding-overhaul`.
6. Push raw source assets (`assets/source/...`) only to the `landmark-assets-2026-11-21` branch. Never commit `.blend` files.

## Rules that always apply

- Never modify `places/AsurasPath.rbxlx` or `outputs/AsurasPath.rbxlx`.
- Never Publish, purchase, or change permissions or experience settings.
- No Meshy, paid, NC, ND or Creator Store assets; CC0/CC-BY/MIT and ElevenLabs SFX are fine.
- Never decimate. Keep upload sub-meshes under 18–20k tris and use 2048 maps.
- Never `git add -A`, force-push, reset, stash or clean.
- Never touch the Codex, Obsidian Vault or Cagebound_Archive folders.
- Never break the lobby, combat, progression, persistent IDs or the Shen barrier.
- Stop and report only if a step fails twice, or needs payment, publishing or a licence decision.

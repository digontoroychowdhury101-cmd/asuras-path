# Mac /loop prompt (paste everything inside the code block into Claude Code, started in ~/Documents/asuras-path)

```
/loop Continuously build the Asura's Path open-world landmarks from the creator's concept art and keep improving the world's visuals, on this Mac (repo ~/Documents/asuras-path, branch ux/onboarding-overhaul). Do not ask me anything; be ambitious; give me a one-line status after each step.

SPEC FILES (read in full every iteration; they are the contract):
- outputs/claude-open-world-2026-11-14/LANDMARK-BUILD-SPEC.md: per-landmark design from the concept images, how to build them (the Vesperhold way), where they go, and the order.
- outputs/claude-open-world-2026-11-14/concepts/*.webp: the creator's concept art. Open and look at the images for the landmark you're working on before modelling, and compare your renders against them.
- outputs/claude-open-world-2026-11-14/NEXT-VISUAL-PASS-PROMPT.md: hard rules, lighting priorities B-E, performance budget, and the section 4 high-poly split/bake import procedure.
- outputs/vesperhold/THIRD_PARTY.md: how Vesperhold's textures were sourced (kevinbadi/blender-skills at commit b2f0f816d320b56ae86d52597a35284e0e6cc929 + Poly Haven CC0 over the blender-mcp socket on 127.0.0.1:9876).

FIRST ITERATION ONLY: make this Mac run the exact same game as the Windows PC.
a. Sync and check tools:
   - git pull --rebase origin ux/onboarding-overhaul. HEAD must contain the commit that added LANDMARK-BUILD-SPEC.md.
   - Check the toolchain: the versions in tools/toolchain.env (Rojo 7.7.1, Luau 0.742, Lune) must be in work/bin/ or on PATH. Install exactly those versions into work/bin/ if any is missing.
   - Blender: /Applications/Blender.app (the same install that built Vesperhold), with the blender-mcp addon. If work/third_party/blender-skills is missing, clone kevinbadi/blender-skills and check out b2f0f816d320b56ae86d52597a35284e0e6cc929.
b. Build and prove:
   - python3 tools/build.py --output work/latest.rbxlx
   - Quit Studio, then launch /Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio -task EditFile -localPlaceFile "$PWD/work/latest.rbxlx". Studio updates itself on launch; it is signed in to the same Roblox account as the PC (user 3148600636), so every uploaded mesh, texture and model ID in the registries loads.
   - Record the file's shasum first.
   - Prove the open place is exactly this build: python3 tools/studio_mcp.py --digest work/latest.rbxlx, then run tools/qa/SourceDigest.luau in Studio (execute_luau, Edit). Script count, bytes and digest must match. If they don't, rebuild and reopen.
c. Play-test the reference views and compare them with outputs/claude-open-world-2026-11-14/captures/win/sky80/ and captures/win/forest79/ (same game, so the same look):
   - Bellwood forest at noon, dusk and night.
   - Vesperhold views 01/02.
   - Check that the clouds, ambient particles, moonlit night and lit lanterns all appear. Report any mismatch.

EACH ITERATION:
1. Sync and read:
   - git pull --rebase origin ux/onboarding-overhaul.
   - Read the top of PROJECT_STATE.md and the spec files above.
   - Build work/latest.rbxlx, open it, prove the digest as in (b), and take "before" captures.
2. Pick the next single step, in this order:
   (B) If not yet done: the golden-hour fix (looking into the low sun goes muddy), as specified in NEXT-VISUAL-PASS-PROMPT.md 2B. Do it once, first.
   (L) Otherwise, the next unfinished step of the current landmark in LANDMARK-BUILD-SPEC.md order:
       1. Bellwood: the Fallen Giant's Face with its walkable eye tunnel, the hidden cliff-enclosed basin, and the Sunken Temple revealed only after walking through the eye.
       2. Amberfall.
       3. Saltreach.
       4. Frostmere.
       5. Ashen Stair.
       6. Vesperhold extension: attach to the EXISTING castle via VesperholdLayout, VesperholdKitRegistry and VesperholdKit, with the nave by P2, the gargoyle bridge on V2/V3 and the graveyard by P3. Never build it as a separate site.
       7. Lore glue: colossus, sealing pillars, waystone shrines at road forks.
       A step is one of these:
       - write/extend the Blender kit script in tools/blender/landmarks/ (or tools/blender/vesperhold/ for the extension), building procedurally the Vesperhold way: welded primitives, real arches, triplanar UVs, auto-split at about 18k, 1 unit = 1 stud, organic forms sculpted then baked;
       - apply the Poly Haven CC0 textures through blender-skills and tone-map them vesp_polyhaven-style to the concept palette;
       - render a contact sheet and compare it to the concept image; iterate until the silhouette and materials match;
       - export GLBs (VESP_EMBED=jpeg, under 20 MB, glb_split.py if needed) and upload with tools/assets/upload_batch.py. Open the cloud window ONLY for uploads (RobloxStudio -task EditPlace -placeId 118614906972571 -universeId 10777041159), set ASURA_CLOUD_STUDIO to that window's studio id, pilot piece first, and record every operation ID and asset ID in a workers/ ledger. Never save that window; close it unsaved.
       - register the pieces (kit_registry.py or VesperholdKitRegistry) and place them through a layout module + SliceDressingService/VesperholdKit, tests first;
       - sculpt the terrain (hidden basin, water, dunes, ice) and set up lights, particles and the region look;
       - take the acceptance captures (for Bellwood: the exact tunnel-exit reveal framing of bellwood_3).
   (C/D/E) Between heavy jobs, or when a landmark step is blocked: the per-region noon/dusk/night fixes, ground material variants and scatter, and colour grading from NEXT-VISUAL-PASS-PROMPT.md.
3. Code changes are tests-first, with the smallest change. Run the touched Lune suites: python3 tools/lune_compat.py tools/<suite>.luau.
4. Verify in the disposable build:
   - Rebuild work/latest.rbxlx and reopen it in Studio. Record the shasum first.
   - Take after captures at player height, plus from beyond 1,500 studs for landmarks, into outputs/claude-open-world-2026-11-14/captures/mac/<landmark-or-item>/, side by side with the concept image.
   - Measure frame time, draw calls and triangles with Studio focused (rbx-perf-profiling / rbx-scene-analysis).
   - Close Studio unsaved and confirm the shasum is unchanged.
   - One heavy Studio or Blender job at a time, holding work/vesperhold-claude/heavy.lock. This Mac has 8 GB: lean bakes, close Blender before opening Studio.
5. Run ASURA_BUILD_OUTPUT=work/verify.rbxlx bash tools/verify_all.sh. It must pass.
6. Commit and push:
   - Commit explicit paths only (src/, tools/, assets/models/*.rbxmx, registries, ledgers, captures, docs). Never git add -A, never commit outputs/mugen-combat-review-2026-11-09/, never commit assets/source/ or .blend files.
   - When a landmark kit is finished, push its raw GLBs, maps and renders (each under 100 MB) to the branch landmark-assets-2026-11-21 so the PC can rebuild it.
   - Append at most 60 words tagged "(Mac)" to the top of PROJECT_STATE.md: what was done, and what's next.
   - git push origin ux/onboarding-overhaul, and confirm git status is clean apart from that review folder.

NEVER:
- Never edit or save the cloud place (it stays M1).
- Never modify places/AsurasPath.rbxlx or outputs/AsurasPath.rbxlx.
- Never use Meshy or any paid generation credits, Creator Store free models, or NC/ND/paid assets. Use only procedural-in-repo, CC0 (Poly Haven) and the creator's concept art as reference.
- Never publish, purchase, or change settings or permissions.
- Never break the lobby, lobby lighting, combat, progression, persistent IDs or the single Shen barrier.
- Always use the task library and modern Luau.

STOP AND REPORT only if:
- a step fails twice,
- an action needs publishing or payment,
- a source licence is unclear, or
- every landmark in LANDMARK-BUILD-SPEC.md is built and no visible defect remains.
```

# Computer B handoff — 23 October 2026

Latest work is on **`ux/onboarding-overhaul`** in `digontoroychowdhury101-cmd/asuras-path`.

With computer B's checkout clean (commit its local work first if needed):

```text
git switch ux/onboarding-overhaul
git pull --rebase origin ux/onboarding-overhaul
```

Open **`places/AsurasPath.rbxlx`** in Roblox Studio. `outputs/AsurasPath.rbxlx` is the identical canonical build. Use the XML place rather than any older binary `.rbxl`. Rebuild with `python tools/build.py` on Windows, or `python3 tools/build.py` on macOS, if source changes are needed. No re-import or new upload is required: normalized Rojo libraries and uploaded asset IDs are included.

Current build: 3,223,393 bytes; SHA-256 `3b6de54795b27df3a06e14e95dac23f3db217aa212fccfdde7fe768b95ed1bac`; SourceDigest **1045496687**. Do not save a Play-session data model over the source build.

Included: all source changes, both place files, imported mesh library, upload manifest/provenance, original Blender detail kit and GLB, Vista rock maps needed by its generator, QA harnesses/results, prior art-pass before/after images and final phone/tablet screenshots. Editable detail files are under `assets/build/sanctuary_detail/`. Existing uploaded architecture, landscape, statue/tree and gameplay remain in the project.

Optional machine-specific Rojo 7.7.1 warning fix: follow `tools/qa/rojo_preloader_fix/README.md` only if that plugin version still reports asset `203785492`. Computer A's installed plugin is outside the checkout and cannot be installed on B by pulling Git.

Verified: full local verifier 14/14; movement 50; device-layout regression 89; final Studio bounds audits on Galaxy A06, iPhone 17 Pro, iPad Pro M5 and Xbox. Final audit JSON files are under `qa/`; physical device/controller/FPS certification is outstanding.

Deferred at the user's request: finer cliff/foliage refinement, foreground and physical-device performance measurement, successful two-client duel, public-server/asset-permission checks. Local multiplayer partially booted both clients but did not complete match allocation. The `tools/qa/LobbyMultiplayer.*` harnesses are preserved and are not mapped into the shipping place. No experience has been published.

See `ART_FINISH_REPORT.md` for evidence and precise limits. Earlier art-pass reports describe historical measurements; this handoff identifies the current build.

# Shared Save to Roblox checkpoint — 16 November 2026

**Completed at the creator's explicit request.** The creator asked whether the
Mac prompt used the Save to Roblox version, then asked Codex to migrate the
verified build into it. This supersedes the earlier uploads-only restriction for
this migration. The private cloud place now contains the open-world checkpoint.

## Open this on both computers

- Experience: **Asura's Path — Development**
- Universe: **10777041159**
- Existing root place: **118614906972571**
- Latest explicit save reported by Studio MCP: **version 6**.
- Current runtime source: **`32d448e`**, including the Mac far-tree reconciliation.
- Initial migration source: `358e24fa02865c2579e565697d62c8699d017a61`, delivered
  as the dated checkpoint in Git commit `fbb5894`.
- Initial local reference: `places/checkpoints/AsurasPath_OpenWorld_2026-11-16.rbxlx`.
  This dated file predates the one-module Mac update; do not overwrite current
  cloud source with it.
- Open through **Studio > Experiences / Open from Roblox**, signed into the
  creator account or an account with edit access. Select the Development game
  and verify the IDs above with Studio MCP. Other similarly named recent entries
  and local files are separate copies.

The connected Studio must report `persistedToCloud=true`. Run
`tools/qa/SourceDigest.luau` in Edit mode and expect:

```text
scripts 275 bytes 3151007 digest 1357214079
```

The initial cold reopen verified **275 / 3149701 / 1516687798** from cloud version
4; the initial final save returned version **5**. After reconciling the Mac Git
commits, a guarded single-module update brought the cloud to the current
fingerprint above; `save_place` returned `Saved`, location `TeamCreate`, version
**6**. The already-open Edit DataModel still reports its load version 4. Do not
use a displayed date or session-load version alone to identify current source.

## Mac source reconciliation after migration

The Mac pushed `de50f6f` and `32d448e` during the migration. Both commits and their
worker notes/captures were preserved. The only runtime-source difference from
the migrated checkpoint was `src/shared/SliceDressing.luau`: the six far-tree
specifications now use the real pack manifest and far-tree density is 0.4.

Focused local regression passed **1013 assertions / 0 failures**, the module
compiled, and a temporary build produced the current fingerprint above. Only
`ReplicatedStorage.AsurasPath.Shared.SliceDressing` was updated in cloud Edit
mode, guarded by the exact previous source, target IDs and Edit state. The
complete cloud script fingerprint then matched the temporary build; the lobby,
asset library and material fingerprints below stayed unchanged. This update was
saved as **version 6**. No newer terrain/Actor work from the Mac was integrated.
The smoke check below was on the initial migrated checkpoint; no new Play or
performance acceptance is claimed for this one-module follow-up.

## Transfer and preservation evidence

1. Before transfer, the existing cloud place was Edit mode / version 2 with the
   original baseline: **286 scripts, 2859366 bytes, digest 462022588**.
2. Studio's **Download a Copy** saved a binary backup at
   `work/cloud-migration-2026-11-16/CLOUD_BEFORE_v2.rbxl` on Windows (ignored by Git).
   Size **2784009 bytes**, SHA-256
   `6be2ccc60e0305da5e24ccf34197d1eb944e591cd26f62f6be9a8241d0d713f9`.
   The pre-overworld place files in Git are also preserved. Roblox version 2 is
   the prior cloud checkpoint; do not restore it over new work automatically.
3. A working copy of the checksummed dated build was opened locally. Its full-file
   SHA-256 matched
   `d9be83ac03d7c1ceb61ab99a60601271a68c222401847d478ffbcbacdc644cf6`.
4. **File > Save to Roblox As** selected the existing Development experience and
   existing root place, then **Overwrite**. No new experience/place was created.
   Studio reported **Successfully saved**. File > Publish was not invoked.
5. The cloud place was reopened independently. Place/universe IDs, cloud
   persistence, all script counts/bytes/digest and the following fingerprints
   matched the new local build:

   | Preserved collection | Instances | Property digest before / after |
   |---|---:|---:|
   | ServerStorage.AsuraLobbyKit | 129 | 308331669 |
   | ServerStorage.AsuraAssets | 1443 | 442941466 |
   | MaterialService | 13 | 306913035 |

   These fingerprints cover hierarchy/class, selected geometry/material/texture
   properties and attributes; they are not a full visual acceptance test.
6. A final Studio MCP save reported version **5**. An authenticated universe read
   confirmed **visibility PRIVATE**, the same owner and the same root place.

## Single-client Studio smoke check

The saved cloud place was tested in Play with `Config.Backend.StudioLiveData=false`
(mock persistence). Server and client reached ready. A player character spawned
at the shrine; `Workspace.Sanctuary` and `Workspace.Map_Overworld` were present.
The shrine, controls panel, HUD and compass were visible. The overworld terrain
generator started in the background. Play was stopped; Edit script and asset
fingerprints still matched afterward. No temporary probe script was inserted.

Existing/open findings remain: startup Heartbeat budget warning, the pre-existing
asset-type mismatch for 203785492, and EditableImage unavailable under this
experience's current setting. WorldMapController already catches that API failure
and has a Frame-grid fallback; its full in-world behavior was not accepted here.
No security/privacy settings were changed. Full traversal, terrain completion,
real-mesh imports, combat acceptance, multiplayer and device profiling remain open.

Studio logged transient 429 responses during internal script-asset application;
the full reopened script fingerprint subsequently matched. The first Team Create
reopen also failed with "Server did not start [0]"; one retry connected and allowed
the verification and smoke check. These are recorded rather than hidden by the
save dialog's success message.

## Continue without losing the shared state

Use this cloud place for the shared integrated checkpoint. Keep Git source and
asset registries current and coordinate one writer at a time. Build/test candidate
changes in a separate local working copy, then deliberately integrate verified
milestones into this same cloud place and record the save version. Team Create
Edit changes persist; never run a temporary sync-and-restore workflow there or
restore digest 462022588 after a test. Preserve the lobby, combat and progression.

Saving to Roblox updates the shared Studio version. It does not release the game
to players. The original open-world brief and its unfinished acceptance criteria
still apply. The asset branch still carries raw mesh/audio sources; this migration
did not resolve the lantern upload or invent any asset IDs.

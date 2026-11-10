# Grandmaster Shen clipping repair: Windows pass (2026-11-09 to 11-11)

Boss 01 only. Nothing was published or uploaded, and no asset ID was created. Bosses 02-06 were not touched. The
validator thresholds, the dense measure, the between-frame and fade-in checks, `POP_LIMIT`, the GLB bones and skin weights,
the exporter and the cloth system are unchanged.

Sections follow WINDOWS_START.md: static review, local regression, Studio integration, multiplayer and device profiling
are reported separately. Every number below comes from a file in `results/` or a log named next to it.

## 1. Setup and reproduction gate

- Windows 11, Python 3.15.0 (`py`), NumPy 2.5.3 (the handoff's version, kept for like-for-like debugging), SciPy 1.18.1,
  Blender 5.2.2, Luau 0.742 (downloaded for `tools/verify_all.sh`). Bakes ran single-threaded (OMP/OPENBLAS/MKL = 1).
- Assets restored from branch `shen-assets-2026-11-09` per ARCHIVE.md; `work/shen_import` was not rebuilt.
- Gate: `scripts/repro_check.py` printed REPRODUCED for P1_GuardHit (largest difference 5.88e-15) and P1_Guandao_L1
  (1.22e-13), 98 inputs matched, validator clean. Work started only after that.

## 2. What changed

**Bake library** (`tools/animation/opening_cast/shen_lib.py`). Per-clip opt-ins on `Clip`, default off, so no other clip's
bake changes:
- `hold_start` / `hold_end` / `hold_entry`: swivel pins a hand's grip state on the first/last frame (and through the fade in)
  to Idle's, so the game's fades blend like with like.
- `blow_envelope`: wrist_yield eases a blow frame's haft tilt over its neighbours as an envelope (P1 FlowingJian's 0.58 blade pop).
- `run_recheck` + `recheck_spike` (`recheck_runs`, `RECHECK_SPIKE_COST`): swivel's torso recheck walks each run of frames past
  the wall as one path, and may not whip a hand round for one frame (FlowingJian's left wrist 173 deg at f84-85, and a 45 deg
  single-frame grip change at f88).
- `legs_guard`: held_clash also weighs the weapon inside his legs on every weapon sample (built for P2 Skyfall; see section 9).

**Clip keys** (`tools/animation/opening_cast/shen_clips.py`): P1 FlowingJian's second-cut wind-up faces the cut; P2 RendingArc's
overhead finish slides the rear fist toward the butt; P2 Skyfall carries the follow-through's fist; P2 RunForward nudges the fist
0.08 forward; P2 WalkBackward and TurnRight carry the guard in his chest's frame; P2 Death keys the stagger in his chest's frame and
the kneel's fist 0.15 to his right (WINDOWS_START option B); the Idle-hold pins per clip (`IDLE_HOLD`, `ends`, `entry`, L3's end
grip, Skyfall's end grip, DeathblowVictim's entry). Each change carries a dated comment with its measured reason.

**Game code** (`src/shared/BossRigs.luau`), found by the Studio check in section 5: `BossRigs.apply` skipped a helper bone that an
earlier form had built, so after the phase transition Shen's glaive joint stayed on phase 1's pivot. Every phase 2 clip and weapon
mesh is made about phase 2's point, so in game the whole weapon sat a constant 0.167 rig units (about 0.22 studs) off his grip in
every phase 2 clip, including the clips already published. `apply` now re-points the existing helper's joint to the current form's
point (its part, joint and welds stay). New regression test `tools/test_boss_rigs.luau` (runs in `verify_all.sh` through
`lune_compat.py --all`): 68 checks pass on the fix; on the pre-fix module it fails exactly the 4 phase-2 glaive checks.

**Exported clips**: 39 re-exported (`assets/animations/opening_cast/shen/`, 15 phase 1 + 24 phase 2) and the manifest; the other
25 clip files are unchanged (`results/jsondiff_pre4_final.txt`: 0.000 moved). The game plays published asset IDs, so the repaired
clips reach the game only once they are published, which this pass did not do. The rig fix is in the built place now, and it also
corrects the glaive for the phase 2 clips already published (they were made about phase 2's point too).

**Build** (`tools/build.py`): ElementTree wrote the place in text mode, which is CRLF on Windows, so a Windows build turned every
line of the committed (LF) place into a change (343k lines). It now writes through a binary handle, LF on every OS; this pass's
place diff is the 15 lines of BossRigs.

## 3. Static review (the repo's validator on the final bakes)

- `revalidate.py` on all 64 final bakes (`work/shen_repair/baked_set2`): **0 problems** (`results/reval_final2.txt`). Deepest arm in
  his torso: on frames 0.169 (P2 Skyfall left), between frames 0.179 (P1 Guandao_Running left, f3), fading in 0.162 (P2 Death).
- Before/after for the 23 clips whose numbers changed (`results/revaltable_dp11_final.md`, before = the dp11 bakes handed over):
  P1 FlowingJian 0.200/0.228 with a blade pop and a flipped wrist -> 0.167/0.177, clean; P2 CrimsonEmbrace 0.351 -> 0.157;
  P2 Death 0.231 -> 0.158; P2 DeathblowVictim 0.205 (0.257 fading in) -> 0.160 (0.039); P2 RendingArc between frames 0.189 -> 0.167;
  P1 Guandao_Running 0.188 between / 0.214 fading in -> 0.179 / 0.154; P1 PrayerBeads 0.184 -> 0.175; P2 Feint, PostureBreak,
  Guandao_Running fade-in and between flags all cleared.
- Weapon inside his legs (validator records, does not limit; `results/legsall_final.txt`): unchanged or lower everywhere except
  P2 Skyfall, where the haft sits 0.121 in his right thigh at f49 after vs 0.122 at f52 before (dense, every weapon sample). See 9.

## 4. Local regression

- **Fades, as the game plays them** (BossAnimations.luau: planned attacks fade in over 0.1 s, other plays and stops 0.15 s, gaits
  0.2 s): `fadecheck2.py` (0.15 s) worst 0.179 (P2 HitLightFront in), `results/fade2_final2.txt`; `fadecheck3.py` at each clip's
  own fade times worst 0.179 (`results/fade3_final2.txt`). fadecheck3 also prints every clip at all three times; cells the game never
  uses exceed 0.18 on 7 clips, all non-gaits at 0.2 s or reactions at 0.1 s (worst P2 DeathblowVictim 0.278 at a 0.2 s fade in; the
  game fades it in over 0.1 or 0.15 s: 0.092 / 0.114). The review renders' own fade (0.2 s smoothstep) puts P1 Guandao_Running's
  left arm 0.196 in at the start of its video; the game fades that attack in over 0.1 or 0.15 s (0.145 / 0.169).
- **Pops** (`popjson.py` vs `bakes/pre4_export`, `results/popjson_final2.txt`): frames with a >= 0.5 out-and-back 81 -> 51.
  **Face pops** (`facepop.py`): 0 clips with a roll pop > 0.3 (`results/facepop_final2.txt`).
- **Cloth** (rendered mesh, `measure_set2` before/after, `results/msetcmp_pre4L_finL.txt`): cloth pairs >= 0.05 deep 135 -> 117,
  sum(share x depth) 1.462 -> 1.333, deepest 0.200 -> 0.166. Per pair (`results/cloth_changes.txt`): 61 shallower or rarer, 34 deeper
  or more frequent; the largest new ones are P1 Guandao_Running RobeLeft in LowerTorso 0.125 (6% of frames), P2 Guandao_Heavy
  RobeBack in LeftLowerLeg 0.119 (4%), P2 Guandao_L2 RibbonLeft in LeftLowerArm 0.118 (6%), P2 Skyfall RobeFront in LeftLowerArm
  0.046 -> 0.110. These are listed as open in section 8. Arm-in-weapon 137 -> 129 pairs, weapon-in-arm 27 -> 26.
  "Other" pairs 148 -> 127, but their deepest rose 0.308 -> 0.341 (P2 Flourish, the glaive in his upper torso for one shot frame
  as the review fades in; none at the game's 0.1 s fade, section 8 item 4).
- `py tools/test_cloth_sim.py`: P1 ok (rest drift 1.143, sprint trail 0.17), P2 ok (1.187, 0.39).
- `bash tools/verify_all.sh` (Git Bash, `python3` shimmed to `py`): all 14 stages pass, exit 0, "Shen integration: ok"
  (`results/verify_all_final2.log`; the Shen audio manifest it needs was generated with `py tools/assets/build_shen_audio.py`, which
  writes only the gitignored `assets/build/shen_audio/`).
- After the 11-11 follow-up (review.py's output path, the new probes): `verify_all.sh` again all 14 stages pass, exit 0, now with
  `test_boss_rigs.luau` 68 passed (`results/verify_all_followup.log`); `test_cloth_sim.py` ok with the same numbers.

## 5. Visual review (renders watched)

X-ray before/after videos of every re-exported clip, front view, arms through the upper torso, in
`outputs/grandmaster-shen-2026-11-05/repair/arms_w10_f{1,2}_<clip>_uppertorso_before_after.mp4` (39 clips) plus
`arms_w10_f2_GuandaoSkyfall_uppertorso_side_before_after.mp4`. Each was made from the final bake (checked: every video is newer
than its bake and its frame JSON) and watched, with contact sheets of the worst stretches (local only, `work/shen_repair/sheets/`).

What the renders show, beside the numbers (`results/xray_mesh_table.md`, the rendered mesh's deepest point inside the upper torso):
- Clearly better on screen: P2 RendingArc 0.385 -> 0.200, P2 Feint 0.277 -> 0.183, P2 Guandao_L2 0.251 -> 0.182, P2 Guandao_Heavy
  0.237 -> 0.173, P2 Guandao_Running 0.242 -> 0.169, P2 RunForward 0.270 -> 0.174, P2 Skyfall 0.219 -> 0.176, P2 BloodWave
  0.204 -> 0.172, P2 CrimsonEmbrace 0.186 -> 0.166, P1 FlowingJian 0.188 -> 0.144 (blade pop and wrist flip gone).
- Rendered mesh still past 0.18 (the validator's skin samples pass on all of them; open, section 8; what each measure counts:
  `results/xray_why.md`): P2 Death 0.252 (unchanged),
  P2 DeathblowVictim 0.275 (0.285), P2 RendingArc 0.200, P2 PhantomDrift 0.186, P2 Transform 0.183 (unchanged), P2 Feint 0.183,
  P2 Guandao_L1 0.182 (0.180), P2 Guandao_L2 0.182, P2 HitLightFront 0.182 (0.184).
- Rose: P2 Guandao_L3 0.147 -> 0.180 (f25-29), and by 0.006-0.009 P1 Feint, P1 Flourish, P1 Guandao_L3, P1 PrayerBeads,
  P2 Flourish, P2 Strike.

## 6. Studio integration (local playback, no publishing)

Full numbers and method: `results/studio_playback.txt`. In a Play session of `places/AsurasPath.rbxlx`, the real boss spawned by
the game, the exported KeyframeSequences loaded locally from Studio's content folder and played on a clone of the live rig, paused
at every exported frame and compared with the solver's frames:

- Phase 1, 16 clips (15 repaired + Idle): every part within 0.0127 rig units (Idle, which the exporter reduced to 22 keyframes);
  repaired clips 0.0016-0.0117.
- Phase 2 before the rig fix, 24 clips: body and hands within 0.0103, but the glaive 0.10-0.33 off (the stale phase 1 pivot).
- Phase 2 after the fix (fresh Play session, the game's own phase transition, live pivot read back as 1.090, -0.390, -0.350):
  glaive worst 0.0173 (WalkBackward, 20 of 73 frames kept as keyframes), every other part 0.0104.
- Stills (Studio screen captures, viewed, not saved as files): P1 FlowingJian t=3.05 and HesitantMoon t=1.40 textured, weapon in
  both hands, nothing through his chest at those poses. P2 Strike t=0.22 with the fix: pose and glaive placement as the solver, but
  the phase 2 skin rendered untextured: every SurfaceAppearance map (phase 1's too) failed to fetch in this Studio session
  (ContentProvider AssetFetchStatus.Failure within 0.2 s). That is this machine's Studio session, not the clips or the rig.
- P2 Skyfall (measured last, same session): within 0.0109 (right hand, f78), glaive 0.0078; the live boss's and the clone's glaive
  pivot read back as phase 2's point.

## 7. Multiplayer and device profiling

- Multiplayer: not run. No two-client session was started in this pass, so nothing here shows two clients seeing the same
  phase 2 glaive. The fix is server-side state (the joint attachment replicates); a two-client check is still owed. Starting one
  needs Studio's Test tab (a local server with clients), which the Studio connection used here cannot start (it has single-player
  Play only). Desktop control of Studio was requested on 11-11 for this and declined, so it was not retried.
- Device profiling: not run; no phone, tablet or console hardware here. Nothing in this pass measures frame time or memory.

## 8. Open defects (not accepted, still to fix)

1. Rendered-mesh arm depth past 0.18 in nine phase 2 clips (section 5), worst P2 DeathblowVictim 0.275 and P2 Death 0.252,
   although the validator's dense skin samples are under its limit on all of them. Traced on 11-11 (`results/xray_why.md`,
   `scripts/xray_why.py`), the two measures count different skin:
   - Seven clips (RendingArc, PhantomDrift, Transform, Feint, L1, L2, HitLightFront): the depth past 0.18 is upper-arm skin at the
     shoulder seam that sat within 0.05 of his chest at rest. The validator leaves that skin out (`_torso_free`); the x-ray counts it.
   - P2 Death 0.252: only in the review shot's fade from his last pose back to Idle. The game holds Death's last frame after KO
     (`BossAnimations.luau:226`), so that fade never plays. Inside the clip: 0.181, the same shoulder-seam skin.
   - P2 DeathblowVictim 0.275: the review's 0.2 s fade in (0.114 at the game's 0.15 s). Inside the clip, at clip f18 (shot f36), the
     top of his left shoulder is 0.219 in; 0.188 of that is skin the validator would count, but it falls between its ~510
     left-upper-arm samples.
   In normal renders of the two worst in-clip frames (RendingArc f58, DeathblowVictim f36), nothing comes through the front of his chest.
   The seam depth is still there in all nine, so this item stays open.
2. P2 Guandao_L3 rose 0.147 -> 0.180 in the rendered mesh (f25-29): left upper arm at the shoulder seam (0.180), and 0.173 for skin
   the validator counts, which is past the 0.17 wall but under its 0.18 flag (`results/xray_why.md`).
3. Cloth: the 34 deeper or more frequent cloth pairs in `results/cloth_changes.txt`, led by P1 Guandao_Running's RobeLeft in his
   LowerTorso (0.125) and P2 Skyfall's RobeFront in the left forearm (0.110).
4. The glaive through his upper torso for a frame as the review shot fades in from Idle (shot f22): P2 Flourish 0.308 -> 0.341,
   P2 Guandao_L2 0.298 -> 0.281 (P2 RunForward's 0.274 is gone). At the game's own fades (11-11, `results/fadeweapon_final.txt`: every
   weapon sample against the solver's torso solids, fading in from the clip's first frame) both are 0.000 at 0.1 s. That is the fade the
   game gives them, since both have contact times (`BossAnimations.luau:72`). At 0.15 s: Flourish 0.065, L2 0.012; at 0.2 s: Flourish 0.187.
   No other clip passes 0.05 at any game fade time; P2 Death's 0.079 is its fade-out, which never plays. On the rendered mesh
   (`scripts/shots_gamefade.py` + mesh_clash.py, every frame, `results/mset_gamefade.json`): the 0.2 s shots reproduce 0.341 and
   0.281 exactly, and with the fade at 0.1 s neither clip has any glaive in his torso. At 0.15 s Flourish is 0.361 and L2 0.079, but the
   game never gives these clips 0.15 s: Flourish is cued as a BossSwing with an impact time (`BossAttackService.luau:49`), so it gets the
   0.1 s fade. Left: in L2 at 0.1 s, his chest surface is 0.071 inside the glaive at clip f4 (0.064 before this pass). Not checked: fades
   from poses other than Idle, and a late start when latency eats into the impact time.
5. The review renders' 0.2 s fade puts P1 Guandao_Running's left arm 0.196 in at the start of its video (the game's own fades: 0.145
   and 0.169).
6. P2 Skyfall's haft in his right thigh after the landing (section 9).
7. Multiplayer and device checks not done (section 7).

## 9. P2 Guandao Skyfall: the weapon in his thigh

Open. The exported Skyfall is the bake that passes the validator (R 0.160, L 0.169, no problems), and its arms are much better on
screen (rendered mesh 0.219 -> 0.176). But after the landing the haft, ahead of his right fist, runs into his right thigh:

- Dense measure over every weapon sample (`scripts/legsall.py`): 0.121 at f49 now, 0.122 at f52 in the handed-over bake, so the
  depth is not new. The validator's own `weapon_in_legs` thins the weapon to every 6th sample and reads 0.000 for both.
- Rendered mesh (`results/mset_finL_*.json`): weapon in RightUpperLeg 0.162 at one measured frame (shot f68); the before shots
  showed only the thigh 0.052 inside the wood (shot f72), not the wood in the thigh.

The attempt to fix it is in the code but switched off: `Clip.legs_guard` makes held_clash weigh the weapon inside his legs on every
weapon sample. With it, replayed from the same controls, every stage keeps the legs clear (`LEGS ... none`), but the right arm ends
0.18-0.20 in his chest over f45-55 and the joint polish could not take it back under the wall in two runs (`legpol_1/2.log`: the
window f45-55 not kept three ways; the validator would flag "right arm 0.18 inside his torso"), and the full bake with it showed a
0.57 blade pop at f46 after its pre-polish stages. A third polish run (`ctp_lg.log`) was still solving when this was committed.
No clip opts in, so the code reproduces the exported Skyfall exactly (a full bake from code, `baked_rpS`, matches the export with
a largest difference of 0.0).

Next step for it: the guard has to be weighed together with the torso in the polish window, not only in the stages before it
(the polish brings the arm back out of the chest by moving the fist, and the haft follows the fist into the thigh).

## 10. Files

- `scripts/`: every probe and tool written in this pass (each starts with a usage line). New ones for the checks above:
  `studio_expected.py` (the solver frames as a model file Studio can load), `studio_preview.luau` (the Studio harness),
  `revaltable.py`, `jsondiff.py`, `legsall.py`, `fadecheck3.py`, `measure_set2.py`, `render_cmp.py`, `sheet.py`, `xray_why.py`, `fadeweapon.py`, `shots_gamefade.py`.
- `results/`: the outputs cited above.
- Bakes: `work/shen_repair/baked_set2` (local, gitignored) is the final set the exports came from.

## 11. Housekeeping

- Studio: the place was never saved from Studio. `HttpService.HttpEnabled`, switched on for an early version of the harness, was
  set back to false in Edit mode. The temporary folder `content\shenpreview` in Studio's install folder (clip copies and the
  harness) is deleted at the end of the pass.
- Stray render folders `C:\work\shen_repair\rv5` were removed; the empty `C:\work` above them is left for you to delete (a safety
  check stops me removing a top-level folder). Cause: review.py passed its relative output folder to Blender, which resolved it
  against the drive root. review.py now makes the folder absolute (11-11).
- Untracked `outputs/hero-grand-soul-review-2026-11-09/` and `outputs/mugen-combat-review-2026-11-09/` belong to another task and
  were left uncommitted on purpose, so `git status` is not fully clean.

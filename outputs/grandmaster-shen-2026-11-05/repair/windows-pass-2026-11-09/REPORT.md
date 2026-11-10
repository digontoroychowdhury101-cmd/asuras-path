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
- **Cloth and the glaive on the rendered mesh** (`mesh_clash.py` on all 64 review shots; before = the export this pass started
  from, after = the final bakes). First measured every other frame (`results/msetcmp_pre4L_finL.txt`, `results/cloth_changes.txt`);
  on 11-11 again at every frame, because that pass missed peaks on odd frames. The numbers below are the every-frame ones
  (`results/msetcmp_pre4L1_finL1.txt`, `results/cloth_changes_every.txt`, `results/rest_changes_every.txt`, `scripts/clothchanges.py`).
  The cloth bake is deterministic: the P1 clips this pass did not touch measure identically before and after.
  - Robes and ribbons: pairs >= 0.05 deep 168 -> 145, sum(share x depth) 1.488 -> 1.387, deepest 0.200 -> 0.166. Per pair, 61
    shallower or rarer and 34 deeper or more frequent. The largest rises: P1 Guandao_Running RobeLeft in LowerTorso 0.071 -> 0.125,
    P2 Guandao_Heavy RobeRight in his right thigh 0.035 -> 0.124 and RobeBack in his left shin 0 -> 0.119 (2% of frames each),
    P2 Guandao_L2 RibbonLeft in the left forearm 0.053 -> 0.118, P1 HesitantMoon RobeFront in LowerTorso 0.040 -> 0.105. P2 Skyfall's
    RobeFront in the left forearm, which the every-other-frame pass read as 0.046 -> 0.110, is 0.113 -> 0.110 at every frame, so it
    is not new.
  - Sleeve, beard, beads and hair (simulated like the robes, but `msetcmp.py` files them under "other"): 119 -> 108 pairs, sum
    1.949 -> 1.930, deepest 0.201 both. Per pair 41 shallower, 43 deeper; 28 of the deeper are 0.10 or more after, led by P2
    Guandao_L2 LeftSleeve in the left upper arm 0.151 -> 0.196, P1 FlowingJian Beads in LowerTorso 0.094 -> 0.188, P2 Death Beard
    in his head 0.066 -> 0.182, P2 Guandao_Running LeftSleeve in the left upper arm 0.118 -> 0.180 and P2 HitLightFront LeftSleeve in
    the left forearm 0.034 -> 0.118. All five peak inside the clip, not in the review's fades.
  - The glaive in him: 53 -> 49 pairs, sum 0.286 -> 0.255, deepest 0.352 -> 0.341 (before: P2 RunForward in his upper torso at
    shot f21, an odd frame; after: P2 Flourish, section 8 item 4). In his arms alone 35 -> 38 pairs, sum 0.218 -> 0.223, deepest
    0.162 -> 0.145. 15 pairs deeper, led by P2 Skyfall in his right thigh 0 -> 0.162 (section 9), then P1 Guandao_L3 and
    Guandao_Running in the right forearm 0.127 -> 0.142 and 0.113 -> 0.140 (as the review fades in).
  - His arms, hands and torso in the glaive: 204 -> 188 pairs, sum 3.345 -> 3.211, deepest 0.083 both (fingers round the haft).
  The rises are open (section 8 item 3).
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
  What the single-player session does show: `BossRigs.apply` runs only on the server (`BossSkin.luau:160`; the client only reads
  `Rigs.rest`), and the harness ran in the play session's client datamodel, where the live boss's glaive pivot read back as phase 2's
  point after the server's own transition (section 6). So the re-pointed joint reached one client. Two clients at once, and a player
  who joins after the transition, are untested.
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
3. Cloth, rendered mesh at every frame (section 4): the 34 robe and ribbon pairs that went deeper or more frequent
   (`results/cloth_changes_every.txt`), led by P1 Guandao_Running RobeLeft in LowerTorso 0.125, P2 Guandao_Heavy RobeRight in the
   right thigh 0.124 and RobeBack in the left shin 0.119, P2 Guandao_L2 RibbonLeft in the left forearm 0.118; and the 43 sleeve,
   beard, beads and hair pairs that did (`results/rest_changes_every.txt`), led by P2 Guandao_L2 LeftSleeve in the left upper arm
   0.196, P1 FlowingJian Beads in LowerTorso 0.188, P2 Death Beard in his head 0.182, P2 Guandao_Running LeftSleeve 0.180. The
   every-other-frame list's P2 Skyfall RobeFront in the left forearm was a sampling miss (0.113 before, at every frame).
4. The glaive through his upper torso for a frame as the review shot fades in from Idle (shot f22): P2 Flourish 0.308 -> 0.341,
   P2 Guandao_L2 0.298 -> 0.281 (P2 RunForward's, 0.352 at shot f21 at every frame, is gone). At the game's own fades (11-11, `results/fadeweapon_final.txt`: every
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

- Dense measure over every weapon sample (`scripts/legsall.py`): 0.121 at f49 now, 0.122 at f52 in the handed-over bake, so by
  the solver's leg solids the depth is not new. The validator's own `weapon_in_legs` thins the weapon to every 6th sample and reads
  0.000 for both.
- Rendered mesh (`results/mset_finL_*.json`): weapon in RightUpperLeg 0.162 at one measured frame (shot f68); the before shots
  showed only the thigh 0.052 inside the wood (shot f72), not the wood in the thigh. The x-ray of the review shots, every frame
  (review.py, glaive vertices inside the right thigh, 11-11): exported 234 vertices 0.183 deep at shot f67 (clip f49) and 184 at
  0.175 at f68; handed-over 1 vertex 0.034 at f78 and f80. So on the mesh the game draws, the wood in his thigh came with this pass.

The attempt to fix it is in the code but switched off: `Clip.legs_guard` makes held_clash weigh the weapon inside his legs on every
weapon sample. With it, replayed from the same controls, every stage keeps the legs clear (`LEGS ... none`), but the right arm ends
0.18-0.20 in his chest over f45-55 and the joint polish could not take it back under the wall in two runs (`legpol_1/2.log`: the
window f45-55 not kept three ways; the validator would flag "right arm 0.18 inside his torso"), and the full bake with it showed a
0.57 blade pop at f46 after its pre-polish stages. A third polish run (`ctp_lg.log`: the stages after clear_torso replayed with the
guard on, then the joint polish; `scripts/ctmoves.py` restores the clip state cached in `ctcache_sky_lg.pkl`, which has
`legs_guard: True`) failed the same way on 11-11. Its first window (f0-6) was kept. In the main window (f43-71) the
right arm entered 0.195 deep; after 95 SLSQP iterations (87 min) it was still 0.191, its right-hand reach worse, the solve
infeasible ("Positive directional derivative for linesearch"), and the window was not kept. The elbows-only retry stopped after
13 iterations ("Inequality constraints incompatible") with the arm deeper, 0.208, and was not kept either. The seeded retry
(from clear_torso's moves) reached 0.182 in 20 iterations but was infeasible, with the weapon clash and both grips worse, and was
not kept. Its final reading, run to the end (REST): weapon in his legs none, but right arm 0.195 and left arm 0.184 inside his
torso, right 0.193 between f58 and f59, so the validator would flag three problems (right arm 0.20, right arm 0.19 between
f58 and f59, left arm 0.18). A full bake from the start with the guard on (`ttlgS_P2_GuandaoSkyfall.log`, 11081 s) ended the
same way: right 0.195, left 0.184, the same three problems.
No clip opts in, so the code reproduces the exported Skyfall exactly (a full bake from code, `baked_rpS`, matches the export with
a largest difference of 0.0).

Next step for it: the polish already weighs the guard together with the torso. With `legs_guard` on, its held_clash constraint
counts the weapon in his legs (`shen_lib.py`, `_polish_window` measure), and with that it still finds no pose that clears both.
Within the polish's controls (fist point, haft tilt about the fist, elbow swings), the fist positions that take the right arm out of
his chest put the haft in his thigh. The way out has to be in Skyfall's own keys after the landing (where the fist and the haft are
carried), then a full bake.

Keys, 11-11 (`results/skyfall_lift_screen.txt`, `scripts/thighdir.py`). On the exported bake the wood is in his right thigh on two
frames only, f49 0.121 and f50 0.041. The deepest point is 0.21 ahead of the fist along the haft, and the way out of the thigh is
almost straight up (+0.94 of the outward direction). So the screen lifts the fist for a moment after the contact (a second carry,
eased in from 1.52 s, full over f48-50, gone by f53; the contact keeps its key). It ran four DEV overlays of shen_clips.py from the
start of the bake to clear_free_arm, then the later stages without the polish:
- lift 0.15: guard off, wood 0.142 in his thigh, right arm 0.216; guard on, legs clear, right arm 0.235.
- lift 0.25: guard off, legs clear, right arm 0.200; guard on, legs clear, right arm 0.184. The exported bake's own polish window
  (f45-55) also started at 0.184, and its seeded retry took it to 0.160 (`ttrpS_P2_GuandaoSkyfall.log`).
More lift left his arm shallower in both modes.

Full bakes, 11-11 (runall.py with the polish, DEV overlays; `results/skyfall_lift_full.txt`, `scripts/liftsum.py`). Lifts 0.25, 0.35
and 0.45, guard on and off, two with a gentler ease (in over 1.50-1.60 s, out over 1.68-1.80 s), and three that also carry the fist
outward or forward during the lift (0.15 right and 0.1 forward; 0.25 right; 0.2 forward) to keep the arm off his chest:
- Legs: with the guard on and the gentler ease the lift keeps them clear (0.35: clear on every frame f40-70; 0.25: 0.019 at most).
  With the standard ease the fist comes back down into the thigh as the lift eases out and he sinks: 0.35 with the guard has the
  wood 0.183 in his right thigh at f53. Without the guard: 0.25 left 0.079 at f62, 0.35 left 0.085 at f57.
- Arms: the lift folds his right arm into his chest while the fist is up. The bakes' per-frame readings have it at 0.17-0.19 around
  f47-52 (lift 0.25 gentle: 0.17, 0.17, 0.19, 0.17, 0.17, 0.18 over f47-52), where the exported bake reads at most 0.14. In the six
  finished bakes no try at the main polish window was feasible, and all six fail the validator: right arm 0.200 (0.25, no guard),
  0.192 with blade and edge pops 0.50 and 0.46 at f46 (0.35, guard), 0.214 with a 0.52 blade pop (0.35, no guard), 0.260 with the
  left 0.385 (0.45, guard), 0.212 (0.35 gentle, guard), 0.194 (0.25 gentle, guard; its seeded retry reached 0.177 but made the
  weapon clash worse, so it was not kept).
- Still baking at the time of writing: 0.25 with the guard (in its last retry) and the three outward/forward ones. Of these, the
  lift with 0.25 to his right is the first whose main polish window was feasible and kept (f41-49, 0.171 -> 0.160).

The knee instead, 11-11 (`scripts/kneeprobe.py`). The lift moves the fist, and with it the arm, to clear a thigh that rises into
the haft as he sinks. The other way is to move the thigh. On the exported bake, re-solving only the legs with the right knee's pole
turned about his vertical (the feet, arms and glaive as they are): turned out 10-30 deg the wood stays in the thigh (0.08-0.12 at
f49-50); turned in 10-24 deg it is 0.010-0.033 at most (15 deg: 0.006 at f49, 0.027 at f50; 6 deg is worse, 0.139), and the knee
moves up to 0.49 (15 deg). The validator then reports a 0.20-0.24 fist pop at f50 for most angles, from the poses it solves
between frames, where the solver re-places the glaive against the moved leg (`Clip.clear_surface`); only a full bake shows
what that becomes. Full bakes (`results/skyfall_lift_full.txt`, kn*), the knee turning in while he is in the air (1.2-1.42 s), held
through the landing to 1.92 s and back by 2.15 s, every other key unchanged:
- At clear_torso the knee bakes match or beat the exported bake (0.172 at 15 deg, 0.181 at 15 deg with the guard, 0.185 at 20 deg,
  against 0.184), and the wood is out of his thigh at f49-50 in all of them.
- But the polish's main window moved later, to the follow-through (f51-68), and was not kept in any of them. 15 deg without the
  guard came closest: right arm 0.173, left 0.143, pops within the limits (fist 0.173, blade 0.266), the wood in his thigh 0.023
  at most (f55-59, dense; the exported bake 0.121), the game's fades 0.169 in and 0.122 out, no glaive in his torso while fading,
  no face pop (`work/shen_repair/skycheck_knA.txt`, local). It fails on one reading: the right arm 0.19 inside his torso between f62
  and f63. 20 deg: 0.185 with a 0.27 fist pop at f64, and the wood back in his thigh at f63-64 (0.093); 15 deg with the guard:
  0.182 and the left hand 0.20 off the haft. Those frames are where the knee turns back out (f58-64), and the solver re-places the
  glaive against the moving thigh there.
- Watched (normal renders of the review shot, quarter view grounded, f46-62, with and without the robe; local
  `work/shen_repair/kneelook/`): the 15 deg landing reads as the same deep crouch, the right knee still outside the foot (0.28
  outside the ankle instead of 0.43), the haft passing in front of the right shin instead of into the thigh. Nothing pops between
  the stills; the robe settles differently but covers the knee as before.
- Still baking at the time of writing: the knee held in until he rises (back over 2.3-2.6 s, after the follow-through) at 12, 15
  and 18 deg (15 deg left clear_torso at 0.168, the lowest of any Skyfall bake), and 12 deg returning at 1.92-2.15 s.

## 10. Files

- `scripts/`: every probe and tool written in this pass (each starts with a usage line). New ones for the checks above:
  `studio_expected.py` (the solver frames as a model file Studio can load), `studio_preview.luau` (the Studio harness),
  `revaltable.py`, `jsondiff.py`, `legsall.py`, `fadecheck3.py`, `measure_set2.py`, `render_cmp.py`, `sheet.py`, `xray_why.py`,
  `fadeweapon.py`, `shots_gamefade.py`, `thighdir.py`, `liftsum.py`, `kneeprobe.py`, `clothchanges.py` (per-pair rendered-mesh changes between two
  `mesh_clash.py` measurements; `rest` lists the pairs that are not robe or ribbon). `render_cmp.py` can now light the glaive inside a part
  (`FROM=Weapon`), pick frames (`FRAMES`) and leave garments out (`SHEN_REVIEW_HIDE`, a new opt-in in `tools/blender/shen_import/review.py`
  for views the robe would cover; default renders are unchanged).
- `results/`: the outputs cited above, with the `mesh_clash.py` measurements they come from (`mset_<tag>_<n>.json`; `pre4L`/`finL`
  every other frame, `pre4L1`/`finL1` every frame; `SHEN_SCRATCH` pointed at `results/` reproduces the comparisons).
- Bakes: `work/shen_repair/baked_set2` (local, gitignored) is the final set the exports came from.

## 11. Housekeeping

- Studio: the place was never saved from Studio. `HttpService.HttpEnabled`, switched on for an early version of the harness, was
  set back to false in Edit mode. The temporary folder `content\shenpreview` in Studio's install folder (clip copies and the
  harness, 46 files) was deleted on 11-11. Studio's Edit session was checked afterwards: no harness objects left in it,
  HttpEnabled false.
- Stray render folders `C:\work\shen_repair\rv5` were removed; the empty `C:\work` above them is left for you to delete (a safety
  check stops me removing a top-level folder). Cause: review.py passed its relative output folder to Blender, which resolved it
  against the drive root. review.py now makes the folder absolute (11-11).
- Untracked `outputs/hero-grand-soul-review-2026-11-09/` and `outputs/mugen-combat-review-2026-11-09/` belong to another task and
  were left uncommitted on purpose, so `git status` is not fully clean.

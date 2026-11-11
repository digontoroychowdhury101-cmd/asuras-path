# Grandmaster Shen clipping repair: Windows pass (2026-11-09 to 11-12)

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
- `walk_spike` (11-11): swivel's grip walk charges each degree a hand turns on the haft past 15 deg in one frame (P2 Skyfall's fist
  rolling back and forth on the haft, section 9; and P1 Guandao_Running, section 12).
- `roll_from` / `roll_to` (11-12): a rolled edge gap (`Clip.edge_roll`, below) that spans either rolls only between them (P2
  Guandao_Running and P2 BloodWave, section 13).

One change applies to every clip (11-11, section 12): `EDGE_TURN` (120 deg) and `Clip.edge_roll`. Where two keys of the blade's
edge (the `face` channel) turn it more than 120 deg about the haft, the edge now rolls about the haft at the key's ease. Before,
the unit-vector spline passed through the haft's own line and turned the blade over in one frame. Gaps of 120 deg or less keep
the spline, so only clips with such a gap get new keys: 11 have one, and 10 roll, because P1 PrayerBeads keeps the spline
throughout (`Clip.roll_edges` off, section 12).

**Clip keys** (`tools/animation/opening_cast/shen_clips.py`): P1 FlowingJian's second-cut wind-up faces the cut; P2 RendingArc's
overhead finish slides the rear fist toward the butt; P2 Skyfall carries the follow-through's fist; P2 RunForward nudges the fist
0.08 forward; P2 WalkBackward and TurnRight carry the guard in his chest's frame; P2 Death keys the stagger in his chest's frame and
the kneel's fist 0.15 to his right (WINDOWS_START option B); the Idle-hold pins per clip (`IDLE_HOLD`, `ends`, `entry`, L3's end
grip, Skyfall's end grip, DeathblowVictim's entry). Each change carries a dated comment with its measured reason. On 11-11:
P2 Skyfall's right knee turns in 16 deg from 1.42 s to 2.3 s (`kin`, section 9). `arc()` also gains two options (section 12).
`carry_edge`, now the default, carries a first cut's edge up from the guard with the haft (18 clips' entries; P1 Guandao_Heavy and
P2 Guandao_L3 keep the old blend, `carry_edge=False` for that phase); before, the edge blended linearly and snapped on the entry's
last frame. `turn` rolls the edge 180 deg over 0.17 s on Wheel of Heaven's rising return. With the edge roll above, the keyed edge
(`face`) of 21 clips changes, and nothing else in any clip's keys. P1 Feint now starts on Idle's right-hand grip, and
P1 Guandao_Running on Idle's grip with both hands, with its grip walk priced as Skyfall's (section 12). On 11-12 `arc()` gains
`edge_enter` (the carried edge's own roll-in, longer than the hands'), used by P1 and P2 Guandao_L2's first cut (section 13).

**Game code** (`src/shared/BossRigs.luau`), found by the Studio check in section 5: `BossRigs.apply` skipped a helper bone that an
earlier form had built, so after the phase transition Shen's glaive joint stayed on phase 1's pivot. Every phase 2 clip and weapon
mesh is made about phase 2's point, so in game the whole weapon sat a constant 0.167 rig units (about 0.22 studs) off his grip in
every phase 2 clip, including the clips already published. `apply` now re-points the existing helper's joint to the current form's
point (its part, joint and welds stay). New regression test `tools/test_boss_rigs.luau` (runs in `verify_all.sh` through
`lune_compat.py --all`): 68 checks pass on the fix; on the pre-fix module it fails exactly the 4 phase-2 glaive checks.

**Exported clips**: 39 re-exported (`assets/animations/opening_cast/shen/`, 15 phase 1 + 24 phase 2) and the manifest; the other
25 clip files are unchanged (`results/jsondiff_pre4_final4.txt`: 0.000 moved). 21 of the 39 were exported again on 11-11 evening
for the glaive's edge (section 12); P1 PrayerBeads, P1 Guandao_Heavy and P2 Guandao_L3 keep their exports from earlier in this pass.
On 11-12 four of the 21 were exported again (P1 and P2 Guandao_L2, P2 BloodWave, P2 Guandao_Running; section 13); the other 60
clips' frame JSON is unchanged (`results/jsondiff_pre5_final5.txt`). The game plays published asset IDs, so the repaired clips reach the game only once they are published, which this pass did not
do. The rig fix is in the built place now, and it also
corrects the glaive for the phase 2 clips already published (they were made about phase 2's point too).

**Build** (`tools/build.py`): ElementTree wrote the place in text mode, which is CRLF on Windows, so a Windows build turned every
line of the committed (LF) place into a change (343k lines). It now writes through a binary handle, LF on every OS; this pass's
place diff is the 15 lines of BossRigs.

## 3. Static review (the repo's validator on the final bakes)

- `revalidate.py` on all 64 final bakes (`work/shen_repair/baked_set2`, after the glaive-edge fix of section 12): **0 problems**
  (`results/reval_final4.txt`; just before that fix `results/reval_final3.txt`, 0 problems). Deepest arm in his torso: on frames
  0.172 (P1 FlowingJian left, 0.167 before the edge fix: past the 0.17 wall, under the 0.18 flag, section 8), between frames 0.175
  (P1 PrayerBeads left, f48), fading in 0.162 (P2 Death). Before the edge fix: 0.168 and 0.179 (P1 Guandao_Running left, f3) and 0.162. After the four clips of
  section 13 (11-12): 0 problems, the same three worsts (`results/reval_final5.txt`, `revaltable_dp11_final5.md`).
- Before/after for the 31 clips whose numbers changed (`results/revaltable_dp11_final4.md`, before = the dp11 bakes handed over):
  P1 FlowingJian 0.200/0.228 with a blade pop and a flipped wrist -> 0.172/0.173, clean; P2 CrimsonEmbrace 0.351 -> 0.157;
  P2 Death 0.231 -> 0.158; P2 DeathblowVictim 0.205 (0.257 fading in) -> 0.160 (0.039); P2 RendingArc between frames 0.189 -> 0.163;
  P1 Guandao_Running 0.188 between / 0.214 fading in -> 0.160 / 0.133; P1 PrayerBeads 0.184 -> 0.175; P2 Feint, PostureBreak,
  Guandao_Running fade-in and between flags all cleared.
- Weapon inside his legs (validator records, does not limit; dense, every weapon sample; `results/legsall_final4.txt`): unchanged or
  lower than at the handover everywhere except P1 WheelOfHeaven 0 -> 0.056 (f25) and P2 BloodWave 0.049 -> 0.079 (f19), both from
  the edge fix (section 8), and P1 PrayerBeads 0 -> 0.002. P2 Skyfall's haft (0.122 in his right thigh at f52 at the handover) is out
  of his legs on every frame. See 9. After section 13: line for line as `legsall_final4.txt` (`results/legsall_final5.txt`).

## 4. Local regression

- **Fades, as the game plays them** (BossAnimations.luau: planned attacks fade in over 0.1 s, other plays and stops 0.15 s, gaits
  0.2 s): `fadecheck2.py` (0.15 s) worst 0.179 (P2 HitLightFront in), `results/fade2_final4.txt`; `fadecheck3.py` at each clip's
  own fade times worst 0.179 (`results/fade3_final4.txt`; the same worsts before the edge fix, `*_final2.txt` and `*_final3.txt`).
  fadecheck3 also prints every clip at all three times; cells the game never uses exceed 0.18 on 6 clips, all non-gaits at 0.2 s or
  reactions at 0.1 s (worst P2 DeathblowVictim 0.278 at a 0.2 s fade in; the game fades it in over 0.1 or 0.15 s: 0.092 / 0.114).
  The seventh before the edge fix, P1 Guandao_Running (0.145 / 0.169 / 0.190 at 0.1 / 0.15 / 0.2 s, and 0.196 at the start of its
  review video, whose own fade is 0.2 s smoothstep), now reads 0.150 / 0.145 / 0.145 and 0.145. The edge fix raised some fades, all
  under 0.18 (section 8): at 0.15 s P2 Flourish's fade out 0.128 -> 0.163, P2 Guandao_L2's fade in 0.160 -> 0.169, P2 RendingArc's
  0.139 -> 0.150; at 0.1 s, RendingArc's own fade in, 0.138 -> 0.172.
- **Pops** (`popjson.py` vs `bakes/pre4_export`, `results/popjson_final4.txt`): frames with a >= 0.5 out-and-back 81 -> 40 (49 just
  before the edge fix, `popjson_final3.txt`). **Face pops** (`facepop.py`): 0 clips with a roll pop > 0.3 (`results/facepop_final4.txt`).
- **Turns in one frame** (section 12; against the export this pass started from, and in brackets just before the edge fix): the
  glaive turning more than 60 deg (`glaiveturn.py`, `results/glaiveturn_pre4_final4.txt`) 48 -> 12 frames (31); a hand reversing on
  the haft (`rollscan.py`, `rollscan_pre4_final4.txt`) right 66 -> 53, left 39 -> 9 (61, 20); an upper arm swinging over 30 deg
  (`armjump.py`, `armjump_pre4_final4.txt`) 295 -> 248 (268). The "just before" counts are in the `*_preedge_final4.txt` files.
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
  - After the glaive-edge fix (11-11 evening), the 21 clips it changed re-shot from the exported JSON and measured at every frame
    (`finK2`; the other clips as `finK1`, the export just before the fix, which has P2 Skyfall's knee; `work/shen_repair/finK2.sh`,
    `finK2b.sh`, local). msetcmp's own groups, `finK1` -> `finK2` (`results/msetcmp_finK1_finK2.txt`): robes and ribbons ("cloth")
    146 -> 148 pairs, sum 1.399 -> 1.422, deepest 0.166 both; "arm-in-weapon" 151 -> 154, sum 2.892 -> 2.955; "weapon-in-arm"
    38 both, sum 0.226 -> 0.223; "other" 153 -> 157, sum 2.245 -> 2.271, deepest 0.341 -> 0.342. Against the export this pass
    started from (`results/msetcmp_pre4L1_finK2.txt`) every group is still lower but "weapon-in-arm" (35 -> 38 pairs, sum 0.218 ->
    0.223, deepest 0.162 -> 0.145). Per pair: `results/cloth_changes_finK1_finK2.txt` (16 robe and ribbon pairs deeper or more
    frequent, 10 shallower) and `rest_changes_finK1_finK2.txt` (52 deeper, 36 shallower); against the start, `*_every_finK2.txt`.
  The rises are open (section 8 items 3 and 8).
  - After the four clips of section 13 (11-12; `finK3`, those clips re-shot from their exported frame JSON, `work/shen_repair/finK3.sh`,
    local): robes and ribbons 148 -> 149 pairs (sum 1.422 -> 1.426), arm-in-weapon 154 -> 152, weapon-in-arm 38 -> 39, other
    157 -> 153 (2.271 -> 2.260), deepest unchanged in each (`results/msetcmp_finK2_finK3.txt`); per pair `cloth_changes_finK2_finK3.txt`
    (1 deeper) and `rest_changes_finK2_finK3.txt` (4 deeper, 10 shallower), listed in section 13; against the start, `*_every_finK3.txt`.
- After section 13 (11-12, `results/*_final5.txt`): fades worst 0.179, unchanged; pops 81 -> 38 frames (40 before it); the glaive over
  60 deg in a frame 48 -> 10 (12); hands reversing on the haft right 66 -> 54, left 39 -> 8 (53, 9); upper-arm swings 295 -> 247 (248).
- `py tools/test_cloth_sim.py`: P1 ok (rest drift 1.143, sprint trail 0.17), P2 ok (1.187, 0.39).
- `bash tools/verify_all.sh` (Git Bash, `python3` shimmed to `py`): all 14 stages pass, exit 0, "Shen integration: ok"
  (`results/verify_all_final2.log`; the Shen audio manifest it needs was generated with `py tools/assets/build_shen_audio.py`, which
  writes only the gitignored `assets/build/shen_audio/`).
- After the 11-11 follow-up (review.py's output path, the new probes): `verify_all.sh` again all 14 stages pass, exit 0, now with
  `test_boss_rigs.luau` 68 passed (`results/verify_all_followup.log`); `test_cloth_sim.py` ok with the same numbers.
- After the glaive-edge fix (11-11 evening): `verify_all.sh` all 14 stages pass, exit 0, "Shen integration: ok"
  (`results/verify_all_edge.log`); `test_cloth_sim.py` ok with the same numbers; `tools/build.py` left the place unchanged (the
  exported clips are not part of it).
- After section 13 (11-12): `verify_all.sh` all 14 stages pass, exit 0, "Shen integration: ok", cloth sim ok with the same numbers
  (`results/verify_all_1112.log`).

## 5. Visual review (renders watched)

X-ray before/after videos of every re-exported clip, front view, arms through the upper torso, in
`outputs/grandmaster-shen-2026-11-05/repair/arms_w10_f{1,2}_<clip>_uppertorso_before_after.mp4` (39 clips) plus
`arms_w10_f2_GuandaoSkyfall_uppertorso_side_before_after.mp4`. Each was made from the final bake (checked before the edge
fix: every video was newer than its bake and its frame JSON; for the 21 below, the frame JSON was compared byte for byte
instead) and watched, with contact sheets of the worst stretches (local only, `work/shen_repair/sheets/`).
The 21 clips exported again for the glaive's edge (section 12) have new videos, made on 11-11 evening from their final frame JSON
(`work/shen_repair/json_ck_fin5`, byte for byte the exported JSON) against the same "before"; their rows in the table below are
re-measured from those renders (`scripts/xraytable.py`, logs `work/shen_repair/rv5/*_fin5L_UpperTorso_front.log`, local).

What the renders show, beside the numbers (`results/xray_mesh_table.md`, the rendered mesh's deepest point inside the upper torso):
- Clearly better on screen (with the four clips of section 13 as now exported): P2 RendingArc 0.385 -> 0.199, P2 Feint 0.277 -> 0.190, P2 Guandao_L2 0.251 -> 0.182, P2 Guandao_Heavy
  0.237 -> 0.174, P2 RunForward 0.270 -> 0.174, P2 Skyfall 0.219 -> 0.179, P2 BloodWave 0.204 -> 0.167, P2 CrimsonEmbrace
  0.186 -> 0.166, P1 FlowingJian 0.188 -> 0.149 (blade pop and wrist flip gone), P2 Guandao_Running 0.242 -> 0.173 (0.169 before the
  edge fix, 0.205 after it; below and section 13).
- Rendered mesh still past 0.18 (the validator's skin samples pass on all of them; open, section 8; what each measure counts:
  `results/xray_why.md`): P2 Death 0.252 (unchanged), P2 DeathblowVictim 0.275 (0.285), P2 RendingArc
  0.199, P2 Feint 0.190, P2 PhantomDrift 0.186, P2 Transform 0.183 (unchanged), P2 Guandao_L1 0.182 (0.180),
  P2 Guandao_L2 0.182, P2 HitLightFront 0.182 (0.184). P2 Guandao_Running and BloodWave were past 0.18 after the edge fix (0.205 and
  0.183; 0.169 and 0.172 in the export just before it) and are under it since section 13 (0.173 and 0.167).
- Rose: P2 Guandao_L3 0.147 -> 0.180 (f25-29); P2 Flourish 0.126 -> 0.176 (0.132 before the edge fix), P1 WheelOfHeaven 0.144 ->
  0.154 (0.145), P1 Flourish 0.116 -> 0.131 (0.123); and by 0.006-0.009 P1 Feint, P1 Guandao_L3, P1 PrayerBeads, P2 Strike.
- Where the edge fix raised it, frame by frame (`work/shen_repair/sheets/edge_*.png`, local): P2 Guandao_Running's left arm now
  crosses his chest level over clip f11-13, where it rose across it before; with the edge's late roll switched off (bake edH,
  `work/shen_repair/xrayone.sh`) those frames read 0.041-0.062 as before, so the roll does it. P2 Flourish's blade lies flatter over
  shot f63-67 (viewed; the seam reads 0.160-0.176 over f63-67). In the front view nothing comes through his chest in either; the depth is in
  skin the validator does not count (section 8). Fixed for P2 Guandao_Running on 11-12 (section 13).
- 11-12: new videos for the four clips of section 13 (`arms_w10_f1_Guandao_L2`, `arms_w10_f2_Guandao_L2`, `arms_w10_f2_BloodWave`,
  `arms_w10_f2_Guandao_Running`), made from their exported frame JSON against the same "before" and watched; their rows in
  `results/xray_mesh_table.md` are measured from the trial renders of that JSON (`scripts/xraytable.py CLIP=TAG`).

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
- After the glaive-edge fix (11-11 evening, a fresh Play session, Shen taken to phase 2 by the game's own transition): the 21 clips
  exported for it. Phase 1, 10 clips: within 0.0115 (Guandao_L1 f12, the glaive, as in the first check), the other nine
  0.0021-0.0067. Phase 2, 11 clips: within 0.0103 (Skyfall's right hand, f21, as in its rsC check), glaive worst 0.0090
  (Guandao_L1 f12), the other ten 0.0024-0.0074. Still, viewed, not saved: P2 Flourish at the catch (t=1.413, f42), both hands on
  the haft, the blade out to his left, nothing through him.

- The four clips exported on 11-12 (section 13), checked later that day the same way (a fresh Play session, phase 2 by the game's
  own transition, live glaive pivot 1.090, -0.390, -0.350): P1 Guandao_L2 within 0.0056, P2 BloodWave 0.0020, P2 Guandao_L2 0.0058,
  P2 Guandao_Running 0.0091 (the glaive at the last frame in each; every other part within 0.0009). Stills, viewed, not saved, textured
  this time: P2 Guandao_L2 t=0.117, Guandao_Running t=0.442 and 0.454, BloodWave t=1.554 and 2.071; both hands on the haft, nothing
  through his body. Studio was driven over stdio with `scripts/studio_mcp.py` (Roblox's StudioMCP.exe), since no Studio tools were
  attached to that session.

## 7. Multiplayer and device profiling

- Multiplayer: not run. No two-client session was started in this pass, so nothing here shows two clients seeing the same
  phase 2 glaive. The fix is server-side state (the joint attachment replicates); a two-client check is still owed. Starting one
  needs Studio's Test tab (a local server with clients), which the Studio connection used here cannot start (it has single-player
  Play only). Desktop control of Studio was requested on 11-11 for this and declined, so it was not retried.
  What the single-player session does show: `BossRigs.apply` runs only on the server (`BossSkin.luau:160`; the client only reads
  `Rigs.rest`), and the harness ran in the play session's client datamodel, where the live boss's glaive pivot read back as phase 2's
  point after the server's own transition (section 6). So the re-pointed joint reached one client. Two clients at once, and a player
  who joins after the transition, are untested.
- Device profiling: not run; no phone, tablet or console hardware here. The one frame-time number in this pass is the cloth step,
  timed in Studio on this PC alone with bakes running (section 14): about 6-8 ms a step. Nothing measures memory.

## 8. Open defects (not accepted, still to fix)

1. Rendered-mesh arm depth past 0.18 in nine phase 2 clips (section 5), worst P2 DeathblowVictim 0.275 and P2 Death 0.252,
   although the validator's dense skin samples are under its limit on all of them. Two more, P2 Guandao_Running and BloodWave,
   came with the glaive-edge fix (item 8) and are under 0.18 since 11-12 (0.173 and 0.167, section 13). Traced on 11-11 (`results/xray_why.md`, `scripts/xray_why.py`), the two measures count
   different skin:
   - Seven clips (RendingArc, PhantomDrift, Transform, Feint, L1, L2, HitLightFront): the depth past 0.18 is upper-arm skin at the
     shoulder seam that sat within 0.05 of his chest at rest. The validator leaves that skin out (`_torso_free`); the x-ray counts it.
   - P2 Death 0.252: only in the review shot's fade from his last pose back to Idle. The game holds Death's last frame after KO
     (`BossAnimations.luau:226`), so that fade never plays. Inside the clip: 0.181, the same shoulder-seam skin.
   - P2 DeathblowVictim 0.275: the review's 0.2 s fade in (0.114 at the game's 0.15 s). Inside the clip, at clip f18 (shot f36), the
     top of his left shoulder is 0.219 in; 0.188 of that is skin the validator would count, but it falls between its ~510
     left-upper-arm samples.
   - P2 Feint 0.190 (since the edge fix): the same shoulder-seam skin (the counted skin 0.166). P2 BloodWave 0.183 (the same skin)
     and P2 Guandao_Running 0.205 (clip f11-13: arm-mesh skin that follows his upper torso's bone most, which the validator files
     under the torso) were fixed on 11-12 by where the edge rolls (section 13).
   In normal renders of the two worst in-clip frames (RendingArc f58, DeathblowVictim f36), nothing comes through the front of his chest.
   The depth is still there in all nine, so this item stays open.
2. P2 Guandao_L3 rose 0.147 -> 0.180 in the rendered mesh (f25-29): left upper arm at the shoulder seam (0.180), and 0.173 for skin
   the validator counts, which is past the 0.17 wall but under its 0.18 flag (`results/xray_why.md`).
3. Cloth, rendered mesh at every frame (section 4): the 34 robe and ribbon pairs that went deeper or more frequent
   (`results/cloth_changes_every.txt`), led by P1 Guandao_Running RobeLeft in LowerTorso 0.125, P2 Guandao_Heavy RobeRight in the
   right thigh 0.124 and RobeBack in the left shin 0.119, P2 Guandao_L2 RibbonLeft in the left forearm 0.118; and the 43 sleeve,
   beard, beads and hair pairs that did (`results/rest_changes_every.txt`), led by P2 Guandao_L2 LeftSleeve in the left upper arm
   0.196, P1 FlowingJian Beads in LowerTorso 0.188, P2 Death Beard in his head 0.182, P2 Guandao_Running LeftSleeve 0.180. The
   every-other-frame list's P2 Skyfall RobeFront in the left forearm was a sampling miss (0.113 before, at every frame). Added on
   11-12 by section 13: P2 BloodWave LeftSleeve in the left upper arm 0.117 -> 0.151, P2 Guandao_Running LeftSleeve 0.109 -> 0.137,
   P1 Guandao_L2 RobeLeft in the left thigh 0.049 -> 0.062 (`results/cloth_changes_finK2_finK3.txt`, `rest_changes_finK2_finK3.txt`).
4. The glaive through his upper torso for a frame as the review shot fades in from Idle (shot f22): P2 Flourish 0.308 -> 0.341,
   P2 Guandao_L2 0.298 -> 0.281 (P2 RunForward's, 0.352 at shot f21 at every frame, is gone); after the edge fix 0.342 and 0.293
   (`mset_finK2_*.json`). At the game's own fades (11-11, `results/fadeweapon_final.txt`; after the edge fix `fadeweapon_final4.txt`: every
   weapon sample against the solver's torso solids, fading in from the clip's first frame) both are 0.000 at 0.1 s. That is the fade the
   game gives them, since both have contact times (`BossAnimations.luau:72`). At 0.15 s: Flourish 0.065, L2 0.012 (after the edge fix
   0.083 and 0.013); at 0.2 s: Flourish 0.187 (0.194). No other clip passes 0.05 at 0.1 or 0.15 s; at 0.2 s, which the game uses only
   for gaits, P1 Flourish 0.054 (0.060 before the edge fix); P2 Death's 0.079 is its fade-out, which never plays. On the rendered mesh
   (`scripts/shots_gamefade.py` + mesh_clash.py, every frame, `results/mset_gamefade.json`): the 0.2 s shots reproduce 0.341 and
   0.281 exactly, and with the fade at 0.1 s neither clip has any glaive in his torso. At 0.15 s Flourish is 0.361 and L2 0.079, but the
   game never gives these clips 0.15 s: Flourish is cued as a BossSwing with an impact time (`BossAttackService.luau:49`), so it gets the
   0.1 s fade. Left: in L2 at 0.1 s, his chest surface is 0.071 inside the glaive at clip f4 (0.064 before this pass). Not checked: fades
   from poses other than Idle, and a late start when latency eats into the impact time.
5. Fixed on 11-11 evening: the review renders' 0.2 s fade put P1 Guandao_Running's left arm 0.196 in at the start of its video (the
   game's own fades: 0.145 and 0.169). Started on Idle's grip (section 12): 0.145 at the start of the video, 0.150 and 0.145 at the
   game's 0.1 and 0.15 s (`fade2_final4.txt`, `fade3_final4.txt`).
6. Fixed on 11-11: P2 Skyfall's haft in his right thigh after the landing (section 9). The exported rsD keeps it out of his legs on
   every frame by the dense measure (`legsall_final4.txt`), and the rendered mesh has no glaive in either thigh at any frame
   (`mset_finK2_*.json`).
7. Multiplayer and device checks not done (section 7).
8. What the glaive-edge fix (section 12) made worse by a measure, against the export just before it (set-wide: the `*_final4` and
   `*_preedge_final4` results; per clip: `work/shen_repair/candcheck.txt` and `onecheck_*.txt`, local):
   - The blade going out and back at the pinwheels' starts (`popjson.py`, f3-4): P1 Flourish 1.14, P2 Flourish 1.26, P1 WheelOfHeaven
     1.64 (the export 0.64 or none there), and inside Wheel of Heaven's pinwheel: right hand f8 0.67 and f22 0.65, glaive f27 0.70.
     In the player's camera these frames look the same as the export. P2 Guandao_Running's right forearm out and back 0.96 at f3
     (0.60), from its carried entry (0.90 with the roll off, bake edH).
   - Rendered-mesh arm depth in the upper torso (section 5, item 1): P2 Guandao_Running 0.169 -> 0.205 over clip f11-13, from the
     edge's late roll (bake edH, the roll off: 0.041-0.062 there; fixed on 11-12, 0.043-0.056 there, section 13); P2 Flourish
     0.132 -> 0.176, P2 BloodWave 0.172 -> 0.183 (fixed on 11-12: 0.167), P2 Feint
     0.183 -> 0.190; P1 WheelOfHeaven and P1 Flourish 0.008-0.009 deeper, P1 FlowingJian 0.005.
   - The validator's own arm depth: P1 FlowingJian's left arm 0.167 -> 0.172 on frames, past the 0.17 wall and under its 0.18 flag.
   - The game's fades, all under 0.18 (section 4): P2 Flourish's fade out 0.128 -> 0.163, P2 Guandao_L2's fade in 0.160 -> 0.169,
     P2 RendingArc's 0.139 -> 0.150 at 0.15 s and 0.138 -> 0.172 at its own 0.1 s; the glaive in his body as P2 Flourish fades in
     (item 4).
   - Upper arms swinging further in one frame (`armjump.py`): P1 Feint 37 deg at f7 (27), P1 and P2 Guandao_L2 right 67 and 72 (56, 60),
     P2 RendingArc right 60 (52), P2 BloodWave left 52 (42), P2 Guandao_Running right 63 at f3 (36; its largest, 68 at f5, as before)
     and left 47 at f15 (40). After section 13: P1 Guandao_L2 right 72 at f11 and 60 at f2; P2 Guandao_Running right 61 at f3 and
     left 35 at f15.
   - Hands reversing on the haft (`rollscan.py`): P1 WheelOfHeaven right 1 -> 3, P2 BloodWave 0 -> 1 on each hand (the left back to 0
     on 11-12, section 13).
   - The weapon inside his legs (`legsall.py`, dense): P2 BloodWave 0.049 -> 0.079, P1 WheelOfHeaven 0 -> 0.056.
   - P2 Guandao_Heavy's glaive now turns 63 deg at f4, over 60 (it did not before).
   - Cloth and the glaive on the rendered mesh (section 4; `cloth_changes_finK1_finK2.txt`, `rest_changes_finK1_finK2.txt`): 16 robe
     and ribbon pairs deeper or more frequent, led by P1 Guandao_Running RobeLeft in LowerTorso 0.125 -> 0.161, P2 BloodWave RobeLeft
     in the left thigh 0.091 -> 0.134 and P1 FlowingJian RobeFront in the left forearm 0 -> 0.089; 52 other pairs, led by P2 Flourish's
     glaive in LowerTorso 0.124 -> 0.173 (shot f23, as the review fades in), P2 Guandao_L2's glaive in the right forearm 0.049 ->
     0.128, P2 Strike LeftSleeve in the left upper arm 0.061 -> 0.123 and P1 Guandao_L2 Beads in UpperTorso 0 -> 0.121.
9. The glaive still turns more than 60 deg in a frame on 10 frames in 8 clips (`results/glaiveturn_pre4_final5.txt`; 12 before
   section 13). Six are the haft swinging with the hand, its roll under 15 deg: P1 and P2 Guandao_L1 f11 (77, 78), Guandao_L2 f11
   (94, 95) and Guandao_Heavy f22 (65, 68). Four roll 35-66 deg: P2 Guandao_Heavy f4 (63), P2 Guandao_Running f2 (66) and
   P1 PrayerBeads f2 and f21 (69 each, kept, section 12). P1 and P2 Guandao_L2's f2 (64 each) are 49 and 56 since 11-12; P2
   Guandao_Running's f2 with a slower roll-in was not adopted (section 13).
10. Nine phase 1 clips start with the right upper arm 86-114 deg from Idle's (`armjump.py`, first frame against Idle 0.6 s in,
    `results/armjump_pre4_final4.txt`), which a fade in from Idle turns through: the attacks Guandao_L1 102, Guandao_L2 104, Flourish
    101, WheelOfHeaven 103 and PrayerBeads 86, and DeathblowVictim 114, PostureBreak 110, Death 106 and Transform 101. Seven were the
    same in the export this pass started from. P1 Death (20 there) and P1 PrayerBeads (59) came with the handed-over dp11 bakes, which
    already read 106 and 86 (frame JSON made from `work/shen_repair/baked_dp11`), and which this pass exported. Starting the attacks
    on Idle's grip moved the swing into f0 -> f1 and added forearm pops (section 12), so it was not adopted. PrayerBeads was started
    on Idle's grip only with its edge rolled (section 12), Death not at all.
11. What the four fixes of 11-12 (section 13) made worse by a measure, against the export just before them: P2 BloodWave LeftSleeve
    in the left upper arm 0.117 -> 0.151 (f64) and P2 Guandao_Running's 0.109 -> 0.137 (f29); P2 Guandao_Running's left forearm in
    the glaive on 11% of frames (3%); P1 Guandao_L2 RobeLeft in the left thigh 0.049 -> 0.062 and his chest in the glaive 0.049 ->
    0.060; P1 Guandao_L2's right upper arm 72 deg in a frame at f11 (67) and 60 at f2; P2 Guandao_L2's right hand reversing on the
    haft once (16 deg; none before); P1 Guandao_L2's rendered arm 0.132 -> 0.137 (under the wall).
    Traced on 11-12 (section 14): both sleeve rises come with the edge roll each fix moved. The trials that kept the sleeve down
    failed the validator (Running, roll from 0.467: an edge pop 0.64 at f16) or turned the glaive 49 deg and swung the right upper
    arm 41 deg in a frame (BloodWave not rolled, bwR); still open.
12. The cloth costs about 6-8 ms a step in Studio on this PC (section 14), mostly the surface passes, which every graphics tier runs
    4 + 2 times. Making it cheaper without changing the cloth's look needs a new approach to those passes; not started.

## 9. P2 Guandao Skyfall: the weapon in his thigh, the fist's flutter, the coil

Fixed on 11-11 by three changes to the clip, each checked by a full bake from the start (`results/skyfall_lift_full.txt`,
`scripts/liftsum.py`). The export is the last bake, `rsD`. It passes the validator: right 0.155, left 0.149, fist pop 0.156, blade
0.396, slide 0.087. The wood stays out of his legs on every frame f40-78, on every weapon sample. Neither hand rolls back and forth
on the haft. The glaive no longer turns over in the coil: at most 22 deg in a frame, against 169 and 177.
1. The haft in his right thigh after the landing: his right knee turns in 16 deg while he is in the air and stays in until he rises
   (`shen_clips.py` skyfall(), `kin`). Lifting the fist instead put his right arm into his chest in all ten bakes (below).
2. The fist flicking round the haft and back on 14 frames: swivel's grip walk now charges each degree a hand turns on the haft past
   15 deg in a frame (`Clip.walk_spike`, phase 2 Skyfall only).
3. The glaive turning over for two frames in the coil (f13-15, there since the handover): the first cut's edge is carried up from the
   guard (section 12).

The thigh as first found. This pass's first Skyfall export passed the validator (R 0.160, L 0.169), and its arms were much better on
screen (rendered mesh 0.219 -> 0.176). But after the landing the haft, ahead of his right fist, ran into his right thigh:

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
No clip opts in to `legs_guard`.

Where that pointed: the polish already weighs the guard together with the torso. With `legs_guard` on, its held_clash constraint
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
  f47-52 (lift 0.25 gentle: 0.17, 0.17, 0.19, 0.17, 0.17, 0.18 over f47-52), where the exported bake reads at most 0.14. All ten
  bakes fail the validator: right arm 0.200 (0.25, no guard), 0.184 and 0.18 between f52 and
  f53 (0.25, guard; legs clear on every frame), 0.192 with blade and edge pops 0.50 and 0.46 at f46 (0.35, guard), 0.214 with a 0.52
  blade pop (0.35, no guard), 0.260 with the left 0.385 (0.45, guard), 0.212 (0.35 gentle, guard), 0.194 (0.25 gentle, guard; its
  seeded retry reached 0.177 but made the weapon clash worse, so it was not kept), 0.192 with a 0.63 blade pop (0.25 up and 0.25
  to his right, guard: its first window, f41-49, was the only main-window try of any lift that was feasible and kept, 0.171 ->
  0.160, but the next, f54-68, was not), 0.206 (0.25 up and 0.2 forward, guard), and right 0.196 with the left arm 0.361 (0.28 and 0.38
  between f47 and f49; 0.25 up, 0.15 right and 0.1 forward, guard: it entered its main polish window, f41-66, at 0.381 and none of
  three tries there was feasible; the glaive also 0.112 into the right thigh at f59).

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
- Held in until he rises (back over 2.3-2.6 s, after the follow-through), full bakes. 15 deg passes the validator (right 0.177,
  left 0.171) but leaves the wood 0.045 in his right thigh at f59. 12, 14 and 18 deg were stopped by hand once clear_torso had left
  the right arm deeper than the 15 deg bake's (0.242, 0.202, 0.189). 16 deg (`knI`) passes: right 0.160, left 0.152, fist pop
  0.122, blade pop 0.380, and no wood in his legs on any frame f40-78. The 12 deg knee returning at 1.92-2.15 s failed (right 0.188,
  and 0.19 between f53 and f54). The export keeps 16 deg held to 2.3 s.

The fist's flutter, 11-11 (`scripts/rollscan.py`, `scripts/rolltrace.py`; normal renders of the right hand frame by frame, local
`work/shen_repair/rolllook/`). On screen, the knee bake's fist rolled on the haft and back for a frame at a time after the landing.
rollscan counts such frames in the exported frame JSON: frames where the hand's turn on the glaive takes two steps of 15 deg or more
about opposed axes. Skyfall had 5 (right) and 3 (left) at the handover, 14 and 2 in this pass's first export, and 13 and 5 with the
knee. rolltrace re-runs the bake's stages from saved state and counts after each one. None come from the keys, and each swivel round
adds more over f40-70 (3, 6, 9).
- The torso recheck's per-degree price on a one-frame whip (`recheck_spike`, already used by P1 FlowingJian) alone left 12 and 5
  (15 deg, `rsA`), and the same at 10 deg (`rsB`); the verdicts are knI's.
- The same price in swivel's own walk (`Clip.walk_spike`, new, opt-in) with recheck_spike, both 15 deg (`rsC`): none on either
  hand, validator clean (right 0.160, left 0.149, fist pop 0.144, blade 0.396, slide 0.153), legs clear f40-78.

rsC was exported and checked in Studio first (section 6). Then the new glaive-turn measure (section 12) found its glaive turning over in the
coil: 169 deg in one frame at f13 and 177 deg back at f15, with the right hand 178 deg round the haft. The handover had the same flip
(f13-14, 162 and 179 deg). The pop checks look at positions out and back on adjacent frames, so they never saw it, and the review
cameras crop the blade there (overhead). Cause: the cut's keyed edge ran along the haft as the haft rose to the vertical (section
12). `rsD` is rsC with the carried edge. Its keys differ from rsC's only in the edge, and it is the bake above (full bake, 4076 s,
`results/skyfall_lift_full.txt`). The repo's keyed controls for Skyfall equal that bake's overlay on every frame
(`scripts/keymatch.py`, `results/keymatch_final4.txt`). rsD is the export now; it was checked in Studio with the other 20 clips of
section 12 on 11-11 evening (section 6).

## 10. Files

- `scripts/`: every probe and tool written in this pass (each starts with a usage line). New ones for the checks above:
  `studio_expected.py` (the solver frames as a model file Studio can load), `studio_preview.luau` (the Studio harness),
  `revaltable.py`, `jsondiff.py`, `legsall.py`, `fadecheck3.py`, `measure_set2.py`, `render_cmp.py`, `sheet.py`, `xray_why.py`,
  `fadeweapon.py`, `shots_gamefade.py`, `thighdir.py`, `liftsum.py`, `kneeprobe.py`, `clothchanges.py` (per-pair rendered-mesh changes between two
  `mesh_clash.py` measurements; `rest` lists the pairs that are not robe or ribbon). On 11-11 also `rollscan.py` and `rolltrace.py` (a hand
  rolling back and forth on the haft, in the export and stage by stage), `glaiveturn.py` (the glaive's turn per frame: swing and roll),
  `keyroll.py` (the same for the keys, before the solver) and `armjump.py` (each upper arm's one-frame swings, and its first frame against Idle's),
  then `keymatch.py` (the repo's keys and per-clip options against the DEV overlay a bake was made with), `edgecount.py` (which clips
  each part of the edge fix changes, `results/edge_keys_count.txt`) and `xraytable.py` (rewrites rows of `results/xray_mesh_table.md`
  from the x-ray renders' logs). `render_cmp.py` can now light the glaive inside a part
  (`FROM=Weapon`), pick frames (`FRAMES`) and leave garments out (`SHEN_REVIEW_HIDE`, a new opt-in in `tools/blender/shen_import/review.py`
  for views the robe would cover; default renders are unchanged).
- `results/`: the outputs cited above, with the `mesh_clash.py` measurements they come from (`mset_<tag>_<n>.json`; `pre4L`/`finL`
  every other frame, `pre4L1`/`finL1` every frame, then `finK1` with P2 Skyfall's knee and `finK2` after the edge fix, every frame;
  `SHEN_SCRATCH` pointed at `results/` reproduces the comparisons). The set-wide checks are suffixed by when they ran: `_final2` the
  first full export, `_final3` just before the glaive-edge fix (with P2 Skyfall's rsC), `_final4` after it; `_preedge_final4` sets
  the export just before the fix beside the final one. Also `keyroll_edgeB.txt` (the edB overlay's keys: the same 23 frames as the
  repo's now), `rollscan_pre4_final.txt` (the first export's hand reversals, section 9), `rolltrace_knI.log` and `rolltrace_rsC.log`
  (section 9, stage by stage) and `verify_all_edge.log` (section 4). On 11-12 (section 13): `_final5` after its four clips, and
  `_pre5_final5` with the export just before them (`pre5_export`) beside the final one; `mset_finK3_*.json` and the `finK3` comparisons;
  `keymatch_final5.txt`; `verify_all_1112.log`. `scripts/xraytable.py` takes `CLIP=TAG` to read a clip's row from a trial's render.
- Bakes: `work/shen_repair/baked_set2` (local, gitignored) is the final set the exports came from.

## 11. Housekeeping

- Studio: the place was never saved from Studio. `HttpService.HttpEnabled`, switched on for an early version of the harness, was
  set back to false in Edit mode. The temporary folder `content\shenpreview` in Studio's install folder (clip copies and the
  harness, 46 files) was deleted on 11-11. Studio's Edit session was checked afterwards: no harness objects left in it,
  HttpEnabled false. The same again after the 21-clip check on 11-11 evening: play stopped, `content\shenpreview` deleted, the
  place not saved, the Edit session clean, HttpEnabled false.
- Stray render folders `C:\work\shen_repair\rv5` were removed; the empty `C:\work` above them is left for you to delete (a safety
  check stops me removing a top-level folder). Cause: review.py passed its relative output folder to Blender, which resolved it
  against the drive root. review.py now makes the folder absolute (11-11).
- Untracked `outputs/hero-grand-soul-review-2026-11-09/` and `outputs/mugen-combat-review-2026-11-09/` belong to another task and
  were left uncommitted on purpose, so `git status` is not fully clean.

## 12. The glaive turning over in one frame (11-11)

Found while fixing Skyfall's coil (section 9) and measured set-wide with a new check, `scripts/glaiveturn.py`: the glaive's rotation
from frame to frame in the exported frame JSON, split into the haft's swing and the blade's roll about the haft (the glaive mesh's own
haft axis), with the right hand's turn on the glaive. The validator's pop check and `popjson.py` look at positions going out and coming
straight back on adjacent frames, so a glaive that turns over in one frame and stays, or comes back two frames later, passes both.

- At the handover, 48 frames turned the glaive more than 60 deg in one frame; this pass's previous export had 31, in 16 clips
  (`results/glaiveturn_pre4_final3.txt`). Most are rolls about the haft of 90-170 deg in a frame with the hand nearly still, i.e. the
  glaive spinning over inside the fist: P1 WheelOfHeaven f46 173 deg (roll 169), P1 FlowingJian f53 163 (157) and f72 135 (126),
  P2 Skyfall f13/f15 (169/177, out and back), P2 RendingArc f48 121, P1/P2 Guandao_L2 f11 141, P1/P2 Flourish f2 and f42 103-113,
  P1 WheelOfHeaven f2 153. Watched: P1 WheelOfHeaven f43-49, player's camera: at f45 -> f46 the blade's edge and its back hook swap
  sides from one frame to the next.
- The keys already do it (`scripts/keyroll.py`, the keyed glaive before the solver; `results/keyroll_pre_edge.txt`: 39 frames where
  the keyed edge rolls more than 45 deg, or the haft swings more than 60, in one frame). Three causes, all in how the edge is keyed or
  splined, not in the solver:
  1. A first cut's entry (`shen_clips.arc`, t0 < 0.3): the guard's unit edge blended linearly with the cut's own, which arc keys as a
     2-degree difference (length 0.035), so the guard's edge held until the last frame of the entry and then snapped to the cut's
     (Returning Tide and Charging Crescent 99 deg at f3; Feint, FlowingJian f12, HesitantMoon, RendingArc f13; Skyfall's haft rising
     to the vertical made it degenerate). Fix: the edge is carried up from the guard with the haft (least rotation key to key) and
     rolled about the haft toward the way the blade travels on its plane by the entry's own weight (`arc(carry_edge=True)`, now the
     default; `carry_edge=False` keeps the old blend).
  2. Face keys far apart: the face channel is a Catmull-Rom spline of unit vectors, and two keys that turn the edge 130-180 deg about
     the haft put the spline through the haft's own line, so the edge turned over in one frame wherever such a gap was (FlowingJian
     between its cuts, the cuts' returns to the guard, the pinwheels' starts and catches, RendingArc, BloodWave). Fix: where two face
     keys turn the edge more than `EDGE_TURN` (120 deg) about the haft, the edge rolls about the haft at the key's ease
     (`shen_lib.Clip.edge_roll`); every gap of 110 deg or less keeps the spline, so those clips' keys are unchanged. A clip can keep the
     spline throughout (`Clip.roll_edges`, default on).
  3. Wheel of Heaven's rising return starts one frame after the falling cut ends, along nearly the same line (13 deg) with the edge
     reversed: no gap to roll in. Fix: the return starts edge last, as the falling cut left it, and rolls 180 deg to lead over its
     first 0.17 s (`arc(turn=0.17)`, that cut only).
- Together the three changed 24 clips' keyed edges (the carried edge 20 clips' entries, the roll 11 clips, Wheel of Heaven's turn one
  of those) and nothing else in any clip's keys. With the three opt-outs below, the repo now changes 21: 18 by the carried edge, 10 by
  the roll (`scripts/edgecount.py`, `results/edge_keys_count.txt`). By keyroll.py's count the keyed glaive now turns that far on 23
  frames (`results/keyroll_final4.txt`): 3 are P1 PrayerBeads' kept spline, 4 the haft's swing at Guandao_L1 and L2's f11 (72-78 deg,
  roll under 60), and most of the rest the edge rolling 46-61 deg a frame over a few frames where it turned over in one before.

Bakes. Each of the 24 was baked in full from the start (`runall.py`, DEV overlays of the repo files) and checked against the export it
would replace with every measure here (`work/shen_repair/candcheck.txt` and `onecheck_*.txt`, local). A clip was adopted when the
validator passed, the game's fades stayed at or under 0.18, the renders watched showed nothing new, and its glaive turned less
(per-frame turns, `scripts/glaiveturn.py`); other rises are listed below and in section 8, not accepted.
- Adopted, 21 clips (`work/shen_repair/candmap.sh`, local, names each one's bake): with the carried edge alone (bake edA) P2 Feint,
  P2 Guandao_Heavy, P1 and P2 Guandao_L1, P1 Guandao_L3, P1 and P2 Strike, P2 PhantomDrift and P1 HesitantMoon; with the edge roll and
  Wheel of Heaven's turn as well (edB) P1 FlowingJian, P2 RendingArc, P2 BloodWave, P1 and P2 Flourish, P1 and P2 Guandao_L2,
  P2 Guandao_Running and P1 WheelOfHeaven; P1 Feint started on Idle's right-hand grip (edC); P1 Guandao_Running on Idle's grip with
  both hands, its grip walk priced (edD); P2 Skyfall (rsD, section 9).
- P1 Feint passed, but swivel took the right hand round the haft to a grip 101 deg from Idle's at f0, which the game's fade in from
  Idle turns through (`scripts/armjump.py`: each upper arm's turn from Idle's in his chest's frame; the previous export's was 1). It
  now starts on Idle's right-hand grip (`hold_start`, as P1 Guandao_L3 already did): 1 deg, validator clean, its broad/edge/broad
  flicker at f7-9 gone on screen.
- P1 Guandao_Running failed: the left wrist turned 165 deg on the arm. With Skyfall's price on the grip walk (`walk_spike` 15) it
  passes (fist pop 0.167, blade 0.256, the glaive still turning 67 deg at f2); started on Idle's grip with both hands as well, it
  passes with fist pop 0.050, blade 0.022, no glaive turn over 52 deg, and on the right-hand camera its fist stays on the haft
  through f1-3, where the previous export and walk_spike alone leave it at f3-4. That is the export.
- P2 Guandao_Running passed, and both of the previous export's spins in the fist are gone (f3: 100 deg in a frame, the hand 53 deg
  round the haft; f15: 93, the hand 90): its largest turn is 66 deg at f2, with the hand 10 deg on the glaive, and its right hand no
  longer reverses on the haft (`rollscan.py` 1 -> 0). But its right forearm goes out and back 0.96 at f3 (0.60), the right upper arm
  swings 63 deg at f3 (36), and the left arm crosses his chest level over f11-13, 0.205 deep on the rendered mesh (0.169). Baked
  again with the roll off (`Clip.roll_edges`, bake edH, a check only): the crossing goes (0.041-0.062 there), but the f15 spin comes
  back (93 deg, the hand 90 on the glaive), while the forearm pop (0.90) and the f3 swing (62) stay, so those two come from the
  carried entry. Adopted for the two spins; the rest is open (section 8 item 8). Watched: f0-6 in the player's camera, as the
  export; the x-ray review shot's f29-31 beside the export's and edH's (`work/shen_repair/sheets/edge_P2Running_zoom.png`): the left
  arm level across his chest, nothing through it.
- The pinwheels' starts (both Flourishes, P1 WheelOfHeaven): the edge rolls 167 deg over the 3-4 frames before the wheel, and the wheel
  then rolls it back, where the export turned the glaive over at f2 (103, 103 and 153 deg in a frame). `popjson.py` now finds the blade
  going out and back at f3-4: 1.14, 1.26 and 1.64 (the export's 0.64 or none there). Watched in the player's camera, f1-7, export and
  candidate side by side (local `work/shen_repair/look_pin/`): the same in all three, the blade turning edge-on at f3, out to his right
  at f4 (a little further in the candidate) and up into the wheel at f5. Wheel of Heaven also adds three smaller out-and-backs inside
  its pinwheel (right hand f8 0.67 and f22 0.65, glaive f27 0.70); f6-10 and f20-30 look the same as the export. Kept, and listed open
  in section 8 as measured.
- Adopted although the glaive's largest turn did not change, for their pops: P2 Guandao_Heavy (the blade's 0.79 out-and-back at f4
  gone, right hand reversing on the haft 5 -> 4 and the left 1 -> 0, f0 15 deg from Idle's left arm -> 1; its f4 turn 59 -> 63 deg),
  P1 Guandao_L1 (0.53 at f2 gone), P2 Guandao_L1 (2 frames of out-and-back -> 1, left-hand reversal gone), P1 Guandao_L3 (0.62 -> 0.57).

Not adopted; each keeps its export, its keyed controls equal to the export's on every frame (`keydump`, local) and its bake
reproduced from the repo code (below):
- P1 PrayerBeads (`Clip.roll_edges` off). Rolled at its pinwheel's start and catch (f0-3, f18-22), its bake failed the validator: from
  f34 swivel took his arms another way (left upper arm up to 179 deg from the export's over f41-45), and the left arm went 0.20 into his
  torso between f40 and f41, which the joint polish could not clear (0.211 -> 0.205 in 150 iterations, then no better). Started on
  Idle's grip as well it reached the polish with the same 0.21 at f41 and was stopped. The roll also added blade out-and-backs
  (`popjson.py`: 4 frames, worst 1.20 at f18, against the export's 1 frame, 0.69) and hand reversals on the haft (`rollscan.py`: right
  1 -> 4), for one glaive turn fewer over 60 deg (69 and 69 -> 63). Its glaive still turns 69 deg in a frame at f2 and f21 (open).
- P1 Guandao_Heavy (`carry_edge` off for phase 1's Heavy). Carried, and started on Idle's right-hand grip like P1 Feint, it passed, but
  its glaive turned no less (largest 65 deg a frame at f22 either way, 57 at f4), and its right forearm went out and back 0.57 at f4
  (`popjson.py`; the export none), the upper arm swinging 42 deg there (34).
- P2 Guandao_L3 (`carry_edge` off for phase 2's L3). Carried, it passed the validator, but its glaive turned no less (largest 56 deg
  a frame at f2; the export 53), its right hand reversed on the haft 4 times (2), and the game's fade out to Idle put the right upper
  arm 0.186 into his chest a third of the way through (`fadecheck2.py`; the export 0.151). Its keys equal the export's from f5, but
  swivel took the arms another way over f10-16 (up to 58 deg from the export's at f11), and the end pose, 4 deg from the export's at
  the shoulder and 7 at the wrist, fades to Idle's through his chest. Pinned at its end to Idle's right-hand grip as well
  (`hold_end`, bake edG2), it faded out at 0.133, but the validator failed it on an edge pop of 0.93 at f1, and its right hand still
  reversed on the haft 4 times (`work/shen_repair/onecheck_edG2.txt`, local).
- Tried and not adopted: the same start pin on P1 Guandao_L1, L2 and Flourish, whose upper arm also starts 101-104 deg from Idle's in
  the previous export. It brings f0 to 1-9 deg but moves the swing into f0 -> f1 (L1 and L2 71-73 deg, against 46-47) and adds
  forearm out-and-back pops of 0.77 and 0.81 (L1, L2; none without it); Flourish 4 frames of out-and-back (worst 1.21) against 2 and
  12 upper-arm steps over 30 deg against 10.
- Watched (player's camera, export and candidate side by side, local `work/shen_repair/look_edge/`, `look_pin/`): P1 WheelOfHeaven
  f43-49, the blade rolling over across f45-48 and edge-on at f48 where the export swapped edge and hook sides in one frame; P1 and
  P2 Flourish's catch, the blade rolling over across f39-44 (edge-on at f42-43) where the export turned it at f41 -> f42; P1 Feint f7-9
  without the export's broad/edge/broad flicker; P2 Skyfall's coil (low camera f10-18) with the haft continuous; P1 Guandao_Running's
  fist on the haft f1-3; P2 Guandao_L2, P2 Guandao_Running and P2 RendingArc where their numbers moved: as the export. X-ray
  contact sheets, the same ten frames before and after (local `work/shen_repair/sheets/edge_*.png`), for the clips whose x-ray rose:
  P2 Feint, P2 Flourish, P2 BloodWave, P1 WheelOfHeaven and P1 Flourish show the same poses with no new arm through the chest (the
  magenta at P2 Feint f28 and P1 WheelOfHeaven f46 and f75 is there before as well).
- From the repo code as committed (no overlay), the bakes of P1 Feint and P1 WheelOfHeaven (rpE), P1 Guandao_Running (rpF, and rpI
  after the last code change) and P1 PrayerBeads (rpG) are identical, value for value, to the bakes exported or kept
  (`scripts/cmppkl.py`). P1 Guandao_Heavy and P2 Guandao_L3 (rpH) differ from the bakes their exports came from, made on 11-09 before
  the later library changes of section 2, by at most 1.8e-13 and 6.4e-8 (cmppkl's largest difference); their exports stay as they
  are. For every adopted clip the repo's keys equal, on every frame, those of the overlay its bake was made with (`scripts/keymatch.py`,
  `results/keymatch_final4.txt`). The overlays predate the `roll_edges` option and roll as its default does; P1 Guandao_Running's
  overlay also priced the torso recheck's one-frame whip (`recheck_spike` 15), which the repo does not for that clip;
  it changes nothing there (rpI, from the repo, is identical to the export's bake).

The final set (`work/shen_repair/setcheck4.sh`, `finK2.sh` and `finK2b.sh`, local; `results/*_final4*`, `*finK2*`):
- Validator: 64 clips, 0 problems (section 3).
- The glaive turning more than 60 deg in a frame: 48 at the handover, 31 just before this fix, 12 now (section 8 item 9). Out-and-back
  pops 49 -> 40 frames, hands reversing on the haft 61/20 -> 53/9, upper-arm swings over 30 deg 268 -> 248 (section 4).
- The game's fades: worst 0.179, unchanged (section 4).
- Rendered mesh: the arm x-ray deeper by 0.005 or more in 7 of the 21 clips, cloth and the glaive's contacts a little up overall
  (sections 4, 5, 8).
- Studio: the 21 clips play back within 0.0115 rig units of the solver (section 6). Videos: new x-ray before/after videos (section 5).

## 13. Four clips the glaive-edge fix left worse (11-12)

Targets from section 8 items 1, 8 and 9: P2 Guandao_Running's left arm across his chest (rendered mesh 0.205), P2 BloodWave's arm
x-ray (0.183), and the glaive turning 64-66 deg in a frame at f2 in P1 and P2 Guandao_L2 and P2 Guandao_Running. Each trial was baked
in full from the start (`runall.py`, DEV overlays of the repo files with environment switches, local `work/shen_repair/edgeJ`, `edgeK`,
`edgeL`) and checked as in section 12 (`work/shen_repair/onecheck_<tag>.txt`; cloth and the glaive on the rendered mesh at every frame,
`msetone_<tag>.txt`; the x-ray review render `rv5/<shot>_<tag>_UpperTorso_front.log`; all local). Against the export just before
(the 11-11 evening one).

What each one was:
- P2 Guandao_Running, clip f11-13: the return to the guard rolls the edge 136 deg about the haft, and the roll started at the cut's end,
  0.4 s, while the left hand is still on the haft (phase 2 lets go over 0.47-0.55 s; phase 1, which shows no crossing, over 0.34-0.42).
  The arm followed the haft across his chest.
- P2 BloodWave, clip f62-65: the return's roll ran to the clip's last frame (2.15 s), with the left arm 0.18 in his chest over the last
  frames, and the left hand turned back on the haft once.
- The f2 turns: the carried edge (section 12) rolled to the cut's own over the hands' pick-up, three frames (`enter` 0.1 s). Keyed,
  the edge rolled 57-61 deg at f2 (`keyroll.py`), and the solver's glaive turned 64-66 deg there.

The code (both opt-in per clip; no other clip's keys change, `results/keyroll_final5.txt` differs from `keyroll_final4.txt` only in the
L2s' f2):
- `Clip.roll_from` / `roll_to` (`shen_lib.py`, seconds): a rolled gap (`Clip.edge_roll`) that spans either rolls only between them,
  at the key's ease. P2 Guandao_Running `roll_from = 0.433`; P2 BloodWave `roll_to = 1.95` (its return's gap starts at 1.45 s, so it
  rolls over 1.45-1.95 s).
- `arc(edge_enter=...)` (`shen_clips.py`): the carried edge rolls to the cut's own over its own time, where that is longer than the
  hands' pick-up. Returning Tide (Guandao_L2's first cut): 0.1333 s (4 frames) in phase 1, 0.1167 s (3.5) in phase 2. Keyed, the edge's
  largest roll in a frame is then 43 deg (phase 1) and 52 (phase 2); at 4.5 and 5 frames, 41 and 38.

Adopted (bake): P1 Guandao_L2 (eKl), P2 Guandao_L2 (eLa), P2 BloodWave (bwE), P2 Guandao_Running (rJa). Each passes the validator, and
for each the repo's keys and per-clip options equal, on every frame, those of the overlay and switches its bake was made with
(`results/keymatch_final5.txt`; BloodWave's overlay also set `roll_from` 1.45, the gap's own start, which gives the same keys).
- P2 Guandao_Running: rendered arm in his upper torso 0.205 -> 0.173 (`results/xray_mesh_table.md`); review shot f29-31 (clip f11-13)
  0.043-0.056, and the 0.173 is shot f21, the entry, as before the edge fix (0.172 with the roll off, bake edH). Forearm out and back at
  f3 0.96 -> 0.88, upper-arm steps over 30 deg 10 -> 9 (right f3 63 -> 61, left f15 47 -> 35), no hand reversal on the haft either way.
  The glaive still turns 66 deg at f2 (open). Deeper: LeftSleeve in the left upper arm 0.109 -> 0.137 (f29, 14% -> 25% of frames) and
  the left forearm in the glaive on 11% of frames (3%), 0.064 deep. Shallower: the beard in the right upper arm 0.117 -> 0.045.
- P2 BloodWave: rendered arm 0.183 -> 0.167 (its worst now shot f36, inside the clip, 0.167 before as well); left hand's reversal on
  the haft 1 -> 0; the glaive's largest turn in a frame 30 deg (unchanged). Deeper: LeftSleeve in the left upper arm 0.117 -> 0.151
  (f64). The weapon in his legs stays 0.079 at f19 (open, section 8 item 8). Several glaive contacts shallower (`results/rest_changes_finK2_finK3.txt`).
- P1 Guandao_L2: the glaive at f2 64 -> 49 deg (roll 47); the beads in his chest 0.121 -> 0 and the hair in his head 0.102 -> 0;
  rendered arm 0.132 -> 0.137 (under the wall). Deeper: RobeLeft in the left thigh 0.049 -> 0.062, his chest in the glaive 0.049 -> 0.060.
  The right upper arm swings 60 deg at f2 (where the edge now rolls) and 72 at f11 (67), its 64 at f4 gone.
- P2 Guandao_L2: the glaive at f2 64 -> 56 deg (roll 52); out-and-back frames 5 -> 3 (worst 0.69 -> 0.54); the glaive in the right
  forearm 0.128 -> 0.115. The right hand now reverses on the haft once (16 deg, `rollscan.py` 0 -> 1). Rendered arm 0.182 unchanged
  (the shoulder-seam skin, section 8 item 1).

Not adopted:
- P2 Guandao_Running rolled from 0.467 s (rJb), and with a 5-frame edge entry as well (eKb): the validator failed both, edge pops 0.64
  and 0.66 at f16. With a 4-frame edge entry (eKc, roll from 0.433): clean, the glaive's f2 turn 66 -> 52, but the right upper arm
  turned 104 deg in one frame at f3 (89 of it twist about its own length; the export 61) and LeftSleeve went 0.180 into the left upper arm. With a 5-frame entry (eKa, roll from
  0.433): both of its joint-polish rounds over f0-8 ended infeasible (0.185 deep at the start of the window; the bake was still running
  when this was written).
- P2 Guandao_L2 with a 4-frame edge entry (eKl): the game's 0.15 s fade in from Idle put his arm 0.197 into his chest
  (`fadecheck2.py`, past 0.18) and LeftSleeve went 0.199 into the left upper arm (0.068); 4.5 frames (eLb): fade in 0.171, LeftSleeve
  0.140. 3.5 frames (eLa) leaves the sleeve as it was.
- P1 Guandao_L2 with 3.5 frames (eLc): the glaive 57 deg at f2, the beads left 0.121 in his chest, the glaive in his chest 0.060 -> 0.077.
- P2 BloodWave without the carried edge (bwC): the weapon in his legs back to 0.049, but the validator failed it (edge pop 0.46 at
  f14). Not rolled at all (bwR): the same x-ray as bwE, but the glaive turned 49 deg at f54 and the right upper arm swung 41 there.
  Rolled over 1.6-2.15 s (bwF): the end frames 0.180-0.182 as before.

Watched (renders, local `work/shen_repair/sheets/`, `look_*`): P2 Guandao_Running's x-ray sheets and a zoom of shot f28-31 (the left
arm below his chest line, where the export crossed it), and the player's camera f9-16 and f0-6 beside the export and eKc; P1 and P2
Guandao_L2 in the player's camera f0-6 beside the export, and their x-ray sheets
(`l2_p1_eKl.png`, `l2_p2_eLa.png`: the same poses, P1's f26-27 0.121-0.122 -> 0.131-0.137, P2's unchanged); P2 BloodWave's end, shot f80-84,
and the sleeve over f74-92 (the dark slit in the sleeve is in the export too). New before/after videos for the four
(`arms_w10_f1_Guandao_L2`, `arms_w10_f2_Guandao_L2`, `arms_w10_f2_BloodWave`, `arms_w10_f2_Guandao_Running`, `_uppertorso_before_after.mp4`),
before = the export this pass started from, made from the exported frame JSON.

The final set after them (`work/shen_repair/setcheck5.sh`, `finK3.sh`, local; `results/*_final5*`, `*_pre5_final5*`, `*finK3*`;
pre5 = the export just before them):
- Validator: 64 clips, 0 problems (`results/reval_final5.txt`); its worsts as before (0.172, 0.175, 0.162; section 3).
- The glaive turning more than 60 deg in a frame: 12 -> 10 frames (48 at the handover; `glaiveturn_pre5_final5.txt`,
  `glaiveturn_pre4_final5.txt`). Out-and-back pops 40 -> 38 frames (81). Hands reversing on the haft right 53 -> 54, left 9 -> 8 (66, 39).
  Upper-arm swings over 30 deg 248 -> 247 (295). Face pops: none. The other 60 clips' frame JSON unchanged (`jsondiff_pre5_final5.txt`).
- The game's fades: worst 0.179, unchanged (`fade2_final5.txt`, `fade3_final5.txt`); the glaive in his torso as clips fade in
  (`fadeweapon_final5.txt`) as `fadeweapon_final4.txt` but the four clips' lines, none past 0.05 at any fade (P1 Guandao_L2's
  0.2 s fade in 0.047 -> 0.031). The weapon in his legs: as `legsall_final4.txt`, line for line.
- Rendered mesh at every frame, finK2 -> finK3 (`msetcmp_finK2_finK3.txt`): robes and ribbons 148 -> 149 pairs, sum 1.422 -> 1.426;
  arm-in-weapon 154 -> 152 (2.955 -> 2.945); weapon-in-arm 38 -> 39 (0.223 -> 0.224); other 157 -> 153 (2.271 -> 2.260); deepest
  unchanged in every group. One robe pair deeper and none shallower (`cloth_changes_finK2_finK3.txt`), four other pairs deeper and ten
  shallower (`rest_changes_finK2_finK3.txt`); all listed above.
- Arm x-ray past 0.18 on the rendered mesh: eleven clips -> nine (section 8 item 1).
- `tools/verify_all.sh`: all 14 stages pass, exit 0, "Shen integration: ok", `test_cloth_sim` P1 and P2 ok (`results/verify_all_1112.log`).
- Studio: checked after this commit, all four within 0.0091 rig units of the solver (section 6, `results/studio_playback.txt`).
  Multiplayer and device profiling: not run (section 7).

## 14. The game run with the 11-12 clips, and the cloth's native code (11-12, later)

Studio over stdio: no Roblox Studio tools were attached to this session, so `scripts/studio_mcp.py` drives Roblox's own StudioMCP.exe
(as `tools/run_studiomcp.py` launches it) with a JSON list of tool calls. `places/AsurasPath.rbxlx` was opened in Studio from the repo
and never saved; HttpEnabled stayed false.

The game's own run (Play, 25 s, the console read back): server, campaign, Colosseum and client all start. Two messages:
- "Native code generation of script ReplicatedStorage.AsurasPath.Shared.ClothSim failed ... Function 'step' at line 630 encountered an
  internal lowering failure. Script will be interpreted." A real defect, fixed below.
- "ContentId rbxassetid://203785492 failed due to: Asset type does not match requested type" (three times): the Rojo plugin preloading
  its notification sound as an image (`tools/qa/rojo_preloader_fix/README.md`); editor-only, not the game's. Left alone.

The cloth step (`src/shared/ClothSim.luau`):
- Reproduced locally with luau-compile (`--codegennull -O2 -t1`): on x64 and x64_ms (Windows PCs) register allocation failed for
  one function ("regalloc failed: 1", the spill slots ran out), so Studio and Windows clients ran the whole step interpreted; arm64
  (phones, Macs) compiled it. The fault was the volume-placement loop: twelve limb-matrix terms and six end points live at once.
- Fix, arithmetic unchanged: `Sim.step` split into module-level functions, each block as it stood (moveParticles, placeCap,
  placeCaps, keepOut, pullLinks, pushMiddles, gripHaft, fingerBone, dropOrb, circleOrb, turnBones), and the placement's two end points
  each through `limbPoint` (the same sums in the same order). x64, x64_ms and a64: "regalloc failed: 0".
- Also bit-identical: in the later surface passes each volume's fields are copied to flat arrays once a pass, and a sample beyond the
  first pass's bounding sphere is skipped (a sample's clearance is never more than the margin that sphere allows, so nothing past it
  could be pushed).
- Proof the cloth is the same: a dump of every particle position, bone rotation and grip value over 200 steps of moving limbs, both
  phases, 1, 2 and 3 passes, the orbs dropped at step 150 (33,864 numbers at 17 digits), byte-identical before and after, interpreted
  and native. `tools/test_cloth_sim.py` unchanged (P1 rest drift 1.143, trail 0.17; P2 1.187, 0.39). luau-analyze: the same five
  warnings as before.
- In Studio with the new source (a Play session; the edit copy replaced in memory, never saved): the codegen message is gone, nothing
  new on the console. Shen spawned by the QA probe (phase 1, 123 skin bones): 120 bones moved within a second, none non-finite. Stills
  taken then show only the game's intro card, so they prove nothing about the cloth and are not counted.
- Cost, timed in that Studio session on this PC with bakes running alongside (so loose): about 6-8 ms a step, P1 and P2, at 3, 2
  or 1 link passes alike; the surface passes are most of it (P1, ms a step: first pass, positions 1.2 and volumes 1.1; the five
  later passes, volumes 2.0 -> 1.4 after the flat arrays, positions 0.7, middles 0.8; keepOut 0.8, pushMiddles 0.55). The surface
  passes run 4 + 2 a step on every graphics tier (`BossCloth` Rates change only the link passes and the step rate), so the Low tier
  saves only its halved rate. Fewer surface passes on Low would change how the cloth looks; not done, noted as open (section 8).


### Third pass (2026-11-09): solver causes, re-authored clips, blade roll

Solver and interpolation (`shen_lib.py`):

| Problem | Cause | Change |
|---|---|---|
| Upper arm pushed into the chest while the hand reached across (phase 2 Blood Wave lead arm 0.37) | the shoulder-blade glide toward an out-of-reach hand moved the shoulder in toward his middle as well as forward | `protract_dir`: the glide goes forward round the ribs, out or a little up, never in |
| Spine bent toward the lead hand while it was letting go | `spine_reach` stepped by the full grip even while the hand was reaching elsewhere | the step is weighted by the share of the grip (hold squared, less the reach) |
| Phase 1 Death right arm 0.02 -> 0.22 in the chest at f33 | a last `settle` after `clear_torso` spread the neighbours' weapon over the frames it had cleared | removed; `depop` covers the pops it was there for |
| Haft tilts that cleared the weapon from the arm put the arm into the chest | `tilt_haft` did not see the arm's torso depth | each candidate tilt pays for torso depth beyond the frame's own |
| Blade edge turned ~90 deg for one frame and back at the end of most cuts (Strike f22, Feint f15, Rending Arc f64, Blood Wave f43, Skyfall f57, Phantom Drift f39, Hesitant Moon f46, Prayer Beads f42, Abbot Sweep f39) | cuts key the edge as a 2-degree difference of the haft (length 0.035); splined against the guard's unit edge its direction swung | direction channels are interpolated as unit vectors; keyed out-and-back edge flips 1.55 -> none |
| The pop check could not see the blade's roll | it followed the fist, the haft line and the slide only | an `edge` track (a point 2.5 out along the edge), limit 0.45 like the blade |

Time-scaled spline tangents were also tried. They fixed no edge flip that unit keys had not, and changed every cut's return to the guard enough to put arms back in the chest in five clips that had passed (phase 2 Strike, Death, Skyfall, Transform; phase 1 L3). Reverted.

Re-authored clips (`shen_clips.py`). Most remaining arm-in-chest cases were cuts left in front of his feet while his body lunged 0.6-1.2 forward, so his arms folded against his chest to reach them:

| Clip | Before | Change | After |
|---|---|---|---|
| P2 Crimson Embrace | both arms 0.37 in the chest, lead hand 1.17 off the haft, reach pop 0.35 | regrip only once the glaive is back in front; the trailing glaive follows the lunge | passes (0.16 / 0.14) |
| P2 Blood Wave | right 0.29, left 0.37 | twist arrives at 0.5 s, not 0.35 | ARMS_BW |
| P1 Hesitant Moon | fist pop 0.62, lead hand 0.33 short, arms 0.20 / 0.22 | the hang is the falling cut's own first pose, 1.0 out to his right and 0.1 forward, so the butt hangs outside his hip | ARMS_HM |
| P1/P2 Flourish | fist went 1.5 behind his back at the catch (pop 0.29-0.33); P2 right 0.22 | pinwheels start and end on the guard's line, haft forward, so the catch slides the weapon forward, not into the floor | ARMS_FL |
| P1/P2 Returning Tide (L2) | fist hopped 0.6 across his belly f6-7 (0.29-0.36); P2 right 0.29 | follow-through carries the fist out to his right and forward (`carry`) | ARMS_L2 |
| P2 Rending Arc | right 0.35, left 0.38 | second and third cuts go forward with the lunge | ARMS_RA |
| P2 Phantom Drift | right 0.20 | cut forward with the glide | ARMS_PD |
| P2 Green Dragon (Heavy) | right 0.27, regrip pop 0.26 | sweep 0.3 forward, 0.18 out; the blow lands within 0.07 of where it did | ARMS_HV |
| P2 Charging Crescent | right 0.18, left 0.23 | cut forward with the lunge (blow 0.27 further along it) | ARMS_GR |
| P2 Run | right 0.20, left 0.22 most of the loop | past a 20 deg lean the hands go 0.45 forward, 0.1 down | ARMS_RF |
| P2 Deathblow Victim | glaive dropped flat to the floor and jittered f45-66 | phase 2's bowed grip further out | ARMS_DB |

# Why the arm x-ray and the validator disagree (phase 2, 2026-11-11)

`scripts/xray_why.py` replays review.py's arm x-ray (UpperTorso, both arms and hands) on the final review shots and sorts every lit vertex by
what the validator (`shen_lib.arm_torso_world`, dense) would do with it. It reproduces every logged x-ray depth exactly (render_w10*.log,
render_dp11/15.log). Raw output: `work/shen_repair/xray_why_f2.json` (local).

The two measures count different skin:
- **x-ray**: every vertex of the arm meshes, minus what is already lit in the bind pose.
- **validator**: about 500 evenly thinned samples per upper arm (`work/shen_import/surface_p2.npz`; the meshes have about 12,000 vertices),
  minus any skin within 0.05 of the torso solid at rest (`_torso_free`).

Classes: **arm** = follows an arm or hand bone most and sat at least 0.05 clear of the chest at rest (the validator's kind of skin);
**near** = follows an arm bone most but sat within 0.05 of the chest at rest (left out by the validator); **torso** = arm-mesh vertex that
follows UpperTorso most (filed under the torso by the validator).

Review shots are Idle 0.6 s, the clip, Idle 0.8 s with 0.2 s smoothstep fades (shots_fade.py). Deepest per stretch (arm / near / torso):

| Shot | Fade in from Idle | Clip | Fade out to Idle | Deepest past 0.18 is |
|---|---|---|---|---|
| P2 Death | 0.088 / 0.107 / 0.073 | 0.129 / **0.181** / 0.121 | **0.243 / 0.252** / 0.167 | the fade out (see below) |
| P2 DeathblowVictim | **0.275** / 0.137 / 0.175 | **0.188 / 0.198 / 0.219** | 0.047 / 0.081 / 0.086 | the 0.2 s fade in; in the clip f36 |
| P2 RendingArc | 0.111 / 0.132 / 0.089 | 0.175 / **0.200** / 0.128 | 0.126 / **0.182** / 0.124 | near (left armpit, f58) |
| P2 PhantomDrift | 0.083 / 0.103 / 0.069 | 0.147 / **0.186** / 0.129 | 0.134 / **0.186** / 0.123 | near |
| P2 Transform | 0.088 / 0.100 / 0.071 | 0.154 / **0.183** / 0.118 | 0.138 / 0.179 / 0.118 | near |
| P2 Feint | 0.089 / 0.126 / 0.077 | 0.152 / **0.181** / 0.124 | 0.166 / **0.183** / 0.120 | near |
| P2 Guandao_L1 | 0.087 / 0.114 / 0.075 | 0.155 / **0.182** / 0.131 | 0.092 / 0.116 / 0.082 | near |
| P2 Guandao_L2 | 0.165 / 0.111 / 0.069 | 0.176 / **0.182** / 0.126 | 0.132 / 0.144 / 0.126 | near |
| P2 HitLightFront | 0.136 / 0.167 / 0.103 | 0.117 / **0.182** / 0.121 | 0.138 / **0.182** / 0.121 | near |
| P2 Guandao_L3 | 0.104 / 0.142 / 0.069 | 0.173 / 0.180 / 0.103 | 0.131 / 0.153 / 0.103 | (0.180, the rise) |

What that means, clip by clip:
- **Eight clips (RendingArc, PhantomDrift, Transform, Feint, L1, L2, HitLightFront, L3):** the depth past 0.18 is "near" skin, upper-arm
  skin at the shoulder seam: the deepest such vertex in each sat 0.013-0.046 from the chest at rest, skinned 64-85 % to the arm bone. In
  Feint, PhantomDrift and HitLightFront it is as deep in the fade back to Idle as in the clip. For the skin the validator does count, the
  clip's deepest is 0.117-0.176: under its 0.18 flag, but L2 (0.176), RendingArc (0.175) and L3 (0.173) are past the 0.17 wall.
- **P2 Death 0.252:** only in the review shot's fade from his fallen last pose back to Idle (shot f110). The game never plays that:
  after KO it holds Death's last frame (`src/client/Controllers/BossAnimations.luau:226`, "a corpse never goes back to idle").
  Within the clip: 0.181 armpit skin, 0.129 for the validator's kind of skin.
- **P2 DeathblowVictim 0.275:** the last frame of the review's 0.2 s fade in from Idle (shot f23). At the game's 0.15 s reaction fade it
  is 0.114 (fade3_final2.txt). Within the clip, at shot f36 (clip f18), the top of his left shoulder: 0.219 for arm-mesh skin that follows
  the chest, 0.198 armpit skin, and **0.188 for skin of the validator's kind** (vertex 802, 0.057 from the chest at rest, 55 % arm). The
  validator reads 0.160 there because its ~510 left-upper-arm samples miss that spot.

Watched (normal and x-ray stills, front and quarter, `work/shen_repair/why/`): at RendingArc f58 and DeathblowVictim f36 the lit vertices
sit at the armpit and the top of the left shoulder. In the normal render nothing comes through the front of his chest at either frame.

Not changed: the validator, its thresholds and its samples. Everything here stays listed as open in REPORT.md section 8.

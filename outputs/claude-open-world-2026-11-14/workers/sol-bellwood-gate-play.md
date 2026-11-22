# Bellwood gate in Development

## Local regression

The 88 raw landmark and audio files matched asset snapshot `659168d` byte for byte. The gate's two upload parts measured 19,159,544 and 7,306,244 bytes. Roblox approved both, and Studio read back all seven gate meshes. The gate bake has 70,016 triangles across seven meshes, with a maximum of 16,880 and 2048×2048 maps. The upload operation and asset IDs are in [the landmark ledger](mac-90-landmark-ledger.json).

All 14 stages of `verify_all.sh` passed with Studio Play stopped. The landmark layout passed 40 checks, the loader passed 182 and terrain ordering passed 496. A concurrent verifier run hit the slice dressing timing threshold during Play. The isolated rerun passed all 1,371 slice checks.

## Studio integration

- Initial Play exposed the root hull across both towers. A detached raycast hit that hull up to 26.7 studs above the centre of the stair. The shared roots now render without collision. The stone stair retains precise collision.
- The original fall guard sent the avatar back to Bell Terrace when it stood at world Y 155 in the built basin. The guard now uses the lower carved floor once the landmark reports the carve complete. It still rescues below the carved floor.
- In the revised disposable build, Bellwood was ready at the 326-second observation. The avatar walked from gate-local Z −2.0 on stone to Z −44.1 on the grassy terrace. The rescue counter stayed at zero. The terrace ends at the cliff and still needs a route to the forest.
- The edit source digest matched `295 / 3653293 / 578572382`. The disposable build's SHA-256 stayed `9eef84a03b987b2f90c2a3fdec9bd278a4329bf6df573386c304ae70894a75b6` after Play. Studio confirmed Save to Roblox As for Development place `118614906972571`.

## Mac Studio rendering

Four-second foreground samples, one local client, rain, in-game time about 12.61. No multiplayer or device profiling was run. The startup observations come from different workloads and cannot establish a speedup.

| View | Average fps | 95th-percentile frame time |
|---|---:|---:|
| [Tunnel exit](../captures/mac/bellwood_face/sol_gate_exit.jpg) | 60.0 | 18.9 ms |
| [Gate close-up](../captures/mac/bellwood_face/sol_gate_gate.jpg) | 60.0 | 19.6 ms |
| [Landing](../captures/mac/bellwood_face/sol_gate_landing.jpg) | 60.1 | 19.9 ms |

## Model and scene review

- The twin roof silhouettes and left/right placement read clearly. In the [gate bake](../captures/mac/bellwood_face/gate_towers_bake_sheet.jpg), the blunt upper root ends and sharp bends read as cut timber. Taper them into the stone and branch across the roof edges. Inspect the dark ribbon patches in the bake before choosing how much weathering to keep.
- In the exit capture, both façades lose their material detail in the rain despite the daytime exposure. Test basin-local fill and warmer eave accents before rebaking the stone. Use the same camera and weather for the comparison.
- The repeating dark cliff strata and detached foliage are visible above the temple. Break up the strata and ground the rim vegetation to the sculpted surface.
- The hall manifest gives a width of 90.4 studs. The 120-stud target applies to the temple complex, so measure the dressed composition with the colonnade in place before resizing the hall.

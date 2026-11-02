# Third-party notices

Asura's Path uses no third-party code files, data or assets from the projects below. Its Luau modules are independent implementations that adapt published techniques, and they name their sources in a comment. These notices are kept because some of that work follows upstream expressions closely (the critically damped offset decay in particular). Source-symbol to local-code to test mapping: `outputs/combat-recovery-2026-11-02/INTEGRATION_MAP.md`.

| Project | Pinned commit | License | Used for | Local code |
|---|---|---|---|---|
| Orange Duck, Motion-Matching (github.com/orangeduck/Motion-Matching) | `57b7250e0d34a4e456a34d47e24c2f05fdcc711e` | MIT (code; its LaFAN1-derived data is not MIT and is not used) | `spring.h` `decay_spring_damper_exact`, `inertialize_transition`, `inertialize_update`; `controller.cpp` `contact_update`, `ik_two_bone`, `adjust_character_position_by_velocity` | `src/client/Controllers/ActorPose.luau`, `src/simulation/AnimationTiming.luau`, `src/simulation/FootStep.luau` |
| Sixze et al., ALS-Refactored (github.com/Sixze/ALS-Refactored) | `b754d6f0f2bb03741d301f8fb88077ebfe561e17` | MIT | `AlsAnimationInstance.cpp` `RefreshFootLock` rules; pelvis offset concept | `src/simulation/FootStep.luau`, `src/client/Controllers/ActorPose.luau` |
| Wolfire Games, Overgrowth (github.com/WolfireGames/overgrowth) | `245fe4828631c84c0023d29d1525f5716ccb6106` | Apache-2.0 (code; its data and assets have other terms and are not used) | `Data/Scripts/aschar.as` `HandleFootStance` concept: a foot steps when stance drift exceeds a limit | `src/simulation/FootStep.luau` |
| Jose Luis Ponton, MotionMatching (github.com/JLPM22/MotionMatching) | `35fc8ee9a0fd97f12de458ea81eaef7c8219d87a` | MIT | Cross-check of the offset form of inertialization; its sample mocap is not used | `src/client/Controllers/ActorPose.luau` |

Epic Fight (GPL-3.0) and Better Combat (all rights reserved) informed phase and contact coordination concepts only. Nothing was copied from them and no notice is owed.

## Orange Duck Motion-Matching

MIT License

Copyright (c) 2021 Daniel Holden

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## ALS-Refactored

MIT License

Copyright (c) 2026 Sixze, Caleb Longmire, Doğa Can Yanıkoğlu, and Advanced Locomotion System Refactored contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## JLPM22 MotionMatching

MIT License

Copyright (c) 2022-present Jose Luis Ponton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Overgrowth

Overgrowth is licensed under the Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0). Copyright Wolfire Games. Its repository at the pinned commit has no NOTICE file. `src/simulation/FootStep.luau` is an independent Luau implementation of the stepping concept, not a copy of `aschar.as`, and is provided on the terms of this project.

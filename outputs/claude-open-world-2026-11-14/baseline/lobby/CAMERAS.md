# Fixed lobby cameras (before overworld geometry)

Build identity: places/AsurasPath.rbxlx sha256 a353dd00028eb3bf…, script digest `scripts 286 bytes 2859366 digest 462022588` (matches `tools/studio_mcp.py --digest`), HEAD fb51a42. Captured 2026-11-15 in a Studio Play solo session; region Sanctuary; client Lighting ClockTime 17.40, Brightness 2.20 (Sanctuary golden-hour profile, no weather exists).
Setup (labelled, capture-only): all PlayerGui ScreenGuis disabled; camera forced each frame by `RunService:BindToRenderStep("ClaudeCaptureCam", Last+50)` with `CameraType = Scriptable`. Retake "after" with identical CFrames and setup.

| ID | File | CFrame.lookAt(eye, target) | Bearing | Demonstrates |
|---|---|---|---|---|
| L1 | before_L1_courtyard.jpg | (0,640,1010) → (0,605,880) | N | plaza, bonfire, halls, colossus |
| L2 | before_L2_NW_overworld_bearing.jpg | (0,640,900) → (-4000,500,-3500) | ~310° | direction of the overworld; condition C check |
| L3 | before_L3_west.jpg | (0,640,900) → (-4000,550,600) | ~266° | west horizon toward the overworld |
| L4 | before_L4_elevated_overview.jpg | (260,820,1320) → (0,600,760) | ~335° | whole lobby, tree, cloud sea |
| L5 | before_L5_north.jpg | (0,640,900) → (0,500,-2500) | N | gateway stair and colossus; north horizon |

Condition C: after blockout, retake L1–L5. If any overworld silhouette is visible, hide overworld landmarks for lobby players (no lobby fog/lighting change).

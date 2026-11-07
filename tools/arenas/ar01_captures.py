#!/usr/bin/env python3
"""AR01 before/after capture calls for tools/studio_mcp.py (seeded Studio cameras, not earned play).

    python tools/arenas/ar01_captures.py STUDIO_ID OUT_CALLS.json [--no-play]
    python tools/studio_mcp.py OUT_CALLS.json --images outputs/environment-production-2026-11-06/AR01/<before|after>

The three audit views keep their 5 November eye/look (outputs/visual-audit-2026-11-05/views.csv); the rest
are fixed AR01 views shared by the before and after sets. Captures use Studio's viewport at its current
quality and FOV 70; the player stands in the Hall of Champions with every boss marked defeated.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VIEWS = {
    "a06_arena": ([0, 6, -1897], [0, 8, -1990]),
    "a11_facade_diagnostic": ([0, 10, -1855], [0, 14, -1877]),
    "qh_a03_champions_n": ([0, 6, -1784], [-26, 6, -1810]),
    "ar01_entrance": ([0, 7, -1866], [0, 9, -1990]),
    "ar01_centre": ([20, 7, -1985], [-100, 12, -2010]),
    "ar01_corner": ([-110, 7, -2075], [0, 10, -1960]),
    "ar01_return": ([0, 7, -2078], [0, 12, -1895]),
    "ar01_far_horizon": ([0, 9, -1905], [-70, 34, -2400]),
    "ar01_cavea_east": ([60, 9, -1960], [150, 20, -1990]),
    "ar01_top_down": ([0, 330, -1985], [0, 0, -1986]),
}
STAND = (0, 3.3, -1870)
# Client: a scripted camera at FOV 70 and the HUD hidden for the capture (restored by Stop).
# The game's camera controller rewrites the camera every frame, so the shot is held from a later render step.
CAMERA = """local RS = game:GetService("RunService")
local cam = workspace.CurrentCamera
_G.AR01Target = CFrame.lookAt(Vector3.new(%s), Vector3.new(%s))
pcall(function() RS:UnbindFromRenderStep("AR01Cam") end)
RS:BindToRenderStep("AR01Cam", Enum.RenderPriority.Last.Value + 50, function()
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 70
	cam.CFrame = _G.AR01Target
end)
for _, g in game.Players.LocalPlayer.PlayerGui:GetChildren() do
	if g:IsA("ScreenGui") then g.Enabled = false end
end
task.wait(0.5)
return tostring(cam.CFrame.Position)"""


def main() -> int:
    studio, out = sys.argv[1], Path(sys.argv[2])
    play = "--no-play" not in sys.argv
    setup = (ROOT / "tools/qa/AR01CaptureSetup.luau").read_text(encoding="utf-8")
    setup = setup.replace("STAND_X", str(STAND[0])).replace("STAND_Y", str(STAND[1])).replace("STAND_Z", str(STAND[2]))
    calls = []
    if play:
        calls += [["start_stop_play", {"studio_id": studio, "is_start": True}], ["__sleep", 30]]
    calls += [["execute_luau", {"studio_id": studio, "datamodel_type": "Server", "code": setup}], ["__sleep", 14]]
    # Warm-up: the region's grade and the night sky take several seconds to settle after the move.
    warm = CAMERA % ("0, 7, -1866", "0, 9, -1990")
    calls += [["execute_luau", {"studio_id": studio, "datamodel_type": "Client", "code": warm}], ["__sleep", 12],
              ["screen_capture", {"studio_id": studio, "capture_id": "_warmup"}], ["__sleep", 4]]
    # The first frames after a far camera cut can come back black while the region streams in, so the three
    # audit views are visited once uncaptured before the captured pass.
    for name in ("a06_arena", "a11_facade_diagnostic", "qh_a03_champions_n"):
        eye, look = VIEWS[name]
        calls += [["execute_luau", {"studio_id": studio, "datamodel_type": "Client",
                                    "code": CAMERA % (", ".join(map(str, eye)), ", ".join(map(str, look)))}], ["__sleep", 6]]
    for name, (eye, look) in VIEWS.items():
        code = CAMERA % (", ".join(map(str, eye)), ", ".join(map(str, look)))
        calls += [["execute_luau", {"studio_id": studio, "datamodel_type": "Client", "code": code}], ["__sleep", 4],
                  ["screen_capture", {"studio_id": studio, "capture_id": name}]]
    if play:
        calls.append(["start_stop_play", {"studio_id": studio, "is_start": False}])
    out.write_text(json.dumps(calls, indent=1), encoding="utf-8")
    print("wrote", len(calls), "calls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

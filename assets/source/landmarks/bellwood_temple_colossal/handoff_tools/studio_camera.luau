local run = game:GetService("RunService")
local mode = "__VIEW__"
local frame = assert(workspace:GetAttribute("SolTempleFrame"))
local exit = assert(workspace:GetAttribute("SolBasinExit"))
local camera = workspace.CurrentCamera
local views = {
    front = {Vector3.new(0, 45, 580), Vector3.new(0, 320, -85), 72},
    east = {Vector3.new(-710, 200, 130), Vector3.new(0, 350, -86), 75},
    west = {Vector3.new(710, 200, 122), Vector3.new(0, 350, -86), 75},
    rear = {Vector3.new(0, 210, -720), Vector3.new(0, 375, -95), 74},
    above = {Vector3.new(60, 1040, 280), Vector3.new(0, 300, -88), 72},
    approach = {Vector3.new(0, 7, 267), Vector3.new(0, 237, -40), 80},
    interior = {Vector3.new(5, 121, -53), Vector3.new(0, 126, -110), 70},
    eastGuardian = {Vector3.new(-85, 52, 248), Vector3.new(-54.54, 34, 202.95), 52},
    westGuardian = {Vector3.new(88, 58, 240), Vector3.new(54.02, 38, 193.55), 52},
    lowerFork = {Vector3.new(175, 144, 154), Vector3.new(115, 104, 68), 55},
    upperFork = {Vector3.new(350, 477, 318), Vector3.new(130, 392, -101), 45},
}
local a, b, fieldOfView
if mode == "exit" then
    local toward = (frame.Position - exit) * Vector3.new(1, 0, 1)
    a, b, fieldOfView = exit + toward.Unit * 12, frame * Vector3.new(0, 315, -100), 75
else
    local view = assert(views[mode], mode)
    a, b, fieldOfView = frame * view[1], frame * view[2], view[3]
end
for _, gui in game.Players.LocalPlayer.PlayerGui:GetChildren() do
    if gui:IsA("ScreenGui") then gui.Enabled = false end
end
run:UnbindFromRenderStep("SolBasinCapture")
run:BindToRenderStep("SolBasinCapture", Enum.RenderPriority.Last.Value + 10, function()
    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = fieldOfView
    camera.CFrame = CFrame.lookAt(a, b)
end)
return {eye = tostring(a), target = tostring(b)}

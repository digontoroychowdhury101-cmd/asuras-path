local run = game:GetService("RunService")
local player = game.Players.LocalPlayer
local char = assert(player.Character)
local humanoid = assert(char:FindFirstChildWhichIsA("Humanoid"))
local root = assert(char:FindFirstChild("HumanoidRootPart"))
local route = game.HttpService:JSONDecode(assert(workspace:GetAttribute("SolBasinRoutePoints")))
local binding = "SolBasinRouteWalk"
local i, arrivedAt = 2, os.clock()
local function finish(reason)
    run:UnbindFromRenderStep(binding)
    humanoid:Move(Vector3.zero, false)
    root:SetAttribute("SolRouteReason", reason)
end
root:SetAttribute("SolRouteReason", "running")
run:BindToRenderStep(binding, Enum.RenderPriority.Input.Value + 2, function()
    local p = route[i]
    if not p then finish("complete"); return end
    local here = root.Position
    local d = Vector3.new(p.X - here.X, 0, p.Z - here.Z)
    if d.Magnitude < 1.55 then
        root:SetAttribute("SolRouteIndex", i)
        i += 1
        arrivedAt = os.clock()
    elseif os.clock() - arrivedAt > 7 then
        finish("stalled at " .. i .. " " .. p.Kind .. " distance " .. tostring(d.Magnitude) .. " position " .. tostring(here))
    else
        humanoid:Move(d.Unit * math.clamp(d.Magnitude / 4, .45, 1), false)
    end
end)
return "walking " .. #route .. " points using the character controller"

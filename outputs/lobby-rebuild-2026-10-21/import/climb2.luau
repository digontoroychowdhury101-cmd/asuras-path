local RunService = game:GetService("RunService")
local player = game:GetService("Players").LocalPlayer
local h = player.Character:FindFirstChildOfClass("Humanoid")
local root = player.Character.HumanoidRootPart
root.CFrame = CFrame.lookAt(Vector3.new(-76, 603.1, 915.3), Vector3.new(-76, 603.1, 930))
local log, t0, phase = {}, os.clock(), "north"
local conn = RunService.RenderStepped:Connect(function()
	local dir = if phase == "north" then Vector3.new(0, 0, 1) elseif phase == "south" then Vector3.new(0, 0, 1) else Vector3.zero
	h:Move(dir, false)
end)
local peak = 0
for i = 1, 70 do
	task.wait(0.1)
	peak = math.max(peak, root.Position.Y)
	if phase == "north" and root.Position.Y > 617.2 then phase = "south"; table.insert(log, string.format("top at %.1fs", os.clock() - t0)) end
	if phase == "south" and root.Position.Z > 921.5 then phase = "stop" end
	if i % 10 == 0 then table.insert(log, string.format("%.1f,%.1f,%.1f %s", root.Position.X, root.Position.Y, root.Position.Z, h:GetState().Name)) end
end
conn:Disconnect()
h:Move(Vector3.zero)
return string.format("peak %.1f | final %.1f,%.1f,%.1f %s | %s", peak, root.Position.X, root.Position.Y, root.Position.Z, h:GetState().Name, table.concat(log, " ; "))

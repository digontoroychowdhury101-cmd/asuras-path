--!nonstrict
-- Unmapped Studio-only client half of tools/qa/OmniPvP.server.luau (post-F26 step 2). Fires the
-- production ColosseumIntent / ActionIntent remotes on the server's cue; "Spin" turns this client's own
-- body every frame to test that a mid-swing spin cannot redirect a committed strike.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local player = Players.LocalPlayer
local event = RS:WaitForChild("OmniPvPQA", 120)
if not event or not Run:IsStudio() then return end
local net = RS:WaitForChild("AsurasPath"):WaitForChild("Net")
local seq = 0
net.ColosseumIntent.OnClientEvent:Connect(function(p)
	if p.action == "Challenge" and p.challenge then net.ColosseumIntent:FireServer({ action = "Respond", challenge = p.challenge, accept = true }) end
	event:FireServer("Observed", { action = p.action, phase = p.phase, ok = p.ok })
end)
event.OnClientEvent:Connect(function(op, arg)
	if op == "Challenge" then
		net.ColosseumIntent:FireServer({ action = "Challenge", target = arg })
	elseif op == "Position" then
		if player.Character then player.Character:PivotTo(arg) end
	elseif op == "Act" then
		seq = math.max(seq, arg.seq or 0) + 1
		net.ActionIntent:FireServer({ seq = seq, action = arg.action, time = workspace:GetServerTimeNow(), x = arg.x, z = arg.z })
	elseif op == "Spin" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local deadline = os.clock() + arg.seconds
		local conn
		conn = Run.Heartbeat:Connect(function()
			if os.clock() > deadline or not root.Parent then conn:Disconnect(); return end
			local p = root.Position
			root.CFrame = CFrame.lookAt(p, Vector3.new(arg.target.X, p.Y, arg.target.Z))
		end)
	elseif op == "Jump" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)
local deadline = os.clock() + 180
repeat task.wait(0.2) until player:GetAttribute("AsuraClientReady") or os.clock() > deadline
event:FireServer("Ready", { at = player.Character and tostring(player.Character:GetPivot().Position) })

--!nonstrict
-- Unmapped Studio-only client half of tools/qa/ShenMultiClient.server.luau (lane R2-5).
-- On the server's cue: moves the character, walks toward the Shen trigger, holds the gate prompt, reports what this
-- client sees (gate Sealed, own AsuraEncounter, Shen model Humanoid.Health), or leaves the test.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local event = RS:WaitForChild("ShenQA", 120)
if not event or not game:GetService("RunService"):IsStudio() then return end
local GATE = "FogGate_Gate_AshColosseum"

event.OnClientEvent:Connect(function(op, arg, arg2)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if op == "Position" then
		if character then character:PivotTo(arg) end
	elseif op == "MoveTo" then
		task.spawn(function()
			local deadline = os.clock() + (arg2 or 20)
			while humanoid and os.clock() < deadline do
				humanoid:MoveTo(arg)
				task.wait(0.5)
			end
		end)
	elseif op == "Prompt" then
		local part = workspace:FindFirstChild(GATE, true)
		local prompt = part and part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.3)
			prompt:InputHoldEnd()
		end
	elseif op == "Report" then
		local part = workspace:FindFirstChild(GATE, true)
		local found
		for _, d in workspace:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("AsuraLookKey") == "GrandmasterShen" then found = d break end
		end
		local h = found and found:FindFirstChildOfClass("Humanoid")
		event:FireServer("Report", {
			sealed = part and part:GetAttribute("Sealed"), encounter = player:GetAttribute("AsuraEncounter"),
			shenFound = found ~= nil, health = h and h.Health, maxHealth = h and h.MaxHealth,
		})
	elseif op == "Intent" then
		local remote = RS:FindFirstChild("ActionIntent", true)
		if remote then remote:FireServer({ seq = arg2, action = arg, time = workspace:GetServerTimeNow() }) end
	elseif op == "Leave" then
		game:GetService("StudioTestService"):LeaveTest()
	end
end)
local deadline = os.clock() + 180
repeat task.wait(0.2) until player:GetAttribute("AsuraClientReady") or os.clock() > deadline
event:FireServer("Ready")

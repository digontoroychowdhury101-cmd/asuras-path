--!nonstrict
-- Unmapped Studio-only client half of tools/qa/ColosseumMultiClient.server.luau (follow-up 23).
-- Fires the production ColosseumIntent / WagerIntent / ActionIntent remotes on the server's cue.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local event = RS:WaitForChild("ColoQA", 120)
if not event or not game:GetService("RunService"):IsStudio() then return end
local net = RS:WaitForChild("AsurasPath"):WaitForChild("Net")
local seq = 0
net.ColosseumIntent.OnClientEvent:Connect(function(p)
	if p.action == "Challenge" and p.challenge then net.ColosseumIntent:FireServer({ action = "Respond", challenge = p.challenge, accept = true }) end
	event:FireServer("Observed", { action = p.action, phase = p.phase, err = p.err, ok = p.ok, result = p.result, winner = p.winner })
end)
net.WagerIntent.OnClientEvent:Connect(function(p)
	event:FireServer("Wager", { action = p.action, matches = p.matches, message = p.message, payout = p.payout, refund = p.refund, qi = p.qi })
end)
event.OnClientEvent:Connect(function(op, arg)
	if op == "Challenge" then net.ColosseumIntent:FireServer({ action = "Challenge", target = arg })
	elseif op == "Enqueue" then net.ColosseumIntent:FireServer({ action = "Enqueue" })
	elseif op == "Position" then if player.Character then player.Character:PivotTo(arg) end
	elseif op == "WagerRefresh" then net.WagerIntent:FireServer({ action = "Refresh" })
	elseif op == "Wager" then net.WagerIntent:FireServer({ action = "Wager", match = arg.match, fighter = arg.fighter, amount = arg.amount })
	elseif op == "Attack" then
		seq = arg or 0
		for _ = 1, 6 do seq += 1; net.ActionIntent:FireServer({ seq = seq, action = "Light", time = workspace:GetServerTimeNow() }); task.wait(0.85) end
	elseif op == "Leave" then game:GetService("StudioTestService"):LeaveTest()
	elseif op == "Report" then
		local c = player.Character
		event:FireServer("Report", { duel = c and c:GetAttribute("AsuraDuel"), lighting = string.format("%s|%.2f|%s", tostring(Lighting.Ambient), Lighting.ClockTime, tostring(Lighting.OutdoorAmbient)),
			viewport = tostring(workspace.CurrentCamera.ViewportSize) })
	end
end)
local deadline = os.clock() + 180
repeat task.wait(0.2) until player:GetAttribute("AsuraClientReady") or os.clock() > deadline
event:FireServer("Ready", { at = player.Character and tostring(player.Character:GetPivot().Position) })

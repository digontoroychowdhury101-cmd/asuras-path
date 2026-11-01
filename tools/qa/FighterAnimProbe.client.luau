-- Studio QA (Client datamodel, execute_luau): records the local fighter's combat state against the tracks
-- FighterAnimations plays, for SECONDS, then stores a compact transition log in the LocalPlayer attribute
-- AsuraAnimProbe (read it back with a second execute_luau). Seeded diagnostic, not real play. Each row:
-- client time | server state, move, state elapsed | controller action key | strongest playing track
-- (id tail @ time, weight, priority) | blade tip in root space | horizontal root speed.
local SECONDS = tonumber(game.Players.LocalPlayer:GetAttribute("AsuraAnimProbeSeconds")) or 12
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Combat = require(game.ReplicatedStorage.AsurasPath.Simulation.CombatRules)
local player = game.Players.LocalPlayer
player:SetAttribute("AsuraAnimProbe", nil)
task.spawn(function()
	local character = player.Character
	local animator = character.Humanoid.Animator
	local root = character.HumanoidRootPart
	local rows, last, t0 = {}, "", os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > SECONDS then
			connection:Disconnect()
			player:SetAttribute("AsuraAnimProbe", HttpService:JSONEncode(rows))
			return
		end
		local snap = Combat.unpackString(character:GetAttribute("AsuraState"))
		if not snap then
			return
		end
		local best, bestRank = "-", -1
		for _, track in animator:GetPlayingAnimationTracks() do
			local rank = (if track.Priority == Enum.AnimationPriority.Core then -1 else track.Priority.Value) * 10 + track.WeightCurrent
			if track.WeightCurrent > 0.05 and rank > bestRank then
				bestRank = rank
				best = string.format("%s@%.2f w%.1f %s", string.sub(track.Animation.AnimationId, -6), track.TimePosition,
					track.WeightCurrent, track.Priority.Name)
			end
		end
		local weapon = character:FindFirstChild("AsuraWeapon")
		local tip = weapon and root.CFrame:PointToObjectSpace((weapon.CFrame * CFrame.new(0, 0, -weapon.Size.Z / 2)).Position)
		local key = snap.State .. tostring(snap.Move) .. tostring(character:GetAttribute("AsuraFighterAnimation")) .. string.sub(best, 1, 6)
		local velocity = root.AssemblyLinearVelocity
		local row = string.format("%.2f %s %s %.2f | %s | %s | tip %s | v%.0f", t, snap.State, tostring(snap.Move), snap.StateElapsed,
			tostring(character:GetAttribute("AsuraFighterAnimation")), best,
			tip and string.format("%.1f,%.1f,%.1f", tip.X, tip.Y, tip.Z) or "-", Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
		if key ~= last or snap.State == "Active" then
			table.insert(rows, row)
		end
		last = key
	end)
end)
return "probe started"

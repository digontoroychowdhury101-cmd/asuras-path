-- Studio QA (Client datamodel): logs the local fighter's state, move and FighterAnimations key for 6 s into the
-- LocalPlayer attribute AsuraCombo. Pair with tools/qa/jian_combo_clicks.ps1 (real OS clicks at combo timing).
local Combat = require(game.ReplicatedStorage.AsurasPath.Simulation.CombatRules)
local me = game.Players.LocalPlayer
me:SetAttribute("AsuraCombo", nil)
task.spawn(function()
	local rows, t0, last = {}, os.clock(), ""
	local animator = me.Character.Humanoid.Animator
	while os.clock() - t0 < 6 do
		local s = Combat.unpackString(me.Character:GetAttribute("AsuraState"))
		local top = ""
		for _, t in animator:GetPlayingAnimationTracks() do
			if t.Priority == Enum.AnimationPriority.Action2 and t.WeightCurrent > 0.5 then top = string.sub(t.Animation.AnimationId, -6) .. "@" .. string.format("%.2f", t.TimePosition) end
		end
		local row = s.State .. " " .. tostring(s.Move) .. " | " .. tostring(me.Character:GetAttribute("AsuraFighterAnimation")) .. " | " .. top
		if string.sub(row, 1, 30) ~= string.sub(last, 1, 30) then table.insert(rows, string.format("%5.2f ", os.clock() - t0) .. row) end
		last = row
		task.wait()
	end
	me:SetAttribute("AsuraCombo", table.concat(rows, "\n"))
end)
return "watching"

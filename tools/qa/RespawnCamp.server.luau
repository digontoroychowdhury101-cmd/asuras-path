--!nonstrict
-- Unmapped Studio-only probe (Windows acceptance, 2026-11-03): after the first player dies, samples four times a
-- second the player's state and position and every living foe within 80 studs of the player's respawn point
-- (state, distance), and counts KOs. JSON lands in the ServerStorage attribute AsuraRespawnLog. Used to check
-- that foes which killed the player at an altar go home instead of waiting on the respawn.
-- Evidence type: seeded Studio diagnostic (the death itself is ordinary AI play against an idle player).
if not game:GetService("RunService"):IsStudio() then
	return
end
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Characters = require(game:GetService("ServerScriptService").AsurasPath.Services.CharacterService)

local SPAWN = Vector3.new(60, 3, -1018) -- Altar_DesecratedCloister.Spawn
local samples, deaths, wasKO = {}, 0, false
local function round(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end
task.spawn(function()
	local t0 = os.clock()
	while true do
		task.wait(0.25)
		local p = Players:GetPlayers()[1]
		local e = p and Characters.GetEntity(p.UserId)
		if e then
			local ko = e.Fighter.State == "KO"
			if ko and not wasKO then
				deaths += 1
			end
			wasKO = ko
			if deaths > 0 then
				local near = {}
				for _, other in Characters.Entities() do
					if other.Kind == "Enemy" and other.Fighter.State ~= "KO" then
						local d = (other.Root.Position - SPAWN).Magnitude
						if d <= 80 then
							table.insert(near, { n = other.Model.Name, s = other.Fighter.State, d = round(d) })
						end
					end
				end
				local r = e.Root.Position
				table.insert(samples, { t = round(os.clock() - t0), s = e.Fighter.State, resp = e.Respawning == true,
					hp = round(e.Fighter.ActiveHP), p = { round(r.X), round(r.Y), round(r.Z) }, foes = near })
				if #samples > 240 then
					table.remove(samples, 1)
				end
				ServerStorage:SetAttribute("AsuraRespawnLog", HttpService:JSONEncode({ deaths = deaths, samples = samples }))
			end
		end
	end
end)
print("[RespawnCamp] on")

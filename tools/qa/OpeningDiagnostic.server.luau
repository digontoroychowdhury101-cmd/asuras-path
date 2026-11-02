--!nonstrict
-- Unmapped Studio-only diagnostic for the opening walk (seeded, never the earned result): holds the player's
-- body at 1 HP so the real kill, ore, milestone and objective path can be followed past a fight the MCP input
-- rate cannot win, and logs combat events so a strike that does not land can be explained. Stop removes it.
if not game:GetService("RunService"):IsStudio() then return end
local Services = game:GetService("ServerScriptService").AsurasPath.Services
local Characters = require(Services.CharacterService)
local Players = game:GetService("Players")
Characters.Subscribe(function(event: any)
	if event.Kind == "Hit" or event.Kind == "Block" or event.Kind == "DeflectSpark" or event.Kind == "KO" or event.Kind == "Whiff" or event.Kind == "Deathblow" or event.Kind == "StanceBreak" then
		print(string.format("[OpeningDiag] %s src=%s tgt=%s dmg=%s", event.Kind, tostring(event.Source), tostring(event.Target), tostring(event.Value)))
	end
end)
game:GetService("RunService").Heartbeat:Connect(function()
	for _, p in Players:GetPlayers() do
		local f = Characters.GetFighter(p.UserId)
		if f then f.KOProtected = true end
	end
end)
print("[OpeningDiag] on")

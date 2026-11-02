--!nonstrict
-- Unmapped Studio-only seeded fixture (Windows acceptance, 2026-11-03): marks the opening steps before the Cloister
-- as done on the local mock profile (Monastery Gate kindled, a Jian mastery point for Fought, one lore entry for
-- Read) so the Cloister -> Gao return leg can be driven with real input. Seeded, never the earned result; the
-- full ordinary-input journey still needs a human run. Stop removes it.
if not game:GetService("RunService"):IsStudio() then return end
local Services = game:GetService("ServerScriptService").AsurasPath.Services
local Persistence = require(Services.PersistenceService)
local World = require(Services.WorldService)
assert(Persistence.IsMock, "refuses anything but the local mock store")
local GATE = "Altar_MonasteryGate"
for _, p in game:GetService("Players"):GetPlayers() do
	local ok, err = Persistence.Transaction(p.UserId, function(profile: any)
		profile.weaponMastery.Jian = math.max(profile.weaponMastery.Jian or 0, 1)
		profile.inventory.LoreEntries.QA_OpeningSeed = true
		profile.souls.world.altars[GATE] = true
	end)
	local s = World.GetSession(p.UserId)
	if s and s.Altars then s.Altars[GATE] = true end
	World.Refresh(p.UserId)
	print("[OpeningMilestones]", ok, err, p:GetAttribute("AsuraOpening"))
end

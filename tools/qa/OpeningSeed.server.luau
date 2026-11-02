--!nonstrict
-- Unmapped Studio-only seeded fixture for Gao's panel: one Spirit Iron Ore and an owned Dao on the local mock
-- profile, so the panel can be driven with real clicks. Seeded, never the earned result. Stop removes it.
if not game:GetService("RunService"):IsStudio() then return end
local Services = game:GetService("ServerScriptService").AsurasPath.Services
local Persistence = require(Services.PersistenceService)
assert(Persistence.IsMock, "refuses anything but the local mock store")
for _, p in game:GetService("Players"):GetPlayers() do
	local ok, err = Persistence.Transaction(p.UserId, function(profile: any)
		profile.inventory.Materials.SpiritIronOre = (profile.inventory.Materials.SpiritIronOre or 0) + 1
		profile.inventory.Weapons.Dao = profile.inventory.Weapons.Dao or { Level = 0 }
		profile.qiEssence += game:GetService("ServerStorage"):GetAttribute("AsuraSeedEssence") or 0
	end)
	print("[OpeningSeed]", ok, err)
end

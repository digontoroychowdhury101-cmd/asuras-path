--!strict
-- Run with work/bin/luau/luau tools/combat_anim_coverage.luau (no Roblox runtime required).
-- Player weapon animation coverage: for every playable weapon and AnimationCatalog weapon/universal
-- key, whether FighterAnimations would play an authored clip (Custom id), and whether that clip is
-- the weapon's own or borrowed from its family. FighterAnimations skips slots without a Custom id,
-- so "none" means the action shows no action-layer motion at all. Evidence type: static catalog table.
local Catalog = require("../src/shared/AnimationCatalog")
local Weapons = require("../src/simulation/WeaponSchema")
local FAMILY = { Odachi = "Guandao", TwinDaggers = "Jian", ChainScythe = "Guandao", WarFan = "Dao", Catalyst = "Guandao",
	PrayerOfTheDefiled = "Guandao", CalamityBoneCleaver = "Guandao", HeavenPiercingGuandao = "Guandao" }
print("| Weapon | " .. table.concat(Catalog.WeaponKeys, " | ") .. " | authored | borrowed | none |")
print("|---|" .. string.rep("---|", #Catalog.WeaponKeys + 3))
for _, weapon in Weapons.WeaponKeys do
	local cells, own, borrowed, none = {}, 0, 0, 0
	for _, key in Catalog.WeaponKeys do
		local slot = Catalog.weapon(weapon, key)
		local cell
		if slot and slot.Custom then
			if FAMILY[weapon] then cell, borrowed = FAMILY[weapon], borrowed + 1 else cell, own = "own", own + 1 end
		else
			cell, none = "none", none + 1
		end
		table.insert(cells, cell)
	end
	print(string.format("| %s | %s | %d | %d | %d |", weapon, table.concat(cells, " | "), own, borrowed, none))
end
local missing = {}
for _, key in Catalog.UniversalKeys do
	local slot = Catalog.universal(key)
	if not (slot and slot.Custom) then table.insert(missing, key) end
end
print("")
print("Universal keys without an authored clip: " .. (if #missing == 0 then "none" else table.concat(missing, ", ")))

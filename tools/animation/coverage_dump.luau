-- Prints what AnimationCatalog and WeaponSchema actually resolve, as JSON, for tools/animation/coverage.py.
local Catalog = require("../../src/shared/AnimationCatalog")
local Weapons = require("../../src/simulation/WeaponSchema")
local function q(v: any): string
	return if v == nil then "null" else '"' .. tostring(v) .. '"'
end
local weapons = {}
for _, id in Weapons.WeaponKeys do
	local cells = {}
	for _, key in Catalog.WeaponKeys do
		local slot = Catalog.weapon(id, key)
		table.insert(cells, string.format('"%s":{"slot":%s,"custom":%s}', key, q(slot.Name), q(slot.Custom)))
	end
	local weapon = Weapons.Weapons[id]
	table.insert(weapons, string.format('"%s":{"grip":%s,"lights":%d,"name":%s,"slots":{%s}}', id, q(weapon.Grip), #weapon.Light, q(weapon.Name), table.concat(cells, ",")))
end
local universal = {}
for _, key in Catalog.UniversalKeys do
	table.insert(universal, string.format('"%s":%s', key, q(Catalog.Universal[key].Custom)))
end
local characters = {}
for definition, set in Catalog.Characters do
	local cells = {}
	for key, slot in set :: any do
		table.insert(cells, string.format('"%s":%s', key, q(slot.Custom)))
	end
	table.insert(characters, string.format('"%s":{%s}', definition, table.concat(cells, ",")))
end
local enemies = {}
for key, slot in Catalog.Enemies do
	table.insert(enemies, string.format('"%s":%s', key, q(slot.Custom)))
end
print(string.format('{"weapons":{%s},"universal":{%s},"characters":{%s},"enemies":{%s}}', table.concat(weapons, ","), table.concat(universal, ","), table.concat(characters, ","), table.concat(enemies, ",")))

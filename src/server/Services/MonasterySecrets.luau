--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasterySecrets
-- The optional discoveries of the Desecrated Monastery made into places (batch 15, #26, #44).
-- The once-empty strip west of the courtyard becomes the secret waterfall path: a postern in the
-- courtyard wall, stepping slabs and prayer-ribbon posts, a cliff that the waterfall pours from with
-- the cache behind the curtain, and a return through the breached back wall of the west prayer
-- hall (a bypass of the courtyard's south). The high rafter cache gets the drum tower it is named
-- for, its ladder outside the loft floor; the mausoleum gets a broken seal and a walk through the
-- graves. Chests, ledges and the ladder themselves are LootWorld's; this layer only stages them.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local Zones = require(Shared.MonasteryZones)
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Ruins = require(script.Parent:WaitForChild("MonasteryRuins") :: ModuleScript)

local Secrets = {}

local P = Kit.Palette
local G = Kit.GROUND
local SLATE, WOOD, FABRIC, BASALT = Enum.Material.Slate, Enum.Material.Wood, Enum.Material.Fabric, Enum.Material.Basalt
Secrets.Tower = { X = 92, Z = -1000, Floor = 29, Half = 4 } -- PagodaRafters loft (ArsenalCatalog cache)

-- Flat slabs along a polyline, tops at ground level; every `ribbons`-th turn gets a ribbon post.
local function walk(parent: Instance, path: { { number } }, rng: Random, ribbons: number?)
	for k = 1, #path - 1 do
		local a, b = Vector3.new(path[k][1], G, path[k][2]), Vector3.new(path[k + 1][1], G, path[k + 1][2])
		local steps = math.max(1, math.floor((b - a).Magnitude / 3.2))
		for s = 0, steps - 1 do
			local at = a:Lerp(b, (s + 0.5) / steps)
			Kit.part(parent, "PathSlab", Vector3.new(rng:NextNumber(2.4, 3), 0.5, rng:NextNumber(1.8, 2.3)),
				CFrame.lookAt(at, b) * CFrame.new(0, -0.25, 0) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0), P.Flag:Lerp(P.Moss, rng:NextNumber(0.1, 0.4)), SLATE)
		end
		if ribbons and k % ribbons == 0 then
			local post = Kit.part(parent, "RibbonPost", Vector3.new(0.4, 4.6, 0.4), CFrame.new(b + Vector3.new(2.2, 2.3, 0)), P.WoodDark, WOOD)
			Kit.part(parent, "PrayerRibbon", Vector3.new(0.08, 2.2, 0.5), post.CFrame * CFrame.new(0.2, 1, 0) * CFrame.Angles(0, 0, 0.2), P.Leaf, FABRIC, Kit.decor())
		end
	end
end

local function postern(parent: Instance)
	local group = Kit.folder("WestPostern", parent)
	for _, z in { -825.6, -834.4 } do
		Kit.part(group, "PosternPost", Vector3.new(1.4, 9, 1.4), CFrame.new(-82, G + 4.5, z), P.Lacquer:Lerp(P.WoodDark, 0.5), WOOD)
	end
	Kit.part(group, "PosternLintel", Vector3.new(1.6, 1, 10.4), CFrame.new(-82, G + 9.4, -830), P.WoodDark, WOOD)
	Kit.part(group, "FallenDoor", Vector3.new(3.6, 0.4, 7.4), CFrame.new(-87.5, G + 0.2, -823.5) * CFrame.Angles(0, 0.35, 0.05), P.WoodDark, WOOD)
	Fx.lantern(group, CFrame.new(-87, G, -836), false, 14)
end

-- Rock walls close the alcove on three sides; the waterfall (LootWorld) pours from the lip.
local function alcove(parent: Instance)
	local group = Kit.folder("WaterfallCliff", parent)
	local c = Zones.Alcove
	Kit.part(group, "CliffBack", Vector3.new(18, 30, 3), CFrame.new(c.X, G + 15, c.Z - 7.5), P.StoneDark, BASALT)
	for _, x in { -8, 8 } do
		Kit.part(group, "CliffShoulder", Vector3.new(3, 28, 7), CFrame.new(c.X + x, G + 14, c.Z - 2), P.StoneDark:Lerp(P.Moss, 0.2), BASALT)
	end
	Kit.part(group, "CliffLip", Vector3.new(18, 3, 7), CFrame.new(c.X, G + 28, c.Z + 2), P.StoneDark, BASALT)
	Kit.part(group, "PlungePool", Vector3.new(13, 0.1, 6), CFrame.new(c.X, G + 0.06, c.Z + 9), Color3.fromRGB(70, 132, 140), Enum.Material.Glass,
		{ Collide = false, Query = false, Transparency = 0.35 })
end

-- Timber drum tower whose loft floor is the PagodaRafters ledge; the ladder rises on its south face.
local function drumTower(parent: Instance, rng: Random)
	local group = Kit.folder("DrumTower", parent)
	local t = Secrets.Tower
	local top = t.Floor + 6.5
	for _, x in { -t.Half, t.Half } do
		for _, z in { -t.Half, t.Half } do
			Kit.part(group, "TowerPost", Vector3.new(1.2, top - G, 1.2), CFrame.new(t.X + x, (top + G) * 0.5, t.Z + z), P.Lacquer:Lerp(P.WoodDark, 0.5), WOOD)
		end
	end
	for _, y in { 10, 20 } do
		for _, z in { -t.Half, t.Half } do
			Kit.part(group, "Brace", Vector3.new(t.Half * 2, 0.6, 0.6), CFrame.new(t.X, G + y, t.Z + z), P.WoodDark, WOOD, Kit.decor())
		end
	end
	for _, edge in { { 0, t.Half }, { -t.Half, 0 }, { t.Half, 0 } } do -- loft rails; the ladder (south) side stays open
		local along = edge[1] == 0
		Kit.part(group, "LoftRail", Vector3.new(if along then t.Half * 2 else 0.4, 0.4, if along then 0.4 else t.Half * 2), CFrame.new(t.X + edge[1], t.Floor + 2.4, t.Z + edge[2]), P.WoodDark, WOOD, Kit.decor())
	end
	Ruins.roof(group, CFrame.new(t.X, top, t.Z), 13, 13, rng, true)
	Fx.lantern(group, CFrame.new(t.X - t.Half, t.Floor + 4.5, t.Z - t.Half - 0.6), true, 16)
end

local function mausoleum(parent: Instance, rng: Random)
	local group = Kit.folder("MausoleumSeal", parent)
	Kit.part(group, "BrokenSeal", Vector3.new(6, 0.5, 4.2), CFrame.new(-110, G + 0.25, -1067.2) * CFrame.Angles(0, 0.12, 0.03), P.StoneDark, SLATE)
	for _, x in { -115.6, -104.4 } do
		Kit.part(group, "SealTalisman", Vector3.new(0.06, 1.6, 0.7), CFrame.new(x, G + 4, -1064.6), Color3.fromRGB(214, 190, 120), FABRIC, Kit.decor())
	end
	Fx.lantern(group, CFrame.new(-102, G, -1070), false, 14)
	walk(group, Zones.GravePath, rng, nil)
end

function Secrets.Build(parent: Instance, rng: Random)
	local group = Kit.folder("Secrets", parent)
	postern(group)
	walk(Kit.folder("WaterfallPath", group), Zones.WestPath, rng, 2)
	alcove(group)
	drumTower(group, rng)
	mausoleum(group, rng)
end

return Secrets

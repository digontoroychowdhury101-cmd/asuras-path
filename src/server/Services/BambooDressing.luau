--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/BambooDressing
-- Bamboo Pass silhouettes and storytelling (batch 17). All decor: the thicket groves that read as the
-- pass's walls, frost-capped karst spires beyond them, the Bamboo Gate's lacquered torii lintels, the
-- whispering shrine's roof and wind ribbons, a fallen jade-root giant by tablet V, a pilgrim's hat and
-- staff where the first swordsman waits, the frost ridge's snow drifts and the moon gate's ring.
-- Collision lives in BambooPassLayout only.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Decor = require(script.Parent:WaitForChild("RegionDecor") :: ModuleScript)

local Dressing = {}
local P = Kit.Palette
local M = Enum.Material
local rgb = Color3.fromRGB
local FROST = rgb(222, 230, 234)

local function spire(parent: Instance, x: number, z: number, height: number, rng: Random)
	local base = CFrame.new(x, -2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local tower = Decor.kit("Karst", rng)
	if tower then -- fluted, frost-capped limestone tower (tools/blender/bamboo_karst_kit.py)
		Decor.placeKit(parent, tower, "Karst", base * CFrame.new(0, -4, 0), height + 4)
		return
	end
	local width = height * rng:NextNumber(0.22, 0.32)
	Kit.part(parent, "KarstSpire", Vector3.new(width, height, width * 0.8), base * CFrame.new(0, height / 2, 0)
		* CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), 0, math.rad(rng:NextNumber(-4, 4))), rgb(84, 88, 92), M.Rock, Kit.decor())
	Kit.part(parent, "FrostCap", Vector3.new(width * 0.9, 3, width * 0.7), base * CFrame.new(0, height - 0.5, 0), FROST, M.Snow, Kit.decor())
end

function Dressing.Build(map: Instance, layout: any, rng: Random)
	local groves = Kit.folder("BambooGroves", map)
	for _, grove in layout.Groves or {} do
		Decor.scatter(grove, rng, function(x, floor, z)
			Decor.bamboo(groves, x, floor, z, rng)
		end)
	end
	local set = Kit.folder("PassDressing", map)
	-- Karst spires beyond the thicket: the pass's skyline on both sides.
	for i = 0, 9 do
		local z = -1160 - i * 54
		spire(set, -186 + rng:NextNumber(-8, 8), z, rng:NextNumber(60, 110), rng)
		spire(set, 186 + rng:NextNumber(-8, 8), z - 20, rng:NextNumber(60, 110), rng)
	end
	-- Bamboo Gate: two lacquered lintels on the posts (x +/-9, z -1150), a weathered name board.
	Kit.part(set, "ToriiKasagi", Vector3.new(26, 1.4, 2), CFrame.new(0, 16.6, -1150), P.Lacquer, M.Wood, Kit.decor())
	Kit.part(set, "ToriiNuki", Vector3.new(21, 0.9, 1.2), CFrame.new(0, 13.4, -1150), P.WoodDark, M.Wood, Kit.decor())
	Kit.part(set, "GateBoard", Vector3.new(3, 2.4, 0.4), CFrame.new(0, 15, -1149.4), P.WoodDark, M.Wood, Kit.decor())
	-- The fallen jade-root giant beside tablet V (outside the veil, seen from the path).
	Kit.part(set, "JadeRootGiant", Vector3.new(38, 6, 6), CFrame.new(-56, 2.9, -1150) * CFrame.Angles(0, math.rad(68), 0),
		rgb(96, 128, 98), M.Wood, { Collide = false, Query = false, Shadow = true, Shape = Enum.PartType.Cylinder })
	-- A pilgrim's hat and staff where the first swordsman waits.
	Kit.part(set, "PilgrimHat", Vector3.new(0.5, 3.2, 3.2), CFrame.new(-4, 0.3, -1200) * CFrame.Angles(0, 0, math.rad(90)), rgb(150, 128, 86), M.Fabric,
		{ Collide = false, Query = false, Shadow = true, Shape = Enum.PartType.Cylinder })
	Kit.beam(set, "PilgrimStaff", Vector3.new(-6, 0.2, -1197), Vector3.new(-2, 0.5, -1205), 0.25, P.WoodDark)
	-- The whispering shrine: roof over its back screen, wind ribbons, a bronze bell.
	Decor.roof(set, CFrame.new(-36, 9.2, -1346), 22, 8, 2.4)
	for k = 0, 5 do
		local x = -45 + k * 3.6
		Kit.part(set, "WindRibbon", Vector3.new(0.5, 3.2, 0.05), CFrame.new(x, 7, -1344.6) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
			if k % 2 == 0 then P.Lacquer else rgb(214, 204, 176), M.Fabric, Kit.decor())
	end
	local bell = Kit.part(set, "ShrineBell", Vector3.new(1.6, 2, 1.6), CFrame.new(-28, 7.2, -1344.4), rgb(112, 91, 57), M.Metal, Kit.decor())
	bell.Shape = Enum.PartType.Ball
	-- Frost ridge: snow drifts, frost on the stones, mist pooling in the arena basin below.
	for _ = 1, 14 do
		Kit.part(set, "SnowDrift", Vector3.new(rng:NextNumber(6, 14), 0.6, rng:NextNumber(4, 10)),
			CFrame.new(rng:NextNumber(110, 156), 18.15, rng:NextNumber(-1296, -1388)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), FROST, M.Snow, Kit.decor())
	end
	for _, x in { -30, -18, 18, 28 } do
		Kit.part(set, "SnowDrift", Vector3.new(8, 0.6, 5), CFrame.new(x, 12.15, -1270 + rng:NextNumber(-12, 12)), FROST, M.Snow, Kit.decor())
	end
	Fx.mist(set, CFrame.new(0, 4, -1470), Vector3.new(170, 6, 170), 3, 26, FROST)
	Fx.mist(set, CFrame.new(-120, 6, -1250), Vector3.new(120, 8, 220), 2, 30)
	-- Moon gate: a half ring of stone voussoirs springing from the jambs (decor; the jambs are the layout's).
	for k = 0, 12 do
		local a = math.rad(k * 15)
		Kit.part(set, "MoonRing", Vector3.new(4.6, 2, 3), CFrame.new(math.cos(a) * 17, 18 + math.sin(a) * 17, -1577) * CFrame.Angles(0, 0, a + math.pi / 2),
			P.Stone, M.Slate, Kit.decor())
	end
	-- Baize's palisade: frost-rimed caps and torn prayer flags along its top.
	for z = -1386, -1556, -34 do
		Decor.banner(set, CFrame.new(-104, 9.5, z) * CFrame.Angles(0, math.rad(90), 0), 5, rgb(214, 204, 176))
	end
end

return Dressing

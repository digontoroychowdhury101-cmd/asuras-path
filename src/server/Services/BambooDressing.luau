--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/BambooDressing
-- Bamboo Pass silhouettes and storytelling (batch 17). All decor: the thicket groves that read as the
-- pass's walls, frost-capped karst spires beyond them, the Bamboo Gate's lacquered torii lintels, the
-- whispering shrine's roof and wind ribbons, a fallen jade-root giant by tablet V, a pilgrim's hat and
-- staff where the first swordsman waits, the frost ridge's snow drifts and the moon gate's ring, plus
-- uploaded Han pieces: valley-wall pagodas, shrine lanterns and cauldron, bixies, ridge pines and crags.
-- Collision lives in BambooPassLayout only.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Decor = require(script.Parent:WaitForChild("RegionDecor") :: ModuleScript)
local Ground = require(script.Parent:WaitForChild("CampaignTerrain") :: ModuleScript)
local Ecology = require(script.Parent:WaitForChild("BambooEcology") :: ModuleScript)
local World = require(game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared.WorldDefinitions)

local Dressing = {}
local P = Kit.Palette
local M = Enum.Material
local rgb = Color3.fromRGB
local FROST = rgb(222, 230, 234)

-- Two structural bays reuse the Sanctuary's authored joinery and tiled roof. The gate's
-- existing posts remain its only colliders; the visual opening keeps their original width.
local function entryGate(parent: Instance, map: Instance): boolean
	local lib = game:GetService("ServerStorage"):FindFirstChild("AsuraLobbyKit")
	for _, name in { "Column_Base", "Column_Lacquer", "Bracket_Set", "Beam_Architrave", "Roof_Gallery", "Roof_GalleryEnd", "Gate_Plaque" } do
		if not lib or not lib:FindFirstChild(name) then return false end
	end
	local gate = Kit.folder("BambooRoofedGate", parent)
	for _, x in { -9, 9 } do
		Decor.han(gate, "AsuraLobbyKit", "Column_Base", CFrame.new(x, 0.1, -1150), 1.4)
		Decor.han(gate, "AsuraLobbyKit", "Column_Lacquer", CFrame.new(x, 0.9, -1150), 1.55)
		Decor.han(gate, "AsuraLobbyKit", "Bracket_Set", CFrame.new(x, 16, -1150), 0.7)
	end
	for _, x in { -4.5, 4.5 } do
		Decor.han(gate, "AsuraLobbyKit", "Beam_Architrave", CFrame.new(x, 14.7, -1150), 1.15)
	end
	for _, x in { -8.8, 0, 8.8 } do
		Decor.han(gate, "AsuraLobbyKit", "Roof_Gallery", CFrame.new(x, 17.8, -1150), 1)
	end
	for _, x in { -13.2, 13.2 } do
		Decor.han(gate, "AsuraLobbyKit", "Roof_GalleryEnd", CFrame.new(x, 17.8, -1150), 1)
	end
	Decor.han(gate, "AsuraLobbyKit", "Gate_Plaque", CFrame.new(0, 15.6, -1148.9), 0.8)
	local structure = map:FindFirstChild("Structure")
	for _, p in if structure then structure:GetChildren() else {} do
		if p:IsA("BasePart") and p.Name == "GatePost" then p.Transparency, p.CastShadow = 1, false end
	end
	return true
end

local function fallenRoots(parent: Instance): boolean
	local y = Ground.surfaceHeight(-56, -1150, -0.1)
	-- The scan's underside sits ~4 studs above its pivot and bows upward in the middle: sink and
	-- roll it so both ends bear on the soil (measured within 0.5 stud of the surface in v9).
	local trunk = Decor.nature(parent, "AsuraDeadTrunk", CFrame.new(-56, y - 3.62, -1150)
		* CFrame.Angles(0, math.rad(68), 0) * CFrame.Angles(0, 0, math.rad(4.4)), 32)
	if not trunk then return false end
	Ground.forestFloor(-56, -1150, 9, 15)
	trunk.Name = "FallenJadeTrunk"
	for _, c in { { -62, -1162, 17, 22 }, { -21, -1177, 9, 115 } } do
		local floor = Ground.surfaceHeight(c[1], c[2], -0.1)
		Decor.nature(parent, "AsuraRoots", CFrame.new(c[1], floor - 0.08, c[2])
			* CFrame.Angles(0, math.rad(c[4]), 0), c[3])
	end
	return true
end

local function shrineShelter(parent: Instance, map: Instance): boolean
	local model = Decor.han(parent, "AsuraHanKit", "HanShrine", Decor.facing(
		Vector3.new(-36, 0.2, -1346), Vector3.new(-36, 0.2, -1328)), 1.15)
	if not model then return false end
	local structure = map:FindFirstChild("Structure")
	for _, p in if structure then structure:GetChildren() else {} do
		if p:IsA("BasePart") and p.Name == "ShrineHall" then p.Transparency, p.CastShadow = 1, false end
	end
	return true
end

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
	for i, grove in layout.Groves or {} do
		if i ~= 1 and i ~= 4 then
			Ecology.Grove(groves, layout, grove, Random.new(291030 + i * 971))
		end
	end
	Ecology.Entry(map, layout, Random.new(291026))
	Ecology.Shrine(map, layout, Random.new(291027))
	local set = Kit.folder("PassDressing", map)
	-- Karst spires beyond the thicket: the pass's skyline on both sides.
	for i = 0, 9 do
		local z = -1160 - i * 54
		spire(set, -186 + rng:NextNumber(-8, 8), z, rng:NextNumber(60, 110), rng)
		spire(set, 186 + rng:NextNumber(-8, 8), z - 20, rng:NextNumber(60, 110), rng)
	end
	-- High-detail pagodas on the valley walls (seated on CampaignTerrain's backdrop), above the bamboo.
	for _, c in { { 246, -1330 }, { -246, -1490 } } do
		local y = Ground.backdropHeight("BambooPass", World.Regions.BambooPass.Bounds, c[1], c[2])
		if y then
			Ground.pad(c[1], c[2], y - 1.5, 44) -- a level terrace on the slope under the plinth
			local at = Vector3.new(c[1], y - 1.5, c[2])
			Decor.han(set, "AsuraHanHD", "HanPagodaHD", Decor.facing(at, Vector3.new(0, y, c[2])), 1)
		end
	end
	-- The whispering shrine's lanterns and incense cauldron (behind the altar), Baize's guardians.
	for _, x in { -48, -24 } do
		Decor.han(set, "AsuraHanKit", "HanLantern", CFrame.new(x, 0, -1336), 1.2)
	end
	Decor.han(set, "AsuraHanKit", "HanCauldron", CFrame.new(-36, 0, -1341), 2.2)
	for _, side in { -1, 1 } do
		Decor.han(set, "AsuraHanKit", "HanBixie", Decor.facing(Vector3.new(side * 13, 0, -1356), Vector3.new(0, 0, -1356)), 1.5)
	end
	-- Pines and crags on the frost ridge, seated on its terrain.
	for k = 1, 10 do
		local x, z = rng:NextNumber(112, 156), rng:NextNumber(-1298, -1386)
		local y = Decor.layoutTop(layout, x, z)
		if y then
			local piece = if k <= 7 then "Pine" else ({ "CragA", "CragB", "CragC" })[rng:NextInteger(1, 3)]
			local scale = if k <= 7 then rng:NextNumber(4, 6) else rng:NextNumber(1, 1.6)
			Decor.han(set, "AsuraHanKit", piece, CFrame.new(x, y - 0.6, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0), scale)
		end
	end
	if not entryGate(set, map) then
		Kit.part(set, "ToriiKasagi", Vector3.new(26, 1.4, 2), CFrame.new(0, 16.6, -1150), P.Lacquer, M.Wood, Kit.decor())
		Kit.part(set, "ToriiNuki", Vector3.new(21, 0.9, 1.2), CFrame.new(0, 13.4, -1150), P.WoodDark, M.Wood, Kit.decor())
		Kit.part(set, "GateBoard", Vector3.new(3, 2.4, 0.4), CFrame.new(0, 15, -1149.4), P.WoodDark, M.Wood, Kit.decor())
	end
	-- The fallen jade-root giant beside tablet V (outside the veil, seen from the path).
	if not fallenRoots(set) then
		Kit.part(set, "JadeRootGiant", Vector3.new(38, 6, 6), CFrame.new(-56, 2.9, -1150) * CFrame.Angles(0, math.rad(68), 0),
			rgb(96, 128, 98), M.Wood, { Collide = false, Query = false, Shadow = true, Shape = Enum.PartType.Cylinder })
	end
	-- A pilgrim's hat and staff where the first swordsman waits.
	Kit.part(set, "PilgrimHat", Vector3.new(0.5, 3.2, 3.2), CFrame.new(-4, 0.3, -1200) * CFrame.Angles(0, 0, math.rad(90)), rgb(150, 128, 86), M.Fabric,
		{ Collide = false, Query = false, Shadow = true, Shape = Enum.PartType.Cylinder })
	Kit.beam(set, "PilgrimStaff", Vector3.new(-6, 0.2, -1197), Vector3.new(-2, 0.5, -1205), 0.25, P.WoodDark)
	-- The whispering shrine: roof over its back screen, wind ribbons, a bronze bell.
	local shelter = shrineShelter(set, map)
	if not shelter then Decor.roof(set, CFrame.new(-36, 9.2, -1346), 22, 8, 2.4) end
	for k = 0, 5 do
		local x = -45 + k * 3.6
		Kit.part(set, "WindRibbon", Vector3.new(0.5, 3.2, 0.05), CFrame.new(x, if shelter then 10.2 else 7, if shelter then -1342.3 else -1344.6) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
			if k % 2 == 0 then P.Lacquer else rgb(214, 204, 176), M.Fabric, Kit.decor())
	end
	local bell = Kit.part(set, "ShrineBell", Vector3.new(1.6, 2, 1.6), CFrame.new(-28, 7.2, -1344.4), rgb(112, 91, 57), M.Metal, Kit.decor())
	bell.Shape = Enum.PartType.Ball
	-- Frost ridge: drifts are clusters of overlapping low discs, so their margins read as wind-cut
	-- edges rather than rectangles; frost on the stones, mist pooling in the arena basin below.
	-- Discs are sunk so only a thin rim rises over the ground; none are laid on paved floors.
	local function drift(x: number, y: number, z: number, span: number)
		for _ = 1, 4 do
			local d = span * rng:NextNumber(0.45, 0.8)
			Kit.part(set, "SnowDrift", Vector3.new(0.4, d, d * rng:NextNumber(0.9, 1)),
				CFrame.new(x + rng:NextNumber(-span, span) * 0.35, y - rng:NextNumber(0.02, 0.1), z + rng:NextNumber(-span, span) * 0.35) * CFrame.Angles(0, 0, math.rad(90)),
				rgb(204, 212, 216), M.Snow, { Collide = false, Query = false, Shadow = false, Shape = Enum.PartType.Cylinder })
		end
	end
	for _ = 1, 9 do drift(rng:NextNumber(118, 156), 18, rng:NextNumber(-1296, -1384), rng:NextNumber(6, 11)) end
	for _, x in { -30, -18, 18, 28 } do drift(x, 12, -1270 + rng:NextNumber(-12, 12), 7) end
	-- Overlook: rough coping along the parapet's top and frost-heaped crags at its ends (all decor).
	for z = -1390, -1434, -4 do
		Kit.part(set, "ParapetCoping", Vector3.new(1.9, 0.5, rng:NextNumber(3.6, 4.3)),
			CFrame.new(106.8, 20.85, z) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), math.rad(rng:NextNumber(-2, 2))), rgb(118, 122, 124), M.Slate, Kit.decor())
	end
	for _, c in { { 110, -1389, "CragB" }, { 110, -1435, "CragA" } } do
		Decor.han(set, "AsuraHanKit", c[3], CFrame.new(c[1], 17.6, c[2]) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), 1.1)
	end
	for _, spec in { { 0, -1470, 170, 170 }, { -120, -1250, 100, 180 } } do
		local mist = Fx.mist(set, CFrame.new(spec[1], 1.5, spec[2]), Vector3.new(spec[3], 2, spec[4]), 1, 17, rgb(177, 188, 180))
		mist.Squash = NumberSequence.new(2)
		mist.Lifetime = NumberRange.new(12, 18)
		mist.Transparency = Kit.sequence({ { 0, 1 }, { 0.25, 0.91 }, { 0.75, 0.94 }, { 1, 1 } })
		mist.Color, mist.LightInfluence = ColorSequence.new(rgb(177, 188, 180)), 0.15
	end
	-- Moon gate: fine voussoirs under a slate coping band and keystone, springing from dressed jambs.
	-- Everything here is decor; the layout's 3 x 18 x 3 MoonJamb boxes stay the only colliders.
	local STONE = rgb(128, 131, 128)
	for k = 0, 24 do
		local a = math.rad(k * 7.5)
		local frame = CFrame.new(math.cos(a) * 17.3, 18 + math.sin(a) * 17.3, -1577) * CFrame.Angles(0, 0, a + math.pi / 2)
		local tone = STONE:Lerp(rgb(104, 108, 104), rng:NextNumber(0, 1))
		Kit.part(set, "MoonRing", Vector3.new(if k == 12 then 2.9 else 2.35, 3.4, 3.4), frame, tone, M.Slate, Kit.decor())
		Kit.part(set, "MoonCoping", Vector3.new(2.4, 0.7, 3.9), frame * CFrame.new(0, 2, 0), rgb(92, 96, 94), M.Slate, Kit.decor())
	end
	for _, x in { -17.1, 17.1 } do
		Kit.part(set, "MoonJambShell", Vector3.new(3.4, 16.6, 3.4), CFrame.new(x, 9.3, -1577), STONE, M.Slate, Kit.decor())
		Kit.part(set, "MoonPlinth", Vector3.new(4.6, 1.6, 4.6), CFrame.new(x, 0.7, -1577), rgb(98, 101, 98), M.Slate, Kit.decor())
		Kit.part(set, "MoonImpost", Vector3.new(4.2, 0.9, 4.2), CFrame.new(x, 17.6, -1577), rgb(98, 101, 98), M.Slate, Kit.decor())
	end
	Ecology.South(map, layout, Random.new(291034))
	-- Baize's palisade: frost-rimed caps and torn prayer flags along its top.
	for z = -1386, -1556, -34 do
		Decor.banner(set, CFrame.new(-104, 9.5, z) * CFrame.Angles(0, math.rad(90), 0), 5, rgb(214, 204, 176))
	end
end

return Dressing

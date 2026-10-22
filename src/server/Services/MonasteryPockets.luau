--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryPockets
-- Batch 15 (#25, #32): rhythm, cover and storytelling along the walked route, in the established
-- ruin vocabulary (slate and lacquered timber, tiled roofs, moss wear). Each stop gets its own
-- silhouette: carved cloud pillars at the gate, toppled stone lanterns and a broken spirit screen
-- as courtyard cover, a stele avenue on the processional path, the seven-bowl table beside the
-- Feast inscription, a timber gateway and guardian lions at the bridge, and a dry "river of souls"
-- crossed by stepping stones in the cloister garth. The central lanes stay open.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Ruins = require(script.Parent:WaitForChild("MonasteryRuins") :: ModuleScript)

local Pockets = {}

local P = Kit.Palette
local G = Kit.GROUND
local SLATE, WOOD = Enum.Material.Slate, Enum.Material.Wood

-- Pillars of the gate approach: octagonal shaft, a cloud plate across it, a crouching beast on top.
local function cloudPillar(parent: Instance, x: number, z: number)
	local base = CFrame.new(x, G, z)
	Kit.disc(parent, "PillarPlinth", 2, 1.2, base * CFrame.new(0, 0.6, 0), P.StoneDark, SLATE)
	Kit.disc(parent, "CloudPillar", 0.9, 11, base * CFrame.new(0, 6.7, 0), P.Stone:Lerp(P.Moss, 0.2), SLATE)
	Kit.part(parent, "CloudPlate", Vector3.new(4.2, 0.9, 0.5), base * CFrame.new(0, 10, 0) * CFrame.Angles(0, math.rad(if x > 0 then 90 else -90), 0), P.Stone, SLATE, Kit.decor())
	Kit.part(parent, "Beast", Vector3.new(1.6, 1.4, 1.6), base * CFrame.new(0, 12.9, 0), P.StoneDark, SLATE, { Shape = Enum.PartType.Ball, Collide = false, Query = false })
end

-- A stone lantern toppled where it stood: plinth upright, shaft and firebox lying beside it.
local function toppledLantern(parent: Instance, x: number, z: number, yaw: number)
	local base = CFrame.new(x, G, z) * CFrame.Angles(0, math.rad(yaw), 0)
	Kit.part(parent, "LanternPlinth", Vector3.new(3, 1.6, 3), base * CFrame.new(0, 0.8, 0), P.StoneDark, SLATE)
	Kit.part(parent, "LanternShaft", Vector3.new(1.6, 1.6, 6), base * CFrame.new(0, 0.8, -4.6) * CFrame.Angles(0, 0.15, 0), P.Stone:Lerp(P.Moss, 0.3), SLATE)
	Kit.part(parent, "Firebox", Vector3.new(2.6, 2.6, 2.6), base * CFrame.new(0.6, 1.3, -8.8) * CFrame.Angles(0.2, 0.5, 0.1), P.Stone, SLATE)
	Kit.part(parent, "LanternRoof", Vector3.new(3.8, 0.7, 3.8), base * CFrame.new(-1.4, 0.4, -11) * CFrame.Angles(0.3, 0.8, 0.2), P.Roof, SLATE, Kit.decor())
end

-- The fallen spirit screen: low broken halves of the courtyard's warding wall, waist-high cover.
local function spiritScreen(parent: Instance, x: number, z: number)
	Kit.part(parent, "ScreenHalf", Vector3.new(5.4, 4, 1.4), CFrame.new(x - 3, G + 2, z) * CFrame.Angles(0, 0.08, 0.04), P.Stone:Lerp(P.Dawn, 0.25), Enum.Material.Plaster)
	Kit.part(parent, "ScreenHalf", Vector3.new(4.6, 2.6, 1.4), CFrame.new(x + 2.6, G + 1.3, z - 0.6) * CFrame.Angles(0, -0.2, 0), P.Stone, Enum.Material.Plaster)
	Kit.part(parent, "ScreenCap", Vector3.new(5.6, 0.6, 2.2), CFrame.new(x + 4, G + 0.3, z + 2.6) * CFrame.Angles(0, 0.6, 0.1), P.Roof, SLATE)
end

-- "The bowls were set for seven" (Feast inscription): a long offering table, six bowls overturned.
local function feastTable(parent: Instance, at: Vector3)
	local group = Kit.folder("SevenBowls", parent)
	local base = CFrame.new(at.X, G, at.Z)
	Kit.part(group, "Table", Vector3.new(9, 0.6, 2.6), base * CFrame.new(0, 2.5, 0), P.StoneDark, SLATE)
	for _, x in { -3.8, 3.8 } do Kit.part(group, "TableLeg", Vector3.new(0.8, 2.2, 2), base * CFrame.new(x, 1.1, 0), P.StoneDark, SLATE) end
	for k = 0, 6 do
		local upright = k == 3
		Kit.part(group, "Bowl", Vector3.new(0.5, 0.9, 0.9), base * CFrame.new(-3.6 + k * 1.2, 3.05, 0) * CFrame.Angles(0, 0, math.rad(if upright then 90 else 90 + 70)),
			Color3.fromRGB(96, 74, 52), Enum.Material.Wood, { Shape = Enum.PartType.Cylinder, Collide = false, Query = false })
	end
end

local function stele(parent: Instance, x: number, z: number, height: number, fallen: boolean)
	local frame = if fallen then CFrame.new(x, G + 0.6, z) * CFrame.Angles(math.rad(90), 0.3, 0) else CFrame.new(x, G + height * 0.5, z) * CFrame.Angles(0, 0, math.rad(x * 0.2))
	Kit.part(parent, "Stele", Vector3.new(2.4, height, 0.8), frame, P.StoneDark:Lerp(P.Moss, 0.2), SLATE)
	if not fallen then Kit.part(parent, "SteleCap", Vector3.new(3, 0.6, 1.3), frame * CFrame.new(0, height * 0.5 + 0.3, 0), P.Roof, SLATE, Kit.decor()) end
end

-- Timber gateway over the north bridgehead and stone lions guarding the far end.
local function bridgeGate(parent: Instance)
	local group = Kit.folder("BridgeGateway", parent)
	for side = -1, 1, 2 do
		Kit.part(group, "GatePlinth", Vector3.new(2.8, 1, 2.8), CFrame.new(side * 12.5, G + 0.5, -928), P.StoneDark, SLATE)
		Kit.part(group, "GatePost", Vector3.new(1.8, 13, 1.8), CFrame.new(side * 12.5, G + 7.5, -928), P.Lacquer:Lerp(P.WoodDark, 0.45), WOOD)
		local lion = CFrame.new(side * 11.6, G, -993) * CFrame.Angles(0, if side < 0 then math.rad(-15) else math.rad(15), 0)
		Kit.part(group, "LionPlinth", Vector3.new(2.6, 1.6, 3.6), lion * CFrame.new(0, 0.8, 0), P.StoneDark, SLATE)
		Kit.part(group, "LionBody", Vector3.new(2, 2.4, 2.8), lion * CFrame.new(0, 2.8, 0.3), P.Stone:Lerp(P.Moss, 0.25), SLATE)
		Kit.part(group, "LionHead", Vector3.new(1.9, 1.9, 1.9), lion * CFrame.new(0, 4.5, -0.9), P.Stone, SLATE, { Shape = Enum.PartType.Ball })
	end
	Kit.part(group, "Lintel", Vector3.new(28, 1.4, 1.6), CFrame.new(0, G + 13.4, -928), P.WoodDark, WOOD)
	Kit.part(group, "TieBeam", Vector3.new(24, 0.9, 1.2), CFrame.new(0, G + 10.8, -928), P.WoodDark, WOOD)
	local plaque = Kit.part(group, "Plaque", Vector3.new(7, 1.6, 0.3), CFrame.new(0, G + 12.1, -927.3) * CFrame.Angles(0, math.pi, 0), P.WoodDark, WOOD, Kit.decor())
	Ruins.inscription(plaque, "BRIDGE OF PARTING SOULS")
	Ruins.roof(group, CFrame.new(0, G + 14.2, -928) * CFrame.Angles(0, math.pi / 2, 0), 4.4, 30, Random.new(15), false)
	Fx.lantern(group, CFrame.new(-11, G + 10.2, -926.8), true, 18)
end

-- "A phantom stood at the river of souls": a dry stone channel across the garth, stepping stones.
local function soulRiver(parent: Instance)
	local group = Kit.folder("RiverOfSouls", parent)
	for side = -1, 1, 2 do
		Kit.part(group, "Curb", Vector3.new(56, 0.35, 0.8), CFrame.new(72, G + 0.17, -1079 + side * 3), P.StoneDark, SLATE, Kit.decor())
	end
	Kit.part(group, "Riverbed", Vector3.new(56, 0.06, 5.2), CFrame.new(72, G + 0.03, -1079), Color3.fromRGB(46, 50, 54), Enum.Material.Pebble, Kit.decor())
	for k = -1, 1 do Kit.disc(group, "SteppingStone", 1.2, 0.4, CFrame.new(72 + k * 1.6, G + 0.2, -1079 + k * 1.1), P.Flag, SLATE, Kit.decor()) end
end

function Pockets.Build(parent: Instance, _rng: Random)
	local group = Kit.folder("RoutePockets", parent)
	for _, x in { -22, 22 } do cloudPillar(group, x, -744) end
	toppledLantern(group, -30, -806, 20)
	toppledLantern(group, 32, -812, -160)
	spiritScreen(group, -24, -832)
	feastTable(group, Vector3.new(48, 0, -838))
	for index, z in { -870, -890, -910 } do
		stele(group, -11, z, ({ 6, 3.2, 5.2 })[index], index == 2)
		stele(group, 11, z - 6, ({ 4.4, 6, 2.6 })[index], index == 3)
	end
	bridgeGate(group)
	soulRiver(group)
end

return Pockets

--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryAtmosphere
-- Mood layer for the Desecrated Monastery: banks of dawn mist (dense in the ravine), crimson leaf
-- litter drifted against stone, falling leaves, pale roots strangling the masonry and a sparse
-- string of warm lanterns marking the route from the gate to the cloister.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Grounds = require(script.Parent:WaitForChild("MonasteryGrounds") :: ModuleScript)

local Atmosphere = {}

local P = Kit.Palette
local G = Kit.GROUND

local function mists(parent: Instance)
	local group = Kit.folder("DawnMist", parent)
	-- Ground-hugging veils over each zone.
	Fx.mist(group, CFrame.new(0, G + 1.5, -722), Vector3.new(60, 2, 50), 0.6, 22)
	Fx.mist(group, CFrame.new(0, G + 2, -805), Vector3.new(160, 3, 100), 2.2, 30)
	Fx.mist(group, CFrame.new(0, G + 2, -900), Vector3.new(220, 3, 70), 1.8, 30)
	Fx.mist(group, CFrame.new(70, G + 2, -1052), Vector3.new(110, 3, 120), 1, 28)
	Fx.mist(group, CFrame.new(-75, G + 2, -1052), Vector3.new(110, 3, 120), 1.2, 32)
	-- The ravine breathes thick mist up around the bridge.
	for x = -110, 110, 44 do
		Fx.mist(group, CFrame.new(x, -8, Grounds.RAVINE_Z), Vector3.new(44, 6, 34), 1.8, 40, Color3.fromRGB(170, 166, 168))
	end
	-- Distant dawn haze over the valley walls and beyond the south road.
	for _, spot in { Vector3.new(-215, 34, -800), Vector3.new(215, 34, -800), Vector3.new(-215, 34, -1020), Vector3.new(215, 34, -1020), Vector3.new(0, 20, -1150) } do
		Fx.mist(group, CFrame.new(spot), Vector3.new(60, 20, 200), 0.8, 90)
	end
end

local DRIFTS = {
	-- {x, z, radius, count}: leaves pile against walls, columns and the dead tree.
	{ -58, -836, 12, 40 }, { -70, -756, 10, 18 }, { 60, -756, 10, 18 }, { -78, -812, 6, 14 }, { 78, -830, 6, 14 },
	{ 0, -852, 8, 16 }, { -44, -900, 8, 16 }, { 44, -905, 8, 16 }, { -12, -936, 4, 10 }, { 12, -986, 4, 10 },
	{ 66, -1048, 12, 36 }, { 24, -1100, 8, 14 }, { 118, -1000, 8, 14 }, { -50, -1030, 14, 24 }, { 0, -1110, 8, 14 },
}

local function litter(parent: Instance, rng: Random)
	local group = Kit.folder("LeafLitter", parent)
	for _, drift in DRIFTS do
		for _ = 1, drift[4] do
			local r = drift[3] * math.sqrt(rng:NextNumber()) ^ 1.5
			local a = rng:NextNumber(0, math.pi * 2)
			local color = P.Leaf:Lerp(P.LeafDark, rng:NextNumber()):Lerp(P.Rust, if rng:NextNumber() < 0.2 then 0.6 else 0)
			Kit.part(group, "Leaf", Vector3.new(rng:NextNumber(0.5, 0.9), 0.05, rng:NextNumber(0.4, 0.7)),
				CFrame.new(drift[1] + math.cos(a) * r, G + rng:NextNumber(0.03, 0.12), drift[2] + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi * 2), 0),
				color, Enum.Material.Fabric, Kit.decor())
		end
	end
	for _, spot in { Vector3.new(-58, 20, -836), Vector3.new(66, 20, -1048), Vector3.new(0, 15, -800), Vector3.new(0, 13, -1060) } do
		local volume = Kit.hidden(group, "LeafFall", Vector3.new(if spot.Y > 16 then 18 else 120, 2, if spot.Y > 16 then 18 else 80), CFrame.new(spot))
		Fx.leaves(volume, if spot.Y > 16 then 7 else 3)
	end
end

-- A pale root creeping over the ground from `start`, half-sunk, bending and thinning as it goes.
local function root(parent: Instance, start: Vector3, dir: Vector3, segments: number, radius: number, rng: Random)
	local at, heading, r = Vector3.new(start.X, G - radius * 0.3, start.Z), Vector3.new(dir.X, 0, dir.Z).Unit, radius
	for _ = 1, segments do
		local length = rng:NextNumber(2, 3.4)
		heading = (heading + Vector3.new(rng:NextNumber(-0.45, 0.45), 0, rng:NextNumber(-0.45, 0.45))).Unit
		local nextAt = Vector3.new(at.X, G - r * 0.3, at.Z) + heading * length
		Kit.part(parent, "Root", Vector3.new(length + r, r * 2, r * 2), CFrame.lookAt((at + nextAt) * 0.5, nextAt) * CFrame.Angles(0, math.pi / 2, 0),
			P.Root:Lerp(P.StoneDark, rng:NextNumber(0.25, 0.5)), Enum.Material.Wood, { Collide = false, Query = false, Shape = Enum.PartType.Cylinder })
		at, r = nextAt, math.max(0.12, r * 0.84)
	end
end

local ROOTS = {
	-- {start, direction}: creeping out from wall feet, idols, the tree and the ravine lips.
	{ Vector3.new(-80, 0, -780), Vector3.new(1, 0, 0.2) }, { Vector3.new(-80, 0, -830), Vector3.new(1, 0, -0.3) },
	{ Vector3.new(80, 0, -800), Vector3.new(-1, 0, 0.1) }, { Vector3.new(-40, 0, -754), Vector3.new(0.2, 0, -1) },
	{ Vector3.new(-100, 0, -890), Vector3.new(1, 0, 0.3) }, { Vector3.new(116, 0, -912), Vector3.new(-1, 0, -0.2) },
	{ Vector3.new(-30, 0, -935), Vector3.new(0.3, 0, 1) }, { Vector3.new(40, 0, -935), Vector3.new(-0.2, 0, 1) },
	{ Vector3.new(126, 0, -1040), Vector3.new(-1, 0, 0) }, { Vector3.new(80, 0, -1112), Vector3.new(0, 0, 1) },
	{ Vector3.new(-58, 0, -836), Vector3.new(1, 0, 0.6) }, { Vector3.new(66, 0, -1048), Vector3.new(-0.7, 0, 1) },
}

function Atmosphere.Build(parent: Instance, rng: Random)
	mists(parent)
	litter(parent, rng)
	local roots = Kit.folder("PaleRoots", parent)
	for _, spec in ROOTS do
		for strand = 1, 2 do
			root(roots, spec[1] + Vector3.new(0, 0, strand * 0.8), spec[2], 6 + strand * 2, 0.55 - strand * 0.1, rng)
		end
	end
	-- Sparse warm light along the route; most of the ruin stays in cold dawn shadow.
	local lamps = Kit.folder("RouteLanterns", parent)
	for _, spot in { Vector2.new(-16, -766), Vector2.new(16, -846), Vector2.new(-11, -870), Vector2.new(11, -926), Vector2.new(-10, -1000), Vector2.new(10, -1060) } do
		Fx.lantern(lamps, CFrame.new(spot.X, G, spot.Y), false, 20)
	end
end

return Atmosphere

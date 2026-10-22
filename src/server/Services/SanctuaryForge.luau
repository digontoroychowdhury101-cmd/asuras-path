--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryForge
-- The working forge of the Blacksmith Loggia, rebuilt from the lobby kit: a timber hall under a
-- hip-and-gable roof on a paved platform, a brick-and-stone furnace with a chimney through the roof,
-- anvil, quench-side racks, coal, bellows and benches, balustrade open to the walkway. Gameplay stays
-- in SanctuaryService (Master Smith Gao, his prompts and the quench trough); this module is the
-- building around them and keeps their spots clear. `base` is the Loggia centre on the platform top.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Frame = require(script.Parent:WaitForChild("SanctuaryFrame") :: ModuleScript)
local Rails = require(script.Parent:WaitForChild("SanctuaryRails") :: ModuleScript)
local Props = require(script.Parent:WaitForChild("SanctuaryProps") :: ModuleScript)
local Eaves = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.ArsenalCatalog).Caches.SanctuaryEaves

local Forge = {}

local HALF = 18 -- platform half-size
local HALL = { Z = -2, Width = 30, Depth = 20, Height = 12 }
local M = Enum.Material
local rgb = Color3.fromRGB
local Y = Vector3.yAxis

local function timberBrace(group: Instance, name: string, a: Vector3, b: Vector3, thickness: number)
	Kit.slab(group, name, Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), "Timber", Kit.decor())
end

local function fire(parent: BasePart, size: number, heat: number)
	local f = Instance.new("Fire")
	f.Size, f.Heat, f.Color, f.SecondaryColor = size, heat, rgb(255, 110, 40), rgb(200, 40, 20)
	f.Parent = parent
end

local function furnace(group: Instance, base: CFrame, embers: (BasePart) -> ())
	local at = base * CFrame.new(-12, 0, 0)
	-- Keep the original solid envelope for circulation, with a recessed hearth behind a stone frontage.
	Kit.part(group, "Forge", Vector3.new(7, 6, 6), at * CFrame.new(0, 3, 0), rgb(67, 64, 60), M.Brick,
		{ Collide = true, Query = true, Transparency = 1, Shadow = false })
	Kit.slab(group, "ForgePlinth", Vector3.new(7.8, 0.8, 6.8), at * CFrame.new(0, 0.4, 0), "StoneDark")
	Kit.slab(group, "ForgeBack", Vector3.new(1, 5.2, 6), at * CFrame.new(-3, 3.4, 0), "StoneDark", Kit.decor())
	for _, side in { -1, 1 } do
		Kit.slab(group, "ForgeCheek", Vector3.new(6.1, 5.2, 1.25), at * CFrame.new(0.4, 3.4, side * 2.38), "StoneDark", Kit.decor())
		Kit.slab(group, "HearthJamb", Vector3.new(1.1, 3.8, 1.1), at * CFrame.new(3.1, 2.7, side * 2.24), "Stone", Kit.decor())
	end
	Kit.slab(group, "HearthLintel", Vector3.new(1.2, 1.2, 5.8), at * CFrame.new(3.1, 5.2, 0), "Stone", Kit.decor())
	Kit.slab(group, "ForgeHood", Vector3.new(8, 0.8, 7), at * CFrame.new(0, 6.2, 0), "StoneDark", Kit.decor())
	for i, layer in { { 7, 1.2, 6 }, { 5.8, 1.2, 4.8 }, { 4.2, 1, 3.8 } } do
		Kit.slab(group, "HoodMasonryCourse", Vector3.new(layer[1], layer[2], layer[3]), at * CFrame.new(-0.4, 6.1 + i * 1.1, 0), "StoneDark", Kit.decor())
	end
	Kit.part(group, "HearthSoot", Vector3.new(0.1, 3.5, 3.4), at * CFrame.new(0.6, 2.9, 0), rgb(24, 24, 24), M.Basalt, Kit.decor())
	Kit.part(group, "Chimney", Vector3.new(3, 15, 3), at * CFrame.new(-1, 16.5, 0), rgb(69, 65, 60), M.Brick)
	for _, h in { 9.6, 17, 23.8 } do
		Kit.part(group, "ChimneyIronBand", Vector3.new(3.12, 0.23, 3.12), at * CFrame.new(-1, h, 0), Kit.Palette.Iron, M.Metal, Kit.decor())
	end
	Kit.place(group, "Roof_Square", at * CFrame.new(-1, 24.2, 0), 0.3)
	Kit.slab(group, "HearthApron", Vector3.new(2.8, 0.25, 5.7), at * CFrame.new(4.1, 0.92, 0), "StoneDark", Kit.decor())
	local mouth = Kit.part(group, "ForgeMouth", Vector3.new(1.3, 0.18, 3.3), at * CFrame.new(2.8, 1.25, 0), rgb(255, 96, 36), M.Neon, Kit.decor())
	for z = -1.4, 1.4, 0.56 do
		Kit.part(group, "HearthGrate", Vector3.new(1.65, 0.12, 0.1), at * CFrame.new(2.8, 1.4, z), Kit.Palette.Iron, M.Metal, Kit.decor())
	end
	fire(mouth, 3.2, 5)
	embers(mouth)
	Kit.light(mouth, rgb(255, 147, 76), 22, 2.1, true)
	-- Coal heap and bellows beside the mouth.
	for k = 0, 6 do
		local ball = Kit.part(group, "Coal", Vector3.new(1.1, 0.8, 1.1), at * CFrame.new(4.4 + (k % 3) * 0.7, 0.35 + math.floor(k / 3) * 0.4, 3.3 + (k % 2) * 0.6),
			rgb(30, 28, 28), M.Basalt, Kit.decor())
		ball.Shape = Enum.PartType.Ball
	end
	Kit.slab(group, "Bellows", Vector3.new(2.6, 1.2, 1.6), at * CFrame.new(2.2, 0.9, -3.8), "Timber")
	Kit.part(group, "BellowsHide", Vector3.new(2.2, 0.9, 1.7), at * CFrame.new(2.4, 1.9, -3.8), rgb(86, 58, 40), M.Leather, Kit.decor())
end

local function workshop(group: Instance, base: CFrame)
	Kit.disc(group, "Stump", 1.2, 2, base * CFrame.new(-4, 1, 3), rgb(70, 52, 40), M.Wood)
	Kit.part(group, "AnvilFoot", Vector3.new(1.8, 0.22, 2.2), base * CFrame.new(-4, 2.11, 3), rgb(48, 48, 50), M.Metal, Kit.decor())
	Kit.part(group, "AnvilWaist", Vector3.new(0.92, 0.68, 1.1), base * CFrame.new(-4, 2.46, 3), rgb(49, 49, 52), M.Metal, Kit.decor())
	Kit.part(group, "AnvilBody", Vector3.new(1.45, 0.32, 2.8), base * CFrame.new(-4, 2.95, 3), rgb(73, 77, 81), M.Metal)
	Kit.part(group, "AnvilHorn", Vector3.new(1.0, 0.32, 1.3), base * CFrame.new(-4, 2.95, 5.0), rgb(73, 77, 81), M.Metal, { Class = "WedgePart" })
	-- Weapon rack against the back wall, clear of the corner column.
	local rack = base * CFrame.new(-14.3, 0, -7)
	Kit.slab(group, "Rack", Vector3.new(0.6, 4.4, 6), rack * CFrame.new(0, 2.2, 0), "Lacquer")
	for k = -1, 1 do
		Kit.part(group, "RackBlade" .. (k + 2), Vector3.new(0.15, 3.8, 0.4), rack * CFrame.new(0.5, 2.6, k * 1.8) * CFrame.Angles(math.rad(-8), 0, 0),
			rgb(190, 194, 200), M.Metal, Kit.decor())
	end
	for _, z in { -2.5, 2.5 } do
		Kit.slab(group, "RackFoot", Vector3.new(2.1, 0.3, 0.7), rack * CFrame.new(0.1, 0.15, z), "Timber", Kit.decor())
	end
	-- Bench with tongs and hammers, barrels of quench oil.
	local bench = base * CFrame.new(-6, 0, 7.5)
	Kit.slab(group, "Workbench", Vector3.new(6, 0.4, 2), bench * CFrame.new(0, 2.6, 0), "Timber")
	for x = -2.6, 2.6, 5.2 do
		Kit.slab(group, "BenchLeg", Vector3.new(0.4, 2.4, 1.6), bench * CFrame.new(x, 1.2, 0), "Timber")
	end
	for x = -1.5, 1.5, 1.5 do
		Kit.part(group, "Tool", Vector3.new(0.3, 0.2, 1.6), bench * CFrame.new(x, 2.9, 0) * CFrame.Angles(0, math.rad(x * 12), 0), rgb(60, 60, 64), M.Metal, Kit.decor())
	end
	for _, p in { { 3.5, 7.4 }, { 5, 6.6 } } do
		local barrel = base * CFrame.new(p[1], 0, p[2])
		Kit.disc(group, "Barrel", 1, 2.4, barrel * CFrame.new(0, 1.2, 0), rgb(76, 54, 40), M.Wood).MaterialVariant = Kit.Surface.Timber.Variant
		for _, h in { 0.35, 1.95 } do
			Kit.disc(group, "BarrelHoop", 1.025, 0.14, barrel * CFrame.new(0, h, 0), Kit.Palette.Iron, M.Metal, Kit.decor())
		end
	end
end

-- The existing cache deck and climbable truss stay in LootWorld. This timberwork carries its load
-- visually without adding collision to the ladder's climbing volume or the service-ledge route.
local function lookout(group: Instance, base: CFrame)
	local x, z, height = Eaves.X - base.X, Eaves.Z - base.Z, Eaves.Y - base.Y - 1.9
	for _, side in { -1, 1 } do
		local cf = base * CFrame.new(x + side * 4.2, 0, HALF - 2)
		Kit.slab(group, "LookoutPostFoot", Vector3.new(1.9, 0.7, 1.9), cf * CFrame.new(0, 0.35, 0), "StoneDark", Kit.decor())
		Kit.slab(group, "LookoutTimberPost", Vector3.new(0.85, height, 0.85), cf * CFrame.new(0, height / 2, 0), "Timber", Kit.decor())
		Kit.slab(group, "LookoutCantilever", Vector3.new(0.85, 0.8, z + 4 - (HALF - 2)), cf * CFrame.new(0, height - 0.25, (z + 4 - (HALF - 2)) / 2), "Timber", Kit.decor())
		local a = (cf * CFrame.new(0, height * 0.32, 0)).Position
		local b = (base * CFrame.new(x + side * 4.2, height - 0.4, z + 2.5)).Position
		timberBrace(group, "LookoutKneeBrace", a, b, 0.65)
	end
	Kit.slab(group, "LookoutCrossTie", Vector3.new(10.8, 0.7, 0.9), base * CFrame.new(x, height - 0.25, z + 2.5), "Timber", Kit.decor())
end

-- `embers` lets the service keep its shared ember emitter for the forge mouth.
function Forge.Build(parent: Instance, base: CFrame, embers: (BasePart) -> ()): Folder
	local group = Kit.folder("BlacksmithLoggia", parent)
	Kit.slab(group, "Platform", Vector3.new(HALF * 2, 6, HALF * 2), base * CFrame.new(0, -3, 0), "Paving")
	Kit.slab(group, "PlatformSkirting", Vector3.new(HALF * 2 + 1, 2, HALF * 2 + 1), base * CFrame.new(0, -4.4, 0), "StoneDark")
	local hall = base * CFrame.new(0, 0, HALL.Z)
	Frame.pavilion(group, hall, HALL.Width, HALL.Depth, HALL.Height, { Rise = 1.2 })
	-- Back wall: stone dado and a timber lattice up to the beams, behind the furnace.
	local back = hall * CFrame.new(-HALL.Width / 2 - 1.2, 0, 0)
	Kit.slab(group, "BackWall", Vector3.new(1.2, 4.5, HALL.Depth), back * CFrame.new(0, 2.25, 0), "StoneDark")
	Kit.slab(group, "LatticeRail", Vector3.new(0.5, 0.4, HALL.Depth), back * CFrame.new(0, 4.7, 0), "Timber", Kit.decor())
	for z = -HALL.Depth / 2 + 0.7, HALL.Depth / 2 - 0.7, 1.1 do
		Kit.slab(group, "Lattice", Vector3.new(0.3, 6.8, 0.22), back * CFrame.new(0, 8.3, z), "Timber", Kit.decor())
	end
	Kit.blocker(group, "BackWallCollision", (back * CFrame.new(0, 0, -HALL.Depth / 2)).Position, (back * CFrame.new(0, 0, HALL.Depth / 2)).Position, HALL.Height, 1.2)
	furnace(group, base, embers)
	workshop(group, base)
	lookout(group, base)
	local e = HALF - 0.6
	local function run(a: Vector3, b: Vector3)
		Rails.run(group, (base * CFrame.new(a)).Position, (base * CFrame.new(b)).Position)
	end
	run(Vector3.new(-e, 0, -e), Vector3.new(e, 0, -e))
	-- South edge: open where the Loggia Eaves ladder (LootWorld) stands, so it is climbed from the platform.
	local ladder = Eaves.X - base.X
	run(Vector3.new(-e, 0, e), Vector3.new(ladder - 3, 0, e))
	run(Vector3.new(ladder + 3, 0, e), Vector3.new(e, 0, e))
	run(Vector3.new(-e, 0, -e), Vector3.new(-e, 0, e))
	run(Vector3.new(e, 0, -e), Vector3.new(e, 0, -7))
	run(Vector3.new(e, 0, 7), Vector3.new(e, 0, e))
	-- Lanterns at the hall's east corners, clear of its columns and the walkway mouth.
	for _, z in { -15, 14 } do
		Props.lantern(group, base * CFrame.new(e - 3.4, 0, z))
	end
	Props.tree(group, base * CFrame.new(-13.5, 0, 13.5) * CFrame.Angles(0, 2.2, 0), 0.85, true)
	Props.shrub(group, base * CFrame.new(-15.5, 0, -15.5), 1.2)
	return group
end

return table.freeze(Forge)

--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryCloisters
-- The connected covered architecture of the courtyard: two open halls flanking the Ascension stairs,
-- a cloister gallery down each side, and the roofed walkways out to the Blacksmith Loggia (west) and
-- the Colosseum Promenade (east) with carved rails between their columns. Floors are the collision;
-- columns carry their own boxes (SanctuaryFrame). Local to the plaza centre; north is -Z.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Frame = require(script.Parent:WaitForChild("SanctuaryFrame") :: ModuleScript)
local Rails = require(script.Parent:WaitForChild("SanctuaryRails") :: ModuleScript)
local Props = require(script.Parent:WaitForChild("SanctuaryProps") :: ModuleScript)

local Cloisters = {}

local TOP = 0.1
local HALL = { X = 24, Z = -37, Width = 20, Depth = 10, Height = 10.5 }
local SIDE = { X = 40.8, Z0 = -42, Z1 = -6, Width = 6, Height = 8.5 }
local WALK = { Width = 12, Height = 8.5 }
local Y = Vector3.yAxis

local function hall(group: Instance, origin: CFrame, side: number)
	local cf = origin * CFrame.new(side * HALL.X, TOP + 0.35, HALL.Z)
	Kit.slab(group, "HallSill", Vector3.new(HALL.Width + 3, 0.6, HALL.Depth + 3), cf * CFrame.new(0, -0.3, 0), "StoneDark")
	Kit.slab(group, "HallThreshold", Vector3.new(HALL.Width + 2.6, 0.12, 0.6), cf * CFrame.new(0, 0.04, HALL.Depth / 2 + 1), "Stone", Kit.decor())
	Frame.pavilion(group, cf, HALL.Width, HALL.Depth, HALL.Height)
	-- An offering table against the back row: incense censer and two candles.
	local table_ = cf * CFrame.new(0, 0, -HALL.Depth / 2 + 1.6)
	Kit.slab(group, "OfferingTable", Vector3.new(6, 0.4, 1.8), table_ * CFrame.new(0, 1.2, 0), "Timber")
	for _, x in { -2.5, 2.5 } do
		for _, z in { -0.55, 0.55 } do
			Kit.slab(group, "OfferingTableLeg", Vector3.new(0.32, 1.3, 0.32), table_ * CFrame.new(x, 0.65, z), "Timber", Kit.decor())
		end
	end
	Kit.slab(group, "OfferingTableShelf", Vector3.new(5.2, 0.18, 1.45), table_ * CFrame.new(0, 0.4, 0), "Timber", Kit.decor())
	Kit.slab(group, "OfferingTop", Vector3.new(6.4, 0.18, 2.1), table_ * CFrame.new(0, 1.49, 0), "Lacquer", Kit.decor())
	Kit.disc(group, "CenserFoot", 0.45, 0.14, table_ * CFrame.new(0, 1.66, 0), Kit.Palette.Gold, Enum.Material.Metal, Kit.decor()).MaterialVariant = "AsuraBronze"
	Kit.disc(group, "Censer", 0.6, 0.45, table_ * CFrame.new(0, 1.91, 0), Kit.Palette.Gold, Enum.Material.Metal, Kit.decor()).MaterialVariant = "AsuraBronze"
	Kit.disc(group, "CenserAsh", 0.5, 0.04, table_ * CFrame.new(0, 2.15, 0), Color3.fromRGB(61, 61, 57), Enum.Material.Basalt, Kit.decor())
	for _, x in { -0.17, 0.04, 0.19 } do
		Kit.part(group, "IncenseStick", Vector3.new(0.035, 0.72, 0.035), table_ * CFrame.new(x, 2.51, 0), Color3.fromRGB(82, 56, 35), Enum.Material.Wood, Kit.decor())
	end
	for x = -2, 2, 4 do
		Kit.disc(group, "CandleDish", 0.31, 0.08, table_ * CFrame.new(x, 1.64, 0), Kit.Palette.Gold, Enum.Material.Metal, Kit.decor())
		Kit.part(group, "OfferingCandle", Vector3.new(0.24, 0.52, 0.24), table_ * CFrame.new(x, 1.94, 0), Color3.fromRGB(194, 164, 119), Enum.Material.SmoothPlastic, Kit.decor())
		Kit.glow(group, table_ * CFrame.new(x, 2.3, 0), Vector3.new(0.1, 0.18, 0.1), 7, 0.35)
	end
end

-- Covered walk on a 12-stud bridge from the courtyard edge `a` to the destination edge `b`. `gap`
-- leaves the last bay's rail out on one side (-1 south of a westward walk), for a route off it.
local function walkway(group: Instance, origin: CFrame, a: Vector3, b: Vector3, gap: number?)
	local mid, length = (a + b) * 0.5, (b - a).Magnitude
	Kit.slab(group, "Walkway", Vector3.new(length + 2, 3, WALK.Width), origin * CFrame.new(mid + Y * (TOP - 1.55)), "Paving")
	local pa, pb = (origin * CFrame.new(a + Y * (TOP - 0.05))).Position, (origin * CFrame.new(b + Y * (TOP - 0.05))).Position
	Frame.gallery(group, pa, pb, WALK.Width, WALK.Height, { CapStart = false })
	local dir = (pb - pa).Unit
	local across = dir:Cross(Y).Unit
	local floorFrame = Kit.along(pa, pb)
	for side = -1, 1, 2 do
		Kit.slab(group, "GalleryEdgeCourse", Vector3.new(length, 0.12, 0.7), floorFrame * CFrame.new(0, -0.005, side * (WALK.Width / 2 - 0.4)), "StoneDark", Kit.decor())
		Kit.slab(group, "GalleryBronzeThread", Vector3.new(length - 0.8, 0.025, 0.06), floorFrame * CFrame.new(0, 0.057, side * (WALK.Width / 2 - 1)), "Bronze", Kit.decor())
	end
	local n = math.max(1, math.round(length / 7.5))
	local step = length / n
	for s = -1, 1, 2 do
		for i = 1, n do
			if gap == s and i == n then
				continue
			end
			local p0 = pa + dir * (step * (i - 1) + 0.9) + across * s * (WALK.Width / 2)
			local p1 = pa + dir * (step * i - 0.9) + across * s * (WALK.Width / 2)
			Rails.run(group, p0, p1, false)
		end
	end
end

function Cloisters.Build(parent: Instance, origin: CFrame, forgeEdge: number, duelEdge: number): Folder
	local group = Kit.folder("Cloisters", parent)
	for side = -1, 1, 2 do
		hall(group, origin, side)
		local a = (origin * CFrame.new(side * SIDE.X, TOP, SIDE.Z0)).Position
		local b = (origin * CFrame.new(side * SIDE.X, TOP, SIDE.Z1)).Position
		Frame.gallery(group, a, b, SIDE.Width, SIDE.Height, { CapEnd = true, Lanterns = true })
		Props.bench(group, origin * CFrame.new(side * (SIDE.X + 2.2), TOP, -24) * CFrame.Angles(0, math.rad(side * 90), 0))
	end
	-- The forge walk opens onto the Loggia Eaves service ledge (SanctuaryRoutes) beside the platform.
	walkway(group, origin, Vector3.new(-46, 0, 0), Vector3.new(-forgeEdge, 0, 0), -1)
	walkway(group, origin, Vector3.new(46, 0, 0), Vector3.new(duelEdge, 0, 0))
	return group
end

return table.freeze(Cloisters)

--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryHalls
-- The two ruined prayer halls flanking the processional path and the desecrated cloister beyond
-- the ravine. Halls keep half a pagoda roof; the other half has slid off and leans against the
-- north colonnade. Column lines stay outside every patrol circle in WorldDefinitions.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Ruins = require(script.Parent:WaitForChild("MonasteryRuins") :: ModuleScript)

local Halls = {}

local P = Kit.Palette
local G = Kit.GROUND
local SLATE, WOOD, FABRIC = Enum.Material.Slate, Enum.Material.Wood, Enum.Material.Fabric
local COLUMN_HEIGHT = 14

local function column(parent: Instance, x: number, z: number, rng: Random, height: number?)
	local h = height or COLUMN_HEIGHT
	local broken = height == nil and rng:NextNumber() < 0.22
	if broken then
		h = rng:NextNumber(3, 8)
	end
	Kit.disc(parent, "ColumnBase", 1.7, 1, CFrame.new(x, G + 0.5, z), P.StoneDark, SLATE)
	Kit.disc(parent, "Column", 1, h, CFrame.new(x, G + 1 + h * 0.5, z), P.Lacquer:Lerp(P.WoodDark, rng:NextNumber(0.35, 0.7)), WOOD)
	if broken then
		Kit.part(parent, "ColumnDrum", Vector3.new(2, 2, rng:NextNumber(4, 7)), CFrame.new(x + rng:NextNumber(-1, 1), G + 1, z + 3) *
			CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), P.Lacquer:Lerp(P.WoodDark, 0.6), WOOD, Kit.decor())
	else
		Kit.part(parent, "Bracket", Vector3.new(3, 1, 3), CFrame.new(x, G + h + 1.5, z), P.WoodDark, WOOD, Kit.decor())
	end
end

local function banner(parent: Instance, at: CFrame, rng: Random)
	local length = rng:NextNumber(6, 9)
	Kit.part(parent, "Banner", Vector3.new(2.4, length, 0.08), at * CFrame.new(0, -length * 0.5, 0) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.05, 0.05)),
		P.LeafDark:Lerp(P.WoodDark, rng:NextNumber(0, 0.4)), FABRIC, { Collide = false, Query = false })
end

-- side = -1 for the west hall (back wall at x0), +1 for the east hall (back wall at x1).
local function hall(parent: Instance, name: string, x0: number, x1: number, z0: number, z1: number, side: number, rng: Random)
	local group = Kit.folder(name, parent)
	local back, front = if side < 0 then x0 else x1, if side < 0 then x1 else x0
	local inward = -side -- direction from the back wall toward the path
	local zN, zS, zMid = z0 - 3, z1 + 3, (z0 + z1) * 0.5
	for x = back + inward * 4, front - inward * 2, inward * 8 do
		column(group, x, zN, rng)
		column(group, x, zS, rng)
	end
	for z = zN - 8, zS + 1, -8 do
		column(group, front - inward * 3, z, rng)
	end
	Ruins.wall(group, Vector2.new(back, z0), Vector2.new(back, z1), 13, rng, 0.08)
	Ruins.wall(group, Vector2.new(back, z0 - 0.5), Vector2.new(back + inward * 24, z0 - 0.5), 13, rng, 0.15)
	-- Half the roof survives over the back aisle...
	local width = math.abs(x1 - x0) * 0.5 + 2
	Ruins.roof(group, CFrame.new(back + inward * (width * 0.5 - 1), G + COLUMN_HEIGHT + 2, zMid), width, math.abs(z1 - z0) + 4, rng, true)
	-- ...the front half slid off and leans against the north colonnade, tiles shattered below.
	for k = 0, 2 do
		local xc = front - inward * (6 + k * 9)
		local top, foot = Vector3.new(xc, G + COLUMN_HEIGHT, zN - 1), Vector3.new(xc + rng:NextNumber(-1, 1), G + 0.6, zN + 9)
		Kit.part(group, "FallenRoof", Vector3.new(9.4, 0.6, (top - foot).Magnitude), CFrame.lookAt((top + foot) * 0.5, top) * CFrame.Angles(0, 0, rng:NextNumber(-0.06, 0.06)),
			P.Roof:Lerp(P.StoneDark, rng:NextNumber(0, 0.3)), SLATE)
	end
	for _ = 1, 26 do
		Kit.part(group, "Tile", Vector3.new(1.4, 0.18, 1), CFrame.new(front - inward * rng:NextNumber(2, 26), G + 0.09, zMid + rng:NextNumber(-30, 30)) *
			CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.1, 0.1)), P.Roof, SLATE, Kit.decor())
	end
	-- The defaced idol at the back: seated body, head struck off and lying at its feet.
	local idol = back + inward * 7
	Kit.part(group, "IdolDais", Vector3.new(7, 2, 9), CFrame.new(idol, G + 1, zMid), P.StoneDark, SLATE)
	Kit.part(group, "IdolBody", Vector3.new(4, 6, 5), CFrame.new(idol, G + 5, zMid), P.Stone:Lerp(P.Moss, 0.25), SLATE)
	Kit.part(group, "IdolHead", Vector3.new(2.2, 2.4, 2.2), CFrame.new(idol + inward * 5, G + 1.2, zMid + 3) * CFrame.Angles(0.4, 1.1, 1.3), P.Stone, SLATE)
	for dz = -1, 1, 2 do
		Fx.lantern(group, CFrame.new(idol + inward * 6, G, zMid + dz * 7), false, 16)
		banner(group, CFrame.new(front - inward * 3, G + COLUMN_HEIGHT, zMid + dz * 12), rng)
	end
	local motes = Kit.hidden(group, "Dust", Vector3.new(24, 10, 50), CFrame.new(back + inward * 14, G + 7, zMid))
	local dust = Fx.leaves(motes, 3)
	dust.Name = "DustMotes"
	dust.Color = ColorSequence.new(P.Dawn)
	dust.Acceleration = Vector3.new(0.2, -0.05, 0.1)
	dust.Size = Kit.sequence({ { 0, 0.12 }, { 1, 0.06 } })
end

-- Square cloister: outer wall, inner colonnade under lean-to eaves (some fallen), open garth.
local function cloister(parent: Instance, x0: number, x1: number, z0: number, z1: number, rng: Random)
	local group = Kit.folder("Cloister", parent)
	local walls = Kit.folder("CloisterWalls", group)
	Ruins.wall(walls, Vector2.new(x0, z0), Vector2.new(x1, z0), 10, rng, 0.12)
	Ruins.wall(walls, Vector2.new(x1, z0), Vector2.new(x1, z1), 10, rng, 0.1)
	Ruins.wall(walls, Vector2.new(x1, z1), Vector2.new(x0, z1), 10, rng, 0.15)
	Ruins.wall(walls, Vector2.new(x0, z1), Vector2.new(x0, -1034), 10, rng, 0.1) -- West gateway opens -990..-1034
	local cx0, cx1, cz0, cz1 = x0 + 8, x1 - 8, z0 - 8, z1 + 8
	local ring: { { Vector3 } } = {
		{ Vector3.new(cx0, 0, cz0), Vector3.new(cx1, 0, cz0), Vector3.new(0, 0, 8) },
		{ Vector3.new(cx1, 0, cz0), Vector3.new(cx1, 0, cz1), Vector3.new(-8, 0, 0) },
		{ Vector3.new(cx1, 0, cz1), Vector3.new(cx0, 0, cz1), Vector3.new(0, 0, -8) },
		{ Vector3.new(cx0, 0, cz1), Vector3.new(cx0, 0, cz0), Vector3.new(8, 0, 0) },
	}
	for _, edge in ring do
		local a, b, out = edge[1], edge[2], edge[3]
		local count = math.round((b - a).Magnitude / 12)
		for k = 0, count - 1 do
			local at = a:Lerp(b, k / count)
			column(group, at.X, at.Z, rng, 8)
			local mid = a:Lerp(b, (k + 0.5) / count)
			local low, high = mid + Vector3.new(0, G + 9.2, 0), mid + out + Vector3.new(0, G + 10.8, 0)
			if rng:NextNumber() < 0.8 then
				Kit.part(group, "Eave", Vector3.new(12.4, 0.45, (high - low).Magnitude + 1.6), CFrame.lookAt((low + high) * 0.5, high), P.Roof:Lerp(P.StoneDark, rng:NextNumber(0, 0.3)), SLATE, Kit.decor())
			else
				local foot = mid + out * 0.4 + Vector3.new(0, G + 0.5, 0)
				Kit.part(group, "FallenEave", Vector3.new(12, 0.45, 10), CFrame.lookAt((foot + high) * 0.5, high), P.Roof, SLATE, Kit.decor())
			end
		end
	end
end

function Halls.Build(parent: Instance, rng: Random)
	hall(parent, "WestPrayerHall", -102, -38, -866, -934, -1, rng)
	hall(parent, "EastPrayerHall", 38, 118, -868, -936, 1, rng)
	cloister(parent, 14, 128, -990, -1114, rng)
end

return Halls
